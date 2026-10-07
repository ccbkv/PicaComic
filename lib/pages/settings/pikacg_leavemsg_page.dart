import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/components/comment.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/cache_network.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/pages/picacg/comments_page.dart';
import 'package:pica_comic/utils/translations.dart';

/// 哔咔留言板的固定ID, 与picacg-qt中CommentWidget的default一致
const String kLeaveMsgId = "5822a6e3ad7ede654696e482";

/// 留言条目, [floor]为null时表示置顶留言
class LeaveMsgItem {
  LeaveMsgItem(this.comment, this.floor);

  final Comment comment;
  final int? floor;
}

/// 解析留言数据, 与PicacgNetwork.loadMoreCommends中的解析逻辑一致
Comment parseLeaveMsgComment(dynamic doc) {
  String url = defaultAvatarUrl;
  try {
    url = "${doc["_user"]["avatar"]["fileServer"]}"
        "/static/"
        "${doc["_user"]["avatar"]["path"]}";
  } catch (e) {
    url = defaultAvatarUrl;
  }
  if (doc["_user"] != null) {
    return Comment(
      doc["_user"]["name"],
      url,
      doc["_user"]["_id"],
      doc["_user"]["level"],
      doc["content"],
      doc["commentsCount"],
      doc["_id"],
      doc["isLiked"],
      doc["likesCount"],
      doc["_user"]["character"],
      doc["_user"]["slogan"],
      doc["created_at"],
    );
  } else {
    return Comment(
      "Unknown",
      url,
      "",
      1,
      doc["content"],
      doc["commentsCount"],
      doc["_id"],
      doc["isLiked"],
      doc["likesCount"],
      null,
      null,
      doc["created_at"],
    );
  }
}

/// 将UTC时间转换为本地时间, 修复时间显示相差八小时的问题
String formatLeaveMsgTime(String time) {
  var dt = DateTime.tryParse(time);
  if (dt == null) {
    try {
      return "${time.substring(0, 10)}  ${time.substring(11, 19)}";
    } catch (e) {
      return time;
    }
  }
  if (dt.isUtc) {
    dt = dt.toLocal();
  }
  String two(int n) => n.toString().padLeft(2, "0");
  return "${dt.year}-${two(dt.month)}-${two(dt.day)}  "
      "${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}";
}

class PicacgLeaveMsgPageLogic extends StateController {
  bool isLoading = true;
  bool started = false;
  bool loading = false;
  bool sending = false;
  List<LeaveMsgItem> items = [];
  int page = 0;
  int pages = 0;
  int total = 0;
  int limit = 20;
  final controller = TextEditingController();

  /// 加载指定页的留言, [toEnd]为true时追加到列表末尾
  Future<void> loadPage(int page, {bool toEnd = false}) async {
    if (loading) {
      return;
    }
    loading = true;
    var res = await network.get(
      "${network.apiUrl}/comics/$kLeaveMsgId/comments?page=$page",
      expiredTime: CacheExpiredTime.no,
    );
    loading = false;
    if (res.error) {
      isLoading = false;
      update();
      return;
    }
    var data = res.data["data"];
    if (data == null || data["comments"] == null) {
      isLoading = false;
      update();
      return;
    }
    var comments = data["comments"];
    pages = int.parse(comments["pages"].toString());
    limit = int.parse(comments["limit"].toString());
    total = int.parse(comments["total"].toString());
    var docs = comments["docs"] ?? [];
    var newItems = <LeaveMsgItem>[];
    if (page == 1) {
      for (var doc in (data["topComments"] ?? [])) {
        newItems.add(LeaveMsgItem(parseLeaveMsgComment(doc), null));
      }
    }
    for (int i = 0; i < docs.length; i++) {
      // 与picacg-qt一致: 楼层 = total - ((page - 1) * limit + index)
      newItems.add(LeaveMsgItem(parseLeaveMsgComment(docs[i]),
          total - ((page - 1) * limit + i)));
    }
    if (toEnd) {
      items.addAll(newItems);
    } else {
      items = newItems;
    }
    this.page = page;
    isLoading = false;
    update();
  }

  /// 跳转到指定页并重新加载
  void jumpTo(int page) {
    if (loading) {
      return;
    }
    if (page < 1) {
      page = 1;
    }
    if (pages > 0 && page > pages) {
      page = pages;
    }
    isLoading = true;
    update();
    loadPage(page);
  }
}

