import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/components/components.dart';
import 'package:venera/foundation/context.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/utils/translations.dart';

/// Reads a folder of remote WebDAV PDF files as a single "comic", where each
/// PDF is treated as a chapter. The selected PDF is streamed to a temp file
/// (with progress) and rendered via [PdfViewer].
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

class _RemotePdfComicPageState extends State<RemotePdfComicPage> {
  late int _current;

  /// Download progress (0..1) while a chapter is being fetched; null when ready.
  double? _progress;

  String? _localPath;

  String? _error;

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

  String _safeName(String name, int index) {
    final base = name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    return '${index}_$base';
  }

  Future<void> _loadCurrent() async {
    if (_current < 0 || _current >= widget.pdfs.length) return;
    final file = widget.pdfs[_current];
    // Drop the previously opened chapter to avoid filling the disk with
    // multi-GB PDFs while flipping through volumes.
    final old = _localPath;
    setState(() {
      _localPath = null;
      _progress = 0;
      _error = null;
    });
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {
        // ignore
      }
    }
    try {
      final dir = await _tempDir();
      final dest = p.join(dir, _safeName(file.name ?? 'file.pdf', _current));
      await RemoteWebDav.downloadToFile(
        file.path!,
        dest,
        onProgress: (count, total) {
          if (mounted && total > 0) {
            setState(() => _progress = count / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _localPath = dest;
        _progress = null;
      });
    } catch (e, s) {
      Log.error('Remote PDF', e, s);
      if (mounted) {
        setState(() {
          _error = 'Failed to load'.tl;
          _progress = null;
        });
      }
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.pdfs.length || index == _current) return;
    _current = index;
    _loadCurrent();
  }

  @override
  void dispose() {
    final path = _localPath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {
        // ignore
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pdfs.length;
    final chapterName = widget.pdfs.isEmpty
        ? ''
        : (widget.pdfs[_current].name ?? 'PDF');
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
    if (_progress != null) {
      final percent = (_progress! * 100).toInt();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text('$percent%  ·  ${'Downloading'.tl}'),
          ],
        ),
      );
    }
    if (_localPath != null) {
      return PdfViewer.openFile(
        _localPath!,
        key: ValueKey(_localPath),
        params: const PdfViewerParams(
          scrollDirection: Axis.vertical,
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}
