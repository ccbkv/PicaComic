import 'package:pica_comic/tools/ext.dart';

enum ImageFavoriteSortType {
  title('按标题'),
  timeAsc('按时间升序'),
  timeDesc('按时间降序'),
  maxFavorites('按收藏数量'),
  favoritesCompareComicPages('收藏数比上总页数');

  const ImageFavoriteSortType(this.value);

  final String value;

  String get tl => value;
  
  String get displayName => value;
}

enum TimeRangeType {
  all('全部'),
  lastWeek('最近一周'),
  lastMonth('最近一个月'),
  lastHalfYear('最近半年'),
  lastYear('最近一年'),
  custom('自定义');

  const TimeRangeType(this.value);

  final String value;

  String get tl => value;
  
  String get displayName => value;
}

class TimeRange {
  static const TimeRange all = TimeRange._all();
  static const TimeRange lastWeek = TimeRange._lastWeek();
  static const TimeRange lastMonth = TimeRange._lastMonth();
  static const TimeRange lastHalfYear = TimeRange._lastHalfYear();
  static const TimeRange lastYear = TimeRange._lastYear();

  final DateTime? end;
  final Duration? duration;
  
  TimeRangeType get type {
    if (this == all) return TimeRangeType.all;
    if (this == lastWeek) return TimeRangeType.lastWeek;
    if (this == lastMonth) return TimeRangeType.lastMonth;
    if (this == lastHalfYear) return TimeRangeType.lastHalfYear;
    if (this == lastYear) return TimeRangeType.lastYear;
    return TimeRangeType.custom;
  }

  const TimeRange._all()
      : end = null,
        duration = null;

  const TimeRange._lastWeek()
      : end = null,
        duration = const Duration(days: 7);

  const TimeRange._lastMonth()
      : end = null,
        duration = const Duration(days: 30);

  const TimeRange._lastHalfYear()
      : end = null,
        duration = const Duration(days: 180);

  const TimeRange._lastYear()
      : end = null,
        duration = const Duration(days: 365);

  const TimeRange({this.end, this.duration});

  bool contains(DateTime time) {
    if (this == all) return true;
    
    final now = DateTime.now();
    final startTime = end != null 
        ? end!.subtract(duration!)
        : now.subtract(duration!);
    
    return time.isAfter(startTime) && time.isBefore(now);
  }

  static TimeRange fromString(String? str) {
    if (str == null) return all;
    
    switch (str) {
      case 'all':
        return all;
      case 'lastWeek':
        return lastWeek;
      case 'lastMonth':
        return lastMonth;
      case 'lastHalfYear':
        return lastHalfYear;
      case 'lastYear':
        return lastYear;
      default:
        return all;
    }
  }

  @override
  String toString() {
    if (this == all) return 'all';
    if (this == lastWeek) return 'lastWeek';
    if (this == lastMonth) return 'lastMonth';
    if (this == lastHalfYear) return 'lastHalfYear';
    if (this == lastYear) return 'lastYear';
    return 'custom';
  }
  
  static TimeRange fromType(TimeRangeType type) {
    switch (type) {
      case TimeRangeType.all:
        return all;
      case TimeRangeType.lastWeek:
        return lastWeek;
      case TimeRangeType.lastMonth:
        return lastMonth;
      case TimeRangeType.lastHalfYear:
        return lastHalfYear;
      case TimeRangeType.lastYear:
        return lastYear;
      case TimeRangeType.custom:
        return all;
    }
  }
}

const List<int> numFilterList = [0, 1, 5, 10, 20, 50, 100];