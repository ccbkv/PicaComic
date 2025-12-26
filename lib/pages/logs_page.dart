import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/tools/io_tools.dart';
import 'package:pica_comic/tools/translations.dart';
import 'package:pica_comic/components/components.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String logLevelToShow = "all";


  @override
  Widget build(BuildContext context) {
       var logToShow = logLevelToShow == "all"
        ? LogManager.logs
        : LogManager.logs.where((log) => log.level.name == logLevelToShow).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logs"),
        actions: [
             IconButton(
              onPressed: () => setState(() {
                    final RelativeRect position = RelativeRect.fromLTRB(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).padding.top + kToolbarHeight,
                      0.0,
                      0.0,
                    );
                    showMenu(context: context, position: position, items: [
                      PopupMenuItem(
                          child: Text("all"),
                          onTap: () => setState(() => logLevelToShow = "all")
                      ),
                      PopupMenuItem(
                          child: Text("info"),
                          onTap: () => setState(() => logLevelToShow = "info")
                      ),
                      PopupMenuItem(
                          child: Text("warning"),
                          onTap: () => setState(() => logLevelToShow = "warning")
                      ),
                      PopupMenuItem(
                          child: Text("error"),
                          onTap: () => setState(() => logLevelToShow = "error")
                      ),
                    ]);
              }),
              icon: const Icon(Icons.filter_list_outlined)
          ),       
          IconButton(onPressed: ()=>setState(() {
            final RelativeRect position = RelativeRect.fromLTRB(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).padding.top + kToolbarHeight,
              0.0,
              0.0,
            );
            showMenu(context: context, position: position, items: [
              PopupMenuItem(
                child: Text("清空".tl),
                onTap: () => setState(()=>LogManager.clear()),
              ),
              PopupMenuItem(
                child: Text("禁用长度限制".tl),
                onTap: (){
                  LogManager.ignoreLimitation = true;
                  showToast(message: "仅在本次运行时有效".tl);
                },
              ),
              PopupMenuItem(
                child: Text("导出".tl),
                onTap: () => saveLog(LogManager().toString()),
              ),
            ]);
          }), icon: const Icon(Icons.more_horiz))
        ],
      ),
      body: ListView.builder(
        reverse: true,
        controller: ScrollController(),
        itemCount: logToShow.length,
        itemBuilder: (context, index){
          var log = logToShow[logToShow.length - index - 1];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 0, 5, 1),
                          child: Text(log.title),
                        ),
                      ),
                      const SizedBox(width: 3,),
                      Container(
                        decoration: BoxDecoration(
                          color: [
                            Theme.of(context).colorScheme.error,
                            Theme.of(context).colorScheme.errorContainer,
                            Theme.of(context).colorScheme.primaryContainer
                          ][log.level.index],
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 0, 5, 1),
                          child: Text(
                            log.level.name,
                            style: TextStyle(color: log.level.index==0?Colors.white:Colors.black),),
                        ),
                      ),
                    ],
                  ),
                  Text(log.content),
                  Text(log.time.toString().replaceAll(RegExp(r"\.\w+"), "")),
                  TextButton(onPressed: (){
                    Clipboard.setData(ClipboardData(text: log.content));
                  }, child: Text("复制".tl)),
                  const Divider(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
