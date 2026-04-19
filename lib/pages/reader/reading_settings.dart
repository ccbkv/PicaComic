part of 'comic_reading_page.dart';

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

class _ComicSwitchSetting extends StatelessWidget {
  final String title;
  final int settingIndex;
  final String? comicId;
  final String? sourceKey;
  final VoidCallback? onChanged;

  const _ComicSwitchSetting({
    required this.title,
    required this.settingIndex,
    this.comicId,
    this.sourceKey,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: appdata.getReaderSetting(comicId, sourceKey, settingIndex) == "1",
      onChanged: (b) {
        appdata.setReaderSetting(comicId, sourceKey, settingIndex, b ? "1" : "0");
        appdata.updateSettings();
        onChanged?.call();
      },
    );
  }
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
    var comicId = logic.data.id;
    var sourceKey = logic.data.sourceKey;
    var isEnabledSpecificSettings = appdata.isComicSpecificSettingsEnabled(comicId, sourceKey);

    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          pinned: true,
          title: Text("阅读设置".tl),
        ),
        // 漫画特定设置
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("启用此漫画特定设置".tl),
            value: isEnabledSpecificSettings,
            onChanged: (b) {
              setState(() {
                appdata.setEnabledComicSpecificSettings(comicId, sourceKey, b);
              });
            },
          ),
        ),
        if (isEnabledSpecificSettings)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    // 清除当前漫画的特定设置
                    appdata.setEnabledComicSpecificSettings(comicId, sourceKey, false);
                  });
                },
                child: Text("清除该漫画的特殊阅读设置".tl),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: Divider()),
        // 阅读模式
        SliverToBoxAdapter(
          child: ListTile(
            leading: const Icon(Icons.chrome_reader_mode),
            title: Text("阅读模式".tl),
            trailing: Select(
              width: 136,
              initialValue: int.parse(appdata.getReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                9,
              )) - 1,
              values: [
                "从左至右".tl,
                "从右至左".tl,
                "从上至下".tl,
                "从上至下(连续)".tl,
                "双页".tl,
                "双页(反向)".tl
              ],
              onChange: (i) {
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  9,
                  (i + 1).toString(),
                );
                appdata.updateSettings();
                setValue(i + 1);
              },
            ),
          ),
        ),
        // 首页显示单张图片（双页模式）
        if (appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              9,
            ) == "5" ||
            appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              9,
            ) == "6")
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
        // 显示章节评论
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("显示章节评论".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              92,
            ) == "1",
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 92) {
                  appdata.settings.add("1");
                }
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  92,
                  b ? "1" : "0",
                );
                if (!b) {
                  while (appdata.settings.length <= 99) {
                    appdata.settings.add("0");
                  }
                  appdata.setReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    99,
                    "0",
                  );
                }
              });
              appdata.updateSettings();
              try {
                StateController.find<ComicReadingPageLogic>().update();
              } catch (_) {}
            },
          ),
        ),
        if (appdata.settings.length > 92 ? appdata.settings[92] == "1" : true)
          SliverToBoxAdapter(
            child: SwitchListTile(
              title: Text("章节末尾显示评论".tl),
              value: appdata.settings.length > 99 ? appdata.settings[99] == "1" : false,
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 99) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[99] = b ? "1" : "0";
                });
                appdata.updateSettings();
                try {
                  StateController.find<ComicReadingPageLogic>().update();
                } catch (_) {}
              },
            ),
          ),
        // 点按翻页

        if (App.isMobile)
          SliverToBoxAdapter(
            child: SwitchListTile(
              title: Text("在阅读器中显示时间和电量信息".tl),
              value: appdata.getReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                98,
              ) == "1",
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 98) {
                    appdata.settings.add("0");
                  }
                  appdata.setReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    98,
                    b ? "1" : "0",
                  );
                });
                appdata.updateSettings();
              },
            ),
          ),
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("宽屏时显示控制按钮".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              4,
            ) == "1",
            onChanged: (b) {
              setState(() {
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  4,
                  b ? "1" : "0",
                );
              });
              appdata.updateSettings();
              try {
                StateController.find<ComicReadingPageLogic>().update();
              } catch (_) {}
            },
          ),
        ),

        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("点按翻页".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              0,
            ) == "1",
            onChanged: (b) {
              setState(() {
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  0,
                  b ? "1" : "0",
                );
                pageChangeValue = b;
              });
              appdata.writeData();
            },
          ),
        ),
        // 点按翻页识别范围
        if (appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              0,
            ) == "1")
          SliverToBoxAdapter(
            child: ListTile(
              leading: const SizedBox(width: 40),
              title: Text("点按翻页识别范围".tl),
              subtitle: Slider(
                max: 40,
                min: 0,
                divisions: 40,
                value: int.parse(appdata.getReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  40,
                )).toDouble(),
                onChanged: (v) {
                  if (v == 0) return;
                  appdata.setReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    40,
                    v.toInt().toString(),
                  );
                  appdata.updateSettings();
                  setState(() {});
                },
              ),
              trailing: SizedBox(
                width: 40,
                child: Text(
                  "${appdata.getReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    40,
                  )}%",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        // 反转点按翻页
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("反转点按翻页".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              70,
            ) == "1",
            onChanged: (b) => setState(() {
              appdata.setReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                70,
                b ? "1" : "0",
              );
              appdata.updateSettings();
            }),
          ),
        ),
        // 使用音量键翻页
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("使用音量键翻页".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              7,
            ) == "1",
            onChanged: (b) {
              setState(() {
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  7,
                  b ? "1" : "0",
                );
                useVolumeKeyChangePage = b;
              });
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
              value: int.parse(appdata.getReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                33,
              )).toDouble(),
              onChanged: (v) {
                if (v == 0) return;
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  33,
                  v.toInt().toString(),
                );
                appdata.updateSettings();
                setState(() {});
              },
            ),
            trailing: SizedBox(
              width: 40,
              child: Text(
                "${appdata.getReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  33,
                )}s",
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
              value: appdata.getReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                14,
              ) == "1",
              onChanged: (b) {
                b ? setKeepScreenOn() : cancelKeepScreenOn();
                setState(() {
                  appdata.setReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    14,
                    b ? "1" : "0",
                  );
                  keepScreenOn = b;
                });
                appdata.writeData();
              },
            ),
          ),
        // 深色模式下降低图片亮度
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("深色模式下降低图片亮度".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              18,
            ) == "1",
            onChanged: (b) {
              setState(() {
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  18,
                  b ? "1" : "0",
                );
                lowBrightness = b;
              });
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
                initialValue: int.parse(appdata.getReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  76,
                )),
                values: [
                  "禁用".tl,
                  "横屏".tl,
                  "竖屏".tl,
                ],
                onChange: (int i) {
                  appdata.setReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    76,
                    i.toString(),
                  );
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
                initialValue: int.parse(appdata.getReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  41,
                )),
                values: ["容纳".tl, "适应宽度".tl, "适应高度".tl],
                onChange: (int i) {
                  appdata.setReaderSetting(
                    isEnabledSpecificSettings ? comicId : null,
                    isEnabledSpecificSettings ? sourceKey : null,
                    41,
                    i.toString(),
                  );
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
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              49,
            ) == "1",
            onChanged: (value) {
              appdata.setReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                49,
                value ? "1" : "0",
              );
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
              value: appdata.getReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                43,
              ) == "1",
              onChanged: (b) => setState(() {
                appdata.setReaderSetting(
                  isEnabledSpecificSettings ? comicId : null,
                  isEnabledSpecificSettings ? sourceKey : null,
                  43,
                  b ? "1" : "0",
                );
                appdata.updateSettings();
                Future.microtask(() => logic.update());
              }),
            ),
          ),
        // 长按缩放
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("长按缩放".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              55,
            ) == "1",
            onChanged: (b) => setState(() {
              appdata.setReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                55,
                b ? "1" : "0",
              );
              appdata.updateSettings();
              Future.microtask(() => logic.update());
            }),
          ),
        ),
        // 显示页面信息
        SliverToBoxAdapter(
          child: SwitchListTile(
            title: Text("显示页面信息".tl),
            value: appdata.getReaderSetting(
              isEnabledSpecificSettings ? comicId : null,
              isEnabledSpecificSettings ? sourceKey : null,
              57,
            ) == "1",
            onChanged: (b) => setState(() {
              appdata.setReaderSetting(
                isEnabledSpecificSettings ? comicId : null,
                isEnabledSpecificSettings ? sourceKey : null,
                57,
                b ? "1" : "0",
              );
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
