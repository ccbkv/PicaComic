part of pica_settings;

/// 漫画评论分组信息
class _ComicCommentsGroup {
  final String sourceKey;
  final String comicId;
  String? comicName;
  final List<_ChapterCommentsInfo> chapters = [];
  int get totalSize => chapters.fold(0, (sum, c) => sum + c.fileSize);

  _ComicCommentsGroup({
    required this.sourceKey,
    required this.comicId,
    this.comicName,
  });

  String get displayName => comicName ?? comicId;
}

/// 单个章节的评论信息
class _ChapterCommentsInfo {
  final String epId;
  String? chapterTitle;
  final DateTime? savedAt;
  final int fileSize;
  final List<dynamic> comments;
  final String filePath;
  bool isLocked;

  _ChapterCommentsInfo({
    required this.epId,
    this.chapterTitle,
    this.savedAt,
    required this.fileSize,
    required this.comments,
    required this.filePath,
    this.isLocked = false,
  });

  String get displayTitle => chapterTitle ?? "章节 $epId".tl;
}

class ChapterCommentsManagerPage extends StatefulWidget {
  const ChapterCommentsManagerPage({super.key});

  @override
  State<ChapterCommentsManagerPage> createState() => _ChapterCommentsManagerPageState();
}

class _ChapterCommentsManagerPageState extends State<ChapterCommentsManagerPage> {
  List<_ComicCommentsGroup> _comics = [];
  bool _loading = true;
  int _totalFiles = 0;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var allComments = await ChapterCommentsStorage.getAllSavedComments();
    
    // 按漫画分组
    var groupMap = <String, _ComicCommentsGroup>{};
    
    for (var data in allComments) {
      var sourceKey = data['sourceKey'] as String? ?? '';
      var comicId = data['comicId'] as String? ?? '';
      var groupKey = '${sourceKey}_$comicId';
      
      var group = groupMap.putIfAbsent(groupKey, () => _ComicCommentsGroup(
        sourceKey: sourceKey,
        comicId: comicId,
        comicName: data['comicName'] as String?,
      ));
      
      // 如果之前没有漫画名但这条数据有，更新漫画名
      if (group.comicName == null && data['comicName'] != null) {
        group.comicName = data['comicName'] as String;
      }
      
      var savedAtStr = data['savedAt'] as String?;
      DateTime? savedAt;
      if (savedAtStr != null) {
        try {
          savedAt = DateTime.parse(savedAtStr);
        } catch (_) {}
      }
      
      group.chapters.add(_ChapterCommentsInfo(
        epId: data['epId'] as String? ?? '',
        chapterTitle: data['chapterTitle'] as String?,
        savedAt: savedAt,
        fileSize: data['fileSize'] as int? ?? 0,
        comments: data['comments'] as List<dynamic>? ?? [],
        filePath: data['filePath'] as String? ?? '',
        isLocked: data['isLocked'] == true,
      ));
    }
    
    var comics = groupMap.values.toList();
    // 按最新评论时间排序
    comics.sort((a, b) {
      var aTime = a.chapters.isNotEmpty ? a.chapters.map((c) => c.savedAt).reduce((v, e) => v?.isAfter(e ?? DateTime(0)) ?? false ? v : e) : null;
      var bTime = b.chapters.isNotEmpty ? b.chapters.map((c) => c.savedAt).reduce((v, e) => v?.isAfter(e ?? DateTime(0)) ?? false ? v : e) : null;
      return (bTime ?? DateTime(0)).compareTo(aTime ?? DateTime(0));
    });
    
    var totalFiles = allComments.length;
    var totalSize = allComments.fold(0, (sum, c) => sum + (c['fileSize'] as int? ?? 0));

