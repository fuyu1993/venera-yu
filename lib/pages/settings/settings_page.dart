import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:flutter_memory_info/flutter_memory_info.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/network/app_dio.dart';
import 'package:webdav_client/webdav_client.dart' hide File;
import 'package:venera/network/dev_network_logger.dart';
import 'package:venera/utils/data.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';
import 'package:yaml/yaml.dart';

part 'reader.dart';
part 'explore_settings.dart';
part 'setting_components.dart';
part 'local_favorites.dart';
part 'app.dart';
part 'about.dart';
part 'network.dart';
part 'debug.dart';
part 'lab.dart';
part 'developer.dart';
part 'general.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.initialPage = -1, super.key});

  final int initialPage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int currentPage = -1;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<_SettingIndexItem> _searchResults = [];

  ColorScheme get colors => Theme.of(context).colorScheme;

  bool get enableTwoViews => context.width > 720;

  final categories = <String>[
    "General",
    "Explore",
    "Reading",
    "Local Favorites",
    "APP",
    "Network",
    "About",
    "Lab",
    "Debug"
  ];

  final icons = <IconData>[
    LucideIcons.sliders_horizontal,
    LucideIcons.compass,
    LucideIcons.book_open,
    LucideIcons.bookmark,
    LucideIcons.app_window,
    LucideIcons.globe,
    LucideIcons.info,
    LucideIcons.building,
    LucideIcons.bug,
  ];

  // Settings index for search: all searchable settings with their page index
  List<_SettingIndexItem> get _settingIndex => const [
    // 0 - General
    _SettingIndexItem("Language", 0),
    _SettingIndexItem("Appearance", 0),
    _SettingIndexItem("Theme", 0),
    _SettingIndexItem("Custom Tabs", 0),
    // 1 - Explore
    _SettingIndexItem("Display mode of comic tile", 1),
    _SettingIndexItem("Size of comic tile", 1),
    _SettingIndexItem("Explore Pages", 1),
    _SettingIndexItem("Category Pages", 1),
    _SettingIndexItem("Network Favorite Pages", 1),
    _SettingIndexItem("Search Sources", 1),
    _SettingIndexItem("Show favorite status on comic tile", 1),
    _SettingIndexItem("Show history on comic tile", 1),
    _SettingIndexItem("Reverse default chapter order", 1),
    _SettingIndexItem("Keyword blocking", 1),
    _SettingIndexItem("Comment keyword blocking", 1),
    _SettingIndexItem("Default Search Target", 1),
    _SettingIndexItem("Auto Language Filters", 1),
    _SettingIndexItem("Initial Page", 1),
    _SettingIndexItem("Display mode of comic list", 1),
    // 2 - Reading
    _SettingIndexItem("Enable comic specific settings", 2),
    _SettingIndexItem("Enable device specific settings", 2),
    _SettingIndexItem("Tap to turn Pages", 2),
    _SettingIndexItem("Reverse tap to turn Pages", 2),
    _SettingIndexItem("Page animation", 2),
    _SettingIndexItem("Reading mode", 2),
    _SettingIndexItem("Auto page turning interval", 2),
    _SettingIndexItem("Show single image on first page", 2),
    _SettingIndexItem("Mouse scroll speed", 2),
    _SettingIndexItem("Double tap to zoom", 2),
    _SettingIndexItem("Long press to zoom", 2),
    _SettingIndexItem("Long press zoom position", 2),
    _SettingIndexItem("Limit image width", 2),
    _SettingIndexItem("Turn page by volume keys", 2),
    _SettingIndexItem("Display time & battery info in reader", 2),
    _SettingIndexItem("Show system status bar", 2),
    // 3 - Local Favorites
    _SettingIndexItem("Show local favorites before network favorites", 3),
    _SettingIndexItem("Auto close favorite panel after operation", 3),
    _SettingIndexItem("Add new favorite to", 3),
    _SettingIndexItem("Move favorite after reading", 3),
    _SettingIndexItem("Quick Favorite", 3),
    _SettingIndexItem("Delete all unavailable local favorite items", 3),
    _SettingIndexItem("Click favorite", 3),
    // 4 - APP
    _SettingIndexItem("Storage Path for local comics", 4),
    _SettingIndexItem("Set New Storage Path", 4),
    _SettingIndexItem("Cache Size", 4),
    _SettingIndexItem("Clear Cache", 4),
    _SettingIndexItem("Cache Limit", 4),
    _SettingIndexItem("Export App Data", 4),
    _SettingIndexItem("Import App Data", 4),
    _SettingIndexItem("Data Sync", 4),
    // 5 - Network
    _SettingIndexItem("Proxy", 5),
    _SettingIndexItem("DNS Overrides", 5),
    _SettingIndexItem("Download Threads", 5),
    _SettingIndexItem("Enable DNS Overrides", 5),
    // 6 - About
    _SettingIndexItem("Check for updates", 6),
    _SettingIndexItem("Check for updates on startup", 6),
    _SettingIndexItem("Github", 6),
    // 7 - Lab
    _SettingIndexItem("Enable Experimental Features", 7),
    _SettingIndexItem("Hide Comic Thumbnails", 7),
    _SettingIndexItem("Developer Mode", 7),
    // 8 - Debug
    _SettingIndexItem("Reload Configs", 8),
    _SettingIndexItem("Open Log", 8),
    _SettingIndexItem("Ignore Certificate Errors", 8),
  ];

  @override
  void initState() {
    currentPage = widget.initialPage;
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _fuzzyMatch(String text, String pattern) {
    text = text.toLowerCase();
    pattern = pattern.toLowerCase();
    int i = 0, j = 0;
    while (i < text.length && j < pattern.length) {
      if (text[i] == pattern[j]) {
        j++;
      }
      i++;
    }
    return j == pattern.length;
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = [];
        return;
      }
      _searchResults = _settingIndex
          .where((item) =>
              _fuzzyMatch(item.title, query) ||
              _fuzzyMatch(item.title.tl, query) ||
              _fuzzyMatch(categories[item.pageIndex], query) ||
              _fuzzyMatch(categories[item.pageIndex].tl, query))
          .toList();
    });
  }

  void _navigateToPage(int pageIndex) {
    setState(() {
      currentPage = pageIndex;
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
      _searchFocus.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: buildBody(),
    );
  }

  Widget buildBody() {
    if (enableTwoViews) {
      return Row(
        children: [
          SizedBox(
            width: 280,
            height: double.infinity,
            child: buildLeft(),
          ),
          Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return LayoutBuilder(
                  builder: (context, constrains) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        var width = constrains.maxWidth;
                        var value = animation.isForwardOrCompleted
                            ? 1 - animation.value
                            : 1;
                        var left = width * value;
                        return Stack(
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: left,
                              width: width,
                              child: child,
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: buildRight(),
            ),
          )
        ],
      );
    } else {
      return buildLeft();
    }
  }

  Widget buildLeft() {
    return Material(
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).padding.top,
          ),
          SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(width: 8),
              Tooltip(
                message: "Back".tl,
                child: IconButton(
                  icon: const Icon(LucideIcons.chevron_left),
                  onPressed: _isSearching
                      ? () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                            _searchResults = [];
                            _searchFocus.unfocus();
                          });
                        }
                      : context.pop,
                ),
              ),
              if (!_isSearching) ...[
                const SizedBox(width: 24),
                Expanded(
                  child: Text("Settings".tl, style: ts.s20),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.search),
                  tooltip: "搜索设置".tl,
                  onPressed: () {
                    setState(() => _isSearching = true);
                    _searchFocus.requestFocus();
                  },
                ),
              ] else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "搜索设置...".tl,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isSearching ? buildSearchResults() : buildCategories(),
          )
        ],
      ),
    );
  }

  Widget buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.search, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text("输入关键词搜索设置项".tl,
                style: ts.s14.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.x, size: 48,
                color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text("没有找到相关设置".tl,
                style: ts.s14.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final categoryName = categories[item.pageIndex].tl;
        return Padding(
          padding: enableTwoViews
              ? const EdgeInsets.fromLTRB(8, 0, 8, 0)
              : EdgeInsets.zero,
          child: InkWell(
            onTap: () => _navigateToPage(item.pageIndex),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Icon(icons[item.pageIndex], size: 20,
                      color: colors.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.title.tl, style: ts.s14),
                        const SizedBox(height: 2),
                        Text(categoryName, style: ts.s12.copyWith(
                            color: colors.primary)),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevron_right, size: 20),
                ],
              ),
            ),
          ).paddingVertical(4),
        );
      },
    );
  }

  Widget buildCategories() {
    Widget buildItem(String name, int id) {
      final bool selected = id == currentPage;

      Widget content = AnimatedContainer(
        key: ValueKey(id),
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 46,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer.toOpacity(0.36) : null,
          border: Border(
            left: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(children: [
          Icon(icons[id]),
          const SizedBox(width: 16),
          Text(
            name,
            style: ts.s16,
          ),
          const Spacer(),
          if (selected) const Icon(LucideIcons.arrow_right)
        ]),
      );

      return Padding(
        padding: enableTwoViews
            ? const EdgeInsets.fromLTRB(8, 0, 8, 0)
            : EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            if (enableTwoViews) {
              setState(() => currentPage = id);
            } else {
              context.to(() => _SettingsDetailPage(pageIndex: id));
            }
          },
          child: content,
        ).paddingVertical(4),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      itemBuilder: (context, index) => buildItem(categories[index].tl, index),
    );
  }

  Widget buildRight() {
    if (currentPage == -1) {
      return const SizedBox();
    }
    return Navigator(
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return _buildSettingsContent(currentPage);
          },
          transitionDuration: Duration.zero,
        );
      },
    );
  }

  Widget _buildSettingsContent(int pageIndex) {
    return switch (pageIndex) {
      0 => const GeneralSettings(),
      1 => const ExploreSettings(),
      2 => const ReaderSettings(),
      3 => const LocalFavoritesSettings(),
      4 => const AppSettings(),
      5 => const NetworkSettings(),
      6 => const AboutSettings(),
      7 => const LabSettings(),
      8 => const DebugPage(),
      _ => throw UnimplementedError()
    };
  }

}

class _SettingIndexItem {
  final String title;
  final int pageIndex;

  const _SettingIndexItem(this.title, this.pageIndex);
}

class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage({required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: _buildPage(),
    );
  }

  Widget _buildPage() {
    return switch (pageIndex) {
      0 => const GeneralSettings(),
      1 => const ExploreSettings(),
      2 => const ReaderSettings(),
      3 => const LocalFavoritesSettings(),
      4 => const AppSettings(),
      5 => const NetworkSettings(),
      6 => const AboutSettings(),
      7 => const LabSettings(),
      8 => const DebugPage(),
      _ => throw UnimplementedError()
    };
  }
}
