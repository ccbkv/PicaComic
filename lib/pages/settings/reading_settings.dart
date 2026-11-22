part of pica_settings;

class ReadingSettings extends StatefulWidget {
  const ReadingSettings(this.popUp, {super.key});

  final bool popUp;

  @override
  State<ReadingSettings> createState() => _ReadingSettingsState();
}

class _ReadingSettingsState extends State<ReadingSettings> {
  bool keepScreenOn = appdata.settings[14] == "1";
  bool lowBrightness = appdata.settings[18] == "1";
  bool pageChangeValue = appdata.settings[0] == "1";
  bool showThreeButton = appdata.settings[4] == "1";
  bool useVolumeKeyChangePage = appdata.settings[7] == "1";

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectSetting(
          leading: const Icon(Icons.chrome_reader_mode),
          title: "阅读模式".tl,
          initialValue: int.parse(appdata.settings[9]) - 1,
          values: [
            "从左至右".tl,
            "从右至左".tl,
            "从上至下".tl,
            "从上至下(连续)".tl,
            "双页".tl,
            "双页(反向)".tl
          ],
          onChanged: (i) {
            appdata.settings[9] = (i + 1).toString();
            appdata.updateSettings();
          },
        ),
        SwitchSetting(
          title: "点按翻页".tl,
          settingsIndex: 0,
          icon: const Icon(Icons.touch_app_outlined),
        ),
        SwitchSetting(
          title: "反转点按翻页".tl,
          settingsIndex: 70,
          icon: const Icon(Icons.swap_horiz),
        ),
        if (App.isAndroid)
          SwitchSetting(
            title: "使用音量键翻页".tl,
            settingsIndex: 7,
            icon: const Icon(Icons.volume_mute),
          ),
        ListTile(
          leading: const Icon(Icons.comment),
          title: Text("显示章节评论".tl),
          trailing: AdaptiveSwitch(
            value: appdata.settings.length > 92
                ? appdata.settings[92] == "1"
                : true,
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 92) {
                  appdata.settings.add("1");
                }
                appdata.settings[92] = b ? "1" : "0";
                if (!b) {
                  while (appdata.settings.length <= 99) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[99] = "0";
                }
              });
              appdata.updateSettings();
            },
          ),
        ),
        if (appdata.settings.length > 92 ? appdata.settings[92] == "1" : true)
          ListTile(
            leading: const Icon(Icons.comment_bank),
            title: Text("章节末尾显示评论".tl),
            trailing: AdaptiveSwitch(
              value: appdata.settings.length > 99
                  ? appdata.settings[99] == "1"
                  : false,
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 99) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[99] = b ? "1" : "0";
                });
                appdata.updateSettings();
              },
            ),
          ),
        ListTile(
          leading: const Icon(Icons.save),
          title: Text("下载时保存章节评论".tl),
          subtitle: Text("断网时也可查看已保存的章节评论".tl),
          trailing: AdaptiveSwitch(
            value: appdata.settings.length > 102
                ? appdata.settings[102] == "1"
                : false,
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 102) {
                  appdata.settings.add("0");
                }
                appdata.settings[102] = b ? "1" : "0";
              });
              appdata.updateSettings();
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder),
          title: Text("管理已保存的章节评论".tl),
          subtitle: Text("查看或删除已保存的评论文件".tl),
          onTap: () {
            context.to(() => const ChapterCommentsManagerPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.comment_bank),
          title: Text("下载漫画时保存普通评论".tl),
          subtitle: Text("断网时也可查看已保存的漫画评论, 联网时会自动更新".tl),
          trailing: AdaptiveSwitch(
            value: appdata.settings.length > 104
                ? appdata.settings[104] == "1"
                : false,
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 104) {
                  appdata.settings.add("0");
                }
                appdata.settings[104] = b ? "1" : "0";
              });
              appdata.updateSettings();
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.comment_bank),
          title: Text("管理已保存的普通评论".tl),
          subtitle: Text("查看或删除已下载漫画的评论".tl),
          onTap: () {
            context.to(() => const ComicCommentsManagerPage());
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text("文件管理器".tl),
          subtitle: Text("浏览应用私有目录".tl),
          onTap: () => context.to(() => const FileManagerPage()),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.timer_sharp),
          subtitle: SizedBox(
            height: 25,
            child: Stack(
              children: [
                Positioned(
                    top: 0,
                    bottom: 0,
                    left: -20,
                    right: 0,
                    child: Slider(
                      max: 20,
                      min: 0,
                      divisions: 20,
                      value: int.parse(appdata.settings[33]).toDouble(),
                      overlayColor: WidgetStateColor.resolveWith(
                          (states) => Colors.transparent),
                      onChanged: (v) {
                        if (v == 0) return;
                        appdata.settings[33] = v.toInt().toString();
                        appdata.updateSettings();
                        setState(() {});
                      },
                    ))
              ],
            ),
          ),
          trailing: SizedBox(
            width: 40,
            child: Text(
              "${appdata.settings[33]}s",
              style: const TextStyle(fontSize: 14),
            ),
          ),
          title: Text("自动翻页时间间隔".tl),
        ),
        SwitchSetting(
          title: "宽屏时显示控制按钮".tl,
          settingsIndex: 4,
          icon: const Icon(Icons.control_camera),
        ),
        if (App.isAndroid)
          SwitchSetting(
            title: "保持屏幕常亮".tl,
            settingsIndex: 14,
            icon: const Icon(Icons.screenshot_outlined),
          ),
        SwitchSetting(
          title: "深色模式下降低图片亮度".tl,
          settingsIndex: 18,
          icon: const Icon(Icons.brightness_4),
        ),
        if (App.isAndroid)
          SelectSetting(
            leading: const Icon(Icons.screen_lock_rotation),
            title: "固定屏幕方向".tl,
            initialValue: int.parse(appdata.settings[76]),
            values: [
              "禁用".tl,
              "横屏".tl,
              "竖屏".tl,
            ],
            onChanged: (i) {
              appdata.settings[76] = i.toString();
              appdata.updateSettings();
            },
          ),
        if (App.isMobile)
          ListTile(
            leading: const Icon(Icons.signal_cellular_alt),
            title: Text("始终显示状态栏".tl),
            trailing: AdaptiveSwitch(
              value:
                  appdata.settings.length > 95 && appdata.settings[95] == "1",
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 95) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[95] = b ? "1" : "0";
                });
                appdata.updateSettings();
              },
            ),
          ),
        if (App.isMobile)
          SwitchSetting(
            title: "在阅读器中显示时间和电量信息".tl,
            settingsIndex: 98,
            icon: const Icon(Icons.battery_std),
          ),
        SelectSetting(
          leading: const Icon(Icons.image_outlined),
          title: "图片预加载".tl,
          initialValue: ["0", "1", "2", "3", "4", "5", "10", "15"]
              .indexOf(appdata.settings[28]),
          values: const ["0", "1", "2", "3", "4", "5", "10", "15"],
          onChanged: (i) {
            appdata.settings[28] =
                ["0", "1", "2", "3", "4", "5", "10", "15"][i];
            appdata.updateSettings();
          },
        ),
        SwitchSetting(
          title: "双击缩放".tl,
          settingsIndex: 49,
          icon: const Icon(Icons.zoom_out_map),
        ),
        SwitchSetting(
          title: "长按缩放".tl,
          settingsIndex: 55,
          icon: const Icon(Icons.zoom_in),
        ),
        SwitchSetting(
          title: "显示页面信息".tl,
          settingsIndex: 57,
          icon: const Icon(Icons.insert_drive_file_outlined),
        ),
        SwitchSetting(
          title: "使用深色背景".tl,
          settingsIndex: 81,
          icon: const Icon(Icons.dark_mode),
        ),
        const ImageEnhanceSettings(showTitle: true),
        Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
      ],
    );
  }
}

