import 'package:flutter/material.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/context.dart';
import 'package:venera/pages/tabs.dart';
import 'package:venera/utils/translations.dart';

class CustomTabsPage extends StatefulWidget {
  const CustomTabsPage({super.key});

  @override
  State<CustomTabsPage> createState() => _CustomTabsPageState();
}

class _CustomTabsPageState extends State<CustomTabsPage> {
  late List<Map<String, dynamic>> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = getTabConfig();
  }

  int get _visibleCount => _tabs.where((t) => t['visible'] == true).length;

  void _persist() => setTabConfig(_tabs);

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, item);
      _persist();
    });
  }

  void _toggle(String id, bool value) {
    if (!value && _visibleCount <= 1) {
      context.showMessage(message: "至少保留一个标签页");
      return;
    }
    setState(() {
      final item = _tabs.firstWhere((t) => t['id'] == id);
      item['visible'] = value;
      _persist();
    });
  }

  void _reset() {
    setState(() {
      _tabs = kDefaultTabConfig
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      resetTabConfig();
    });
    context.showMessage(message: "已恢复默认设置");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Custom Tabs".tl),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text("Reset".tl),
          ),
        ],
      ),
      body: ReorderableListView(
        onReorderItem: _onReorderItem,
        buildDefaultDragHandles: false,
        children: [
          for (int i = 0; i < _tabs.length; i++)
            ListTile(
              key: ValueKey(_tabs[i]['id']),
              leading: ReorderableDragStartListener(
                index: i,
                child: const Icon(Icons.drag_handle),
              ),
              title: Text(getTabDefinition(_tabs[i]['id']).labelKey.tl),
              trailing: Switch(
                value: _tabs[i]['visible'] == true,
                onChanged: (v) => _toggle(_tabs[i]['id'], v),
              ),
            ),
        ],
      ),
    );
  }
}
