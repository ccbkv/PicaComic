import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:flutter/material.dart';
import 'package:pica_comic/utils/translations.dart';
import '../../network/base_comic.dart';
import '../../network/eh_network/eh_main_network.dart';
import '../../network/eh_network/eh_models.dart';
import '../../network/res.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  @override
  Widget build(BuildContext context) {
    final source = ComicSource.find('ehentai');
    ComicListBuilder? watchedLoader;
    if (source != null && !source.isBuiltIn) {
      for (final page in source.explorePages) {
        if (page.title == 'Eh观看') {
          watchedLoader = page.loadPage;
          break;
        }
      }
    }
    return Scaffold(
      appBar: Appbar(title: Text("EH订阅".tl), actions: [
        Tooltip(
          message: "更多".tl,
          child: IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: (){
              showConfirmDialog(
                context: context,
                title: "订阅".tl,
                content: "请在网页端管理订阅".tl,
                onConfirm: (){},
                confirmText: "返回",
              );
            },
          ),
        )
      ],),
      body: source == null
          ? Center(child: Text('请先添加EH漫画源'.tl))
          : source.isBuiltIn
              ? EhSubscriptionComics()
              : watchedLoader == null
                  ? Center(child: Text('当前EH脚本未提供订阅入口（Eh观看）'.tl))
                  : _ScriptSubscriptionComics(watchedLoader),
    );
  }
}

class _ScriptSubscriptionComics extends ComicsPage<BaseComic> {
  const _ScriptSubscriptionComics(this.loader);

  final ComicListBuilder loader;

  @override
  Future<Res<List<BaseComic>>> getComics(int i) => loader(i);

  @override
  String get tag => 'EhScriptSubscriptionPage';

  @override
  String? get title => null;

  @override
  String get sourceKey => 'ehentai';
}


class PageData{
  Galleries? galleries;
  int page = 1;
  Map<int, List<EhGalleryBrief>> comics = {};
}

class EhSubscriptionComics extends ComicsPage<EhGalleryBrief>{
  EhSubscriptionComics({super.key});

  final data = PageData();

  @override
  Future<Res<List<EhGalleryBrief>>> getComics(int i) async{
    if(data.galleries == null){
      Res<Galleries> res = await EhNetwork().getGalleries("${EhNetwork().ehBaseUrl}/watched");
      if(res.error){
        return Res(null, errorMessage: res.errorMessage);
      }else{
        data.galleries = res.data;
        data.comics[1] = [];
        data.comics[1]!.addAll(data.galleries!.galleries);
        data.galleries!.galleries.clear();
      }
    }
    if(data.comics[i] != null){
      return Res(data.comics[i]!);
    }else{
      while(data.comics[i] == null){
        data.page++;
        if(! await EhNetwork().getNextPageGalleries(data.galleries!)){
          return const Res(null, errorMessage: "网络错误");
        }
        data.comics[data.page] = [];
        data.comics[data.page]!.addAll(data.galleries!.galleries);
        data.galleries!.galleries.clear();
      }
      return Res(data.comics[i]);
    }
  }

  @override
  String? get tag => "EhSubscriptionPage";

  @override
  String? get title => null;

  @override
  String get sourceKey => 'ehentai';
}