class ImageEnhanceSettings extends StatefulWidget {
  const ImageEnhanceSettings({super.key, this.showTitle = false});

  final bool showTitle;

  @override
  State<ImageEnhanceSettings> createState() => _ImageEnhanceSettingsState();
}

class _ImageEnhanceSettingsState extends State<ImageEnhanceSettings> {
  Widget _slider(
    String title,
    int settingsIndex,
    double max,
    double fallback,
  ) {
    final value = (double.tryParse(appdata.settings[settingsIndex]) ?? fallback)
        .clamp(0.0, max)
        .toDouble();
    return ListTile(
      leading: const SizedBox(width: 40),
      title: Text(title),
      subtitle: Slider(
        min: 0,
        max: max,
        divisions: (max * 10).round(),
        value: value,
        onChanged: (value) {
          setState(() {
            appdata.settings[settingsIndex] = value.toStringAsFixed(1);
          });
          appdata.updateSettings();
        },
      ),
      trailing: SizedBox(
        width: 36,
        child: Text(value.toStringAsFixed(1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTitle) SettingsTitle("图片处理 / 增强".tl),
        ListTile(
          leading: const Icon(Icons.auto_fix_high),
          title: Text("图像增强".tl),
          subtitle: Text("锐化模糊图片，并在渲染时调整清晰度".tl),
          trailing: AdaptiveSwitch(
            value:
                appdata.settings[ImageEnhanceShader.enabledSettingIndex] == "1",
            onChanged: (value) {
              setState(() {
                appdata.settings[ImageEnhanceShader.enabledSettingIndex] =
                    value ? "1" : "0";
              });
              appdata.updateSettings();
            },
          ),
        ),
        if (appdata.settings[ImageEnhanceShader.enabledSettingIndex] ==
            "1") ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ImageEnhancePreview(
              settingsVersion: Object.hash(
                appdata.settings[ImageEnhanceShader.strengthSettingIndex],
                appdata.settings[ImageEnhanceShader.claritySettingIndex],
                appdata.settings[ImageEnhanceShader.contrastSettingIndex],
                appdata.settings[ImageEnhanceShader.vibranceSettingIndex],
              ),
            ),
          ),
          _slider(
            "锐化强度".tl,
            ImageEnhanceShader.strengthSettingIndex,
            ImageEnhanceShader.maxStrength,
            0.5,
          ),
          _slider(
            "清晰度".tl,
            ImageEnhanceShader.claritySettingIndex,
            1.0,
            0.0,
          ),
          _slider(
            "对比度".tl,
            ImageEnhanceShader.contrastSettingIndex,
            1.0,
            0.0,
          ),
          _slider(
            "色彩鲜艳度".tl,
            ImageEnhanceShader.vibranceSettingIndex,
            1.0,
            0.0,
          ),
        ],
      ],
    );
  }
}
