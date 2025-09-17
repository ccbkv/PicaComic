part of pica_settings;

class SetJmComicsOrderController extends StateController{
  int settingsOrder;
  SetJmComicsOrderController(this.settingsOrder);
  late String value = appdata.settings[settingsOrder];

  void set(String v){
    value = v;
    appdata.settings[settingsOrder] = v;
    appdata.writeData();
    App.globalBack();
  }
}


class JmSettings extends StatefulWidget {
  const JmSettings(this.popUp, {Key? key}) : super(key: key);
  final bool popUp;

  @override
  State<JmSettings> createState() => _JmSettingsState();

  static const builtInApiDomains = <String>[
    "www.cdnaspa.vip",
    "www.cdnaspa.club",
    "www.cdnplaystation6.vip",
    "www.cdnplaystation6.cc"
  ];

  static void updateApiDomains([bool showLoading = false]) async {
    var title = "";
    var msg = "";
    List<String> domains = builtInApiDomains;
    var controller = showLoading ? showLoadingDialog(App.globalContext!) : null;
    var res = await JmNetwork().getApiDomains();
    if (res.error) {
      title += "更新失败".tl;
      if (res.errorMessage!.isNum) {
        title += ": ${res.errorMessage!}";
      }
      msg += "${"使用内置域名:".tl}\n";
    } else {
      title += "更新成功".tl;
      domains = res.data;
    }
    controller?.close();
    for (String domain in domains) {
        msg += "${"域名".tl}${domains.indexOf(domain) + 1}: $domain\n";
    }
    msg = msg.trim();
    showConfirmDialog(App.globalContext!, title, msg, () {
      appdata.appSettings.jmApiDomains = domains;
      JmNetwork().loginFromAppdata();
    });
  }

  static void daily([bool showLoading = false]) async {
    if (!jm.isLogin && showLoading) {
      showToast(message: "未登录".tl);
      return;
    }
    var controller = showLoading ? showLoadingDialog(App.globalContext!) : null;
    var res = await JmNetwork().dailyChk();
    controller?.close();
    var title = res.success ? "签到成功".tl : "签到失败".tl;
    var msg = res.success ? "${res.subData}".tl : res.errorMessage;
    showDialogMessage(App.globalContext!, title, msg!);
  }
}

class _JmSettingsState extends State<JmSettings> {
  bool autoSelectStream = appdata.settings[15] == "1";
  bool autoCheckIn = appdata.settings[88] == "1";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text("禁漫天堂".tl),
        ),
        ListTile(
          leading: const Icon(Icons.track_changes),
          title: Text("自动选择域名".tl),
          subtitle: Text("登录时自动选择API域名".tl),
          trailing: Switch(
            value: autoSelectStream,
            onChanged: (b){
              b ? appdata.settings[15] = "1" : appdata.settings[15] = "0";
              setState(() {
                autoSelectStream = b;
              });
              appdata.updateSettings();
              if (autoSelectStream) JmNetwork().loginFromAppdata();
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: Text("API域名".tl),
          trailing: IgnorePointer(
            ignoring: autoSelectStream,
            child: Opacity(
              opacity: !autoSelectStream ? 1.0 : 0.5,
              child: Select(
                initialValue: int.parse(appdata.settings[17]),
                values: [
                  "分流1".tl,"分流2".tl,"分流3".tl,"分流4".tl,
                ],
                onChange: (i){
                  appdata.settings[17] = i.toString();
                  appdata.updateSettings();
                  JmNetwork().loginFromAppdata();
                },
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text("图片分流".tl),
          trailing: Select(
            initialValue: int.parse(appdata.appSettings.jmImgUrlIndex),
            values: [
              "分流1".tl,"分流2".tl,"分流3".tl,"分流4".tl
            ],
            onChange: (i){
              appdata.settings[37] = i.toString();
              appdata.updateSettings();
              if (jm.isLogin) JmNetwork().updateImgUrl(i + 1);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_border),
          title: Text("收藏夹漫画排序模式".tl),
          trailing: Select(
            initialValue: int.parse(appdata.settings[42]),
            width: App.locale.languageCode == "en" ? 130 : 120,
            values: [
              "最新收藏".tl, "最新更新".tl
            ],
            onChange: (i){
              appdata.settings[42] = i.toString();
              appdata.updateSettings();
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.update_outlined),
          title: Text("更新API域名".tl),
          onTap: () => JmSettings.updateApiDomains(true),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.today),
          title: Text("每日签到".tl),
          subtitle: Text("勾选启用, 点击测试".tl),
          onTap: () => JmSettings.daily(true),
          trailing: Switch(
            value: autoCheckIn,
            onChanged: (b){
              b ? appdata.settings[88] = "1" : appdata.settings[88] = "0";
              setState(() {
                autoCheckIn = b;
              });
              appdata.updateSettings();
              if (autoCheckIn && jm.isLogin) JmSettings.daily(false);
            },
          ),
        ),
      ],
    );
  }
}