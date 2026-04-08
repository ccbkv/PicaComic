import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/network/app_dio.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/network/custom_download_model.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/hitomi_network/hitomi_download_model.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/network/htmanga_network/ht_download_model.dart';
import 'package:pica_comic/network/nhentai_network/download.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/picacg/comic_page.dart';
import 'package:pica_comic/pages/reader/comic_reading_page.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/io_tools.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/utils/pdf.dart';
import 'package:pica_comic/utils/tags_translation.dart';
import 'package:pica_comic/pages/downloading_page.dart';
import 'package:pica_comic/pages/ehentai/eh_gallery_page.dart';
import 'package:pica_comic/pages/hitomi/hitomi_comic_page.dart';
import 'package:pica_comic/pages/jm/jm_comic_page.dart';
import 'package:pica_comic/pages/nhentai/comic_page.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/network/eh_network/eh_download_model.dart';
import 'package:pica_comic/network/jm_network/jm_download.dart';
import 'package:pica_comic/network/picacg_network/picacg_download_model.dart';
import 'dart:io';
import 'package:pica_comic/utils/show_delayed_dialog.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/components/components.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import 'htmanga/ht_comic_page.dart';

enum DownloadSortType {
  time(0),
  name(1),
  author(2),
  size(3);

  final int value;
  const DownloadSortType(this.value);
}

extension ReadComic on DownloadedItem {
  void read({int? ep}) async {
    final comic = this;
    if (comic.type == DownloadType.picacg) {
      var history =
          await History.findOrCreate((comic as DownloadedComic).comicItem);
      App.globalTo(
        () => ComicReadingPage.picacg(
          comic.id,
          ep ?? history.ep,
          comic.eps,
          comic.name,
          initialPage: ep == null ? history.page : 0,
        ),
      );
    } else if (comic.type == DownloadType.ehentai) {
      var history =
          await History.findOrCreate((comic as DownloadedGallery).gallery);
      App.globalTo(
        () => ComicReadingPage.ehentai(
          (comic).gallery,
          initialPage: ep == null ? history.page : 0,
        ),
      );
    } else if (comic.type == DownloadType.jm) {
      var history =
          await History.findOrCreate((comic as DownloadedJmComic).comic);
      App.globalTo(
        () => ComicReadingPage.jmComic(
          comic.comic,
          ep ?? history.ep,
          initialPage: ep == null ? history.page : 0,
        ),
      );
    } else if (comic.type == DownloadType.hitomi) {
      var history =
          await History.findOrCreate((comic as DownloadedHitomiComic).comic);
      App.globalTo(
        () => ComicReadingPage.hitomi(
          comic.comic,
          comic.link,
          initialPage: ep == null ? history.page : 0,
        ),
      );
    } else if (comic.type == DownloadType.htmanga) {
      var history =
          await History.findOrCreate((comic as DownloadedHtComic).comic);
      App.globalTo(
        () => ComicReadingPage.htmanga(
          comic.comic.id,
          comic.comic.title,
          initialPage: ep == null ? history.page : 0,
        ),
      );
    } else if (comic.type == DownloadType.nhentai) {
      var nc = NhentaiComic(
          comic.id.replaceFirst("nhentai", ""),
          comic.name,
          comic.subTitle,
          (comic as NhentaiDownloadedComic).cover,
          {},
          false,
          [],
          [],
          "");
      var history = await History.findOrCreate(nc);
      App.globalTo(
        () => ComicReadingPage.nhentai(
          comic.id.replaceFirst("nhentai", ""),
          comic.title,
          initialPage: ep == null ? history.page : 0,
        ),
      );
    } else if (comic.type == DownloadType.other) {
      comic as CustomDownloadedItem;
      var data = ComicInfoData(
        name,
        subTitle,
        comic.cover,
        null,
        {},
        null,
        null,
        null,
        0,
        null,
        comic.sourceKey,
        comic.id.replaceFirst("${comic.sourceKey}-", ""),
      );
      var history = await History.findOrCreate(data);
      App.globalTo(
        () => ComicReadingPage(
          CustomReadingData(
            data.target,
            data.title,
            ComicSource.find(comic.sourceKey),
            comic.chapters,
          ),
          ep == null ? history.page : 0,
          ep ?? history.ep,
        ),
      );
    }
  }
}

class DownloadPageLogic extends StateController {
  _CustomTextEditingController? searchController;

  // 初始化搜索控制器
  void initSearchController() {
    searchController = _CustomTextEditingController();
  }

  // 释放资源
  void disposeSearchController() {
    searchController?.dispose();
  }

  ///是否正在加载
  bool loading = true;

  ///是否处于选择状态
  bool selecting = false;

  ///已选择的数量
  int selectedNum = 0;

  ///已选择的漫画
  var selected = <bool>[];

  ///已下载的漫画
  var comics = <DownloadedItem>[];

  var baseComics = <DownloadedItem>[];

  bool searchMode = false;
  bool tagSearchMode = false;
  bool categorySearchMode = false;

  bool searchInit = false;

  ///搜索框的焦点节点
  FocusNode? searchFocusNode;

  String keyword = "";
  String keyword_ = "";
  String tagKeyword = "";
  String tagKeyword_ = "";
  String categoryKeyword = "";
  String categoryKeyword_ = "";

  /// 下载类型筛选
  DownloadType? downloadTypeFilter;

  /// 普通搜索防抖计时器
  Timer? _searchDebounceTimer;

  /// 标签搜索防抖计时器
  Timer? _tagDebounceTimer;

  /// 分类搜索防抖计时器
  Timer? _categoryDebounceTimer;

  /// 防抖延迟时间（毫秒）
  final int _debounceDelay = 300;

  ///分页相关
  int currentPage = 1;
  int pageSize = 20;
  //int pageSize = 4;
  int maxPage = 1;
  String _lastTagKeyword = "";
  String _lastCategoryKeyword = "";

  ///获取当前显示模式（连续或分页）
  bool get isPaginationMode => appdata.settings[25] == "1";

  ///重置分页
  void resetPagination() {
    currentPage = 1;
    maxPage = 1;
  }

  void change() {
    loading = !loading;
    try {
      update();
    } catch (e) {
      //忽视
    }
  }

  void searchByTag() {
    // 添加调试日志
    print('开始执行标签搜索: tagKeyword = $tagKeyword');
    print('搜索前漫画总数: ${baseComics.length}');

    List<DownloadedItem> filteredComics;
    if (tagKeyword.isEmpty) {
      print('标签关键词为空，显示所有漫画');
      filteredComics = List.from(baseComics);
    } else {
      filteredComics = baseComics
          .where((comic) => comic.tags.any((t) =>
              t.toLowerCase().contains(tagKeyword.toLowerCase()) ||
              t.translateTagsToCN
                  .toLowerCase()
                  .contains(tagKeyword.toLowerCase()))) // 支持中英文标签搜索
          .toList();
      print('找到 ${filteredComics.length} 个匹配的漫画');
    }

    // 处理分页
    if (isPaginationMode) {
      if (tagKeyword != _lastTagKeyword) {
        resetPagination();
        _lastTagKeyword = tagKeyword;
      }
      maxPage = (filteredComics.length / pageSize).ceil();
      int startIndex = (currentPage - 1) * pageSize;
      int endIndex = startIndex + pageSize;
      if (endIndex > filteredComics.length) {
        endIndex = filteredComics.length;
      }
      comics = filteredComics.sublist(startIndex, endIndex);
    } else {
      comics = filteredComics;
    }

    // 同步selected数组长度
    resetSelected(comics.length);

    print('重置分页，更新UI');
    update();
  }

  void searchByCategory() {
    // 添加调试日志
    print('开始执行分类搜索: categoryKeyword = $categoryKeyword');
    print('搜索前漫画总数: ${baseComics.length}');

    List<DownloadedItem> filteredComics;
    if (categoryKeyword.isEmpty) {
      print('分类关键词为空，显示所有漫画');
      filteredComics = List.from(baseComics);
    } else {
      filteredComics = baseComics.where((comic) {
        // 检查是否是DownloadedComic类型，如果是，则访问其comicItem.categories
        if (comic is DownloadedComic) {
          return comic.comicItem.categories.any((c) =>
              c.toLowerCase().contains(categoryKeyword.toLowerCase()) ||
              c.translateTagsToCN
                  .toLowerCase()
                  .contains(categoryKeyword.toLowerCase()));
        }
        // 对于其他类型的DownloadedItem，暂时不进行分类搜索
        return false;
      }).toList();
      print('找到 ${filteredComics.length} 个匹配的漫画');
    }

    // 处理分页
    if (isPaginationMode) {
      if (categoryKeyword != _lastCategoryKeyword) {
        resetPagination();
        _lastCategoryKeyword = categoryKeyword;
      }
      maxPage = (filteredComics.length / pageSize).ceil();
      int startIndex = (currentPage - 1) * pageSize;
      int endIndex = startIndex + pageSize;
      if (endIndex > filteredComics.length) {
        endIndex = filteredComics.length;
      }
      comics = filteredComics.sublist(startIndex, endIndex);
    } else {
      comics = filteredComics;
    }

    // 同步selected数组长度
    resetSelected(comics.length);

    print('重置分页，更新UI');
    update();
  }

