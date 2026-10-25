part of pica_settings;

class ComicSourceSettings extends StatefulWidget {
  const ComicSourceSettings({super.key, this.onBack, this.showHeader = true});

  /// 覆盖头部返回键行为 (嵌入设置页时返回分类列表, 而非退出整个路由)
  final VoidCallback? onBack;

  /// 是否显示自带的固定头部 (Fluent 嵌入模式下由外层 PageHeader 提供标题)
  final bool showHeader;

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
          if (widget.showHeader)
            SliverPersistentHeader(
              pinned: true,
              delegate: _ComicSourceAppBarDelegate(
                title: "漫画源".tl,
                topPadding: MediaQuery.of(context).padding.top,
                onBack: widget.onBack,
              ),
            ),
          buildCard(context),
          _SliverBuiltInSources(
            onAdd: handleAddSource,
            onDelete: delete,
          ),
          if (appdata.appSettings.isComicSourceEnabled("picacg"))
            const SliverPicacgSettings(),
          if (appdata.appSettings.isComicSourceEnabled("ehentai"))
            const SliverEhSettings(),
          if (appdata.appSettings.isComicSourceEnabled("nhentai"))
            const SliverNhSettings(),
          if (appdata.appSettings.isComicSourceEnabled("jm"))
            const SliverJmSettings(),
          if (appdata.appSettings.isComicSourceEnabled("hitomi"))
            const SliverHitomiSettings(),
          if (appdata.appSettings.isComicSourceEnabled("htmanga"))
            const SliverHtSettings(),
          for (var source in ComicSource.sources.where((e) => !e.isBuiltIn))
            _SliverComicSource(
              key: ValueKey(source.key),
              source: source,
              edit: edit,
              update: update,
              delete: delete,
            ),
          SliverPadding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom)),
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
    showConfirmDialog(
      context: App.globalContext!,
      title: "删除".tl,
      content: "要删除漫画源 '${source.name}' 吗?".tl,
      btnColor: context.colorScheme.error,
      onConfirm: () async {
        try {
          var file = File(source.filePath);
          if (await file.exists()) {
            await file.delete();
          }
          ComicSource.sources.remove(source);
          _validatePages();
          if (mounted) setState(() {});
          MyApp.updater?.call();
          StateController.findOrNull(tag: "me_page_sources")?.update();
        } catch (e) {
          showToast(message: e.toString());
        }
      },
    );
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

  static Future<void> update(ComicSource source, {String? url}) async {
    final downloadUrl = url ?? source.url;
    if (!downloadUrl.isURL) {
      showToast(message: "Invalid url config");
      return;
    }
    bool cancel = false;
    var controller = showLoadingDialog(App.globalContext!,
        onCancel: () => cancel = true, barrierDismissible: false);
    try {
      var res = await logDio().get<String>(downloadUrl,
          options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await ComicSourceParser().parse(res.data!, source.filePath);
      await File(source.filePath).writeAsString(res.data!);
    } catch (e) {
      if (cancel) return;
      showToast(message: e.toString());
    } finally {
      controller.close();
    }
    await ComicSource.reload();
    if (ComicSource.find(source.key)?.version == ComicSource.updates[source.key]) {
      ComicSource.updates.remove(source.key);
    }
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
                  label: Text("漫画源列表".tl),
                  onPressed: () {
                    showPopUpWidget(
                      context,
                      _ComicSourceList(handleAddSource,
                          onClose: () => Navigator.of(context).pop()),
                    );
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text("使用配置文件".tl),
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
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['js'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null) {
        try {
          result = await FilePicker.platform.pickFiles(
            withData: true,
            allowMultiple: false,
          );
        } on PlatformException {
          return;
        }
      }
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final lowerName = file.name.toLowerCase();
      if (!lowerName.endsWith('.js')) {
        showToast(message: "仅支持 .js 文件".tl);
        return;
      }
      String content;
      if (file.path != null &&
          file.path!.isNotEmpty &&
          File(file.path!).existsSync()) {
        content = File(file.path!).readAsStringSync();
      } else if (file.bytes != null && file.bytes!.isNotEmpty) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else {
        showToast(message: "读取文件失败".tl);
        return;
      }
      var fileName = file.name;
      await addSource(content, fileName);
    } on PlatformException catch (e) {
      if (e.code == 'unknown_activity' || e.code == 'unknown_activity_error') {
        return;
      }
      LogManager.addLog(
          LogLevel.error, "ComicSourceSettings.chooseFile", e.toString());
      showToast(message: e.toString());
    } catch (e, s) {
      LogManager.addLog(
          LogLevel.error, "ComicSourceSettings.chooseFile", "$e\n$s");
      showToast(message: e.toString());
    }
  }

  void help() {
    AppUrlLauncher.launchExternalUrl(
      "$kProjectRepoUrl/blob/master/doc/comic_source.md",
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
    } finally {
      controller.close();
    }
  }

  Future<void> addSource(String js, String fileName) async {
    var comicSource = await ComicSourceParser().createAndParse(js, fileName);
    ComicSource.sources.add(comicSource);
    _addAllPagesWithComicSource(comicSource);
    appdata.updateSettings();
    if (mounted) setState(() {});
    MyApp.updater?.call();
    StateController.findOrNull(tag: "me_page_sources")?.update();
  }
}

