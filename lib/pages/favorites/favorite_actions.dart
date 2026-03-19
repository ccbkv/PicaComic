part of 'favorites_page.dart';

/// Open a dialog to create a new favorite folder.
Future<void> newFolder() async {
  return showDialog(
      context: App.globalContext!,
      builder: (context) {
        var controller = TextEditingController();
        String? error;

        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "新建收藏夹".tl,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "名称".tl,
                    errorText: error,
                  ),
                  onChanged: (s) {
                    if (error != null) {
                      setState(() {
                        error = null;
                      });
                    }
                  },
                ),
              ],
            ).paddingHorizontal(16),
            actions: [
              TextButton(
                child: Text("从文件导入".tl),
                onPressed: () async {
                  var data = await getDataFromUserSelectedFile(["json"]);
                  if (data == null) return;
                  try {
                    var (err, msg) = LocalFavoritesManager().loadFolderData(data);
                    if (err) {
                      showToast(message: msg);
                      return;
                    }
                  } catch (e) {
                    showToast(message: "导入失败".tl);
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ).paddingRight(4),
              TextButton(
                child: Text("从网络导入".tl),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 200));
                  networkToLocal();
                },
              ).paddingRight(4),
              FilledButton(
                onPressed: () {
                  var e = validateFolderName(controller.text);
                  if (e != null) {
                    setState(() {
                      error = e;
                    });
                  } else {
                    try {
                      LocalFavoritesManager().createFolder(controller.text);
                      Navigator.of(context).pop();
                    } catch (e) {
                      setState(() {
                        error = e.toString();
                      });
                    }
                  }
                },
                child: Text("创建".tl),
              ),
            ],
          );
        });
      });
}

String? validateFolderName(String newFolderName) {
  var folders = LocalFavoritesManager().folderNames;
  if (newFolderName.isEmpty) {
    return "Folder name cannot be empty".tl;
  } else if (newFolderName.length > 50) {
    return "Folder name is too long".tl;
  } else if (folders.contains(newFolderName)) {
    return "Folder already exists".tl;
  }
  return null;
}

void addFavorite(List<BaseComic> comics, String sourceKey) {
  var folders = LocalFavoritesManager().folderNames;

  showDialog(
    context: App.globalContext!,
    builder: (context) {
      String? selectedFolder;

      return StatefulBuilder(builder: (context, setState) {
        return ContentDialog(
          title: "选择一个文件夹".tl,
          content: ListTile(
            title: Text("Folder".tl),
            trailing: DropdownButton<String>(
              value: selectedFolder,
              items: folders.map((f) => DropdownMenuItem(
                value: f,
                child: Text(f),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  selectedFolder = v;
                });
              },
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (selectedFolder != null) {
                  for (var comic in comics) {
                    LocalFavoritesManager().addComic(
                      selectedFolder!,
                      FavoriteItem(
                        target: comic.id,
                        name: comic.title,
                        coverPath: comic.cover,
                        author: comic.subTitle ?? '',
                        type: FavoriteType(sourceKey.hashCode),
                        tags: comic.tags ?? [],
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                }
              },
              child: Text("确认".tl),
            ),
          ],
        );
      });
    },
  );
}

Future<List<FavoriteItem>> updateComicsInfo(String folder) async {
  var comics = LocalFavoritesManager().getAllComics(folder);

  Future<void> updateSingleComic(int index) async {
    int retry = 3;

    while (true) {
      try {
        var c = comics[index];
        var comicSource = c.type.comicSource;
        if (comicSource == null) return;

        var newInfo = (await comicSource.loadComicInfo!(c.target)).data;

        var newTags = <String>[];
        for (var entry in newInfo.tags.entries) {
          const shouldIgnore = ['author', 'artist', 'time'];
          var namespace = entry.key;
          if (shouldIgnore.contains(namespace.toLowerCase())) {
            continue;
          }
          for (var tag in entry.value) {
            newTags.add("$namespace:$tag");
          }
        }

        comics[index] = FavoriteItem(
          target: c.target,
          name: newInfo.title,
          coverPath: newInfo.cover,
          author: newInfo.subTitle ??
              newInfo.tags['author']?.firstOrNull ??
              c.author,
          type: c.type,
          tags: newTags,
        );

        LocalFavoritesManager().updateInfo(folder, comics[index]);
        return;
      } catch (e) {
        retry--;
        if (retry == 0) {
          rethrow;
        }
        continue;
      }
    }
  }

  var finished = ValueNotifier(0);

  var errors = 0;

  var index = 0;

  bool isCanceled = false;

  showDialog(
    context: App.globalContext!,
    builder: (context) {
      return ValueListenableBuilder(
        valueListenable: finished,
        builder: (context, value, child) {
          var isFinished = value == comics.length;
          return ContentDialog(
            title: isFinished ? "Finished".tl : "Updating".tl,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: value / comics.length,
                ),
                const SizedBox(height: 4),
                Text("$value/${comics.length}"),
                const SizedBox(height: 4),
                if (errors > 0) Text("Errors: $errors"),
              ],
            ).paddingHorizontal(16),
            actions: [
              Button.filled(
                color: isFinished ? null : Theme.of(context).colorScheme.error,
                onPressed: () {
                  isCanceled = true;
                  Navigator.of(context).pop();
                },
                child: isFinished ? Text("OK".tl) : Text("Cancel".tl),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    isCanceled = true;
  });

  while (index < comics.length) {
    var futures = <Future>[];
    const maxConcurrency = 4;

    if (isCanceled) {
      return comics;
    }

    for (var i = 0; i < maxConcurrency; i++) {
      if (index + i >= comics.length) break;
      futures.add(updateSingleComic(index + i).then((v) {
        finished.value++;
      }, onError: (_) {
        errors++;
        finished.value++;
      }));
    }

    await Future.wait(futures);
    index += maxConcurrency;
  }

  return comics;
}

Future<void> sortFolders({VoidCallback? onReorder}) async {
  var folders = LocalFavoritesManager().folderNames;

  await showDialog(
    context: App.globalContext!,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Row(
            children: [
              Text("排序".tl),
              const Spacer(),
              Tooltip(
                message: "帮助".tl,
                child: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("重新排序".tl),
                        content: Text("长按并拖动以重新排序。".tl),
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
            ],
          ),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 300,
            height: 400,
            child: ReorderableListView.builder(
              padding: EdgeInsets.zero,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex--;
                }
                setState(() {
                  var item = folders.removeAt(oldIndex);
                  folders.insert(newIndex, item);
                });
                // 立即保存排序結果
                LocalFavoritesManager().updateOrder(
                  {for (var i = 0; i < folders.length; i++) folders[i]: i},
                );
                // 通知外部更新UI
                onReorder?.call();
              },
              itemCount: folders.length,
              itemBuilder: (context, index) {
                return ReorderableDragStartListener(
                  key: ValueKey(folders[index]),
                  index: index,
                  child: Container(
                    width: double.infinity,
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(folders[index]),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("取消".tl),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("确认".tl),
            ),
          ],
        );
      });
    },
  );
}

