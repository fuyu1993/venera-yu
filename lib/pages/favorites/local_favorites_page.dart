part of 'favorites_page.dart';

const _localAllFolderLabel = '^_^[%local_all%]^_^';

/// If the number of comics in a folder exceeds this limit, it will be
/// fetched asynchronously.
const _asyncDataFetchLimit = 500;

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.folder, super.key});

  final String folder;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage> {
  late _FavoritesPageState favPage;

  late List<FavoriteItem> comics;

  String? networkSource;
  String? networkFolder;

  Map<Comic, bool> selectedComics = {};

  var selectedLocalFolders = <String>{};

  late List<String> added = [];

  String keyword = "";
  bool searchHasUpper = false;

  bool searchMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  bool get isAllFolder => widget.folder == _localAllFolderLabel;

  LocalFavoritesManager get manager => LocalFavoritesManager();

  bool isLoading = false;

  late String readFilterSelect;

  var searchResults = <FavoriteItem>[];

  void updateSearchResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = comics;
      } else {
        searchResults = [];
        for (var comic in comics) {
          if (matchKeyword(keyword, comic) ||
              matchKeywordT(keyword, comic) ||
              matchKeywordS(keyword, comic)) {
            searchResults.add(comic);
          }
        }
      }
    });
  }

  void updateComics() {
    if (isLoading) return;
    if (isAllFolder) {
      var totalComics = manager.totalComics;
      if (totalComics < _asyncDataFetchLimit) {
        comics = manager.getAllComics();
      } else {
        isLoading = true;
        manager
            .getAllComicsAsync()
            .minTime(const Duration(milliseconds: 200))
            .then((value) {
          if (mounted) {
            setState(() {
              isLoading = false;
              comics = value;
            });
          }
        });
      }
    } else {
      var folderComics = manager.folderComics(widget.folder);
      if (folderComics < _asyncDataFetchLimit) {
        comics = manager.getFolderComics(widget.folder);
      } else {
        isLoading = true;
        manager
            .getFolderComicsAsync(widget.folder)
            .minTime(const Duration(milliseconds: 200))
            .then((value) {
          if (mounted) {
            setState(() {
              isLoading = false;
              comics = value;
            });
          }
        });
      }
    }
    setState(() {});
  }

  List<FavoriteItem> filterComics(List<FavoriteItem> curComics) {
    return curComics.where((comic) {
      var history =
          HistoryManager().find(comic.id, ComicType(comic.sourceKey.hashCode));
      if (readFilterSelect == "UnCompleted") {
        return history == null || history.page != history.maxPage;
      } else if (readFilterSelect == "Completed") {
        return history != null && history.page == history.maxPage;
      }
      return true;
    }).toList();
  }

  bool matchKeyword(String keyword, FavoriteItem comic) {
    var list = keyword.split(" ");
    for (var k in list) {
      if (k.isEmpty) continue;
      if (checkKeyWordMatch(k, comic.title, false)) {
        continue;
      } else if (comic.subtitle != null && checkKeyWordMatch(k, comic.subtitle!, false)) {
        continue;
      } else if (comic.tags.any((tag) {
        if (checkKeyWordMatch(k, tag, true)) {
          return true;
        } else if (tag.contains(':') && checkKeyWordMatch(k, tag.split(':')[1], true)) {
          return true;
        } else if (App.locale.languageCode != 'en' &&
            checkKeyWordMatch(k, tag.translateTagsToCN, true)) {
          return true;
        }
        return false;
      })) {
        continue;
      } else if (checkKeyWordMatch(k, comic.author, true)) {
        continue;
      }
      return false;
    }
    return true;
  }

  bool checkKeyWordMatch(String keyword, String compare, bool needEqual) {
    String temp = compare;
    // 没有大写的话, 就转成小写比较, 避免搜索需要注意大小写
    if (!searchHasUpper) {
      temp = temp.toLowerCase();
    }
    if (needEqual) {
      return  keyword == temp;
    }
    return temp.contains(keyword);
  }
  // Convert keyword to traditional Chinese to match comics
  bool matchKeywordT(String keyword, FavoriteItem comic) {
    if (!OpenCC.hasChineseSimplified(keyword)) {
      return false;
    }
    keyword = OpenCC.simplifiedToTraditional(keyword);
    return matchKeyword(keyword, comic);
  }

  // Convert keyword to simplified Chinese to match comics
  bool matchKeywordS(String keyword, FavoriteItem comic) {
    if (!OpenCC.hasChineseTraditional(keyword)) {
      return false;
    }
    keyword = OpenCC.traditionalToSimplified(keyword);
    return matchKeyword(keyword, comic);
  }
  @override
  void initState() {
    readFilterSelect = appdata.implicitData["local_favorites_read_filter"] ??
        readFilterList[0];
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    if (!isAllFolder) {
      var (a, b) = LocalFavoritesManager().findLinked(widget.folder);
      networkSource = a;
      networkFolder = b;
    } else {
      networkSource = null;
      networkFolder = null;
    }
    comics = [];
    updateComics();
    LocalFavoritesManager().addListener(updateComics);
    App.viewModeNotifier.addListener(_onViewModeChanged);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    LocalFavoritesManager().removeListener(updateComics);
    App.viewModeNotifier.removeListener(_onViewModeChanged);
  }

  void _onViewModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void selectAll() {
    setState(() {
      if (searchMode) {
        selectedComics = searchResults.asMap().map((k, v) => MapEntry(v, true));
      } else {
        selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
      }
    });
  }

  void invertSelection() {
    setState(() {
      if (searchMode) {
        for (var c in searchResults) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      } else {
        for (var c in comics) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      }
    });
  }

  bool downloadComic(FavoriteItem c) {
    var source = c.type.comicSource;
    if (source != null) {
      bool isDownloaded = LocalManager().isDownloaded(
        c.id,
        (c).type,
      );
      if (isDownloaded) {
        return false;
      }
      LocalManager().addTask(ImagesDownloadTask(
        source: source,
        comicId: c.id,
        comicTitle: c.title,
      ));
      return true;
    }
    return false;
  }

  void downloadSelected() {
    int count = 0;
    for (var c in selectedComics.keys) {
      if (downloadComic(c as FavoriteItem)) {
        count++;
      }
    }
    if (count > 0) {
      context.showMessage(
        message: "Added @c comics to download queue.".tlParams({"c": count}),
      );
    }
  }

  var scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    var title = favPage.folder ?? "Unselected".tl;
    if (title == _localAllFolderLabel) {
      title = "All".tl;
    }

    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        if (!searchMode && !multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Folders".tl,
              child: context.width <= _kTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(LucideIcons.menu),
                      color: context.colorScheme.primary,
                      onPressed: favPage.showFolderSelector,
                    )
                  : const SizedBox(),
            ),
            title: GestureDetector(
              onTap: context.width < _kTwoPanelChangeWidth
                  ? favPage.showFolderSelector
                  : null,
              child: Text(title),
            ),
            actions: [
              if (networkSource != null && !isAllFolder)
                Tooltip(
                  message: "Sync".tl,
                  child: Flyout(
                    flyoutBuilder: (context) {
                      final GlobalKey<_SelectUpdatePageNumState>
                          selectUpdatePageNumKey =
                          GlobalKey<_SelectUpdatePageNumState>();
                      var updatePageWidget = _SelectUpdatePageNum(
                        networkSource: networkSource!,
                        networkFolder: networkFolder,
                        key: selectUpdatePageNumKey,
                      );
                      return FlyoutContent(
                        title: "Sync".tl,
                        content: updatePageWidget,
                        actions: [
                          Button.filled(
                            child: Text("Update".tl),
                            onPressed: () {
                              context.pop();
                              importNetworkFolder(
                                networkSource!,
                                selectUpdatePageNumKey
                                    .currentState!.updatePageNum,
                                widget.folder,
                                networkFolder!,
                              ).then(
                                (value) {
                                  updateComics();
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                    child: Builder(builder: (context) {
                      return IconButton(
                        icon: const Icon(LucideIcons.refresh_ccw),
                        onPressed: () {
                          Flyout.of(context).show();
                        },
                      );
                    }),
                  ),
                ),
              // Filter and Search moved to unified ComicsToolbar below
              if (!isAllFolder)
                MenuButton(
                  entries: [
                    MenuEntry(
                      icon: LucideIcons.square_pen,
                      text: "Rename".tl,
                      onClick: () {
                        showInputDialog(
                          context: App.rootContext,
                          title: "Rename".tl,
                          hintText: "New Name".tl,
                          onConfirm: (value) {
                            var err = validateFolderName(value.toString());
                            if (err != null) {
                              return err;
                            }
                            LocalFavoritesManager().rename(
                              widget.folder,
                              value.toString(),
                            );
                            favPage.folderList?.updateFolders();
                            favPage.setFolder(false, value.toString());
                            return null;
                          },
                        );
                      },
                    ),
                    MenuEntry(
                      icon: LucideIcons.arrow_down_up,
                      text: "Reorder".tl,
                      onClick: () {
                        context.to(
                          () {
                            return _ReorderComicsPage(
                              widget.folder,
                              (comics) {
                                this.comics = comics;
                              },
                            );
                          },
                        ).then(
                          (value) {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                    MenuEntry(
                      icon: LucideIcons.cloud_upload,
                      text: "Export".tl,
                      onClick: () {
                        var json = LocalFavoritesManager().folderToJson(
                          widget.folder,
                        );
                        saveFile(
                          data: utf8.encode(json),
                          filename: "${widget.folder}.json",
                        );
                      },
                    ),
                    MenuEntry(
                      icon: LucideIcons.refresh_ccw,
                      text: "Update Comics Info".tl,
                      onClick: () {
                        updateComicsInfo(widget.folder).then((newComics) {
                          if (mounted) {
                            setState(() {
                              comics = newComics;
                            });
                          }
                        });
                      },
                    ),
                    MenuEntry(
                      icon: LucideIcons.trash,
                      text: "Delete Folder".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: App.rootContext,
                          title: "Delete".tl,
                          content: "Delete folder '@f' ?".tlParams({
                            "f": widget.folder,
                          }),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            favPage.setFolder(false, _localAllFolderLabel);
                            LocalFavoritesManager().deleteFolder(widget.folder);
                            favPage.folderList?.updateFolders();
                          },
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        // Unified comics toolbar (Sort + Filter + View Mode + Search)
        if (!searchMode && !multiSelectMode)
          SliverToBoxAdapter(
            child: ComicsToolbar(
              onFilterTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return _LocalFavoritesFilterDialog(
                      initReadFilterSelect: readFilterSelect,
                      updateConfig: (readFilter) {
                        setState(() {
                          readFilterSelect = readFilter;
                        });
                        updateComics();
                      },
                    );
                  },
                );
              },
              filterActive: readFilterSelect != readFilterList[0],
              onSearchTap: () {
                setState(() {
                  keyword = "";
                  searchMode = true;
                  updateSearchResult();
                });
              },
            ),
          ),
        if (multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedComics.clear();
                  });
                },
              ),
            ),
            title: Text(
                "Selected @c comics".tlParams({"c": selectedComics.length})),
            actions: [
              MenuButton(entries: [
                if (!isAllFolder)
                  MenuEntry(
                      icon: LucideIcons.arrow_up_from_line,
                      text: "Move to folder".tl,
                      onClick: () => favoriteOption('move')),
                if (!isAllFolder)
                  MenuEntry(
                      icon: LucideIcons.copy,
                      text: "Copy to folder".tl,
                      onClick: () => favoriteOption('add')),
                MenuEntry(
                    icon: LucideIcons.square_check,
                    text: "Select All".tl,
                    onClick: selectAll),
                MenuEntry(
                    icon: LucideIcons.x,
                    text: "Deselect".tl,
                    onClick: _cancel),
                MenuEntry(
                    icon: LucideIcons.flip_horizontal_2,
                    text: "Invert Selection".tl,
                    onClick: invertSelection),
                if (!isAllFolder)
                  MenuEntry(
                      icon: LucideIcons.trash,
                      text: "Delete Comic".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: context,
                          title: "Delete".tl,
                          content: "Delete @c comics?"
                              .tlParams({"c": selectedComics.length}),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            _deleteComicWithId();
                          },
                        );
                      }),
                MenuEntry(
                  icon: LucideIcons.download,
                  text: "Download".tl,
                  onClick: downloadSelected,
                ),
                if (selectedComics.length == 1)
                  MenuEntry(
                    icon: LucideIcons.copy,
                    text: "Copy Title".tl,
                    onClick: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: selectedComics.keys.first.title,
                        ),
                      );
                      context.showMessage(
                        message: "Copied".tl,
                      );
                    },
                  ),
                if (selectedComics.length == 1)
                  MenuEntry(
                    icon: LucideIcons.list,
                    text: "Read".tl,
                    onClick: () {
                      final c = selectedComics.keys.first as FavoriteItem;
                      App.rootContext.to(() => ReaderWithLoading(
                            id: c.id,
                            sourceKey: c.sourceKey,
                          )
                      );
                    },
                  ),
                if (selectedComics.length == 1)
                  MenuEntry(
                    icon: LucideIcons.chevron_right,
                    text: "Jump to Detail".tl,
                    onClick: () {
                      final c = selectedComics.keys.first as FavoriteItem;
                      App.mainNavigatorKey?.currentContext?.to(() => ComicPage(
                            id: c.id,
                            sourceKey: c.sourceKey,
                          )
                      );
                    },
                  ),
              ]),
            ],
          )
        else if (searchMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () {
                  setState(() {
                    setState(() {
                      searchMode = false;
                    });
                  });
                },
              ),
            ),
            title: SizedBox(
              height: 48,
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search".tl,
                  border: UnderlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (v) {
                  keyword = v;
                  searchHasUpper = keyword.contains(RegExp(r'[A-Z]'));
                  updateSearchResult();
                },
              ),
            ).paddingBottom(8).paddingRight(8),
          ),
        if (isLoading)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else
          SliverGridComics(
            comics: searchMode ? searchResults : filterComics(comics),
            selections: selectedComics,
            timeBuilder: (c) {
              final item = c as FavoriteItem;
              return HistoryManager.formatBrowseTime(
                HistoryManager().find(item.id, item.type)?.time,
              );
            },
            menuBuilder: (c) {
              return [
                if (!isAllFolder)
                  MenuEntry(
                    icon: LucideIcons.trash,
                    text: "Delete".tl,
                    onClick: () {
                      LocalFavoritesManager().deleteComicWithId(
                        widget.folder,
                        c.id,
                        (c as FavoriteItem).type,
                      );
                    },
                  ),
                MenuEntry(
                  icon: LucideIcons.check,
                  text: "Select".tl,
                  onClick: () {
                    setState(() {
                      if (!multiSelectMode) {
                        multiSelectMode = true;
                      }
                      if (selectedComics.containsKey(c as FavoriteItem)) {
                        selectedComics.remove(c);
                        _checkExitSelectMode();
                      } else {
                        selectedComics[c] = true;
                      }
                      lastSelectedIndex = comics.indexOf(c);
                    });
                  },
                ),
                MenuEntry(
                  icon: LucideIcons.download,
                  text: "Download".tl,
                  onClick: () {
                    downloadComic(c as FavoriteItem);
                    context.showMessage(
                      message: "Download started".tl,
                    );
                  },
                ),
                if (appdata.settings["onClickFavorite"] == "viewDetail")
                  MenuEntry(
                    icon: LucideIcons.book_open,
                    text: "Read".tl,
                    onClick: () {
                      _readFavorite(c as FavoriteItem);
                    },
                  ),
              ];
            },
            onTap: (c, heroID) {
              if (multiSelectMode) {
                setState(() {
                  if (selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics.remove(c);
                    _checkExitSelectMode();
                  } else {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = comics.indexOf(c);
                });
              } else {
                _openFavorite(c as FavoriteItem, heroID);
              }
            },
            onLongPressed: (c, heroID) {
              setState(() {
                if (!multiSelectMode) {
                  multiSelectMode = true;
                  if (!selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = comics.indexOf(c);
                } else {
                  if (lastSelectedIndex != null) {
                    int start = lastSelectedIndex!;
                    int end = comics.indexOf(c as FavoriteItem);
                    if (start > end) {
                      int temp = start;
                      start = end;
                      end = temp;
                    }

                    for (int i = start; i <= end; i++) {
                      if (i == lastSelectedIndex) continue;

                      var comic = comics[i];
                      if (selectedComics.containsKey(comic)) {
                        selectedComics.remove(comic);
                      } else {
                        selectedComics[comic] = true;
                      }
                    }
                  }
                  lastSelectedIndex = comics.indexOf(c as FavoriteItem);
                }
                _checkExitSelectMode();
              });
            },
          ),
      ],
    );
    body = AppScrollBar(
      topPadding: 48,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            updateComics();
          });
        }
      },
      child: body,
    );
  }

  void favoriteOption(String option) {
    var targetFolders = LocalFavoritesManager()
        .folderNames
        .where((folder) => folder != favPage.folder)
        .toList();

    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(
        builder: (context, setState) {
          return PopUpWidgetScaffold(
            title: favPage.folder ?? "Unselected".tl,
            body: Padding(
              padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
              child: Container(
                constraints:
                    const BoxConstraints(maxHeight: 700, maxWidth: 500),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: targetFolders.length + 1,
                        itemBuilder: (context, index) {
                          if (index == targetFolders.length) {
                            return SizedBox(
                              height: 36,
                              child: Center(
                                child: TextButton(
                                  onPressed: () {
                                    newFolder().then((v) {
                                      setState(() {
                                        targetFolders = LocalFavoritesManager()
                                            .folderNames
                                            .where((folder) =>
                                                folder != favPage.folder)
                                            .toList();
                                      });
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.plus, size: 20),
                                      const SizedBox(width: 4),
                                      Text("New Folder".tl),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          var folder = targetFolders[index];
                          var disabled = false;
                          if (selectedLocalFolders.isNotEmpty) {
                            if (added.contains(folder) &&
                                !added.contains(selectedLocalFolders.first)) {
                              disabled = true;
                            } else if (!added.contains(folder) &&
                                added.contains(selectedLocalFolders.first)) {
                              disabled = true;
                            }
                          }
                          return CheckboxListTile(
                            title: Row(
                              children: [
                                Text(folder),
                                const SizedBox(width: 8),
                              ],
                            ),
                            value: selectedLocalFolders.contains(folder),
                            onChanged: disabled
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v!) {
                                        selectedLocalFolders.add(folder);
                                      } else {
                                        selectedLocalFolders.remove(folder);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    Center(
                      child: FilledButton(
                        onPressed: () {
                          if (selectedLocalFolders.isEmpty) {
                            return;
                          }
                          if (option == 'move') {
                            var comics = selectedComics.keys
                                .map((e) => e as FavoriteItem)
                                .toList();
                            for (var f in selectedLocalFolders) {
                              LocalFavoritesManager().batchMoveFavorites(
                                favPage.folder as String,
                                f,
                                comics,
                              );
                            }
                          } else {
                            var comics = selectedComics.keys
                                .map((e) => e as FavoriteItem)
                                .toList();
                            for (var f in selectedLocalFolders) {
                              LocalFavoritesManager().batchCopyFavorites(
                                favPage.folder as String,
                                f,
                                comics,
                              );
                            }
                          }
                          App.rootContext.pop();
                          updateComics();
                          _cancel();
                        },
                        child: Text(option == 'move' ? "Move".tl : "Add".tl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _checkExitSelectMode() {
    if (selectedComics.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  /// Opens a favorite on tap. Local imports and remote-library (WebDAV) /
  /// PDF / ZIP favorites have no comic source, so they must go straight to
  /// their dedicated readers instead of [ComicPage] (which would fail with
  /// "Comic source not found" or, for local imports, is simply unnecessary).
  /// Only comic-source favorites honor the [onClickFavorite] "viewDetail"
  /// setting and open the detail page first.
  void _openFavorite(FavoriteItem c, int heroID) {
    if (c.type != ComicType.webdav &&
        c.type != ComicType.pdf &&
        c.type != ComicType.zip &&
        c.type != ComicType.local &&
        appdata.settings["onClickFavorite"] == "viewDetail") {
      App.mainNavigatorKey?.currentContext?.to(
        () => ComicPage(
          id: c.id,
          sourceKey: c.sourceKey,
          cover: c.cover,
          title: c.title,
          heroID: heroID,
        ),
      );
      return;
    }
    _readFavorite(c);
  }

  /// Routes a favorite directly to the appropriate reader.
  void _readFavorite(FavoriteItem c) {
    if (c.type == ComicType.webdav) {
      App.mainNavigatorKey?.currentContext?.to(
        () => RemoteReaderWithLoading(
          folderPath: c.id,
          name: c.name,
          cover: c.coverPath,
        ),
      );
      return;
    }
    if (c.type == ComicType.pdf) {
      App.mainNavigatorKey?.currentContext?.to(
        () => RemotePdfReaderWithLoading(
          remotePath: c.id,
          name: c.name,
          cover: c.coverPath,
        ),
      );
      return;
    }
    if (c.type == ComicType.zip) {
      App.mainNavigatorKey?.currentContext?.to(
        () => RemoteZipReaderWithLoading(
          remotePath: c.id,
          name: c.name,
          cover: c.coverPath,
        ),
      );
      return;
    }
    App.mainNavigatorKey?.currentContext?.to(
      () => ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
    );
  }

  void _cancel() {
    setState(() {
      selectedComics.clear();
      multiSelectMode = false;
    });
  }

  void _deleteComicWithId() {
    var toBeDeleted = selectedComics.keys.map((e) => e as FavoriteItem).toList();
    LocalFavoritesManager().batchDeleteComics(widget.folder, toBeDeleted);
    _cancel();
  }
}

class _ReorderComicsPage extends StatefulWidget {
  const _ReorderComicsPage(this.name, this.onReorder);

  final String name;

  final void Function(List<FavoriteItem>) onReorder;

  @override
  State<_ReorderComicsPage> createState() => _ReorderComicsPageState();
}

class _ReorderComicsPageState extends State<_ReorderComicsPage> {
  final _key = GlobalKey();
  final _scrollController = ScrollController();
  late var comics = LocalFavoritesManager().getFolderComics(widget.name);
  bool changed = false;

  /// Human-readable source label using the unified [ComicType.sourceLabel]
  /// helper (本地导入 / 远程书库/... / 漫画源/`<key>`).
  static String _favoriteSourceLabel(FavoriteItem item) =>
      ComicType.sourceLabel(item.type, item.sourceKey);

  /// Machine-readable sourceKey for image-provider / routing fallback.
  static String? _favoriteSourceKey(FavoriteItem item) {
    if (item.type == ComicType.webdav) return 'webdav';
    if (item.type == ComicType.pdf) return 'pdf';
    if (item.type == ComicType.zip) return 'zip';
    return item.type.comicSource?.key;
  }

  static int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }

  Color lightenColor(Color color, double lightenValue) {
    int red =
        (_floatToInt8(color.r) + ((255 - color.r) * lightenValue)).round();
    int green = (_floatToInt8(color.g) * 255 + ((255 - color.g) * lightenValue))
        .round();
    int blue = (_floatToInt8(color.b) * 255 + ((255 - color.b) * lightenValue))
        .round();

    return Color.fromARGB(_floatToInt8(color.a), red, green, blue);
  }

  @override
  void dispose() {
    if (changed) {
      // Delay to ensure navigation is completed
      Future.delayed(const Duration(milliseconds: 200), () {
        LocalFavoritesManager().reorder(comics, widget.name);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['comicDisplayMode'];

    // Derive the ReorderableBuilder key from the SET of comics (order-independent).
    // When an item is removed (e.g. via the LocalFavoritesManager listener) the set
    // changes -> the builder remounts and re-initializes its internal entities with
    // fresh 0..n-1 order ids, keeping them in sync with `comics`. A pure reorder or
    // reverse only changes order, not the set, so the key stays stable.
    final sortedIds = comics.map((c) => '${c.id}:${c.type.value}').toList()..sort();
    final reorderWidgetKey = ValueKey('${comics.length}:${sortedIds.join('\u0000')}');

    var tiles = comics.map(
      (e) {
        return ComicTile(
          key: Key(e.hashCode.toString()),
          enableLongPressed: false,
          comic: Comic(
            e.name,
            e.coverPath,
            e.id,
            e.author,
            e.tags,
            type == 'detailed'
                ? "${e.time} | ${_favoriteSourceLabel(e)}"
                : "${_favoriteSourceLabel(e)} | ${e.time}",
            _favoriteSourceKey(e) ?? "Unknown".tl,
            null,
            null,
          ),
        );
      },
    ).toList();
    return Scaffold(
      appBar: Appbar(
        title: Text("Reorder".tl),
        actions: [
          Tooltip(
            message: "Information".tl,
            child: IconButton(
              icon: const Icon(LucideIcons.info),
              onPressed: () {
                showInfoDialog(
                  context: context,
                  title: "Reorder".tl,
                  content: "Long press and drag to reorder.".tl,
                );
              },
            ),
          ),
          Tooltip(
            message: "Reverse".tl,
            child: IconButton(
              icon: const Icon(LucideIcons.arrow_left_right),
              onPressed: () {
                setState(() {
                  comics = comics.reversed.toList();
                  changed = true;
                });
              },
            ),
          )
        ],
      ),
      body: ReorderableBuilder<FavoriteItem>(
        key: reorderWidgetKey,
        scrollController: _scrollController,
        longPressDelay: App.isDesktop
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 500),
        onReorder: (reorderFunc) {
          try {
            final reordered = reorderFunc(comics);
            changed = true;
            setState(() {
              comics = reordered;
            });
            widget.onReorder(comics);
          } catch (e) {
            // Safety net: keep the app from crashing if the package ever
            // computes out-of-range indices (e.g. entity list desync).
            Log.error('reorder failed', e.toString());
          }
        },
        dragChildBoxDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: lightenColor(
            Theme.of(context).splashColor.withAlpha(255),
            0.2,
          ),
        ),
        builder: (children) {
          return GridView(
            key: _key,
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithComics(),
            children: children,
          );
        },
        children: tiles,
      ),
    );
  }
}

class _SelectUpdatePageNum extends StatefulWidget {
  const _SelectUpdatePageNum({
    required this.networkSource,
    this.networkFolder,
    super.key,
  });

  final String? networkFolder;
  final String networkSource;

  @override
  State<_SelectUpdatePageNum> createState() => _SelectUpdatePageNumState();
}

class _SelectUpdatePageNumState extends State<_SelectUpdatePageNum> {
  int updatePageNum = 9999999;

  String get _allPageText => 'All'.tl;

  List<String> get pageNumList =>
      ['1', '2', '3', '5', '10', '20', '50', '100', '200', _allPageText];

  @override
  void initState() {
    updatePageNum =
        appdata.implicitData["local_favorites_update_page_num"] ?? 9999999;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var source = ComicSource.find(widget.networkSource);
    var sourceName = source?.name ?? widget.networkSource;
    var text = "The folder is Linked to @source".tlParams({
      "source": sourceName,
    });
    if (widget.networkFolder != null && widget.networkFolder!.isNotEmpty) {
      text += "\n${"Source Folder".tl}: ${widget.networkFolder}";
    }

    return Column(
      children: [
        Row(
          children: [Text(text)],
        ),
        Row(
          children: [
            Text("Update the page number by the latest collection".tl),
            Spacer(),
            Select(
              current: updatePageNum.toString() == '9999999'
                  ? _allPageText
                  : updatePageNum.toString(),
              values: pageNumList,
              minWidth: 48,
              onTap: (index) {
                setState(() {
                  updatePageNum = int.parse(pageNumList[index] == _allPageText
                      ? '9999999'
                      : pageNumList[index]);
                  appdata.implicitData["local_favorites_update_page_num"] =
                      updatePageNum;
                  appdata.writeImplicitData();
                });
              },
            )
          ],
        ),
      ],
    );
  }
}

class _LocalFavoritesFilterDialog extends StatefulWidget {
  const _LocalFavoritesFilterDialog({
    required this.initReadFilterSelect,
    required this.updateConfig,
  });

  final String initReadFilterSelect;
  final Function updateConfig;

  @override
  State<_LocalFavoritesFilterDialog> createState() =>
      _LocalFavoritesFilterDialogState();
}

const readFilterList = ['All', 'UnCompleted', 'Completed'];

class _LocalFavoritesFilterDialogState
    extends State<_LocalFavoritesFilterDialog> {
  List<String> optionTypes = ['Filter'];
  late var readFilter = widget.initReadFilterSelect;
  @override
  Widget build(BuildContext context) {
    Widget tabBar = Material(
      borderRadius: BorderRadius.circular(8),
      child: AppTabBar(
        key: PageStorageKey(optionTypes),
        tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
      ),
    ).paddingTop(context.padding.top);
    return ContentDialog(
      content: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tabBar,
            TabViewBody(children: [
              Column(
                children: [
                  ListTile(
                    title: Text("Filter reading status".tl),
                    trailing: Select(
                      current: readFilter.tl,
                      values: readFilterList.map((e) => e.tl).toList(),
                      minWidth: 64,
                      onTap: (index) {
                        setState(() {
                          readFilter = readFilterList[index];
                        });
                      },
                    ),
                  )
                ],
              )
            ]),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            appdata.implicitData["local_favorites_read_filter"] = readFilter;
            appdata.writeImplicitData();
            if (mounted) {
              Navigator.pop(context);
              widget.updateConfig(readFilter);
            }
          },
          child: Text("Confirm".tl),
        ),
      ],
    );
  }
}
