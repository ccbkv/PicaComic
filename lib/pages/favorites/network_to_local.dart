import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/network/net_fav_to_local.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/components/components.dart';

import '../../base.dart';
import '../../network/base_comic.dart';
import '../../network/res.dart';

class _ChooseNetworkFolderWidget extends StatefulWidget {
  const _ChooseNetworkFolderWidget();

  @override
  State<_ChooseNetworkFolderWidget> createState() =>
      _ChooseNetworkFolderWidgetState();
}

class LoadComicClass {
  Future<Res<List<BaseComic>>> loadComic(
      FavoriteData fData, int i, String? folder) async {
    final source = ComicSource.find(fData.key);
    if (source == null || source.isBuiltIn) {
      return Res.error("请先添加对应漫画源".tl);
    }
    final favorites = source.favoriteData;
    if (favorites == null) return Res.error("漫画源不支持网络收藏".tl);
    return favorites.loadComic(i, favorites.multiFolder ? folder : null);
  }
}

class _ChooseNetworkFolderWidgetState
    extends State<_ChooseNetworkFolderWidget> {
  late final List<FavoriteData> _folders;

  late List<bool> isExpanded;

  String? selected;
  bool agreeSync = false;

  Map<String, Map<String, String>> multiFolderData = {};

  @override
  void initState() {
    var folders = <FavoriteData>[];
    for (var key in appdata.settings[68].split(',')) {
      final source = ComicSource.find(key);
      if (source != null && !source.isBuiltIn && source.favoriteData != null) {
        folders.add(source.favoriteData!);
      }
    }
    _folders = folders;
    isExpanded = _folders.map((e) => false).toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("选择收藏夹".tl),
        actions: [
          IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _folders.isEmpty
                  ? Text("请先添加支持网络收藏的漫画源".tl)
                  : ExpansionPanelList(
                materialGapSize: 0,
                expandedHeaderPadding: EdgeInsets.zero,
                expansionCallback: (i, value) =>
                    setState(() => isExpanded[i] = value),
                children: _folders.map((e) => buildItem(e)).toList(),
              ),
            ),
          ),
          const Divider(
            height: 1,
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(
                  width: 8,
                ),
                Checkbox(
                    value: agreeSync,
                    onChanged: (b) {
                      setState(() {
                        agreeSync = b ?? false;
                      });
                    }),
                Text("支持下拉更新".tl),
                const Spacer(),
                FilledButton(onPressed: selected == null ? null : onConfirm,
                    child: Text("继续".tl)),
                const SizedBox(
                  width: 24,
                ),
              ],
            ),
          ),
          if (UiMode.m1(context))
            SizedBox(height: MediaQuery.of(context).padding.bottom)
        ],
      ),
    );
  }

  ExpansionPanel buildItem(FavoriteData data) {
    return ExpansionPanel(
        headerBuilder: (context, expand) {
          return ListTile(
            title: Text(data.title),
          );
        },
        isExpanded: isExpanded[_folders.indexOf(data)],
        body: buildBody(data),
        canTapOnHeader: true);
  }

  Widget buildTile(String key, String title) {
    return RadioListTile<String?>(
        title: Text(title),
        value: key,
        groupValue: selected,
        onChanged: (newValue) {
          setState(() {
            selected = newValue;
          });
        });
  }

  Widget buildBody(FavoriteData data) {
    if (!data.multiFolder) {
      return buildTile(data.key, data.title);
    } else {
      return StatefulBuilder(builder: (context, updater) {
        if (multiFolderData[data.key] == null) {
          if (isExpanded[_folders.indexOf(data)]) {
            data.loadFolders!().then((value) {
              if (!mounted) return;
              if (value.error) {
                showToast(message: "网络错误".tl);
              } else {
                updater(() {
                  multiFolderData[data.key] = value.data;
                });
              }
            });
          }
          return const SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: multiFolderData[data.key]!
                .entries
                .map((e) => buildTile("${data.key}:${e.key}", e.value))
                .toList(),
          );
        }
      });
    }
  }

  void onConfirm() {
    var key = selected!.split(":").first;
    var folderId = selected!.split(":").last;
    var data = _folders.firstWhere((element) => element.key == key);
    String name;
    if (!data.multiFolder) {
      name = data.title;
    } else {
      name = multiFolderData[data.key]![folderId]!;
      if (data.key == "ehentai" && name.contains("(")) {
        name = name.substring(0, name.lastIndexOf("("));
      }
    }
    App.globalBack();
    final loadComicObj = LoadComicClass();
    startConvert<BaseComic>(
        (page) => loadComicObj.loadComic(data, page, folderId),
        null,
        App.globalContext!,
        name,
        (comic) => FavoriteItem.fromBaseComic(comic),
        data.key,
        agreeSync,
        {"folderId": folderId});
  }
}

void networkToLocal() {
  showPopUpWidget(App.globalContext!, const _ChooseNetworkFolderWidget());
}

