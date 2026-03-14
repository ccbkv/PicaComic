part of pica_settings;

class ComicSourceSettings extends StatefulWidget {
  const ComicSourceSettings({super.key});

  @override
  State<ComicSourceSettings> createState() => _ComicSourceSettingsState();

  // static void checkCustomComicSourceUpdate([bool showLoading = false]) async {
  //   if (ComicSource.sources.isEmpty) {
  //     return;
  //   }
  //   var controller = showLoading ? showLoadingDialog(App.globalContext!) : null;
  //   var dio = logDio();
  //   var res = await dio.get<String>(
  //       "https://raw.githubusercontent.com/user/repo/master/index.json");
  //   if (res.statusCode != 200) {
  //     showToast(message: "网络错误".tl);
  //     return;
  //   }
  //   var list = jsonDecode(res.data!) as List;
  //   var versions = <String, String>{};
  //   for (var source in list) {
  //     versions[source['key']] = source['version'];
  //   }
  //   var shouldUpdate = <String>[];
  //   for (var source in ComicSource.sources) {
  //     if (versions.containsKey(source.key) &&
  //         versions[source.key] != source.version) {
  //       shouldUpdate.add(source.key);
  //     }
  //   }
  //   controller?.close();
  //   if (shouldUpdate.isEmpty) {
  //     return;
  //   }
  //   var msg = "";
  //   for (var key in shouldUpdate) {
  //     msg += "${ComicSource.find(key)?.name}: v${versions[key]}\n";
  //   }
  //   msg = msg.trim();
  //   showConfirmDialog(App.globalContext!, "有可用更新".tl, msg, () {
  //     for (var key in shouldUpdate) {
  //       var source = ComicSource.find(key);
  //       _ComicSourceSettingsState.update(source!);
  //     }
  //   });
  // }
}



