import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';

/// A single image entry inside the ZIP, resolved from the central directory.
class _ZipEntry {
  final String name;
  final int method;
  final int compressedSize;
  final int localOffset;
  final int uncompressedSize;

  _ZipEntry(this.name, this.method, this.compressedSize, this.localOffset,
      this.uncompressedSize);
}

/// A single open remote ZIP, exposed to the built-in comic reader.
///
/// A ZIP's central directory lives at the end of the file, so the session
/// first Range-fetches the tail (EOCD + central directory) to enumerate every
/// image entry without downloading the whole archive. Reading page *N* then
/// fetches just that entry's compressed bytes via one more Range request and
/// inflates them (method 8) or passes them through (method 0, stored). The
/// result is an ordinary image (jpg/png/...), cached on disk so scrolling back
/// never re-fetches.
///
/// If the server ignores Range requests, the whole archive is downloaded once
/// to a temp file and all subsequent reads come from there (mirroring the
/// [PdfSession] fallback).
class ZipSession {
  ZipSession._({
    required this.key,
    required this.remotePath,
    required this.fileSize,
    required wd.Client client,
  }) : _client = client;

  /// Unique session key (the WebDAV file path). Also used as the reader `cid`.
  final String key;

  final String remotePath;

  final int fileSize;

  final wd.Client _client;

  int _pageCount = 0;

  int get pageCount => _pageCount;

  /// Image entries in reading order (natural sort by name).
  List<_ZipEntry> _imageEntries = const [];

  /// Decompressed page cache directory.
  String? _pageCacheDir;

  /// When Range is unsupported, the whole archive is downloaded here.
  File? _localFile;

  Future<void>? _fullDownloadFuture;

  final CancelToken _cancel = CancelToken();

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Opening
  // ---------------------------------------------------------------------------

