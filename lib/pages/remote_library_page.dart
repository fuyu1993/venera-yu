import 'dart:io';
import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/utils/translations.dart';
import 'package:webdav_client/webdav_client.dart' as wd;
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/webdav_image.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/foundation/remote_history_model.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/foundation/pdf/pdf_session.dart';
import 'package:venera/foundation/zip/zip_session.dart';
import 'package:venera/foundation/remote_import.dart';
import 'package:venera/foundation/remote_downloads.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';
import 'package:venera/pages/remote_downloads_page.dart';
import 'package:venera/foundation/local.dart';

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}



/// Cached metadata for a folder: item count and total byte size.
class _FolderInfo {
  final int itemCount;
  final int totalSize;
  const _FolderInfo(this.itemCount, this.totalSize);
}

/// Appbar button that opens the remote downloads page, with a live badge
/// showing how many items have been downloaded.
class _DownloadBadgeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteDownloads.countNotifier,
      builder: (context, count, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.download),
              tooltip: 'Downloads'.tl,
              onPressed: () {
                context.to(() => const RemoteDownloadsPage());
              },
            ),
            if (count > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class RemoteLibraryPage extends StatefulWidget {
  const RemoteLibraryPage({super.key});

  @override
  State<RemoteLibraryPage> createState() => _RemoteLibraryPageState();
}

class _RemoteLibraryPageState extends State<RemoteLibraryPage> {
  final List<String> _pathStack = [RemoteWebDav.root];

  bool _loading = false;

  String? _error;

  List<wd.File> _files = [];

  bool _isGridView = true;

  final Map<String, _FolderInfo> _folderInfo = {};
  bool _loadingFolderInfo = false;

  /// Debounce guard: a fast streak of taps on the same item must not open
  /// multiple readers / sheets / navigations. Set on entry and cleared once
  /// the open/navigation settles (including async downloads), so a
  /// double-tap only ever triggers one action.
  bool _opening = false;

  String get _currentPath => _pathStack.last;

  @override
  void initState() {
    super.initState();
    _isGridView = appdata.settings['remoteLibraryViewMode'] != 'list';
    // Sync the badge notifier with whatever was persisted before this page.
    if (RemoteDownloads.countNotifier.value != RemoteDownloads.count) {
      RemoteDownloads.countNotifier.value = RemoteDownloads.count;
    }
    _load();
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
    appdata.settings['remoteLibraryViewMode'] = _isGridView ? 'grid' : 'list';
    appdata.saveData();
  }



  Future<void> _loadFolderInfo() async {
    if (_loadingFolderInfo) return;
    _loadingFolderInfo = true;
    _folderInfo.clear();
    var folders = _files.where((f) => f.isDir == true).toList();
    for (var folder in folders) {
      if (!mounted) break;
      try {
        var entries = await RemoteWebDav.readDir(folder.path!);
        var count = entries.length;
        var totalSize = 0;
        for (var e in entries) {
          if (e.isDir != true) {
            totalSize += (e.size ?? 0);
          }
        }
        if (mounted) {
          setState(() {
            _folderInfo[folder.path!] = _FolderInfo(count, totalSize);
          });
        }
      } catch (_) {
        // Skip folders that fail to load
      }
    }
    _loadingFolderInfo = false;
  }
  Future<void> _load() async {
    if (!RemoteWebDav.enabled || !RemoteWebDav.isConfigured) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _files = [];
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      var files = await RemoteWebDav.readDir(_currentPath);
      // Sort: folders first, then files, both in natural order so numbered
      // names (e.g. 1, 2, 12) line up by value instead of lexicographically.
      files.sort((a, b) {
        var ad = a.isDir == true;
        var bd = b.isDir == true;
        if (ad != bd) return ad ? -1 : 1;
        return naturalCompare(a.name ?? '', b.name ?? '');
      });
      if (mounted) {
        setState(() {
          _files = files;
          _loading = false;
          _error = null;
        });
        _loadFolderInfo();  // Load folder metadata in background
      }
    } catch (e, s) {
      Log.error('Remote Library', e, s);
      if (mounted) {
        setState(() {
          _error = 'Failed to load remote library'.tl;
          _loading = false;
          _files = [];
        });
      }
    }
  }

  void _navigateTo(String path) {
    _pathStack.add(path);
    _load();
  }

  void _navigateBack() {
    if (_pathStack.length > 1) {
      _pathStack.removeLast();
      _load();
    }
  }

  void _navigateToIndex(int index) {
    if (index < _pathStack.length - 1) {
      _pathStack.removeRange(index + 1, _pathStack.length);
      _load();
    }
  }

  Future<void> _onFolderTap(wd.File folder) async {
    final path = folder.path!;
    // 1) Manually marked as a comic folder (e.g. `manga/chapter/page.png`).
    //    Open it directly — buildChapters turns each sub folder into a chapter.
    if (WebDavComicMarks.isMarked(path)) {
      String? cover;
      try {
        cover = await RemoteWebDav.firstImageKey(path);
      } catch (_) {}
      _openComic(path, folder.name ?? 'Comic'.tl, cover);
      return;
    }
    // Probe the folder to decide: comic (has images) or container (sub folders).
    try {
      var entries = await RemoteWebDav.readDir(path);
      var files = entries.where((e) => e.isDir != true).toList();
      var hasImages = files.any((e) => RemoteWebDav.isImageName(e.name));
      var hasSubDirs = entries.any((e) => e.isDir == true);
      if (hasImages) {
        var firstImage = files
            .firstWhere((e) => RemoteWebDav.isImageName(e.name));
        _openComic(path, folder.name ?? 'Comic'.tl,
            RemoteWebDav.encodeKey(firstImage.path!));
        return;
      }
      // 2) Exactly one comic file (PDF or archive) and no sub folders -> open
      //    it directly instead of drilling in.
      var comicFiles = files
          .where((e) =>
              RemoteWebDav.isPdfName(e.name) ||
              RemoteWebDav.isArchiveName(e.name))
          .toList();
      if (!hasSubDirs && comicFiles.length == 1) {
        final f = comicFiles.first;
        if (RemoteWebDav.isPdfName(f.name)) {
          _openPdfComic(path, f.name ?? 'PDF'.tl, [f]);
        } else {
          _openZipStreaming(f);
        }
        return;
      }
      // 3) Contains sub folders or several comic files -> container, navigate in.
      if (hasSubDirs || comicFiles.isNotEmpty) {
        _navigateTo(path);
        return;
      }
      if (entries.isEmpty) {
        context.showMessage(message: 'Empty folder'.tl);
      } else {
        // The folder has files, but none are readable images (e.g. archives
        // or unsupported extensions). Don't call it "empty".
        context.showMessage(
            message: 'No readable images in this folder'.tl);
      }
    } catch (e) {
      context.showMessage(message: 'Failed to load remote library'.tl);
    }
  }

  /// Long-press / right-click menu for a folder: toggle its "comic" mark so a
  /// nested `manga/chapter/page.png` structure opens directly as one comic.
  void _showFolderMenu(wd.File folder, Offset position) {
    final path = folder.path!;
    final marked = WebDavComicMarks.isMarked(path);
    final entries = <MenuEntry>[
      MenuEntry(
        icon: LucideIcons.bookmark,
        text: marked ? 'Unmark as comic'.tl : 'Mark as comic'.tl,
        onClick: () {
          final next = WebDavComicMarks.toggle(path);
          context.showMessage(
            message: next ? 'Marked as comic'.tl : 'Unmarked as comic'.tl,
          );
          setState(() {});
        },
      ),
    ];
    if (RemoteDownloads.has(path)) {
      entries.add(MenuEntry(
        icon: LucideIcons.folder_open,
        text: 'Open imported'.tl,
        onClick: () => _openImported(path),
      ));
      entries.add(MenuEntry(
        icon: LucideIcons.trash,
        text: 'Remove download'.tl,
        onClick: () => _removeDownload(path),
      ));
    } else {
      entries.add(MenuEntry(
        icon: LucideIcons.download,
        text: 'Download & import'.tl,
        onClick: () => _importItem(folder),
      ));
    }
    showMenuX(context, position, entries);
  }

  /// Long-press menu for a comic file (PDF / ZIP): download & import, or open
  /// / remove a previous download.
  void _showFileMenu(wd.File file, Offset position) {
    final path = file.path!;
    final entries = <MenuEntry>[];
    if (RemoteDownloads.has(path)) {
      if (getFileType(file) == RemoteFileType.pdf) {
        entries.add(MenuEntry(
          icon: LucideIcons.folder_open,
          text: 'Open downloaded'.tl,
          onClick: () => _openImported(path),
        ));
      }
      entries.add(MenuEntry(
        icon: LucideIcons.trash,
        text: 'Remove download'.tl,
        onClick: () => _removeDownload(path),
      ));
    } else {
      entries.add(MenuEntry(
        icon: LucideIcons.download,
        text: 'Download & import'.tl,
        onClick: () => _importItem(file),
      ));
    }
    showMenuX(context, position, entries);
  }

  /// Dispatch the long-press menu to the right handler based on item type.
  void _showItemMenu(wd.File file, Offset position) {
    if (getFileType(file) == RemoteFileType.folder) {
      _showFolderMenu(file, position);
    } else {
      _showFileMenu(file, position);
    }
  }

  bool _isMenuType(RemoteFileType t) =>
      t == RemoteFileType.folder ||
      t == RemoteFileType.pdf ||
      t == RemoteFileType.archive;

  /// Open a previously imported/downloaded item.
  void _openImported(String remotePath) {
    final e = RemoteDownloads.get(remotePath);
    if (e == null || e.comicId == null) return;
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

  /// Delete a downloaded item (local PDF file, or the imported local comic)
  /// and drop its registry record.
  void _removeDownload(String remotePath) {
    final e = RemoteDownloads.get(remotePath);
    if (e == null) return;
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
    RemoteDownloads.remove(remotePath);
    context.showMessage(message: 'Download removed'.tl);
    setState(() {});
  }

  void _openComic(String folderPath, String name, String? coverKey) {
    context.to(() => RemoteReaderWithLoading(
          folderPath: folderPath,
          name: name,
          cover: coverKey,
        ));
  }

  void _openPdfComic(String folderPath, String name, List<wd.File> pdfs) {
    if (pdfs.isEmpty) return;
    final file = pdfs.first;
    context.to(() => RemotePdfReaderWithLoading(
          remotePath: file.path!,
          name: name,
          cover: null,
        ));
  }

  void _onImageTap(wd.File image) {
    _openComic(_currentPath, _folderName(_currentPath),
        RemoteWebDav.encodeKey(image.path!));
  }

  void _onFileTap(wd.File file) {
    if (_opening) return;
    _opening = true;
    _runOpen(file).whenComplete(() {
      if (mounted) _opening = false;
    });
  }

  Future<void> _runOpen(wd.File file) async {
    var type = getFileType(file);
    switch (type) {
      case RemoteFileType.folder:
        await _onFolderTap(file);
        break;
      case RemoteFileType.image:
        _onImageTap(file);
        break;
      case RemoteFileType.archive:
        _openZipStreaming(file);
        break;
      case RemoteFileType.pdf:
        _openPdfComic(_currentPath, file.name ?? 'PDF'.tl, [file]);
        break;
      case RemoteFileType.other:
        _showFileInfo(file, type);
        break;
    }
  }

  /// Open a remote ZIP/CBZ as a streaming comic: each image entry is fetched
  /// and inflated on demand (WebDAV Range), exactly like the PDF streaming
  /// reader. The archive is never downloaded as a whole.
  void _openZipStreaming(wd.File file) {
    context.to(() => RemoteZipReaderWithLoading(
          remotePath: file.path!,
          name: file.name ?? 'Archive'.tl,
          cover: null,
        ));
  }

  /// Open the downloads page for [file]. A global [RemoteDownloadTask] is
  /// created for it and started immediately; progress shows inline on the page
  /// (the former download dialog, now embedded in the downloads page) with
  /// Start / Pause / Cancel controls. The task keeps running in the background
  /// after the page is closed, and is still there with live progress when you
  /// return.
  Future<void> _importItem(wd.File file) async {
    final type = getFileType(file);
    if (type != RemoteFileType.folder &&
        type != RemoteFileType.archive &&
        type != RemoteFileType.pdf) {
      return;
    }
    await context.to(() => RemoteDownloadsPage(initialFile: file));
    if (mounted) setState(() {});
  }

  void _showFileInfo(wd.File file, RemoteFileType type) {
    IconData icon;
    String typeLabel;
    Color color;
    switch (type) {
      case RemoteFileType.pdf:
        icon = LucideIcons.file_text;
        typeLabel = 'PDF'.tl;
        color = Colors.red;
        break;
      case RemoteFileType.archive:
        icon = LucideIcons.file_archive;
        typeLabel = 'Archive'.tl;
        color = Colors.orange;
        break;
      default:
        icon = LucideIcons.file;
        typeLabel = 'File'.tl;
        color = Colors.grey;
        break;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              file.name ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              typeLabel,
              style: TextStyle(
                color: Theme.of(ctx).hintColor,
                fontSize: 14,
              ),
            ),
            if (file.size != null && file.size! > 0) ...[
              const SizedBox(height: 4),
              Text(
                _formatFileSize(file.size),
                style: TextStyle(
                  color: Theme.of(ctx).hintColor,
                  fontSize: 13,
                ),
              ),
            ],
            if (file.mTime != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(file.mTime),
                style: TextStyle(
                  color: Theme.of(ctx).hintColor,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close'.tl),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  String _folderName(String path) {
    if (path == '/' || path.isEmpty) return 'Root';
    var name = path.split('/').where((e) => e.isNotEmpty).last;
    return name.isEmpty ? 'Root' : name;
  }

  List<String> _pathSegments() {
    return _pathStack.map((p) {
      if (p == '/' || p.isEmpty) return 'Root'.tl;
      var segments = p.split('/').where((e) => e.isNotEmpty).toList();
      return segments.isEmpty ? 'Root'.tl : segments.last;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!RemoteWebDav.enabled) {
      return _centeredMessage(
        'Remote library is disabled'.tl,
        'Enable it in Settings -> Lab -> "Enable Remote Library"'.tl,
      );
    }
    if (!RemoteWebDav.isConfigured) {
      return _centeredMessage(
        'WebDAV not configured'.tl,
        'Set the remote WebDAV info in Settings -> Lab -> "Remote Library WebDAV"'.tl,
      );
    }
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: const SizedBox.shrink(),
          actions: [
            _DownloadBadgeButton(),
            IconButton(
              icon: Icon(
                  _isGridView ? LucideIcons.list : LucideIcons.grid_2x2),
              onPressed: _toggleViewMode,
              tooltip:
                  (_isGridView ? 'List View' : 'Grid View').tl,
            ),
            IconButton(
              icon: const Icon(LucideIcons.refresh_cw),
              onPressed: _load,
            ),
          ],
        ),
        // Breadcrumb path
        if (_pathStack.length > 1)
          SliverToBoxAdapter(
            child: _buildBreadcrumb(),
          ),
        // Loading indicator
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        // Error state
        else if (_error != null)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circle_alert,
                      size: 48, color: context.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    child: Text('Retry'.tl),
                  ),
                ],
              ),
            ),
          )
        // Empty state
        else if (_files.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.folder_open,
                      size: 48, color: context.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('Empty'.tl,
                      style: TextStyle(color: context.colorScheme.outline)),
                ],
              ),
            ),
          )
        // Grid view
        else if (_isGridView)
          _buildGridView()
        // List view
        else
          _buildListView(),
      ],
    );
  }

  // --- Breadcrumb ---

  Widget _buildBreadcrumb() {
    var segments = _pathSegments();
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: segments.length,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(LucideIcons.chevron_right,
                    size: 14, color: context.colorScheme.outline),
              ),
              itemBuilder: (context, index) {
                var isLast = index == segments.length - 1;
                return Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: isLast ? null : () => _navigateToIndex(index),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        segments[index],
                        style: TextStyle(
                          fontSize: 13,
                          color: isLast ? null : context.colorScheme.primary,
                          fontWeight: isLast ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(LucideIcons.undo_2, size: 16),
              padding: EdgeInsets.zero,
              tooltip: 'Go up'.tl,
              onPressed: _navigateBack,
            ),
          ),
        ],
      ),
    );
  }

  // --- Grid View ---

  Widget _buildGridView() {
    final width = MediaQuery.of(context).size.width;
    // Compact square grid: ~130px per cell.
    final crossAxisCount = (width / 130).floor().clamp(2, 7);
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridTile(_files[index]),
          childCount: _files.length,
        ),
      ),
    );
  }

  Widget _buildGridTile(wd.File file) {
    var type = getFileType(file);
    final marked = type == RemoteFileType.folder &&
        WebDavComicMarks.isMarked(file.path!);
    final name = file.name ?? '';
    final sub = (type == RemoteFileType.folder &&
            _folderInfo.containsKey(file.path!))
        ? _folderInfoText(file.path!)
        : '';
    return Builder(builder: (context) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onFileTap(file),
        onLongPress: _isMenuType(type)
            ? () {
                final box = context.findRenderObject() as RenderBox;
                final o = box.localToGlobal(Offset.zero);
                _showItemMenu(
                  file,
                  Offset(
                    o.dx + box.size.width / 2,
                    o.dy + box.size.height - 8,
                  ),
                );
              }
            : null,
        onSecondaryTapUp: _isMenuType(type)
            ? (d) => _showItemMenu(file, d.globalPosition)
            : null,
        child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: marked
              ? BorderSide(color: context.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        // The tile itself is a perfect square; the label is overlaid inside
        // (with a scrim) so it does not add height and cause bottom overflow.
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildGridThumbnail(file, type),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    });
  }

  Widget _comicBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.book_open, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text('Comic'.tl,
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        ],
      ),
    );
  }

  /// Short label for an item that has been downloaded/imported locally.
  String _importLabel(RemoteFileType type) =>
      type == RemoteFileType.pdf ? 'Downloaded'.tl : 'Imported'.tl;

  /// Green pill shown on items that have been downloaded/imported locally.
  Widget _importedBadge(RemoteFileType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.check, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(_importLabel(type),
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildGridThumbnail(wd.File file, RemoteFileType type) {
    switch (type) {
      case RemoteFileType.folder:
        final marked = WebDavComicMarks.isMarked(file.path!);
        final imported = RemoteDownloads.has(file.path!);
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: context.colorScheme.primaryContainer.withAlpha(76),
              child: Center(
                child: Icon(LucideIcons.folder,
                    size: 48, color: context.colorScheme.primary),
              ),
            ),
            if (imported)
              Positioned(
                top: 6,
                left: 6,
                child: _importedBadge(RemoteFileType.folder),
              ),
            if (marked)
              Positioned(
                top: 6,
                right: 6,
                child: _comicBadge(),
              ),
          ],
        );
      case RemoteFileType.image:
        return Image(
          image: WebDavImageProvider(
            RemoteWebDav.encodeKey(file.path!),
            'webdav',
            file.path!,
            '',
            0,
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(LucideIcons.file_image,
                size: 32, color: context.colorScheme.outline),
          ),
        );
      case RemoteFileType.pdf:
        final imported = RemoteDownloads.has(file.path!);
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.red.withAlpha(20),
              child: const Center(
                child:
                    Icon(LucideIcons.file_text, size: 48, color: Colors.red),
              ),
            ),
            if (imported)
              Positioned(
                top: 6,
                left: 6,
                child: _importedBadge(RemoteFileType.pdf),
              ),
          ],
        );
      case RemoteFileType.archive:
        final imported = RemoteDownloads.has(file.path!);
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.orange.withAlpha(20),
              child: const Center(
                child: Icon(LucideIcons.file_archive,
                    size: 48, color: Colors.orange),
              ),
            ),
            if (imported)
              Positioned(
                top: 6,
                left: 6,
                child: _importedBadge(RemoteFileType.archive),
              ),
          ],
        );
      case RemoteFileType.other:
        return Container(
          color: context.colorScheme.surfaceContainerHighest.withAlpha(76),
          child: Center(
            child: Icon(LucideIcons.file,
                size: 48, color: context.colorScheme.outline),
          ),
        );
    }
  }

  // --- List View ---

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildListTile(_files[index]),
          childCount: _files.length,
        ),
      ),
    );
  }

  Widget _buildListTile(wd.File file) {
    var type = getFileType(file);
    final marked = type == RemoteFileType.folder &&
        WebDavComicMarks.isMarked(file.path!);
    return Builder(builder: (context) {
      return InkWell(
        onTap: () => _onFileTap(file),
        onLongPress: _isMenuType(type)
            ? () {
                final box = context.findRenderObject() as RenderBox;
                final o = box.localToGlobal(Offset.zero);
                _showItemMenu(
                  file,
                  Offset(
                    o.dx + box.size.width / 2,
                    o.dy + box.size.height - 8,
                  ),
                );
              }
            : null,
        onSecondaryTapUp: _isMenuType(type)
            ? (d) => _showItemMenu(file, d.globalPosition)
            : null,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildListLeading(file, type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (marked) ...[
                        const SizedBox(width: 6),
                        _comicBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSubtitle(file, type),
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
            if (type == RemoteFileType.folder)
              Icon(LucideIcons.chevron_right,
                  size: 18, color: context.colorScheme.outline),
          ],
        ),
      ),
    );
    });
  }

  Widget _buildListLeading(wd.File file, RemoteFileType type) {
    switch (type) {
      case RemoteFileType.folder:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer.withAlpha(76),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(LucideIcons.folder,
              size: 24, color: context.colorScheme.primary),
        );
      case RemoteFileType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Image(
              image: WebDavImageProvider(
                RemoteWebDav.encodeKey(file.path!),
                'webdav',
                file.path!,
                '',
                0,
              ),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: context.colorScheme.surfaceContainerHighest,
                child: Icon(LucideIcons.file_image,
                    size: 24, color: context.colorScheme.outline),
              ),
            ),
          ),
        );
      case RemoteFileType.pdf:
        final imported = RemoteDownloads.has(file.path!);
        return Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.file_text,
                  size: 24, color: Colors.red),
            ),
            if (imported)
              Positioned(
                top: -2,
                left: -2,
                child: _importedBadge(RemoteFileType.pdf),
              ),
          ],
        );
      case RemoteFileType.archive:
        final imported = RemoteDownloads.has(file.path!);
        return Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.file_archive,
                  size: 24, color: Colors.orange),
            ),
            if (imported)
              Positioned(
                top: -2,
                left: -2,
                child: _importedBadge(RemoteFileType.archive),
              ),
          ],
        );
      case RemoteFileType.other:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                context.colorScheme.surfaceContainerHighest.withAlpha(76),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(LucideIcons.file,
              size: 24, color: context.colorScheme.outline),
        );
    }
  }

  String _buildSubtitle(wd.File file, RemoteFileType type) {
    var parts = <String>[];
    if (RemoteDownloads.has(file.path!)) {
      parts.add(_importLabel(type));
    }
    switch (type) {
      case RemoteFileType.folder:
        if (!WebDavComicMarks.isMarked(file.path!)) {
          parts.add('Folder'.tl);
        }
        if (_folderInfo.containsKey(file.path!)) {
          parts.add(_folderInfoText(file.path!));
        }
        break;
      case RemoteFileType.image:
        parts.add('Image'.tl);
        break;
      case RemoteFileType.pdf:
        parts.add('PDF'.tl);
        break;
      case RemoteFileType.archive:
        parts.add('Archive'.tl);
        break;
      case RemoteFileType.other:
        var ext = RemoteWebDav.getFileExtension(file.name);
        parts.add(ext.isEmpty ? 'File'.tl : ext.toUpperCase());
        break;
    }
    var size = _formatFileSize(file.size);
    if (size.isNotEmpty) parts.add(size);
    var date = _formatDate(file.mTime);
    if (date.isNotEmpty) parts.add(date);
    return parts.join(' · ');
  }



  String _folderInfoText(String path) {
    var info = _folderInfo[path];
    if (info == null) return '';
    var parts = <String>[];
    parts.add('${info.itemCount} ${'items'.tl}');
    var size = _formatFileSize(info.totalSize);
    if (size.isNotEmpty) parts.add(size);
    return parts.join(' · ');
  }
  // --- Centered message for disabled/unconfigured states ---

  Widget _centeredMessage(String title, String subtitle) {
    return SmoothCustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Loads the chapters of a remote WebDAV folder and launches the reader.
class RemoteReaderWithLoading extends StatefulWidget {
  final String folderPath;

  final String name;

  final String? cover;

  const RemoteReaderWithLoading({
    super.key,
    required this.folderPath,
    required this.name,
    this.cover,
  });

  @override
  State<RemoteReaderWithLoading> createState() =>
      _RemoteReaderWithLoadingState();
}

class _RemoteReaderWithLoadingState
    extends LoadingState<RemoteReaderWithLoading, ReaderProps> {
  @override
  Widget buildContent(BuildContext context, ReaderProps data) {
    return Reader(
      type: data.type,
      cid: data.cid,
      name: data.name,
      chapters: data.chapters,
      history: data.history,
      initialChapter: data.history.ep,
      initialPage: data.history.page,
      initialChapterGroup: data.history.group,
      author: data.author,
      tags: data.tags,
    );
  }

  @override
  Future<Res<ReaderProps>> loadData() async {
    Map<String, String> map;
    try {
      map = await RemoteWebDav.buildChapters(widget.folderPath);
    } catch (e, s) {
      Log.error('Remote Library', e, s);
      return Res.error('Failed to load remote library'.tl);
    }
    if (map.isEmpty) {
      return Res.error('No readable images in this folder'.tl);
    }
    var chapters = ComicChapters(map);
    var history = HistoryManager().find(widget.folderPath, ComicType.webdav) ??
        History.fromModel(
          model: RemoteHistoryModel(
            widget.folderPath,
            widget.name,
            widget.cover ?? '',
          ),
          ep: 0,
          page: 0,
        );
    return Res(
      ReaderProps(
        type: ComicType.webdav,
        cid: widget.folderPath,
        name: widget.name,
        chapters: chapters,
        history: history,
        author: '',
        tags: const [],
      ),
    );
  }
}

/// Opens a PDF as a comic: renders each page to an image on demand and feeds
/// it to the built-in comic reader (paged/continuous modes, gestures, history
/// — the full reading experience).
///
/// - Remote PDFs are streamed via WebDAV Range requests, so multi-GB files
///   start reading almost immediately.
/// - Downloaded PDFs (imported from the remote library) are read from the
///   local file via [localPath], offline, with the same streaming renderer.
class RemotePdfReaderWithLoading extends StatefulWidget {
  final String? remotePath;

  /// When set, the PDF is read from a local file (offline imported copy).
  final String? localPath;

  final String name;

  final String? cover;

  const RemotePdfReaderWithLoading({
    super.key,
    this.remotePath,
    this.localPath,
    required this.name,
    this.cover,
  });

  @override
  State<RemotePdfReaderWithLoading> createState() =>
      _RemotePdfReaderWithLoadingState();
}

class _RemotePdfReaderWithLoadingState
    extends LoadingState<RemotePdfReaderWithLoading, ReaderProps> {
  bool _sessionOpened = false;

  /// The session key (also the reader `cid`): local file path when offline,
  /// otherwise the remote path.
  late final String _cid = widget.localPath ?? widget.remotePath!;

  @override
  Widget buildContent(BuildContext context, ReaderProps data) {
    return Reader(
      type: data.type,
      cid: data.cid,
      name: data.name,
      chapters: data.chapters,
      history: data.history,
      initialChapter: data.history.ep,
      initialPage: data.history.page,
      initialChapterGroup: data.history.group,
      author: data.author,
      tags: data.tags,
    );
  }

  @override
  Future<Res<ReaderProps>> loadData() async {
    try {
      if (widget.localPath != null) {
        await PdfSessionManager().openLocal(
          sessionKey: widget.localPath!,
          localPath: widget.localPath!,
        );
      } else {
        await PdfSessionManager().open(
          sessionKey: widget.remotePath!,
          remotePath: widget.remotePath!,
        );
      }
      _sessionOpened = true;
    } catch (e, s) {
      Log.error('Remote PDF', e, s);
      return Res.error('Failed to load'.tl);
    }
    var history = HistoryManager().find(_cid, ComicType.pdf) ??
        History.fromModel(
          model: RemoteHistoryModel(
            _cid,
            widget.name,
            widget.cover ?? '',
            ComicType.pdf,
          ),
          ep: 0,
          page: 0,
        );
    return Res(
      ReaderProps(
        type: ComicType.pdf,
        cid: _cid,
        name: widget.name,
        chapters: null,
        history: history,
        author: '',
        tags: const [],
      ),
    );
  }

  @override
  void dispose() {
    if (_sessionOpened) {
      // Fire-and-forget close: releases the pdfium document, the local sparse
      // cache file and the rendered-page PNG cache.
      PdfSessionManager().close(_cid);
    }
    super.dispose();
  }
}

/// Opens a remote ZIP/CBZ as a comic: each image entry is fetched and
/// inflated on demand (WebDAV Range), exactly like the PDF streaming reader —
/// the archive is never downloaded as a whole.
class RemoteZipReaderWithLoading extends StatefulWidget {
  final String remotePath;

  final String name;

  final String? cover;

  const RemoteZipReaderWithLoading({
    super.key,
    required this.remotePath,
    required this.name,
    this.cover,
  });

  @override
  State<RemoteZipReaderWithLoading> createState() =>
      _RemoteZipReaderWithLoadingState();
}

class _RemoteZipReaderWithLoadingState
    extends LoadingState<RemoteZipReaderWithLoading, ReaderProps> {
  bool _sessionOpened = false;

  @override
  Widget buildContent(BuildContext context, ReaderProps data) {
    return Reader(
      type: data.type,
      cid: data.cid,
      name: data.name,
      chapters: data.chapters,
      history: data.history,
      initialChapter: data.history.ep,
      initialPage: data.history.page,
      initialChapterGroup: data.history.group,
      author: data.author,
      tags: data.tags,
    );
  }

  @override
  Future<Res<ReaderProps>> loadData() async {
    try {
      await ZipSessionManager().open(
        sessionKey: widget.remotePath,
        remotePath: widget.remotePath,
      );
      _sessionOpened = true;
    } catch (e, s) {
      Log.error('Remote ZIP', e, s);
      return Res.error('Failed to load'.tl);
    }
    var history =
        HistoryManager().find(widget.remotePath, ComicType.zip) ??
            History.fromModel(
              model: RemoteHistoryModel(
                widget.remotePath,
                widget.name,
                widget.cover ?? '',
                ComicType.zip,
              ),
              ep: 0,
              page: 0,
            );
    return Res(
      ReaderProps(
        type: ComicType.zip,
        cid: widget.remotePath,
        name: widget.name,
        chapters: null,
        history: history,
        author: '',
        tags: const [],
      ),
    );
  }

  @override
  void dispose() {
    if (_sessionOpened) {
      ZipSessionManager().close(widget.remotePath);
    }
    super.dispose();
  }
}