class _ComicSourceSettingsState extends State<ComicSourceSettings> {
  var url = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text("漫画源".tl),
            pinned: true,
          ),
          buildCard(context),
          const _SliverBuiltInSources(),
          if(appdata.appSettings.isComicSourceEnabled("picacg"))
            const SliverPicacgSettings(),
          if(appdata.appSettings.isComicSourceEnabled("ehentai"))
            const SliverEhSettings(),
          if(appdata.appSettings.isComicSourceEnabled("nhentai"))
            const SliverNhSettings(),
          if(appdata.appSettings.isComicSourceEnabled("jm"))
            const SliverJmSettings(),
          if(appdata.appSettings.isComicSourceEnabled("hitomi"))
            const SliverHitomiSettings(),
          if(appdata.appSettings.isComicSourceEnabled("htmanga"))
            const SliverHtSettings(),
          for (var source in ComicSource.sources.where((e) => !e.isBuiltIn))
            _SliverComicSource(
              key: ValueKey(source.key),
              source: source,
              edit: edit,
              update: update,
              delete: delete,
            ),
          SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom)),
        ],
      ),
    );
  }

  // Widget buildCustomSettings() {
  //   return Column(
  //     children: [
  //       ListTile(
  //         title: Text("自定义漫画源".tl),
  //       ),
  //       ListTile(
  //         leading: const Icon(Icons.update_outlined),
  //         title: Text("检查更新".tl),
  //         onTap: () => ComicSourceSettings.checkCustomComicSourceUpdate(true),
  //         trailing: const Icon(Icons.arrow_right),
  //       ),
  //       SwitchSetting(
  //         title: "启动时检查更新".tl,
  //         icon: const Icon(Icons.security_update),
  //         settingsIndex: 80,
  //       )
  //     ],
  //   );
  // }



  void delete(ComicSource source) {
    showConfirmDialog(App.globalContext!, "删除".tl, "要删除此漫画源吗?".tl, () {
      var file = File(source.filePath);
      file.delete();
      ComicSource.sources.remove(source);
      _validatePages();
      MyApp.updater?.call();
      StateController.findOrNull(tag: "me_page_sources")?.update();
    });
  }

  void edit(ComicSource source) async {
    // Use built-in editor for all platforms - no VS Code dependency
    App.globalTo(
      () => _EditFilePage(source.filePath, () async {
        await ComicSource.reload();
        MyApp.updater?.call();
      }),
    );
  }

  static void update(ComicSource source) async {
    ComicSource.sources.remove(source);
    if (!source.url.isURL) {
      showToast(message: "Invalid url config");
    }
    bool cancel = false;
    var controller = showLoadingDialog(App.globalContext!,
        onCancel: () => cancel = true, barrierDismissible: false);
    try {
      var res = await logDio().get<String>(source.url,
          options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await ComicSourceParser().parse(res.data!, source.filePath);
      await File(source.filePath).writeAsString(res.data!);
    } catch (e) {
      if (cancel) return;
      showToast(message: e.toString());
    }
    await ComicSource.reload();
    MyApp.updater?.call();
    StateController.findOrNull(tag: "me_page_sources")?.update();
  }

  Widget buildCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("添加漫画源".tl),
              leading: const Icon(Icons.dashboard_customize),
            ),
            TextField(
              decoration: InputDecoration(
                hintText: "URL",
                border: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                suffix: IconButton(
                  onPressed: () => handleAddSource(url),
                  icon: const Icon(Icons.check),
                ),
              ),
              onChanged: (value) {
                url = value;
              },
              onSubmitted: handleAddSource,
            ).paddingHorizontal(16).paddingBottom(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.article_outlined),
                  label: Text("浏览列表".tl),
                  onPressed: () {
                    showPopUpWidget(
                      context,
                      _ComicSourceList(handleAddSource, onClose: () => Navigator.of(context).pop()),
                    );
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text("选择文件".tl),
                  onPressed: chooseFile,
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.help_outline),
                  label: Text("帮助".tl),
                  onPressed: help,
                ),
                const _CheckUpdatesButton(),
              ],
            ).paddingHorizontal(12).paddingVertical(8),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void chooseFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      extensions: <String>['js'],
      uniformTypeIdentifiers: <String>['public.javascript-source'],
    );
    final XFile? file =
        await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    try {
      var fileName = file.name;
      // file.readAsString 会导致中文乱码
      var bytes = await file.readAsBytes();
      var content = utf8.decode(bytes);
      await addSource(content, fileName);
    } catch (e) {
      showToast(message: e.toString());
    }
  }

  void help() {
    launchUrlString(
      "https://github.com/ccbkv/PicaComic/blob/master/doc/comic_source.md",
    );
  }

  Future<void> handleAddSource(String url) async {
    if (url.isEmpty) {
      return;
    }
    var splits = url.split("/");
    splits.removeWhere((element) => element == "");
    var fileName = splits.last;
    bool cancel = false;
    var controller = showLoadingDialog(App.globalContext!,
        onCancel: () => cancel = true, barrierDismissible: false);
    try {
      var res = await logDio()
          .get<String>(url, options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await addSource(res.data!, fileName);
    } catch (e) {
      if (cancel) return;
      showToast(message: e.toString());
    }
  }

  Future<void> addSource(String js, String fileName) async {
    var comicSource = await ComicSourceParser().createAndParse(js, fileName);
    ComicSource.sources.add(comicSource);
    _addAllPagesWithComicSource(comicSource);
    appdata.updateSettings();
    MyApp.updater?.call();
    StateController.findOrNull(tag: "me_page_sources")?.update();
  }
}

class _CheckUpdatesButton extends StatefulWidget {
  const _CheckUpdatesButton();

  @override
  State<_CheckUpdatesButton> createState() => _CheckUpdatesButtonState();
}

class _CheckUpdatesButtonState extends State<_CheckUpdatesButton> {
  bool isLoading = false;

