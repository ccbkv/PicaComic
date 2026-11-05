import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/eh_network/eh_main_network.dart';
import 'package:pica_comic/utils/translations.dart';

class CookieManagementView extends StatefulWidget {
  const CookieManagementView({super.key});

  @override
  State<CookieManagementView> createState() => _CookieManagementViewState();
}

class _CookieManagementViewState extends State<CookieManagementView> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text("cookies"),
      shape: const RoundedRectangleBorder(),
      children: _cookieTiles(context, () => setState(() {})),
    );
  }
}

/// A standalone page version of [CookieManagementView], opened from the
/// account page of the ehentai JS source via the "ehentai_cookie_management"
/// info item action.
class CookieManagementPage extends StatefulWidget {
  const CookieManagementPage({super.key});

  @override
  State<CookieManagementPage> createState() => _CookieManagementPageState();
}

class _CookieManagementPageState extends State<CookieManagementPage> {
  @override
  void initState() {
    super.initState();
    // Refresh in-memory cookie values from the shared cookie jar, so the
    // page shows current values even before any network request.
    EhNetwork().getCookies(true).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("cookies"),
      ),
      body: ListView(
        children: _cookieTiles(context, () => setState(() {})),
      ),
    );
  }
}

List<Widget> _cookieTiles(BuildContext context, VoidCallback refresh) => [
      ListTile(
        title: const Text("ipb_member_id"),
        subtitle: Text(EhNetwork().id),
        onTap: () => _setClipboard(EhNetwork().id),
      ),
      ListTile(
        title: const Text("ipb_pass_hash"),
        subtitle: Text(EhNetwork().hash),
        onTap: () => _setClipboard(EhNetwork().hash),
      ),
      ListTile(
        title: const Text("igneous"),
        subtitle: Text(EhNetwork().igneous),
        onTap: () => _setClipboard(EhNetwork().igneous),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _showIgnEditDialog(context, refresh),
        ),
      ),
    ];

void _showIgnEditDialog(BuildContext context, VoidCallback refresh) {
  showDialog(
    context: context,
    builder: (context) {
      String text = EhNetwork().igneous;
      return ContentDialog(
        title: "igneous",
        content: TextField(
          controller: TextEditingController(text: text),
          onChanged: (s) => text = s,
        ).paddingHorizontal(16),
        actions: [
          Button.filled(
            onPressed: () async {
              EhNetwork().igneous = text;
              await EhNetwork().cookieJar.saveFromResponse(
                Uri.parse("https://exhentai.org"),
                [Cookie("igneous", text)],
              );
              await EhNetwork().cookieJar.saveFromResponse(
                Uri.parse("https://e-hentai.org"),
                [Cookie("igneous", text)],
              );
              if (context.mounted) context.pop();
              refresh();
            },
            child: Text("确定".tl),
          ),
        ],
      );
    },
  );
}

void _setClipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
  showToast(message: "已复制".tl, icon: const Icon(Icons.check));
}
