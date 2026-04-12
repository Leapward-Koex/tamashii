import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/api/jikan_api.dart';
import 'package:tamashii/models/jikan_models.dart';
import 'package:tamashii/providers/jikan_api_providers.dart';

class FakeJikanApi extends JikanApi {
  FakeJikanApi();

  final List<String> searchedQueries = <String>[];

  @override
  Future<List<JikanAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searchedQueries.add(query);
    return const <JikanAnimeSearchResult>[
      JikanAnimeSearchResult(
        malId: 1,
        title: 'Cowboy Bebop',
        titleEnglish: 'Cowboy Bebop',
        type: 'TV',
        episodes: 26,
        imageUrl: '',
      ),
    ];
  }
}

class ThrowingJikanApi extends JikanApi {
  ThrowingJikanApi();

  int callCount = 0;

  @override
  Future<List<JikanAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    callCount += 1;
    throw const JikanApiException('boom');
  }
}

void main() {
  group('searchJikanShowsProvider', () {
    test(
      'keeps cached results for the same query after listeners are removed',
      () async {
        final api = FakeJikanApi();
        final container = ProviderContainer(
          overrides: [jikanApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final provider = searchJikanShowsProvider(' hero ');
        final subscription = container.listen(
          provider,
          (_, __) {},
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
        final api = FakeJikanApi();
        final container = ProviderContainer(
          overrides: [jikanApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final results = await container.read(
          searchJikanShowsProvider('   ').future,
        );

        expect(results, isEmpty);
        expect(api.searchedQueries, isEmpty);
      },
    );

    test('does not retry failed searches automatically', () async {
      final api = ThrowingJikanApi();
      final container = ProviderContainer(
        overrides: [jikanApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(searchJikanShowsProvider('bebop').future),
        throwsA(isA<JikanApiException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await container.pump();

      expect(api.callCount, 1);
    });
  });
}
