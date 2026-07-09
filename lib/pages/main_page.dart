import 'package:flutter/material.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/pages/categories_page.dart';
import 'package:venera/pages/search_page.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/translations.dart';

import '../components/components.dart';
import '../foundation/app.dart';
import 'explore_page.dart';
import 'favorites/favorites_page.dart';
import 'home_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final NaviObserver _observer;

  GlobalKey<NavigatorState>? _navigatorKey;

  void to(Widget Function() widget, {bool preventDuplicate = false}) async {
    if (preventDuplicate) {
      var page = widget();
      if ("/${page.runtimeType}" == _observer.routes.last.toString()) return;
    }
    _navigatorKey!.currentContext!.to(widget);
  }

  void back() {
    _navigatorKey!.currentContext!.pop();
  }

  // Get all available tabs
  static const _allTabs = [
    {'id': 'home', 'label': 'Home', 'icon': TIcons.home, 'activeIcon': TIcons.home},
    {'id': 'favorites', 'label': 'Favorites', 'icon': TIcons.activity, 'activeIcon': TIcons.activity},
    {'id': 'explore', 'label': 'Explore', 'icon': TIcons.explore, 'activeIcon': TIcons.explore},
    {'id': 'categories', 'label': 'Categories', 'icon': TIcons.view_list, 'activeIcon': TIcons.view_list},
  ];

  // Get all pages
  static const _allPages = {
    'home': HomePage(),
    'favorites': FavoritesPage(key: PageStorageKey('favorites')),
    'explore': ExplorePage(key: PageStorageKey('explore')),
    'categories': CategoriesPage(key: PageStorageKey('categories')),
  };

  List<Map<String, dynamic>> get _customTabs {
    var tabs = appdata.settings['customTabs'] as List?;
    if (tabs == null || tabs.isEmpty) {
      return _allTabs.asMap().entries.map((e) => {
        'id': e.value['id'],
        'visible': true,
        'order': e.key,
      }).toList();
    }
    return tabs.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _visibleTabs {
    var tabs = _customTabs.where((t) => t['visible'] == true).toList();
    _ensureMinTabs(tabs);
    tabs.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    return tabs;
  }

  /// Ensure at least 2 tabs are visible, mutating the config if needed.
  void _ensureMinTabs(List<Map<String, dynamic>> tabs) {
    if (tabs.length >= 2) return;
    var visibleIds = tabs.map((t) => t['id']).toSet();
    for (var entry in _allTabs) {
      if (tabs.length >= 2) break;
      if (!visibleIds.contains(entry['id'])) {
        tabs.add({'id': entry['id'], 'visible': true, 'order': tabs.length});
        visibleIds.add(entry['id']);
      }
    }
  }

  List<PaneItemEntry> get _paneItems {
    return _visibleTabs.map((tab) {
      var tabInfo = _allTabs.firstWhere((t) => t['id'] == tab['id']);
      return PaneItemEntry(
        label: (tabInfo['label'] as String).tl,
        icon: tabInfo['icon'] as IconData,
        activeIcon: tabInfo['activeIcon'] as IconData,
      );
    }).toList();
  }

  List<Widget> get _pages {
    return _visibleTabs.map((tab) => _allPages[tab['id']]!).toList();
  }

  @override
  void initState() {
    _observer = NaviObserver();
    _navigatorKey = GlobalKey();
    App.mainNavigatorKey = _navigatorKey;
    var initialPage = int.tryParse(appdata.settings['initialPage'].toString()) ?? 0;
    // Ensure initialPage is within valid range
    var visibleTabs = _visibleTabs;
    if (initialPage >= visibleTabs.length) {
      initialPage = 0;
    }
    index = initialPage;
    // Listen to settings changes to rebuild when customTabs changes
    appdata.settings.addListener(_onSettingsChanged);
    super.initState();
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  var index = 0;

  @override
  Widget build(BuildContext context) {
    return NaviPane(
      initialPage: index,
      observer: _observer,
      navigatorKey: _navigatorKey!,
      paneItems: _paneItems,
      onPageChanged: (i) {
        setState(() {
          index = i;
        });
      },
      paneActions: [
        if(index != 0)
          PaneActionEntry(
            icon: TIcons.search,
            label: "Search".tl,
            onTap: () {
              to(() => const SearchPage(), preventDuplicate: true);
            },
          ),
        PaneActionEntry(
          icon: TIcons.setting,
          label: "Settings".tl,
          onTap: () {
            to(() => const SettingsPage(), preventDuplicate: true);
          },
        )
      ],
      pageBuilder: (index) {
        final pages = _pages;
        if (pages.isEmpty) return const SizedBox();
        if (index >= pages.length) index = 0;
        return pages[index];
      },
    );
  }
}
