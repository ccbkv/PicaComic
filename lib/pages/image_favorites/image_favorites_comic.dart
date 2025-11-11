
import '../../foundation/history.dart';

class ImageFavoritesComic {
  final String id;
  final String title;
  final List<ImageFavorite> images;
  final DateTime time;

  ImageFavoritesComic({
    required this.id,
    required this.title,
    required this.images,
    required this.time,
  });

  /// 从图片收藏列表创建漫画分组
  static List<ImageFavoritesComic> fromFavorites(List<ImageFavorite> favorites) {
    var grouped = <String, List<ImageFavorite>>{};
    
    for (var favorite in favorites) {
      if (!grouped.containsKey(favorite.id)) {
        grouped[favorite.id] = [];
      }
      grouped[favorite.id]!.add(favorite);
    }
    
    return grouped.entries.map((entry) {
      // 获取最新的收藏时间作为漫画的收藏时间
      var latestTime = entry.value
          .map((f) => _getFavoriteTime(f))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      
      return ImageFavoritesComic(
        id: entry.key,
        title: entry.value.first.title,
        images: entry.value,
        time: latestTime,
      );
    }).toList();
  }

  /// 从otherInfo中获取收藏时间
  static DateTime _getFavoriteTime(ImageFavorite favorite) {
    if (favorite.otherInfo.containsKey('favoriteTime')) {
      var timeStr = favorite.otherInfo['favoriteTime'];
      if (timeStr is String) {
        return DateTime.parse(timeStr);
      }
    }
    
    // 如果没有收藏时间，使用当前时间
    return DateTime.now();
  }

  /// 获取漫画的最大页数（从ep信息中推断）
  int get maxPageFromEp {
    if (images.isEmpty) return 0;
    
    // 从otherInfo中获取章节总页数
    var firstImage = images.first;
    if (firstImage.otherInfo.containsKey('epTotalPages')) {
      return firstImage.otherInfo['epTotalPages'] ?? 0;
    }
    
    // 如果没有章节总页数信息，尝试获取最大页数
    if (firstImage.otherInfo.containsKey('maxPages')) {
      return firstImage.otherInfo['maxPages'] ?? 0;
    }
    
    // 如果没有最大页数信息，使用当前收藏的最大页数
    return images.map((img) => img.page).reduce((a, b) => a > b ? a : b);
  }
}