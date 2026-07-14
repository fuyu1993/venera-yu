import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';

/// Minimal async mutex used to serialize operations. Interleaved
/// [RandomAccessFile] seek/read/write would corrupt the sparse cache file, and
/// pdfium's FPDF_FILEACCESS has a single return slot, so renders must run one
/// at a time too. Every critical section goes through one of these locks.
class _Mutex {
  Future<void>? _chain;

  Future<T> run<T>(Future<T> Function() task) async {
    final prev = _chain;
    final completer = Completer<void>();
    _chain = completer.future;
    if (prev != null) {
      try {
        await prev;
      } on Object {
        // Ignore errors from a previous task; we still run ours.
      }
    }
    try {
      return await task();
    } finally {
      completer.complete();
    }
  }
}

/// A single open remote PDF, exposed to the built-in comic reader.
///
/// The PDF itself is opened with pdfrx's [PdfDocument.openCustom] over a
/// streaming byte source backed by a WebDAV Range download into a local sparse
/// cache file. Individual pages are rendered to PNG on demand (serialized) and
/// cached on disk, so scrolling back never re-renders or re-downloads.
class PdfSession {
  PdfSession._({
    required this.key,
    required this.remotePath,
    required this.fileSize,
    required RandomAccessFile raf,
    required String cachePath,
    required String pageCacheDir,
    required wd.Client client,
  })  : _raf = raf,
        _cachePath = cachePath,
        _pageCacheDir = pageCacheDir,
        _client = client;

  /// Unique session key (the WebDAV file path). Also used as the reader `cid`.
  final String key;

  final String remotePath;

  final int fileSize;

  final RandomAccessFile _raf;

  final String _cachePath;

  final String _pageCacheDir;

  final wd.Client _client;

  PdfDocument? _document;

  int _pageCount = 0;

  int get pageCount => _pageCount;

  /// Longest side (in pixels) each page is rendered at. Comics are usually a
  /// single full-page image; ~2400px keeps text/lines crisp without blowing up
  /// memory.
  static const double _maxLongSide = 2400;

  static const int _chunk = 1 * 1024 * 1024;

  static const int _tailSize = 4 * 1024 * 1024;

  /// Cached byte intervals [start, endInclusive] in the local sparse file.
  final List<(int, int)> _cached = [];

  /// Serializes all cache-file access (the `read` callback + prefetcher).
  final _Mutex _ioLock = _Mutex();

  /// Serializes page rendering (FPDF_FILEACCESS has a single return slot).
  final _Mutex _renderLock = _Mutex();

  final CancelToken _cancel = CancelToken();

  bool _rangeSupported = true;

  bool _disposed = false;

  Future<void>? _fullDownload;

  // ---------------------------------------------------------------------------
  // Opening
  // ---------------------------------------------------------------------------

