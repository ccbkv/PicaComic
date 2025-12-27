import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/tools/font_manager.dart';
import 'package:pica_comic/tools/translations.dart';

class FontManagementPage extends StatefulWidget {
  const FontManagementPage({super.key});

  @override
  State<FontManagementPage> createState() => _FontManagementPageState();
}

class _FontManagementPageState extends State<FontManagementPage> {
  List<File> fonts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFonts();
  }

  Future<void> loadFonts() async {
    setState(() {
      loading = true;
    });
    var path = await FontManager().getFontsDir();
    if (path != null) {
      var dir = Directory(path);
      if (await dir.exists()) {
        var files = await dir.list().toList();
        fonts = files.whereType<File>().toList();
        // Sort by name
        fonts.sort((a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last));
      }
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("字体管理".tl),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : fonts.isEmpty
              ? Center(child: Text("无字体文件".tl))
              : ListView.builder(
                  itemCount: fonts.length,
                  itemBuilder: (context, index) {
                    var file = fonts[index];
                    var name = file.uri.pathSegments.last;
                    return ListTile(
                      leading: const Icon(Icons.font_download),
                      title: Text(name),
                      subtitle: Text(
                          "${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("确认删除".tl),
                            content: Text("要删除字体 $name 吗?".tl),
                            actions: [
                              TextButton(
                                onPressed: () => App.globalBack(),
                                child: Text("取消".tl),
                              ),
                              TextButton(
                                onPressed: () async {
                                  App.globalBack();
                                  await file.delete();
                                  await FontManager().scanFonts();
                                  loadFonts();
                                },
                                child: Text("删除".tl),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