  static Future<ZipSession> open({
    required String sessionKey,
    required String remotePath,
  }) async {
    final client = RemoteWebDav.getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    final size = await RemoteWebDav.fileSize(remotePath);
    if (size <= 0) throw Exception('Unknown file size');

    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'venera_zip'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final hash = sha1.convert(sessionKey.codeUnits).toString().substring(0, 16);
    final pageDir = Directory(p.join(dir.path, 'pages_$hash'));
    if (!await pageDir.exists()) await pageDir.create(recursive: true);

    final session = ZipSession._(
      key: sessionKey,
      remotePath: remotePath,
      fileSize: size,
      client: client,
    )
      .._pageCacheDir = pageDir.path;

    try {
      await session._parseCentralDirectory();
      if (session._imageEntries.isEmpty) {
        throw Exception('No images found in the archive');
      }
      session._pageCount = session._imageEntries.length;
      return session;
    } catch (e) {
      await session.dispose();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ZIP structure parsing
  // ---------------------------------------------------------------------------

  static const int _sigLocal = 0x04034b50;
  static const int _sigCentral = 0x02014b50;

  static int _u16(Uint8List b, int off) => b[off] | (b[off + 1] << 8);

  static int _u32(Uint8List b, int off) =>
      b[off] |
      (b[off + 1] << 8) |
      (b[off + 2] << 16) |
      (b[off + 3] << 24);

  static bool _isImageName(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0) return false;
    const exts = {
      'jpg',
      'jpeg',
      'jpe',
      'png',
      'webp',
      'gif',
      'bmp',
      'avif',
      'heic',
      'heif',
      'tif',
      'tiff',
      'jfif',
      'jxl'
    };
    return exts.contains(name.substring(i + 1).toLowerCase());
  }

  Future<void> _parseCentralDirectory() async {
    // Locate the End Of Central Directory record in the tail.
    final tailLen = fileSize > 64 * 1024 + 22 ? 64 * 1024 + 22 : fileSize;
    final tailStart = fileSize - tailLen;
    final tail = await _fetchRange(tailStart, fileSize - 1);
    int eocd = -1;
    for (int i = tail.length - 22; i >= 0; i--) {
      if (tail[i] == 0x50 &&
          tail[i + 1] == 0x4B &&
          tail[i + 2] == 0x05 &&
          tail[i + 3] == 0x06) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw Exception('Not a ZIP file (no EOCD)');

    final cdOffset = _u32(tail, eocd + 16);
    final cdSize = _u32(tail, eocd + 12);
    if (cdOffset == 0xffffffff || cdSize == 0xffffffff) {
      throw Exception('ZIP64 archives are not supported');
    }

    final cd = await _fetchRange(cdOffset, cdOffset + cdSize - 1);

    final entries = <_ZipEntry>[];
    int pos = 0;
    while (pos + 46 <= cd.length) {
      if (_u32(cd, pos) != _sigCentral) break;
      final method = _u16(cd, pos + 10);
      final compressedSize = _u32(cd, pos + 20);
      final nameLen = _u16(cd, pos + 28);
      final extraLen = _u16(cd, pos + 30);
      final commentLen = _u16(cd, pos + 32);
      final localOffset = _u32(cd, pos + 42);
      final uncompressedSize = _u32(cd, pos + 24);
      if (localOffset == 0xffffffff) {
        throw Exception('ZIP64 archives are not supported');
      }
      final nameBytes = cd.sublist(pos + 46, pos + 46 + nameLen);
      final name = String.fromCharCodes(nameBytes);
      pos += 46 + nameLen + extraLen + commentLen;
      // Only keep readable image entries.
      if (_isImageName(name)) {
        entries.add(_ZipEntry(
          name,
          method,
          compressedSize,
          localOffset,
          uncompressedSize,
        ));
      }
    }

    // Natural order so `page_2` precedes `page_10`, etc.
    entries.sort((a, b) => naturalCompare(_baseName(a.name), _baseName(b.name)));
    _imageEntries = entries;
  }

  static String _baseName(String path) {
    final clean = path.split('/').where((e) => e.isNotEmpty).lastOrNull ?? path;
    return clean;
  }

  // ---------------------------------------------------------------------------
  // Byte source
  // ---------------------------------------------------------------------------

  Future<Uint8List> _fetchRange(int start, int end) async {
    if (_localFile != null) return _readLocal(start, end);
    late Response<ResponseBody> resp;
    try {
      resp = await _client.c.req<ResponseBody>(
        _client,
        'GET',
        remotePath,
        optionsHandler: (options) {
          options.responseType = ResponseType.stream;
          options.headers ??= {};
          options.headers?['Range'] = 'bytes=$start-$end';
        },
        cancelToken: _cancel,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != null && e.response!.statusCode != 206) {
        // Range unsupported: fall back to a full local download.
        await _ensureLocalFile();
        return _readLocal(start, end);
      }
      rethrow;
    }
    final status = resp.statusCode ?? 0;
    final stream = resp.data?.stream;
    if (stream == null) throw Exception('Empty response (HTTP $status)');
    final out = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (chunk.isEmpty) continue;
      out.add(chunk);
    }
    final bytes = out.takeBytes();
    if (status == 206) return bytes;
    // Server ignored Range: the whole file came back. Cache it locally.
    await _ensureLocalFile();
    return _readLocal(start, end);
  }

  Future<Uint8List> _readLocal(int start, int end) async {
    final raf = await _localFile!.open();
    try {
      await raf.setPosition(start);
      final out = BytesBuilder(copy: false);
      var remaining = end - start + 1;
      while (remaining > 0) {
        final chunk = await raf.read(remaining > 1 << 16 ? 1 << 16 : remaining);
        if (chunk.isEmpty) break;
        out.add(chunk);
        remaining -= chunk.length;
      }
      return out.takeBytes();
    } finally {
      await raf.close();
    }
  }

  Future<void> _ensureLocalFile() {
    return _fullDownloadFuture ??= () async {
      final base = await getTemporaryDirectory();
      final dir = Directory(p.join(base.path, 'venera_zip'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final hash = sha1.convert(key.codeUnits).toString().substring(0, 16);
      _localFile = File(p.join(dir.path, '$hash.zip'));
      final raf = await _localFile!.open(mode: FileMode.write);
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
        await for (final chunk in resp.data!.stream) {
          if (chunk.isEmpty) continue;
          if (_cancel.isCancelled) break;
          await raf.writeFrom(chunk);
        }
      } finally {
        await raf.close();
      }
    }();
  }

  // ---------------------------------------------------------------------------
  // Rendering (decompressing) pages
  // ---------------------------------------------------------------------------

  String _pagePath(int index) => p.join(_pageCacheDir!, '$index.img');

  Future<Uint8List> renderPage(int index) async {
    if (_disposed) throw 'ZIP session disposed';
    if (index < 0 || index >= _imageEntries.length) {
      throw 'Page out of range';
    }
    final cacheFile = File(_pagePath(index));
    if (await cacheFile.exists()) {
      try {
        final bytes = await cacheFile.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {
        // fall through
      }
    }
    final bytes = await _readEntry(_imageEntries[index]);
    try {
      await cacheFile.writeAsBytes(bytes, flush: false);
    } catch (_) {
      // best-effort cache
    }
    return bytes;
  }

  Future<Uint8List> _readEntry(_ZipEntry e) async {
    // Read just the local file header to locate where the data begins.
    final header = await _fetchRange(e.localOffset, e.localOffset + 29);
    if (header.length < 30 || _u32(header, 0) != _sigLocal) {
      throw Exception('Corrupt local file header');
    }
    final nameLen = _u16(header, 26);
    final extraLen = _u16(header, 28);
    final dataOffset = e.localOffset + 30 + nameLen + extraLen;
    final compressed =
        await _fetchRange(dataOffset, dataOffset + e.compressedSize - 1);
    if (e.method == 0) {
      // Stored (no compression): the bytes are already the image.
      return compressed;
    } else if (e.method == 8) {
      // DEFLATE: inflate the raw compressed bytes.
      final out = Inflate(compressed).getBytes();
      return Uint8List.fromList(out);
    }
    throw Exception('Unsupported compression method ${e.method}');
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancel.cancel();
    try {
      if (_localFile != null) await _localFile!.delete();
    } catch (_) {}
    try {
      if (_pageCacheDir != null) {
        await Directory(_pageCacheDir!).delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// Global registry of open [ZipSession]s, keyed by the WebDAV file path (which
/// is also the reader `cid`). The reader's image providers look sessions up
/// here to render pages on demand.
class ZipSessionManager {
  ZipSessionManager._();

  static final ZipSessionManager _instance = ZipSessionManager._();

  factory ZipSessionManager() => _instance;

  final Map<String, ZipSession> _sessions = {};

  ZipSession? get(String key) => _sessions[key];

  Future<ZipSession> open({
    required String sessionKey,
    required String remotePath,
  }) async {
    await close(sessionKey);
    final session =
        await ZipSession.open(sessionKey: sessionKey, remotePath: remotePath);
    _sessions[sessionKey] = session;
    return session;
  }

  Future<void> close(String key) async {
    final s = _sessions.remove(key);
    if (s != null) await s.dispose();
  }

  /// Renders the first image of a remote ZIP as a cover (used by history-grid
  /// thumbnails). Reuses an already-open session if one is active; otherwise
  /// opens a throwaway session that is closed immediately. Returns `null` on
  /// failure so callers can fall back to a placeholder.
  Future<Uint8List?> renderCover(String remotePath) async {
    final existing = _sessions[remotePath];
    if (existing != null) {
      try {
        return await existing.renderPage(0);
      } catch (e) {
        Log.error('ZIP cover', e);
        return null;
      }
    }
    ZipSession? s;
    try {
      s = await ZipSession.open(sessionKey: remotePath, remotePath: remotePath);
      _sessions[remotePath] = s;
      return await s.renderPage(0);
    } catch (e) {
      Log.error('ZIP cover', e);
      return null;
    } finally {
      if (s != null) await close(remotePath);
    }
  }
}
