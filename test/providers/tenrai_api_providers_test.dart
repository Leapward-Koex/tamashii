import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';

class FakeTenraiApi extends TenraiApi {
  FakeTenraiApi();

  final List<String> searchedQueries = <String>[];

  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searchedQueries.add(query);
    return const <TenraiAnimeSearchResult>[
      TenraiAnimeSearchResult(
        malId: 1,
        title: 'Cowboy Bebop',
        titleEnglish: 'Cowboy Bebop',
        type: 'TV',
        episodes: 26,
      ),
    ];
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
}
