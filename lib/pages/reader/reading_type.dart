part of 'comic_reading_page.dart';

typedef ReadingType = ComicType;

enum ReadingMethod {
  leftToRight,
  rightToLeft,
  topToBottom,
  topToBottomContinuously,
  twoPage,
  twoPageReversed;

  bool get isTwoPage => this == ReadingMethod.twoPage
      || this == ReadingMethod.twoPageReversed;

  bool get useComicImage => this == ReadingMethod.topToBottomContinuously ||
      this == ReadingMethod.twoPage || this == ReadingMethod.twoPageReversed;
}