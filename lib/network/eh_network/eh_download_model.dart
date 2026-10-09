import 'dart:async';
import 'dart:isolate';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart' show showToast;
import 'package:pica_comic/foundation/comic_source/comic_source.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/network/eh_network/eh_models.dart';
import 'package:pica_comic/network/download_model.dart';
import 'package:pica_comic/foundation/image_manager.dart';
import 'package:pica_comic/network/file_downloader.dart';
import 'package:pica_comic/network/http_client.dart';
import 'dart:io';
import '../../utils/io_tools.dart';
import '../download.dart';
import 'eh_main_network.dart';
import 'get_gallery_id.dart';
import 'package:pica_comic/utils/zip_utils.dart';
import 'package:pica_comic/utils/translations.dart';

class DownloadedGallery extends DownloadedItem{
  Gallery gallery;
  double? size;
  DownloadedGallery(this.gallery,this.size);

  @override
  Map<String, dynamic> toJson()=>{
    "gallery": gallery.toJson(),
    "size": size
  };
  DownloadedGallery.fromJson(Map<String, dynamic> map):
        gallery = Gallery.fromJson(map["gallery"]),
        size = map["size"];

  @override
  DownloadType get type => DownloadType.ehentai;

  @override
  List<int> get downloadedEps => [0];

  @override
  List<String> get eps => ["EP 1"];

  @override
  String get name {
    if(appdata.settings[78] == "1"){
      return gallery.subTitle ?? gallery.title;
    } else {
      return gallery.title;
    }
  }

  @override
  String get id => getGalleryId(gallery.link);

  @override
  String get subTitle => gallery.uploader;

  @override
  double? get comicSize => size;

  @override
  set comicSize(double? value) {
    size = value;
  }

  List<String> _getTags(){
    var res = <String>[];
    gallery.tags.forEach((key, value) => value.forEach((element) => res.add(element)));
    return res;
  }

  @override
  List<String> get tags => _getTags();
}

///e-hentai的下载进程模型
class EhDownloadingItem extends DownloadingItem{
  EhDownloadingItem(
      this.gallery,
      super.whenFinish,
      super.onError,
      super.updateInfo,
      super.id,
      this.downloadType,
      {super.type = DownloadType.ehentai}
  );

  ///画廊模型
  final Gallery gallery;

  final int downloadType;

  @override
  Map<String, String> get headers => {
    "Cookie": EhNetwork().cookiesStr,
    "User-Agent": webUA,
    "Referer": EhNetwork().ehBaseUrl,
  };

  @override
  String get cover => gallery.coverPath.replaceFirst('s.exhentai.org', 'ehgt.org');

  @override
  String get title => gallery.title;

  @override
  Future<Map<int, List<String>>> getLinks() async{
    return {
      0: List.generate((int.parse(gallery.maxPage)), (index) => (index+1).toString())
    };
  }

  @override
  Future<Stream<DownloadProgress>> downloadImage(String link) async {
    return ImageManager().getEhImageNew(gallery, int.parse(link));
  }

  @override
  Map<String, dynamic> toMap() => {
    "gallery": gallery.toJson(),
    "downloadType": downloadType,
    "_downloadLink": _downloadLink,
    "_currentBytes": _currentBytes,
    "_totalBytes": _totalBytes,
    ...super.toBaseMap()
  };

  @override
  Future<void> onStart() async{
    await super.onStart();
  }