  void check() async {
    setState(() {
      isLoading = true;
    });
    var count = await checkComicSourceUpdate();
    if (count == -1) {
      showToast(message: "网络错误".tl);
    } else if (count == 0) {
      showToast(message: "没有更新".tl);
    } else {
      showUpdateDialog();
    }
    setState(() {
      isLoading = false;
    });
  }

  void showUpdateDialog() async {
    var text = ComicSource.updates.entries.map((e) {
      return "${ComicSource.find(e.key)?.name}: ${e.value}";
    }).join("\n");
    bool doUpdate = false;
    await showDialog(
      context: App.globalContext!,
      builder: (context) {
        return AlertDialog(
          title: Text("有可用更新".tl),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("取消".tl),
            ),
            FilledButton(
              onPressed: () {
                doUpdate = true;
                Navigator.pop(context);
              },
              child: Text("更新".tl),
            ),
          ],
        );
      },
    );
    if (doUpdate) {
      var loadingController = showLoadingDialog(App.globalContext!,
          message: "更新中".tl, barrierDismissible: false);
      try {
        var shouldUpdate = ComicSource.updates.keys.toList();
        for (var key in shouldUpdate) {
          var source = ComicSource.find(key)!;
          _ComicSourceSettingsState.update(source);
        }
      } catch (e) {
        showToast(message: e.toString());
      }
      loadingController.close();
    }
  }

  static Future<int> checkComicSourceUpdate() async {
    if (ComicSource.sources.isEmpty) {
      return 0;
    }
    var dio = logDio();
    var res = await dio.get<String>(
        "https://raw.githubusercontent.com/ccbkv/pica_configs/refs/heads/master/index.json");
    if (res.statusCode != 200) {
      return -1;
    }
    var list = jsonDecode(res.data!) as List;
    var versions = <String, String>{};
    for (var source in list) {
      versions[source['key']] = source['version'];
    }
    var shouldUpdate = <String>[];
    for (var source in ComicSource.sources.where((e) => !e.isBuiltIn)) {
      if (versions.containsKey(source.key) &&
          versions[source.key] != source.version) {
        shouldUpdate.add(source.key);
      }
    }
    if (shouldUpdate.isNotEmpty) {
      ComicSource.updates = {
        for (var key in shouldUpdate) key: versions[key]!
      };
    }
    return shouldUpdate.length;
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.update),
      label: Text("检查更新".tl),
      onPressed: check,
    );
  }
}

class _ComicSourceList extends StatefulWidget {
  const _ComicSourceList(this.onAdd, {this.onClose});

  final Future<void> Function(String) onAdd;
  final VoidCallback? onClose;

  @override
  State<_ComicSourceList> createState() => _ComicSourceListState();
}

class _ComicSourceListState extends State<_ComicSourceList> {
  List? json;
  bool changed = false;
  var controller = TextEditingController();

