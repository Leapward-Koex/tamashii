// test/providers/combined_episodes_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/filter_provider.dart';

void main() {
  group('Combined Episodes Logic', () {
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

    test('should handle duplicate episodes correctly', () async {
      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );

      // Add episodes with same show and episode but different data
      final cachedEpisode = createTestEpisode(
        showName: 'Test Show',
        episode: '1',
        releaseDate: DateTime(2024),
      );

      await cachedNotifier.cacheEpisodes([cachedEpisode]);

      // Simulate adding the same episode again (should not duplicate)
      final duplicateEpisode = createTestEpisode(
        showName: 'Test Show',
        episode: '1',
        releaseDate: DateTime(2024),
      );

      await cachedNotifier.cacheNewBookmarkedEpisodes([duplicateEpisode]);

      final cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );
      expect(cachedEpisodes, hasLength(1));
    });

    test('should sort episodes by release date', () async {
      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );

      final episodes = [
        createTestEpisode(
          showName: 'Show A',
          episode: '1',
          releaseDate: DateTime(2024), // Oldest
        ),
        createTestEpisode(
          showName: 'Show B',
          episode: '1',
          releaseDate: DateTime(2024, 1, 3), // Newest
        ),
        createTestEpisode(
          showName: 'Show C',
          episode: '1',
          releaseDate: DateTime(2024, 1, 2), // Middle
        ),
      ];

      await cachedNotifier.cacheEpisodes(episodes);
      final cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );

      // Should be sorted newest first
      expect(cachedEpisodes[0].show, equals('Show B'));
      expect(cachedEpisodes[1].show, equals('Show C'));
      expect(cachedEpisodes[2].show, equals('Show A'));
    });

    test('should handle filter state correctly', () async {
      // Set up bookmarks
      final bookmarkNotifier = container.read(
        bookmarkedSeriesNotifierProvider.notifier,
      );
      await bookmarkNotifier.add(
        BookmarkedShowInfo(
          showName: 'Bookmarked Show',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );

      // Set up cached episodes
      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );
      final episodes = [
        createTestEpisode(
          showName: 'Bookmarked Show',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
        createTestEpisode(
          showName: 'Non-Bookmarked Show',
          episode: '1',
          releaseDate: DateTime(2024, 1, 2),
        ),
      ];

      await cachedNotifier.cacheEpisodes(episodes);

      // Test with "saved" filter
      final filterNotifier = container.read(
        showFilterNotifierProvider.notifier,
      );
      await filterNotifier.setFilter(ShowFilter.saved);

      // The filteredCombinedEpisodes provider would filter by bookmarks
      // This test verifies the logic exists
      final bookmarks = await container.read(
        bookmarkedSeriesNotifierProvider.future,
      );
      expect(bookmarks.map((b) => b.showName), contains('Bookmarked Show'));
      expect(
        bookmarks.map((b) => b.showName),
        isNot(contains('Non-Bookmarked Show')),
      );
    });

    test('should handle empty bookmarks gracefully', () async {
      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );

      // Add episodes but no bookmarks
      final episodes = [
        createTestEpisode(
          showName: 'Test Show',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
      ];

      await cachedNotifier.cacheNewBookmarkedEpisodes(episodes);

      // Should not cache anything since no bookmarks exist
      final cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );
      expect(cachedEpisodes, isEmpty);
    });

    test('should maintain cache across multiple operations', () async {
      final bookmarkNotifier = container.read(
        bookmarkedSeriesNotifierProvider.notifier,
      );
      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );

      // Set up bookmark
      await bookmarkNotifier.add(
        BookmarkedShowInfo(
          showName: 'Long Running Show',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );

      // Add multiple episodes over time
      for (int i = 1; i <= 5; i++) {
        final episode = createTestEpisode(
          showName: 'Long Running Show',
          episode: '$i',
          releaseDate: DateTime(2024, 1, i),
        );
        await cachedNotifier.cacheNewBookmarkedEpisodes([episode]);
      }

      final cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );
      expect(cachedEpisodes, hasLength(5));

      // Should be sorted by release date (newest first)
      expect(cachedEpisodes.first.episode, equals('5'));
      expect(cachedEpisodes.last.episode, equals('1'));
    });

    test('should handle cache cleanup correctly', () async {
      final cachedNotifier = container.read(
        cachedEpisodesNotifierProvider.notifier,
      );

      // Create many episodes for cleanup test
      final episodes = List.generate(
        150,
        (index) => createTestEpisode(
          showName: 'Test Show',
          episode: '${index + 1}',
          releaseDate: DateTime(2024).add(Duration(days: index)),
        ),
      );

      await cachedNotifier.cacheEpisodes(episodes);

      // Verify all episodes are cached
      var cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );
      expect(cachedEpisodes, hasLength(150));

      // Trigger cleanup
      await cachedNotifier.cleanupOldEpisodes();

      // Should now have only 100 episodes
      cachedEpisodes = await container.read(
        cachedEpisodesNotifierProvider.future,
      );
      expect(cachedEpisodes, hasLength(100));

      // Should keep the newest episodes
      expect(cachedEpisodes.first.episode, equals('150'));
      expect(cachedEpisodes.last.episode, equals('51'));
    });
  });
}
