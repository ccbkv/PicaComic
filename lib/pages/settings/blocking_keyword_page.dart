part of pica_settings;

class BlockingKeywordPageLogic extends StateController {
  var keywords = appdata.blockingKeyword;
  var jmKeywords = appdata.jmBlockingKeyword;
  bool down = true;
  final controller = TextEditingController();
  int currentTab = 0;

  void changeTab(int index) {
    currentTab = index;
    update();
  }

  List<String> get currentKeywords => currentTab == 0 ? keywords : jmKeywords;

  void addKeyword() {
    final keyword = controller.text;
    if (keyword.isEmpty || currentKeywords.contains(keyword)) {
      controller.clear();
      return;
    }
    currentKeywords.add(keyword);
    controller.clear();
    update();
    if (currentTab == 0) {
      appdata.writeBlockingKeyword();
    } else {
      appdata.writeJmBlockingKeyword();
    }
  }

  void removeKeyword(String keyword) {
    currentKeywords.remove(keyword);
    update();
    if (currentTab == 0) {
      appdata.writeBlockingKeyword();
    } else {
      appdata.writeJmBlockingKeyword();
    }
  }

  void toggleOrder() {
    down = !down;
    update();
  }

  void dismissBanner() {
    appdata.firstUse[0] = "0";
    appdata.writeData();
    update();
  }
}

class BlockingKeywordPage extends StatefulWidget {
  const BlockingKeywordPage({this.popUp = false, Key? key}) : super(key: key);

  final bool popUp;

  @override
  State<BlockingKeywordPage> createState() => _BlockingKeywordPageState();
}

class _BlockingKeywordPageState extends State<BlockingKeywordPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final logic = StateController.put(BlockingKeywordPageLogic());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: logic.currentTab,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddKeywordDialog() {
    logic.controller.clear();
    final now = DateTime.now();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return TapRegion(
          onTapOutside: (_) {
            // Workaround for https://github.com/flutter/flutter/issues/177992
            if (DateTime.now().difference(now) < const Duration(milliseconds: 500)) {
              return;
            }
            if (Navigator.canPop(dialogContext)) {
              Navigator.pop(dialogContext);
            }
          },
          child: SimpleDialog(
            title: Text("添加屏蔽关键词".tl),
            children: [
              const SizedBox(width: 300),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: TextField(
                  controller: logic.controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: "添加关键词".tl,
                  ),
                  onEditingComplete: () {
                    logic.addKeyword();
                    App.globalBack();
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: FilledButton(
                  child: Text("提交".tl),
                  onPressed: () {
                    logic.addKeyword();
                    App.globalBack();
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StateBuilder<BlockingKeywordPageLogic>(
      builder: (logic) {
        if (_tabController.index != logic.currentTab) {
          _tabController.animateTo(logic.currentTab);
        }

        final addButton = Tooltip(
          message: "添加".tl,
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddKeywordDialog,
          ),
        );

        final orderButton = Tooltip(
          message: "显示顺序",
          child: IconButton(
            icon: logic.down
                ? const Icon(Icons.arrow_downward)
                : const Icon(Icons.arrow_upward),
            onPressed: logic.toggleOrder,
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text("关键词屏蔽".tl),
            actions: [addButton, orderButton],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: "通用".tl),
                Tab(text: "禁漫天堂".tl),
              ],
              onTap: logic.changeTab,
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKeywordList(logic, logic.keywords),
              _buildKeywordList(logic, logic.jmKeywords),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeywordList(
      BlockingKeywordPageLogic logic, List<String> keywords) {
    final showBanner =
        identical(keywords, logic.keywords) && appdata.firstUse[0] == "1";

    final keywordList = logic.down ? keywords : keywords.reversed.toList();

    return ListView(
      children: [
        if (showBanner)
          MaterialBanner(
            forceActionsBelow: true,
            padding: const EdgeInsets.all(15),
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
            content: Text("关键词屏蔽不会生效于收藏夹和历史记录, 屏蔽的依据仅限加载漫画列表时能够获取到的信息".tl),
            actions: [
              TextButton(
                onPressed: logic.dismissBanner,
                child: const Text("关闭"),
              )
            ],
          ),
        ...keywordList.map((keyword) => ListTile(
              title: Text(keyword),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => logic.removeKeyword(keyword),
              ),
            )),
      ],
    );
  }
}
