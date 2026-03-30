import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/utils/app_links.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/translations.dart';

import 'ehentai/subscription.dart';
import 'jm/jm_comic_page.dart';
import 'webview.dart';

void openTool(BuildContext context) {
  showSideBar(
    context,
    CustomScrollView(
      slivers: [
        SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: ListTile(
                title: Text("工具".tl),
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.subscriptions),
                title: Text("EH订阅".tl),
                onTap: () {
                  App.globalBack();
                  App.mainNavigatorKey?.currentContext?.to(() => const SubscriptionPage());
                },
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.image_search_outlined),
                title: Text("图片搜索 [搜图bot酱]".tl),
                onTap: () async {
                  App.globalBack();
                  if (App.isLinux) {
                    var webview = DesktopWebview(
                      initialUrl: "https://soutubot.moe/",
                      onNavigation: (s, webview) {
                        if (handleAppLinks(Uri.parse(s),
                            showMessageWhenError: false)) {
                          Future.microtask(() => webview.close());
                        }
                      },
                    );
                    webview.open();
                  } else {
                    await App.mainNavigatorKey?.currentContext?.to(
                      () => AppWebview(
                        initialUrl: "https://soutubot.moe/",
                        onNavigation: (uri, controller) {
                          return handleAppLinks(Uri.parse(uri),
                              showMessageWhenError: false);
                        },
                      ),
                    );
                  }
                },
                trailing: const Icon(Icons.open_in_new)
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.image_search),
                title: Text("图片搜索 [SauceNAO]".tl),
                onTap: () async {
                  App.globalBack();
                  if (App.isLinux) {
                    var webview = DesktopWebview(
                      initialUrl: "https://saucenao.com/",
                      onNavigation: (s, webview) {
                        if (handleAppLinks(Uri.parse(s),
                            showMessageWhenError: false)) {
                          Future.microtask(() => webview.close());
                        }
                      },
                    );
                    webview.open();
                  } else {
                    await App.mainNavigatorKey?.currentContext?.to(
                      () => AppWebview(
                        initialUrl: "https://saucenao.com/",
                        onNavigation: (uri, controller) {
                          return handleAppLinks(Uri.parse(uri),
                              showMessageWhenError: false);
                        },
                      ),
                    );
                  }
                },
                trailing: const Icon(Icons.open_in_new)
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text("打开链接".tl),
                onTap: () {
                  showInputDialog(
                    context: context,
                    title: "输入链接".tl,
                    hintText: "https://",
                    onConfirm: (value) {
                      var text = value;
                      if (text == "") {
                        return "链接不能为空".tl;
                      }
                      if (!text.contains("http://") && !text.contains("https://")) {
                        text = "https://$text";
                      }
                      if (!text.isURL) {
                        return "不支持的链接".tl;
                      }
                      var uri = Uri.parse(text);
                      if (![
                        "exhentai.org",
                        "e-hentai.org",
                        "hitomi.la",
                        "nhentai.net",
                        "nhentai.xxx"
                      ].contains(uri.host)) {
                        return "不支持的链接".tl;
                      }
                      handleAppLinks(Uri.parse(text));
                      return null;
                    },
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.numbers),
                title: Text("禁漫漫画ID".tl),
                onTap: () {
                  showInputDialog(
                    context: context,
                    title: "输入禁漫漫画ID".tl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp("[0-9]"))
                    ],
                    labelText: "ID",
                    prefix: const Text("JM"),
                    onConfirm: (value) {
                      if (value.isEmpty) {
                        return "ID不能为空".tl;
                      }
                      if (!value.isNum) {
                        return "输入的ID不是数字".tl;
                      }
                      // 不调用 App.globalBack()，让 showInputDialog 自己关闭
                      // 也不关闭工具侧边栏，直接导航到新页面
                      App.mainNavigatorKey?.currentContext
                          ?.to(() => JmComicPage(value));
                      return null;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    ),
    title: "工具".tl,
    width: 400,
  );
}
