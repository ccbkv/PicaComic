part of 'comic_reading_page.dart';

extension ScrollExtension on ScrollController {
  static double? futurePosition;

  void smoothTo(double value) {
    futurePosition ??= position.pixels;
    futurePosition = futurePosition! + value * 1.2;
    futurePosition = futurePosition!
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    animateTo(futurePosition!,
        duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }
}

const Set<PointerDeviceKind> _kTouchLikeDeviceTypes = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown
};

extension ImageExt on ComicReadingPage {
  /// build comic image
  Widget buildComicView(
      ComicReadingPageLogic logic, BuildContext context, String target) {
    ScrollExtension.futurePosition = null;
    Widget buildType4() {
      final showChapterTransitionPage = _shouldShowChapterTransitionPage(logic);
      return ScrollablePositionedList.builder(
        itemScrollController: logic.itemScrollController,
        itemPositionsListener: logic.itemScrollListener,
        itemCount: logic.urls.length + (showChapterTransitionPage ? 1 : 0),
        addSemanticIndexes: false,
        scrollController: logic.scrollController,
        scrollBehavior: const MaterialScrollBehavior()
            .copyWith(scrollbars: false, dragDevices: _kTouchLikeDeviceTypes),
        physics: (logic.noScroll || logic.isCtrlPressed || logic.mouseScroll)
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
        itemBuilder: (context, index) {
          if (showChapterTransitionPage && index == logic.urls.length) {
            return _ChapterTransitionPage(
              comicTitle: readingData.title,
              currentChapterTitle:
                  readingData.eps?.values.elementAtOrNull(logic.order - 1) ??
                      "",
              nextChapterTitle:
                  readingData.eps?.values.elementAtOrNull(logic.order) ?? "",
              useDarkBackground: useDarkBackground,
            );
          }

          double width = MediaQuery.of(context).size.width;
          double height = MediaQuery.of(context).size.height;

          double imageWidth = width;

          if (height / width < 1.2 && appdata.settings[43] == "1") {
            imageWidth = height / 1.2;
          }

          precacheComicImage(logic, context, index + 1, target);

          ImageProvider image = createImageProvider(type, logic, index, target);
          return ComicImage(
            filterQuality: FilterQuality.medium,
            image: image,
            width: imageWidth,
            height: imageWidth * 1.2,
            fit: BoxFit.cover,
          );
        },
      );
    }

    final decoration = BoxDecoration(
      color: useDarkBackground
          ? Colors.black
          : Theme.of(context).colorScheme.surface,
    );

    Widget buildType123() {
      final showCommentsAtEnd = _shouldShowChapterCommentsAtEnd();
      final extraPage = showCommentsAtEnd ? 1 : 0;
      return PhotoViewGallery.builder(
        backgroundDecoration: decoration,
        key: Key('${logic.readingMethod.index}_$showCommentsAtEnd'),
        reverse: appdata.settings[9] == "2",
        scrollDirection:
            appdata.settings[9] != "3" ? Axis.horizontal : Axis.vertical,
        itemCount: logic.urls.length + 2 + extraPage,
        builder: (BuildContext context, int index) {
          ImageProvider? imageProvider;
          if (index != 0 && index != logic.urls.length + 1 + extraPage) {
            if (showCommentsAtEnd && index == logic.urls.length + 1) {
              var source = ComicSource.find(readingData.sourceKey);
              var epId = readingData.eps!.keys.elementAt(logic.order - 1);
              var chapterTitle =
                  readingData.eps!.values.elementAt(logic.order - 1);
              return PhotoViewGalleryPageOptions.customChild(
                scaleStateController: PhotoViewScaleStateController(),
                child: _EmbeddedChapterCommentsPage(
                  comicId: readingData.id,
                  epId: epId,
                  source: source!,
                  comicTitle: readingData.title,
                  chapterTitle: chapterTitle,
                ),
              );
            }
            imageProvider = createImageProvider(type, logic, index - 1, target);
          } else {
            return PhotoViewGalleryPageOptions.customChild(
              scaleStateController: PhotoViewScaleStateController(),
              child: const SizedBox(),
            );
          }

          precacheComicImage(logic, context, index, target);

          BoxFit getFit() {
            switch (appdata.settings[41]) {
              case "1":
                return BoxFit.fitWidth;
              case "2":
                return BoxFit.fitHeight;
              default:
                return BoxFit.contain;
            }
          }

          logic.photoViewControllers[index] ??= PhotoViewController();

          return PhotoViewGalleryPageOptions(
            filterQuality: FilterQuality.medium,
            imageProvider: imageProvider,
            fit: getFit(),
            controller: logic.photoViewControllers[index],
            errorBuilder: (_, error, s, retry) {
              return Center(
                child: SizedBox(
                  height: 300,
                  width: 400,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            error.toString(),
                            style: TextStyle(
                                color: appdata.appSettings.useDarkBackground
                                    ? Colors.white
                                    : null),
                            maxLines: 3,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Listener(
                          onPointerDown: (details) {
                            TapController.ignoreNextTap = true;
                            retry();
                          },
                          child: const SizedBox(
                            width: 84,
                            height: 36,
                            child: Center(
                              child: Text(
                                "Retry",
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                    ],
                  ),
                ),
              );
            },
            heroAttributes:
                PhotoViewHeroAttributes(tag: "$index/${logic.urls.length}"),
          );
        },
        pageController: logic.pageController,
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              backgroundColor: context.colorScheme.surfaceContainerHigh,
              value: event == null || event.expectedTotalBytes == null
                  ? null
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        onPageChanged: (i) {
          if (i == 0) {
            if (!logic.data.hasEp) {
              logic.jumpByDeviceType(1);
              return;
            }
            logic.jumpToLastChapter();
          } else if (i == logic.urls.length + 1 + extraPage) {
            if (!logic.data.hasEp) {
              logic.jumpByDeviceType(i - 1);
              return;
            }
            logic.jumpToNextChapter();
          } else {
            logic.index = i;
            logic.isOnChapterCommentsPage =
                showCommentsAtEnd && i == logic.urls.length + 1;
            logic.update();
          }
        },
      );
    }

    Widget buildComicImageOrEmpty(
        {required int imageIndex,
        required BoxFit fit,
        required Alignment alignment}) {
      if (imageIndex < 0 || imageIndex >= logic.urls.length) {
        return const SizedBox();
      }

      return ComicImage(
        key: ValueKey(imageIndex),
        image: createImageProvider(type, logic, imageIndex, target),
        fit: fit,
        alignment: alignment,
      );
    }

    Widget buildType56() {
      int calcItemCount() {
        int count = logic.urls.length ~/ 2;
        if (logic.urls.length % 2 != 0) {
          count++;
        } else if (logic.singlePageForFirstScreen) {
          count++;
        }
        return count + 2;
      }

      return PhotoViewGallery.builder(
        key: Key(logic.readingMethod.index.toString()),
        backgroundDecoration: decoration,
        itemCount: calcItemCount(),
        reverse: logic.readingMethod == ReadingMethod.twoPageReversed,
        builder: (BuildContext context, int index) {
          if (index == 0 || index == calcItemCount() - 1) {
            return PhotoViewGalleryPageOptions.customChild(
                child: const SizedBox());
          }
          precacheComicImage(logic, context, index * 2 + 1, target);

          logic.photoViewControllers[index] ??= PhotoViewController();

          int firstImage = index * 2 - 2;
          if (firstImage % 2 != 0) {
            firstImage++;
          }
          if (logic.singlePageForFirstScreen) {
            firstImage--;
          }
          var images = <int>[firstImage, firstImage + 1];
          if (logic.readingMethod == ReadingMethod.twoPageReversed) {
            images = images.reversed.toList();
          }

          return PhotoViewGalleryPageOptions.customChild(
              controller: logic.photoViewControllers[index],
              child: Row(
                children: [
                  Expanded(
                    child: buildComicImageOrEmpty(
                      imageIndex: images[0],
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                  Expanded(
                    child: buildComicImageOrEmpty(
                      imageIndex: images[1],
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ],
              ));
        },
        pageController: logic.pageController,
        onPageChanged: (i) {
          if (i == 0) {
            if (!logic.data.hasEp || logic.order == 1) {
              logic.pageController.jumpByDeviceType(1);
              return;
            }
            logic.jumpToLastChapter();
          } else if (i == calcItemCount() - 1) {
            if (!logic.data.hasEp || logic.order == logic.data.eps?.length) {
              logic.pageController
                  .jumpByDeviceType(logic.pageController.page!.round() - 1);
              return;
            }
            logic.jumpToNextChapter();
          } else {
            logic.index = logic.singlePageForFirstScreen
                ? (i * 2 - 2).clamp(1, logic.urls.length)
                : i * 2 - 1;
            logic.update();
          }
        },
      );
    }

    Widget body;

    if (["1", "2", "3"].contains(appdata.settings[9])) {
      body = buildType123();
    } else if (appdata.settings[9] == "4") {
      logic.photoViewControllers[0] ??= PhotoViewController();
      body = PhotoView.customChild(
          backgroundDecoration: decoration,
          key: Key(logic.order.toString()),
          minScale: 1.0,
          maxScale: 2.5,
          strictScale: true,
          controller: logic.photoViewControllers[0],
          onScaleEnd: (context, detail, value) {
            var prev = logic.currentScale;
            logic.currentScale = value.scale ?? 1.0;
            if ((prev <= 1.05 && logic.currentScale > 1.05) ||
                (prev > 1.05 && logic.currentScale <= 1.05)) {
              logic.update();
            }
            if (appdata.settings[43] != "1") {
              return false;
            }
            return updateLocation(context, logic.photoViewController);
          },
          child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: buildType4()));
    } else {
      body = buildType56();
    }

    void onPointerSignal(PointerSignalEvent pointerSignal) {
      logic.mouseScroll = pointerSignal.kind == PointerDeviceKind.mouse;
      if (pointerSignal is PointerScrollEvent && !logic.isCtrlPressed) {
        if (logic.readingMethod != ReadingMethod.topToBottomContinuously) {
          pointerSignal.scrollDelta.dy > 0
              ? logic.jumpToNextPage()
              : logic.jumpToLastPage();
        } else {
          if (pointerSignal.scrollDelta.dy > 0 && logic.isAtChapterEnd) {
            logic.jumpToNextChapter();
            return;
          }
          if (pointerSignal.scrollDelta.dy < 0 && logic.isAtChapterStart) {
            logic.jumpToLastChapter();
            return;
          }
          if ((logic.scrollController.position.pixels <=
                      logic.scrollController.position.minScrollExtent + 2 &&
                  pointerSignal.scrollDelta.dy < 0) ||
              (logic.scrollController.position.pixels >=
                      logic.scrollController.position.maxScrollExtent - 2 &&
                  pointerSignal.scrollDelta.dy > 0)) {
            logic.photoViewController.updateMultiple(
                position: logic.photoViewController.position -
                    Offset(0, pointerSignal.scrollDelta.dy));
          } else if (!App.isMacOS) {
            logic.scrollController.smoothTo(pointerSignal.scrollDelta.dy);
          }
        }
      }
    }

    return Positioned.fill(
      top: App.isDesktop ? MediaQuery.of(context).padding.top : 0,
      child: Listener(
        onPointerSignal: onPointerSignal,
        onPointerPanZoomUpdate: (event) {
          if (event.kind == PointerDeviceKind.trackpad &&
              logic.readingMethod == ReadingMethod.topToBottomContinuously) {
            if (event.scale == 1.0) {
              if (event.panDelta.dy < 0 && logic.isAtChapterEnd) {
                logic.jumpToNextChapter();
                return;
              }
              if (event.panDelta.dy > 0 && logic.isAtChapterStart) {
                logic.jumpToLastChapter();
                return;
              }
              logic.scrollController.smoothTo(0 - event.panDelta.dy * 1.2);
            }
          }
        },
        onPointerDown: (details) => logic.mouseScroll = false,
        child: NotificationListener<ScrollUpdateNotification>(
          child: body,
          onNotification: (notification) {
            TapController.lastScrollTime = DateTime.now();
            if (!logic.scrollController.hasClients) return false;
            return true;
          },
        ),
      ),
    );
  }

  /// create a image provider
  ImageProvider createImageProvider(
      ReadingType type, ComicReadingPageLogic logic, int index, String target) {
    return logic.data
        .createImageProvider(logic.order, index, logic.urls[index]);
  }

  /// check current location of [PageView], update location when it is out of range.
  bool updateLocation(BuildContext context, PhotoViewController controller) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    if (width / height < 1.2) {
      return false;
    }
    final currentLocation = controller.position;
    final scale = controller.scale ?? 1;
    final imageWidth = height / 1.2;
    final showWidth = width / scale;
    if (showWidth >= imageWidth && currentLocation.dx != 0) {
      controller.updateMultiple(
          position: Offset(controller.initial.position.dx, currentLocation.dy));
      return true;
    }
    if (showWidth < imageWidth) {
      final lEdge = (width - imageWidth) / 2;
      final rEdge = width - lEdge;
      final showLEdge =
          (0 - currentLocation.dx) / scale - showWidth / 2 + width / 2;
      final showREdge =
          (0 - currentLocation.dx) / scale + showWidth / 2 + width / 2;
      final updateValue = (width / 2 - (rEdge - showWidth / 2)) * scale;
      if (lEdge > showLEdge) {
        controller.updateMultiple(
            position: Offset(0 - updateValue, currentLocation.dy));
        return true;
      } else if (rEdge < showREdge) {
        controller.updateMultiple(
            position: Offset(updateValue, currentLocation.dy));
        return true;
      }
    }
    return false;
  }

  /// preload image
  void precacheComicImage(ComicReadingPageLogic logic, BuildContext context,
      int index, String target) {
    if (logic.requestedLoadingItems.length != logic.length) {
      logic.requestedLoadingItems = List.filled(logic.length + 1, false);
    }
    int ahead = int.parse(appdata.settings[28]);
    if (App.isIOS) {
      ahead = ahead.clamp(0, 2);
    }
    int precacheNum = ahead + index;
    for (; index < precacheNum; index++) {
      if (index >= logic.urls.length || logic.requestedLoadingItems[index]) {
        return;
      }
      precacheImage(createImageProvider(type, logic, index, target), context);
      logic.requestedLoadingItems[index] = true;
    }
    if (!ImageManager.haveTask) {
      if (!App.isIOS) {
        precacheNum += 3;
      }
      for (; index < precacheNum; index++) {
        if (index >= logic.urls.length || logic.requestedLoadingItems[index]) {
          return;
        }
        precacheImage(createImageProvider(type, logic, index, target), context);
        logic.requestedLoadingItems[index] = true;
      }
    }
  }

  bool _shouldShowChapterCommentsAtEnd() {
    if (!readingData.hasEp ||
        readingData.eps == null ||
        readingData.eps!.isEmpty) {
      return false;
    }
    var showChapterComments =
        appdata.settings.length > 92 && appdata.settings[92] == "1";
    if (!showChapterComments) return false;
    var showAtEnd = appdata.settings.length > 99 && appdata.settings[99] == "1";
    if (!showAtEnd) return false;
    var source = ComicSource.find(readingData.sourceKey);
    if (source == null || source.chapterCommentsLoader == null) return false;
    var readingMethod =
        ReadingMethod.values[int.parse(appdata.settings[9]) - 1];
    if (readingMethod != ReadingMethod.leftToRight &&
        readingMethod != ReadingMethod.rightToLeft &&
        readingMethod != ReadingMethod.topToBottom) {
      return false;
    }
    return true;
  }

  bool _shouldShowChapterTransitionPage(ComicReadingPageLogic logic) {
    return appdata.settings[9] == "4" &&
        readingData.hasEp &&
        readingData.eps != null &&
        logic.order < readingData.eps!.length;
  }
}

class _ChapterTransitionPage extends StatelessWidget {
  const _ChapterTransitionPage({
    required this.comicTitle,
    required this.currentChapterTitle,
    required this.nextChapterTitle,
    required this.useDarkBackground,
  });

  final String comicTitle;
  final String currentChapterTitle;
  final String nextChapterTitle;
  final bool useDarkBackground;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textColor = useDarkBackground ? Colors.white : null;

    return Container(
      width: size.width,
      height: size.height,
      color: useDarkBackground
          ? Colors.black
          : Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: size.height * 0.22,
          bottom: size.height * 0.14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "已读完:".tl,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "$currentChapterTitle $comicTitle",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.35,
              ),
            ),
            SizedBox(height: size.height * 0.13),
            Text(
              "下一章:".tl,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              nextChapterTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
