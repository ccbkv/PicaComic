part of pica_settings;

class NhSettings extends StatefulWidget {
  const NhSettings(this.popUp, {super.key});

  final bool popUp;

  @override
  State<NhSettings> createState() => _NhSettingsState();
}

class _NhSettingsState extends State<NhSettings> {

  String baseUrl = "https://nhentai.net";

  void deleteAllCookie() async {
    final cookieJar = SingleInstanceCookieJar.instance!;
    var cookies = cookieJar.loadForRequest(Uri.parse(baseUrl));
    if (cookies.isEmpty) {
      showToast(message: "cookie 为空".tl);
      return;
    } else {
      var title = "${"确认删除".tl}?";
      var msg = "${"删除全部".tl}(${cookies.length}) nhentai cookie\n${"删除后需重新登录".tl}\n";
      showConfirmDialog(
        context: App.globalContext!,
        title: title,
        content: msg,
        onConfirm: () {
          NhentaiNetwork().logged = false;
          cookieJar.deleteUri(Uri.parse(baseUrl));
          var source = ComicSource.find('nhentai')!;
          source.data["account"] = null;
          source.saveData();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text("nhentai".tl),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: Text("${"删除".tl} cookie"),
          onTap: () => deleteAllCookie(),
          trailing: const Icon(Icons.arrow_right),
        )
      ],
    );
  }
}