  @override
  Future<void> downloadCover() async {
    final file = File('$path/cover.jpg');
    if (file.existsSync()) return;
    final source = ComicSource.find('ehentai');
    if (source == null || source.isBuiltIn) {
      throw '请先添加对应漫画源'.tl;
    }
    DownloadProgress? result;
    await for (final progress
        in ImageManager().getCustomThumbnail(cover, source.key, {})) {
      if (progress.finished) result = progress;
    }
    if (result == null) throw StateError('Cover download did not complete');
    final bytes = result.data ?? await result.getFile().readAsBytes();
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  int? _currentBytes;

  int? _totalBytes;

  @override
  int get totalPages {
    if(downloadType == 0){
      return super.totalPages;
    } else {
      return _totalBytes ?? 1;
    }
  }

  @override
  int get downloadedPages {
    if(downloadType == 0){
      return super.downloadedPages;
    } else {
      return _currentBytes ?? 0;
    }
  }

  _IsolateDownloader? _downloader;

  bool _stop = false;
  int _generation = 0;

  String? _downloadLink;

  int _currentSpeed = 0;

  @override
  int get currentSpeed => downloadType == 0
      ? super.currentSpeed
      : _currentSpeed;

  @override
  start() async{
    if(downloadType == 0){
      return super.start();
    } else {
      final generation = ++_generation;
      _stop = false;
      await Future<void>.value();
      if (_stop || generation != _generation) return;
      try{
        final source = ComicSource.find('ehentai');
        if (source == null || source.isBuiltIn) {
          throw '请先添加对应漫画源'.tl;
        }
        final archive = source.archiveDownloader;
        if (archive == null) throw '漫画源不支持归档下载'.tl;
        await onStart();
        if (_stop || generation != _generation) return;
        await downloadCover();
        if (_stop || generation != _generation) return;
        if(_downloadLink == null) {
          final options = await archive.getArchives(gallery.link);
          if (_stop || generation != _generation) return;
          if (options.error) throw options.errorMessageWithoutNull;
          final archiveId = (downloadType - 1).toString();
          if (!options.data.any((item) => item.id == archiveId)) {
            throw '漫画源未提供旧任务选定的归档类型'.tl;
          }
          final res = await archive.getDownloadUrl(gallery.link, archiveId);
          if (_stop || generation != _generation) {
            return;
          }
          if (res.error) {
            throw res.errorMessage!;
          }
          _downloadLink = res.data;
        }
        if (!identical(source, ComicSource.find('ehentai'))) {
          throw '请先添加对应漫画源'.tl;
        }
        _downloader = _IsolateDownloader(
            _downloadLink!,
            path,
            (current, total, speed){
              if (_stop || generation != _generation) return;
              _currentBytes = current;
              _totalBytes = total;
              _currentSpeed = speed;
              updateInfo?.call();
              if(current == total){
                if (DownloadManager().downloading.firstOrNull != this) return;
                finish();
              }
            },
            onError!
        );
        _downloader!.start();
      }
      catch(e, s){
        if (_stop || generation != _generation) return;
        log("$e\n$s", "Download", LogLevel.error);
        showToast(message: e.toString());
        onError?.call();
        return;
      }
    }
  }

  void finish() async{
    onFinish?.call();
  }

  @override
  pause() async{
    if(downloadType == 0){
      return super.pause();
    } else {
      _stop = true;
      _generation++;
      _downloader?.pause();
      _downloader = null;
    }
  }

  @override
  stop() async{
    if(downloadType == 0){
      return super.stop();
    } else {
      _stop = true;
      _generation++;
      _downloader?.stop();
      var directory = Directory(path);
      if(await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  EhDownloadingItem.fromMap(
      Map<String, dynamic> map,
      DownloadProgressCallback whenFinish,
      DownloadProgressCallback whenError,
      DownloadProgressCallbackAsync updateInfo,
      String id
      ):gallery=Gallery.fromJson(map["gallery"]),
        downloadType = map["downloadType"],
        _currentBytes = map["_currentBytes"],
        _totalBytes = map["_totalBytes"],
        _downloadLink = map["_downloadLink"],
        super.fromMap(map, whenFinish, whenError, updateInfo);

  @override
  FutureOr<DownloadedItem> toDownloadedItem() async {
    return DownloadedGallery(gallery, await getFolderSize(Directory(path)));
  }
}

class _IsolateDownloader{
  final String url;

  final String savePath;

  late ReceivePort port;

  SendPort? sendPort;
  bool _stopped = false;

  final void Function(int current, int total, int speed) updateInfo;

  final void Function() onError;

  _IsolateDownloader(this.url, this.savePath, this.updateInfo,
      this.onError);

  Isolate? isolate;

  void stop(){
    _stopped = true;
    if (sendPort != null) {
      sendPort!.send("stop");
      isolate = null;
      port.close();
    }
  }

  void pause(){
    stop();
  }

  void start() async{
    port = ReceivePort();
    isolate = await Isolate.spawn<_DownloadData>(run, _DownloadData(
        port.sendPort, url, savePath, await getProxy()));
    var total = 0;
    port.listen((message) {
      if(message is SendPort){
        sendPort = message;
        if (_stopped) stop();
      } else if(message is DownloadingStatus){
        if (_stopped) return;
        updateInfo(message.downloadedBytes, message.totalBytes+1, message.bytesPerSecond);
        total = message.totalBytes;
      } else if(message == "finish"){
        isolate?.kill(priority: Isolate.immediate);
        isolate = null;
        updateInfo(total+1, total+1, 0);
      } else if(message is _DownloadException){
        isolate?.kill(priority: Isolate.immediate);
        isolate = null;
        LogManager.addLog(LogLevel.error, "Download", message.message);
        onError();
      }
    });
  }

  static void run(_DownloadData data) async{
    var receivePort = ReceivePort();

    final sendPort = data.port;

    sendPort.send(receivePort.sendPort);

    final url = data.url;

    final savePath = data.savePath;

    FileDownloader? task;

    receivePort.listen((message) {
      if(message == "stop"){
        task?.stop().then((value) => Isolate.current.kill());
      }
    });

    Future.sync(() async{
      task = FileDownloader(url, "$savePath/temp.zip", data.proxy);

      try {
        await for (var status in task!.start()) {
          sendPort.send(status);
        }
        await extractZipFile("$savePath/temp.zip", savePath);
        var files = Directory(savePath).listSync();
        files.sort((a, b) => a.path.compareTo(b.path));
        int index = 0;
        for(var entry in Directory(savePath).listSync()){
          if(entry is File){
            var name = entry.path.split(pathSep).last;
            if(name.endsWith(".zip")){
              entry.deleteSync();
            } else if(!name.contains("cover")){
              var baseName = index.toString();
              index++;
              var ext = name.split(".").last;
              entry.renameSync("$savePath/$baseName.$ext");
            }
          }
        }
        sendPort.send("finish");
      }
      catch(e, s){
        sendPort.send(_DownloadException("$e\n$s"));
      }
    });
  }
}

class _DownloadData{
  final SendPort port;
  final String url;
  final String savePath;
  final String? proxy;

  const _DownloadData(this.port, this.url, this.savePath,
      this.proxy);
}

class _DownloadException{
  final String message;

  const _DownloadException(this.message);
}
