part of pica_reader;

void showSettings(BuildContext context) {
  showSideBar(
      context,
      const ReadingSettings(),
      width: 400);
}

class ReadingSettings extends StatefulWidget {
  const ReadingSettings({Key? key}) : super(key: key);

  @override
  State<ReadingSettings> createState() => _ReadingSettingsState();
}

class _ReadingSettingsState extends State<ReadingSettings> {
  bool pageChangeValue = appdata.settings[0] == "1";
  bool useVolumeKeyChangePage = appdata.settings[7] == "1";
  bool keepScreenOn = appdata.settings[14] == "1";
  bool lowBrightness = appdata.settings[18] == "1";
  var value = int.parse(appdata.settings[9]);
  int i = 0;

  void setValue(int newValue) {
    App.globalBack();
    value = newValue;
    appdata.settings[9] = value.toString();
    appdata.writeData();
    var logic = StateController.find<ComicReadingPageLogic>();
    logic.tools = false;
    logic.showSettings = false;
    logic.index = 1;
    logic.pageController = PageController(initialPage: 1);
    logic.clearPhotoViewControllers();
    logic.update();
  }

  @override
  Widget build(BuildContext context) {
    var logic = StateController.find<ComicReadingPageLogic>();

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        reverseDuration: const Duration(milliseconds: 0),
        switchInCurve: Curves.ease,
        transitionBuilder: (Widget child, Animation<double> animation) {
          Tween<Offset> tween;
          if (i == 0) {
            tween = Tween<Offset>(
                begin: const Offset(-0.1, 0), end: const Offset(0, 0));
          } else {
            tween = Tween<Offset>(
                begin: const Offset(0.1, 0), end: const Offset(0, 0));
          }
          return SlideTransition(
            position: tween.animate(animation),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: Key(i.toString()),
          child: i == 0 
            ? _buildMainSettings(context, logic)
            : i == 1 
              ? _buildReadingModeSettings(context)
              : _buildProxySettings(context),
        ),
      ),
    );
  }

  /// 主设置页面 - venera 风格
  Widget _buildMainSettings(BuildContext context, ComicReadingPageLogic logic) {
    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          pinned: true,
          title: Text("阅读设置".tl),
        ),
        // 阅读模式
        SliverToBoxAdapter(
          child: ListTile(
            leading: const Icon(Icons.chrome_reader_mode),
            title: Text("阅读模式".tl),
            trailing: Select(
              width: 136,
              initialValue: int.parse(appdata.settings[9]) - 1,
              values: [
                "从左至右".tl,
                "从右至左".tl,
                "从上至下".tl,
                "从上至下(连续)".tl,
                "双页".tl,
                "双页(反向)".tl
              ],
              onChange: (i) => setValue(i + 1),
            ),
          ),
        ),
        // 首页显示单张图片（双页模式）
        if (appdata.settings[9] == "5" || appdata.settings[9] == "6")
          SliverToBoxAdapter(
            child: SwitchListTile(
              title: Text("首页显示单张图片".tl),
              value: appdata.implicitData[1] == '1',
              onChanged: (b) {
                appdata.implicitData[1] = b ? '1' : '0';
                appdata.writeData();
                setState(() {});
                logic.update();
              },
            ),
          ),
        // 点按翻页
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("点按翻页".tl),
            value: pageChangeValue,
            onChanged: (b) {
              b ? appdata.settings[0] = "1" : appdata.settings[0] = "0";
              setState(() => pageChangeValue = b);
              appdata.writeData();
            },
          ),
        ),
        // 点按翻页识别范围
        if (appdata.settings[0] == "1")
          SliverToBoxAdapter(
            child: ListTile(
              leading: const SizedBox(width: 40),
              title: Text("点按翻页识别范围".tl),
              subtitle: Slider(
                max: 40,
                min: 0,
                divisions: 40,
                value: int.parse(appdata.settings[40]).toDouble(),
                onChanged: (v) {
                  if (v == 0) return;
                  appdata.settings[40] = v.toInt().toString();
                  appdata.updateSettings();
                  setState(() {});
                },
              ),
              trailing: SizedBox(
                width: 40,
                child: Text(
                  "${appdata.settings[40]}%",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        // 反转点按翻页
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("反转点按翻页".tl),
            value: appdata.settings[70] == "1",
            onChanged: (b) => setState(() {
              appdata.settings[70] = b ? "1" : "0";
              appdata.updateSettings();
            }),
          ),
        ),
        // 使用音量键翻页
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("使用音量键翻页".tl),
            value: useVolumeKeyChangePage,
            onChanged: (b) {
              b ? appdata.settings[7] = "1" : appdata.settings[7] = "0";
              setState(() => useVolumeKeyChangePage = b);
              appdata.writeData();
              logic.update();
            },
          ),
        ),
        // 自动翻页时间间隔
        SliverToBoxAdapter(
          child: ListTile(
            leading: const Icon(Icons.timer_sharp),
            title: Text("自动翻页时间间隔".tl),
            subtitle: Slider(
              max: 20,
              min: 0,
              divisions: 20,
              value: int.parse(appdata.settings[33]).toDouble(),
              onChanged: (v) {
                if (v == 0) return;
                appdata.settings[33] = v.toInt().toString();
                appdata.updateSettings();
                setState(() {});
              },
            ),
            trailing: SizedBox(
              width: 40,
              child: Text(
                "${appdata.settings[33]}s",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        // 保持屏幕常亮
        if (App.isAndroid)
          SliverToBoxAdapter(
            child: SwitchListTile(
              title: Text("保持屏幕常亮".tl),
              value: keepScreenOn,
              onChanged: (b) {
                b ? setKeepScreenOn() : cancelKeepScreenOn();
                b ? appdata.settings[14] = "1" : appdata.settings[14] = "0";
                setState(() => keepScreenOn = b);
                appdata.writeData();
              },
            ),
          ),
        // 深色模式下降低图片亮度
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("深色模式下降低图片亮度".tl),
            value: lowBrightness,
            onChanged: (b) {
              b ? appdata.settings[18] = "1" : appdata.settings[18] = "0";
              setState(() => lowBrightness = b);
              appdata.writeData();
              logic.update();
            },
          ),
        ),
        // 固定屏幕方向
        if (App.isAndroid)
          SliverToBoxAdapter(
            child: ListTile(
              leading: const Icon(Icons.screen_lock_rotation),
              title: Text("固定屏幕方向".tl),
              trailing: Select(
                initialValue: int.parse(appdata.settings[76]),
                values: [
                  "禁用".tl,
                  "横屏".tl,
                  "竖屏".tl,
                ],
                onChange: (int i) {
                  appdata.settings[76] = i.toString();
                  logic.update();
                  appdata.updateSettings();
                  if (i == 1) {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight
                    ]);
                  } else if (i == 2) {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.portraitDown,
                    ]);
                  }
                  setState(() {});
                },
              ),
            ),
          ),
        // 图片缩放
        if (logic.readingMethod != ReadingMethod.topToBottomContinuously)
          SliverToBoxAdapter(
            child: ListTile(
              leading: const Icon(Icons.fit_screen_outlined),
              title: Text("图片缩放".tl),
              trailing: Select(
                initialValue: int.parse(appdata.settings[41]),
                values: ["容纳".tl, "适应宽度".tl, "适应高度".tl],
                onChange: (int i) {
                  appdata.settings[41] = i.toString();
                  appdata.updateSettings();
                  logic.photoViewController.resetWithNewBoxFit(switch(i){
                    0 => BoxFit.contain,
                    1 => BoxFit.fitWidth,
                    2 => BoxFit.fitHeight,
                    _ => BoxFit.contain,
                  });
                },
              ),
            ),
          ),
        // 双击缩放
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("双击缩放".tl),
            value: appdata.settings[49] == "1",
            onChanged: (value) {
              appdata.settings[49] = value ? "1" : "0";
              logic.update();
              appdata.updateSettings();
              setState(() {});
            },
          ),
        ),
        // 限制图片最大显示宽度
        if (logic.readingMethod == ReadingMethod.topToBottomContinuously)
          SliverToBoxAdapter(
            child: SwitchListTile(
              title: Text("限制图片最大显示宽度".tl),
              value: appdata.settings[43] == "1",
              onChanged: (b) => setState(() {
                appdata.settings[43] = b ? "1" : "0";
                appdata.updateSettings();
                Future.microtask(() => logic.update());
              }),
            ),
          ),
        // 长按缩放
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("长按缩放".tl),
            value: appdata.settings[55] == "1",
            onChanged: (b) => setState(() {
              appdata.settings[55] = b ? "1" : "0";
              appdata.updateSettings();
              Future.microtask(() => logic.update());
            }),
          ),
        ),
        // 显示页面信息
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("显示页面信息".tl),
            value: appdata.settings[57] == "1",
            onChanged: (b) => setState(() {
              appdata.settings[57] = b ? "1" : "0";
              appdata.updateSettings();
              Future.microtask(() => logic.update());
            }),
          ),
        ),
        // 设置分流
        if (!logic.data.downloaded &&
            (logic.data.type == ReadingType.picacg ||
                logic.data.type == ReadingType.jm))
          SliverToBoxAdapter(
            child: ListTile(
              leading: const Icon(Icons.account_tree_sharp),
              title: Text("设置分流".tl),
              trailing: const Icon(Icons.arrow_right),
              onTap: () => setState(() => i = 2),
            ),
          ),
        // 底部安全区域
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom),
        ),
      ],
    );
  }

  /// 阅读模式设置页面
  Widget _buildReadingModeSettings(BuildContext context) {
    var options = [
      "从左至右".tl,
      "从右至左".tl,
      "从上至下".tl,
      "从上至下(连续)".tl,
      "双页".tl,
      "双页(反向)".tl
    ];

    return CustomScrollView(
      slivers: [
        // AppBar with back button
        SliverAppBar(
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => i = 0),
          ),
          title: Text("阅读模式".tl),
        ),
        // 阅读模式选项
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ListTile(
              trailing: Radio<int>(
                value: index + 1,
                groupValue: value,
                onChanged: (i) => setValue(i!),
              ),
              title: Text(options[index]),
              onTap: () => setValue(index + 1),
            ),
            childCount: 6,
          ),
        ),
        // 底部安全区域
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom),
        ),
      ],
    );
  }

  /// 分流设置页面
  Widget _buildProxySettings(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // AppBar with back button
        SliverAppBar(
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => i = 0),
          ),
          title: Text("设置分流".tl),
        ),
        // 重启阅读器按钮
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: FilledButton(
                child: Text("重启阅读器".tl),
                onPressed: () {
                  App.globalBack();
                  var logic = StateController.find<ComicReadingPageLogic>();
                  logic.refresh_();
                },
              ),
            ),
          ),
        ),
        // 底部安全区域
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom),
        ),
      ],
    );
  }
}
