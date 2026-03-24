part of pica_settings;

class MultiPagesFilter extends StatefulWidget {
  const MultiPagesFilter(this.title, this.settingsIndex, this.pages,
      {super.key, this.onChange, this.helpContent});

  final String title;

  final int settingsIndex;

  // key - showName
  final Map<String, String> pages;

  final VoidCallback? onChange;

  final String? helpContent;

  @override
  State<MultiPagesFilter> createState() => _MultiPagesFilterState();
}

class _MultiPagesFilterState extends State<MultiPagesFilter> {
  late List<String> keys;

  @override
  void initState() {
    keys = appdata.settings[widget.settingsIndex].split(",");
    keys.remove("");
    super.initState();
  }

  var reorderWidgetKey = UniqueKey();
  var scrollController = ScrollController();
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var tiles = keys.map((e) => buildItem(e)).toList();

    var view = ReorderableBuilder(
      key: reorderWidgetKey,
      scrollController: scrollController,
      longPressDelay: App.isDesktop
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 500),
      dragChildBoxDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 2),
              spreadRadius: 2)
        ],
      ),
      onReorder: (reorderFunc) {
        setState(() {
          keys = List.from(reorderFunc(keys));
        });
        updateSetting();
      },
      children: tiles,
      builder: (children) {
        return GridView(
          key: _key,
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 48,
          ),
          children: children,
        );
      },
    );

    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        if (widget.helpContent != null)
          Tooltip(
            message: "帮助".tl,
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                final helpParts = widget.helpContent!.split('\n');
                final helpTitle = helpParts[0];
                final helpBody = helpParts.length > 1 ? helpParts[1] : '';
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(helpTitle),
                    content: Text(helpBody),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("确定".tl),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (keys.length < widget.pages.length)
          IconButton(onPressed: showAddDialog, icon: const Icon(Icons.add))
      ],
      body: view,
    );
  }

  Widget buildItem(String key) {
    Widget removeButton = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
          onPressed: () {
            setState(() {
              keys.remove(key);
            });
            updateSetting();
          },
          icon: const Icon(Icons.delete)),
    );

    if (App.isFluent) {
      return fluent.ListTile(
        title: Text(widget.pages[key] ?? "(Invalid) $key"),
        key: Key(key),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            removeButton,
            const Icon(Icons.drag_handle),
          ],
        ),
      );
    }

    return ListTile(
      title: Text(widget.pages[key] ?? "(Invalid) $key"),
      key: Key(key),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          removeButton,
          const Icon(Icons.drag_handle),
        ],
      ),
    );
  }

  void showAddDialog() {
    var canAdd = <String, String>{};
    widget.pages.forEach((key, value) {
      if (!keys.contains(key)) {
        canAdd[key] = value;
      }
    });
    var selected = <String>[];
    if (App.isFluent) {
      fluent.showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return fluent.ContentDialog(
                title: Text("Add".tl),
                content: SizedBox(
                  height: 300,
                  child: ListView(
                    children: canAdd.entries
                        .map((e) => fluent.Checkbox(
                              checked: selected.contains(e.key),
                              content: Text(e.value),
                              onChanged: (value) {
                                setState(() {
                                  if (value!) {
                                    selected.add(e.key);
                                  } else {
                                    selected.remove(e.key);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),
                ),
                actions: [
                  if (selected.length < canAdd.length)
                    fluent.Button(
                      child: Text("全选".tl),
                      onPressed: () {
                        setState(() {
                          selected = canAdd.keys.toList();
                        });
                      },
                    )
                  else
                    fluent.Button(
                      child: Text("取消全选".tl),
                      onPressed: () {
                        setState(() {
                          selected.clear();
                        });
                      },
                    ),
                  const SizedBox(width: 8),
                  fluent.FilledButton(
                    onPressed: selected.isNotEmpty
                        ? () {
                            this.setState(() {
                              keys.addAll(selected);
                            });
                            updateSetting();
                            App.back(context);
                          }
                        : null,
                    child: Text("Add".tl),
                  ),
                ],
              );
            },
          );
        },
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: "添加".tl,
              content: SizedBox(
                width: 300,
                height: 400,
                child: ListView(
                  children: canAdd.entries
                      .map((e) => CheckboxListTile(
                            value: selected.contains(e.key),
                            title: Text(e.value),
                            key: Key(e.key),
                            onChanged: (value) {
                              setState(() {
                                if (value!) {
                                  selected.add(e.key);
                                } else {
                                  selected.remove(e.key);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
              actions: [
                if (selected.length < canAdd.length)
                  Button.text(
                    onPressed: () {
                      setState(() {
                        selected = canAdd.keys.toList();
                      });
                    },
                    child: Text("全选".tl),
                  )
                else
                  Button.text(
                    onPressed: () {
                      setState(() {
                        selected.clear();
                      });
                    },
                    child: Text("取消全选".tl),
                  ),
                Button.filled(
                  onPressed: () {
                    this.setState(() {
                      keys.addAll(selected);
                    });
                    updateSetting();
                    Navigator.pop(context);
                  },
                  disabled: selected.isEmpty,
                  child: Text("添加".tl),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void updateSetting() {
    appdata.settings[widget.settingsIndex] = keys.join(",");
    appdata.updateSettings();
    widget.onChange?.call();
  }
}