  void onTagSearchSubmitted(String value) {
    tagKeyword = value;
    searchByTag();
  }

  /// 普通搜索防抖方法
  void _debounceUpdateKeyword(String value) {
    // 如果已有计时器，先取消
    _searchDebounceTimer?.cancel();

    // 创建新的计时器
    _searchDebounceTimer = Timer(Duration(milliseconds: _debounceDelay), () {
      keyword = value;
      find();
    });
  }

  /// 标签搜索防抖方法
  void _debounceUpdateTagKeyword(String value) {
    // 如果已有计时器，先取消
    _tagDebounceTimer?.cancel();

    // 创建新的计时器
    _tagDebounceTimer = Timer(Duration(milliseconds: _debounceDelay), () {
      tagKeyword = value;
      searchByTag();
    });
  }

  /// 分类搜索防抖方法
  void _debounceUpdateCategoryKeyword(String value) {
    // 如果已有计时器，先取消
    _categoryDebounceTimer?.cancel();

    // 创建新的计时器
    _categoryDebounceTimer = Timer(Duration(milliseconds: _debounceDelay), () {
      categoryKeyword = value;
      searchByCategory();
    });
  }

  void find() {
    // 只有在搜索模式下才执行查找
    if (!searchMode) return;

    // 保存旧关键词用于比较
    String oldKeyword = keyword_;

    if (keyword == keyword_) {
      return;
    }
    keyword_ = keyword;
    comics.clear();
    List<DownloadedItem> filteredComics;

    if (keyword == "") {
      filteredComics = baseComics;
    } else {
      filteredComics = [];
      for (var element in baseComics) {
        if (element.name.toLowerCase().contains(keyword) ||
            element.subTitle.toLowerCase().contains(keyword)) {
          filteredComics.add(element);
        }
      }
    }

    // 处理分页
    if (isPaginationMode) {
      if (keyword != oldKeyword) {
        resetPagination();
      }
      maxPage = (filteredComics.length / pageSize).ceil();
      int startIndex = (currentPage - 1) * pageSize;
      int endIndex = startIndex + pageSize;
      if (endIndex > filteredComics.length) {
        endIndex = filteredComics.length;
      }
      comics = filteredComics.sublist(startIndex, endIndex);
    } else {
      comics = filteredComics;
    }

    resetSelected(comics.length);

    // 更新UI
    update();
  }

  @override
  void refresh() {
    searchMode = false;
    selecting = false;
    selectedNum = 0;
    comics.clear();
    resetPagination();

    // 重新初始化selected数组
    resetSelected(comics.length);

    change();
  }

  void resetSelected(int length) {
    selected = List.generate(length, (index) => false);
    selectedNum = 0;
  }

  /// 更新下载类型筛选
  void updateDownloadTypeFilter(DownloadType? type) {
    downloadTypeFilter = type;
    
    // 重置所有搜索状态
    searchMode = false;
    tagSearchMode = false;
    categorySearchMode = false;
    searchInit = false;
    
    // 清空搜索输入框
    searchController?.clear();
    keyword = "";
    tagKeyword = "";
    categoryKeyword = "";
    
    // 重置分页
    resetPagination();
    
    // 重新应用筛选
    applyTypeFilter();
    update();
  }

  /// 应用类型筛选
  void applyTypeFilter() {
    List<DownloadedItem> filteredComics = baseComics;

    // 应用类型筛选
    if (downloadTypeFilter != null) {
      filteredComics = filteredComics.where((comic) => comic.type == downloadTypeFilter).toList();
    }

    // 处理分页
    if (isPaginationMode) {
      maxPage = (filteredComics.length / pageSize).ceil();
      int startIndex = (currentPage - 1) * pageSize;
      int endIndex = startIndex + pageSize;
      if (endIndex > filteredComics.length) {
        endIndex = filteredComics.length;
      }
      comics = filteredComics.sublist(startIndex, endIndex);
    } else {
      comics = filteredComics;
    }

    resetSelected(comics.length);
  }
}

/// 获取下载类型的显示名称
String getDownloadTypeName(DownloadType type) {
  const typeNames = {
    DownloadType.picacg: "哔咔",
    DownloadType.ehentai: "E-Hentai",
    DownloadType.jm: "禁漫",
    DownloadType.hitomi: "Hitomi",
    DownloadType.htmanga: "HTManga",
    DownloadType.nhentai: "nhentai",
    DownloadType.other: "其他",
  };
  return typeNames[type] ?? "";
}

// 自定义文本编辑控制器，用于检测IME输入状态
class _CustomTextEditingController extends TextEditingController {
  bool isComposing = false;

  @override
  set value(TextEditingValue newValue) {
    // 检查是否处于 composing 状态
    isComposing = newValue.composing.isValid &&
        newValue.composing.start < newValue.composing.end;
    super.value = newValue;
  }
}

class LowercaseEnglishInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.split('').map((char) {
      int code = char.codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        // A-Z
        return String.fromCharCode(code + 32);
      }
      return char;
    }).join('');

    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late final DownloadPageLogic logic;

  @override
  void initState() {
    super.initState();
    logic = DownloadPageLogic();
    logic.initSearchController();
  }

  ModalRoute? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.animation?.removeStatusListener(_handleStatusChange);
      _route = route;
      _route?.animation?.addStatusListener(_handleStatusChange);
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      if (App.isFluent) {
        App.mainAppbarActions.value = null;
      }
    }
  }

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_handleStatusChange);
    logic.disposeSearchController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StateBuilder<DownloadPageLogic>(
        init: logic,
        dispose: (logic) {
          if (App.isFluent) {
            App.mainAppbarActions.value = null;
          }
        },
        builder: (logic) {
          if (logic.loading) {
            Future.wait([
              getComics(logic),
              Future.delayed(const Duration(milliseconds: 300))
            ]).then((v) {
              logic.resetSelected(logic.comics.length);
              logic.change();
            });
            if (App.isFluent) {
              return const fluent.ScaffoldPage(
                content: Center(
                  child: fluent.ProgressBar(),
                ),
              );
            }
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else {
            if (App.isFluent) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                var route = ModalRoute.of(context);
                if (mounted && route != null && route.isCurrent) {
                  if (route.animation?.status == AnimationStatus.reverse) {
                    return;
                  }
                  App.mainAppbarActions.value =
                      _buildFluentCommandBar(context, logic);
                }
              });
              return fluent.ScaffoldPage(
                header: fluent.PageHeader(
                  title: (logic.searchMode ||
                          logic.tagSearchMode ||
                          logic.categorySearchMode ||
                          logic.selecting)
                      ? buildTitle(context, logic)
                      : null,
                ),
                content: _buildFluentBody(context, logic),
              );
            }
            return Scaffold(
              floatingActionButton: buildFAB(context, logic),
              body: SmoothCustomScrollView(
                slivers: [
                  buildAppbar(context, logic),
                  if (logic.isPaginationMode)
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          FilledButton(
                            onPressed: logic.currentPage > 1
                                ? () {
                                    logic.currentPage--;
                                    getComics(logic).then((_) {
                                      logic.resetSelected(logic.comics.length);
                                      logic.update();
                                    });
                                  }
                                : null,
                            child: Text("后退".tl),
                          ).fixWidth(84),
                          Expanded(
                            child: Center(
                              child: Material(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    int? page = await showDialog<int>(
                                      context: context,
                                      builder: (context) {
                                        TextEditingController controller =
                                            TextEditingController(
                                                text: logic.currentPage.toString());
                                        return ContentDialog(
                                          title: "输入页码".tl,
                                          content: TextField(
                                            controller: controller,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: "页码".tl,
                                              hintText: "1-${logic.maxPage}",
                                            ),
                                            inputFormatters: <TextInputFormatter>[
                                              FilteringTextInputFormatter.digitsOnly
                                            ],
                                          ).paddingHorizontal(16),
                                          actions: [
                                            Button.filled(
                                              onPressed: () {
                                                int? p = int.tryParse(controller.text);
                                                if (p != null && p >= 1 && p <= logic.maxPage) {
                                                  Navigator.pop(context, p);
                                                } else {
                                                  showToast(message: "页码无效".tl);
                                                }
                                              },
                                              child: Text("确认".tl),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (page != null) {
                                      logic.currentPage = page;
                                      getComics(logic).then((_) {
                                        logic.resetSelected(logic.comics.length);
                                        logic.update();
                                      });
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Text("${"页面".tl} ${logic.currentPage} / ${logic.maxPage}"),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: logic.currentPage < logic.maxPage
                                ? () {
                                    logic.currentPage++;
                                    getComics(logic).then((_) {
                                      logic.resetSelected(logic.comics.length);
                                      logic.update();
                                    });
                                  }
                                : null,
                            child: Text("前进".tl),
                          ).fixWidth(84),
                        ],
                      ).paddingVertical(8).paddingHorizontal(16),
                    ),
                  buildComicsSliver(context, logic),
                  if (logic.isPaginationMode)
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          FilledButton(
                            onPressed: logic.currentPage > 1
                                ? () {
                                    logic.currentPage--;
                                    getComics(logic).then((_) {
                                      logic.resetSelected(logic.comics.length);
                                      logic.update();
                                    });
                                  }
                                : null,
                            child: Text("后退".tl),
                          ).fixWidth(84),
                          Expanded(
                            child: Center(
                              child: Material(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    int? page = await showDialog<int>(
                                      context: context,
                                      builder: (context) {
                                        TextEditingController controller =
                                            TextEditingController(
                                                text: logic.currentPage.toString());
                                        return ContentDialog(
                                          title: "输入页码".tl,
                                          content: TextField(
                                            controller: controller,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: "页码".tl,
                                              hintText: "1-${logic.maxPage}",
                                            ),
                                            inputFormatters: <TextInputFormatter>[
                                              FilteringTextInputFormatter.digitsOnly
                                            ],
                                          ).paddingHorizontal(16),
                                          actions: [
                                            Button.filled(
                                              onPressed: () {
                                                int? p = int.tryParse(controller.text);
                                                if (p != null && p >= 1 && p <= logic.maxPage) {
                                                  Navigator.pop(context, p);
                                                } else {
                                                  showToast(message: "页码无效".tl);
                                                }
                                              },
                                              child: Text("确认".tl),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (page != null) {
                                      logic.currentPage = page;
                                      getComics(logic).then((_) {
                                        logic.resetSelected(logic.comics.length);
                                        logic.update();
                                      });
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Text("${"页面".tl} ${logic.currentPage} / ${logic.maxPage}"),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: logic.currentPage < logic.maxPage
                                ? () {
                                    logic.currentPage++;
                                    getComics(logic).then((_) {
                                      logic.resetSelected(logic.comics.length);
                                      logic.update();
                                    });
                                  }
                                : null,
                            child: Text("前进".tl),
                          ).fixWidth(84),
                        ],
                      ).paddingVertical(8).paddingHorizontal(16),
                    ),
                ],
              ),
            );
          }
        });
  }

  Widget _buildFluentBody(BuildContext context, DownloadPageLogic logic) {
    return CustomScrollView(
      slivers: [
        if (logic.isPaginationMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  fluent.Button(
                    onPressed: logic.currentPage > 1
                        ? () {
                            logic.currentPage--;
                            getComics(logic).then((_) {
                              logic.resetSelected(logic.comics.length);
                              logic.update();
                            });
                          }
                        : null,
                    child: Text("后退".tl),
                  ),
                  const SizedBox(width: 16),
                  Text("${"页面".tl}: ${logic.currentPage}/${logic.maxPage}"),
                  const SizedBox(width: 16),
                  fluent.Button(
                    onPressed: logic.currentPage < logic.maxPage
                        ? () {
                            logic.currentPage++;
                            getComics(logic).then((_) {
                              logic.resetSelected(logic.comics.length);
                              logic.update();
                            });
                          }
                        : null,
                    child: Text("前进".tl),
                  ),
                ],
              ),
            ),
          ),
        buildComicsSliver(context, logic),
        if (logic.isPaginationMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  fluent.Button(
                    onPressed: logic.currentPage > 1
                        ? () {
                            logic.currentPage--;
                            getComics(logic).then((_) {
                              logic.resetSelected(logic.comics.length);
                              logic.update();
                            });
                          }
                        : null,
                    child: Text("后退".tl),
                  ),
                  const SizedBox(width: 16),
                  Text("${"页面".tl}: ${logic.currentPage}/${logic.maxPage}"),
                  const SizedBox(width: 16),
                  fluent.Button(
                    onPressed: logic.currentPage < logic.maxPage
                        ? () {
                            logic.currentPage++;
                            getComics(logic).then((_) {
                              logic.resetSelected(logic.comics.length);
                              logic.update();
                            });
                          }
                        : null,
                    child: Text("前进".tl),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        )
      ],
    );
  }

  Widget _buildFluentCommandBar(BuildContext context, DownloadPageLogic logic) {
    if (logic.selecting) {
      return fluent.CommandBar(
        mainAxisAlignment: MainAxisAlignment.end,
        primaryItems: [
          fluent.CommandBarButton(
            icon: const Icon(fluent.FluentIcons.select_all),
            label: Text("全选".tl),
            onPressed: () {
              for (int i = 0; i < logic.selected.length; i++) {
                logic.selected[i] = true;
              }
              logic.selectedNum = logic.comics.length;
              logic.update();
            },
          ),
          fluent.CommandBarButton(
            icon: const Icon(fluent.FluentIcons.delete),
            label: Text("删除".tl),
            onPressed: () {
              if (logic.selectedNum == 0) return;
              fluent.showDialog(
                context: context,
                builder: (dialogContext) {
                  return fluent.ContentDialog(
                    title: Text("删除".tl),
                    content: Text("要删除已选择的项目吗? 此操作无法撤销".tl),
                    actions: [
                      fluent.Button(
                          onPressed: () => App.globalBack(),
                          child: Text("取消".tl)),
                      fluent.FilledButton(
                          onPressed: () async {
                            App.globalBack();
                            var comics = <String>[];
                            for (int i = 0; i < logic.selected.length; i++) {
                              if (logic.selected[i]) {
                                comics.add(logic.comics[i].id);
                              }
                            }
                            await downloadManager.delete(comics);
                            logic.refresh();
                            StateController.findOrNull(tag: "me_page_downloads")
                                ?.update();
                          },
                          child: Text("确认".tl)),
                    ],
                  );
                },
              );
            },
          ),
          fluent.CommandBarButton(
            icon: const Icon(fluent.FluentIcons.cancel),
            label: Text("取消".tl),
            onPressed: () {
              logic.selecting = false;
              logic.selectedNum = 0;
              for (int i = 0; i < logic.selected.length; i++) {
                logic.selected[i] = false;
              }
              logic.update();
            },
          ),
          fluent.CommandBarButton(
            icon: const Icon(fluent.FluentIcons.more),
            label: Text("更多".tl),
            onPressed: () {
              // TODO: Implement more options for Fluent UI
            },
          ),
        ],
      );
    }

    return fluent.CommandBar(
      mainAxisAlignment: MainAxisAlignment.end,
      primaryItems: [
        fluent.CommandBarButton(
          icon: const Icon(fluent.FluentIcons.search),
          label: Text(logic.categorySearchMode
              ? "分类搜索".tl
              : (logic.tagSearchMode ? "标签搜索".tl : "搜索".tl)),
          onPressed: () {
            if (logic.categorySearchMode) {
              logic.categorySearchMode = false;
              logic.searchMode = true;
              logic.tagSearchMode = false;
              logic.searchInit = true;
              logic.searchController?.text = logic.keyword;
              logic.searchController?.selection = TextSelection.fromPosition(
                TextPosition(offset: logic.keyword.length),
              );
              logic.find();
              logic.update();
            } else if (logic.tagSearchMode) {
              logic.tagSearchMode = false;
              logic.searchMode = true;
              logic.searchInit = true;
              logic.searchController?.text = logic.keyword;
              logic.searchController?.selection = TextSelection.fromPosition(
                TextPosition(offset: logic.keyword.length),
              );
              logic.find();
              logic.update();
            } else if (logic.searchMode) {
              logic.searchMode = false;
              logic.searchInit = false;
              logic.searchController?.clear();
              logic.keyword = '';
              logic.update();
            } else {
              logic.searchMode = true;
              logic.searchInit = true;
              logic.searchController?.text = logic.keyword;
              logic.searchController?.selection = TextSelection.fromPosition(
                TextPosition(offset: logic.keyword.length),
              );
              logic.find();
              logic.update();
            }
          },
        ),
        fluent.CommandBarButton(
          icon: const Icon(fluent.FluentIcons.tag),
          label: Text("标签搜索".tl),
          onPressed: () {
            if (!logic.tagSearchMode) {
              logic.tagSearchMode = true;
              logic.searchMode = false;
              logic.searchInit = true;
              logic.searchController?.text = logic.tagKeyword;
              logic.searchController?.selection = TextSelection.fromPosition(
                TextPosition(offset: logic.tagKeyword.length),
              );
              logic.searchByTag();
            } else {
              logic.tagSearchMode = false;
              logic.searchMode = false;
              logic.selected =
                  List.generate(logic.comics.length, (index) => false);
              logic.selectedNum = 0;
              logic.searchController?.text = '';
              logic.update();
            }
          },
        ),
        fluent.CommandBarButton(
          icon: const Icon(Icons.category_outlined),
          label: Text("分类搜索".tl),
          onPressed: () {
            if (!logic.categorySearchMode) {
              logic.categorySearchMode = true;
              logic.searchMode = false;
              logic.tagSearchMode = false;
              logic.searchInit = true;
              logic.searchController?.text = logic.categoryKeyword;
              logic.searchController?.selection = TextSelection.fromPosition(
                TextPosition(offset: logic.categoryKeyword.length),
              );
              logic.searchByCategory();
            } else {
              logic.categorySearchMode = false;
              logic.searchMode = false;
              logic.tagSearchMode = false;
              logic.selected =
                  List.generate(logic.comics.length, (index) => false);
              logic.selectedNum = 0;
              logic.searchController?.text = '';
              logic.update();
            }
          },
        ),
        fluent.CommandBarButton(
          icon: const Icon(fluent.FluentIcons.sort),
          label: Text("排序".tl),
          onPressed: () async {
            bool changed = false;
            await showDelayedDialog(
              context: context,
              builder: (context) => fluent.ContentDialog(
                title: Text("漫画排序模式".tl),
                content: SizedBox(
                  height: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("漫画排序模式".tl),
                          const Spacer(),
                          fluent.ComboBox<int>(
                            value: int.parse(appdata.settings[26][0]),
                            items: ["时间", "漫画名", "作者名", "大小"]
                                .tl
                                .asMap()
                                .entries
                                .map((e) => fluent.ComboBoxItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ))
                                .toList(),
                            onChanged: (i) {
                              if (i != null) {
                                appdata.settings[26] = appdata.settings[26]
                                    .setValueAt(i.toString(), 0);
                                appdata.updateSettings();
                                changed = true;
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      fluent.ToggleSwitch(
                        checked: appdata.settings[26][1] == "1",
                        content: Text("倒序".tl),
                        onChanged: (b) {
                          if (b) {
                            appdata.settings[26] =
                                appdata.settings[26].setValueAt("1", 1);
                          } else {
                            appdata.settings[26] =
                                appdata.settings[26].setValueAt("0", 1);
                          }
                          appdata.updateSettings();
                          changed = true;
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  fluent.Button(
                    onPressed: () => Navigator.pop(context),
                    child: Text("取消".tl),
                  ),
                ],
              ),
            );
            if (changed) {
              logic.refresh();
            }
          },
        ),
        fluent.CommandBarButton(
          icon: const Icon(fluent.FluentIcons.download),
          label: Text("下载管理".tl),
          onPressed: () {
            showPopUpWidget(
              App.globalContext!,
              const DownloadingPage(),
            );
          },
        ),
        fluent.CommandBarButton(
          icon: const Icon(fluent.FluentIcons.multi_select),
          label: Text("多选".tl),
          onPressed: () {
            logic.selecting = true;
            logic.update();
          },
        ),
      ],
    );
  }

  Widget buildComicsSliver(BuildContext context, DownloadPageLogic logic) {
    logic.find();
    final comics = logic.comics;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithComics(),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return buildItem(context, logic, index);
        },
        childCount: comics.length,
      ),
    );
  }

  Future<void> getComics(DownloadPageLogic logic) async {
    var order = '', direction = 'desc';
    switch (appdata.settings[26][0]) {
      case "0":
        order = 'time';
      case "1":
        order = 'title';
      case "2":
        order = 'subtitle';
      case "3":
        order = 'size';
      default:
        throw UnimplementedError();
    }
    if (appdata.settings[26][1] == "1") {
      direction = 'asc';
    }
    logic.baseComics = DownloadManager().getAll(order, direction);

    // 处理分页
    if (logic.isPaginationMode) {
      // 使用完整的搜索结果计算分页
      List<DownloadedItem> fullResultComics;
      if (logic.tagSearchMode) {
        // 标签搜索模式下使用标签搜索结果
        if (logic.tagKeyword.isEmpty) {
          fullResultComics = logic.baseComics;
        } else {
          fullResultComics = logic.baseComics
              .where((comic) => comic.tags.any((t) =>
                  t.toLowerCase().contains(logic.tagKeyword.toLowerCase()) ||
                  t.translateTagsToCN
                      .toLowerCase()
                      .contains(logic.tagKeyword.toLowerCase()))) // 支持中英文标签搜索
              .toList();
        }
      } else if (logic.categorySearchMode) {
        // 分类搜索模式下使用分类搜索结果
        if (logic.categoryKeyword.isEmpty) {
          fullResultComics = logic.baseComics;
        } else {
          fullResultComics = logic.baseComics.where((comic) {
            // 检查是否是DownloadedComic类型，如果是，则访问其comicItem.categories
            if (comic is DownloadedComic) {
              return comic.comicItem.categories.any((c) =>
                  c
                      .toLowerCase()
                      .contains(logic.categoryKeyword.toLowerCase()) ||
                  c.translateTagsToCN
                      .toLowerCase()
                      .contains(logic.categoryKeyword.toLowerCase()));
            }
            // 对于其他类型的DownloadedItem，暂时不进行分类搜索
            return false;
          }).toList();
        }
      } else if (logic.searchMode) {
        // 普通搜索模式下使用普通搜索结果
        if (logic.keyword.isEmpty) {
          fullResultComics = logic.baseComics;
        } else {
          fullResultComics = logic.baseComics
              .where((comic) =>
                  comic.name
                      .toLowerCase()
                      .contains(logic.keyword.toLowerCase()) ||
                  comic.subTitle
                      .toLowerCase()
                      .contains(logic.keyword.toLowerCase()))
              .toList();
        }
      } else {
        // 默认使用所有漫画
        if (logic.downloadTypeFilter != null) {
          fullResultComics = logic.baseComics
              .where((element) => element.type == logic.downloadTypeFilter)
              .toList();
        } else {
          fullResultComics = logic.baseComics;
        }
      }

      // 计算最大页数
      logic.maxPage = (fullResultComics.length / logic.pageSize).ceil();

      // 确保当前页码不超出范围
      if (logic.currentPage > logic.maxPage) {
        logic.currentPage = logic.maxPage > 0 ? logic.maxPage : 1;
      }

      // 计算当前页数据范围
      int startIndex = (logic.currentPage - 1) * logic.pageSize;
      int endIndex = startIndex + logic.pageSize;
      if (endIndex > fullResultComics.length) {
        endIndex = fullResultComics.length;
      }

      // 更新当前页数据
      logic.comics = fullResultComics.sublist(startIndex, endIndex);
    } else {
      // 非分页模式下的搜索处理
      if (logic.tagSearchMode) {
        // 标签搜索模式下使用标签搜索结果
        if (logic.tagKeyword.isEmpty) {
          logic.comics = logic.baseComics.toList();
        } else {
          logic.comics = logic.baseComics
              .where((comic) => comic.tags.any((t) =>
                  t.toLowerCase().contains(logic.tagKeyword.toLowerCase()) ||
                  t.translateTagsToCN
                      .toLowerCase()
                      .contains(logic.tagKeyword.toLowerCase()))) // 支持中英文标签搜索
              .toList();
        }
      } else if (logic.categorySearchMode) {
        // 分类搜索模式下使用分类搜索结果
        if (logic.categoryKeyword.isEmpty) {
          logic.comics = logic.baseComics.toList();
        } else {
          logic.comics = logic.baseComics.where((comic) {
            // 检查是否是DownloadedComic类型，如果是，则访问其comicItem.categories
            if (comic is DownloadedComic) {
              return comic.comicItem.categories.any((c) =>
                  c
                      .toLowerCase()
                      .contains(logic.categoryKeyword.toLowerCase()) ||
                  c.translateTagsToCN
                      .toLowerCase()
                      .contains(logic.categoryKeyword.toLowerCase()));
            }
            // 对于其他类型的DownloadedItem，暂时不进行分类搜索
            return false;
          }).toList();
        }
      } else if (logic.searchMode) {
        // 普通搜索模式下使用普通搜索结果
        if (logic.keyword.isEmpty) {
          logic.comics = logic.baseComics.toList();
        } else {
          logic.comics = logic.baseComics
              .where((comic) =>
                  comic.name
                      .toLowerCase()
                      .contains(logic.keyword.toLowerCase()) ||
                  comic.subTitle
                      .toLowerCase()
                      .contains(logic.keyword.toLowerCase()))
              .toList();
        }
      } else {
        // 默认使用所有漫画
        logic.comics = logic.baseComics.toList();
      }
    }

    // 重新初始化selected数组，确保其长度与当前显示的comics数组长度一致
    logic.resetSelected(logic.comics.length);
  }

  Future<void> export(DownloadPageLogic logic) async {
    var comics = <DownloadedItem>[];
    for (int i = 0; i < logic.selected.length; i++) {
      if (logic.selected[i]) {
        comics.add(logic.comics[i]);
      }
    }
    if (comics.isEmpty) {
      return;
    }
    bool res;
    if (comics.length > 1) {
      res = await exportComics(comics);
    } else {
      res = await exportComic(
          comics.first.id, comics.first.name, comics.first.eps);
    }
    App.globalBack();
    if (!res) {
      showToast(message: "导出失败".tl);
    }
  }

  void downloadFont() async {
    bool canceled = false;
    var cancelToken = CancelToken();
    var controller = showLoadingDialog(
      App.globalContext!,
      onCancel: () {
        canceled = true;
        cancelToken.cancel();
      },
      barrierDismissible: false,
      allowCancel: true,
      message: "Downloading",
    );
    var dio = logDio();
    try {
      await dio.download(
        "https://raw.githubusercontent.com/ccbkv/PicaComic/master/fonts/NotoSansSC-Regular.ttf",
        "${App.dataPath}/font.ttf",
        cancelToken: cancelToken,
      );
    } catch (e) {
      showToast(message: "下载失败".tl);
      controller.close();
      return;
    }
    if (!canceled) {
      controller.close();
      showToast(message: "下载完成".tl);
    }
  }

  void exportAsPdf(DownloadedItem? comic, DownloadPageLogic logic) async {
    if (comic == null) {
      for (int i = 0; i < logic.selected.length; i++) {
        if (logic.selected[i]) {
          comic = logic.comics[i];
        }
      }
    }
    if (comic == null) {
      showToast(message: "请选择一个漫画".tl);
      return;
    }
    var file = File("${App.dataPath}/font.ttf");
    if (!App.isWindows && !await file.exists()) {
      showConfirmDialog(
        context: App.globalContext!,
        title: "缺少字体".tl,
        content: "需要下载字体文件(10.1MB), 是否继续?".tl,
        onConfirm: downloadFont,
      );
    } else {
      bool canceled = false;
      var controller = showLoadingDialog(
        App.globalContext!,
        onCancel: () => canceled = true,
        allowCancel: false,
      );
      var fileName = "${comic.name}.pdf";
      fileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      await createPdfFromComicWithIsolate(
          title: comic.name,
          comicPath:
              "${downloadManager.path}/${downloadManager.getDirectory(comic.id)}",
          savePath: "${App.cachePath}/$fileName",
          chapters: comic.eps,
          chapterIndexes: comic.downloadedEps);
      if (!canceled) {
        controller.close();
        await exportPdf("${App.cachePath}/$fileName");
      }
    }
  }

  Widget buildItem(BuildContext context, DownloadPageLogic logic, int index) {
    // 添加边界检查以防止越界访问
    if (index < 0 ||
        index >= logic.selected.length ||
        index >= logic.comics.length) {
      // 如果索引越界，返回一个空的容器
      return const SizedBox.shrink();
    }

    bool selected = logic.selected[index];
    var type = logic.comics[index].type.name;
    if (logic.comics[index].type == DownloadType.other) {
      type = (logic.comics[index] as CustomDownloadedItem).sourceName;
    }

    // 获取分类信息
    List<String>? categories;
    if (logic.comics[index].type == DownloadType.picacg) {
      categories =
          (logic.comics[index] as DownloadedComic).comicItem.categories;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(16))),
        child: DownloadedComicTile(
          name: logic.comics[index].name,
          author: logic.comics[index].subTitle,
          imagePath: downloadManager.getCover(logic.comics[index].id),
          type: type,
          tag: logic.comics[index].tags,
          category: categories,
          onTap: () async {
            // 再次检查边界，防止在异步操作期间数组发生变化
            if (index < 0 ||
                index >= logic.selected.length ||
                index >= logic.comics.length) {
              return;
            }

            if (logic.selecting) {
              logic.selected[index] = !logic.selected[index];
              logic.selected[index] ? logic.selectedNum++ : logic.selectedNum--;
              if (logic.selectedNum == 0) {
                logic.selecting = false;
              }
              logic.update();
            } else {
              showInfo(index, logic, context);
            }
          },
          size: () {
            // 添加边界检查
            if (index < 0 || index >= logic.comics.length) {
              return "未知大小".tl;
            }

            if (logic.comics[index].comicSize != null) {
              return logic.comics[index].comicSize!.toStringAsFixed(2);
            } else {
              return "未知大小".tl;
            }
          }.call(),
          onLongTap: () {
            // 添加边界检查
            if (index < 0 ||
                index >= logic.selected.length ||
                index >= logic.comics.length) {
              return;
            }

            if (logic.selecting) return;
            logic.selected[index] = true;
            logic.selectedNum++;
            logic.selecting = true;
            logic.update();
          },
          onSecondaryTap: (details) {
            // 添加边界检查
            if (index < 0 ||
                index >= logic.selected.length ||
                index >= logic.comics.length) {
              return;
            }

            showDesktopMenu(App.globalContext!,
                Offset(details.globalPosition.dx, details.globalPosition.dy), [
              DesktopMenuEntry(
                text: "阅读".tl,
                onClick: () {
                  logic.comics[index].read();
                },
              ),
                  DesktopMenuEntry(
                    text: "删除".tl,
                    onClick: () {
                      showConfirmDialog(
                        context: context,
                        title: "确认删除".tl,
                        content: "此操作无法撤销, 是否继续?".tl,
                        onConfirm: () {
                          downloadManager.delete([logic.comics[index].id]);
                          logic.comics.removeAt(index);
                          logic.selected.removeAt(index);
                          logic.update();
                          StateController.findOrNull(tag: "me_page_downloads")
                              ?.update();
                        },
                      );
                    },
                  ),
              DesktopMenuEntry(
                text: "导出".tl,
                onClick: () =>
                    Future.delayed(const Duration(milliseconds: 200), () {
                  Future<void>.delayed(
                    const Duration(milliseconds: 200),
                    () => showDialog(
                      context: App.globalContext!,
                      barrierDismissible: false,
                      barrierColor: Colors.black26,
                      builder: (context) => SimpleDialog(
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: SizedBox(
                                width: 50,
                                height: 80,
                                child: Column(
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    const CircularProgressIndicator(),
                                    const SizedBox(
                                      height: 9,
                                    ),
                                    Text("打包中".tl)
                                  ],
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                  Future<void>.delayed(const Duration(milliseconds: 500),
                      () async {
                    var res = await exportComic(logic.comics[index].id,
                        logic.comics[index].name, logic.comics[index].eps);
                    App.globalBack();
                    if (res) {
                      //忽视
                    } else {
                      showToast(message: "导出失败".tl);
                    }
                  });
                }),
              ),
              DesktopMenuEntry(
                text: "导出为pdf".tl,
                onClick: () {
                  exportAsPdf(logic.comics[index], logic);
                },
              ),
              DesktopMenuEntry(
                text: "查看漫画详情".tl,
                onClick: () {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    toComicInfoPage(logic.comics[index]);
                  });
                },
              ),
              DesktopMenuEntry(
                text: "复制路径".tl,
                onClick: () {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    var path =
                        "${downloadManager.path}/${downloadManager.getDirectory(logic.comics[index].id)}";
                    Clipboard.setData(ClipboardData(text: path));
                  });
                },
              ),
            ]);
          },
        ),
      ),
    );
  }

  void toComicInfoPage(DownloadedItem comic) => _toComicInfoPage(comic);

  void showInfo(int index, DownloadPageLogic logic, BuildContext context) {
    if (UiMode.m1(context)) {
      showModalBottomSheet(
          context: context,
          builder: (context) {
            return DownloadedComicInfoView(logic.comics[index], logic);
          });
    } else {
      showSideBar(App.globalContext!,
          DownloadedComicInfoView(logic.comics[index], logic));
    }
  }

  Widget buildFAB(BuildContext context, DownloadPageLogic logic) =>
      FloatingActionButton(
        enableFeedback: true,
        onPressed: () {
          if (!logic.selecting) {
            logic.selecting = true;
            logic.update();
          } else {
            if (logic.selectedNum == 0) return;
            showConfirmDialog(
              context: context,
              title: "删除".tl,
              content: "要删除已选择的项目吗? 此操作无法撤销".tl,
              btnColor: context.colorScheme.error,
              onConfirm: () async {
                var comics = <String>[];
                for (int i = 0; i < logic.selected.length; i++) {
                  if (logic.selected[i]) {
                    comics.add(logic.comics[i].id);
                  }
                }
                await downloadManager.delete(comics);
                logic.refresh();
                StateController.findOrNull(tag: "me_page_downloads")?.update();
              },
            );
          }
        },
        child: logic.selecting
            ? const Icon(Icons.delete_forever_outlined)
            : const Icon(Icons.checklist_outlined),
      );

  Widget buildTitle(BuildContext context, DownloadPageLogic logic) {
    if ((logic.searchMode || logic.tagSearchMode || logic.categorySearchMode) &&
        !logic.selecting) {
      // 使用一个持久化的focusNode，避免每次build都创建新的
      // 控制器已经在State初始化时创建

      // 同步控制器文本内容
      final currentText = logic.searchMode
          ? logic.keyword
          : (logic.tagSearchMode ? logic.tagKeyword : logic.categoryKeyword);
      if (logic.searchController?.text != currentText) {
        logic.searchController?.text = currentText;
        logic.searchController?.selection = TextSelection.fromPosition(
          TextPosition(offset: currentText.length),
        );
      }

      if (logic.searchFocusNode == null) {
        logic.searchFocusNode = FocusNode();
      }
      // 只在初始进入搜索模式时请求焦点
      if (logic.searchInit) {
        logic.searchFocusNode?.requestFocus();
        logic.searchInit = false;
      }

      if (App.isFluent) {
        return fluent.TextBox(
          focusNode: logic.searchFocusNode,
          placeholder: logic.searchMode
              ? "搜索漫画名".tl
              : (logic.tagSearchMode ? "搜索标签".tl : "搜索分类".tl),
          controller: logic.searchController,
          inputFormatters: [LowercaseEnglishInputFormatter()],
          onChanged: (s) {
            if (!logic.searchController!.isComposing) {
              if (logic.searchMode) {
                logic._debounceUpdateKeyword(s);
              } else if (logic.tagSearchMode) {
                logic._debounceUpdateTagKeyword(s);
              } else {
                logic._debounceUpdateCategoryKeyword(s);
              }
            }
          },
          onSubmitted: (s) {
            if (logic.searchMode) {
              logic.keyword = s;
              logic.find();
            } else if (logic.tagSearchMode) {
              logic.tagKeyword = s;
              logic.searchByTag();
            } else {
              logic.categoryKeyword = s;
              logic.searchByCategory();
            }
          },
        );
      }

      return TextField(
        focusNode: logic.searchFocusNode,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: logic.searchMode
              ? "搜索漫画名".tl
              : (logic.tagSearchMode ? "搜索标签".tl : "搜索分类".tl),
        ),
        controller: logic.searchController,
        inputFormatters: [LowercaseEnglishInputFormatter()],
        onChanged: (s) {
          // 只有当输入完成（非 composing 状态）时才更新关键词
          if (!logic.searchController!.isComposing) {
            if (logic.searchMode) {
              logic._debounceUpdateKeyword(s);
            } else if (logic.tagSearchMode) {
              print('标签搜索模式下更新关键词: $s');
              logic._debounceUpdateTagKeyword(s);
            } else {
              print('分类搜索模式下更新关键词: $s');
              logic._debounceUpdateCategoryKeyword(s);
            }
          }
        },
        onSubmitted: (s) {
          if (logic.searchMode) {
            logic.keyword = s;
            logic.find();
          } else if (logic.tagSearchMode) {
            print('标签搜索模式下提交搜索: $s');
            logic.tagKeyword = s;
            logic.searchByTag();
          } else {
            print('分类搜索模式下提交搜索: $s');
            logic.categoryKeyword = s;
            logic.searchByCategory();
          }
        },
      );
    } else {
      return logic.selecting
          ? Text("已选择 @num 个项目".tlParams({"num": logic.selectedNum.toString()}))
          : Text("已下载".tl);
    }
  }

  Widget buildAppbar(BuildContext context, DownloadPageLogic logic) {
    return SliverAppbar(
      radius: UiMode.m1(context) ? 0 : 16,
      color: logic.selecting
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      leading: logic.selecting
          ? IconButton(
              onPressed: () {
                logic.selecting = false;
                logic.selectedNum = 0;
                for (int i = 0; i < logic.selected.length; i++) {
                  logic.selected[i] = false;
                }
                logic.update();
              },
              icon: const Icon(Icons.close))
          : IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back)),
      title: buildTitle(context, logic),
      actions: buildActions(context, logic),
    );
  }

  List<Widget> buildActions(BuildContext context, DownloadPageLogic logic) {
    List<Widget> actions = [];

    // 添加排序和下载管理器按钮
    if (!logic.selecting && !logic.searchMode) {
      actions.add(
        Tooltip(
          message: "排序".tl,
          child: IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () async {
              bool changed = false;
              var sortType = DownloadSortType.values[int.parse(appdata.settings[26][0])];
              await showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(builder: (context, setState) {
                    return ContentDialog(
                      title: "漫画排序模式".tl,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioGroup<DownloadSortType>(
                            groupValue: sortType,
                            onChanged: (v) {
                              setState(() {
                                sortType = v ?? sortType;
                              });
                            },
                            child: Column(
                              children: [
                                RadioListTile<DownloadSortType>(
                                  title: Text("时间".tl),
                                  value: DownloadSortType.time,
                                ),
                                RadioListTile<DownloadSortType>(
                                  title: Text("漫画名".tl),
                                  value: DownloadSortType.name,
                                ),
                                RadioListTile<DownloadSortType>(
                                  title: Text("作者名".tl),
                                  value: DownloadSortType.author,
                                ),
                                RadioListTile<DownloadSortType>(
                                  title: Text("大小".tl),
                                  value: DownloadSortType.size,
                                ),
                              ],
                            ),
                          ),
                          ListTile(
                            title: Text("倒序".tl),
                            trailing: StatefulSwitch(
                              initialValue: appdata.settings[26][1] == "1",
                              onChanged: (b) {
                                if (b) {
                                  appdata.settings[26] = appdata.settings[26].setValueAt("1", 1);
                                } else {
                                  appdata.settings[26] = appdata.settings[26].setValueAt("0", 1);
                                }
                                appdata.updateSettings();
                                changed = true;
                              },
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        FilledButton(
                          onPressed: () {
                            appdata.settings[26] = appdata.settings[26].setValueAt(sortType.index.toString(), 0);
                            appdata.updateSettings();
                            changed = true;
                            Navigator.pop(context);
                            logic.refresh();
                          },
                          child: Text("确认".tl),
                        ),
                      ],
                    );
                  });
                },
              );
            },
          ),
        ),
      );
      actions.add(
        Tooltip(
          message: "下载管理器".tl,
          child: IconButton(
            icon: const Icon(Icons.download_for_offline),
            onPressed: () {
              showPopUpWidget(
                App.globalContext!,
                const DownloadingPage(),
              );
            },
          ),
        ),
      );
    } else if (logic.selecting) {
      // 添加选择状态下的更多按钮
      actions.add(
        Tooltip(
          message: "更多".tl,
          child: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              showMenuX(
                context,
                Offset(
                  MediaQuery.of(context).size.width - 16,
                  MediaQuery.of(context).padding.top,
                ),
                [
                  MenuEntry(
                    icon: Icons.select_all,
                    text: "全选".tl,
                    onClick: () {
                      for (int i = 0; i < logic.selected.length; i++) {
                        logic.selected[i] = true;
                      }
                      logic.selectedNum = logic.comics.length;
                      logic.update();
                    },
                  ),
                  MenuEntry(
                    icon: Icons.favorite_border,
                    text: "添加至本地收藏".tl,
                    onClick: () => addToLocalFavoriteFolder(App.globalContext!, logic),
                  ),
                  MenuEntry(
                    icon: Icons.chrome_reader_mode_outlined,
                    text: "查看漫画详情".tl,
                    onClick: () {
                      if (logic.selectedNum != 1) {
                        showToast(message: "请选择一个漫画".tl);
                      } else {
                        for (int i = 0; i < logic.selected.length; i++) {
                          if (logic.selected[i]) {
                            toComicInfoPage(logic.comics[i]);
                          }
                        }
                      }
                    },
                  ),
                  MenuEntry(
                    icon: Icons.outbox_outlined,
                    text: "导出为zip".tl,
                    onClick: () => exportSelectedComic(context, logic),
                  ),
                  MenuEntry(
                    icon: Icons.picture_as_pdf_outlined,
                    text: "导出为pdf".tl,
                    onClick: () => exportAsPdf(null, logic),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // 添加漫画源筛选按钮
    if (!logic.selecting && !logic.searchMode) {
      actions.add(
        Builder(
          builder: (buttonContext) => Tooltip(
            message: "漫画源筛选".tl,
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                showDownloadTypeFilterMenu(
                  buttonContext: buttonContext,
                  logic: logic,
                );
              },
            ),
          ),
        ),
      );
    }

    // 添加标签搜索和普通搜索按钮
    if (!logic.selecting) {
      actions.add(
        Tooltip(
          message: "标签搜索".tl,
          child: IconButton(
            icon: const Icon(Icons.tag_rounded),
            onPressed: () {
              if (!logic.tagSearchMode) {
                // 切换到标签搜索模式
                logic.tagSearchMode = true;
                logic.searchMode = false;
                logic.searchInit = true;
                // 同步标签关键词到搜索控制器
                logic.searchController?.text = logic.tagKeyword;
                logic.searchController?.selection = TextSelection.fromPosition(
                  TextPosition(offset: logic.tagKeyword.length),
                );
                // 执行标签搜索
                logic.searchByTag();
              } else {
                // 退出标签搜索模式
                logic.tagSearchMode = false;
                logic.searchMode = false;
                // 保留当前页面，不重置为第一页
                // logic.currentPage = 1;
                logic.selected =
                    List.generate(logic.comics.length, (index) => false);
                logic.selectedNum = 0;
                logic.searchController?.text = '';
                // 退出搜索模式时保留当前页面，不调用会重置分页的refresh()
                // 只更新UI而不重置分页信息
                logic.update();
              }
            },
          ),
        ),
      );
      actions.add(
        Tooltip(
          message: "分类搜索".tl,
          child: IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              if (!logic.categorySearchMode) {
                // 切换到分类搜索模式
                logic.categorySearchMode = true;
                logic.searchMode = false;
                logic.tagSearchMode = false;
                logic.searchInit = true;
                // 同步分类关键词到搜索控制器
                logic.searchController?.text = logic.categoryKeyword;
                logic.searchController?.selection = TextSelection.fromPosition(
                  TextPosition(offset: logic.categoryKeyword.length),
                );
                // 执行分类搜索
                logic.searchByCategory();
              } else {
                // 退出分类搜索模式
                logic.categorySearchMode = false;
                logic.searchMode = false;
                logic.tagSearchMode = false;
                // 保留当前页面，不重置为第一页
                // logic.currentPage = 1;
                logic.selected =
                    List.generate(logic.comics.length, (index) => false);
                logic.selectedNum = 0;
                logic.searchController?.text = '';
                // 退出搜索模式时保留当前页面，不调用会重置分页的refresh()
                // 只更新UI而不重置分页信息
                logic.update();
              }
            },
          ),
        ),
      );
      // 始终显示搜索按钮，根据模式执行不同的搜索逻辑
      actions.add(
        Tooltip(
          message: logic.categorySearchMode
              ? "分类搜索".tl
              : (logic.tagSearchMode ? "标签搜索".tl : "搜索".tl),
          child: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (logic.categorySearchMode) {
                // 从分类搜索模式切换到普通搜索模式
                logic.categorySearchMode = false;
                logic.searchMode = true;
                logic.tagSearchMode = false;
                logic.searchInit = true;
                // 同步普通关键词到搜索控制器
                logic.searchController?.text = logic.keyword;
                logic.searchController?.selection = TextSelection.fromPosition(
                  TextPosition(offset: logic.keyword.length),
                );
                // 执行普通搜索
                logic.find();
                // 确保UI更新
                logic.update();
              } else if (logic.tagSearchMode) {
                // 从标签搜索模式切换到普通搜索模式
                logic.tagSearchMode = false;
                logic.searchMode = true;
                logic.searchInit = true;
                // 同步普通关键词到搜索控制器
                logic.searchController?.text = logic.keyword;
                logic.searchController?.selection = TextSelection.fromPosition(
                  TextPosition(offset: logic.keyword.length),
                );
                // 执行普通搜索
                logic.find();
                // 确保UI更新
                logic.update();
              } else if (logic.searchMode) {
                // 普通搜索模式下退出搜索
                logic.searchMode = false;
                logic.searchInit = false;
                // 清空搜索控制器
                logic.searchController?.clear();
                // 重置搜索关键词
                logic.keyword = '';
                // 退出搜索模式时保留当前页面，不调用会重置分页的refresh()
                // 只更新UI而不重置分页信息
                logic.update();
              } else {
                // 主界面下进入普通搜索模式
                logic.searchMode = true;
                logic.searchInit = true;
                // 同步普通关键词到搜索控制器
                logic.searchController?.text = logic.keyword;
                logic.searchController?.selection = TextSelection.fromPosition(
                  TextPosition(offset: logic.keyword.length),
                );
                // 执行普通搜索
                logic.find();
                // 确保UI更新
                logic.update();
              }
              // 所有分支中已包含UI更新，无需重复调用
              // logic.update();
            },
          ),
        ),
      );
    }

    return actions;
  }

  void exportSelectedComic(BuildContext context, DownloadPageLogic logic) {
    if (logic.selectedNum == 0) {
      showToast(message: "请选择漫画".tl);
    } else {
      Future<void>.delayed(
        const Duration(milliseconds: 200),
        () => showDialog(
          context: App.globalContext!,
          barrierColor: Colors.black26,
          barrierDismissible: false,
          builder: (context) => const SimpleDialog(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: SizedBox(
                    width: 50,
                    height: 75,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 10,
                        ),
                        CircularProgressIndicator(),
                        SizedBox(
                          height: 9,
                        ),
                        Text("打包中")
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
      Future<void>.delayed(
          const Duration(milliseconds: 500), () => export(logic));
    }
  }

  void addToLocalFavoriteFolder(BuildContext context, DownloadPageLogic logic) {
    String? folder;
    showDialog(
        context: App.globalContext!,
        builder: (context) => SimpleDialog(
              title: const Text("复制到..."),
              children: [
                SizedBox(
                  width: 400,
                  height: 132,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text("收藏夹".tl),
                        trailing: Select(
                          width: 156,
                          values: LocalFavoritesManager().folderNames,
                          initialValue: null,
                          onChange: (i) =>
                              folder = LocalFavoritesManager().folderNames[i],
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: FilledButton(
                          child: Text("确认".tl),
                          onPressed: () {
                            if (folder == null) {
                              return;
                            }
                            for (int i = 0; i < logic.selected.length; i++) {
                              if (logic.selected[i]) {
                                var comic = logic.comics[i];
                                LocalFavoritesManager().addComic(
                                    folder!,
                                    switch (comic.type) {
                                      DownloadType.picacg =>
                                        FavoriteItem.fromPicacg(
                                            (comic as DownloadedComic)
                                                .comicItem
                                                .toBrief()),
                                      DownloadType.ehentai =>
                                        FavoriteItem.fromEhentai(
                                            (comic as DownloadedGallery)
                                                .gallery
                                                .toBrief()),
                                      DownloadType.jm =>
                                        FavoriteItem.fromJmComic(
                                            (comic as DownloadedJmComic)
                                                .comic
                                                .toBrief()),
                                      DownloadType.nhentai => FavoriteItem
                                          .fromNhentai(NhentaiComicBrief(
                                              comic.name,
                                              (comic as NhentaiDownloadedComic)
                                                  .cover,
                                              comic.id,
                                              "",
                                              const [])),
                                      DownloadType.hitomi =>
                                        FavoriteItem.fromHitomi((comic
                                                as DownloadedHitomiComic)
                                            .comic
                                            .toBrief(comic.link, comic.cover)),
                                      DownloadType.htmanga =>
                                        FavoriteItem.fromHtcomic(
                                            (comic as DownloadedHtComic)
                                                .comic
                                                .toBrief()),
                                      DownloadType.other => () {
                                          var c =
                                              (comic as CustomDownloadedItem);
                                          return FavoriteItem.custom(
                                              CustomComic(
                                                  c.name,
                                                  c.subTitle,
                                                  c.cover,
                                                  c.comicId,
                                                  c.tags,
                                                  "",
                                                  c.sourceKey));
                                        }(),
                                      DownloadType.favorite =>
                                        throw UnimplementedError(),
                                    });
                              }
                            }
                            App.globalBack();
                          },
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                    ],
                  ),
                )
              ],
            ));
  }
}

class DownloadedComicInfoView extends StatefulWidget {
  const DownloadedComicInfoView(this.item, this.logic, {Key? key})
      : super(key: key);
  final DownloadedItem item;
  final DownloadPageLogic logic;

  @override
  State<DownloadedComicInfoView> createState() =>
      _DownloadedComicInfoViewState();
}

class _DownloadedComicInfoViewState extends State<DownloadedComicInfoView>
    with SingleTickerProviderStateMixin {
  String name = "";
  List<String> eps = [];
  List<int> downloadedEps = [];
  late final comic = widget.item;

  ComicChapters? _chapters;
  int _selectedGroupIndex = 0;
  TabController? _tabController;

  bool get _isGrouped => _chapters != null && _chapters!.isGrouped;

  @override
  void initState() {
    super.initState();
    if (comic is CustomDownloadedItem) {
      _chapters = (comic as CustomDownloadedItem).chapters;
    }
    if (_isGrouped) {
      _tabController = TabController(
        length: _chapters!.groupCount,
        initialIndex: 0,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  deleteEpisode(int i) {
    showConfirmDialog(
      context: context,
      title: "确认删除".tl,
      content: "要删除这个章节吗".tl,
      onConfirm: () async {
        var message = await DownloadManager().deleteEpisode(comic, i);
        if (message == null) {
          setState(() {});
        } else {
          showToast(message: message);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    getInfo();
    if (App.isFluent) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: Text(name),
          leading: fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (BuildContext context, int i) {
                    return fluent.Button(
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(child: Text(eps[i])),
                          const SizedBox(width: 4),
                          if (downloadedEps.contains(i))
                            const Icon(fluent.FluentIcons.download),
                          const SizedBox(width: 16),
                        ],
                      ),
                      onPressed: () => readSpecifiedEps(i),
                      onLongPress: () => deleteEpisode(i),
                    );
                  },
                  itemCount: eps.length,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: fluent.Button(
                        onPressed: () {
                          App.globalBack();
                          _toComicInfoPage(widget.item);
                        },
                        child: Text("查看详情".tl)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: fluent.FilledButton(
                        onPressed: () => read(), child: Text("阅读".tl)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: Text(
              name,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          if (_isGrouped) ...[
            SizedBox(
              height: 40,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                onTap: (index) {
                  if (index != _selectedGroupIndex) {
                    setState(() {
                      _selectedGroupIndex = index;
                    });
                  }
                },
                tabs: _chapters!.groups
                    .map((g) => Tab(text: g))
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Expanded(
            child: Builder(builder: (context) {
              List<String> displayEps;
              int Function(int) epOffset;
              if (_isGrouped) {
                var group = _chapters!.getGroupByIndex(_selectedGroupIndex);
                displayEps = group.values.toList();
                int offset = 0;
                for (int j = 0; j < _selectedGroupIndex; j++) {
                  offset += _chapters!.getGroupByIndex(j).length;
                }
                epOffset = (i) => offset + i;
              } else {
                displayEps = eps;
                epOffset = (i) => i;
              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  childAspectRatio: 4,
                ),
                itemBuilder: (BuildContext context, int i) {
                  var globalIndex = epOffset(i);
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: InkWell(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(16)),
                          color: downloadedEps.contains(globalIndex)
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Expanded(child: Text(displayEps[i])),
                            const SizedBox(width: 4),
                            if (downloadedEps.contains(globalIndex))
                              const Icon(Icons.download_done),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                      onTap: () => readSpecifiedEps(globalIndex),
                      onLongPress: () => deleteEpisode(globalIndex),
                      onSecondaryTapDown: (details) => deleteEpisode(globalIndex),
                    ),
                  );
                },
                itemCount: displayEps.length,
              );
            }),
          ),
          SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                        onPressed: () {
                          App.globalBack();
                          _toComicInfoPage(widget.item);
                        },
                        child: Text("查看详情".tl)),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: FilledButton(
                        onPressed: () => read(), child: Text("阅读".tl)),
                  ),
                ],
              )),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom,
          )
        ],
      ),
    );
  }

  void getInfo() {
    name = comic.name;
    eps = comic.eps;
    downloadedEps = comic.downloadedEps;
  }

  void read() {
    comic.read();
  }

  void readSpecifiedEps(int i) {
    comic.read(ep: i + 1);
  }
}

