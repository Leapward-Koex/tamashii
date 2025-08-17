// lib/providers/api_cache_sync_provider.dart

import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/show_models.dart';
import 'bookmarked_series_provider.dart';
import 'subsplease_api_providers.dart';
import 'cached_episodes_provider.dart';

/// Provider that listens to API updates and automatically caches bookmarked episodes
final apiCacheSyncProvider = Provider<ApiCacheSyncService>((ref) {
  return ApiCacheSyncService(ref);
});

class ApiCacheSyncService {
  final Ref _ref;
  bool _initialized = false;

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
    _ref.listen(bookmarkedSeriesNotifierProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final previousBookmarks = previous!.value!.toSet();
        final currentBookmarks = next.value!.toSet();

        // Find removed bookmarks
        final removedBookmarks = previousBookmarks.difference(currentBookmarks);

        // Remove cached episodes for unbookmarked series
        for (final removedSeries in removedBookmarks) {
          _ref
              .read(cachedEpisodesNotifierProvider.notifier)
              .removeSeriesFromCache(removedSeries);
        }
      }
    });

    // Perform initial sync
    _performInitialSync();
  }

  /// Sync new episodes from API to cache
  Future<void> _syncNewEpisodes(List<ShowInfo> apiEpisodes) async {
    final cachedNotifier = _ref.read(cachedEpisodesNotifierProvider.notifier);
    await cachedNotifier.cacheNewBookmarkedEpisodes(apiEpisodes);
  }

  /// Perform initial sync of bookmarked episodes
  Future<void> _performInitialSync() async {
    try {
      final bookmarkedSeries = await _ref.read(
        bookmarkedSeriesNotifierProvider.future,
      );
      if (bookmarkedSeries.isEmpty) return;

      final latestEpisodes = await _ref.read(latestShowsProvider.future);
      final bookmarkedEpisodes =
          latestEpisodes
              .where((episode) => bookmarkedSeries.contains(episode.show))
              .toList();

      if (bookmarkedEpisodes.isNotEmpty) {
        await _ref
            .read(cachedEpisodesNotifierProvider.notifier)
            .cacheEpisodes(bookmarkedEpisodes);
      }
    } catch (e) {
      // Ignore initial sync errors
    }
  }

  /// Manually trigger a sync
  Future<void> syncNow() async {
    await _performInitialSync();
  }
}