  void load() async {
    if (json != null) {
      setState(() {
        json = null;
      });
    }
    if (controller.text.isEmpty) {
      setState(() {
        json = [];
      });
      return;
    }
    var dio = logDio();
    try {
      var res = await dio.get<String>(controller.text);
      if (res.statusCode != 200) {
        throw "error";
      }
      if (mounted) {
        setState(() {
          json = jsonDecode(res.data!);
        });
      }
    } catch (e) {
      showToast(message: "网络错误".tl);
      if (mounted) {
        setState(() {
          json = [];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controller.text = "https://raw.githubusercontent.com/ccbkv/pica_configs/refs/heads/master/index.json";
    load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("漫画源".tl),
        actions: [
          IconButton(onPressed: widget.onClose ?? App.globalBack, icon: const Icon(Icons.close)),
        ],
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    var currentKey = ComicSource.sources.map((e) => e.key).toList();

    return ListView.builder(
      itemCount: (json?.length ?? 1) + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.source_outlined),
                  title: Text("仓库地址".tl),
                ),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "URL",
                    border: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (value) {
                    changed = true;
                  },
                ).paddingHorizontal(16).paddingBottom(8),
                Text(
                  "URL 应指向 'index.json' 文件".tl,
                ).paddingLeft(16),
                Text(
                  "请勿向 App 仓库反馈与漫画源相关的问题".tl,
                ).paddingLeft(16),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        launchUrlString(
                          "https://github.com/venera-app/venera/blob/master/doc/comic_source.md",
                        );
                      },
                      child: Text("帮助".tl),
                    ),
                    FilledButton.tonal(
                      onPressed: load,
                      child: Text("刷新".tl),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        if (index == 1 && json == null) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        }

        index--;

        var key = json![index]["key"];
        var action = currentKey.contains(key)
            ? const Icon(Icons.check, size: 20).paddingRight(8)
            : FilledButton(
                onPressed: () async {
                  var fileName = json![index]["fileName"];
                  var url = json![index]["url"];
                  if (url == null || !(url.toString()).isURL) {
                    var listUrl = controller.text;
                    if (listUrl
                        .replaceFirst("https://", "")
                        .replaceFirst("http://", "")
                        .contains("/")) {
                      url =
                          listUrl.substring(0, listUrl.lastIndexOf("/") + 1) +
                          fileName;
                    } else {
                      url = '$listUrl/$fileName';
                    }
                  }
                  await widget.onAdd(url);
                  setState(() {});
                },
                child: Text("添加".tl),
              ).fixHeight(32);

        var description = json![index]["version"];
        if (json![index]["description"] != null) {
          description = "$description\n${json![index]["description"]}";
        }

        return ListTile(
          title: Text(json![index]["name"]),
          subtitle: Text(description),
          trailing: action,
        );
      },
    );
  }
}

// Sliver wrappers for built-in source settings
class SliverPicacgSettings extends StatelessWidget {
  const SliverPicacgSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const PicacgSettings(false),
        ],
      ),
    );
  }
}

class SliverEhSettings extends StatelessWidget {
  const SliverEhSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const EhSettings(false),
        ],
      ),
    );
  }
}

class SliverNhSettings extends StatelessWidget {
  const SliverNhSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const NhSettings(false),
        ],
      ),
    );
  }
}

class SliverJmSettings extends StatelessWidget {
  const SliverJmSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const JmSettings(false),
        ],
      ),
    );
  }
}

class SliverHitomiSettings extends StatelessWidget {
  const SliverHitomiSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const HitomiSettings(false),
        ],
      ),
    );
  }
}

class SliverHtSettings extends StatelessWidget {
  const SliverHtSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 0.6,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const HtSettings(false),
        ],
      ),
    );
  }
}

class _SliverBuiltInSources extends StatefulWidget {
  const _SliverBuiltInSources();

  @override
  State<_SliverBuiltInSources> createState() => _SliverBuiltInSourcesState();
}

