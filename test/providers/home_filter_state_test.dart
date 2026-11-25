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

class _DeferredLatestApi extends FakeSubsPleaseApi {
  _DeferredLatestApi()
    : super(latestEpisodes: const [], searchEpisodesByTerm: const {});

  final started = Completer<void>();
  final result = Completer<List<ShowInfo>>();

  @override
  Future<List<ShowInfo>> getLatestShowList() {
    if (!started.isCompleted) {
      started.complete();
    }
    return result.future;
  }
}

class _DeferredCache extends CachedEpisodesNotifier {
  _DeferredCache(this.source);

  final Completer<List<ShowInfo>> source;
  bool started = false;

  @override
  Future<List<ShowInfo>> build() {
    started = true;
    return source.future;
  }
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

    test('saved feed displays cache while latest is pending', () async {
      SharedPreferences.setMockInitialValues({'show_filter': 'saved'});
      final api = _DeferredLatestApi();
      final cache = _DeferredCache(Completer());
      final cached = createEpisode(
        showName: 'Watched show',
        episode: '1',
        releaseDate: DateTime(2024),
      );
      final latest = createEpisode(
        showName: 'Watched show',
        episode: '1',
        releaseDate: DateTime(2024, 1, 2),
      );
      final unrelated = createEpisode(
        showName: 'Other show',
        episode: '10',
        releaseDate: DateTime(2024, 1, 3),
      );
      final container = ProviderContainer(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(api),
          cachedEpisodesProvider.overrideWith(() => cache),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(bookmarkedSeriesProvider.notifier)
          .add(
            BookmarkedShowInfo(
              imageUrl: cached.imageUrl,
              releaseDayOfWeek: DateTime.monday,
              showName: cached.show,
            ),
          );

      final preview = Completer<List<ShowInfo>>();
      final refreshed = Completer<List<ShowInfo>>();
      final listener = container.listen(filteredShowsProvider(''), (_, next) {
        final items = next.asData?.value;
        if (items == null || items.isEmpty) {
          return;
        }
        if (items.contains(cached) && !preview.isCompleted) {
          preview.complete(items);
        }
        if (items.contains(latest) && !refreshed.isCompleted) {
          refreshed.complete(items);
        }
      });
      addTearDown(listener.close);

      await api.started.future.timeout(const Duration(seconds: 1));
      expect(cache.started, isTrue);
      cache.source.complete([unrelated, cached]);
      expect(await preview.future.timeout(const Duration(seconds: 1)), [
        cached,
      ]);
      expect(api.result.isCompleted, isFalse);

      api.result.complete([latest, unrelated]);
      expect(await refreshed.future.timeout(const Duration(seconds: 1)), [
        latest,
      ]);
    });

    test('typed search never starts the disk cache', () async {
      final episode = createEpisode(
        showName: 'Watched show',
        episode: '1',
        releaseDate: DateTime(2024),
      );
      final api = FakeSubsPleaseApi(
        latestEpisodes: const [],
        searchEpisodesByTerm: {
          'watched': [episode],
        },
      );
      final cache = _DeferredCache(Completer());
      final container = ProviderContainer(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(api),
          cachedEpisodesProvider.overrideWith(() => cache),
        ],
      );
      addTearDown(container.dispose);

      final provider = filteredShowsProvider('watched');
      final watch = container.listen(provider, (_, _) {});
      addTearDown(watch.close);
      final results = await container
          .read(provider.future)
          .timeout(const Duration(seconds: 1));
      expect(results, [episode]);
      expect(cache.started, isFalse);
    });

    test('saved filter includes a show that was bookmarked from search even when latest is empty', () async {
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
    });

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
