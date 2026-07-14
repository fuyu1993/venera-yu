import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/components/components.dart';
import 'package:venera/foundation/context.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/utils/translations.dart';

/// Reads a remote WebDAV PDF as a single comic (one PDF = one comic).
///
/// Built on pdfrx's [PdfViewer.custom], whose `read` callback is backed by
/// pdfium's FPDF_FILEACCESS under the hood. pdfrx asks for byte ranges on
/// demand; we serve cached bytes immediately, or issue a WebDAV Range request
/// to fill the gap into a local sparse cache file. We never feed zeros for
/// missing ranges — instead we return 0 and pdfrx retries once the bytes
/// arrive, which eliminates the native crash risk of the old sparse-file
/// approach.
class RemotePdfComicPage extends StatefulWidget {
  final String folderPath;

  final String name;

  final List<wd.File> pdfs;

  final int initialIndex;

  const RemotePdfComicPage({
    super.key,
    required this.folderPath,
    required this.name,
    required this.pdfs,
    this.initialIndex = 0,
  });

  @override
  State<RemotePdfComicPage> createState() => _RemotePdfComicPageState();
}

/// Minimal async mutex used to serialize all [RandomAccessFile] operations on
/// the local cache. The `read` callback (and the prefetcher) can run
/// concurrently, and interleaved `setPosition`/`writeFrom`/`readInto` would
/// corrupt the file, so every access goes through this lock.
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

class _RemotePdfComicPageState extends State<RemotePdfComicPage> {
  late int _current;

  bool _metaLoading = true;

  String? _error;

  int _total = 0;

  /// Whether the server supports HTTP Range (true) or we fall back to a full
  /// sequential download (false).
  bool _rangeSupported = true;

  String? _localPath;

  RandomAccessFile? _raf;

  wd.Client? _client;

  CancelToken? _cancel;

  /// Cached byte intervals [start, endInclusive] in the local sparse file.
  final List<(int, int)> _cached = [];

  final _Mutex _lock = _Mutex();

  final ValueNotifier<int> _downloaded = ValueNotifier<int>(0);

  static const int _chunk = 1 * 1024 * 1024;

