// test/providers/api_cache_sync_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/api_cache_sync_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';

class _RecordingApi extends SubsPleaseApi {
  _RecordingApi({this.search});

  final Future<List<ShowInfo>> Function(String title)? search;
  final searchedTitles = <String>[];

  @override
  Future<List<ShowInfo>> getLatestShowList() async => [];

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async {
    searchedTitles.add(searchTerm);
    return search == null ? [] : await search!(searchTerm);
  }
}

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

      await container.read(cachedEpisodesProvider.future);
      final cachedNotifier = container.read(cachedEpisodesProvider.notifier);

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
        cachedEpisodesProvider.future,
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
        cachedEpisodesProvider.future,
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

    test(
      'backfills three missing titles at a time and skips removed shows',
      () async {
        const titles = ['Alpha', 'Beta', 'Gamma', 'Delta'];
        final episodeByTitle = {
          for (final (index, title) in titles.indexed)
            title: createTestEpisode(
              showName: title,
              episode: '1',
              releaseDate: DateTime(2024, 1, index + 1),
            ),
        };
        final replies = {
          for (final title in titles) title: Completer<List<ShowInfo>>(),
        };
        final firstBatch = Completer<void>();
        final secondBatch = Completer<void>();
        var started = 0;
        final api = _RecordingApi(
          search: (title) {
            started += 1;
            if (started == 3) firstBatch.complete();
            if (title == 'Delta' && !secondBatch.isCompleted) {
              secondBatch.complete();
            }
            return replies[title]!.future;
          },
        );
        final testContainer = ProviderContainer(
          overrides: [subsPleaseApiProvider.overrideWithValue(api)],
        );
        addTearDown(testContainer.dispose);
        final bookmarkSubscription = testContainer.listen(
          bookmarkedSeriesProvider,
          (_, _) {},
        );
        addTearDown(bookmarkSubscription.close);
        final notifier = testContainer.read(bookmarkedSeriesProvider.notifier);
        for (final title in titles) {
          expect(
            await notifier.add(
              BookmarkedShowInfo(
                showName: title,
                imageUrl: '',
                releaseDayOfWeek: DateTime.monday,
              ),
            ),
            isTrue,
          );
        }

        final sync = testContainer.read(apiCacheSyncProvider);
        final firstSync = sync.syncNow();
        await firstBatch.future.timeout(const Duration(seconds: 1));
        await testContainer.pump();
        expect(api.searchedTitles, ['Alpha', 'Beta', 'Gamma']);

        final overlappingSync = sync.syncNow();
        await notifier.remove('Beta');
        for (final title in titles.take(3)) {
          replies[title]!.complete([episodeByTitle[title]!]);
        }
        await secondBatch.future.timeout(const Duration(seconds: 1));
        expect(api.searchedTitles, titles);
        replies['Delta']!.complete([episodeByTitle['Delta']!]);
        await Future.wait([firstSync, overlappingSync]);

        final cachedEpisodes = await testContainer.read(
          cachedEpisodesProvider.future,
        );
        expect(cachedEpisodes.map((episode) => episode.show), [
          'Delta',
          'Gamma',
          'Alpha',
        ]);
        expect(api.searchedTitles, titles);
      },
    );

    test(
      'does not backfill episodes when adding or matching a manual show',
      () async {
        final api = _RecordingApi();
        final manualContainer = ProviderContainer(
          overrides: [subsPleaseApiProvider.overrideWithValue(api)],
        );
        addTearDown(manualContainer.dispose);
        manualContainer.read(apiCacheSyncProvider).initialize();
        await manualContainer.read(bookmarkedSeriesProvider.future);
        final notifier = manualContainer.read(
          bookmarkedSeriesProvider.notifier,
        );

        expect(
          await notifier.add(
            const BookmarkedShowInfo(
              showName: 'Frieren',
              imageUrl: '',
              releaseDayOfWeek: DateTime.monday,
              source: BookmarkedShowSource.manual,
            ),
          ),
          isTrue,
        );
        expect(
          await notifier.matchManualEntry(
            'Frieren',
            malId: 52991,
            imageUrl: '',
          ),
          isTrue,
        );
        await manualContainer.pump();

        expect(api.searchedTitles, isEmpty);
      },
    );
  });
}
