import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/tools/translations.dart';

import '../../components/components.dart';
import '../../foundation/js_engine.dart';
import '../logs_page.dart';

part of 'settings_page.dart';


class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => DebugPageState();
}

class DebugPageState extends State<DebugPage> {
  final controller = TextEditingController();

  var result = "";

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 0), // 调整这个值来增加顶部高度
          _CallbackSetting(
            title: "重新加载配置文件".tl,
            actionTitle: "重载".tl,
            callback: () {
              ComicSource.reload();
            },
          ),
          _CallbackSetting(
            title: "打开日志".tl,
            callback: () {
              context.to(() => const LogsPage());
            },
            actionTitle: '打开'.tl,
          ),
          const SizedBox(height: 8),
          const Text(
            "JS Evaluator",
            style: TextStyle(fontSize: 16),
          ).toAlign(Alignment.centerLeft).paddingLeft(16),
          Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlign: TextAlign.start,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(8),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              try {
                var res = JsEngine().runCode(controller.text);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    result = res.toString();
                  });
                });
              } catch (e) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    result = e.toString();
                  });
                });
              }
            },
            child: const Text("Run"),
          ).toAlign(Alignment.centerRight).paddingRight(16),
          const Text(
            "Result",
            style: TextStyle(fontSize: 16),
          ).toAlign(Alignment.centerLeft).paddingLeft(16),
          Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: context.colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: Text(result).paddingAll(4),
            ),
          ),
        ],
      ),
    );
  }
}

// 在文件顶部或合适位置添加
class _CallbackSetting extends StatelessWidget {
  final String title;
  final String actionTitle;
  final VoidCallback callback;

  const _CallbackSetting({required this.title, required this.actionTitle, required this.callback});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: ElevatedButton(onPressed: callback, child: Text(actionTitle)),
    );
  }
}
