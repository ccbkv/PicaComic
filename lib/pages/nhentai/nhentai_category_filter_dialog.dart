import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/network/nhentai_network/tags.dart';
import 'package:pica_comic/utils/translations.dart';

class NhentaiCategoryFilterDialog extends StatefulWidget {
  const NhentaiCategoryFilterDialog({
    required this.initialParam,
    required this.onConfirm,
    super.key,
  });

  final String initialParam;
  final ValueChanged<String> onConfirm;

  @override
  State<NhentaiCategoryFilterDialog> createState() =>
      _NhentaiCategoryFilterDialogState();
}

class _NhentaiCategoryFilterDialogState
    extends State<NhentaiCategoryFilterDialog> {
  static const _comparisons = ['>=', '>', '=', '<', '<='];
  static const _numericLabelWidth = 132.0;
  static const _numericOperatorWidth = 72.0;
  static const _numericFieldHeight = 48.0;
  static const _remoteSearchDelay = Duration(milliseconds: 500);
  static const _localSuggestionLimit = 10;
  static const _remoteSuggestionLimit = 10;
  static const _remoteSuggestionNamespaces = [
    'tag',
    'character',
    'parody',
    'artist',
    'group',
  ];
  static const _localLanguageTerms = [
    NhentaiFilterTerm(namespace: 'language', value: 'chinese'),
    NhentaiFilterTerm(namespace: 'language', value: 'japanese'),
    NhentaiFilterTerm(namespace: 'language', value: 'english'),
  ];

  late final TextEditingController _searchController;
  late final TextEditingController _pagesController;
  late final TextEditingController _favoritesController;
  late final TextEditingController _uploadedController;

  late List<NhentaiFilterTerm> _terms;
  NhentaiNumericCondition? _pages;
  NhentaiNumericCondition? _favorites;
  NhentaiNumericCondition? _uploadedDays;
  String _searchText = '';
  String _pagesComparison = _comparisons.first;
  String _favoritesComparison = _comparisons.first;
  String _uploadedComparison = _comparisons.first;
  List<NhentaiFilterTerm> _localSuggestions = const [];
  List<NhentaiFilterTerm> _remoteSuggestions = const [];
  Timer? _remoteSearchDebounce;
  CancelToken? _remoteSearchCancelToken;
  int _remoteSearchVersion = 0;

  @override
  void initState() {
    super.initState();
    final filter = NhentaiCategoryFilter.fromParam(widget.initialParam);
    _terms = List.of(filter.terms);
    _pages = filter.pages;
    _favorites = filter.favorites;
    _uploadedDays = filter.uploadedDays;
    _pagesComparison = filter.pages?.comparison ?? _comparisons.first;
    _favoritesComparison = filter.favorites?.comparison ?? _comparisons.first;
    _uploadedComparison = filter.uploadedDays?.comparison ?? _comparisons.first;
    _searchController = TextEditingController();
    _pagesController =
        TextEditingController(text: filter.pages?.value.toString() ?? '');
    _favoritesController =
        TextEditingController(text: filter.favorites?.value.toString() ?? '');
    _uploadedController = TextEditingController(
      text: filter.uploadedDays?.value.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _remoteSearchDebounce?.cancel();
    _remoteSearchCancelToken?.cancel();
    _searchController.dispose();
    _pagesController.dispose();
    _favoritesController.dispose();
    _uploadedController.dispose();
    super.dispose();
  }

  List<String> get _commonTags => nhentaiTags.values.take(10).toList();

  List<NhentaiFilterTerm> get _searchSuggestions {
    return _mergeSuggestionTerms(_localSuggestions, _remoteSuggestions);
  }

  String _numericLabel(String label, NhentaiNumericCondition condition) {
    return '$label ${condition.comparison} ${condition.value}';
  }

  String _suggestionKey(NhentaiFilterTerm term) {
    return term.displayValue.trim().toLowerCase();
  }

  List<NhentaiFilterTerm> _mergeSuggestionTerms(
    List<NhentaiFilterTerm> primary,
    List<NhentaiFilterTerm> secondary,
  ) {
    final seen = <String>{};
    final merged = <NhentaiFilterTerm>[];
    for (final term in [...primary, ...secondary]) {
      if (_terms.contains(term)) {
        continue;
      }
      if (seen.add(_suggestionKey(term))) {
        merged.add(term);
      }
    }
    return merged;
  }

  List<NhentaiFilterTerm> _findLocalSuggestionTerms(
    String namespace,
    Iterable<String> values,
    String query,
  ) {
    final matches = <NhentaiFilterTerm>[];
    final seen = <String>{};
    for (final value in values) {
      if (!value.toLowerCase().contains(query)) {
        continue;
      }
      final term = NhentaiFilterTerm(namespace: namespace, value: value);
      if (seen.add(_suggestionKey(term)) && !_terms.contains(term)) {
        matches.add(term);
      }
      if (matches.length >= _localSuggestionLimit) {
        break;
      }
    }
    return matches;
  }

  List<NhentaiFilterTerm> _buildLocalSuggestions(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    return _mergeSuggestionTerms([
      ..._findLocalSuggestionTerms('tag', nhentaiTags.values, normalizedQuery),
      ..._findLocalSuggestionTerms(
        'character',
        nhentaiCharacterTags.values,
        normalizedQuery,
      ),
      ..._findLocalSuggestionTerms(
        'parody',
        nhentaiParodyTags.values,
        normalizedQuery,
      ),
      ..._findLocalSuggestionTerms(
        'language',
        _localLanguageTerms.map((term) => term.value),
        normalizedQuery,
      ),
    ], const []);
  }

  void _updateSearchInput(String value) {
    final localSuggestions = _buildLocalSuggestions(value);
    setState(() {
      _searchText = value;
      _localSuggestions = localSuggestions;
      _remoteSuggestions = const [];
    });
    _scheduleRemoteSuggestions(value);
  }

  void _resetSuggestionState() {
    _remoteSearchDebounce?.cancel();
    _remoteSearchCancelToken?.cancel();
    _remoteSearchCancelToken = null;
    _searchController.clear();
    _searchText = '';
    _localSuggestions = const [];
    _remoteSuggestions = const [];
  }

  void _scheduleRemoteSuggestions(String value) {
    _remoteSearchDebounce?.cancel();
    _remoteSearchCancelToken?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      _remoteSearchCancelToken = null;
      return;
    }

    final version = ++_remoteSearchVersion;
    _remoteSearchDebounce = Timer(_remoteSearchDelay, () async {
      final cancelToken = CancelToken();
      _remoteSearchCancelToken = cancelToken;
      final response = await NhentaiNetwork().autocompleteTagsByTypes(
        query,
        types: _remoteSuggestionNamespaces,
        limit: _remoteSuggestionLimit,
        cancelToken: cancelToken,
      );
      if (!mounted ||
          cancelToken.isCancelled ||
          version != _remoteSearchVersion ||
          _searchText.trim() != query) {
        return;
      }
      final remoteData = response.dataOrNull;
      setState(() {
        _remoteSuggestions = remoteData == null
            ? const []
            : _mergeSuggestionTerms(_localSuggestions, remoteData)
                .skip(_localSuggestions.length)
                .toList();
      });
    });
  }

  void _addTerm(NhentaiFilterTerm term) {
    if (_terms.contains(term)) {
      return;
    }
    setState(() {
      _terms = [..._terms, term];
      _resetSuggestionState();
    });
  }

  void _addTag(String value) {
    value = value.trim();
    if (value.isEmpty) {
      return;
    }
    _addTerm(NhentaiFilterTerm(namespace: 'tag', value: value));
  }

  void _addRawQuery(String value) {
    value = value.trim();
    if (value.isEmpty) {
      return;
    }
    _addTerm(
      NhentaiFilterTerm(
        namespace: nhentaiCategoryFilterRawQueryNamespace,
        value: value,
      ),
    );
  }

  void _removeTerm(NhentaiFilterTerm term) {
    setState(() {
      _terms = _terms.where((item) => item != term).toList();
    });
  }

  void _clearTerms() {
    setState(() {
      _terms = [];
    });
  }

  void _clearNumericCondition(String field) {
    setState(() {
      switch (field) {
        case 'pages':
          _pages = null;
          _pagesController.clear();
          break;
        case 'favorites':
          _favorites = null;
          _favoritesController.clear();
          break;
        case 'uploaded':
          _uploadedDays = null;
          _uploadedController.clear();
          break;
      }
    });
  }

  void _updateNumericCondition(
    String field,
    String comparison,
    String text,
  ) {
    final value = int.tryParse(text.trim());
    final condition = value == null
        ? null
        : NhentaiNumericCondition(comparison: comparison, value: value);
    setState(() {
      switch (field) {
        case 'pages':
          _pages = condition;
          _pagesComparison = comparison;
          break;
        case 'favorites':
          _favorites = condition;
          _favoritesComparison = comparison;
          break;
        case 'uploaded':
          _uploadedDays = condition;
          _uploadedComparison = comparison;
          break;
      }
    });
  }

  String _buildParam() {
    return NhentaiCategoryFilter(
      terms: _terms,
      pages: _pages,
      favorites: _favorites,
      uploadedDays: _uploadedDays,
    ).toParam();
  }

  Widget _buildActiveFiltersSection() {
    final hasActiveFilters =
        _terms.isNotEmpty ||
        _pages != null ||
        _favorites != null ||
        _uploadedDays != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '已选筛选条件'.tl,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: _terms.isEmpty ? null : _clearTerms,
              child: Text('清除'.tl),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasActiveFilters)
          Text('暂无筛选条件'.tl)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._terms.map(
                (term) => Chip(
                  label: Text(term.displayValue),
                  onDeleted: () => _removeTerm(term),
                ),
              ),
              if (_pages != null)
                Chip(
                  label: Text(_numericLabel('页数'.tl, _pages!)),
                  onDeleted: () => _clearNumericCondition('pages'),
                ),
              if (_favorites != null)
                Chip(
                  label: Text(_numericLabel('收藏数'.tl, _favorites!)),
                  onDeleted: () => _clearNumericCondition('favorites'),
                ),
              if (_uploadedDays != null)
                Chip(
                  label: Text(_numericLabel('上传日期天数'.tl, _uploadedDays!)),
                  onDeleted: () => _clearNumericCondition('uploaded'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildNumericField({
    required String label,
    required String field,
    required String comparison,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _numericLabelWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _numericOperatorWidth,
            height: _numericFieldHeight,
            child: DropdownButtonFormField<String>(
              value: comparison,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              items: _comparisons
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _updateNumericCondition(field, value, controller.text);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: _numericFieldHeight,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlignVertical: TextAlignVertical.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                decoration: InputDecoration(
                  hintText: '整数'.tl,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  _updateNumericCondition(field, comparison, value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEditorSection() {
    final suggestions = _searchSuggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '筛选条件'.tl,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索或直接输入标签'.tl,
            suffixIcon: IconButton(
              onPressed: () => _addRawQuery(_searchController.text),
              icon: const Icon(Icons.add),
            ),
          ),
          onChanged: _updateSearchInput,
          onSubmitted: _addRawQuery,
        ),
        const SizedBox(height: 8),
        if (_searchText.trim().isNotEmpty)
          TextButton(
            onPressed: () => _addRawQuery(_searchController.text),
            child: Text('${'添加标签'.tl}: ${_searchText.trim()}'),
          ),
        const SizedBox(height: 4),
        Text(
          '常用标签'.tl,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonTags
              .map(
                (value) => ActionChip(
                  label: Text(value),
                  onPressed: () => _addTag(value),
                ),
              )
              .toList(),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '搜索结果'.tl,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (term) => ActionChip(
                    label: Text(term.displayValue),
                    onPressed: () => _addTerm(term),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        _buildNumericField(
          label: '页数'.tl,
          field: 'pages',
          comparison: _pagesComparison,
          controller: _pagesController,
        ),
        _buildNumericField(
          label: '收藏数'.tl,
          field: 'favorites',
          comparison: _favoritesComparison,
          controller: _favoritesController,
        ),
        _buildNumericField(
          label: '上传日期天数'.tl,
          field: 'uploaded',
          comparison: _uploadedComparison,
          controller: _uploadedController,
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveFiltersSection(),
              _buildFilterEditorSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    widget.onConfirm(_buildParam());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return fluent.ContentDialog(
        title: Text('nhentai 筛选'.tl),
        content: _buildContent(),
        actions: [
          fluent.Button(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'.tl),
          ),
          fluent.FilledButton(
            onPressed: _confirm,
            child: Text('确定'.tl),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('nhentai 筛选'.tl),
      content: _buildContent(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消'.tl),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text('确定'.tl),
        ),
      ],
    );
  }
}
