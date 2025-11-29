// test/providers/cached_episodes_simple_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';

void main() {
  group('CachedEpisodesNotifier - Core Functionality', () {
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

    test('should start with empty cache', () async {
      final episodes = await container.read(cachedEpisodesProvider.future);
      expect(episodes, isEmpty);
    });

    test('should add episodes to cache in memory', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);
      final testEpisodes = [
        createTestEpisode(
          showName: 'Attack on Titan',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
      ];

      await notifier.cacheEpisodes(testEpisodes);

      // Check in-memory state
      final state = container.read(cachedEpisodesProvider);
      expect(state.value, hasLength(1));
      expect(state.value![0].show, equals('Attack on Titan'));
    });

    test('should sort episodes by release date (newest first)', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);
      final testEpisodes = [
        createTestEpisode(
          showName: 'Show A',
          episode: '1',
          releaseDate: DateTime(2024), // Older
        ),
        createTestEpisode(
          showName: 'Show B',
          episode: '1',
          releaseDate: DateTime(2024, 1, 3), // Newer
        ),
        createTestEpisode(
          showName: 'Show C',
          episode: '1',
          releaseDate: DateTime(2024, 1, 2), // Middle
        ),
      ];

      await notifier.cacheEpisodes(testEpisodes);
      final state = container.read(cachedEpisodesProvider);

      expect(state.value![0].show, equals('Show B')); // Newest first
      expect(state.value![1].show, equals('Show C')); // Middle
      expect(state.value![2].show, equals('Show A')); // Oldest last
    });

    test('should filter new episodes by bookmarks', () async {
      // Set up bookmarks first
      final bookmarkNotifier = container.read(
        bookmarkedSeriesProvider.notifier,
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

      final cachedNotifier = container.read(cachedEpisodesProvider.notifier);

      // API episodes (mix of bookmarked and non-bookmarked)
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

      await cachedNotifier.cacheNewBookmarkedEpisodes(apiEpisodes);
      final state = container.read(cachedEpisodesProvider);

      expect(state.value, hasLength(2)); // Only bookmarked series
      expect(
        state.value!.map((e) => e.show),
        containsAll(['Attack on Titan', 'One Piece']),
      );
      expect(
        state.value!.map((e) => e.show),
        isNot(contains('Non-Bookmarked Show')),
      );
    });

    test('should prevent duplicate episodes', () async {
      // Set up bookmarks
      final bookmarkNotifier = container.read(
        bookmarkedSeriesProvider.notifier,
      );
      await bookmarkNotifier.add(
        BookmarkedShowInfo(
          showName: 'Attack on Titan',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );

      final cachedNotifier = container.read(cachedEpisodesProvider.notifier);

      // Add initial episode
      final initialEpisode = createTestEpisode(
        showName: 'Attack on Titan',
        episode: '1',
        releaseDate: DateTime(2024),
      );
      await cachedNotifier.cacheEpisodes([initialEpisode]);

      // Try to add the same episode again
      final duplicateEpisode = createTestEpisode(
        showName: 'Attack on Titan',
        episode: '1', // Same episode
        releaseDate: DateTime(2024),
      );

      await cachedNotifier.cacheNewBookmarkedEpisodes([duplicateEpisode]);
      final state = container.read(cachedEpisodesProvider);

      expect(state.value, hasLength(1)); // Should not duplicate
    });

    test('should clear cache', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);

      // Add some episodes first
      final testEpisodes = [
        createTestEpisode(
          showName: 'Test Show',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
      ];
      await notifier.cacheEpisodes(testEpisodes);

      // Verify they're there
      var state = container.read(cachedEpisodesProvider);
      expect(state.value, hasLength(1));

      // Clear cache
      await notifier.clearCache();
      state = container.read(cachedEpisodesProvider);

      expect(state.value, isEmpty);
    });

    test('should handle cleanup of old episodes', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);

      // Create many episodes for one series
      final episodes = List.generate(
        150,
        (index) => createTestEpisode(
          showName: 'Long Running Show',
          episode: '${index + 1}',
          releaseDate: DateTime(2024).add(Duration(days: index)),
        ),
      );

      await notifier.cacheEpisodes(episodes);

      // Verify all episodes are there
      var state = container.read(cachedEpisodesProvider);
      expect(state.value, hasLength(150));

      // Trigger cleanup
      await notifier.cleanupOldEpisodes();
      state = container.read(cachedEpisodesProvider);

      // Should keep only 100 episodes
      expect(state.value, hasLength(100));
      // Should keep the latest episodes (51-150)
      expect(state.value!.first.episode, equals('150'));
      expect(state.value!.last.episode, equals('51'));
    });

    test('should remove series from cache', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);
      final testEpisodes = [
        createTestEpisode(
          showName: 'Attack on Titan',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
        createTestEpisode(
          showName: 'Attack on Titan',
          episode: '2',
          releaseDate: DateTime(2024, 1, 2),
        ),
        createTestEpisode(
          showName: 'One Piece',
          episode: '1000',
          releaseDate: DateTime(2024, 1, 3),
        ),
      ];

      await notifier.cacheEpisodes(testEpisodes);

      // Remove one series
      await notifier.removeSeriesFromCache('Attack on Titan');

      final state = container.read(cachedEpisodesProvider);
      expect(state.value, hasLength(1));
      expect(state.value![0].show, equals('One Piece'));
    });
  });

  group('Bookmarked Series Integration', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should work with bookmarked series provider', () async {
      final bookmarkNotifier = container.read(
        bookmarkedSeriesProvider.notifier,
      );

      // Add bookmarks
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

      // Verify bookmarks
      final bookmarks = await container.read(bookmarkedSeriesProvider.future);
      expect(
        bookmarks.map((b) => b.showName),
        containsAll(['Attack on Titan', 'One Piece']),
      );
    });

    test('should cache only bookmarked series episodes', () async {
      final bookmarkNotifier = container.read(
        bookmarkedSeriesProvider.notifier,
      );
      await bookmarkNotifier.add(
        BookmarkedShowInfo(
          showName: 'Bookmarked Show',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );

      // Verify bookmarks are set
      final bookmarks = await container.read(bookmarkedSeriesProvider.future);
      expect(bookmarks.map((b) => b.showName), contains('Bookmarked Show'));

      final cachedNotifier = container.read(cachedEpisodesProvider.notifier);

      final episodes = [
        ShowInfo(
          downloads: [],
          episode: '1',
          imageUrl: 'test.jpg',
          page: 'bookmarked-show',
          releaseDate: DateTime(2024),
          show: 'Bookmarked Show',
          timeLabel: '12:00',
          xdcc: 'test',
        ),
        ShowInfo(
          downloads: [],
          episode: '1',
          imageUrl: 'test.jpg',
          page: 'not-bookmarked-show',
          releaseDate: DateTime(2024, 1, 2),
          show: 'Not Bookmarked Show',
          timeLabel: '12:00',
          xdcc: 'test',
        ),
      ];

      await cachedNotifier.cacheNewBookmarkedEpisodes(episodes);

      final cached = container.read(cachedEpisodesProvider);
      expect(cached.value, hasLength(1));
      expect(cached.value![0].show, equals('Bookmarked Show'));
    });
  });
}
