import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/network/nhentai_network/tags.dart';
import 'package:pica_comic/utils/tags_translation.dart';
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
  late final TextEditingController _searchController;
  late final TextEditingController _pagesController;
  late final TextEditingController _favoritesController;
  late final TextEditingController _uploadedController;

  late List<NhentaiFilterTerm> _terms;
  late List<NhentaiNumericCondition> _pages;
  late List<NhentaiNumericCondition> _favorites;
  late List<NhentaiNumericCondition> _uploadedDays;
  String _searchText = '';
  String _pagesComparison = '<=';
  String _favoritesComparison = '<=';
  String _uploadedComparison = '<=';
  String _uploadedUnit = 'd';
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
    _pages = List.of(filter.pages);
    _favorites = List.of(filter.favorites);
    _uploadedDays = List.of(filter.uploadedDays);
    _uploadedUnit = _uploadedDays.isEmpty
        ? 'd'
        : (_uploadedDays.first.suffix.isEmpty ? 'd' : _uploadedDays.first.suffix);
    _searchController = TextEditingController();
    _pagesController = TextEditingController();
    _favoritesController = TextEditingController();
    _uploadedController = TextEditingController();
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
      if (seen.add(term.displayValue.trim().toLowerCase())) {
        merged.add(term);
      }
    }
    return merged;
  }

  NhentaiFilterTerm? _resolveInputToKnownTerm(String value) {
    final match = findNhentaiLocalTag(value);
    if (match == null) {
      return null;
    }
    return NhentaiFilterTerm(namespace: match.namespace, value: match.value);
  }

  List<NhentaiFilterTerm> _buildLocalSuggestions(String query) {
    return _mergeSuggestionTerms(
      searchNhentaiLocalTags(query)
          .map(
            (entry) =>
                NhentaiFilterTerm(namespace: entry.namespace, value: entry.value),
          )
          .toList(),
      const [],
    );
  }

  String _displayTermLabel(NhentaiFilterTerm term) {
    if (App.locale.languageCode != 'zh' || term.isRawQuery) {
      return term.displayValue;
    }
    return TagsTranslation.translationTagWithNamespace(
      term.value,
      term.namespace,
    );
  }

  String _displayTagLabel(String value, {String namespace = 'tag'}) {
    if (App.locale.languageCode != 'zh') {
      return value;
    }
    return TagsTranslation.translationTagWithNamespace(value, namespace);
  }

  void _addSearchValue(String value) {
    value = value.trim();
    if (value.isEmpty) {
      return;
    }
    final term =
        _resolveInputToKnownTerm(value) ??
        NhentaiFilterTerm(
          namespace: nhentaiCategoryFilterRawQueryNamespace,
          value: value,
        );
    if (_terms.contains(term)) {
      return;
    }
    setState(() {
      _terms = [..._terms, term];
      _resetSuggestionState();
    });
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
    final remoteQuery = findNhentaiLocalTag(query)?.value ?? query;
    if (remoteQuery.length < 2) {
      _remoteSearchCancelToken = null;
      return;
    }

    final version = ++_remoteSearchVersion;
    _remoteSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final cancelToken = CancelToken();
      _remoteSearchCancelToken = cancelToken;
      final response = await NhentaiNetwork().autocompleteTagsByTypes(
        remoteQuery,
        types: const ['tag', 'character', 'parody', 'artist', 'group'],
        limit: 10,
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

  bool _canAddNumericCondition(
    List<NhentaiNumericCondition> existing,
    String comparison,
    String text,
  ) {
    final value = int.tryParse(text.trim());
    if (value == null || existing.length >= 2) {
      return false;
    }

    final next = NhentaiNumericCondition(comparison: comparison, value: value);
    if (existing.contains(next) || existing.any((it) => it.comparison == '=')) {
      return false;
    }
    if (comparison == '=') {
      return existing.isEmpty;
    }
    if (existing.isEmpty) {
      return true;
    }

    final first = existing.first.comparison;
    final firstIsLower = first == '>=' || first == '>';
    final firstIsUpper = first == '<=' || first == '<';
    if (firstIsLower) {
      return comparison == '<=' || comparison == '<';
    }
    if (firstIsUpper) {
      return comparison == '>=' || comparison == '>';
    }
    return false;
  }

  List<String> _availableNumericComparisons(
    List<NhentaiNumericCondition> existing,
  ) {
    if (existing.any((it) => it.comparison == '=')) {
      return const ['='];
    }
    if (existing.length >= 2) {
      return const [];
    }
    if (existing.isEmpty) {
      return const ['<=', '<', '=', '>=', '>'];
    }

    final first = existing.first.comparison;
    if (first == '>=' || first == '>') {
      return const ['<=', '<'];
    }
    if (first == '<=' || first == '<') {
      return const ['>=', '>'];
    }
    return const ['<=', '<', '=', '>=', '>'];
  }

  String _uploadedUnitLabel(String unit) {
    switch (unit) {
      case 'h':
        return '小时'.tl;
      case 'd':
        return '天'.tl;
      case 'w':
        return '周'.tl;
      case 'm':
        return '月'.tl;
      case 'y':
        return '年'.tl;
      default:
        return unit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _mergeSuggestionTerms(
      _localSuggestions,
      _remoteSuggestions,
    );
    final searching = _searchText.trim().isNotEmpty;
    final canConfirm = _searchController.text.trim().isEmpty;
    final isCompact = MediaQuery.sizeOf(context).width < 480;
    final dialogWidth = (MediaQuery.sizeOf(context).width - 48)
        .clamp(320.0, 560.0)
        .toDouble();
    final filterLabelWidth = isCompact ? 76.0 : 96.0;
    final filterSpacing = isCompact ? 8.0 : 12.0;
    final comparisonWidth = isCompact ? 64.0 : 72.0;
    final comparisonHeight = isCompact ? 44.0 : 48.0;
    final uploadedUnitWidth = isCompact ? 44.0 : 50.0;
    final addButtonStyle = TextButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8, vertical: 8),
    );
    final pagesAvailableComparisons = _availableNumericComparisons(_pages);
    final favoritesAvailableComparisons = _availableNumericComparisons(
      _favorites,
    );
    final uploadedAvailableComparisons = _availableNumericComparisons(
      _uploadedDays,
    );
    final content = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '已选筛选条件'.tl,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _terms.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _terms = [];
                            });
                          },
                    child: Text('清除'.tl),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_terms.isEmpty &&
                  _pages.isEmpty &&
                  _favorites.isEmpty &&
                  _uploadedDays.isEmpty)
                Text('暂无筛选条件'.tl)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._terms.map(
                      (term) => ActionChip(
                        label: Text(
                          term.isRawQuery
                              ? term.value
                              : '${term.namespace}:${term.value}',
                        ),
                        onPressed: () => setState(() {
                          _terms = _terms.where((item) => item != term).toList();
                        }),
                      ),
                    ),
                    ..._pages.map(
                      (condition) => ActionChip(
                        key: ValueKey(
                          'pages-condition-${condition.comparison}-${condition.value}',
                        ),
                        label: Text('pages:${condition.comparison}${condition.value}'),
                        onPressed: () => setState(() {
                          _pages = _pages
                              .where((item) => item != condition)
                              .toList();
                        }),
                      ),
                    ),
                    ..._favorites.map(
                      (condition) => ActionChip(
                        key: ValueKey(
                          'favorites-condition-${condition.comparison}-${condition.value}',
                        ),
                        label: Text('favorites:${condition.comparison}${condition.value}'),
                        onPressed: () => setState(() {
                          _favorites = _favorites
                              .where((item) => item != condition)
                              .toList();
                        }),
                      ),
                    ),
                    ..._uploadedDays.map(
                      (condition) => ActionChip(
                        key: ValueKey(
                          'uploaded-condition-${condition.comparison}-${condition.value}-${condition.suffix}',
                        ),
                        label: Text(
                          'uploaded:${condition.comparison}${condition.value}${condition.suffix}',
                        ),
                        onPressed: () => setState(() {
                          _uploadedDays = _uploadedDays
                              .where((item) => item != condition)
                              .toList();
                        }),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                '筛选条件'.tl,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索标签或输入搜索语法'.tl,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                key: const ValueKey('search-add-button'),
                onPressed: _searchText.trim().isEmpty
                    ? null
                    : () => _addSearchValue(_searchController.text),
                      child: Text('添加搜索'.tl),
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                    _localSuggestions = _buildLocalSuggestions(value);
                    _remoteSuggestions = const [];
                  });
                  _scheduleRemoteSuggestions(value);
                },
                onSubmitted: (value) {
                  _addSearchValue(value);
                },
              ),
              const SizedBox(height: 4),
              Text(
                (searching ? '搜索标签' : '常用标签').tl,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: searching
                    ? suggestions
                        .map(
                          (term) => ActionChip(
                            label: Text(_displayTermLabel(term)),
                            onPressed: () {
                              if (_terms.contains(term)) {
                                return;
                              }
                              setState(() {
                                _terms = [..._terms, term];
                                _resetSuggestionState();
                              });
                            },
                          ),
                        )
                        .toList()
                    : nhentaiTags.values
                        .take(10)
                        .map(
                          (value) => ActionChip(
                            label: Text(_displayTagLabel(value)),
                            onPressed: () {
                              value = value.trim();
                              if (value.isEmpty) {
                                return;
                              }
                              final term = NhentaiFilterTerm(
                                namespace: 'tag',
                                value: value,
                              );
                              if (_terms.contains(term)) {
                                return;
                              }
                              setState(() {
                                _terms = [..._terms, term];
                                _resetSuggestionState();
                              });
                            },
                          ),
                        )
                        .toList(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: filterLabelWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('页数'.tl),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    SizedBox(
                      width: comparisonWidth,
                      height: comparisonHeight,
                      child: PopupMenuButton<String>(
                        key: const ValueKey('pages-comparison-dropdown'),
                        enabled: pagesAvailableComparisons.isNotEmpty,
                        onSelected: (value) {
                          setState(() {
                            _pagesComparison = value;
                          });
                        },
                        itemBuilder: (context) => [
                          for (final value in pagesAvailableComparisons)
                            PopupMenuItem<String>(
                              key: ValueKey('pages-comparison-option-$value'),
                              value: value,
                              child: Text(value),
                            ),
                        ],
                        child: Container(
                          height: comparisonHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_pagesComparison),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          key: const ValueKey('pages-input'),
                          controller: _pagesController,
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
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    TextButton(
                      key: const ValueKey('pages-add-button'),
                      style: addButtonStyle,
                      onPressed: _canAddNumericCondition(
                        _pages,
                        _pagesComparison,
                        _pagesController.text,
                      )
                          ? () {
                              final parsed = int.tryParse(
                                _pagesController.text.trim(),
                              );
                              if (parsed == null) {
                                return;
                              }
                              setState(() {
                                _pages = [
                                  ..._pages,
                                  NhentaiNumericCondition(
                                    comparison: _pagesComparison,
                                    value: parsed,
                                  ),
                                ];
                                _pagesController.clear();
                              });
                            }
                          : null,
                      child: Text('添加'.tl),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: filterLabelWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('收藏数'.tl),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    SizedBox(
                      width: comparisonWidth,
                      height: comparisonHeight,
                      child: PopupMenuButton<String>(
                        key: const ValueKey('favorites-comparison-dropdown'),
                        enabled: favoritesAvailableComparisons.isNotEmpty,
                        onSelected: (value) {
                          setState(() {
                            _favoritesComparison = value;
                          });
                        },
                        itemBuilder: (context) => [
                          for (final value in favoritesAvailableComparisons)
                            PopupMenuItem<String>(
                              key: ValueKey(
                                  'favorites-comparison-option-$value'),
                              value: value,
                              child: Text(value),
                            ),
                        ],
                        child: Container(
                          height: comparisonHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_favoritesComparison),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          key: const ValueKey('favorites-input'),
                          controller: _favoritesController,
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
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    TextButton(
                      key: const ValueKey('favorites-add-button'),
                      style: addButtonStyle,
                      onPressed: _canAddNumericCondition(
                        _favorites,
                        _favoritesComparison,
                        _favoritesController.text,
                      )
                          ? () {
                              final parsed = int.tryParse(
                                _favoritesController.text.trim(),
                              );
                              if (parsed == null) {
                                return;
                              }
                              setState(() {
                                _favorites = [
                                  ..._favorites,
                                  NhentaiNumericCondition(
                                    comparison: _favoritesComparison,
                                    value: parsed,
                                  ),
                                ];
                                _favoritesController.clear();
                              });
                            }
                          : null,
                      child: Text('添加'.tl),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: filterLabelWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('上传日期'.tl),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    SizedBox(
                      width: comparisonWidth,
                      height: comparisonHeight,
                      child: PopupMenuButton<String>(
                        key: const ValueKey('uploaded-comparison-dropdown'),
                        enabled: uploadedAvailableComparisons.isNotEmpty,
                        onSelected: (value) {
                          setState(() {
                            _uploadedComparison = value;
                          });
                        },
                        itemBuilder: (context) => [
                          for (final value in uploadedAvailableComparisons)
                            PopupMenuItem<String>(
                              key:
                                  ValueKey('uploaded-comparison-option-$value'),
                              value: value,
                              child: Text(value),
                            ),
                        ],
                        child: Container(
                          height: comparisonHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_uploadedComparison),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          key: const ValueKey('uploaded-input'),
                          controller: _uploadedController,
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
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    SizedBox(
                      width: uploadedUnitWidth,
                      height: 44,
                      child: PopupMenuButton<String>(
                        key: const ValueKey('uploaded-unit-dropdown'),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          setState(() {
                            _uploadedUnit = value;
                          });
                        },
                        itemBuilder: (context) => [
                          for (final value in const ['h', 'd', 'w', 'm', 'y'])
                            PopupMenuItem<String>(
                              key: ValueKey('uploaded-unit-option-$value'),
                              value: value,
                              child: Text(_uploadedUnitLabel(value)),
                            ),
                        ],
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.only(left: 2, right: 0),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_uploadedUnitLabel(_uploadedUnit)),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: filterSpacing),
                    TextButton(
                      key: const ValueKey('uploaded-add-button'),
                      style: addButtonStyle,
                      onPressed: _canAddNumericCondition(
                        _uploadedDays,
                        _uploadedComparison,
                        _uploadedController.text,
                      )
                          ? () {
                              final parsed = int.tryParse(
                                _uploadedController.text.trim(),
                              );
                              if (parsed == null) {
                                return;
                              }
                              setState(() {
                                _uploadedDays = [
                                  ..._uploadedDays,
                                  NhentaiNumericCondition(
                                    comparison: _uploadedComparison,
                                    value: parsed,
                                    suffix: _uploadedUnit,
                                  ),
                                ];
                                _uploadedController.clear();
                              });
                            }
                          : null,
                      child: Text('添加'.tl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (App.isFluent) {
      return fluent.ContentDialog(
        title: Text('nhentai 筛选'.tl),
        content: content,
        actions: [
          fluent.Button(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'.tl),
          ),
          fluent.FilledButton(
            key: const ValueKey('confirm-button'),
            onPressed: canConfirm
                ? () {
                    widget.onConfirm(
                      NhentaiCategoryFilter(
                        terms: _terms,
                        pages: _pages,
                        favorites: _favorites,
                        uploadedDays: _uploadedDays,
                      ).toParam(),
                    );
                    Navigator.of(context).pop();
                  }
                : null,
            child: Text('确定'.tl),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('nhentai 筛选'.tl),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消'.tl),
        ),
        FilledButton(
          key: const ValueKey('confirm-button'),
          onPressed: canConfirm
              ? () {
                  widget.onConfirm(
                    NhentaiCategoryFilter(
                      terms: _terms,
                      pages: _pages,
                      favorites: _favorites,
                      uploadedDays: _uploadedDays,
                    ).toParam(),
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: Text('确定'.tl),
        ),
      ],
    );
  }
}
