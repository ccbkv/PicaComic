import 'dart:async';
import 'package:pica_comic/foundation/local_favorites.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/utils/channel.dart';

class ComicUpdateResult {
  final bool updated;
  final String? errorMessage;

  ComicUpdateResult(this.updated, this.errorMessage);
}

Future<ComicUpdateResult> updateComic(
    FavoriteItemWithUpdateInfo c, String folder) async {
  int retries = 3;
  while (true) {
    try {
      var comicSource = c.type.comicSource;
      if (comicSource == null) {
        return ComicUpdateResult(false, "Comic source not found");
      }
      if (comicSource.loadComicInfo == null) {
        return ComicUpdateResult(false, "Comic source does not support loading comic info");
      }
      var res = await comicSource.loadComicInfo!(c.target);
      if (res.data == null) {
        return ComicUpdateResult(false, "Failed to load comic info");
      }
      var newInfo = res.data!;

      var newTags = <String>[];
      for (var entry in newInfo.tags.entries) {
        const shouldIgnore = ['author', 'artist', 'time'];
        var namespace = entry.key;
        if (shouldIgnore.contains(namespace.toLowerCase())) {
          continue;
        }
        for (var tag in entry.value) {
          newTags.add("$namespace:$tag");
        }
      }

      var item = FavoriteItem(
        target: c.target,
        name: newInfo.title,
        coverPath: newInfo.cover,
        author: newInfo.subTitle ??
            newInfo.tags['author']?.firstOrNull ??
            c.author,
        type: c.type,
        tags: newTags,
      );

      LocalFavoritesManager().updateInfo(folder, item, false);

      var updated = false;
      var updateTime = newInfo.findUpdateTime();
      if (updateTime != null && updateTime != c.updateTime) {
        LocalFavoritesManager().updateUpdateTime(
          folder,
          c.target,
          c.type,
          updateTime,
        );
        updated = true;
      } else {
        LocalFavoritesManager().updateCheckTime(folder, c.target, c.type);
      }
      return ComicUpdateResult(updated, null);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Check Updates", "$e\n$s");
      await Future.delayed(const Duration(seconds: 2));
      retries--;
      if (retries == 0) {
        return ComicUpdateResult(false, e.toString());
      }
    }
  }
}

class UpdateProgress {
  final int total;
  final int current;
  final int errors;
  final int updated;
  final FavoriteItemWithUpdateInfo? comic;
  final String? errorMessage;

  UpdateProgress(this.total, this.current, this.errors, this.updated,
      [this.comic, this.errorMessage]);
}

void updateFolderBase(
  String folder,
  StreamController<UpdateProgress> stream,
  bool ignoreCheckTime,
) async {
  var comics = LocalFavoritesManager().getComicsWithUpdatesInfo(folder);
  int total = comics.length;
  int current = 0;
  int errors = 0;
  int updated = 0;

  stream.add(UpdateProgress(total, current, errors, updated));

  var comicsToUpdate = <FavoriteItemWithUpdateInfo>[];

  for (var comic in comics) {
    if (!ignoreCheckTime) {
      var lastCheckTime = comic.lastCheckTime;
      if (lastCheckTime != null &&
          DateTime.now().difference(lastCheckTime).inDays < 1) {
        current++;
        stream.add(UpdateProgress(total, current, errors, updated));
        continue;
      }
    }
    comicsToUpdate.add(comic);
  }

  total = comicsToUpdate.length;
  current = 0;
  stream.add(UpdateProgress(total, current, errors, updated));

  var channel = Channel<FavoriteItemWithUpdateInfo>(10);

  () async {
    var c = 0;
    for (var comic in comicsToUpdate) {
      await channel.push(comic);
      c++;
      if (c % 5 == 0) {
        var delay = c % 100 + 1;
        if (delay > 10) {
          delay = 10;
        }
        await Future.delayed(Duration(seconds: delay));
      }
    }
    channel.close();
  }();

  var updateFutures = <Future>[];
  for (var i = 0; i < 5; i++) {
    var f = () async {
      while (true) {
        var comic = await channel.pop();
        if (comic == null) {
          break;
        }
        var result = await updateComic(comic, folder);
        current++;
        if (result.updated) {
          updated++;
        }
        if (result.errorMessage != null) {
          errors++;
        }
        stream.add(UpdateProgress(
            total, current, errors, updated, comic, result.errorMessage));
      }
    }();
    updateFutures.add(f);
  }

  await Future.wait(updateFutures);

  if (updated > 0) {
    LocalFavoritesManager().updateUI();
  }

  stream.close();
}

Stream<UpdateProgress> updateFolder(String folder, bool ignoreCheckTime) {
  var stream = StreamController<UpdateProgress>();
  updateFolderBase(folder, stream, ignoreCheckTime);
  return stream.stream;
}
