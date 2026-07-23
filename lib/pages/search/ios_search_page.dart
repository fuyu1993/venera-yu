import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:venera/adaptive/adaptive_platform.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/pages/aggregated_search_page.dart';
import 'package:venera/pages/search_result_page.dart';
import 'package:venera/utils/translations.dart';

/// iOS 风格搜索页面
class IosSearchPage extends StatefulWidget {
  const IosSearchPage({super.key, this.showNavigationBar = true});

  /// 是否显示顶部 [CupertinoNavigationBar]。作为底部 Tab 页嵌入时应设为 false，
  /// 避免与 [NaviPane] 的顶部栏重复。
  final bool showNavigationBar;

  @override
  State<IosSearchPage> createState() => _IosSearchPageState();
}

class _IosSearchPageState extends State<IosSearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late List<String> _searchSources;
  String _searchTarget = "";
  bool _aggregatedSearch = false;
  List<String> _suggestions = [];
  List<String> _searchHistory = [];

  /// Search history with source information (text + source).
  List<Map<String, String>> _searchHistoryWithSource = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _findSearchSources();
    _loadSearchHistory();

    _controller.addListener(_findSuggestions);
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _findSearchSources() {
    var all = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    var settings = appdata.settings['searchSources'] as List;
    _searchSources = settings.where((s) => all.contains(s)).cast<String>().toList();
    if (_searchSources.isNotEmpty) {
      _searchTarget = _searchSources.first;
    }
  }

  void _loadSearchHistory() {
    _searchHistoryWithSource = appdata.searchHistoryWithSource;
    _searchHistory = _searchHistoryWithSource
        .map((e) => e['text'] ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _saveSearchHistory(String text) {
    if (text.trim().isEmpty) return;
    // Save with source information
    final source = _aggregatedSearch ? 'aggregated' : _searchTarget;
    appdata.addSearchHistory(text, source: source);
    _loadSearchHistory();
  }

  void _findSuggestions() {
    var text = _controller.text;
    if (text.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    // 简单的建议逻辑
    var suggestions = <String>[];
    // 标签建议功能需要根据实际的 SearchPageData 结构调整

    setState(() {
      _suggestions = suggestions.take(10).toList();
    });
  }

  void _search([String? text]) {
    var searchText = text ?? _controller.text;
    if (searchText.trim().isEmpty) return;

    _saveSearchHistory(searchText);

    if (_aggregatedSearch) {
      Navigator.of(context).push(
        adaptivePageRoute(
          builder: (_) => AggregatedSearchPage(keyword: searchText),
        ),
      );
    } else {
      Navigator.of(context).push(
        adaptivePageRoute(
          builder: (_) => SearchResultPage(
            text: searchText,
            sourceKey: _searchTarget,
            options: [],
          ),
        ),
      );
    }
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      // 嵌入 NaviPane 时，顶部/底部安全区已由 NaviPane 的顶栏和底栏处理，
      // 页面自身不再重复添加；独立 push 时由 CupertinoPageScaffold 负责。
      top: widget.showNavigationBar,
      bottom: widget.showNavigationBar,
      child: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 内容区域
          Expanded(
            child: _controller.text.isNotEmpty
                ? _buildSuggestions()
                : _buildSearchContent(),
          ),
        ],
      ),
    );

    if (widget.showNavigationBar) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Search'.tl),
          backgroundColor: CupertinoColors.systemBackground
              .resolveFrom(context)
              .withValues(alpha: 0.9),
        ),
        child: body,
      );
    }

    // 嵌入底部 Tab：CupertinoPageScaffold 会在 navigationBar 为 null 时自动加
    // SafeArea，造成与 NaviPane 的安全区重复。改用普通 Scaffold 并让 body 的
    // SafeArea 关闭 top/bottom。
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      body: body,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CupertinoSearchTextField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: 'Search comics...'.tl,
                onSubmitted: _search,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ),
          if (_focusNode.hasFocus || _controller.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _clearSearch,
              child: Text(
                'Cancel'.tl,
                style: TextStyle(
                  color: CupertinoColors.systemBlue.resolveFrom(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    return ListView(
      children: [
        // 聚合搜索开关（放在搜索源选择上方）
        if (_searchSources.isNotEmpty) ...[
          CupertinoListTile(
            title: Text('Aggregated Search'.tl),
            leading: Checkbox(
              value: _aggregatedSearch,
              onChanged: (value) {
                setState(() {
                  _aggregatedSearch = value ?? false;
                });
              },
            ),
          ),
          // 搜索源选择
          _buildSectionHeader('Search in'.tl),
          _buildSourceSelector(),
        ],
        // 搜索历史
        if (_searchHistory.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches'.tl),
          _buildSearchHistory(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _searchSources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final isSelected = _searchTarget == source && !_aggregatedSearch;
          final children = <Widget>[
            CupertinoListTile(
              title: Text(ComicSource.find(source)?.name ?? source),
              trailing: isSelected
                  ? Icon(
                      CupertinoIcons.check_mark,
                      color: CupertinoColors.systemBlue.resolveFrom(context),
                    )
                  : null,
              onTap: () {
                setState(() {
                  _searchTarget = source;
                  _aggregatedSearch = false;
                });
              },
            ),
          ];
          // 在每一项之间添加分隔线（最后一项除外）
          if (index < _searchSources.length - 1) {
            children.add(
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 16),
                color: CupertinoColors.separator.resolveFrom(context),
              ),
            );
          }
          return Column(children: children);
        }).toList(),
      ),
    );
  }

  Widget _buildSearchHistory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _searchHistoryWithSource.take(5).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final historyEntry = entry.value;
          final text = historyEntry['text'] ?? '';
          final source = historyEntry['source'] ?? 'unknown';
          final sourceName = source == 'aggregated'
              ? 'Aggregated'.tl
              : source == 'unknown'
                  ? ''
                  : ComicSource.find(source)?.name ?? source;
          final children = <Widget>[
            CupertinoListTile(
              leading: Icon(
                CupertinoIcons.clock,
                size: 20,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              title: Text(text),
              subtitle: sourceName.isNotEmpty ? Text(sourceName, style: const TextStyle(fontSize: 12)) : null,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  appdata.removeSearchHistory(text);
                  _loadSearchHistory();
                  setState(() {});
                },
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 20,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
              ),
              onTap: () {
                _controller.text = text;
                _search(text);
              },
            ),
          ];
          // 在每一项之间添加分隔线（最后一项除外）
          if (index < _searchHistoryWithSource.take(5).length - 1) {
            children.add(
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 52),
                color: CupertinoColors.separator.resolveFrom(context),
              ),
            );
          }
          return Column(children: children);
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          'No suggestions'.tl,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        return CupertinoListTile(
          leading: Icon(
            CupertinoIcons.search,
            size: 20,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          title: Text(_suggestions[index]),
          onTap: () {
            _controller.text = _suggestions[index];
            _search(_suggestions[index]);
          },
        );
      },
    );
  }
}
