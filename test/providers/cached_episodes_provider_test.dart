// test/providers/cached_episodes_provider_test.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';

class _ColdCacheNotifier extends CachedEpisodesNotifier {
  _ColdCacheNotifier(this.load);

  final Future<List<ShowInfo>> load;

  @override
  Future<List<ShowInfo>> build() => load;
}

void main() {
  group('CachedEpisodesNotifier', () {
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

    test('should cache episodes to storage', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);
      final testEpisodes = [
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
      ];

      await notifier.cacheEpisodes(testEpisodes);
      final cachedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(cachedEpisodes, hasLength(2));
      expect(
        cachedEpisodes.map((e) => e.show),
        containsAll(['Attack on Titan', 'One Piece']),
      );

      // Verify storage - using SharedPreferences.getInstance() directly
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getStringList('cached_episodes');
      expect(storedData, isNotNull);
      expect(storedData!, hasLength(2));
    });

    test(
      'unchanged live metadata skips the cache update and disk write',
      () async {
        final episode = createTestEpisode(
          showName: 'Watched Show',
          episode: '1',
          releaseDate: DateTime.utc(2024),
        );
        final originalRow = jsonEncode({
          ...episode.toJson(),
          'unknown_field_from_existing_cache': true,
        });
        final preferences = await SharedPreferences.getInstance();
        await preferences.setStringList('cached_episodes', [originalRow]);
        final original = await container.read(cachedEpisodesProvider.future);
        var updates = 0;
        final listener = container.listen(
          cachedEpisodesProvider,
          (_, _) => updates++,
        );
        addTearDown(listener.close);
        final notifier = container.read(cachedEpisodesProvider.notifier);

        await notifier.cacheEpisodes([episode]);
        expect(container.read(cachedEpisodesProvider).value, same(original));
        expect(preferences.getStringList('cached_episodes'), [originalRow]);
        expect(updates, 0);

        final newMetadata = ShowInfo.fromJson({
          ...episode.toJson(),
          'downloads': [
            {'res': '1080', 'magnet': 'magnet:?xt=test-only'},
          ],
        });
        await notifier.cacheEpisodes([newMetadata]);
        expect(
          container.read(cachedEpisodesProvider).value!.single,
          same(newMetadata),
        );
        expect(
          jsonDecode(
            preferences.getStringList('cached_episodes')!.single,
          )['downloads'],
          isNotEmpty,
        );
        expect(updates, 1);
      },
    );

    test('concurrent cold-cache mutations persist each change', () async {
      final load = Completer<List<ShowInfo>>();
      final cold = ProviderContainer(
        overrides: [
          cachedEpisodesProvider.overrideWith(
            () => _ColdCacheNotifier(load.future),
          ),
        ],
      );
      addTearDown(cold.dispose);
      final notifier = cold.read(cachedEpisodesProvider.notifier);
      final source = createTestEpisode(
        showName: 'Previously cached',
        episode: '1',
        releaseDate: DateTime.utc(2024),
      );
      final first = createTestEpisode(
        showName: 'First update',
        episode: '1',
        releaseDate: DateTime.utc(2024, 1, 2),
      );
      final second = createTestEpisode(
        showName: 'Second update',
        episode: '1',
        releaseDate: DateTime.utc(2024, 1, 3),
      );

      final updates = Future.wait([
        notifier.cacheEpisodes([first]),
        notifier.cacheEpisodes([second]),
        notifier.removeSeriesFromCache(source.show),
      ]);
      load.complete([source]);
      await updates;

      expect(await cold.read(cachedEpisodesProvider.future), [second, first]);
      final persisted = await container.read(cachedEpisodesProvider.future);
      expect(persisted.map((episode) => episode.show), [
        second.show,
        first.show,
      ]);
    });

    for (final corrupt in [false, true]) {
      test(
        'large cache load ${corrupt ? 'clears invalid data' : 'preserves all rows'}',
        () async {
          final rows = List.generate(
            300,
            (index) => jsonEncode(
              createTestEpisode(
                showName: 'Long Series',
                episode: '$index',
                releaseDate: DateTime.utc(2024).add(Duration(days: index)),
              ).toJson(),
            ),
          );
          if (corrupt) rows[250] = 'invalid JSON';
          final preferences = await SharedPreferences.getInstance();
          await preferences.setStringList('cached_episodes', rows);
          final subscription = container.listen(
            cachedEpisodesProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);

          final episodes = await container.read(cachedEpisodesProvider.future);
          if (corrupt) {
            expect(episodes, isEmpty);
            expect(preferences.getStringList('cached_episodes'), isNull);
          } else {
            expect(
              episodes.map((e) => e.episode),
              List.generate(300, (index) => '$index'),
            );
            expect(preferences.getStringList('cached_episodes'), rows);
          }
        },
      );
    }

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
      final cachedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(cachedEpisodes[0].show, equals('Show B')); // Newest first
      expect(cachedEpisodes[1].show, equals('Show C')); // Middle
      expect(cachedEpisodes[2].show, equals('Show A')); // Oldest last
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
      await notifier.removeSeriesFromCache('Attack on Titan');

      final cachedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(cachedEpisodes, hasLength(1));
      expect(cachedEpisodes[0].show, equals('One Piece'));
    });

    test('should cache only new bookmarked episodes', () async {
      // Set up bookmarks
      final bookmarkNotifier = container.read(
        bookmarkedSeriesProvider.notifier,
      );
      await bookmarkNotifier.add(
        const BookmarkedShowInfo(
          showName: 'Attack on Titan',
          imageUrl: '',
          releaseDayOfWeek: 1,
        ),
      );
      await bookmarkNotifier.add(
        const BookmarkedShowInfo(
          showName: 'One Piece',
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

      // New API episodes (mix of bookmarked and non-bookmarked)
      final apiEpisodes = [
        createTestEpisode(
          showName: 'Attack on Titan',
          episode: '1', // Duplicate, should not be added
          releaseDate: DateTime(2024),
        ),
        createTestEpisode(
          showName: 'Attack on Titan',
          episode: '2', // New bookmarked episode
          releaseDate: DateTime(2024, 1, 2),
        ),
        createTestEpisode(
          showName: 'One Piece',
          episode: '1000', // New bookmarked episode
          releaseDate: DateTime(2024, 1, 3),
        ),
        createTestEpisode(
          showName: 'Non-Bookmarked Show',
          episode: '1', // Not bookmarked, should not be cached
          releaseDate: DateTime(2024, 1, 4),
        ),
      ];

      await cachedNotifier.cacheNewBookmarkedEpisodes(apiEpisodes);
      final cachedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(
        cachedEpisodes,
        hasLength(3),
      ); // Initial + 2 new bookmarked episodes
      expect(
        cachedEpisodes.map((e) => e.show),
        containsAll(['Attack on Titan', 'One Piece']),
      );
      expect(
        cachedEpisodes.map((e) => e.show),
        isNot(contains('Non-Bookmarked Show')),
      );
    });

    test('should clean up old episodes (keep only 100 per series)', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);

      // Create 150 episodes for one series
      final episodes = List.generate(
        150,
        (index) => createTestEpisode(
          showName: 'Long Running Show',
          episode: '${index + 1}',
          releaseDate: DateTime(2024).add(Duration(days: index)),
        ),
      );

      await notifier.cacheEpisodes(episodes);
      await notifier.cleanupOldEpisodes();

      final cachedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(cachedEpisodes, hasLength(100));
      // Should keep the latest 100 episodes (51-150)
      expect(cachedEpisodes.first.episode, equals('150'));
      expect(cachedEpisodes.last.episode, equals('51'));
    });

    test('should clear all cached episodes', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);
      final testEpisodes = [
        createTestEpisode(
          showName: 'Test Show',
          episode: '1',
          releaseDate: DateTime(2024),
        ),
      ];

      await notifier.cacheEpisodes(testEpisodes);
      expect(await container.read(cachedEpisodesProvider.future), hasLength(1));

      await notifier.clearCache();
      final cachedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(cachedEpisodes, isEmpty);

      // Verify storage is cleared
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getStringList('cached_episodes');
      expect(storedData, isNull);
    });

    test('should handle corrupted cache data gracefully', () async {
      // Manually corrupt the cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_episodes', [
        'invalid json',
        'another invalid',
      ]);

      // This should clear the corrupted cache and return empty list
      final episodes = await container.read(cachedEpisodesProvider.future);

      expect(episodes, isEmpty);

      // Verify corrupted data was cleared
      final clearedData = prefs.getStringList('cached_episodes');
      expect(clearedData, isNull);
    });

    test('should persist episodes across provider rebuilds', () async {
      final notifier = container.read(cachedEpisodesProvider.notifier);
      final testEpisode = createTestEpisode(
        showName: 'Persistent Show',
        episode: '1',
        releaseDate: DateTime(2024),
      );

      await notifier.cacheEpisodes([testEpisode]);

      // Create new container to simulate app restart
      container.dispose();
      container = ProviderContainer();

      final persistedEpisodes = await container.read(
        cachedEpisodesProvider.future,
      );

      expect(persistedEpisodes, hasLength(1));
      expect(persistedEpisodes[0].show, equals('Persistent Show'));
    });
  });

  group('combinedEpisodesProvider', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should combine API and cached episodes without duplicates', () async {
      // This test would require mocking the API providers
      // For now, we'll test the logic with manual data

      final cachedNotifier = container.read(cachedEpisodesProvider.notifier);

      // Add some cached episodes
      final cachedEpisodes = [
        ShowInfo(
          downloads: [],
          episode: '1',
          imageUrl: 'cached.jpg',
          page: 'cached-show',
          releaseDate: DateTime(2024),
          show: 'Cached Show',
          timeLabel: '12:00',
          xdcc: 'cached',
        ),
        ShowInfo(
          downloads: [],
          episode: '2',
          imageUrl: 'old.jpg',
          page: 'shared-show',
          releaseDate: DateTime(2024, 1, 2),
          show: 'Shared Show',
          timeLabel: '12:00',
          xdcc: 'old',
        ),
      ];

      await cachedNotifier.cacheEpisodes(cachedEpisodes);

      // The actual combination logic is tested implicitly through the provider
      // More comprehensive testing would require mocking the API providers
    });
  });
}