class DownloadedComicTile extends ComicTile {
  final String size;
  final File imagePath;
  final String author;
  final String name;
  final String type;
  final List<String> tag;
  final List<String>? category;
  final void Function() onTap;
  final void Function() onLongTap;
  final void Function(TapDownDetails details) onSecondaryTap;

  @override
  List<String>? get tags => tag
      .map((e) => App.locale.languageCode == "zh" ? e.translateTagsToCN : e)
      .toList();

  @override
  List<String>? get categories => category
      ?.map((e) => App.locale.languageCode == "zh" ? e.translateTagsToCN : e)
      .toList();

  @override
  String get description => "${size}MB";

  @override
  Widget get image => Image.file(
        imagePath,
        fit: BoxFit.cover,
        height: double.infinity,
      );

  @override
  void onTap_() => onTap();

  @override
  String get subTitle => author;

  @override
  String get title => name;

  @override
  void onLongTap_() => onLongTap();

  @override
  void onSecondaryTap_(details) => onSecondaryTap(details);

  @override
  String? get badge => type;

  const DownloadedComicTile(
      {required this.size,
      required this.imagePath,
      required this.author,
      required this.name,
      required this.onTap,
      required this.onLongTap,
      required this.onSecondaryTap,
      required this.type,
      required this.tag,
      this.category,
      super.key});
}