  /// Opens a remote PDF and returns a ready-to-read [PdfSession]. Throws on
  /// failure. [sessionKey] must be stable (the WebDAV path) so the reader can
  /// look the session back up by its `cid`.
  static Future<PdfSession> open({
    required String sessionKey,
    required String remotePath,
  }) async {
    final client = RemoteWebDav.getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    final size = await RemoteWebDav.fileSize(remotePath);
    if (size <= 0) throw Exception('Unknown file size');

    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'venera_pdf'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final hash =
        sha1.convert(sessionKey.codeUnits).toString().substring(0, 16);
    final cachePath = p.join(dir.path, '$hash.pdf');
    final pageDir = p.join(dir.path, 'pages_$hash');
    final pd = Directory(pageDir);
    if (!await pd.exists()) await pd.create(recursive: true);

    final raf = await File(cachePath).open(mode: FileMode.write);
    // Pre-allocate the full size (sparse) so we can seek/write anywhere.
    await raf.truncate(size);

    final session = PdfSession._(
      key: sessionKey,
      remotePath: remotePath,
      fileSize: size,
      raf: raf,
      cachePath: cachePath,
      pageCacheDir: pageDir,
      client: client,
    );

    try {
      await session._warmTail();
      // Non-progressive open so any page can be rendered immediately. The heavy
      // per-page image streams are only read at render time (via `_read`).
      final doc = await PdfDocument.openCustom(
        read: session._read,
        fileSize: size,
        sourceName: 'pdf://$sessionKey',
        useProgressiveLoading: false,
      );
      session._document = doc;
      session._pageCount = doc.pages.length;
      // Warm the rest of the file in the background for smoother reading.
      unawaited(session._prefetchBody());
      return session;
    } catch (e) {
      await session.dispose();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Byte source (FPDF_FILEACCESS m_GetBlock, Dart async version)
  // ---------------------------------------------------------------------------

  bool _isCached(int a, int b) {
    for (final r in _cached) {
      if (r.$1 <= a && r.$2 >= b) return true;
    }
    return false;
  }

  void _addCached(int s, int e) {
    var merged = false;
    for (var i = 0; i < _cached.length; i++) {
      final r = _cached[i];
      if (s <= r.$2 + 1 && e >= r.$1 - 1) {
        _cached[i] = (s < r.$1 ? s : r.$1, e > r.$2 ? e : r.$2);
        merged = true;
        break;
      }
    }
    if (!merged) _cached.add((s, e));
    _cached.sort((x, y) => x.$1.compareTo(y.$1));
    for (var i = 0; i < _cached.length - 1; i++) {
      final a = _cached[i];
      final b = _cached[i + 1];
      if (a.$2 + 1 >= b.$1) {
        _cached[i] = (a.$1 < b.$1 ? a.$1 : b.$1, a.$2 > b.$2 ? a.$2 : b.$2);
        _cached.removeAt(i + 1);
        i--;
      }
    }
  }

  /// Fetch the tail (where the xref/trailer live) so `open` can parse quickly.
  Future<void> _warmTail() async {
    final tail = fileSize > _tailSize ? _tailSize : fileSize;
    final tailStart = fileSize - tail;
    final status = await _ioLock.run(() async {
      return RemoteWebDav.downloadRange(
        remotePath,
        tailStart,
        fileSize - 1,
        _raf,
        client: _client,
        cancelToken: _cancel,
      );
    });
    if (status == 206) {
      await _ioLock.run(() async => _addCached(tailStart, fileSize - 1));
    } else {
      // Server ignored Range: only a full sequential download will work.
      _rangeSupported = false;
      await _ensureFullDownload();
    }
  }

  /// Background prefetch of the whole file (best effort) for smooth reading.
  Future<void> _prefetchBody() async {
    if (!_rangeSupported) return;
    var start = 0;
    final tailStart =
        fileSize > _tailSize ? fileSize - _tailSize : fileSize;
    while (start < tailStart && !_cancel.isCancelled && !_disposed) {
      final end = (start + _chunk - 1 < tailStart - 1)
          ? start + _chunk - 1
          : tailStart - 1;
      try {
        await _ioLock.run(() async {
          if (_isCached(start, end)) return;
          final st = await RemoteWebDav.downloadRange(
            remotePath,
            start,
            end,
            _raf,
            client: _client,
            cancelToken: _cancel,
          );
          if (st == 206) _addCached(start, end);
        });
      } catch (e) {
        if (!_cancel.isCancelled) Log.error('PDF prefetch', e);
        break;
      }
      start = end + 1;
    }
  }

  Future<void> _ensureFullDownload() {
    return _fullDownload ??= () async {
      try {
        final resp = await _client.c.req<ResponseBody>(
          _client,
          'GET',
          remotePath,
          optionsHandler: (options) {
            options.responseType = ResponseType.stream;
          },
          cancelToken: _cancel,
        );
        await _ioLock.run(() async {
          await _raf.setPosition(0);
          await for (final c in resp.data!.stream) {
            if (c.isEmpty) continue;
            if (_cancel.isCancelled) break;
            await _raf.writeFrom(c);
          }
          _addCached(0, fileSize - 1);
        });
      } catch (e) {
        _fullDownload = null; // allow a retry
        rethrow;
      }
    }();
  }

  /// pdfrx `read` callback: fills [buffer] with [size] bytes at [position].
  ///
  /// Unlike the old [PdfViewer] path (which could return 0 and rely on retry),
  /// rendering requires the real bytes, so this *blocks* until the requested
  /// range is available (fetching a WebDAV Range on a cache miss) and returns
  /// the number of bytes actually filled.
  Future<int> _read(Uint8List buffer, int position, int size) async {
    if (_disposed || position >= fileSize) return 0;
    if (position + size > fileSize) size = fileSize - position;
    if (size <= 0) return 0;

    // Range-supported path: serve from cache, or fetch the covering chunk under
    // the io lock, then serve. Returns -1 to signal "range unsupported, retry
    // via full download".
    if (_rangeSupported) {
      final result = await _ioLock.run(() async {
        if (_isCached(position, position + size - 1)) {
          return _readFromCache(buffer, position, size);
        }
        final start = (position ~/ _chunk) * _chunk;
        final end = position + size - 1;
        var blockEnd = ((end ~/ _chunk) + 1) * _chunk - 1;
        if (blockEnd > fileSize - 1) blockEnd = fileSize - 1;
        int status;
        try {
          status = await RemoteWebDav.downloadRange(
            remotePath,
            start,
            blockEnd,
            _raf,
            client: _client,
            cancelToken: _cancel,
          );
        } on DioException catch (e) {
          status = e.response?.statusCode ?? 0;
        }
        if (status == 206) {
          _addCached(start, blockEnd);
          return _readFromCache(buffer, position, size);
        }
        // Server ignored Range: fall back to a single full download.
        _rangeSupported = false;
        return -1;
      });
      if (result >= 0) return result;
    }

    // Range unsupported: ensure the whole file is downloaded (this awaits
    // *outside* the io lock; the download grabs the lock for its own write),
    // then read from the now-complete cache.
    await _ensureFullDownload();
    return _ioLock.run(() => _readFromCache(buffer, position, size));
  }

  Future<int> _readFromCache(Uint8List buffer, int position, int size) async {
    await _raf.setPosition(position);
    var read = 0;
    while (read < size) {
      final n = await _raf.readInto(buffer, read, size);
      if (n <= 0) break;
      read += n;
    }
    return read;
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  String _pagePngPath(int index) => p.join(_pageCacheDir, '$index.png');

  /// Renders page [index] (0-based) to PNG bytes, using the on-disk cache when
  /// available. Rendering is serialized across the whole session.
  Future<Uint8List> renderPage(int index) async {
    if (_disposed) throw 'PDF session disposed';
    final doc = _document;
    if (doc == null) throw 'PDF not opened';
    if (index < 0 || index >= _pageCount) throw 'Page out of range';

    final cacheFile = File(_pagePngPath(index));
    if (await cacheFile.exists()) {
      try {
        final bytes = await cacheFile.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {
        // fall through to re-render
      }
    }

    return _renderLock.run(() async {
      // Re-check the disk cache: another request may have rendered it while we
      // were queued on the render lock.
      if (await cacheFile.exists()) {
        try {
          final bytes = await cacheFile.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        } catch (_) {
          // fall through
        }
      }

      final page = doc.pages[index];
      final ptW = page.width;
      final ptH = page.height;
      var scale = 2.0;
      var fw = ptW * scale;
      var fh = ptH * scale;
      final longest = fw > fh ? fw : fh;
      if (longest > _maxLongSide) {
        final r = _maxLongSide / longest;
        fw *= r;
        fh *= r;
      }

      final img = await page.render(
        fullWidth: fw,
        fullHeight: fh,
        backgroundColor: 0xffffffff,
      );
      if (img == null) throw 'Failed to render PDF page ${index + 1}';
      try {
        final png = await _bgraToPng(img.pixels, img.width, img.height);
        try {
          await cacheFile.writeAsBytes(png, flush: false);
        } catch (_) {
          // Disk cache is best-effort.
        }
        return png;
      } finally {
        img.dispose();
      }
    });
  }

  static Future<Uint8List> _bgraToPng(
    Uint8List bgra,
    int width,
    int height,
  ) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bgra,
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    final image = await completer.future;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw 'PNG encode failed';
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancel.cancel();
    try {
      await _document?.dispose();
    } catch (_) {}
    try {
      await _raf.close();
    } catch (_) {}
    try {
      await File(_cachePath).delete();
    } catch (_) {}
    try {
      await Directory(_pageCacheDir).delete(recursive: true);
    } catch (_) {}
  }
}

/// Global registry of open [PdfSession]s, keyed by the WebDAV file path (which
/// is also the reader `cid`). The reader's image providers look sessions up
/// here to render pages on demand.
class PdfSessionManager {
  PdfSessionManager._();

  static final PdfSessionManager _instance = PdfSessionManager._();

  factory PdfSessionManager() => _instance;

  final Map<String, PdfSession> _sessions = {};

  PdfSession? get(String key) => _sessions[key];

  /// Opens (or replaces) a session for [remotePath], keyed by [sessionKey].
  Future<PdfSession> open({
    required String sessionKey,
    required String remotePath,
  }) async {
    await close(sessionKey);
    final session =
        await PdfSession.open(sessionKey: sessionKey, remotePath: remotePath);
    _sessions[sessionKey] = session;
    return session;
  }

  Future<void> close(String key) async {
    final s = _sessions.remove(key);
    if (s != null) await s.dispose();
  }
}
