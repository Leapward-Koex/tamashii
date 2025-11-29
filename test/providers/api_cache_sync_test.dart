// test/providers/api_cache_sync_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/api_cache_sync_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';

void main() {
  group('ApiCacheSyncService', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    // Helper function to create test episodes
    ShowInfo createTestEpisode({
      required String showName,
      required String episode,
      required DateTime releaseDate,
    }) {
      return ShowInfo(
        downloads: [],
        episode: episode,
        imageUrl: 'https://example.com/image.jpg',
        page: showName.toLowerCase().replaceAll(' ', '-'),
        releaseDate: releaseDate,
        show: showName,
        timeLabel: '12:00',
        xdcc: 'test',
      );
    }

    test('should create sync service instance', () {
      final syncService = container.read(apiCacheSyncProvider);
      expect(syncService, isNotNull);
    });

    test('should sync bookmarked episodes to cache', () async {
      // Set up bookmarks
      final bookmarkNotifier = container.read(
        bookmarkedSeriesNotifierProvider.notifier,
      );
      await bookmarkNotifier.add(
        BookmarkedShowInfo(
          showName: 'Attack on Titan',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );
      await bookmarkNotifier.add(
        BookmarkedShowInfo(
          showName: 'One Piece',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );

      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );

      // Simulate API episodes
      final apiEpisodes = [
        createTestEpisode(
          showName: 'Attack on Titan',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
        createTestEpisode(
          showName: 'One Piece',
          episode: '1000',
          releaseDate: DateTime(2024, 1, 2),
        ),
        createTestEpisode(
          showName: 'Non-Bookmarked Show',
          episode: '1',
          releaseDate: DateTime(2024, 1, 3),
        ),
      ];

      // Manually trigger sync (simulating what would happen when API updates)
      await cachedNotifier.cacheNewBookmarkedEpisodes(apiEpisodes);

      final cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );

      expect(cachedEpisodes, hasLength(2)); // Only bookmarked series
      expect(
        cachedEpisodes.map((e) => e.show),
        containsAll(['Attack on Titan', 'One Piece']),
      );
      expect(
        cachedEpisodes.map((e) => e.show),
        isNot(contains('Non-Bookmarked Show')),
      );
    });

    test('should handle manual sync trigger', () async {
      final syncService = container.read(apiCacheSyncProvider);

      // This should not throw
      await syncService.syncNow();

      // Verify cache is still accessible
      final cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );
      expect(cachedEpisodes, isNotNull);
    });

    test('should initialize without errors', () {
      final syncService = container.read(apiCacheSyncProvider);

      // This should not throw
      syncService.initialize();

      // Should be able to call initialize multiple times safely
      syncService.initialize();
      syncService.initialize();
    });
  });
}
