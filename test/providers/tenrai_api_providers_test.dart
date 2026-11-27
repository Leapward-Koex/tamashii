import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';

class FakeTenraiApi extends TenraiApi {
  FakeTenraiApi({
    this.results = const [
      TenraiAnimeSearchResult(
        malId: 1,
        title: 'Cowboy Bebop',
        titleEnglish: 'Cowboy Bebop',
        type: 'TV',
        episodes: 26,
      ),
    ],
  });

  final List<TenraiAnimeSearchResult> results;
  final List<String> searchedQueries = <String>[];

  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searchedQueries.add(query);
    return results;
  }
}

class ThrowingTenraiApi extends TenraiApi {
  ThrowingTenraiApi();

  int callCount = 0;

  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    callCount += 1;
    throw const TenraiApiException('boom');
  }
}

void main() {
  group('searchTenraiShowsProvider', () {
    test(
      'keeps cached results for the same query after listeners are removed',
      () async {
        final api = FakeTenraiApi();
        final container = ProviderContainer(
          overrides: [tenraiApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final provider = searchTenraiShowsProvider(' hero ');
        final subscription = container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );

        final firstResults = await container.read(provider.future);
        expect(firstResults, hasLength(1));
        expect(api.searchedQueries, <String>['hero']);

        subscription.close();
        await container.pump();

        final secondResults = await container.read(provider.future);
        expect(secondResults, hasLength(1));
        expect(api.searchedQueries, <String>['hero']);
      },
    );

    test(
      'returns empty results for blank queries without calling the api',
      () async {
        final api = FakeTenraiApi();
        final container = ProviderContainer(
          overrides: [tenraiApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final results = await container.read(
          searchTenraiShowsProvider('   ').future,
        );

        expect(results, isEmpty);
        expect(api.searchedQueries, isEmpty);
      },
    );

    test('does not retry failed searches automatically', () async {
      final api = ThrowingTenraiApi();
      final container = ProviderContainer(
        overrides: [tenraiApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(searchTenraiShowsProvider('bebop').future),
        throwsA(isA<TenraiApiException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await container.pump();

      expect(api.callCount, 1);
    });
  });

  group('featuredTenraiPosterProvider', () {
    const largeUrl = 'https://cdn.example.com/large.jpg';
    const regularUrl = 'https://cdn.example.com/regular.jpg';
    const showTitle = 'Meitantei Precure!';
    const match = TenraiAnimeSearchResult(
      malId: 63042,
      title: showTitle,
      type: 'TV',
      imageUrl: regularUrl,
      largeImageUrl: largeUrl,
    );

    test('uses only the large artwork from the matching result', () async {
      final api = FakeTenraiApi(
        results: const [
          TenraiAnimeSearchResult(
            malId: 63903,
            title: 'Meitantei Precure! Movie',
            type: 'Movie',
            largeImageUrl: 'https://cdn.example.com/movie.jpg',
          ),
          match,
        ],
      );
      final container = ProviderContainer.test(
        overrides: [tenraiApiProvider.overrideWithValue(api)],
      );

      expect(
        await container.read(featuredTenraiPosterProvider(showTitle).future),
        largeUrl,
      );
      expect(api.searchedQueries, [showTitle]);
    });

    for (final unusable in [null, '/relative.jpg', 'file:///poster.jpg']) {
      test(
        'returns no preferred poster for ${unusable ?? 'standard art only'}',
        () async {
          final api = FakeTenraiApi(
            results: [match.copyWith(largeImageUrl: unusable)],
          );
          final container = ProviderContainer.test(
            overrides: [tenraiApiProvider.overrideWithValue(api)],
          );

          expect(
            await container.read(
              featuredTenraiPosterProvider(showTitle).future,
            ),
            isNull,
          );
        },
      );
    }
  });
}
