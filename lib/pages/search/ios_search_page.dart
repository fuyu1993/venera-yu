import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/pages/search_result_page.dart';
import 'package:venera/utils/translations.dart';

/// iOS 风格搜索页面
class IosSearchPage extends StatefulWidget {
  const IosSearchPage({super.key});

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
    var history = appdata.settings['searchHistory'] as List?;
    _searchHistory = history?.cast<String>() ?? [];
  }

  void _saveSearchHistory(String text) {
    if (text.trim().isEmpty) return;
    _searchHistory.remove(text);
    _searchHistory.insert(0, text);
    if (_searchHistory.length > 20) {
      _searchHistory = _searchHistory.sublist(0, 20);
    }
    appdata.settings['searchHistory'] = _searchHistory;
    appdata.saveData();
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

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SearchResultPage(
          text: searchText,
          sourceKey: _searchTarget,
          options: [],
        ),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Search'.tl),
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.9),
      ),
      child: SafeArea(
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
      ),
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
        // 搜索源选择
        if (_searchSources.isNotEmpty) ...[
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
        children: _searchSources.map((source) {
          final isSelected = _searchTarget == source && !_aggregatedSearch;
          return CupertinoListTile(
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
          );
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
        children: _searchHistory.take(5).map((text) {
          return CupertinoListTile(
            leading: Icon(
              CupertinoIcons.clock,
              size: 20,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            title: Text(text),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _searchHistory.remove(text);
                });
                appdata.settings['searchHistory'] = _searchHistory;
                appdata.saveData();
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
          );
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
