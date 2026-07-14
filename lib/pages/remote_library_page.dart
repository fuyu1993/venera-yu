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
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/pages/remote_pdf_comic_page.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/foundation/local.dart';

/// File type classification for remote files.
enum _RemoteFileType { folder, image, pdf, archive, other }

_RemoteFileType _getFileType(wd.File file) {
  if (file.isDir == true) return _RemoteFileType.folder;
  if (RemoteWebDav.isImageName(file.name)) return _RemoteFileType.image;
  if (RemoteWebDav.isPdfName(file.name)) return _RemoteFileType.pdf;
  if (RemoteWebDav.isArchiveName(file.name)) return _RemoteFileType.archive;
  return _RemoteFileType.other;
}

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

  String get _currentPath => _pathStack.last;

  @override
  void initState() {
    super.initState();
    _isGridView = appdata.settings['remoteLibraryViewMode'] != 'list';
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
      // Sort: folders first, then files, both alphabetical.
      files.sort((a, b) {
        var ad = a.isDir == true;
        var bd = b.isDir == true;
        if (ad != bd) return ad ? -1 : 1;
        return (a.name ?? '').compareTo(b.name ?? '');
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
    // Probe the folder to decide: comic (has images) or category (sub folders).
    try {
      var entries = await RemoteWebDav.readDir(folder.path!);
      var files = entries.where((e) => e.isDir != true).toList();
      var hasImages = files.any((e) => RemoteWebDav.isImageName(e.name));
      var hasSubDirs = entries.any((e) => e.isDir == true);
      var pdfFiles = files.where((e) => RemoteWebDav.isPdfName(e.name)).toList();
      if (hasImages) {
        var firstImage = files
            .firstWhere((e) => RemoteWebDav.isImageName(e.name));
        _openComic(folder.path!, folder.name ?? 'Comic'.tl,
            RemoteWebDav.encodeKey(firstImage.path!));
      } else if (hasSubDirs) {
        _navigateTo(folder.path!);
      } else if (pdfFiles.isNotEmpty) {
        // A folder of PDF files: treat each PDF as a chapter.
        _openPdfComic(folder.path!, folder.name ?? 'Comic'.tl, pdfFiles);
      } else if (entries.isEmpty) {
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

  void _openComic(String folderPath, String name, String? coverKey) {
    context.to(() => RemoteReaderWithLoading(
          folderPath: folderPath,
          name: name,
          cover: coverKey,
        ));
  }

  void _openPdfComic(String folderPath, String name, List<wd.File> pdfs) {
    context.to(() => RemotePdfComicPage(
          folderPath: folderPath,
          name: name,
          pdfs: pdfs,
        ));
  }

  void _onImageTap(wd.File image) {
    _openComic(_currentPath, _folderName(_currentPath),
        RemoteWebDav.encodeKey(image.path!));
  }

  void _onFileTap(wd.File file) {
    var type = _getFileType(file);
    switch (type) {
      case _RemoteFileType.folder:
        _onFolderTap(file);
        break;
      case _RemoteFileType.image:
        _onImageTap(file);
        break;
      case _RemoteFileType.archive:
        _openArchive(file);
        break;
      case _RemoteFileType.pdf:
        _openPdfComic(_currentPath, file.name ?? 'PDF'.tl, [file]);
        break;
      case _RemoteFileType.other:
        _showFileInfo(file, type);
        break;
    }
  }

  Future<void> _openArchive(wd.File file) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 16),
              Text('Opening archive'.tl),
            ],
          ),
        ),
      ),
    );
    try {
      // Download zip from WebDAV
      var bytes = await RemoteWebDav.readFile(file.path!);
      // Write to temp file
      var ext = RemoteWebDav.getFileExtension(file.name);
      var tempDir = Directory('${App.cachePath}/remote_zip');
      if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
      var tempFile = File('${tempDir.path}/${file.name ?? "archive.$ext"}');
      await tempFile.writeAsBytes(bytes);
      // Import as local comic
      var comic = await CBZ.import(tempFile);
      var id = LocalManager().findValidId(ComicType.local);
      LocalManager().add(comic, id);
      // Clean up temp file
      try {
        if (tempFile.existsSync()) tempFile.deleteSync();
      } catch (_) {}
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        context.to(() => ComicPage(
              id: id,
              sourceKey: comic.sourceKey,
              cover: comic.cover,
              title: comic.title,
            ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        context.showMessage(
            message: '${'Failed to open archive'.tl}: ${e.toString()}');
      }
    }
  }

  void _showFileInfo(wd.File file, _RemoteFileType type) {
    IconData icon;
    String typeLabel;
    Color color;
    switch (type) {
      case _RemoteFileType.pdf:
        icon = LucideIcons.file_text;
        typeLabel = 'PDF'.tl;
        color = Colors.red;
        break;
      case _RemoteFileType.archive:
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
          title: Text('Remote Library'.tl),
          leading: _pathStack.length > 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                )
              : null,
          actions: [
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
    var type = _getFileType(file);
    final name = file.name ?? '';
    final sub = (type == _RemoteFileType.folder &&
            _folderInfo.containsKey(file.path!))
        ? _folderInfoText(file.path!)
        : '';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onFileTap(file),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }

  Widget _buildGridThumbnail(wd.File file, _RemoteFileType type) {
    switch (type) {
      case _RemoteFileType.folder:
        return Container(
          color: context.colorScheme.primaryContainer.withAlpha(76),
          child: Center(
            child: Icon(LucideIcons.folder,
                size: 48, color: context.colorScheme.primary),
          ),
        );
      case _RemoteFileType.image:
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
      case _RemoteFileType.pdf:
        return Container(
          color: Colors.red.withAlpha(20),
          child: const Center(
            child:
                Icon(LucideIcons.file_text, size: 48, color: Colors.red),
          ),
        );
      case _RemoteFileType.archive:
        return Container(
          color: Colors.orange.withAlpha(20),
          child: const Center(
            child: Icon(LucideIcons.file_archive,
                size: 48, color: Colors.orange),
          ),
        );
      case _RemoteFileType.other:
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
    var type = _getFileType(file);
    return InkWell(
      onTap: () => _onFileTap(file),
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
                  Text(
                    file.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
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
            if (type == _RemoteFileType.folder)
              Icon(LucideIcons.chevron_right,
                  size: 18, color: context.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildListLeading(wd.File file, _RemoteFileType type) {
    switch (type) {
      case _RemoteFileType.folder:
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
      case _RemoteFileType.image:
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
      case _RemoteFileType.pdf:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              const Icon(LucideIcons.file_text, size: 24, color: Colors.red),
        );
      case _RemoteFileType.archive:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.file_archive,
              size: 24, color: Colors.orange),
        );
      case _RemoteFileType.other:
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

  String _buildSubtitle(wd.File file, _RemoteFileType type) {
    var parts = <String>[];
    switch (type) {
      case _RemoteFileType.folder:
        parts.add('Folder'.tl);
        if (_folderInfo.containsKey(file.path!)) {
          parts.add(_folderInfoText(file.path!));
        }
        break;
      case _RemoteFileType.image:
        parts.add('Image'.tl);
        break;
      case _RemoteFileType.pdf:
        parts.add('PDF'.tl);
        break;
      case _RemoteFileType.archive:
        parts.add('Archive'.tl);
        break;
      case _RemoteFileType.other:
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
        SliverAppbar(title: Text('Remote Library'.tl)),
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

/// Minimal history model used to seed a [History] for a remote comic.
class _RemoteHistoryModel with HistoryMixin {
  @override
  final String title;

  @override
  final String id;

  @override
  final String cover;

  @override
  String? get subTitle => null;

  @override
  ComicType get historyType => ComicType.webdav;

  _RemoteHistoryModel(this.id, this.title, this.cover);
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
          model: _RemoteHistoryModel(
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
