import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/components/components.dart'
    show Button, ContentDialog, showSideBar, showToast;
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/def.dart';
import 'package:pica_comic/foundation/history.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/network/res.dart';
import 'package:pica_comic/pages/reader/comic_reading_page.dart';
import 'package:pica_comic/utils/io.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class LocalAddComicPage extends StatefulWidget {
  const LocalAddComicPage({super.key});

  @override
  State<LocalAddComicPage> createState() => _LocalAddComicPageState();
}

class _LocalAddComicPageState extends State<LocalAddComicPage> {
  static const _desktopBreakpoint = 980.0;
  static const _pageSize = 20;
  static const _directoryChannel = MethodChannel("ezvenera/directory");

  final _controller = LocalLibraryController.instance;
  final ScrollController _contentScrollController = ScrollController();
  late String _selectedShelfKey;
  bool _sidebarCollapsed = false;
  bool _showList = false;
  String _searchKeyword = "";
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _selectedShelfKey = _restoreShelfKey();
    _sidebarCollapsed = _restoreSidebarCollapsed();
    _showList = _restoreShowList();
    _controller.addListener(_onChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureSelectionIsValid();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        final sidebar = _LocalSidebar(
          selectedShelfKey: _selectedShelfKey,
          sidebarCollapsed: isDesktop ? _sidebarCollapsed : false,
          folders: _controller.folders,
          folderCounts: {
            for (final folder in _controller.folders)
              folder.id: _controller.comicsFor(folder.id).length,
          },
          loadingFolderIds: {
            for (final folder in _controller.folders)
              if (_controller.isLoading(folder.id)) folder.id,
          },
          onSelectShelf: _selectShelf,
          onAddFolder: _addFolder,
          onRemoveFolder: _removeFolderEntry,
          onRefreshFolder: _refreshFolderEntry,
          onToggleCollapse: isDesktop ? _toggleSidebar : null,
        );

        final content = _buildContent(context, isDesktop: isDesktop);

        if (isDesktop) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: _sidebarCollapsed ? 88 : 292,
                    child: sidebar,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildMobileToolbar(context),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _selectedMetadata();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_sharp),
            tooltip: "返回".tl,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metadata.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _openFolderSheet,
            icon: const Icon(Icons.menu_open),
            tooltip: "文件夹".tl,
          ),
          const Spacer(),
          ..._buildHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isDesktop}) {
    final metadata = _selectedMetadata();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          if (isDesktop) _buildDesktopHeader(context, metadata),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: SingleChildScrollView(
                controller: _contentScrollController,
                key: ValueKey<String>(_selectedShelfKey),
                padding: const EdgeInsets.all(24),
                child: _buildSelectedSection(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, _SelectedMetadata metadata) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_sharp),
            tooltip: "返回".tl,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metadata.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ..._buildHeaderActions(),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    final folder = _selectedFolder;
    return [
      IconButton(
        onPressed: _openSearchDialog,
        icon: const Icon(Icons.search),
        tooltip: _searchKeyword.trim().isEmpty
            ? "搜索".tl
            : "${"搜索".tl}: $_searchKeyword",
      ),
      IconButton(
        onPressed: _toggleDisplayMode,
        icon: Icon(
          _showList ? Icons.grid_view_outlined : Icons.view_list_outlined,
        ),
        tooltip: _showList ? "切换为网格视图".tl : "切换为列表视图".tl,
      ),
      if (folder != null) ...[
        IconButton(
          onPressed: () => _openFolder(folder),
          icon: const Icon(Icons.folder_open_outlined),
          tooltip: "打开文件夹".tl,
        ),
      ],
      IconButton(
        onPressed: _addFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        tooltip: "选择文件夹".tl,
      ),
    ];
  }

  Widget _buildSelectedSection(BuildContext context) {
    final folder = _selectedFolder;
    if (folder == null) {
      return _LocalPlaceholder(
        title: "还没有漫画文件夹".tl,
        body: "添加一个包含漫画目录或图片文件的文件夹。".tl,
      );
    }
    return _buildLocalFolder(context, folder);
  }

  Widget _buildLocalFolder(BuildContext context, LocalComicFolderEntry folder) {
    final error = _controller.errorFor(folder.id);
    final loading = _controller.isLoading(folder.id);
    final comics = _controller.comicsFor(folder.id);
    final filteredComics = _filterComics(comics);
    final maxPage = _maxPageForCount(filteredComics.length);
    final currentPage = _clampPage(_currentPage, maxPage);
    final visibleComics = _paginateComics(filteredComics, currentPage);

    if (loading && comics.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && comics.isEmpty) {
      return _LocalPlaceholder(
        title: "文件夹不可用".tl,
        body: "$error\n\n${"所选目录已不存在，或当前无法读取。".tl}",
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
        if (filteredComics.isEmpty)
          _LocalPlaceholder(
            title: _searchKeyword.trim().isEmpty ? "未找到漫画".tl : "未找到结果".tl,
            body: _searchKeyword.trim().isEmpty
                ? "每部漫画应为一个目录，目录内包含图片或章节子目录。".tl
                : "${"没有找到匹配的本地漫画".tl}\n$_searchKeyword",
          )
        else ...[
          Transform.translate(
            offset: const Offset(0, -8),
            child: _buildPaginationSection(
              context,
              currentPage: currentPage,
              maxPage: maxPage,
            ),
          ),
          _LocalComicGrid<LocalLibraryComic>(
            items: visibleComics,
            showList: _showList,
            itemBuilder: (context, comic) {
              return _LocalComicCard(
                showList: _showList,
                title: comic.title,
                subtitle: _basename(comic.path),
                meta: _localChaptersPages(
                    comic.chapters.length, comic.totalPages),
                accent: "本地".tl,
                coverPath: comic.coverPath,
                onTap: () => _showComicActions(context, comic),
                topRight: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == "open") {
                      _showComicActions(context, comic);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: "open",
                      child: Text("阅读".tl),
                    ),
                  ],
                ),
              );
            },
          ),
          Transform.translate(
            offset: const Offset(0, 8),
            child: _buildPaginationSection(
              context,
              currentPage: currentPage,
              maxPage: maxPage,
            ),
          ),
        ],
      ],
    );
  }

  void _onChanged() {
    _ensureSelectionIsValid();
    if (mounted) {
      setState(() {});
    }
  }

  void _selectShelf(String shelfKey) {
    if (_selectedShelfKey == shelfKey) {
      return;
    }
    setState(() {
      _selectedShelfKey = shelfKey;
      _currentPage = 1;
    });
    _persistString("local_add_comic.selectedShelf", shelfKey);
  }

  String _restoreShelfKey() {
    return _readString("local_add_comic.selectedShelf") ?? "";
  }

  bool _restoreSidebarCollapsed() {
    return _readString("local_add_comic.sidebarCollapsed") == "1";
  }

  bool _restoreShowList() {
    return _readString("local_add_comic.showList") == "1";
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
    _persistString(
      "local_add_comic.sidebarCollapsed",
      _sidebarCollapsed ? "1" : "0",
    );
  }

  void _toggleDisplayMode() {
    setState(() {
      _showList = !_showList;
      _currentPage = 1;
    });
    _persistString("local_add_comic.showList", _showList ? "1" : "0");
  }

  List<LocalLibraryComic> _filterComics(List<LocalLibraryComic> comics) {
    final keyword = _searchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return comics;
    }
    return comics
        .where((comic) => _matchesComicSearch(comic, keyword))
        .toList();
  }

  bool _matchesComicSearch(LocalLibraryComic comic, String keyword) {
    if (comic.title.toLowerCase().contains(keyword)) {
      return true;
    }
    if (_basename(comic.path).toLowerCase().contains(keyword)) {
      return true;
    }
    if (comic.path.toLowerCase().contains(keyword)) {
      return true;
    }
    return comic.chapters.any(
      (chapter) =>
          chapter.title.toLowerCase().contains(keyword) ||
          chapter.path.toLowerCase().contains(keyword),
    );
  }

  int _maxPageForCount(int count) {
    if (count <= 0) {
      return 1;
    }
    return ((count - 1) ~/ _pageSize) + 1;
  }

  int _clampPage(int page, int maxPage) {
    if (page < 1) {
      return 1;
    }
    if (page > maxPage) {
      return maxPage;
    }
    return page;
  }

  List<LocalLibraryComic> _paginateComics(
    List<LocalLibraryComic> comics,
    int currentPage,
  ) {
    final startIndex = (currentPage - 1) * _pageSize;
    if (startIndex >= comics.length) {
      return const <LocalLibraryComic>[];
    }
    final endIndex = startIndex + _pageSize;
    return comics.sublist(
      startIndex,
      endIndex > comics.length ? comics.length : endIndex,
    );
  }

  Future<void> _scrollToTop() async {
    if (!_contentScrollController.hasClients) {
      return;
    }
    await _contentScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _updateSearchKeyword(String keyword) {
    setState(() {
      _searchKeyword = keyword.trim();
      _currentPage = 1;
    });
    _scrollToTop();
  }

  void _changePage(int page, int maxPage) {
    final nextPage = _clampPage(page, maxPage);
    if (nextPage == _currentPage) {
      return;
    }
    setState(() {
      _currentPage = nextPage;
    });
    _scrollToTop();
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchKeyword);
    final keyword = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("搜索".tl),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: "关键词".tl,
              hintText: "输入标题或目录名".tl,
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("取消".tl),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ""),
              child: Text("清除".tl),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text("确认".tl),
            ),
          ],
        );
      },
    );
    if (keyword == null) {
      return;
    }
    _updateSearchKeyword(keyword);
  }

  Widget _buildPaginationSection(
    BuildContext context, {
    required int currentPage,
    required int maxPage,
  }) {
    return Row(
      children: [
        FilledButton(
          onPressed: currentPage > 1
              ? () => _changePage(currentPage - 1, maxPage)
              : null,
          child: Text("后退".tl),
        ).fixWidth(84),
        Expanded(
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final page = await showDialog<int>(
                    context: context,
                    builder: (context) {
                      final controller = TextEditingController(
                        text: currentPage.toString(),
                      );
                      return ContentDialog(
                        title: "输入页码".tl,
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "页码".tl,
                            hintText: "1-$maxPage",
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ).paddingHorizontal(16),
                        actions: [
                          Button.filled(
                            onPressed: () {
                              final p = int.tryParse(controller.text);
                              if (p != null && p >= 1 && p <= maxPage) {
                                Navigator.pop(context, p);
                              } else {
                                showToast(message: "页码无效".tl);
                              }
                            },
                            child: Text("确认".tl),
                          ),
                        ],
                      );
                    },
                  );
                  if (page != null) {
                    _changePage(page, maxPage);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text("${"页面".tl} $currentPage / $maxPage"),
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: currentPage < maxPage
              ? () => _changePage(currentPage + 1, maxPage)
              : null,
          child: Text("前进".tl),
        ).fixWidth(84),
      ],
    ).paddingVertical(8).paddingHorizontal(16);
  }

  void _ensureSelectionIsValid() {
    if (_selectedShelfKey.startsWith("folder:")) {
      final folderId = _selectedShelfKey.substring("folder:".length);
      if (_controller.folderById(folderId) != null) {
        return;
      }
    }
    final firstFolder =
        _controller.folders.isEmpty ? null : _controller.folders.first;
    _selectedShelfKey = firstFolder == null ? "" : "folder:${firstFolder.id}";
  }

  _SelectedMetadata _selectedMetadata() {
    final folder = _selectedFolder;
    return _SelectedMetadata(
      title: folder?.name ?? "漫画库".tl,
      subtitle: folder == null
          ? "还没有漫画文件夹".tl
          : _controller.errorFor(folder.id) != null
              ? "文件夹不可用".tl
              : _localComicsCount(_controller.comicsFor(folder.id).length),
    );
  }

  LocalComicFolderEntry? get _selectedFolder {
    if (!_selectedShelfKey.startsWith("folder:")) {
      return null;
    }
    return _controller
        .folderById(_selectedShelfKey.substring("folder:".length));
  }

  Future<void> _addFolder() async {
    try {
      final copyToLocal = await _showAddFolderDialog();
      if (copyToLocal == null) {
        return;
      }
      final selected = await _pickDirectoryPath();
      if (selected == null || selected.trim().isEmpty) {
        return;
      }
      final target = copyToLocal
          ? await _copyToLocalAddComicFolder(selected)
          : selected;
      if (target == null) {
        return;
      }
      final folder = await _controller.addFolder(target);
      if (!mounted) {
        return;
      }
      _selectShelf("folder:${folder.id}");
      _showMessage("已添加文件夹".tl);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage("无法打开文件夹选择器".tl);
    }
  }

  Future<bool?> _showAddFolderDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        // iOS 安全作用域授权不持久，重启后会失去对所选目录的访问权限，因此强制复制到本地存储目录
        final forceCopyToLocal = App.isIOS;
        var copyToLocal = forceCopyToLocal;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("添加文件夹".tl),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: copyToLocal,
                    onChanged: forceCopyToLocal
                        ? null
                        : (v) => setState(() => copyToLocal = v ?? false),
                    title: Text("将漫画复制到本地存储目录中".tl),
                  ),
                  if (forceCopyToLocal)
                    Text(
                      "因 iOS 系统限制，无法直接引用所选文件夹，漫画将被复制到本地存储目录中。"
                          .tl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("取消".tl),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, copyToLocal),
                  child: Text("确认".tl),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _copyToLocalAddComicFolder(String sourcePath) async {
    final targetRoot =
        "${App.dataPath}${Platform.pathSeparator}local_add_comic";
    final rootDir = Directory(targetRoot);
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final safeName = findValidDirectoryName(targetRoot, _basename(sourcePath));
    final destPath = FilePath.join(targetRoot, safeName);
    final destDir = Directory(destPath);
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    await copyDirectoryIsolate(Directory(sourcePath), destDir);
    return destPath;
  }

  Future<String?> _pickDirectoryPath() async {
    if (App.isAndroid) {
      final canUseExternalStorage =
          await _directoryChannel.invokeMethod<bool>("ensureStorageAccess") ??
          false;
      if (!canUseExternalStorage) {
        throw PlatformException(
          code: "storage_permission_required",
          message:
              "Storage permission is required before choosing a shared folder.",
        );
      }
      final path = await _directoryChannel.invokeMethod<String>(
        "pickDirectory",
      );
      if (path == null || path.trim().isEmpty) {
        return null;
      }
      return path;
    }
    if (App.isIOS) {
      // file_selector 在 iOS 上未实现目录选择，改用原生 UIDocumentPicker 通道
      const channel = MethodChannel("venera/method_channel");
      final path = await channel.invokeMethod<String?>("getDirectoryPath");
      if (path == null || path.trim().isEmpty) {
        return null;
      }
      return path;
    }
    return getDirectoryPath();
  }

  Future<void> _refreshFolderEntry(LocalComicFolderEntry folder) async {
    await _controller.refreshFolder(folder.id);
  }

  Future<void> _openFolder(LocalComicFolderEntry folder) async {
    try {
      if (App.isWindows) {
        await Process.start("explorer.exe", [folder.path], runInShell: true);
      } else if (App.isMacOS) {
        await Process.start("open", [folder.path]);
      } else if (App.isLinux) {
        await Process.start("xdg-open", [folder.path]);
          } else if (App.isAndroid) {
            final opened =
                await _directoryChannel.invokeMethod<bool>(
                  "openDirectory",
                  folder.path,
                ) ??
                false;
            if (!opened) {
              throw Exception("failed_to_open_directory");
            }
      } else {
        throw Exception("unsupported");
      }
    } catch (_) {
      if (mounted) {
        _showMessage("无法打开该文件夹。".tl);
      }
    }
  }

  Future<void> _removeFolderEntry(LocalComicFolderEntry folder) async {
    final isManagedCopy = _controller.isManagedCopyPath(folder.path);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("移除文件夹".tl),
          content: Text(
            isManagedCopy
                ? '要移除“${folder.name}”吗？该文件夹是复制到本地存储目录中的副本，移除后将同时删除这些文件。'
                    .tl
                : '要从本地页面移除“${folder.name}”吗？不会删除磁盘上的文件。'.tl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("取消".tl),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("删除".tl),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _controller.removeFolder(folder.id);
    if (isManagedCopy) {
      // 删除复制到本地存储目录中的副本，避免残留孤儿文件
      await Directory(folder.path).deleteIgnoreError(recursive: true);
    }
    if (_selectedShelfKey == "folder:${folder.id}") {
      _ensureSelectionIsValid();
    }
    if (mounted) {
      _showMessage(
        isManagedCopy ? "已移除文件夹并删除本地副本".tl : "已移除文件夹".tl,
      );
    }
  }

  void _openFolderSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: _LocalSidebar(
              selectedShelfKey: _selectedShelfKey,
              sidebarCollapsed: false,
              folders: _controller.folders,
              folderCounts: {
                for (final folder in _controller.folders)
                  folder.id: _controller.comicsFor(folder.id).length,
              },
              loadingFolderIds: {
                for (final folder in _controller.folders)
                  if (_controller.isLoading(folder.id)) folder.id,
              },
              onSelectShelf: (value) {
                Navigator.of(context).pop();
                _selectShelf(value);
              },
              onAddFolder: () async {
                Navigator.of(context).pop();
                await _addFolder();
              },
              onRemoveFolder: (folder) async {
                Navigator.of(context).pop();
                await _removeFolderEntry(folder);
              },
              onRefreshFolder: (folder) async {
                Navigator.of(context).pop();
                await _refreshFolderEntry(folder);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showComicActions(
    BuildContext context,
    LocalLibraryComic comic,
  ) async {
    if (UiMode.m1(context)) {
      await showModalBottomSheet(
        context: context,
        builder: (context) => LocalComicInfoView(comic),
      );
    } else {
      showSideBar(App.globalContext!, LocalComicInfoView(comic));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _LocalSidebar extends StatelessWidget {
  const _LocalSidebar({
    required this.selectedShelfKey,
    required this.sidebarCollapsed,
    required this.folders,
    required this.folderCounts,
    required this.loadingFolderIds,
    required this.onSelectShelf,
    required this.onAddFolder,
    required this.onRemoveFolder,
    required this.onRefreshFolder,
    this.onToggleCollapse,
  });

  final String selectedShelfKey;
  final bool sidebarCollapsed;
  final List<LocalComicFolderEntry> folders;
  final Map<String, int> folderCounts;
  final Set<String> loadingFolderIds;
  final ValueChanged<String> onSelectShelf;
  final Future<void> Function() onAddFolder;
  final Future<void> Function(LocalComicFolderEntry folder) onRemoveFolder;
  final Future<void> Function(LocalComicFolderEntry folder) onRefreshFolder;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  color: theme.colorScheme.primary,
                ),
                if (!sidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "漫画库".tl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (onToggleCollapse != null)
                  IconButton(
                    onPressed: onToggleCollapse,
                    icon: Icon(
                      sidebarCollapsed
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                    ),
                    tooltip: sidebarCollapsed ? "展开侧栏".tl : "收起侧栏".tl,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              children: [
                _SidebarFolderHeader(
                  title: "漫画文件夹".tl,
                  collapsed: sidebarCollapsed,
                  onAdd: onAddFolder,
                ),
                const SizedBox(height: 10),
                if (folders.isEmpty)
                  _SidebarEmptyHint(
                    title: "还没有漫画文件夹".tl,
                    body: "添加一个包含漫画目录或图片文件的文件夹。".tl,
                    collapsed: sidebarCollapsed,
                  )
                else
                  for (final folder in folders) ...[
                    _SidebarItem(
                      label: folder.name,
                      icon: Icons.folder_outlined,
                      selected: selectedShelfKey == "folder:${folder.id}",
                      count: folderCounts[folder.id] ?? 0,
                      collapsed: sidebarCollapsed,
                      trailing: sidebarCollapsed
                          ? null
                          : PopupMenuButton<String>(
                              icon: loadingFolderIds.contains(folder.id)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.more_horiz),
                              onSelected: (value) async {
                                if (value == "refresh") {
                                  await onRefreshFolder(folder);
                                } else if (value == "delete") {
                                  await onRemoveFolder(folder);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: "refresh",
                                  child: Text("刷新文件夹".tl),
                                ),
                                PopupMenuItem<String>(
                                  value: "delete",
                                  child: Text("删除".tl),
                                ),
                              ],
                            ),
                      onTap: () => onSelectShelf("folder:${folder.id}"),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarFolderHeader extends StatelessWidget {
  const _SidebarFolderHeader({
    required this.title,
    required this.collapsed,
    required this.onAdd,
  });

  final String title;
  final bool collapsed;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        if (!collapsed)
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          const Spacer(),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.create_new_folder_outlined),
          tooltip: "添加文件夹".tl,
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.collapsed,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                trailing ??
                    _SidebarCountBadge(count: count, selected: selected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarCountBadge extends StatelessWidget {
  const _SidebarCountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "$count",
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SidebarEmptyHint extends StatelessWidget {
  const _SidebarEmptyHint({
    required this.title,
    required this.body,
    required this.collapsed,
  });

  final String title;
  final String body;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMetadata {
  const _SelectedMetadata({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _LocalPlaceholder extends StatelessWidget {
  const _LocalPlaceholder({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalComicGrid<T> extends StatelessWidget {
  const _LocalComicGrid({
    required this.items,
    required this.itemBuilder,
    required this.showList,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final bool showList;

  @override
  Widget build(BuildContext context) {
    if (showList) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => itemBuilder(context, items[index]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumnCount(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns >= 5 ? 0.72 : 0.68,
          ),
          itemBuilder: (context, index) => itemBuilder(context, items[index]),
        );
      },
    );
  }
}

class _LocalComicCard extends StatelessWidget {
  const _LocalComicCard({
    required this.showList,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.accent,
    required this.onTap,
    this.coverPath,
    this.topRight,
  });

  final bool showList;
  final String title;
  final String subtitle;
  final String meta;
  final String accent;
  final String? coverPath;
  final VoidCallback onTap;
  final Widget? topRight;

  @override
  Widget build(BuildContext context) {
    if (showList) {
      return _buildListCard(context);
    }
    return _buildGridCard(context);
  }

  Widget _buildListCard(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _LocalComicCover(coverPath: coverPath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.replaceAll("\n", " "),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle.trim().isNotEmpty ? subtitle : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          accent,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (topRight != null) topRight!,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: _LocalComicCover(coverPath: coverPath),
                      ),
                    ),
                    if (topRight != null)
                      Positioned(top: 8, right: 8, child: topRight!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.replaceAll("\n", " "),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.trim().isNotEmpty ? subtitle : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalComicCover extends StatelessWidget {
  const _LocalComicCover({this.coverPath});

  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final path = coverPath?.trim();
    Widget child;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      child = Image.file(File(path), fit: BoxFit.cover);
    } else {
      child = const _LocalCoverFallback();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox.expand(child: child),
    );
  }
}

class _LocalCoverFallback extends StatelessWidget {
  const _LocalCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

Future<void> openLocalComicReader(
  LocalLibraryComic comic, {
  int ep = 1,
  int page = 0,
}) async {
  await History.findOrCreate(LocalComicHistoryEntry(comic));
  App.globalTo(
    () => ComicReadingPage(
      LocalFolderReadingData(comic),
      page,
      ep,
    ),
  );
}

bool isLocalHistoryEntry(History history) {
  return history.type.value == "local-folder".hashCode;
}

Future<void> openLocalHistory(History history) async {
  final comic = await LocalLibraryController.instance.loadComicByPath(
    history.target,
  );
  if (comic == null) {
    if (App.globalContext != null) {
      ScaffoldMessenger.of(App.globalContext!).showSnackBar(
        SnackBar(content: Text("本地漫画不存在或无法读取".tl)),
      );
    }
    return;
  }
  await openLocalComicReader(
    comic,
    ep: history.ep <= 0 ? 1 : history.ep,
    page: history.page,
  );
}

class LocalComicInfoView extends StatefulWidget {
  const LocalComicInfoView(this.comic, {super.key});

  final LocalLibraryComic comic;

  @override
  State<LocalComicInfoView> createState() => _LocalComicInfoViewState();
}

class _LocalComicInfoViewState extends State<LocalComicInfoView> {
  int selectedChapter = 0;

  @override
  Widget build(BuildContext context) {
    final comic = widget.comic;

    if (App.isFluent) {
      return fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: Text(comic.title),
          leading: fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: comic.chapters.length,
                  itemBuilder: (context, i) {
                    final chapter = comic.chapters[i];
                    final selected = i == selectedChapter;
                    return fluent.Button(
                      onPressed: () => readSpecifiedEps(i),
                      child: Container(
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Expanded(child: Text(chapter.title)),
                            const SizedBox(width: 4),
                            if (selected)
                              const Icon(fluent.FluentIcons.check_mark),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: fluent.FilledButton(
                      onPressed: read,
                      child: Text("阅读".tl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: Text(
              comic.title,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 4,
              ),
              itemCount: comic.chapters.length,
              itemBuilder: (context, i) {
                final chapter = comic.chapters[i];
                final selected = i == selectedChapter;
                return Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    onTap: () => readSpecifiedEps(i),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(16)),
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(child: Text(chapter.title)),
                          const SizedBox(width: 4),
                          if (selected) const Icon(Icons.check),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: read,
                    child: Text("阅读".tl),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  void read() {
    openLocalComicReader(widget.comic, ep: selectedChapter + 1);
  }

  void readSpecifiedEps(int i) {
    setState(() {
      selectedChapter = i;
    });
    openLocalComicReader(widget.comic, ep: i + 1);
  }
}

class LocalReaderPage extends StatefulWidget {
  const LocalReaderPage({
    required this.comic,
    this.initialChapterId,
    super.key,
  });

  final LocalLibraryComic comic;
  final String? initialChapterId;

  @override
  State<LocalReaderPage> createState() => _LocalReaderPageState();
}

class _LocalReaderPageState extends State<LocalReaderPage> {
  late LocalLibraryChapter selectedChapter = _resolveInitialChapter();

  @override
  Widget build(BuildContext context) {
    final files = _chapterFiles(selectedChapter);
    return Scaffold(
      appBar: AppBar(title: Text(selectedChapter.title)),
      body: Column(
        children: [
          if (widget.comic.chapters.length > 1)
            SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final chapter = widget.comic.chapters[index];
                  return ChoiceChip(
                    label: Text(chapter.title),
                    selected: chapter.id == selectedChapter.id,
                    onSelected: (_) {
                      setState(() {
                        selectedChapter = chapter;
                      });
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: widget.comic.chapters.length,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      files[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 220,
                          alignment: Alignment.center,
                          child: const Text("Failed to load image"),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  LocalLibraryChapter _resolveInitialChapter() {
    if (widget.initialChapterId != null) {
      for (final chapter in widget.comic.chapters) {
        if (chapter.id == widget.initialChapterId) {
          return chapter;
        }
      }
    }
    return widget.comic.chapters.first;
  }

  List<File> _chapterFiles(LocalLibraryChapter chapter) {
    final directory = Directory(chapter.path);
    if (!directory.existsSync()) {
      return const <File>[];
    }
    final files = directory.listSync().whereType<File>().where((file) {
      return _isImageFile(file.path);
    }).toList();
    files.sort((a, b) => naturalComparePaths(a.path, b.path));
    return files;
  }
}

class LocalComicFolderEntry {
  const LocalComicFolderEntry({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String path;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "path": path,
      "createdAt": createdAt.millisecondsSinceEpoch,
    };
  }

  factory LocalComicFolderEntry.fromJson(Map<String, dynamic> json) {
    return LocalComicFolderEntry(
      id: json["id"].toString(),
      name: json["name"].toString(),
      path: json["path"].toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json["createdAt"] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class LocalLibraryComic {
  const LocalLibraryComic({
    required this.folderId,
    required this.title,
    required this.path,
    required this.coverPath,
    required this.modifiedAt,
    required this.chapters,
  });

  final String folderId;
  final String title;
  final String path;
  final String coverPath;
  final DateTime modifiedAt;
  final List<LocalLibraryChapter> chapters;

  int get totalPages =>
      chapters.fold<int>(0, (count, chapter) => count + chapter.pageCount);
}

class LocalLibraryChapter {
  const LocalLibraryChapter({
    required this.id,
    required this.title,
    required this.path,
    required this.pageCount,
  });

  final String id;
  final String title;
  final String path;
  final int pageCount;
}

class LocalComicHistoryEntry with HistoryMixin {
  const LocalComicHistoryEntry(this.comic);

  final LocalLibraryComic comic;

  @override
  String get title => comic.title;

  @override
  String? get subTitle =>
      comic.chapters.isEmpty ? null : comic.chapters.first.title;

  @override
  String get cover => comic.coverPath;

  @override
  String get target => comic.path;

  @override
  HistoryType get historyType => HistoryType("local-folder".hashCode);
}

String? resolveLocalComicCoverSync(String comicPath) {
  final directory = Directory(comicPath);
  if (!directory.existsSync()) {
    return null;
  }

  final rootImages = directory
      .listSync()
      .whereType<File>()
      .where((file) => _isImageFile(file.path))
      .toList()
    ..sort((a, b) => naturalComparePaths(a.path, b.path));

  for (final file in rootImages) {
    if (_basenameWithoutExtension(file.path).toLowerCase() == "cover") {
      return file.path;
    }
  }
  if (rootImages.isNotEmpty) {
    return rootImages.first.path;
  }

  final chapterDirectories = directory
      .listSync()
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => naturalComparePaths(a.path, b.path));

  for (final chapter in chapterDirectories) {
    final images = chapter
        .listSync()
        .whereType<File>()
        .where((file) => _isImageFile(file.path))
        .toList()
      ..sort((a, b) => naturalComparePaths(a.path, b.path));
    if (images.isNotEmpty) {
      return images.first.path;
    }
  }
  return null;
}

class LocalFolderReadingData extends ReadingData {
  LocalFolderReadingData(this.comic)
      : _eps = {
          for (final chapter in comic.chapters) chapter.id: chapter.title,
        };

  final LocalLibraryComic comic;
  final Map<String, String> _eps;

  @override
  String get title => comic.title;

  @override
  String get id => comic.path;

  @override
  String get downloadId => "local-folder:${comic.path.hashCode}";

  @override
  ComicType get type => ComicType.other;

  @override
  String get sourceKey => "local-folder";

  @override
  bool get hasEp => true;

  @override
  Map<String, String>? get eps => _eps;

  @override
  FavoriteType get favoriteType => FavoriteType(-1000);

  @override
  Future<Res<List<String>>> loadEpNetwork(int ep) async {
    final chapter = comic.chapters.elementAt(ep - 1);
    final directory = Directory(chapter.path);
    if (!directory.existsSync()) {
      return const Res.error("Folder not found");
    }
    final files = directory.listSync().whereType<File>().where((file) {
      return _isImageFile(file.path);
    }).toList()
      ..sort((a, b) => naturalComparePaths(a.path, b.path));
    return Res(files.map((e) => e.path).toList());
  }

  @override
  Stream<DownloadProgress> loadImageNetwork(
      int ep, int page, String url) async* {
    yield DownloadProgress(1, 1, "", url);
  }

  @override
  ImageProvider createImageProvider(int ep, int page, String url) {
    return FileImage(File(url));
  }

  @override
  String buildImageKey(int ep, int page, String url) => "$ep-$page-$url";
}

class LocalLibraryController extends ChangeNotifier {
  LocalLibraryController._();

  static final LocalLibraryController instance = LocalLibraryController._();

  static const _imageExtensions = <String>{
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".gif",
    ".bmp",
    ".jpe",
    ".avif",
  };

  List<LocalComicFolderEntry> _folders = const <LocalComicFolderEntry>[];
  final Map<String, List<LocalLibraryComic>> _comicsByFolderId =
      <String, List<LocalLibraryComic>>{};
  final Map<String, String> _errorsByFolderId = <String, String>{};
  final Set<String> _loadingFolderIds = <String>{};
  bool _initialized = false;

  List<LocalComicFolderEntry> get folders =>
      List<LocalComicFolderEntry>.unmodifiable(_folders);

  List<LocalLibraryComic> comicsFor(String folderId) {
    return List<LocalLibraryComic>.unmodifiable(
      _comicsByFolderId[folderId] ?? const <LocalLibraryComic>[],
    );
  }

  String? errorFor(String folderId) => _errorsByFolderId[folderId];

  bool isLoading(String folderId) => _loadingFolderIds.contains(folderId);

  LocalComicFolderEntry? folderById(String folderId) {
    for (final folder in _folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final file = File(_storePath);
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
        _folders = raw
            .whereType<Map>()
            .map((item) =>
                LocalComicFolderEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (_) {
        _folders = const <LocalComicFolderEntry>[];
      }
    }
    _initialized = true;
    notifyListeners();
    await refreshAll();
  }

  Future<LocalComicFolderEntry> addFolder(String path) async {
    await initialize();
    final normalizedPath = _normalizePath(path);
    for (final folder in _folders) {
      if (_samePath(folder.path, normalizedPath)) {
        await refreshFolder(folder.id);
        return folder;
      }
    }

    final directory = Directory(normalizedPath);
    if (!await directory.exists()) {
      throw StateError("Folder not found.");
    }

    final entry = LocalComicFolderEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _displayNameForPath(normalizedPath),
      path: normalizedPath,
      createdAt: DateTime.now(),
    );
    _folders = [..._folders, entry];
    await _persist();
    notifyListeners();
    await refreshFolder(entry.id);
    return entry;
  }

  Future<void> removeFolder(String folderId) async {
    await initialize();
    _folders = _folders.where((folder) => folder.id != folderId).toList();
    _comicsByFolderId.remove(folderId);
    _errorsByFolderId.remove(folderId);
    _loadingFolderIds.remove(folderId);
    await _persist();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    await initialize();
    for (final folder in _folders) {
      await refreshFolder(folder.id);
    }
  }

  Future<void> refreshFolder(String folderId) async {
    await initialize();
    final folder = folderById(folderId);
    if (folder == null) {
      return;
    }

    _loadingFolderIds.add(folderId);
    _errorsByFolderId.remove(folderId);
    notifyListeners();

    try {
      final comics = await _scanFolder(folder);
      _comicsByFolderId[folderId] = comics;
    } catch (error) {
      _comicsByFolderId[folderId] = const <LocalLibraryComic>[];
      _errorsByFolderId[folderId] = error.toString();
    } finally {
      _loadingFolderIds.remove(folderId);
      notifyListeners();
    }
  }

  Future<LocalLibraryComic?> loadComicByPath(String comicPath) async {
    await initialize();
    final directory = Directory(comicPath);
    if (!await directory.exists()) {
      return null;
    }

    String folderId = "";
    final normalizedComicPath = _normalizePath(comicPath).toLowerCase();
    for (final folder in _folders) {
      final normalizedFolderPath = _normalizePath(folder.path).toLowerCase();
      if (normalizedComicPath.startsWith(normalizedFolderPath)) {
        folderId = folder.id;
        break;
      }
    }

    return _scanComicDirectory(
      directory,
      folderId: folderId,
      titleOverride: _basename(directory.path),
    );
  }

  Future<void> _persist() async {
    final file = File(_storePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      jsonEncode(_folders.map((folder) => folder.toJson()).toList()),
    );
  }

  Future<List<LocalLibraryComic>> _scanFolder(
    LocalComicFolderEntry folder,
  ) async {
    final directory = Directory(folder.path);
    if (!await directory.exists()) {
      throw StateError("Folder not found: ${folder.path}");
    }

    final childDirectories = <Directory>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory && !_isHiddenName(entity.path)) {
        childDirectories.add(entity);
      }
    }
    childDirectories.sort((a, b) => naturalComparePaths(a.path, b.path));

    final comics = <LocalLibraryComic>[];
    for (final child in childDirectories) {
      final comic = await _scanComicDirectory(child, folderId: folder.id);
      if (comic != null) {
        comics.add(comic);
      }
    }

    if (comics.isEmpty) {
      final selfComic = await _scanComicDirectory(
        directory,
        folderId: folder.id,
        titleOverride: folder.name,
      );
      if (selfComic != null) {
        comics.add(selfComic);
      }
    }

    comics.sort((a, b) {
      final timeCompare = b.modifiedAt.compareTo(a.modifiedAt);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return a.title.compareTo(b.title);
    });
    return comics;
  }

  Future<LocalLibraryComic?> _scanComicDirectory(
    Directory directory, {
    required String folderId,
    String? titleOverride,
  }) async {
    if (!await directory.exists()) {
      return null;
    }

    final rootImages = <File>[];
    final childDirectories = <Directory>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && _isImageFile(entity.path)) {
        rootImages.add(entity);
      } else if (entity is Directory && !_isHiddenName(entity.path)) {
        childDirectories.add(entity);
      }
    }

    rootImages.sort((a, b) => naturalComparePaths(a.path, b.path));
    childDirectories.sort((a, b) => naturalComparePaths(a.path, b.path));

    final chapters = <LocalLibraryChapter>[];
    for (final child in childDirectories) {
      final images = await _listImageFiles(child);
      if (images.isEmpty) {
        continue;
      }
      chapters.add(
        LocalLibraryChapter(
          id: _basename(child.path),
          title: _basename(child.path),
          path: child.path,
          pageCount: images.length,
        ),
      );
    }

    if (chapters.isEmpty && rootImages.isEmpty) {
      return null;
    }

    if (chapters.isEmpty) {
      chapters.add(
        LocalLibraryChapter(
          id: "main",
          title: "Main",
          path: directory.path,
          pageCount: rootImages.length,
        ),
      );
    }

    final coverPath = await _resolveCoverPath(directory, rootImages, chapters);
    if (coverPath == null) {
      return null;
    }

    final stat = await directory.stat();
    return LocalLibraryComic(
      folderId: folderId,
      title: titleOverride ?? _basename(directory.path),
      path: directory.path,
      coverPath: coverPath,
      modifiedAt: stat.modified,
      chapters: chapters,
    );
  }

  Future<String?> _resolveCoverPath(
    Directory directory,
    List<File> rootImages,
    List<LocalLibraryChapter> chapters,
  ) async {
    for (final file in rootImages) {
      final name = _basenameWithoutExtension(file.path).toLowerCase();
      if (name == "cover") {
        return file.path;
      }
    }
    if (rootImages.isNotEmpty) {
      return rootImages.first.path;
    }
    if (chapters.isEmpty) {
      return null;
    }
    final firstChapter = Directory(chapters.first.path);
    final images = await _listImageFiles(firstChapter);
    if (images.isEmpty) {
      return null;
    }
    return images.first.path;
  }

  Future<List<File>> _listImageFiles(Directory directory) async {
    if (!await directory.exists()) {
      return const <File>[];
    }

    final images = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && _isImageFile(entity.path)) {
        images.add(entity);
      }
    }
    images.sort((a, b) => naturalComparePaths(a.path, b.path));
    return images;
  }

  bool _isImageFile(String path) {
    return _imageExtensions.contains(_extension(path).toLowerCase());
  }

  bool _isHiddenName(String path) {
    return _basename(path).startsWith(".");
  }

  String _displayNameForPath(String path) {
    final basename = _basename(path);
    return basename.isEmpty ? path : basename;
  }

  String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return Directory(trimmed).absolute.path;
  }

  bool _samePath(String a, String b) {
    return _normalizePath(a).toLowerCase() == _normalizePath(b).toLowerCase();
  }

  /// 判断路径是否位于应用管理的本地副本目录（local_add_comic）之内。
  /// 这些文件由"复制到本地存储目录"产生，移除文件夹时应一并删除。
  bool isManagedCopyPath(String path) {
    final root = _normalizePath(
      "${App.dataPath}${Platform.pathSeparator}local_add_comic",
    );
    final normalized = _normalizePath(path);
    if (normalized.length <= root.length + 1) {
      return false;
    }
    return normalized.toLowerCase().startsWith(
          "$root${Platform.pathSeparator}".toLowerCase(),
        );
  }
}

String get _storePath =>
    "${App.dataPath}${Platform.pathSeparator}local_comic_folders.json";

int _gridColumnCount(double width) {
  if (width >= 1400) return 6;
  if (width >= 1180) return 5;
  if (width >= 900) return 4;
  if (width >= 640) return 3;
  if (width >= 360) return 2;
  return 1;
}

String _localComicsCount(int count) => "$count ${"部漫画".tl}";

String _localChaptersPages(int chapters, int pages) =>
    "$chapters ${"章".tl} · $pages ${"页".tl}";

String _basename(String path) {
  final normalized = path.replaceAll("\\", "/");
  final segments = normalized.split("/").where((e) => e.isNotEmpty).toList();
  return segments.isEmpty ? path : segments.last;
}

String _basenameWithoutExtension(String path) {
  final base = _basename(path);
  final index = base.lastIndexOf(".");
  if (index <= 0) {
    return base;
  }
  return base.substring(0, index);
}

String _extension(String path) {
  final base = _basename(path);
  final index = base.lastIndexOf(".");
  if (index < 0) {
    return "";
  }
  return base.substring(index);
}

bool _isImageFile(String path) {
  const imageExtensions = <String>{
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
    ".gif",
    ".bmp",
    ".jpe",
    ".avif",
  };
  return imageExtensions.contains(_extension(path).toLowerCase());
}

int naturalComparePaths(String a, String b) {
  final aa = a.toLowerCase();
  final bb = b.toLowerCase();
  var ia = 0;
  var ib = 0;

  while (ia < aa.length && ib < bb.length) {
    final ca = aa.codeUnitAt(ia);
    final cb = bb.codeUnitAt(ib);
    final isDigitA = ca >= 48 && ca <= 57;
    final isDigitB = cb >= 48 && cb <= 57;

    if (isDigitA && isDigitB) {
      var enda = ia;
      var endb = ib;
      while (enda < aa.length) {
        final code = aa.codeUnitAt(enda);
        if (code < 48 || code > 57) break;
        enda++;
      }
      while (endb < bb.length) {
        final code = bb.codeUnitAt(endb);
        if (code < 48 || code > 57) break;
        endb++;
      }
      final na = int.tryParse(aa.substring(ia, enda)) ?? 0;
      final nb = int.tryParse(bb.substring(ib, endb)) ?? 0;
      if (na != nb) {
        return na.compareTo(nb);
      }
      ia = enda;
      ib = endb;
      continue;
    }

    if (ca != cb) {
      return ca.compareTo(cb);
    }
    ia++;
    ib++;
  }

  return aa.length.compareTo(bb.length);
}

Future<void> _persistString(String key, String value) async {
  final file = File(
    "${App.dataPath}${Platform.pathSeparator}local_add_comic_ui.json",
  );
  Map<String, dynamic> data = <String, dynamic>{};
  if (await file.exists()) {
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
  }
  data[key] = value;
  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }
  await file.writeAsString(jsonEncode(data));
}

String? _readString(String key) {
  final file = File(
    "${App.dataPath}${Platform.pathSeparator}local_add_comic_ui.json",
  );
  if (!file.existsSync()) {
    return null;
  }
  try {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return data[key]?.toString();
  } catch (_) {
    return null;
  }
}
