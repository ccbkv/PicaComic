part of pica_settings;

class NetworkSettings extends StatefulWidget {
  const NetworkSettings({super.key});

  @override
  State<NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends State<NetworkSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 新增代理设置选项
        ListTile(
          leading: const Icon(Icons.settings_ethernet),
          title: Text("代理设置".tl),
          trailing: const Icon(Icons.arrow_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const _ProxySettingView(),
            );
          },
        ),
        // 新增DNS覆写设置
        ListTile(
          title: Row(
            children: [
              const Text("Hosts"),
              const SizedBox(
                width: 2,
              ),
              InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                onTap: () => showDialogMessage(
                  context,
                  "警告".tl,
                  "${"此功能已不再受支持".tl}\n${"请勿反馈相关问题".tl}"
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 18,
                ),
              )
            ]
          )
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: Text("启用".tl),
          trailing: Switch(
            value: appdata.settings[58] == "1",
            onChanged: (value){
              setState(() {
                appdata.settings[58] = value ? "1" : "0";
                appdata.writeData();
              });
              appdata.updateSettings();
              if(value){
                HttpProxyServer.reload();
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.rule),
          title: Text("规则".tl),
          trailing: const Icon(Icons.arrow_right),
          onTap: (){
            App.globalTo(() => const EditRuleView());
          },
        ),
        // ListTile(
        //   leading: const Icon(Icons.help),
        //   title: Text("帮助".tl),
        //   trailing: const Icon(Icons.arrow_right),
        //   onTap: (){
        //     launchUrlString(" `https://github.com/user/repo/blob/master/help.md` ");
        //   },
        // ),
        // 下载线程设置
        _DownloadThreadsSetting(),
        Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
      ],
    );
  }
}

class EditRuleView extends StatefulWidget {
  const EditRuleView({super.key});

  @override
  State<EditRuleView> createState() => _EditRuleViewState();
}

class _EditRuleViewState extends State<EditRuleView> {
  final file = File("${App.dataPath}/rule.json");

  late TextEditingController controller;

  @override
  void initState() {
    HttpProxyServer.createConfigFile();
    controller = TextEditingController(text: file.readAsStringSync());
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    file.writeAsStringSync(controller.text, mode: FileMode.writeOnly);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("rule.json"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, MediaQuery.of(context).padding.bottom),
          child: TextField(
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(
                border: InputBorder.none
            ),
            controller: controller,
          ),
        )
      )
    );
  }
}

// 新增代理设置视图
class _ProxySettingView extends StatefulWidget {
  const _ProxySettingView();

  @override
  State<_ProxySettingView> createState() => _ProxySettingViewState();
}

class _ProxySettingViewState extends State<_ProxySettingView> {
  String type = '';
  String host = '';
  String port = '';
  String username = '';
  String password = '';

  // USERNAME:PASSWORD@HOST:PORT
  String toProxyStr() {
    if (type == 'direct') {
      return 'direct';
    } else if (type == 'system') {
      return 'system';
    }
    var res = '';
    if (username.isNotEmpty) {
      res += username;
      if (password.isNotEmpty) {
        res += ':$password';
      }
      res += '@';
    }
    res += host;
    if (port.isNotEmpty) {
      res += ':$port';
    }
    return res;
  }

  void parseProxyString(String proxy) {
    if (proxy == 'direct') {
      type = 'direct';
      return;
    } else if (proxy == 'system') {
      type = 'system';
      return;
    }
    type = 'manual';
    var parts = proxy.split('@');
    if (parts.length == 2) {
      var auth = parts[0].split(':');
      if (auth.length == 2) {
        username = auth[0];
        password = auth[1];
      }
      parts = parts[1].split(':');
      if (parts.length == 2) {
        host = parts[0];
        port = parts[1];
      }
    } else {
      parts = proxy.split(':');
      if (parts.length == 2) {
        host = parts[0];
        port = parts[1];
      }
    }
  }

