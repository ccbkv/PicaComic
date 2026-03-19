import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/download.dart';
import 'package:pica_comic/network/base_comic.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/reader/comic_reading_page.dart';
import 'package:pica_comic/pages/settings/settings_page.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/io_tools.dart';
import 'package:pica_comic/utils/tags_translation.dart';
import 'package:pica_comic/utils/translations.dart';

import 'local_favorites.dart';
import 'network_to_local.dart';

part 'favorite_actions.dart';
part 'side_bar.dart';
part 'local_favorites_page.dart';
part 'network_favorites_page.dart';

const _kLeftBarWidth = 256.0;

const _kTwoPanelChangeWidth = 720.0;

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String? folder;

  bool isNetwork = false;

  FolderList? folderList;

  void setFolder(bool isNetwork, String? folder) {
    setState(() {
      this.isNetwork = isNetwork;
      this.folder = folder;
    });
    folderList?.update();
    // 兼容旧版格式: selectingFolder;isNetwork;folder
    // selectingFolder = 1 表示正在选择文件夹(侧边栏显示)
    // isNetwork = 1 表示网络收藏, 0 表示本地收藏
    if (folder != null) {
      appdata.implicitData[0] = "0;${isNetwork ? 1 : 0};$folder";
    } else {
      appdata.implicitData[0] = "1;0;";
    }
    appdata.writeImplicitData();
  }

  @override
  void initState() {
    var data = appdata.implicitData[0].split(";");
    // 兼容旧版格式: selectingFolder;isNetwork;folder
    if (data.length >= 3) {
      // 新版格式
      isNetwork = data[1] == "1";
      folder = data[2].isNotEmpty ? data.sublist(2).join(";") : null;
    } else if (data.length == 2) {
      // 旧版格式: isNetwork;folder
      isNetwork = data[0] == "1";
      folder = data[1].isNotEmpty ? data[1] : null;
    }
    if (folder != null
        && !isNetwork
        && !LocalFavoritesManager().folderNames.contains(folder!)) {
      folder = null;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth;
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Stack(
        children: [
          AnimatedPositioned(
            left: isMobileView ? -_kLeftBarWidth : 0,
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              width: _kLeftBarWidth,
              child: _LeftBar(key: ValueKey(isMobileView)),
            ),
          ),
          Positioned(
            top: 0,
            left: isMobileView ? 0 : _kLeftBarWidth,
            right: 0,
            bottom: 0,
            child: buildBody(),
          ),
        ],
      ),
    );
  }

  void showFolderSelector() {
    Navigator.of(App.globalContext!).push(PageRouteBuilder(
      barrierDismissible: true,
      fullscreenDialog: true,
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.36),
      pageBuilder: (context, animation, secondary) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            child: SizedBox(
              width: min(300, MediaQuery.of(context).size.width - 16),
              child: _LeftBar(
                withAppbar: true,
                favPage: this,
                onSelected: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondary, child) {
        var offset =
            Tween<Offset>(begin: const Offset(-1, 0), end: const Offset(0, 0));
        return SlideTransition(
          position: offset.animate(CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
          )),
          child: child,
        );
      },
    ));
  }

  Widget buildBody() {
    if (folder == null) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: Tooltip(
              message: "收藏夹".tl,
              child: MediaQuery.of(context).size.width <= _kTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: showFolderSelector,
                    )
                  : null,
            ),
            title: GestureDetector(
              onTap: MediaQuery.of(context).size.width < _kTwoPanelChangeWidth
                  ? showFolderSelector
                  : null,
              child: Text("未选择".tl),
            ),
          ),
        ],
      );
    }
    if (!isNetwork) {
      return _LocalFavoritesPage(
          folder: folder!, key: PageStorageKey("local_$folder"));
    } else {
      var favoriteData = getFavoriteDataOrNull(folder!);
      if (favoriteData == null) {
        folder = null;
        return buildBody();
      } else {
        return NetworkFavoritePage(favoriteData,
            key: PageStorageKey("network_$folder"));
      }
    }
  }
}

abstract class FolderList {
  void update();

  void updateFolders();
}