class PicacgLeaveMsgPage extends StatelessWidget {
  const PicacgLeaveMsgPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("留言板".tl),
      ),
      body: StateBuilder<PicacgLeaveMsgPageLogic>(
        init: PicacgLeaveMsgPageLogic(),
        builder: (logic) {
          if (logic.isLoading) {
            if (!logic.started) {
              logic.started = true;
              logic.loadPage(1);
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (logic.items.isEmpty) {
            return NetworkError(
              message: "网络错误".tl,
              retry: () => logic.jumpTo(1),
              withAppbar: false,
            );
          } else {
            return Column(
              children: [
                // 分页栏(顶部)
                buildPaginationBar(context, logic),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverList(
                          delegate: SliverChildBuilderDelegate(
                              childCount: logic.items.length,
                              (context, index) {
                        if (index == logic.items.length - 1 &&
                            logic.page < logic.pages) {
                          logic.loadPage(logic.page + 1, toEnd: true);
                        }
                        var comment = logic.items[index].comment;
                        var floor = logic.items[index].floor;
                        var subInfo = floor == null
                            ? "置顶".tl
                            : "$floor${"楼".tl}";
                        subInfo =
                            "$subInfo  ${formatLeaveMsgTime(comment.time)}";
                        return CommentTile(
                          avatarUrl: comment.avatarUrl,
                          frameUrl: comment.frame,
                          name: comment.name,
                          content: comment.text,
                          slogan: comment.slogan,
                          level: comment.level,
                          time: subInfo,
                          like: () {
                            network.likeOrUnlikeComment(comment.id);
                            comment.isLiked = !comment.isLiked;
                            comment.isLiked
                                ? comment.likes++
                                : comment.likes--;
                            logic.update();
                          },
                          likes: comment.likes,
                          liked: comment.isLiked,
                          comments: comment.reply,
                          onTap: () =>
                              showReply(context, comment.id, comment),
                        );
                      })),
                      if (logic.page < logic.pages)
                        const SliverToBoxAdapter(
                          child: ListLoadingIndicator(),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(App.globalContext!).padding.bottom),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 分页栏(底部)
                      buildPaginationBar(context, logic),
                      // 留言输入框
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                        child: Material(
                          child: Container(
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(160),
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(30))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 10, 10, 10),
                                    child: TextField(
                                      controller: logic.controller,
                                      decoration: InputDecoration(
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                          hintText: "留言".tl),
                                      minLines: 1,
                                      maxLines: 5,
                                    ),
                                  ),
                                ),
                                logic.sending
                                    ? const Padding(
                                        padding: EdgeInsets.all(8.5),
                                        child: SizedBox(
                                          width: 23,
                                          height: 23,
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: () async {
                                          if (logic.controller.text.length < 2) {
                                            showToast(
                                                message: "评论至少需要2个字".tl);
                                            return;
                                          }
                                          logic.sending = true;
                                          logic.update();
                                          var b = await network.comment(
                                              kLeaveMsgId,
                                              logic.controller.text,
                                              false);
                                          if (b) {
                                            logic.controller.text = "";
                                            logic.sending = false;
                                            // 发送成功后重新加载第一页, 与picacg-qt一致
                                            logic.jumpTo(1);
                                          } else {
                                            showToast(message: "网络错误".tl);
                                            logic.sending = false;
                                            logic.update();
                                          }
                                        },
                                        icon: Icon(
                                          Icons.send,
                                          color: Theme.of(
                                                  context)
                                              .colorScheme
                                              .secondary,
                                        ))
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom))
              ],
            );
          }
        },
      ),
    );
  }

  /// 分页栏, 与历史记录页的分页样式一致
  Widget buildPaginationBar(
      BuildContext context, PicacgLeaveMsgPageLogic logic) {
    return Row(
      children: [
        FilledButton(
          onPressed: logic.page > 1
              ? () => logic.jumpTo(logic.page - 1)
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
                        text: logic.page.toString(),
                      );
                      return ContentDialog(
                        title: "输入页码".tl,
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "页码".tl,
                            hintText: "1-${logic.pages}",
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ).paddingHorizontal(16),
                        actions: [
                          Button.filled(
                            onPressed: () {
                              final p = int.tryParse(controller.text);
                              if (p != null && p >= 1 && p <= logic.pages) {
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
                    logic.jumpTo(page);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Text("${"页面".tl} ${logic.page} / ${logic.pages}"),
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: logic.page < logic.pages
              ? () => logic.jumpTo(logic.page + 1)
              : null,
          child: Text("前进".tl),
        ).fixWidth(84),
      ],
    ).paddingVertical(8).paddingHorizontal(16);
  }
}
