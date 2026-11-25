// lib/providers/api_cache_sync_provider.dart

import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';

/// Provider that listens to API updates and automatically caches bookmarked episodes
final apiCacheSyncProvider = Provider<ApiCacheSyncService>((ref) {
  return ApiCacheSyncService(ref);
});

class ApiCacheSyncService {
  static const _backfillBatchSize = 3;

  final Ref _ref;
  bool _initialized = false;
  final _pendingBackfillTitles = <String>{};
  Future<void> _backfillQueue = Future<void>.value();

  ApiCacheSyncService(this._ref);

  /// Initialize the sync service
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Listen to latest shows API updates
    _ref.listen(latestShowsProvider, (previous, next) {
      if (next.hasValue) {
        _syncNewEpisodes(next.value!);
      }
    });

    // Listen to bookmarked series changes to clean up cache
    _ref.listen(bookmarkedSeriesProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final previousBookmarks = {
          for (final show in previous!.value!)
            if (show.showsOnHomePage) show.showName: show,
        };
        final currentBookmarks = {
          for (final show in next.value!)
            if (show.showsOnHomePage) show.showName: show,
        };
        final addedBookmarks = currentBookmarks.values.where(
          (show) => !previousBookmarks.containsKey(show.showName),
        );
        final removedBookmarks = previousBookmarks.keys.where(
          (showName) => !currentBookmarks.containsKey(showName),
        );

        if (addedBookmarks.isNotEmpty) {
          unawaited(_backfillBookmarkedEpisodes(addedBookmarks));
        }

        // Remove cached episodes for unbookmarked series
        for (final showName in removedBookmarks) {
          unawaited(
            _ref
                .read(cachedEpisodesProvider.notifier)
                .removeSeriesFromCache(showName),
          );
        }
      }
    });

    // Perform initial sync
    _performInitialSync();
  }

  /// Sync new episodes from API to cache
  Future<void> _syncNewEpisodes(List<ShowInfo> apiEpisodes) async {
    final cachedNotifier = _ref.read(cachedEpisodesProvider.notifier);
    await cachedNotifier.cacheNewBookmarkedEpisodes(apiEpisodes);
  }

  /// Perform initial sync of bookmarked episodes
  Future<void> _performInitialSync() async {
    try {
      final bookmarkedSeries = await _ref.read(bookmarkedSeriesProvider.future);
      final homePageBookmarks = bookmarkedSeries
          .where((bookmark) => bookmark.showsOnHomePage)
          .toList(growable: false);
      if (homePageBookmarks.isEmpty) {
        return;
      }
      final bookmarkedNames = homePageBookmarks
          .map((bookmark) => bookmark.showName)
          .toSet();

      final latestEpisodes = await _ref.read(latestShowsProvider.future);
      final bookmarkedEpisodes = latestEpisodes
          .where((episode) => bookmarkedNames.contains(episode.show))
          .toList();

      if (bookmarkedEpisodes.isNotEmpty) {
        await _ref
            .read(cachedEpisodesProvider.notifier)
            .cacheEpisodes(bookmarkedEpisodes);
      }

      final cachedEpisodes = await _ref.read(cachedEpisodesProvider.future);
      final cachedShows = cachedEpisodes.map((episode) => episode.show).toSet();
      final missingBookmarks = homePageBookmarks
          .where((bookmark) => !cachedShows.contains(bookmark.showName))
          .toSet();

      if (missingBookmarks.isNotEmpty) {
        await _backfillBookmarkedEpisodes(missingBookmarks);
      }
    } catch (e) {
      // Ignore initial sync errors
    }
  }

  Future<void> _backfillBookmarkedEpisodes(
    Iterable<BookmarkedShowInfo> seriesList,
  ) {
    final titles = [
      for (final series in seriesList)
        if (_pendingBackfillTitles.add(series.showName)) series.showName,
    ];
    if (titles.isEmpty) {
      return _backfillQueue;
    }

    _backfillQueue = _backfillQueue.then((_) async {
      for (var index = 0; index < titles.length; index += _backfillBatchSize) {
        final batch = titles.skip(index).take(_backfillBatchSize);
        await _backfillBatch(batch);
        _pendingBackfillTitles.removeAll(batch);
      }
    });
    return _backfillQueue;
  }

  Future<void> _backfillBatch(Iterable<String> titles) async {
    try {
      final matches = await Future.wait(titles.map(_findEpisodes));
      final bookmarks = await _ref.read(bookmarkedSeriesProvider.future);
      final watchedTitles = {
        for (final show in bookmarks)
          if (show.showsOnHomePage) show.showName,
      };
      final episodesToCache = [
        for (final (title, episodes) in matches)
          if (watchedTitles.contains(title)) ...episodes,
      ];
      if (episodesToCache.isNotEmpty) {
        await _ref
            .read(cachedEpisodesProvider.notifier)
            .cacheEpisodes(episodesToCache);
      }
    } catch (_) {
      // A failed batch must not block later bookmark changes.
    }
  }

  Future<(String, List<ShowInfo>)> _findEpisodes(String title) async {
    try {
      final subscription = _ref.listen(
        searchShowsProvider(title).future,
        (_, _) {},
      );
      try {
        final results = await subscription.read();
        final normalizedTitle = title.trim().toLowerCase();
        return (
          title,
          results
              .where(
                (episode) =>
                    episode.show.trim().toLowerCase() == normalizedTitle,
              )
              .toList(),
        );
      } finally {
        subscription.close();
      }
    } catch (_) {
      // Other shows in the batch may still return results.
      return (title, const <ShowInfo>[]);
    }
  }

  /// Manually trigger a sync
  Future<void> syncNow() async {
    await _performInitialSync();
  }
}
