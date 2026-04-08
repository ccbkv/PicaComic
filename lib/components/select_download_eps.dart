import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/utils/translations.dart';

class SelectDownloadChapter extends StatefulWidget {
  const SelectDownloadChapter(this.eps, this.finishSelect, this.downloadedEps,
      {this.chapters, Key? key})
      : super(key: key);
  final List<String> eps;
  final void Function(List<int>) finishSelect;
  final List<int> downloadedEps;
  final ComicChapters? chapters;

  @override
  State<SelectDownloadChapter> createState() => _SelectDownloadChapterState();
}

class _SelectDownloadChapterState extends State<SelectDownloadChapter>
    with SingleTickerProviderStateMixin {
  List<int> selected = [];
  int _selectedGroupIndex = 0;
  TabController? _tabController;

  bool get _isGrouped =>
      widget.chapters != null && widget.chapters!.isGrouped;

  @override
  void initState() {
    super.initState();
    if (_isGrouped) {
      _tabController = TabController(
        length: widget.chapters!.groupCount,
        initialIndex: 0,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("下载漫画".tl),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isGrouped) ...[
            SizedBox(
              height: 40,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                labelStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                onTap: (index) {
                  if (index != _selectedGroupIndex) {
                    setState(() {
                      _selectedGroupIndex = index;
                      selected.clear();
                    });
                  }
                },
                tabs: widget.chapters!.groups
                    .map((g) => Tab(text: g))
                    .toList(),
              ),
            ),
          ],
          Expanded(
            child: Builder(builder: (context) {
              List<String> displayEps;
              int Function(int) epOffset;
              if (_isGrouped) {
                var group =
                    widget.chapters!.getGroupByIndex(_selectedGroupIndex);
                displayEps = group.values.toList();
                int offset = 0;
                for (int j = 0; j < _selectedGroupIndex; j++) {
                  offset += widget.chapters!.getGroupByIndex(j).length;
                }
                epOffset = (i) => offset + i;
              } else {
                displayEps = widget.eps;
                epOffset = (i) => i;
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: displayEps.length,
                itemBuilder: (context, i) {
                  var globalIndex = epOffset(i);
                  return CheckboxListTile(
                    title: Text(displayEps[i]),
                    value: selected.contains(globalIndex) ||
                        widget.downloadedEps.contains(globalIndex),
                    onChanged: widget.downloadedEps.contains(globalIndex)
                        ? null
                        : (v) {
                            setState(() {
                              if (selected.contains(globalIndex)) {
                                selected.remove(globalIndex);
                              } else {
                                selected.add(globalIndex);
                              }
                            });
                          },
                  );
                },
              );
            }),
          ),
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      var res = <int>[];
                      for (int i = 0; i < widget.eps.length; i++) {
                        if (!widget.downloadedEps.contains(i)) {
                          res.add(i);
                        }
                      }
                      widget.finishSelect(res);
                    },
                    child: Text("下载全部".tl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () {
                            widget.finishSelect(selected);
                          },
                    child: Text("下载选中".tl),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