    setState(() {
      _comics = comics;
      _totalFiles = totalFiles;
      _totalSize = totalSize;
      _loading = false;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _deleteComic(_ComicCommentsGroup comic) async {
    var displayName = comic.displayName;
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("确认删除".tl),
        content: Text("确定要删除《$displayName》及其所有 ${comic.chapters.length} 个章节的评论吗？".tl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("删除".tl, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      var success = await ChapterCommentsStorage.deleteComicComments(comic.sourceKey, comic.comicId);
      if (success) {
        await _loadData();
        if (mounted) {
          context.showMessage(message: "删除成功".tl);
        }
      } else {
        if (mounted) {
          context.showMessage(message: "删除失败".tl);
        }
      }
    }
  }

  Future<void> _deleteAll() async {
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("确认删除全部".tl),
        content: Text("确定要删除所有已保存的章节评论吗？此操作不可恢复。".tl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("全部删除".tl, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        var baseDir = Directory("${App.dataPath}/chapter_comments");
        if (await baseDir.exists()) {
          await baseDir.delete(recursive: true);
        }
        await _loadData();
        if (mounted) {
          context.showMessage(message: "已全部删除".tl);
        }
      } catch (e) {
        if (mounted) {
          context.showMessage(message: "删除失败: $e".tl);
        }
      }
    }
  }

  void _openComicChapters(_ComicCommentsGroup comic) {
    context.to(() => _ChapterCommentsListPage(comic: comic));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("已保存的章节评论".tl),
        actions: [
          if (_comics.isNotEmpty)
            IconButton(
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_forever),
              tooltip: "全部删除".tl,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _comics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text("暂无已保存的评论".tl, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.storage, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("共 ${_comics.length} 个漫画, $_totalFiles 个章节".tl),
                                Text("占用空间: ${_formatSize(_totalSize)}".tl,
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _comics.length,
                        itemBuilder: (context, index) {
                          var comic = _comics[index];
                          var subtitle = comic.comicName != null 
                            ? "${comic.sourceKey} · ${comic.chapters.length}个章节".tl
                            : "来源: ${comic.sourceKey} · ${comic.chapters.length}个章节".tl;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  comic.displayName.isNotEmpty ? comic.displayName.substring(0, 1).toUpperCase() : "?",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(
                                comic.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(subtitle),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _openComicChapters(comic),
                                    icon: const Icon(Icons.folder_open),
                                    tooltip: "查看章节".tl,
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteComic(comic),
                                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                    tooltip: "删除".tl,
                                  ),
                                ],
                              ),
                              onTap: () => _openComicChapters(comic),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ChapterCommentsListPage extends StatefulWidget {
  final _ComicCommentsGroup comic;

  const _ChapterCommentsListPage({required this.comic});

  @override
  State<_ChapterCommentsListPage> createState() => _ChapterCommentsListPageState();
}

class _ChapterCommentsListPageState extends State<_ChapterCommentsListPage> {
  late List<_ChapterCommentsInfo> _chapters;

  @override
  void initState() {
    super.initState();
    _chapters = List.from(widget.comic.chapters);
    // 按保存时间排序，最新的在前
    _chapters.sort((a, b) => (b.savedAt ?? DateTime(0)).compareTo(a.savedAt ?? DateTime(0)));
  }

  Future<void> _toggleLock(_ChapterCommentsInfo chapter) async {
    var newState = await ChapterCommentsStorage.toggleLock(
      widget.comic.sourceKey,
      widget.comic.comicId,
      chapter.epId,
    );
    if (newState != false || mounted) {
      setState(() {
        chapter.isLocked = newState;
      });
      if (mounted) {
        context.showMessage(message: newState ? "已锁定，禁止联网更新".tl : "已解锁，允许联网更新".tl);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _deleteChapter(_ChapterCommentsInfo chapter) async {
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("确认删除".tl),
        content: Text("确定要删除《${chapter.displayTitle}》的评论吗？".tl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("删除".tl, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      var success = await ChapterCommentsStorage.deleteComments(
        widget.comic.sourceKey,
        widget.comic.comicId,
        chapter.epId,
      );
      if (success) {
        setState(() {
          _chapters.remove(chapter);
        });
        if (mounted) {
          context.showMessage(message: "删除成功".tl);
        }
      } else {
        if (mounted) {
          context.showMessage(message: "删除失败".tl);
        }
      }
    }
  }

  void _viewChapter(_ChapterCommentsInfo chapter) async {
    var result = await context.to<bool>(() => _ChapterCommentsDetailPage(
      comicName: widget.comic.displayName,
      chapterTitle: chapter.displayTitle,
      sourceKey: widget.comic.sourceKey,
      comicId: widget.comic.comicId,
      epId: chapter.epId,
      comments: chapter.comments,
    ));
    // 如果返回true，说明有评论被删除，刷新数据
    if (result == true) {
      _refreshChapterData(chapter);
    }
  }

  void _refreshChapterData(_ChapterCommentsInfo chapter) async {
    var meta = await ChapterCommentsStorage.loadCommentsWithMeta(
      widget.comic.sourceKey,
      widget.comic.comicId,
      chapter.epId,
    );
    if (meta != null && mounted) {
      setState(() {
        var newComments = meta['comments'] as List<dynamic>? ?? [];
        chapter.comments.clear();
        chapter.comments.addAll(newComments);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("章节列表".tl, style: const TextStyle(fontSize: 18)),
            Text(widget.comic.displayName, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: _chapters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_drive_file, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text("暂无评论文件".tl, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                var chapter = _chapters[index];
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.comment, color: Colors.blue),
                    title: Text(chapter.displayTitle),
                    subtitle: Text("${chapter.comments.length}条评论 · ${_formatSize(chapter.fileSize)} · ${_formatDate(chapter.savedAt)}".tl),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _toggleLock(chapter),
                          icon: Icon(
                            chapter.isLocked ? Icons.lock : Icons.lock_open,
                            color: chapter.isLocked ? Colors.orange : Colors.green,
                          ),
                          tooltip: chapter.isLocked ? "已锁定，点击解锁".tl : "未锁定，点击锁定".tl,
                        ),
                        IconButton(
                          onPressed: () => _viewChapter(chapter),
                          icon: const Icon(Icons.visibility),
                          tooltip: "查看评论".tl,
                        ),
                        IconButton(
                          onPressed: () => _deleteChapter(chapter),
                          icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                          tooltip: "删除".tl,
                        ),
                      ],
                    ),
                    onTap: () => _viewChapter(chapter),
                  ),
                );
              },
            ),
    );
  }
}

class _ChapterCommentsDetailPage extends StatefulWidget {
  final String comicName;
  final String chapterTitle;
  final String sourceKey;
  final String comicId;
  final String epId;
  final List<dynamic> comments;

  const _ChapterCommentsDetailPage({
    required this.comicName,
    required this.chapterTitle,
    required this.sourceKey,
    required this.comicId,
    required this.epId,
    required this.comments,
  });

  @override
  State<_ChapterCommentsDetailPage> createState() => _ChapterCommentsDetailPageState();
}

class _ChapterCommentsDetailPageState extends State<_ChapterCommentsDetailPage> {
  late List<Map<String, dynamic>> _comments;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.comments.map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  void _showCommentOptions(Map<String, dynamic> comment, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text("编辑评论".tl),
              onTap: () {
                Navigator.pop(context);
                _editComment(comment, index);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text("删除评论".tl, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteComment(comment, index);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editComment(Map<String, dynamic> comment, int index) {
    var controller = TextEditingController(text: comment['content'] as String? ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("编辑评论".tl),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: "输入评论内容".tl,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () async {
              var newContent = controller.text.trim();
              if (newContent.isEmpty) {
                context.showMessage(message: "评论内容不能为空".tl);
                return;
              }
              
              var updatedComment = Map<String, dynamic>.from(comment);
              updatedComment['content'] = newContent;
              
              var success = await ChapterCommentsStorage.updateComment(
                widget.sourceKey,
                widget.comicId,
                widget.epId,
                comment['id'] as String,
                updatedComment,
              );
              
              if (success && mounted) {
                setState(() {
                  _comments[index] = updatedComment;
                });
                Navigator.pop(context);
                context.showMessage(message: "编辑成功".tl);
              } else {
                if (mounted) {
                  context.showMessage(message: "编辑失败".tl);
                }
              }
            },
            child: Text("保存".tl),
          ),
        ],
      ),
    );
  }

  void _deleteComment(Map<String, dynamic> comment, int index) async {
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("确认删除".tl),
        content: Text("确定要删除这条评论吗？".tl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("取消".tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("删除".tl, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      var success = await ChapterCommentsStorage.deleteSingleComment(
        widget.sourceKey,
        widget.comicId,
        widget.epId,
        comment['id'] as String,
      );
      
      if (success && mounted) {
        setState(() {
          _comments.removeAt(index);
        });
        context.showMessage(message: "删除成功".tl);
        // 标记有数据变化，返回时通知上级页面刷新
        _hasChanges = true;
      } else {
        if (mounted) {
          context.showMessage(message: "删除失败".tl);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(_hasChanges);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.chapterTitle, style: const TextStyle(fontSize: 18)),
            Text("${widget.comicName} (${_comments.length}条)".tl, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: _comments.isEmpty
          ? Center(
              child: Text("暂无评论".tl, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                var comment = _comments[index];
                return GestureDetector(
                  onLongPress: () => _showCommentOptions(comment, index),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  (comment['userName'] as String? ?? "?").substring(0, 1).toUpperCase(),
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  comment['userName'] as String? ?? "Unknown".tl,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (comment['time'] != null)
                                Text(
                                  comment['time'].toString(),
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(comment['content'] as String? ?? ""),
                          if (comment['replyCount'] != null && (comment['replyCount'] as num) > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "${comment['replyCount']} 条回复".tl,
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                              ),
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
