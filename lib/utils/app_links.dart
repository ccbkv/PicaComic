import 'dart:convert';

import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/js_engine.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/translations.dart';
import '../foundation/app.dart';
import '../pages/comic_page.dart';

bool canHandle(String text){
  if(!text.isURL){
    return false;
  }
  var uri = Uri.parse(text);

  const acceptedHosts = ["e-hentai.org", "exhentai.org", "nhentai.net", "nhentai.xxx", "hitomi.la"];

  return acceptedHosts.contains(uri.host);
}

bool handleAppLinks(Uri uri, {bool showMessageWhenError = true}){
  LogManager.addLog(LogLevel.info, "App Link", "Open Link $uri");
  var context = App.mainNavigatorKey?.currentContext ?? App.globalContext!;
  switch(uri.host){
    case "e-hentai.org":
    case "exhentai.org":
    case "nhentai.net":
    case "nhentai.xxx":
    case "hitomi.la":
      final isEh = uri.host == 'e-hentai.org' || uri.host == 'exhentai.org';
      final isHitomi = uri.host == 'hitomi.la';
      final match = (isEh
          ? RegExp(r'^/g/(\d+)/(\w+)/?$')
          : isHitomi
          ? RegExp(r'^/(?:doujinshi|cg|manga|artistcg|gamecg|imageset|anime|galleries)/[^/]*?(\d+)\.html$')
          : RegExp(r'^/g/(\d+)(?:/|$)')).firstMatch(uri.path);
      if (match == null) return false;
      final sourceKey = isEh ? 'ehentai' : isHitomi ? 'hitomi' : 'nhentai';
      final source = ComicSource.find(sourceKey);
      if (source == null || source.isBuiltIn) {
        showToast(message: '请先添加对应漫画源'.tl);
        // The link is recognized: keep WebViews from falling through to it.
        return true;
      }
      String? id = isEh
          ? 'https://${uri.host}/g/${match[1]}/${match[2]}/'
          : match[1];
      if (!source.isBuiltIn) {
        try {
          id = JsEngine().runCode("""
            (() => {
              const link = ComicSource.sources[${jsonEncode(sourceKey)}]?.comic?.link;
              return typeof link?.linkToId === 'function'
                ? link.linkToId(${jsonEncode('https://${uri.host}${uri.path}')})
                : ${jsonEncode(id)};
            })()
          """) as String?;
        } catch (e) {
          Log.error(sourceKey, 'Failed to handle comic link: $e');
          if (showMessageWhenError) showToast(message: e.toString());
          return false;
        }
      }
      if (id == null || id.isEmpty) return false;
      final comicId = id;
      context.to(() => ComicPage(sourceKey: sourceKey, id: comicId));
    default:
      return false;
  }
  return true;
}
