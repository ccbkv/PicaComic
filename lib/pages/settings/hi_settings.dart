part of pica_settings;

class HitomiSettings extends StatefulWidget {
  const HitomiSettings(this.popUp, {super.key});

  final bool popUp;

  @override
  State<HitomiSettings> createState() => _HitomiSettingsState();
}

class _HitomiSettingsState extends State<HitomiSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text("Hitomi".tl),
        ),
        ListTile(
          leading: const Icon(Icons.dns),
          title: Text("CDN ${"域名".tl}"),
          subtitle: Text(appdata.settings[87]),
          trailing: IconButton(onPressed: () => changeDomain(context), icon: const Icon(Icons.edit)),
        )
      ],
    );
  }

  void changeDomain(BuildContext context){
    showInputDialog(
      context: context,
      title: "更改域名".tl,
      labelText: "域名".tl,
      initialValue: appdata.settings[87],
      confirmText: "完成",
      onConfirm: (text) {
        if(!text.isURL){
          showToast(message: "Invalid Domain");
          return "Invalid Domain";
        }else {
          appdata.settings[87] = text;
          appdata.updateSettings();
          setState(() {});
        }
      },
    );
  }
}