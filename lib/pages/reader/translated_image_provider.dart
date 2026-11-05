part of 'comic_reading_page.dart';

/// Loads a page through PicaComic's original image stream, then resolves its
/// translated variant. The original bytes are shown while translation runs.
class TranslatedImageProvider
    extends BaseImageProvider<TranslatedImageProvider> {
  const TranslatedImageProvider(
    this.streamBuilder,
    this.imageKey,
    this.sourceKey,
    this.cid,
    this.eid,
    this.page,
    this.translationKey,
    this.legacyTranslationKey,
    this.translationConfig,
    this.translated, {
    this.comicTitle = '',
    this.comicCover = '',
    this.chapterTitle = '',
  });

  final Stream<DownloadProgress> Function() streamBuilder;
  final String imageKey;
  final String sourceKey;
  final String cid;
  final String eid;
  final int page;
  final String translationKey;
  final String legacyTranslationKey;
  final TranslationConfig translationConfig;
  final bool translated;
  final String comicTitle;
  final String comicCover;
  final String chapterTitle;

  @override
  Future<Uint8List> load(StreamController<ImageChunkEvent> chunkEvents) async {
    DownloadProgress? finishProgress;
    await for (var progress in streamBuilder()) {
      if (progress.currentBytes == progress.expectedBytes) {
        finishProgress = progress;
      }
      chunkEvents.add(ImageChunkEvent(
        cumulativeBytesLoaded: progress.currentBytes,
        expectedTotalBytes: progress.expectedBytes,
      ));
    }
    if (finishProgress == null) {
      throw StateError('Empty image response');
    }
    var imageBytes =
        finishProgress.data ?? await finishProgress.getFile().readAsBytes();

    var service = ImageTranslationService.instance;
    var translatedFile =
        await service.findTranslated(translationKey, translationConfig.mode);
    if (translatedFile != null) {
      service.markTranslated(translationKey, translationConfig.mode);
      return translatedFile.readAsBytes();
    }

    var chapter = ImageTranslationService.chapterIdentity(
      cid: cid,
      sourceKey: sourceKey,
      eid: eid,
      config: translationConfig,
      comicTitle: comicTitle,
      comicCover: comicCover,
      chapterTitle: chapterTitle,
    );
    var rendered = await service.renderStoredPage(
      translationKey,
      imageBytes,
      translationConfig.mode,
      chapter: chapter,
      legacyCacheKey: legacyTranslationKey,
    );
    if (rendered != null) {
      return rendered;
    }

    if (ImageTranslationService.isReadyForLang(translationConfig.sourceLang)) {
      service.schedule(
        translationKey,
        cid,
        sourceKey,
        imageBytes,
        translationConfig,
        () => ImageTranslationService.evictImage(this),
        chapter: chapter,
        legacyCacheKey: legacyTranslationKey,
      );
    }
    return imageBytes;
  }

  @override
  Future<TranslatedImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }

  @override
  String get key =>
      '$imageKey@$translationKey#${translationConfig.mode.token}@tr:$translated';
}
