import 'package:flutter/material.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/network/picacg_network/models.dart';
import 'package:pica_comic/pages/comic_page.dart';
import 'package:pica_comic/pages/picacg/comments_page.dart';
import 'package:pica_comic/tools/translations.dart';

class UserCommentsPageLogic extends StateController {
  bool isLoading = true;
  var comments = UserCommentsResponse([], 0, 0);

  void change() {
    isLoading = !isLoading;
    update();
  }
}

class UserCommentsPage extends StatelessWidget {
  const UserCommentsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("我的评论".tl),
      ),
      body: StateBuilder<UserCommentsPageLogic>(
        init: UserCommentsPageLogic(),
        builder: (logic) {
          if (logic.isLoading) {
            network.getUserComments(1).then((c) {
              if (c.success) {
                logic.comments = c.data;
              }
              logic.change();
            });
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (logic.comments.comments.isEmpty) {
            return NetworkError(
              message: "无评论或网络错误".tl,
              retry: () => logic.change(),
              withAppbar: false,
            );
          } else {
            return CustomScrollView(
              slivers: [
                SliverList(
                    delegate: SliverChildBuilderDelegate(
                        childCount: logic.comments.comments.length,
                        (context, index) {
                  if (index == logic.comments.comments.length - 1 &&
                      logic.comments.page < logic.comments.pages) {
                    network.getUserComments(logic.comments.page + 1).then((t) {
                      if (t.success) {
                        logic.comments.comments.addAll(t.data.comments);
                        logic.comments.page = t.data.page;
                        logic.update();
                      }
                    });
                  }
                  var comment = logic.comments.comments[index];
                  var user = network.user;
                  return UserCommentTile(
                    comment: comment,
                    user: user,
                    index: index,
                    onTap: () {
                      var c = Comment(
                          user?.name ?? "Unknown",
                          user?.avatarUrl ?? "",
                          user?.id ?? "",
                          user?.level ?? 0,
                          comment.content,
                          comment.commentsCount,
                          comment.id,
                          comment.isLiked,
                          comment.likesCount,
                          user?.frameUrl,
                          user?.slogan,
                          comment.time);
                      showReply(context, comment.id, c);
                    },
                    onComicTap: () {
                      App.to(context, () => ComicPage(sourceKey: "picacg", id: comment.comicId));
                    },
                  );
                })),
                if (logic.comments.page < logic.comments.pages)
                  const SliverToBoxAdapter(
                    child: ListLoadingIndicator(),
                  ),
                SliverPadding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(App.globalContext!).padding.bottom))
              ],
            );
          }
        },
      ),
    );
  }
}

class UserCommentTile extends StatelessWidget {
  final UserComment comment;
  final Profile? user;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onComicTap;

  const UserCommentTile({
    Key? key,
    required this.comment,
    required this.user,
    required this.index,
    required this.onTap,
    required this.onComicTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    var subInfo = "${comment.time.substring(0, 10)}  ${comment.time.substring(11, 19)}";

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Avatar(
                      size: 50,
                      avatarUrl: user?.avatarUrl,
                      frame: user?.frameUrl,
                      name: user?.name ?? "Unknown",
                      couldBeShown: true,
                      level: user?.level ?? 0,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            user?.name ?? "Unknown",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "level:${user?.level ?? 0} (${user?.title ?? 'User'})",
                            style: TextStyle(
                              color: theme.tertiary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            comment.content,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 60),
                    Expanded(
                      child: GestureDetector(
                        onTap: onComicTap,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.secondaryContainer,
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Text(
                            comment.comicTitle,
                            style: TextStyle(
                              color: theme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      index.toString(),
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Text(" / "),
                    Text(subInfo, style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: comment.isLiked ? Colors.red : theme.onSurface,
                    ),
                    const SizedBox(width: 2),
                    Text(comment.likesCount.toString(), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 10),
                    const Icon(Icons.comment, size: 14),
                    const SizedBox(width: 2),
                    Text(comment.commentsCount.toString(), style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
        Divider(
          color: theme.outline.withOpacity(0.5),
          thickness: 1,
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}