  static const int _tailSize = 4 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.pdfs.length - 1);
    _loadCurrent();
  }

  Future<String> _tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'venera_pdf'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  String _safeName(String name, int index) =>
      '${index}_${name.replaceAll(RegExp(r'[^\w\.\-]'), '_')}';

  String get _sourceId =>
      '${widget.name}#$_current#${widget.pdfs.isEmpty ? '' : (widget.pdfs[_current].name ?? '')}';

  Future<void> _loadCurrent() async {
    if (_current < 0 || _current >= widget.pdfs.length) return;
    final file = widget.pdfs[_current];

    // Cancel any in-flight prefetch / read for the previous chapter.
    _cancel?.cancel();
    _cancel = CancelToken();

    final old = _localPath;
    try {
      await _raf?.close();
    } catch (_) {
      // ignore
    }
    _raf = null;
    _cached.clear();
    _downloaded.value = 0;
    if (mounted) {
      setState(() {
        _localPath = null;
        _metaLoading = true;
        _total = 0;
        _error = null;
        _rangeSupported = true;
      });
    }
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {
        // ignore
      }
    }

    try {
      _client = RemoteWebDav.getClient();
      if (_client == null) throw 'Remote WebDAV not configured';
      final size = await RemoteWebDav.fileSize(file.path!);
      if (size <= 0) throw Exception('Unknown file size');
      final dir = await _tempDir();
      final dest = p.join(dir, _safeName(file.name ?? 'file.pdf', _current));
      final raf = await File(dest).open(mode: FileMode.write);
      // Pre-allocate the full size (sparse) so we can seek/write anywhere.
      await raf.truncate(size);
      _localPath = dest;
      _total = size;
      _raf = raf;
      if (mounted) setState(() => _metaLoading = false);
      _startPrefetch(file.path!, size, raf, _cancel!);
    } catch (e, s) {
      Log.error('Remote PDF', e, s);
      if (mounted) {
        setState(() {
          _error = 'Failed to load'.tl;
          _metaLoading = false;
        });
      }
    }
  }

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
        final ns = s < r.$1 ? s : r.$1;
        final ne = e > r.$2 ? e : r.$2;
        _cached[i] = (ns, ne);
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

  void _updateProgress() {
    var bytes = 0;
    for (final r in _cached) {
      bytes += r.$2 - r.$1 + 1;
    }
    _downloaded.value = bytes;
  }

  /// Background prefetcher: tail (xref) first, then body sequentially. This
  /// warms the local cache so on-demand reads usually hit it.
  Future<void> _startPrefetch(
    String path,
    int size,
    RandomAccessFile raf,
    CancelToken cancel,
  ) async {
    final client = _client;
    if (client == null) return;
    try {
      final tail = size > _tailSize ? _tailSize : size;
      final tailStart = size - tail;
      int st = 0;
      await _lock.run(() async {
        st = await RemoteWebDav.downloadRange(
          path,
          tailStart,
          size - 1,
          raf,
          client: client,
          cancelToken: cancel,
        );
      });
      if (st != 206) {
        // Server ignored Range: fall back to a full sequential download.
        _rangeSupported = false;
        await _lock.run(() async {
          await _fullDownload(client, path, raf, size, cancel);
          _addCached(0, size - 1);
          _updateProgress();
        });
        return;
      }
      await _lock.run(() async {
        _addCached(tailStart, size - 1);
        _updateProgress();
      });
      var start = 0;
      while (start < tailStart && !cancel.isCancelled) {
        final end = (start + _chunk - 1 < tailStart - 1)
            ? start + _chunk - 1
            : tailStart - 1;
        await _lock.run(() async {
          await RemoteWebDav.downloadRange(
            path,
            start,
            end,
            raf,
            client: client,
            cancelToken: cancel,
          );
          _addCached(start, end);
          _updateProgress();
        });
        start = end + 1;
      }
    } catch (e) {
      if (!cancel.isCancelled) Log.error('Remote PDF prefetch', e);
    }
  }

  /// Sequential full download (used when Range is unsupported by the server).
  Future<void> _fullDownload(
    wd.Client client,
    String path,
    RandomAccessFile raf,
    int size,
    CancelToken cancel,
  ) async {
    final resp = await client.c.req<ResponseBody>(
      client,
      'GET',
      path,
      optionsHandler: (options) {
        options.responseType = ResponseType.stream;
      },
      cancelToken: cancel,
    );
    await raf.setPosition(0);
    var received = 0;
    await for (final chunk in resp.data!.stream) {
      if (chunk.isEmpty) continue;
      if (cancel.isCancelled) break;
      await raf.writeFrom(chunk);
      received += chunk.length;
      if (received % (4 * 1024 * 1024) < chunk.length) {
        _addCached(0, received - 1);
        _updateProgress();
      }
    }
    _addCached(0, size - 1);
    _updateProgress();
  }

  /// pdfrx read callback (FPDF_FILEACCESS `m_GetBlock`, Dart async version).
  ///
  /// Returns the number of bytes filled into [buffer], or 0 if the requested
  /// range is not (yet) available — pdfrx will retry once the bytes arrive.
  Future<int> _readBlock(Uint8List buffer, int position, int size) async {
    if (_raf == null) return 0;
    if (position + size > _total) {
      size = (_total - position).clamp(0, size);
    }
    if (size <= 0) return 0;
    final path = widget.pdfs[_current].path!;
    return await _lock.run(() async {
      if (_isCached(position, position + size - 1)) {
        await _raf!.setPosition(position);
        await _raf!.readInto(buffer);
        return size;
      }
      if (!_rangeSupported) {
        // Full download in progress; report missing for now, pdfrx retries.
        return 0;
      }
      final start = (position ~/ _chunk) * _chunk;
      var blockEnd = (start + _chunk - 1).clamp(0, _total - 1);
      if (blockEnd < position + size - 1) {
        blockEnd = (position + size - 1).clamp(0, _total - 1);
      }
      int status;
      try {
        status = await RemoteWebDav.downloadRange(
          path,
          start,
          blockEnd,
          _raf!,
          client: _client!,
          cancelToken: _cancel!,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 206 || e.response?.statusCode == 200) {
          // The range was (partially) served; fall through to serve what we
          // can. downloadRange already wrote the available bytes.
        } else {
          return 0;
        }
        status = e.response?.statusCode ?? 0;
      } catch (_) {
        return 0;
      }
      if (status == 206) {
        _addCached(start, blockEnd);
        _updateProgress();
        await _raf!.setPosition(position);
        await _raf!.readInto(buffer);
        return size;
      }
      // 200: server ignored Range. Mark unsupported; pdfrx retries after the
      // full download (started by the prefetcher) catches up.
      _rangeSupported = false;
      return 0;
    });
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.pdfs.length || index == _current) return;
    _current = index;
    _loadCurrent();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    try {
      _raf?.closeSync();
    } catch (_) {
      // ignore
    }
    if (_localPath != null) {
      try {
        File(_localPath!).deleteSync();
      } catch (_) {
        // ignore
      }
    }
    _downloaded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pdfs.length;
    final chapterName =
        widget.pdfs.isEmpty ? '' : (widget.pdfs[_current].name ?? 'PDF');
    return Scaffold(
      appBar: Appbar(
        title: Text(widget.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (total > 1)
            IconButton(
              icon: const Icon(LucideIcons.chevron_left),
              onPressed: _current > 0 ? () => _goTo(_current - 1) : null,
              tooltip: 'Previous'.tl,
            ),
          if (total > 1)
            IconButton(
              icon: const Icon(LucideIcons.chevron_right),
              onPressed:
                  _current < total - 1 ? () => _goTo(_current + 1) : null,
              tooltip: 'Next'.tl,
            ),
          if (total > 1)
            PopupMenuButton<int>(
              icon: const Icon(LucideIcons.list),
              tooltip: 'Chapters'.tl,
              onSelected: _goTo,
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text('Chapters'.tl),
                ),
                for (var i = 0; i < total; i++)
                  PopupMenuItem(
                    value: i,
                    child: Text(
                      widget.pdfs[i].name ?? 'PDF $i',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (total > 1)
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Text(
                '$chapterName  (${_current + 1}/$total)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colorScheme.outline,
                ),
              ),
            ),
          if (_total > 0 && _downloaded.value < _total)
            ValueListenableBuilder<int>(
              valueListenable: _downloaded,
              builder: (ctx, d, _) => LinearProgressIndicator(
                value: _total > 0 ? d / _total : null,
                minHeight: 2,
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circle_alert,
                size: 48, color: context.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadCurrent,
              child: Text('Retry'.tl),
            ),
          ],
        ),
      );
    }
    if (_metaLoading || _total <= 0) {
      final pct = _total > 0 ? (_downloaded.value / _total * 100).toInt() : 0;
      final label = _rangeSupported ? 'Preparing'.tl : 'Downloading'.tl;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _total > 0 ? _downloaded.value / _total : null,
            ),
            const SizedBox(height: 16),
            Text('$label  ·  $pct%'),
          ],
        ),
      );
    }
    return PdfViewer.custom(
      key: Key(_sourceId),
      fileSize: _total,
      read: _readBlock,
      sourceName: _sourceId,
      useProgressiveLoading: true,
      params: const PdfViewerParams(),
    );
  }
}
