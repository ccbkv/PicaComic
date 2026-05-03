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
  late final TextEditingController _searchController;
  late final TextEditingController _pagesController;
  late final TextEditingController _favoritesController;
  late final TextEditingController _uploadedController;

  late List<NhentaiFilterTerm> _terms;
  NhentaiNumericCondition? _pages;
  NhentaiNumericCondition? _favorites;
  NhentaiNumericCondition? _uploadedDays;
  String _searchText = '';
  String _pagesComparison = '>=';
  String _favoritesComparison = '>=';
  String _uploadedComparison = '>=';
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
    _pagesComparison = filter.pages?.comparison ?? '>=';
    _favoritesComparison = filter.favorites?.comparison ?? '>=';
    _uploadedComparison = filter.uploadedDays?.comparison ?? '>=';
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
      if (seen.add(term.displayValue.trim().toLowerCase()) &&
          !_terms.contains(term)) {
        matches.add(term);
      }
      if (matches.length >= 10) {
        break;
      }
    }
    return matches;
  }

  List<NhentaiFilterTerm> _buildLocalSuggestions(String query) {
    query = query.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return _mergeSuggestionTerms([
      ..._findLocalSuggestionTerms('tag', nhentaiTags.values, query),
      ..._findLocalSuggestionTerms(
        'character',
        nhentaiCharacterTags.values,
        query,
      ),
      ..._findLocalSuggestionTerms('parody', nhentaiParodyTags.values, query),
      ..._findLocalSuggestionTerms(
        'language',
        const ['chinese', 'japanese', 'english'],
        query,
      ),
    ], const []);
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
    _remoteSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final cancelToken = CancelToken();
      _remoteSearchCancelToken = cancelToken;
      final response = await NhentaiNetwork().autocompleteTagsByTypes(
        query,
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

  @override
  Widget build(BuildContext context) {
    final suggestions = _mergeSuggestionTerms(
      _localSuggestions,
      _remoteSuggestions,
    );
    final searching = _searchText.trim().isNotEmpty;
    final content = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 560,
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
                  _pages == null &&
                  _favorites == null &&
                  _uploadedDays == null)
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
                    if (_pages != null)
                      Chip(
                        label: Text(
                          "${'页数'.tl} ${_pages!.comparison} ${_pages!.value}",
                        ),
                        onDeleted: () => setState(() {
                          _pages = null;
                          _pagesController.clear();
                        }),
                      ),
                    if (_favorites != null)
                      Chip(
                        label: Text(
                          "${'收藏数'.tl} ${_favorites!.comparison} ${_favorites!.value}",
                        ),
                        onDeleted: () => setState(() {
                          _favorites = null;
                          _favoritesController.clear();
                        }),
                      ),
                    if (_uploadedDays != null)
                      Chip(
                        label: Text(
                          "${'上传日期天数'.tl} "
                          "${_uploadedDays!.comparison} ${_uploadedDays!.value}",
                        ),
                        onDeleted: () => setState(() {
                          _uploadedDays = null;
                          _uploadedController.clear();
                        }),
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
                      onPressed: () {
                        final value = _searchController.text.trim();
                        if (value.isEmpty) {
                          return;
                        }
                        final term = NhentaiFilterTerm(
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
                      },
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
                  value = value.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  final term = NhentaiFilterTerm(
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
                            label: Text(term.displayValue),
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
                            label: Text(value),
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
                      width: 132,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('页数'.tl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 72,
                      height: 48,
                      child: DropdownButtonFormField<String>(
                        initialValue: _pagesComparison,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        items: const ['>=', '>', '=', '<', '<=']
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
                          setState(() {
                            _pagesComparison = value;
                            final parsed = int.tryParse(_pagesController.text.trim());
                            _pages = parsed == null
                                ? null
                                : NhentaiNumericCondition(
                                    comparison: value,
                                    value: parsed,
                                  );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
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
                            setState(() {
                              final parsed = int.tryParse(value.trim());
                              _pages = parsed == null
                                  ? null
                                  : NhentaiNumericCondition(
                                      comparison: _pagesComparison,
                                      value: parsed,
                                    );
                            });
                          },
                        ),
                      ),
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
                      width: 132,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('收藏数'.tl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 72,
                      height: 48,
                      child: DropdownButtonFormField<String>(
                        initialValue: _favoritesComparison,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        items: const ['>=', '>', '=', '<', '<=']
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
                          setState(() {
                            _favoritesComparison = value;
                            final parsed =
                                int.tryParse(_favoritesController.text.trim());
                            _favorites = parsed == null
                                ? null
                                : NhentaiNumericCondition(
                                    comparison: value,
                                    value: parsed,
                                  );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
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
                            setState(() {
                              final parsed = int.tryParse(value.trim());
                              _favorites = parsed == null
                                  ? null
                                  : NhentaiNumericCondition(
                                      comparison: _favoritesComparison,
                                      value: parsed,
                                    );
                            });
                          },
                        ),
                      ),
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
                      width: 132,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('上传日期天数'.tl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 72,
                      height: 48,
                      child: DropdownButtonFormField<String>(
                        initialValue: _uploadedComparison,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        items: const ['>=', '>', '=', '<', '<=']
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
                          setState(() {
                            _uploadedComparison = value;
                            final parsed =
                                int.tryParse(_uploadedController.text.trim());
                            _uploadedDays = parsed == null
                                ? null
                                : NhentaiNumericCondition(
                                    comparison: value,
                                    value: parsed,
                                  );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
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
                            setState(() {
                              final parsed = int.tryParse(value.trim());
                              _uploadedDays = parsed == null
                                  ? null
                                  : NhentaiNumericCondition(
                                      comparison: _uploadedComparison,
                                      value: parsed,
                                    );
                            });
                          },
                        ),
                      ),
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
            onPressed: () {
              widget.onConfirm(
                NhentaiCategoryFilter(
                  terms: _terms,
                  pages: _pages,
                  favorites: _favorites,
                  uploadedDays: _uploadedDays,
                ).toParam(),
              );
              Navigator.of(context).pop();
            },
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
          onPressed: () {
            widget.onConfirm(
              NhentaiCategoryFilter(
                terms: _terms,
                pages: _pages,
                favorites: _favorites,
                uploadedDays: _uploadedDays,
              ).toParam(),
            );
            Navigator.of(context).pop();
          },
          child: Text('确定'.tl),
        ),
      ],
    );
  }
}
