part of 'settings_page.dart';

class GeneralSettings extends StatefulWidget {
  const GeneralSettings({super.key});

  @override
  State<GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<GeneralSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("General".tl)),
        SelectSetting(
          title: "Language".tl,
          settingKey: "language",
          optionTranslation: const {
            "system": "System",
            "zh-CN": "简体中文",
            "zh-TW": "繁體中文",
            "en-US": "English",
          },
          onChanged: () {
            App.forceRebuild();
          },
        ).toSliver(),
        SelectSetting(
          title: "Appearance".tl,
          settingKey: "theme_mode",
          optionTranslation: {
            "system": "System".tl,
            "light": "Light".tl,
            "dark": "Dark".tl,
          },
          onChanged: () async {
            App.forceRebuild();
          },
        ).toSliver(),
        SelectSetting(
          title: "Theme".tl,
          settingKey: "color",
          optionTranslation: {
            "system": "System".tl,
            "red": "Red".tl,
            "pink": "Pink".tl,
            "purple": "Purple".tl,
            "green": "Green".tl,
            "orange": "Orange".tl,
            "blue": "Blue".tl,
          },
          onChanged: () async {
            await App.init();
            App.forceRebuild();
          },
        ).toSliver(),
        SliverToBoxAdapter(
          child: _CustomTabsSetting(),
        ),
      ],
    );
  }
}


class _CustomTabsSetting extends StatefulWidget {
  @override
  State<_CustomTabsSetting> createState() => _CustomTabsSettingState();
}

class _CustomTabsSettingState extends State<_CustomTabsSetting> {
  static const _allTabs = [
    {'id': 'home', 'label': 'Home', 'icon': LucideIcons.house},
    {'id': 'favorites', 'label': 'Favorites', 'icon': LucideIcons.user_star},
    {'id': 'explore', 'label': 'Explore', 'icon': LucideIcons.compass},
    {'id': 'search', 'label': 'Search', 'icon': LucideIcons.search},
    {'id': 'categories', 'label': 'Categories', 'icon': LucideIcons.list},
    {'id': 'remote_library', 'label': 'Remote Library', 'icon': LucideIcons.monitor_cloud},
    {'id': 'settings', 'label': 'Settings', 'icon': LucideIcons.settings},
  ];

  List<Map<String, dynamic>> get _tabs {
    var saved = appdata.settings['customTabs'] as List?;
    List<Map<String, dynamic>> result;
    if (saved == null || saved.isEmpty) {
      result = _allTabs.asMap().entries.map((e) => {
        'id': e.value['id'],
        'visible': true,
        'order': e.key,
      }).toList();
    } else {
      result = saved.cast<Map<String, dynamic>>();
    }
    // Merge any new tabs not in saved config
    var savedIds = result.map((t) => t['id']).toSet();
    for (int i = 0; i < _allTabs.length; i++) {
      if (!savedIds.contains(_allTabs[i]['id'])) {
        result.add({'id': _allTabs[i]['id'], 'visible': true, 'order': result.length});
      }
    }
    // Drop tabs that no longer exist (e.g. a feature moved out of the tab bar).
    result.removeWhere((t) => !_allTabs.any((e) => e['id'] == t['id']));
    return result;
  }

  void _saveTabs(List<Map<String, dynamic>> tabs) {
    appdata.settings['customTabs'] = tabs;
    appdata.saveData();
    setState(() {});
  }

  void _resetToDefault() {
    var defaultTabs = _allTabs.asMap().entries.map((e) => {
      'id': e.value['id'],
      'visible': true,
      'order': e.key,
    }).toList();
    _saveTabs(defaultTabs);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tabs = _tabs;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Custom Tabs".tl,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: _resetToDefault,
                child: Text("Reset".tl),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Customize which tabs are shown and their order".tl,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (oldIndex, newIndex) {
              var newTabs = List<Map<String, dynamic>>.from(tabs);
              var item = newTabs.removeAt(oldIndex);
              newTabs.insert(newIndex, item);
              // Update order
              for (int i = 0; i < newTabs.length; i++) {
                newTabs[i]['order'] = i;
              }
              _saveTabs(newTabs);
            },
            children: tabs.map((tab) {
              var tabInfo = _allTabs.firstWhere((t) => t['id'] == tab['id']);
              return Card(
                key: ValueKey(tab['id']),
                child: ListTile(
                  leading: Icon(tabInfo['icon'] as IconData),
                  title: Text((tabInfo['label'] as String).tl),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.grip_vertical, color: colors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Switch(
                        value: tab['id'] == 'settings' ? true : tab['visible'] == true,
                        onChanged: tab['id'] == 'settings'
                            ? null
                            : (value) {
                                // At least 2 tabs must be visible
                                if (!value) {
                                  var visibleCount = tabs.where((t) => t['visible'] == true).length;
                                  if (visibleCount <= 2) {
                                    showInfoDialog(
                                      context: context,
                                      title: "Tip".tl,
                                      content: "At least 2 tabs must be visible".tl,
                                    );
                                    return;
                                  }
                                }
                                var newTabs = List<Map<String, dynamic>>.from(tabs);
                                var index = newTabs.indexWhere((t) => t['id'] == tab['id']);
                                newTabs[index]['visible'] = value;
                                _saveTabs(newTabs);
                              },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}