  @override
  void initState() {
    // 从appdata.settings[8]获取代理设置
    var proxy = appdata.settings[8];
    if (proxy == "0") {
      type = 'system';
    } else if (proxy.isEmpty) {
      type = 'direct';
    } else {
      parseProxyString(proxy);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("代理设置".tl),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text("Direct".tl),
              value: 'direct',
              groupValue: type,
              onChanged: (v) {
                setState(() {
                  type = v ?? type;
                });
                if (type != 'manual') {
                  appdata.settings[8] = type == 'direct' ? "" : "0";
                  appdata.writeData();
                  setNetworkProxy();
                }
              },
            ),
            RadioListTile<String>(
              title: Text("系统".tl),
              value: 'system',
              groupValue: type,
              onChanged: (v) {
                setState(() {
                  type = v ?? type;
                });
                if (type != 'manual') {
                  appdata.settings[8] = "0";
                  appdata.writeData();
                  setNetworkProxy();
                }
              },
            ),
            RadioListTile<String>(
              title: Text("Manual".tl),
              value: 'manual',
              groupValue: type,
              onChanged: (v) {
                setState(() {
                  type = v ?? type;
                });
              },
            ),
            if (type == 'manual') buildManualProxy(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("取消".tl),
        ),
      ],
    );
  }

  var formKey = GlobalKey<FormState>();

  Widget buildManualProxy() {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "主机".tl,
              ),
              controller: TextEditingController(text: host),
              onChanged: (v) {
                host = v;
              },
              validator: (v) {
                if (v?.isEmpty ?? false) {
                  return "主机不能为空".tl;
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "端口".tl,
              ),
              controller: TextEditingController(text: port),
              onChanged: (v) {
                port = v;
              },
              validator: (v) {
                if (v?.isEmpty ?? true) {
                  return null;
                }
                if (int.tryParse(v!) == null) {
                  return "端口必须是数字".tl;
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "用户名".tl,
              ),
              controller: TextEditingController(text: username),
              onChanged: (v) {
                username = v;
              },
              validator: (v) {
                if ((v?.isEmpty ?? false) && password.isNotEmpty) {
                  return "用户名不能为空".tl;
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "密码".tl,
              ),
              controller: TextEditingController(text: password),
              onChanged: (v) {
                password = v;
              },
              obscureText: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  appdata.settings[8] = toProxyStr();
                  appdata.writeData();
                  setNetworkProxy();
                  Navigator.of(context).pop();
                }
              },
              child: Text("保存".tl),
            ),
          ),
        ],
      ),
    );
  }
}



// 下载线程设置
class _DownloadThreadsSetting extends StatefulWidget {
  const _DownloadThreadsSetting();

  @override
  State<_DownloadThreadsSetting> createState() => __DownloadThreadsSettingState();
}

class __DownloadThreadsSettingState extends State<_DownloadThreadsSetting> {
  // 预定义的下载线程选项
  final List<String> threadOptions = ["1", "2", "4", "6", "8", "16"];
  int currentIndex = 2; // 默认为"4"，在数组中的索引是2

  @override
  void initState() {
    super.initState();
    // 从appdata.settings获取下载线程设置
    var savedValue = appdata.settings[79] ?? "4";
    // 找到当前值在选项列表中的索引
    currentIndex = threadOptions.indexOf(savedValue);
    if (currentIndex == -1) {
      // 如果保存的值不在选项中，使用默认值
      currentIndex = 2; // "4"
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.download_outlined),
      title: Text("下载线程".tl),
      subtitle: Slider(
        value: currentIndex.toDouble(),
        min: 0,
        max: (threadOptions.length - 1).toDouble(),
        divisions: threadOptions.length - 1,
        label: threadOptions[currentIndex],
        onChanged: (value) {
                setState(() {
                  currentIndex = value.round();
                  appdata.settings[79] = threadOptions[currentIndex];
                  appdata.updateSettings();
                });
              },
      ),
      trailing: Container(
        constraints: const BoxConstraints(minWidth: 30),
        child: Text(
          threadOptions[currentIndex],
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