class _SliverBuiltInSourcesState extends State<_SliverBuiltInSources> {
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ListTile(
            title: Text("内置漫画源".tl),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => buildTile(index),
            childCount: builtInSources.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool isLoading = false;

  Widget buildTile(int index) {
    var key = builtInSources[index];
    return ListTile(
      title: Text(
          ComicSource.builtIn.firstWhere((e) => e.key == key).name.tl),
      trailing: Switch(
        value: appdata.appSettings.isComicSourceEnabled(key),
        onChanged: (v) async {
          if (isLoading) return;
          isLoading = true;
          appdata.appSettings.setComicSourceEnabled(key, v);
          await appdata.updateSettings();
          if(!v) {
            ComicSource.sources.removeWhere((e) => e.key == key);
            _validatePages();
          } else {
            var source = ComicSource.builtIn.firstWhere((e) => e.key == key);
            ComicSource.sources.add(source);
            source.loadData();
            _addAllPagesWithComicSource(source);
          }
          isLoading = false;
          if (mounted) {
            setState(() {});
            context.findAncestorStateOfType<_ComicSourceSettingsState>()
                ?.setState(() {});
          }
          StateController.findOrNull(tag: "me_page_sources")?.update();
        },
      ),
    );
  }
}

void _validatePages() {
  var explorePages = appdata.appSettings.explorePages;
  var categoryPages = appdata.appSettings.categoryPages;
  var networkFavorites = appdata.appSettings.networkFavorites;

  var totalExplorePages = ComicSource.sources
      .map((e) => e.explorePages.map((e) => e.title))
      .expand((element) => element)
      .toList();
  var totalCategoryPages = ComicSource.sources
      .map((e) => e.categoryData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
  var totalNetworkFavorites = ComicSource.sources
      .map((e) => e.favoriteData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();

  for (var page in List.from(explorePages)) {
    if (!totalExplorePages.contains(page)) {
      explorePages.remove(page);
    }
  }
  for (var page in List.from(categoryPages)) {
    if (!totalCategoryPages.contains(page)) {
      categoryPages.remove(page);
    }
  }
  for (var page in List.from(networkFavorites)) {
    if (!totalNetworkFavorites.contains(page)) {
      networkFavorites.remove(page);
    }
  }

  appdata.appSettings.explorePages = explorePages;
  appdata.appSettings.categoryPages = categoryPages;
  appdata.appSettings.networkFavorites = networkFavorites;

  appdata.updateSettings();
}

class _SliverComicSource extends StatefulWidget {
  const _SliverComicSource({
    super.key,
    required this.source,
    required this.edit,
    required this.update,
    required this.delete,
  });

  final ComicSource source;
  final void Function(ComicSource source) edit;
  final void Function(ComicSource source) update;
  final void Function(ComicSource source) delete;

  @override
  State<_SliverComicSource> createState() => _SliverComicSourceState();
}

class _SliverComicSourceState extends State<_SliverComicSource> {
  ComicSource get source => widget.source;

  @override
  Widget build(BuildContext context) {
    var newVersion = ComicSource.updates[source.key];
    bool hasUpdate = newVersion != null && newVersion != source.version;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(padding: const EdgeInsets.only(top: 16)),
        SliverToBoxAdapter(
          child: ListTile(
            title: Row(
              children: [
                Text(source.name, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    source.version,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (hasUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "新版本".tl,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ).paddingLeft(4),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: "编辑".tl,
                  child: IconButton(
                    onPressed: () => widget.edit(source),
                    icon: const Icon(Icons.edit_note),
                  ),
                ),
                Tooltip(
                  message: "更新".tl,
                  child: IconButton(
                    onPressed: () => widget.update(source),
                    icon: const Icon(Icons.update),
                  ),
                ),
                Tooltip(
                  message: "删除".tl,
                  child: IconButton(
                    onPressed: () => widget.delete(source),
                    icon: const Icon(Icons.delete),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Venera format settings
        ..._buildVeneraSettings(),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVeneraSettings() {
    if (source.veneraSettings.isEmpty) {
      return [];
    }

    var widgets = <Widget>[];

    // Ensure settings data exists
    if (source.data['settings'] == null) {
      source.data['settings'] = {};
    }

    for (var entry in source.veneraSettings.entries) {
      var key = entry.key;
      var setting = entry.value;

      if (setting is! Map) continue;

      var type = setting['type'] as String?;
      var title = setting['title'] as String? ?? key;

      try {
        if (type == 'select') {
          var options = setting['options'] as List? ?? [];
          var defaultValue = setting['default'];

          // Get current value or use default
          var currentValue = source.data['settings'][key] ?? defaultValue;

          // Find display text for current value
          String currentText = currentValue?.toString() ?? '';
          for (var option in options) {
            if (option is Map && option['value'] == currentValue) {
              currentText = option['text']?.toString() ?? option['value']?.toString() ?? currentValue.toString();
              break;
            }
          }

          // Build option values and texts
          List<String> optionValues = [];
          List<String> optionTexts = [];
          for (var option in options) {
            if (option is Map) {
              var value = option['value']?.toString() ?? '';
              var text = option['text']?.toString() ?? option['value']?.toString() ?? '';
              optionValues.add(value);
              optionTexts.add(text);
            }
          }

          if (optionValues.isEmpty) continue;

          // Find current index
          int currentIndex = optionValues.indexOf(currentValue?.toString() ?? '');
          if (currentIndex < 0) currentIndex = 0;

          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(title),
                trailing: components.Select(
                  initialValue: currentIndex,
                  values: optionTexts,
                  onChange: (index) {
                    source.data['settings'][key] = optionValues[index];
                    source.saveData();
                    setState(() {});
                  },
                ),
              ),
            ),
          );
        } else if (type == 'switch') {
          var defaultValue = setting['default'] ?? false;
          var currentValue = source.data['settings'][key] ?? defaultValue;

          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(title),
                trailing: Switch(
                  value: currentValue is bool ? currentValue : false,
                  onChanged: (value) {
                    source.data['settings'][key] = value;
                    source.saveData();
                    setState(() {});
                  },
                ),
              ),
            ),
          );
        } else if (type == 'input') {
          var defaultValue = setting['default']?.toString() ?? '';
          var currentValue = source.data['settings'][key]?.toString() ?? defaultValue;

          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(title),
                subtitle: Text(
                  currentValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _showInputDialog(
                      context: context,
                      title: title,
                      initialValue: currentValue,
                      onConfirm: (value) {
                        source.data['settings'][key] = value;
                        source.saveData();
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            ),
          );
        }
      } catch (e, s) {
        log("Failed to build setting $key: $e\n$s", "ComicSourceSettings", LogLevel.error);
      }
    }

    return widgets;
  }

  void _showInputDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required void Function(String) onConfirm,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () {
              onConfirm(controller.text);
              Navigator.pop(context);
            },
            child: Text("确定".tl),
          ),
        ],
      ),
    );
  }
}

