import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/api_cache_sync_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';

class FakeSubsPleaseApi extends SubsPleaseApi {
  FakeSubsPleaseApi({
    required this.latestEpisodes,
    required this.searchEpisodesByTerm,
  });

  final List<ShowInfo> latestEpisodes;
  final Map<String, List<ShowInfo>> searchEpisodesByTerm;

  @override
  Future<List<ShowInfo>> getLatestShowList() async => latestEpisodes;

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async {
    return searchEpisodesByTerm[searchTerm] ?? const <ShowInfo>[];
  }

  @override
  Future<String?> getShowSynopsis(String showPage) async => null;
}

void main() {
  group('Home screen filter state', () {
    ShowInfo createEpisode({
      required String showName,
      required String episode,
      required DateTime releaseDate,
    }) {
      return ShowInfo(
        downloads: const <ShowDownloadInfo>[],
        episode: episode,
        imageUrl: 'https://example.com/$showName.jpg',
        page: showName.toLowerCase().replaceAll(' ', '-'),
        releaseDate: releaseDate,
        show: showName,
        timeLabel: '12:00',
        xdcc: 'test',
      );
    }

    ProviderContainer createContainer(FakeSubsPleaseApi api) {
      return ProviderContainer(
        overrides: [subsPleaseApiProvider.overrideWithValue(api)],
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'saved filter includes a show that was bookmarked from search even when latest is empty',
      () async {
        final searchedEpisode = createEpisode(
          showName: 'Older Show',
          episode: '12',
          releaseDate: DateTime(2024, 5),
        );
        final container = createContainer(
          FakeSubsPleaseApi(
            latestEpisodes: const <ShowInfo>[],
            searchEpisodesByTerm: <String, List<ShowInfo>>{
              'Older Show': <ShowInfo>[searchedEpisode],
            },
          ),
        );
        addTearDown(container.dispose);

        await container.read(bookmarkedSeriesProvider.future);

        final syncService = container.read(apiCacheSyncProvider);
        syncService.initialize();

        final cacheSeeded = Completer<void>();
        final subscription = container.listen(cachedEpisodesProvider, (
          previous,
          next,
        ) {
          final cachedShows = next.asData?.value ?? const <ShowInfo>[];
          if (!cacheSeeded.isCompleted &&
              cachedShows.any((episode) => episode.show == 'Older Show')) {
            cacheSeeded.complete();
          }
        }, fireImmediately: true);
        addTearDown(subscription.close);

        await container
            .read(bookmarkedSeriesProvider.notifier)
            .add(
              BookmarkedShowInfo(
                showName: 'Older Show',
                imageUrl: searchedEpisode.imageUrl,
                releaseDayOfWeek: searchedEpisode.releaseDate.weekday,
              ),
            );

        await cacheSeeded.future.timeout(const Duration(seconds: 1));

        await container.read(showFilterProvider.future);
        await container
            .read(showFilterProvider.notifier)
            .setFilter(ShowFilter.saved);
        final filteredShows = await container.read(
          filteredCombinedEpisodesProvider('').future,
        );

        expect(filteredShows.map((show) => show.show), contains('Older Show'));
      },
    );

    test('saved filter excludes manual schedule-only entries', () async {
      final trackedEpisode = createEpisode(
        showName: 'Tracked Show',
        episode: '7',
        releaseDate: DateTime(2024, 5, 3),
      );
      final manualEpisode = createEpisode(
        showName: 'Manual Show',
        episode: '2',
        releaseDate: DateTime(2024, 5, 4),
      );
      final container = createContainer(
        FakeSubsPleaseApi(
          latestEpisodes: <ShowInfo>[trackedEpisode, manualEpisode],
          searchEpisodesByTerm: const <String, List<ShowInfo>>{},
        ),
      );
      addTearDown(container.dispose);

      await container.read(bookmarkedSeriesProvider.future);
      await container
          .read(bookmarkedSeriesProvider.notifier)
          .add(
            BookmarkedShowInfo(
              showName: 'Tracked Show',
              imageUrl: trackedEpisode.imageUrl,
              releaseDayOfWeek: trackedEpisode.releaseDate.weekday,
            ),
          );
      await container
          .read(bookmarkedSeriesProvider.notifier)
          .add(
            BookmarkedShowInfo(
              showName: 'Manual Show',
              imageUrl: manualEpisode.imageUrl,
              releaseDayOfWeek: manualEpisode.releaseDate.weekday,
              source: BookmarkedShowSource.manual,
            ),
          );
      await container.read(showFilterProvider.future);
      await container
          .read(showFilterProvider.notifier)
          .setFilter(ShowFilter.saved);

      final filteredShows = await container.read(
        filteredCombinedEpisodesProvider('').future,
      );

      expect(filteredShows.map((show) => show.show), contains('Tracked Show'));
      expect(
        filteredShows.map((show) => show.show),
        isNot(contains('Manual Show')),
      );
    });

    test(
      'saved filter still filters results while a search query is active',
      () async {
        final bookmarkedEpisode = createEpisode(
          showName: 'Bookmarked Show',
          episode: '5',
          releaseDate: DateTime(2024, 5, 2),
        );
        final otherEpisode = createEpisode(
          showName: 'Other Show',
          episode: '9',
          releaseDate: DateTime(2024, 5, 3),
        );
        final container = createContainer(
          FakeSubsPleaseApi(
            latestEpisodes: const <ShowInfo>[],
            searchEpisodesByTerm: <String, List<ShowInfo>>{
              'show': <ShowInfo>[bookmarkedEpisode, otherEpisode],
            },
          ),
        );
        addTearDown(container.dispose);

        await container.read(bookmarkedSeriesProvider.future);
        await container
            .read(bookmarkedSeriesProvider.notifier)
            .add(
              BookmarkedShowInfo(
                showName: 'Bookmarked Show',
                imageUrl: bookmarkedEpisode.imageUrl,
                releaseDayOfWeek: bookmarkedEpisode.releaseDate.weekday,
              ),
            );
        await container.read(showFilterProvider.future);
        await container
            .read(showFilterProvider.notifier)
            .setFilter(ShowFilter.saved);

        final filteredShows = await container.read(
          filteredCombinedEpisodesProvider('show').future,
        );

        expect(filteredShows.map((show) => show.show), <String>[
          'Bookmarked Show',
        ]);
      },
    );
  });
}