Future<int> checkComicSourceUpdate() async {
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
  ComicSource.updates = {for (var key in shouldUpdate) key: versions[key]!};
  StateController.findOrNull(tag: "me_page_sources")?.update();
  return shouldUpdate.length;
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
        return ContentDialog(
          title: "有可用更新".tl,
          content: Text(text).paddingHorizontal(16).paddingVertical(8),
          actions: [
            Button.filled(
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
    controller.text =
        "https://raw.githubusercontent.com/ccbkv/pica_configs/refs/heads/master/index.json";
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
          IconButton(
              onPressed: widget.onClose ?? App.globalBack,
              icon: const Icon(Icons.close)),
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
                        AppUrlLauncher.launchExternalUrl(
                          "$kProjectRepoUrl/blob/master/doc/comic_source.md",
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
                      url = listUrl.substring(0, listUrl.lastIndexOf("/") + 1) +
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

/// COPY (拷贝漫画) 高级设置：自动更新开关 + 数据 API / 登录域名节点选择(带测速)
/// + App 版本 / 版本号内联输入框。所有配置项(默认值、选项列表、节点列表)
/// 均由 copy_manga.js 的 `copy_advanced` 元数据下发，改 JS 即可改配置，无需重编译 App。
class SliverCopySettings extends StatefulWidget {
  const SliverCopySettings({super.key, required this.source, required this.meta});

  final ComicSource source;

  /// copy_manga.js `settings.copy_advanced` 元数据。
  final Map<dynamic, dynamic> meta;

  @override
  State<SliverCopySettings> createState() => _SliverCopySettingsState();
}

class _SliverCopySettingsState extends State<SliverCopySettings> {
  late String _defaultApiHost;
  late String _defaultAppVersion;
  late String _defaultVersionCode;
  late String _defaultLoginHost;
  late String _defaultContentHost;
  late List<String> _loginHostOptions;
  late List<List<String>> _contentRoutes;
  late List<String> _selectionModeOptions;
  late String _selectionMode;
  late int _contentRoute;
  late String _contentHost;
  bool _autoFillBusy = false;
  bool _testingLatency = false;

  ComicSource get source => widget.source;

  late final TextEditingController _apiHostController;
  late final TextEditingController _appVersionController;
  late final TextEditingController _versionCodeController;
  late final TextEditingController _customLoginController;

  late List<String> _customApiHosts;
  late List<String> _customLoginHosts;
  late String _loginHost;
  late bool _autoUpdate;

  final Map<String, int?> _latency = {};
  final Set<String> _pending = {};

  String _metaStr(String key, String fallback) {
    final text = widget.meta[key]?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<String> _metaList(String key, List<String> fallback) {
    final value = widget.meta[key];
    if (value is List) {
      final out = value
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (out.isNotEmpty) return out;
    }
    return fallback;
  }

  List<List<String>> _metaRoutes(String key) {
    final value = widget.meta[key];
    if (value is List) {
      final routes = <List<String>>[];
      for (final route in value) {
        if (route is List) {
          final hosts = route
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
          if (hosts.isNotEmpty) routes.add(hosts);
        }
      }
      if (routes.isNotEmpty) return routes;
    }
    return const <List<String>>[];
  }

  String _readSetting(String key, String fallback) {
    final settings = source.data['settings'];
    final value = settings is Map ? settings[key] : null;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  bool _readBool(String key) {
    final settings = source.data['settings'];
    final value = settings is Map ? settings[key] : null;
    if (value is bool) return value;
    if (value is String) return value == 'true';
    return false;
  }

  void _writeSetting(String key, dynamic value) {
    final settings = source.data['settings'] ??= <String, dynamic>{};
    settings[key] = value;
    source.saveData();
  }

  void _writeApiHost(String host) {
    final settings = source.data['settings'] ??= <String, dynamic>{};
    if (host.isEmpty || host == _defaultApiHost) {
      settings.remove('base_url');
      settings.remove('base_url_override');
    } else {
      settings['base_url'] = host;
      settings['base_url_override'] = true;
    }
    source.saveData();
  }

  List<String> _readStringList(String key) {
    final settings = source.data['settings'];
    final raw = settings is Map ? settings[key] : null;
    return raw is List
        ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
  }

  @override
  void initState() {
    super.initState();
    _defaultApiHost = _metaStr('defaultApiHost', '');
    _defaultAppVersion = _metaStr('defaultAppVersion', '');
    _defaultVersionCode = _metaStr('defaultVersionCode', '');
    _defaultLoginHost = _metaStr('defaultLoginHost', '');
    _defaultContentHost = _metaStr('defaultContentHost', '');
    _loginHostOptions = _metaList('loginHostOptions', const <String>[]);
    _contentRoutes = _metaRoutes('contentRoutes');
    if (_contentRoutes.isEmpty) {
      _contentRoutes = <List<String>>[[_defaultContentHost]];
    }
    _selectionModeOptions =
        _metaList('selectionModeOptions', const ['线路', '节点']);
    final defaultMode = _metaStr('defaultSelectionMode', 'route');
    _selectionMode =
        _readSetting('content_selection_mode', defaultMode) == 'node'
            ? 'node'
            : 'route';
    _contentRoute = int.tryParse(_readSetting('content_route', '0')) ?? 0;
    if (_contentRoute >= _contentRoutes.length) _contentRoute = 0;
    _contentHost =
        _readSetting('content_host', _contentRoutes.first.first);

    _appVersionController = TextEditingController(
        text: _readSetting('app_version', _defaultAppVersion));
    _versionCodeController = TextEditingController(
        text: _readSetting('version_code', _defaultVersionCode));
    _customLoginController = TextEditingController();

    _customApiHosts = _readStringList('custom_api_hosts');
    _customLoginHosts = _readStringList('custom_login_hosts');
    final savedApiHost = _readSetting('base_url', '');
    final hasApiOverride = _readBool('base_url_override') ||
        _customApiHosts.contains(savedApiHost);
    final apiHost = hasApiOverride && savedApiHost.isNotEmpty
        ? savedApiHost
        : _defaultApiHost;
    _apiHostController = TextEditingController(text: apiHost);
    _loginHost = _readSetting('login_url', _defaultLoginHost);
    _autoUpdate = _readBool('copy_auto_update');
  }

  @override
  void dispose() {
    _apiHostController.dispose();
    _appVersionController.dispose();
    _versionCodeController.dispose();
    _customLoginController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COPY 高级设置',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('自动更新配置', style: tt.bodyMedium),
              value: _autoUpdate,
              onChanged: (v) {
                setState(() => _autoUpdate = v);
                _writeSetting('copy_auto_update', v);
              },
            ),
            _buildNetworkStatusSection(cs, tt),
            const SizedBox(height: 16),
            _buildContentNodesSection(cs, tt),
            const SizedBox(height: 16),
            _buildFixedNodeStatus(
              '拷贝节点',
              _normalizeHost(_apiHostController.text, ''),
              cs,
              tt,
            ),
            const SizedBox(height: 8),
            _buildFixedNodeStatus('拷贝登录', _loginHost, cs, tt),
            const SizedBox(height: 8),
            _buildNodeGroup(
              title: '登录域名',
              hint: '拷贝账号登录接口使用的域名，登录失败时可切换重试',
              builtin: _loginHostOptions,
              custom: _customLoginHosts,
              selected: _loginHost,
              onSelect: _selectLoginHost,
              addController: _customLoginController,
              onAdd: _addCustomLogin,
              onEdit: _editCustomLogin,
              onRemove: _removeCustomLogin,
              addHint: '自定义登录域名',
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiHostController,
              decoration: InputDecoration(
                labelText: 'COPY API URL',
                hintText: _defaultApiHost,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appVersionController,
              decoration: InputDecoration(
                labelText: 'COPY 请求版本号',
                hintText: _defaultAppVersion,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _versionCodeController,
              decoration: InputDecoration(
                labelText: 'COPY versionCode',
                hintText: _defaultVersionCode,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
    );
  }

  String get _routeModeLabel =>
      _selectionModeOptions.isNotEmpty ? _selectionModeOptions.first : '线路';

  String get _nodeModeLabel => _selectionModeOptions.length > 1
      ? _selectionModeOptions[1]
      : '节点';

  String _selectedContentHost() {
    if (_selectionMode == 'node') return _contentHost;
    if (_contentRoutes.isEmpty) return '';
    return _contentRoutes[_contentRoute].first;
  }

  List<String> _allContentHosts() {
    final out = <String>[];
    for (final route in _contentRoutes) {
      for (final host in route) {
        if (host.isNotEmpty && !out.contains(host)) out.add(host);
      }
    }
    return out;
  }

  List<String> _allTestHosts() {
    final hosts = <String>{
      ..._allContentHosts(),
      _selectedContentHost(),
      _normalizeHost(_apiHostController.text, ''),
      ..._loginHostOptions,
      ..._customLoginHosts,
      _loginHost,
    };
    hosts.removeWhere((host) => host.trim().isEmpty);
    return hosts.toList();
  }

  int _contentNodeNumber(int routeIndex, int localIndex) =>
      _contentRoutes.take(routeIndex).fold<int>(
            0,
            (sum, route) => sum + route.length,
          ) +
      localIndex +
      1;

  double? _averageContentLatency(List<String> hosts) {
    final values = hosts.map((h) => _latency[h]).whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int? _bestNumericLatency() {
    int? best;
    for (final host in _allTestHosts()) {
      final ms = _latency[host];
      if (ms != null && (best == null || ms < best)) best = ms;
    }
    return best;
  }

  ({String primary, String secondary, Color color}) _networkStatus(
      ColorScheme cs) {
    if (_testingLatency) {
      return (
        primary: '正在检测',
        secondary: '正在检测各节点...',
        color: cs.primary,
      );
    }
    final average = _contentRoute >= 0 && _contentRoute < _contentRoutes.length
        ? _averageContentLatency(_contentRoutes[_contentRoute])
        : null;
    final best = _bestNumericLatency();
    if (average == null) {
      return (
        primary: '尚未检测',
        secondary: '点击下方按钮测速，了解各节点延迟',
        color: cs.onSurfaceVariant,
      );
    }
    if (average <= 800) {
      return (
        primary: '网络通畅',
        secondary: best == null ? '连接正常，状态良好' : '当前最佳延迟 $best ms，状态良好',
        color: Colors.green,
      );
    }
    if (average <= 2000) {
      return (
        primary: '延迟偏高',
        secondary: best == null ? '当前延迟较大，建议开启代理' : '当前延迟约 $best ms，建议开启代理',
        color: Colors.orange,
      );
    }
    return (
      primary: '连接异常',
      secondary: '当前延迟较大，建议开启代理',
      color: cs.error,
    );
  }

  Widget _buildNetworkStatusSection(ColorScheme cs, TextTheme tt) {
    final status = _networkStatus(cs);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          status.color.withValues(alpha: 0.10),
          cs.surfaceBright,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.primary,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.secondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _testingLatency
                ? null
                : () => _testHosts(_allTestHosts()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: _testingLatency
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('测速'),
          ),
        ],
      ),
    );
  }

  Color _contentHostDotColor(String host, ColorScheme cs) {
    if (_pending.contains(host)) return cs.primary;
    if (!_latency.containsKey(host)) return cs.onSurfaceVariant;
    final ms = _latency[host];
    return ms == null ? cs.error : _latencyColor(ms, cs);
  }

  /// 线路与节点：模式选择（线路 / 节点）+ 线路卡片，对应正文 CDN 域名。
  Widget _buildContentNodesSection(ColorScheme cs, TextTheme tt) {
    final isFixed = _selectionMode == 'node';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '线路与节点',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(_routeModeLabel),
                  selected: !isFixed,
                  onSelected: (_) => _setSelectionMode(_routeModeLabel),
                ),
                ChoiceChip(
                  label: Text(_nodeModeLabel),
                  selected: isFixed,
                  onSelected: (_) => _setSelectionMode(_nodeModeLabel),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            for (var i = 0; i < _contentRoutes.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildContentRouteCard(i, cs, tt),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildContentRouteCard(int index, ColorScheme cs, TextTheme tt) {
    final hosts = _contentRoutes[index];
    final isFixed = _selectionMode == 'node';
    final isSelected = !isFixed && _contentRoute == index;
    final average = _averageContentLatency(hosts);

    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.08)
          : cs.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? cs.primary
              : cs.outlineVariant.withValues(alpha: 0.7),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isFixed ? null : () => _setContentRoute(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '线路 ${index + 1}',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      average == null ? '—' : '平均 ${average.round()} ms',
                      style: tt.labelMedium?.copyWith(
                        color: average == null
                            ? cs.onSurfaceVariant
                            : _latencyColor(average.round(), cs),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '使用中',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (isFixed)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var localIndex = 0;
                        localIndex < hosts.length;
                        localIndex++)
                      _buildContentNodeChip(
                        hosts[localIndex],
                        _contentNodeNumber(index, localIndex),
                        cs,
                        tt,
                      ),
                  ],
                )
              else
                for (var localIndex = 0;
                    localIndex < hosts.length;
                    localIndex++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _contentHostDotColor(hosts[localIndex], cs),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '节点 ${_contentNodeNumber(index, localIndex)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        _buildLatencyText(hosts[localIndex], cs, tt),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentNodeChip(
      String host, int nodeNumber, ColorScheme cs, TextTheme tt) {
    final isSelected = _selectedContentHost() == host;
    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outlineVariant,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _setContentHost(host),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 4),
              ],
              Text(
                '节点 $nodeNumber',
                style: tt.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              _buildLatencyText(host, cs, tt),
            ],
          ),
        ),
      ),
    );
  }

  void _setSelectionMode(String mode) {
    final next = mode == _nodeModeLabel ? 'node' : 'route';
    if (next == _selectionMode) return;
    setState(() => _selectionMode = next);
    _writeSetting('content_selection_mode', next);
  }

  void _setContentRoute(int index) {
    if (index < 0 || index >= _contentRoutes.length) return;
    setState(() => _contentRoute = index);
    _writeSetting('content_route', index);
  }

  void _setContentHost(String host) {
    setState(() => _contentHost = host);
    _writeSetting('content_host', host);
  }

  Widget _buildFixedNodeStatus(
      String label, String host, ColorScheme cs, TextTheme tt) {
    final hasResult = _latency.containsKey(host);
    final latency = _latency[host];
    final color = _pending.contains(host)
        ? cs.primary
        : !hasResult
            ? cs.onSurfaceVariant
            : latency == null
                ? cs.error
                : _latencyColor(latency, cs);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lan_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _buildLatencyText(host, cs, tt),
        ],
      ),
    );
  }

  Widget _buildNodeGroup({
    required String title,
    required String hint,
    required List<String> builtin,
    required List<String> custom,
    required String selected,
    required void Function(String) onSelect,
    required TextEditingController addController,
    required VoidCallback onAdd,
    required void Function(String) onEdit,
    required void Function(String) onRemove,
    required String addHint,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    final hosts = <String>{...builtin, ...custom}.toList();
    final customSet = custom.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                for (var i = 0; i < hosts.length; i++)
                  _buildHostRow(
                    hosts[i],
                    isCustom: customSet.contains(hosts[i]),
                    isSelected: hosts[i] == selected,
                    showDivider: i > 0,
                    onTap: () => onSelect(hosts[i]),
                    onEdit: () => onEdit(hosts[i]),
                    onRemove: () => onRemove(hosts[i]),
                    cs: cs,
                    tt: tt,
                  ),
                _buildAddHostRow(addController, onAdd, addHint, cs),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHostRow(
    String host, {
    required bool isCustom,
    required bool isSelected,
    required bool showDivider,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onRemove,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Column(
      children: [
        if (showDivider)
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
        Material(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                  _buildLatencyText(host, cs, tt),
                  if (isCustom) ...[
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: '编辑',
                      visualDensity: VisualDensity.compact,
                      color: cs.onSurfaceVariant,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: '删除',
                      visualDensity: VisualDensity.compact,
                      color: cs.error,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatencyText(String host, ColorScheme cs, TextTheme tt) {
    if (_pending.contains(host)) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
    }
    if (!_latency.containsKey(host)) {
      return Text('—',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant));
    }
    final ms = _latency[host];
    return Text(
      ms == null ? '超时' : '$ms ms',
      style: tt.labelMedium?.copyWith(
        color: ms == null ? cs.error : _latencyColor(ms, cs),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Color _latencyColor(int ms, ColorScheme cs) {
    if (ms < 150) return Colors.green;
    if (ms < 400) return Colors.orange;
    return cs.error;
  }

  Widget _buildAddHostRow(
    TextEditingController controller,
    VoidCallback onAdd,
    String hint,
    ColorScheme cs,
  ) {
    return Column(
      children: [
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: hint,
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _autoFillBusy ? null : _autoFill,
            icon: _autoFillBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: const Text('填充'),
          ),
          FilledButton.tonalIcon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('重置'),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }

  dynamic _decodeJson(dynamic data) {
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  String get _autoFillApiHost =>
      _normalizeHost(_apiHostController.text, _defaultApiHost);

  Future<void> _autoFill() async {
    if (_autoFillBusy) return;
    setState(() => _autoFillBusy = true);
    try {
      final apiHost = await _fetchCopyApiHost();
      final version = await _fetchCopyLatestVersion();
      if (!mounted) return;
      if (apiHost != null && apiHost.isNotEmpty) {
        _apiHostController.text = apiHost;
      }
      if (version != null && version.isNotEmpty) {
        _appVersionController.text = version;
      }
      setState(() {});
      showToast(
        message: '已填充 COPY API 地址：${apiHost ?? '—'}，版本号：${version ?? '—'}',
      );
    } catch (e) {
      if (!mounted) return;
      showToast(message: '填充失败：$e');
    } finally {
      if (mounted) setState(() => _autoFillBusy = false);
    }
  }

  Future<String?> _fetchCopyApiHost() async {
    final version =
        _trimOrFallback(_appVersionController.text, _defaultAppVersion);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
      headers: {
        'User-Agent': 'COPY/$version',
        'Accept': 'application/json',
        'source': 'copyApp',
        'platform': '3',
        'version': version,
      },
    ));
    final resp = await dio.get(
      'https://$_autoFillApiHost/api/v3/system/network2',
      queryParameters: {'platform': 3},
      options: Options(responseType: ResponseType.plain),
    );
    final data = _decodeJson(resp.data);
    if (data is Map && data['code']?.toString() == '200') {
      final results = data['results'];
      if (results is Map) {
        final api = results['api'];
        if (api is List && api.isNotEmpty) {
          final firstRoute = api.first;
          if (firstRoute is List && firstRoute.isNotEmpty) {
            final host = firstRoute.first?.toString().trim() ?? '';
            if (host.isNotEmpty) return host;
          }
        }
      }
    }
    return null;
  }

  Future<String?> _fetchCopyLatestVersion() async {
    final version =
        _trimOrFallback(_appVersionController.text, _defaultAppVersion);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
      headers: {
        'User-Agent': 'COPY/$version',
        'Accept': 'application/json',
        'source': 'copyApp',
        'platform': '3',
        'version': version,
      },
    ));
    final resp = await dio.get(
      'https://$_autoFillApiHost/api/v3/system/appVersion/last',
      queryParameters: {'platform': 3},
      options: Options(responseType: ResponseType.plain),
    );
    final data = _decodeJson(resp.data);
    if (data is Map && data['code']?.toString() == '200') {
      final results = data['results'];
      if (results is Map) {
        final android = results['android'];
        if (android is Map) {
          final v = android['version']?.toString().trim() ?? '';
          if (v.isNotEmpty) return v;
        }
        final direct = results['version']?.toString().trim() ?? '';
        if (direct.isNotEmpty) return direct;
        for (final value in results.values) {
          if (value is Map) {
            final v = value['version']?.toString().trim() ?? '';
            if (v.isNotEmpty) return v;
          }
        }
      }
    }
    return null;
  }

  void _selectLoginHost(String host) {
    setState(() => _loginHost = host);
    _writeSetting('login_url', host);
  }

  void _addCustomLogin() {
    final host = _normalizeHost(_customLoginController.text, '');
    if (host.isEmpty ||
        _loginHostOptions.contains(host) ||
        _customLoginHosts.contains(host)) {
      _customLoginController.clear();
      return;
    }
    setState(() => _customLoginHosts = [..._customLoginHosts, host]);
    _writeSetting('custom_login_hosts', _customLoginHosts);
    _customLoginController.clear();
  }

  void _editCustomLogin(String oldHost) {
    showInputDialog(
      context: context,
      title: '编辑登录域名',
      initialValue: oldHost,
      onConfirm: (value) {
        final host = _normalizeHost(value.toString(), '');
        if (host.isEmpty ||
            _loginHostOptions.contains(host) ||
            (_customLoginHosts.contains(host) && host != oldHost)) {
          return null;
        }
        setState(() {
          final index = _customLoginHosts.indexOf(oldHost);
          if (index >= 0) {
            _customLoginHosts[index] = host;
          }
          if (_loginHost == oldHost) {
            _loginHost = host;
            _writeSetting('login_url', host);
          }
          _writeSetting('custom_login_hosts', _customLoginHosts);
        });
        return null;
      },
    );
  }

  void _removeCustomLogin(String host) {
    showConfirmDialog(
      context: context,
      title: '删除',
      content: '删除登录域名 "$host" ?',
      onConfirm: () {
        setState(() => _customLoginHosts.remove(host));
        _writeSetting('custom_login_hosts', _customLoginHosts);
        if (_loginHost == host) {
          _loginHost = _defaultLoginHost;
          _writeSetting('login_url', _defaultLoginHost);
        }
      },
    );
  }

  void _save() {
    final apiHost = _normalizeHost(_apiHostController.text, _defaultApiHost);
    final appVersion =
        _trimOrFallback(_appVersionController.text, _defaultAppVersion);
    final versionCode = _normalizeVersionCode(_versionCodeController.text);

    _apiHostController.text = apiHost;
    _appVersionController.text = appVersion;
    _versionCodeController.text = versionCode;

    _writeApiHost(apiHost);
    _writeSetting('app_version', appVersion);
    _writeSetting('version_code', versionCode);
    _writeSetting('login_url', _loginHost);
    _writeSetting('copy_auto_update', _autoUpdate);
    setState(() {});
    showToast(message: '已保存');
  }

  void _reset() {
    _appVersionController.text = _defaultAppVersion;
    _versionCodeController.text = _defaultVersionCode;
    _apiHostController.text = _defaultApiHost;
    _loginHost = _defaultLoginHost;
    _autoUpdate = false;
    _customApiHosts = <String>[];
    _customLoginHosts = <String>[];

    _writeApiHost(_defaultApiHost);
    _writeSetting('app_version', _defaultAppVersion);
    _writeSetting('version_code', _defaultVersionCode);
    _writeSetting('login_url', _defaultLoginHost);
    _writeSetting('copy_auto_update', false);
    _writeSetting('custom_api_hosts', <String>[]);
    _writeSetting('custom_login_hosts', <String>[]);
    setState(() {});
    showToast(message: '已重置');
  }

  Future<void> _testHosts(List<String> hosts) async {
    if (_testingLatency || hosts.isEmpty) return;
    final targets = hosts.toSet().toList();
    setState(() {
      _testingLatency = true;
      _pending
        ..clear()
        ..addAll(targets);
    });
    try {
      await Future.wait(targets.map((host) async {
        final ms = await _measureLatency(host);
        if (!mounted) return;
        setState(() {
          _pending.remove(host);
          _latency[host] = ms;
        });
      }));
    } finally {
      if (mounted) {
        setState(() {
          _testingLatency = false;
          _pending.clear();
        });
      }
    }
  }

  Future<int?> _measureLatency(String host) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
    final sw = Stopwatch()..start();
    try {
      await dio.get(
        'https://$host/',
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      );
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  /// 去协议、去端口两侧空白，保留主机 + 端口；空值时回落 fallback。
  String _normalizeHost(String value, String fallback) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    if (trimmed.contains('://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) return fallback;
      trimmed = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    }
    return trimmed.toLowerCase();
  }

  String _trimOrFallback(String value, String fallback) {
    final text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  String _normalizeVersionCode(String value) {
    final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? _defaultVersionCode : digits;
  }
}

class _SliverBuiltInSources extends StatefulWidget {
  const _SliverBuiltInSources({
    required this.onAdd,
    required this.onDelete,
  });

  final Future<void> Function(String url) onAdd;
  final void Function(ComicSource source) onDelete;

  @override
  State<_SliverBuiltInSources> createState() => _SliverBuiltInSourcesState();
}

class _SliverBuiltInSourcesState extends State<_SliverBuiltInSources> {
  String? _addingKey;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      await checkComicSourceUpdate();
      if (mounted) setState(() {});
    } catch (e) {
      LogManager.addLog(LogLevel.error, 'ComicSourceSettings', e.toString());
    }
  }

  Future<void> add(String key, {ComicSource? installed}) async {
    if (_addingKey != null ||
        (installed == null && ComicSource.find(key) != null)) {
      return;
    }
    setState(() => _addingKey = key);
    try {
      const repository =
          'https://raw.githubusercontent.com/ccbkv/pica_configs/refs/heads/master/';
      String url;
      final response = await logDio().get<String>(
        '${repository}index.json',
        options: Options(responseType: ResponseType.plain),
      );
      final entries = jsonDecode(response.data!) as List;
      final entry = entries.firstWhereOrNull((item) => item['key'] == key);
      if (entry == null) {
        throw '未找到漫画源: $key';
      }
      final configuredUrl = entry['url']?.toString();
      if (configuredUrl != null && configuredUrl.isURL) {
        url = configuredUrl;
      } else {
        final fileName = entry['fileName']?.toString();
        if (fileName == null || fileName.isEmpty) {
          throw '漫画源缺少下载地址: $key';
        }
        url = Uri.parse(repository).resolve(fileName).toString();
      }
      if (!mounted) return;
      if (installed == null) {
        if (ComicSource.find(key) != null) return;
        await widget.onAdd(url);
      } else {
        await _ComicSourceSettingsState.update(installed, url: url);
        if (mounted) {
          context
              .findAncestorStateOfType<_ComicSourceSettingsState>()
              ?.setState(() {});
        }
      }
      await _checkForUpdates();
    } catch (e) {
      showToast(message: e.toString());
    } finally {
      if (mounted) setState(() => _addingKey = null);
    }
  }

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
            title: Text("常用漫画源(github)".tl),
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

  Widget buildTile(int index) {
    var key = builtInSources[index];
    final installed = ComicSource.sources
        .firstWhereOrNull((source) => source.key == key && !source.isBuiltIn);
    final newVersion = ComicSource.updates[key];
    final hasUpdate = installed != null &&
        newVersion != null &&
        newVersion != installed.version;
    return ListTile(
      title: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ComicSource.builtIn.firstWhere((e) => e.key == key).name.tl),
              Text(
                '当前版本号：${installed?.version ?? '未安装'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (hasUpdate) ...[
            Text(
              '新版本可更新：$newVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: _addingKey != null
                  ? null
                  : () => add(key, installed: installed),
              child: Text(_addingKey == key ? '更新中'.tl : '更新'.tl),
            ).fixHeight(32),
          ],
        ],
      ),
      trailing: FilledButton(
        style: installed == null
            ? null
            : FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
        onPressed: _addingKey != null
            ? null
            : () {
                if (installed == null) {
                  add(key);
                } else {
                  widget.onDelete(installed);
                }
              },
        child: Text(
          _addingKey == key && installed == null
              ? '添加中'.tl
              : (installed == null ? '添加'.tl : '删除'.tl),
        ),
      ).fixHeight(32),
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
  bool _callbackRunning = false;

  @override
  void initState() {
    super.initState();
    JmSettings._checkInRevision.addListener(_syncJmCheckIn);
  }

  void _syncJmCheckIn() {
    if (source.key == 'jm') setState(() {});
  }

  @override
  void dispose() {
    JmSettings._checkInRevision.removeListener(_syncJmCheckIn);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var newVersion = ComicSource.updates[source.key];
    bool hasUpdate = newVersion != null && newVersion != source.version;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(padding: const EdgeInsets.only(top: 16)),
        SliverToBoxAdapter(
          child: ListTile(
            title: Wrap(
              spacing: 6,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(source.name, style: const TextStyle(fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    source.version,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (hasUpdate) ...[
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
                      "新版本可更新：$newVersion",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => widget.update(source),
                    child: Text("更新".tl),
                  ).fixHeight(32),
                ],
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

      // COPY 源的高级配置由一个 copy_advanced 组件整体渲染，
      // 这里跳过它本身以及由该组件接管的四个 input 项，避免重复渲染。
      if (source.key == 'copy_manga' &&
          (type == 'copy_advanced' ||
              key == 'base_url' ||
              key == 'app_version' ||
              key == 'version_code' ||
              key == 'login_url')) {
        if (type == 'copy_advanced') {
          widgets.add(SliverToBoxAdapter(
            child: SliverCopySettings(source: source, meta: setting),
          ));
        }
        continue;
      }

      // saveTo == 'data' 时直接读写源数据顶层字段 (与内置哔咔设置页共享)
      bool saveToData = setting['saveTo'] == 'data';
      bool isJmCheckIn = source.key == 'jm' && key == 'dailyCheckInTask';
      Object? readSetting() =>
          isJmCheckIn
              ? appdata.settings[88] == '1'
              : saveToData ? source.data[key] : source.data['settings'][key];
      void writeSetting(Object? value) {
        if (isJmCheckIn) {
          appdata.settings[88] = value == true ? '1' : '0';
          appdata.updateSettings();
          JmSettings._checkInRevision.value++;
          return;
        }
        if (saveToData) {
          source.data[key] = value;
        } else {
          source.data['settings'][key] = value;
        }
        source.saveData();
      }

      try {
        if (type == 'native' &&
            source.key == 'nhentai' &&
            setting['page'] == 'nhentai') {
          widgets.add(const SliverToBoxAdapter(child: NhSettings(false)));
        } else if (type == 'native' &&
            source.key == 'htmanga' &&
            setting['page'] == 'htmanga') {
          widgets.add(const SliverToBoxAdapter(child: HtSettings(false)));
        } else if (type == 'callback') {
          widgets.add(SliverToBoxAdapter(
            child: ListTile(
              leading: Icon(key == 'refreshDomains'
                  ? Icons.update_outlined
                  : key == 'clear_device_info'
                      ? Icons.delete_outline
                      : Icons.today),
              title: Text(title),
              trailing: _callbackRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_right),
              onTap: _callbackRunning
                  ? null
                  : () async {
                      setState(() => _callbackRunning = true);
                      try {
                        await JsEngine().runCode(
                            "ComicSource.sources[${jsonEncode(source.key)}].settings[${jsonEncode(key)}].callback()");
                      } catch (e, s) {
                        log("$e\n$s", "Comic source settings", LogLevel.error);
                        showToast(message: e.toString());
                      } finally {
                        if (mounted) {
                          setState(() => _callbackRunning = false);
                        }
                      }
                    },
            ),
          ));
        } else if (type == 'select') {
          var options = setting['options'] as List? ?? [];
          var defaultValue = setting['default'];

          // Get current value or use default
          var currentValue = readSetting() ?? defaultValue;

          // Find display text for current value
          String currentText = currentValue?.toString() ?? '';
          for (var option in options) {
            if (option is Map && option['value'] == currentValue) {
              currentText = option['text']?.toString() ??
                  option['value']?.toString() ??
                  currentValue.toString();
              break;
            }
          }

          // Build option values and texts
          List<String> optionValues = [];
          List<String> optionTexts = [];
          for (var option in options) {
            if (option is Map) {
              var value = option['value']?.toString() ?? '';
              var text = option['text']?.toString() ??
                  option['value']?.toString() ??
                  '';
              optionValues.add(value);
              optionTexts.add(text);
            }
          }

          if (optionValues.isEmpty) continue;

          // Find current index
          int currentIndex =
              optionValues.indexOf(currentValue?.toString() ?? '');
          if (currentIndex < 0) currentIndex = 0;

          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(title),
                trailing: components.Select(
                  initialValue: currentIndex,
                  values: optionTexts,
                  onChange: (index) {
                    writeSetting(optionValues[index]);
                    setState(() {});
                  },
                ),
              ),
            ),
          );
        } else if (type == 'switch') {
          var defaultValue = setting['default'] ?? false;
          var currentValue = readSetting() ?? defaultValue;

          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(title),
                trailing: AdaptiveSwitch(
                  value: currentValue is bool ? currentValue : false,
                  onChanged: (value) {
                    writeSetting(value);
                    setState(() {});
                  },
                ),
              ),
            ),
          );
        } else if (type == 'input') {
          var defaultValue = setting['default']?.toString() ?? '';
          var currentValue = readSetting()?.toString() ?? defaultValue;

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
                        writeSetting(value);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            ),
          );
        } else if (type == 'action') {
          // 打开指定页面 (目前支持哔咔的留言板/我的评论)
          var action = setting['action'] as String?;
          VoidCallback? onTap;
          IconData? icon;
          switch (action) {
            case 'picacg_leave_messages':
              onTap = () => App.to(context, () => const PicacgLeaveMsgPage());
              icon = Icons.forum;
            case 'picacg_user_comments':
              onTap = () => App.to(context, () => const UserCommentsPage());
              icon = Icons.comment;
          }
          if (onTap == null) continue;
          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                onTap: onTap,
              ),
            ),
          );
        } else if (type == 'appSwitch') {
          // App 级开关 (读写 appdata.settings, 与内置设置页同步)
          var appKey = setting['appKey'] as String?;
          int settingsIndex;
          switch (appKey) {
            case 'showAvatarFrame':
              settingsIndex = 5;
            case 'autoPunchIn':
              settingsIndex = 6;
            default:
              continue;
          }
          widgets.add(
            SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(appKey == 'showAvatarFrame'
                    ? Icons.circle_outlined
                    : Icons.today),
                title: Text(title),
                subtitle: appKey == 'autoPunchIn'
                    ? Text(supportsWorkmanager
                        ? "APP启动或是距离上次打卡间隔一天时执行".tl
                        : "启动时执行".tl)
                    : null,
                trailing: AdaptiveSwitch(
                  value: appdata.settings[settingsIndex] == "1",
                  onChanged: (b) {
                    appdata.settings[settingsIndex] = b ? "1" : "0";
                    if (appKey == 'autoPunchIn' && supportsWorkmanager) {
                      b ? runBackgroundService() : cancelBackgroundService();
                    }
                    appdata.writeData();
                    setState(() {});
                  },
                ),
              ),
            ),
          );
        }
      } catch (e, s) {
        log("Failed to build setting $key: $e\n$s", "ComicSourceSettings",
            LogLevel.error);
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
    showInputDialog(
      context: context,
      title: title,
      initialValue: initialValue,
      onConfirm: (value) {
        onConfirm(value);
        return null;
      },
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
          Container(
              height: 0.6, color: Theme.of(context).colorScheme.outlineVariant),
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

class _ComicSourceAppBarDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final double topPadding;
  final VoidCallback? onBack;

  _ComicSourceAppBarDelegate({
    required this.title,
    required this.topPadding,
    this.onBack,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: shrinkOffset > 0 ? 2 : 0,
        child: Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ).paddingTop(topPadding),
      ),
    );
  }

  @override
  double get maxExtent => 52.0 + topPadding;

  @override
  double get minExtent => 52.0 + topPadding;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _ComicSourceAppBarDelegate ||
        title != oldDelegate.title;
  }
}
