import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/remote_download_manager.dart';
import 'package:venera/foundation/remote_downloads.dart';
import 'package:venera/foundation/remote_download_task.dart';
import 'package:venera/foundation/remote_import.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';

/// Remote-library downloads manager.
///
/// Reaches here from the remote library's appbar download icon. Shows any
/// in-progress downloads (owned by the global [RemoteDownloadManager]) styled
/// like the remote library's list view, with Start / Pause / Cancel controls,
/// and below them every completed download grouped by type (folder / pdf / zip)
/// with open / remove.
///
/// Tasks are **not** owned by this page — they live in the app-lifetime
/// [RemoteDownloadManager], so they keep running in the background after this
/// page is closed and are still here, with live progress, when you return.
///
/// If [initialFile] is supplied (opened via the remote library's
/// "Download & import" menu) a download task for it is created and started
/// immediately.
class RemoteDownloadsPage extends StatefulWidget {
  const RemoteDownloadsPage({super.key, this.initialFile});

  final wd.File? initialFile;

  @override
  State<RemoteDownloadsPage> createState() => _RemoteDownloadsPageState();
}

class _RemoteDownloadsPageState extends State<RemoteDownloadsPage> {
  final RemoteDownloadManager _manager = RemoteDownloadManager.instance;
  bool _startedInitial = false;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChanged);
    RemoteDownloads.countNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    RemoteDownloads.countNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Begin downloading [file] via the manager, unless a task already exists.
  void _startNew(wd.File file) {
    _manager.startDownload(file);
  }

  @override
  Widget build(BuildContext context) {
    // Auto-start the initial file once, after the first frame, so the task is
    // created in the manager and the page rebuilds to show it.
    if (widget.initialFile != null && !_startedInitial) {
      _startedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startNew(widget.initialFile!);
      });
    }

    final active = _manager.activeTasks;
    // Only show the aggregate speed header while at least one task is in the
    // network download phase (importing is local-only, so there is no rate to
    // show). Tasks past the download phase still appear in the active list
    // until their import finishes.
    final anyDownloading = active.any((t) {
      final s = t.state;
      return s == RemoteDownloadState.running ||
          s == RemoteDownloadState.paused;
    });

    return Scaffold(
      appBar: Appbar(
        title: Text('Downloads'.tl),
      ),
      body: SmoothCustomScrollView(
        slivers: [
          // --- Active downloads, styled like the remote library list ---
          if (active.isNotEmpty) ...[
            if (anyDownloading)
              SliverToBoxAdapter(child: _buildSpeedHeader(active)),
            SliverToBoxAdapter(child: _sectionHeader('Downloading'.tl)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildActiveTaskTile(active[i], i, active.length),
                childCount: active.length,
              ),
            ),
          ],
          // --- Completed downloads grouped by type ---
          ..._buildCompletedGroups(active.isNotEmpty),
        ],
      ),
    );
  }

  /// Aggregate speed header: shows the sum of every active task's current
  /// download rate (e.g. "1.23 MB/s") so the user sees total throughput at a
  /// glance. Only built while at least one task is in the network download
  /// phase.
  Widget _buildSpeedHeader(List<RemoteDownloadTask> active) {
    final totalSpeed = _manager.totalSpeed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(LucideIcons.gauge, size: 16),
          const SizedBox(width: 6),
          Text(
            totalSpeed > 0
                ? '${'Download speed'.tl}: ${bytesToReadableString(totalSpeed)}/s'
                : 'Importing'.tl,
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// Active task tile, mirroring the remote library's list tile: a leading
  /// type icon, the file name, a status / progress subtitle, and trailing
  /// Start / Pause / Cancel controls.
  Widget _buildActiveTaskTile(RemoteDownloadTask task, int index, int total) {
    final s = task.state;
    final (IconData icon, Color color) = _typeIcon(task.type);
    // Show "Downloading 40% · 1.2 MB/s" while downloading; fall back to the
    // plain status text for importing / paused / error states.
    final subtitle = s == RemoteDownloadState.running
        ? _taskLabel(task)
        : _statusText(s);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.file.name ?? 'Download'.tl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing controls: Pause while running, Resume/Retry while
              // paused/error, and Cancel unless already finished.
              if (s == RemoteDownloadState.running)
                _iconButton(
                  LucideIcons.circle_pause,
                  'Pause'.tl,
                  task.pause,
                )
              else if (s != RemoteDownloadState.completed &&
                  s != RemoteDownloadState.canceled)
                _iconButton(
                  s == RemoteDownloadState.paused
                      ? LucideIcons.circle_play
                      : LucideIcons.rotate_ccw,
                  s == RemoteDownloadState.paused ? 'Resume'.tl : 'Retry'.tl,
                  task.start,
                ),
              if (s != RemoteDownloadState.completed &&
                  s != RemoteDownloadState.canceled) ...[
                const SizedBox(width: 4),
                _iconButton(LucideIcons.x, 'Cancel'.tl, () => task.cancel()),
              ],
            ],
          ),
        ),
        // Divider between tasks (not after the last one).
        if (index < total - 1)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            endIndent: 16,
            color: context.colorScheme.outlineVariant.withAlpha(80),
          ),
      ],
    );
  }

  /// Per-task status line shown beneath the file name. Combines the phase +
  /// percentage from [RemoteDownloadTask.message] with the current download
  /// rate (e.g. "Downloading 40% · 1.2 MB/s"). The rate is shown only while
  /// there is a meaningful throughput to display.
  String _taskLabel(RemoteDownloadTask task) {
    final base = task.message;
    if (task.speed <= 0) return base;
    return '$base · ${bytesToReadableString(task.speed)}/s';
  }

  Widget _miniButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          textStyle: const TextStyle(fontSize: 12),
          foregroundColor: context.colorScheme.onSurface,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  /// Compact icon button for task controls (pause/resume/retry/cancel).
  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        color: context.colorScheme.onSurface,
      ),
    );
  }

  (IconData, Color) _typeIcon(RemoteFileType type) {
    switch (type) {
      case RemoteFileType.folder:
        return (LucideIcons.folder, context.colorScheme.primary);
      case RemoteFileType.pdf:
        return (LucideIcons.file_text, Colors.red);
      case RemoteFileType.archive:
        return (LucideIcons.file_archive, Colors.orange);
      case RemoteFileType.image:
        return (LucideIcons.file_image, context.colorScheme.outline);
      case RemoteFileType.other:
        return (LucideIcons.file, context.colorScheme.outline);
    }
  }

  String _statusText(RemoteDownloadState s) {
    switch (s) {
      case RemoteDownloadState.running:
        return 'Running'.tl;
      case RemoteDownloadState.paused:
        return 'Paused'.tl;
      case RemoteDownloadState.completed:
        return 'Completed'.tl;
      case RemoteDownloadState.error:
        return 'Error'.tl;
      case RemoteDownloadState.canceled:
        return 'Canceled'.tl;
      case RemoteDownloadState.idle:
        return 'Ready to download'.tl;
    }
  }

  /// Build the completed-download groups (folder / pdf / zip) as a flat list of
  /// slivers. Groups with no entries are skipped; if there are none at all an
  /// empty-state sliver is returned.
  List<Widget> _buildCompletedGroups(bool hasActive) {
    final all = RemoteDownloads.all();
    final folders = all.where((e) => e.type == 'folder').toList();
    final zips = all.where((e) => e.type == 'zip').toList();
    final pdfs = all.where((e) => e.type == 'pdf').toList();

    if (folders.isEmpty && zips.isEmpty && pdfs.isEmpty) {
      if (hasActive) {
        return const [SliverToBoxAdapter(child: SizedBox.shrink())];
      }
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.folder_open,
                    size: 48, color: context.colorScheme.outline),
                const SizedBox(height: 16),
                Text('No downloads yet'.tl,
                    style: TextStyle(color: context.colorScheme.outline)),
              ],
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    void addGroup(String title, List<RemoteDownloadEntry> entries, IconData icon) {
      if (entries.isEmpty) return;
      slivers.add(SliverToBoxAdapter(child: _sectionHeader(title)));
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              _buildCompletedTile(entries[i], icon, i, entries.length),
          childCount: entries.length,
        ),
      ));
    }

    if (hasActive) {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    }
    addGroup('Folders'.tl, folders, LucideIcons.folder);
    addGroup('PDF'.tl, pdfs, LucideIcons.file_text);
    addGroup('Archives'.tl, zips, LucideIcons.file_archive);
    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ),
    );

    return slivers;
  }

  Widget _buildCompletedTile(
      RemoteDownloadEntry e, IconData icon, int index, int total) {
    final color = e.type == 'pdf'
        ? Colors.red
        : e.type == 'zip'
            ? Colors.orange
            : context.colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(icon, color: color),
          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            e.type == 'pdf'
                ? 'PDF'.tl
                : e.type == 'zip'
                    ? 'Archive'.tl
                    : 'Folder'.tl,
            style: TextStyle(color: context.colorScheme.outline, fontSize: 12),
          ),
          onTap: e.comicId != null ? () => _openImported(e) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.comicId != null)
                IconButton(
                  icon: const Icon(LucideIcons.book_open, size: 20),
                  tooltip: 'Open'.tl,
                  onPressed: () => _openImported(e),
                ),
              IconButton(
                icon: const Icon(LucideIcons.trash, size: 20),
                tooltip: 'Remove download'.tl,
                onPressed: () => _removeDownload(e),
              ),
            ],
          ),
        ),
        if (index < total - 1)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            endIndent: 16,
            color: context.colorScheme.outlineVariant.withAlpha(80),
          ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colorScheme.outline,
        ),
      ),
    );
  }

  void _openImported(RemoteDownloadEntry e) {
    if (e.comicId == null) return;
    final localComic = LocalManager().find(e.comicId!, ComicType.local);
    if (localComic == null) {
      context.showMessage(message: 'Local comic not found'.tl);
      return;
    }
    // Directly call [read] instead of routing through ComicPage: [read]
    // detects a PDF backing file and opens the pdfium streaming reader, while
    // ComicPage's local-comic path always lands on the image Reader — which
    // shows nothing for a PDF folder (no image pages, only the .pdf file).
    localComic.read();
  }

  void _removeDownload(RemoteDownloadEntry e) {
    showConfirmDialog(
      context: context,
      title: 'Remove download'.tl,
      content: 'Are you sure you want to remove this download?'.tl,
      onConfirm: () {
        _doRemoveDownload(e);
      },
    );
  }

  void _doRemoveDownload(RemoteDownloadEntry e) {
    if (e.type == 'pdf') {
      if (e.localPath != null) {
        try {
          final f = File(e.localPath!);
          if (f.parent.existsSync()) {
            f.parent.deleteSync(recursive: true);
          } else {
            f.deleteSync();
          }
        } catch (_) {}
      }
      if (e.comicId != null) {
        try {
          LocalManager().remove(e.comicId!, ComicType.local);
        } catch (_) {}
      }
    } else if (e.comicId != null) {
      try {
        LocalManager().remove(e.comicId!, ComicType.local);
      } catch (_) {}
    }
    RemoteDownloads.remove(e.remotePath);
    if (mounted) setState(() {});
  }
}
