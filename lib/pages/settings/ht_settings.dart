part of pica_settings;

class HtSettings extends StatefulWidget {
  const HtSettings(this.popUp, {super.key});

  final bool popUp;

  @override
  State<HtSettings> createState() => _HtSettingsState();
}

class _HtSettingsState extends State<HtSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text("绅士漫画".tl),
        ),
        ListTile(
          leading: const Icon(Icons.compare_arrows),
          title: Text("点击更新API分流".tl),
          subtitle: Text(appdata.settings[31].replaceFirst("https://", "")),
          onTap: () => _chooseApiHost(context),
          trailing: const Icon(Icons.arrow_right),
        ),
      ],
    );
  }

  Future<List<String>> _getApiList() async {
    try {
      var res = await Dio().get<String>(
        "https://raw.githubusercontent.com/ccbkv/PicaComicapitxt/refs/heads/main/htmanga_api_list.txt",
        options: Options(responseType: ResponseType.plain)
      );
      if (res.data != null) {
        var list = res.data!.split("\n").where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
        if (list.isNotEmpty) {
          return list.map((e) {
            try {
              return utf8.decode(base64.decode(e));
            } catch (error) {
              return e;
            }
          }).toList();
        }
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  Future<void> _chooseApiHost(BuildContext context) async {
    var dialog = showLoadingDialog(context);
    var list = await _getApiList();
    dialog.close();
    
    if (!context.mounted) return;

    String? choose = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return ContentDialog(
          title: "API分流".tl,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...list.map(
                (e) => ListTile(
                  title: _HtApiOptionRow(
                    e,
                    key: Key("API:$e"),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(e);
                  },
                ),
              ),
              ListTile(
                title: Text("手动输入".tl),
                onTap: () async {
                  Navigator.of(context).pop(await _manualInputApiHost(context));
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: Text("取消".tl),
            ),
          ],
        );
      },
    );

    if (choose != null) {
      if (!choose.contains("https://")) {
        choose = "https://$choose";
      }
      if(!choose.isURL){
        showToast(message: "Invalid URL");
        return;
      }
      appdata.settings[31] = choose;
      appdata.updateSettings();
      setState(() {});
    }
  }

  Future<String?> _manualInputApiHost(BuildContext context) async {
    String? result;
    await showInputDialog(
      context: context,
      title: "手动输入API地址".tl,
      hintText: "www.example.com",
      initialValue: appdata.settings[31].replaceFirst("https://", ""),
      onConfirm: (value) {
        result = value;
        return null;
      },
    );
    return result;
  }
}

class _HtApiOptionRow extends StatefulWidget {
  final String value;
  const _HtApiOptionRow(this.value, {Key? key}) : super(key: key);
  @override
  State<_HtApiOptionRow> createState() => _HtApiOptionRowState();
}

class _HtApiOptionRowState extends State<_HtApiOptionRow> {
  late Future<int> _feature;
  
  @override
  void initState() {
    super.initState();
    _feature = _ping(widget.value);
  }
  
  Future<int> _ping(String url) async {
    try {
      var stopwatch = Stopwatch()..start();
      await Dio().head("https://$url", options: Options(validateStatus: (s) => true)).timeout(const Duration(seconds: 2));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return 9999;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(widget.value),
        Expanded(child: Container()),
        FutureBuilder(
          future: _feature,
          builder: (
            BuildContext context,
            AsyncSnapshot<int> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _PingStatus(
                "测速中".tl,
                Colors.blue,
              );
            }
            if (snapshot.hasError) {
              return _PingStatus(
                "失败".tl,
                Colors.red,
              );
            }
            int ping = snapshot.requireData;
            if (ping == 9999) {
               return _PingStatus(
                "失败".tl,
                Colors.red,
              );
            }
            if (ping <= 200) {
              return _PingStatus(
                "${ping}ms",
                Colors.green,
              );
            }
            if (ping <= 500) {
              return _PingStatus(
                "${ping}ms",
                Colors.yellow,
              );
            }
            return _PingStatus(
              "${ping}ms",
              Colors.orange,
            );
          },
        ),
      ],
    );
  }
}

class _PingStatus extends StatelessWidget {
  final String title;
  final Color color;

  const _PingStatus(this.title, this.color, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '\u2022',
          style: TextStyle(
            color: color,
          ),
        ),
        Text(" $title"),
      ],
    );
  }
}