class _EditFilePage extends StatefulWidget {
  const _EditFilePage(this.path, this.onExit);

  final String path;

  final void Function() onExit;

  @override
  State<_EditFilePage> createState() => __EditFilePageState();
}

class __EditFilePageState extends State<_EditFilePage> {
  var current = '';

  @override
  void initState() {
    super.initState();
    current = File(widget.path).readAsStringSync();
  }

  @override
  void dispose() {
    File(widget.path).writeAsStringSync(current);
    widget.onExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("编辑"),
        actions: [
          IconButton(
            onPressed: () async {
              // Save and reload configs
              await ComicSource.reload();
              MyApp.updater?.call();
              StateController.findOrNull(tag: "me_page_sources")?.update();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.save),
            tooltip: "保存并重新加载配置",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(height: 0.6, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: current),
              onChanged: (value) => current = value,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _addAllPagesWithComicSource(ComicSource source) {
  var explorePages = appdata.appSettings.explorePages;
  var categoryPages = appdata.appSettings.categoryPages;
  var networkFavorites = appdata.appSettings.networkFavorites;

  if (source.explorePages.isNotEmpty) {
    for (var page in source.explorePages) {
      if (!explorePages.contains(page.title)) {
        explorePages.add(page.title);
      }
    }
  }
  if (source.categoryData != null &&
      !categoryPages.contains(source.categoryData!.key)) {
    categoryPages.add(source.categoryData!.key);
  }
  if (source.favoriteData != null &&
      !networkFavorites.contains(source.favoriteData!.key)) {
    networkFavorites.add(source.favoriteData!.key);
  }

  appdata.appSettings.explorePages = explorePages.toSet().toList();
  appdata.appSettings.categoryPages = categoryPages.toSet().toList();
  appdata.appSettings.networkFavorites = networkFavorites.toSet().toList();

  appdata.updateSettings();
}