Future<void> importNetworkFolder(
  String source,
  int updatePageNum,
  String? folder,
  String? folderID,
) async {
  var comicSource = ComicSource.find(source);
  if (comicSource == null) {
    return;
  }
  if (folder != null && folder.isEmpty) {
    folder = null;
  }
  var resultName = folder ?? comicSource.name;
  var exists = LocalFavoritesManager().folderNames.contains(resultName);
  if (exists) {
    // Check if linked to same network folder
    var syncs = LocalFavoritesManager().folderSync;
    var existingSync = syncs.firstWhereOrNull(
      (s) => s.folderName == resultName && s.key == source,
    );
    if (existingSync == null || 
        existingSync.syncDataObj['folderId'] != folderID) {
      showToast(message: "Folder already exists".tl);
      return;
    }
  }
  if (!exists) {
    LocalFavoritesManager().createFolder(resultName);
    LocalFavoritesManager().insertFolderSync(
      FolderSync(resultName, source, jsonEncode({'folderId': folderID ?? ''})),
    );
  }
  
  bool isOldToNewSort = false; // Default, can be customized per source
  var current = 0;
  int receivedComics = 0;
  int requestCount = 0;
  var isFinished = false;
  int maxPage = 1;
  List<FavoriteItem> comics = [];
  String? next;
  
  Future<void> fetchNext() async {
    var retry = 3;
    while (updatePageNum > requestCount && !isFinished) {
      try {
        if (comicSource.favoriteData?.loadComic != null) {
          next ??= '1';
          var page = int.parse(next!);
          var res = await comicSource.favoriteData!.loadComic(page, folderID);
          var count = 0;
          receivedComics += res.data.length;
          for (var c in res.data) {
            if (!LocalFavoritesManager().comicExists(
                resultName, c.id, comicSource.key.hashCode)) {
              count++;
              comics.add(FavoriteItem(
                target: c.id,
                name: c.title,
                coverPath: c.cover,
                type: FavoriteType(comicSource.key.hashCode),
                author: c.subTitle ?? '',
                tags: c.tags ?? [],
              ));
            }
          }
          requestCount++;
          current += count;
          if (res.data.isEmpty || res.subData == page) {
            isFinished = true;
            next = null;
          } else {
            next = (page + 1).toString();
          }
        } else {
          throw "Unsupported source";
        }
        return;
      } catch (e) {
        retry--;
        if (retry == 0) {
          rethrow;
        }
        continue;
      }
    }
    isFinished = true;
  }

  bool isCanceled = false;
  String? errorMsg;
  bool isErrored() => errorMsg != null;

  void Function()? updateDialog;
  void Function()? closeDialog;

  showDialog(
    context: App.globalContext!,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          updateDialog = () => setState(() {});
          closeDialog = () => Navigator.pop(context);
          return ContentDialog(
            title: isFinished
                ? "Finished".tl
                : isErrored()
                    ? "Error".tl
                    : "Importing".tl,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: isFinished ? 1 : null,
                ),
                const SizedBox(height: 4),
                Text("Imported @a comics, loaded @b pages, received @c comics"
                    .tlParams({
                  "a": current.toString(),
                  "b": requestCount.toString(),
                  "c": receivedComics.toString(),
                })),
                const SizedBox(height: 4),
                if (isErrored()) Text("Error: $errorMsg"),
              ],
            ).paddingHorizontal(16),
            actions: [
              Button.filled(
                color: (isFinished || isErrored())
                    ? null
                    : Theme.of(context).colorScheme.error,
                onPressed: () {
                  isCanceled = true;
                  Navigator.of(context).pop();
                },
                child: (isFinished || isErrored())
                    ? Text("OK".tl)
                    : Text("Cancel".tl),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    isCanceled = true;
  });

  while (!isFinished && !isCanceled) {
    try {
      await fetchNext();
      updateDialog?.call();
    } catch (e) {
      errorMsg = e.toString();
      updateDialog?.call();
      break;
    }
  }
  try {
    for (var c in comics) {
      LocalFavoritesManager().addComic(resultName, c);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    closeDialog?.call();
  } catch (e, stackTrace) {
    LogManager.addLog(LogLevel.error, "Import", "$e\n$stackTrace");
  }
}