void _toComicInfoPage(DownloadedItem comic) {
  var context = App.mainNavigatorKey!.currentContext!;
  if (comic is DownloadedComic) {
    context.to(() => PicacgComicPage((comic).comicItem.id, null));
  } else if (comic is DownloadedGallery) {
    context.to(() => EhGalleryPage((comic).gallery.toBrief()));
  } else if (comic is DownloadedJmComic) {
    context.to(() => JmComicPage((comic).comic.id));
  } else if (comic is DownloadedHitomiComic) {
    context.to(() => HitomiComicPage(comic.toBrief()));
  } else if (comic is DownloadedHtComic) {
    context.to(() => HtComicPage(comic.id.replaceFirst('Ht', '')));
  } else if (comic is NhentaiDownloadedComic) {
    context.to(() => NhentaiComicPage(comic.id.replaceFirst("nhentai", "")));
  } else if (comic is CustomDownloadedItem) {
    context.to(() => ComicPage(sourceKey: comic.sourceKey, id: comic.comicId));
  }
}

/// 显示下载类型筛选菜单
void showDownloadTypeFilterMenu({
  required BuildContext buttonContext,
  required DownloadPageLogic logic,
}) {
  final RenderBox? renderBox = buttonContext.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  final Offset offset = renderBox.localToGlobal(Offset.zero);
  final Size buttonSize = renderBox.size;
  final Size screenSize = MediaQuery.of(App.globalContext!).size;

  showMenu<DownloadType?>(
    context: App.globalContext!,
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + buttonSize.height,
      screenSize.width - offset.dx - buttonSize.width,
      screenSize.height - offset.dy - buttonSize.height,
    ),
    items: [
      PopupMenuItem<DownloadType?>(
        value: null,
        child: Row(
          children: [
            if (logic.downloadTypeFilter == null)
              const Icon(Icons.check, size: 20),
            if (logic.downloadTypeFilter != null)
              const SizedBox(width: 28),
            const SizedBox(width: 8),
            Text("全部".tl),
          ],
        ),
        onTap: () {
          Future.delayed(const Duration(milliseconds: 100), () {
            logic.updateDownloadTypeFilter(null);
          });
        },
      ),
      const PopupMenuDivider(),
      ...[
        DownloadType.picacg,
        DownloadType.ehentai,
        DownloadType.jm,
        DownloadType.hitomi,
        DownloadType.htmanga,
        DownloadType.nhentai,
        DownloadType.other,
      ].map((type) {
        final typeName = getDownloadTypeName(type);
        return PopupMenuItem<DownloadType?>(
          value: type,
          child: Row(
            children: [
              if (logic.downloadTypeFilter == type)
                const Icon(Icons.check, size: 20),
              if (logic.downloadTypeFilter != type)
                const SizedBox(width: 28),
              Text(typeName),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              logic.updateDownloadTypeFilter(type);
            });
          },
        );
      }),
    ],
  );
}
