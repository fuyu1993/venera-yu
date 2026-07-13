import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/context.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/utils/translations.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/webdav_image.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/pages/reader/reader.dart';

class RemoteLibraryPage extends StatefulWidget {
  const RemoteLibraryPage({super.key});

  @override
  State<RemoteLibraryPage> createState() => _RemoteLibraryPageState();
}

class _RemoteLibraryPageState extends State<RemoteLibraryPage> {
  final List<String> _pathStack = [RemoteWebDav.root];

  bool _loading = false;

  String? _error;

  List<File> _files = [];

  String get _currentPath => _pathStack.last;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _onFolderTap(File folder) async {
    // Probe the folder to decide: comic (has images) or category (sub folders).
    try {
      var entries = await RemoteWebDav.readDir(folder.path!);
      var hasImages =
          entries.any((e) => e.isDir != true && RemoteWebDav.isImageName(e.name));
      var hasSubDirs = entries.any((e) => e.isDir == true);
      if (hasImages) {
        var firstImage = entries
            .where((e) => e.isDir != true && RemoteWebDav.isImageName(e.name))
            .first;
        _openComic(folder.path!, folder.name ?? 'Comic',
            RemoteWebDav.encodeKey(firstImage.path!));
      } else if (hasSubDirs) {
        _navigateTo(folder.path!);
      } else {
        context.showMessage(message: 'Empty folder'.tl);
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

  void _onImageTap(File image) {
    // Open the parent folder as a comic; the reader loads its images.
    _openComic(_currentPath, _folderName(_currentPath),
        RemoteWebDav.encodeKey(image.path!));
  }

  String _folderName(String path) {
    if (path == '/' || path.isEmpty) return 'Root';
    var name = path.split('/').where((e) => e.isNotEmpty).last;
    return name.isEmpty ? 'Root' : name;
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
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _currentPath,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: SelectableText(_error!),
              ),
            ),
          )
        else if (_files.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Empty'.tl)),
            ),
          )
        else
          SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildTile(_files[index]),
              childCount: _files.length,
            ),
          ),
      ],
    );
  }

  Widget _buildTile(File file) {
    var isDir = file.isDir == true;
    return InkWell(
      onTap: () {
        if (isDir) {
          _onFolderTap(file);
        } else {
          _onImageTap(file);
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isDir
                  ? const Center(
                      child: Icon(LucideIcons.folder, size: 48),
                    )
                  : Image(
                      image: WebDavImageProvider(
                        RemoteWebDav.encodeKey(file.path!),
                        'webdav',
                        file.path!,
                        '',
                        0,
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(LucideIcons.file),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                file.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
  State<RemoteReaderWithLoading> createState() => _RemoteReaderWithLoadingState();
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
