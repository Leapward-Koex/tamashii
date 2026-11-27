import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/show_catalog_matcher.dart';

const mainSeries = TenraiAnimeSearchResult(
  malId: 44074,
  title: 'Shiguang Dailiren',
  titleEnglish: 'Link Click',
  type: 'ONA',
);
const special = TenraiAnimeSearchResult(
  malId: 49200,
  title: 'Link Click Episode 5.5',
  type: 'ONA',
);
const sideStory = TenraiAnimeSearchResult(
  malId: 50105,
  title: 'Link Click: The Daily Life in Lightime',
  type: 'ONA',
);
const sequel = TenraiAnimeSearchResult(
  malId: 53913,
  title: 'Tensei shitara Ken deshita II',
  titleEnglish: 'Reincarnated as a Sword Season 2',
  type: 'TV',
);
const base = TenraiAnimeSearchResult(
  malId: 49891,
  title: 'Tensei shitara Ken deshita',
  type: 'TV',
);
const sword = ShowCatalogTarget(
  title: 'Tensei Shitara Ken Deshita S2',
  episode: '08',
);

class _Api extends TenraiApi {
  _Api(this.search);
  final FutureOr<List<TenraiAnimeSearchResult>> Function(String) search;
  final queries = <String>[];
  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    queries.add(query);
    return search(query);
  }
}

class _Nano extends Fake implements OnDeviceTextGenerator {
  int calls = 0;
  @override
  Future<OnDeviceGenerationResponse> generateText({
    required String prompt,
    bool allowModelDownload = true,
  }) async {
    calls++;
    return const OnDeviceGenerationResponse(
      text: '{"mal_id":5}',
      modelUsed: 'test',
    );
  }
}

ShowInfo release(String ep, {int day = 1}) => ShowInfo(
  downloads: [],
  episode: ep,
  imageUrl: '',
  page: 'link-click',
  releaseDate: DateTime.utc(2026, 1, day),
  show: 'Link Click',
  timeLabel: '',
  xdcc: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const bookmark = BookmarkedShowInfo(
    imageUrl: '',
    releaseDayOfWeek: 1,
    showName: 'Link Click',
  );
  final firstSP = ShowCatalogTarget.fromRelease(release('SP'));
  final secondSP = ShowCatalogTarget.fromRelease(release('SP2', day: 4));
  Future<ShowCatalogMatch> resolve(
    ProviderContainer container,
    ShowCatalogTarget target,
  ) => container.read(showCatalogMatchProvider(target).future);

  test('scope isolates individual specials, recaps, fractional and episode zero releases', () {
    final schedule = ShowCatalogTarget.fromSchedule(bookmark);
    for (final title in ['Special A', 'Special 7']) {
      expect(
        ShowCatalogTarget(title: title, episode: '01').isReleaseScoped,
        isFalse,
      );
    }
    expect(
      const ShowCatalogTarget(
        title: 'Title - Special: The Reunion',
        episode: '01',
      ).isReleaseScoped,
      isTrue,
    );
    expect(
      ShowCatalogTarget.fromSchedule(
        bookmark,
        latestRelease: release('SP'),
      ).scopeKey,
      schedule.scopeKey,
    );
    for (final ep in ['1', '08', '02v2', 'Episode 07']) {
      expect(
        ShowCatalogTarget.fromRelease(release(ep)).scopeKey,
        schedule.scopeKey,
        reason: ep,
      );
    }
    for (final ep in [
      '0',
      '00v2',
      '05.5',
      'SP1',
      'OVA',
      'Cast Preview',
      '01-12',
    ]) {
      expect(
        ShowCatalogTarget.fromRelease(release(ep)).isReleaseScoped,
        isTrue,
        reason: ep,
      );
    }
    expect(firstSP.scopeKey, isNot(secondSP.scopeKey));
    expect(
      firstSP.scopeKey,
      ShowCatalogTarget.fromRelease(release('SP', day: 4)).scopeKey,
    );
    expect(
      const ShowCatalogTarget(
        title: 'Example OVA',
        episode: '01',
      ).isReleaseScoped,
      isTrue,
    );
    expect(
      const ShowCatalogTarget(
        title: 'Example OVA: Winter Lights',
        episode: '01',
      ).isReleaseScoped,
      isTrue,
    );
    expect(
      isCatalogCandidateCompatible(
        const ShowCatalogTarget(
          title: 'Example OVA: Winter Lights',
          episode: '01',
        ),
        const TenraiAnimeSearchResult(malId: 4, title: 'Example', type: 'TV'),
      ),
      false,
    );
    expect(
      const ShowCatalogTarget(title: 'Example S2').scopeKey,
      isNot(const ShowCatalogTarget(title: 'Example Part 2').scopeKey),
    );
  });

  test('searches the franchise for season spelling, matches Roman season even without artwork', () async {
    final api = _Api((q) => q.endsWith('S2') ? [base] : [base, sequel]);
    final c = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(api)],
    );
    final result = await resolve(c, sword);
    expect(api.queries, [
      'Tensei Shitara Ken Deshita S2',
      'Tensei Shitara Ken Deshita',
    ]);
    expect(result.entry, sequel);
    expect(result.userSelected, false);
    expect(result.evidence, isNotEmpty);
    expect(isCatalogCandidateCompatible(sword, base), false);
    expect(
      isCatalogCandidateCompatible(
        const ShowCatalogTarget(title: 'Example Part 2'),
        const TenraiAnimeSearchResult(malId: 1, title: 'Example Season 2'),
      ),
      false,
    );
    expect(
      isCatalogCandidateCompatible(
        const ShowCatalogTarget(title: 'Example'),
        const TenraiAnimeSearchResult(
          malId: 1,
          title: 'Example',
          type: 'Movie',
        ),
      ),
      false,
    );
  });
  test('generic SP offers plausible side stories without promoting a parent or unrelated season', () async {
    final nano = _Nano();
    final api = _Api(
      (_) => [
        mainSeries,
        special,
        sideStory,
        mainSeries.copyWith(malId: 2, titleEnglish: 'Link Click Season 2'),
      ],
    );
    final c = ProviderContainer.test(
      overrides: [
        tenraiApiProvider.overrideWithValue(api),
        onDeviceTextGeneratorProvider.overrideWithValue(nano),
      ],
    );
    final result = await resolve(c, firstSP);
    expect(result.entry, isNull);
    expect(result.candidates, [special, sideStory]);
    expect(nano.calls, 0);
    final extra = await resolve(
      c,
      ShowCatalogTarget.fromRelease(release('Cast Preview')),
    );
    expect(extra.candidates, isEmpty);
    expect(
      (await resolve(c, ShowCatalogTarget.fromRelease(release('5.5')))).entry,
      special,
    );
  });
  test('model-assisted match uses distinctive words and cannot introduce an incompatible season', () async {
    final nano = _Nano();
    const candidate = TenraiAnimeSearchResult(
      malId: 5,
      title: 'Blue Moon Chronicles',
    );
    final api = _Api(
      (_) => [
        candidate,
        candidate.copyWith(malId: 6, title: 'Blue Moon Chronicles Season 2'),
      ],
    );
    final c = ProviderContainer.test(
      overrides: [
        tenraiApiProvider.overrideWithValue(api),
        onDeviceTextGeneratorProvider.overrideWithValue(nano),
      ],
    );
    final result = await resolve(
      c,
      const ShowCatalogTarget(title: 'Chronicles of the Blue Moon'),
    );
    expect(nano.calls, 1);
    expect(result.entry, candidate);
    expect(result.evidence, contains('on-device'));
  });
  test(
    'identical catalog titles cannot be disambiguated by the model',
    () async {
      final nano = _Nano();
      final api = _Api((_) => [mainSeries, mainSeries.copyWith(malId: 5)]);
      final c = ProviderContainer.test(
        overrides: [
          tenraiApiProvider.overrideWithValue(api),
          onDeviceTextGeneratorProvider.overrideWithValue(nano),
        ],
      );
      final result = await resolve(
        c,
        const ShowCatalogTarget(title: 'Link Click'),
      );
      expect(result.entry, isNull);
      expect(result.candidates, hasLength(2));
      expect(nano.calls, 0);
    },
  );
  test('saving a special and opting out survive a restart independently of the regular match', () async {
    final api = _Api((_) => [mainSeries, special, sideStory]);
    final c = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(api)],
    );
    final series = ShowCatalogTarget.fromSchedule(bookmark);
    final firstProvider = showCatalogMatchProvider(firstSP);
    c.listen(firstProvider, (_, _) {});
    expect((await resolve(c, firstSP)).entry, isNull);
    final overrides = c.read(catalogMatchOverridesProvider.notifier);
    await Future.wait([
      overrides.save(series, mainSeries),
      overrides.save(firstSP, special),
      overrides.save(secondSP, null),
    ]);
    final updated = await resolve(c, firstSP);
    expect(updated.entry, special);
    expect(updated.userSelected, isTrue);
    await overrides.save(firstSP, sideStory);
    final offline = _Api((_) => throw StateError('Unexpected search'));
    final restarted = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(offline)],
    );
    expect(
      (await resolve(
        restarted,
        ShowCatalogTarget.fromRelease(release('03')),
      )).entry,
      mainSeries,
    );
    final refreshed = ShowCatalogTarget.fromRelease(release('SP', day: 3));
    expect((await resolve(restarted, refreshed)).entry, sideStory);
    final optedOut = await resolve(restarted, secondSP);
    expect(optedOut.entry, isNull);
    expect(optedOut.userSelected, isTrue);
    expect(offline.queries, isEmpty);
  });
  test('missing results are a successful lookup while a transient catalog error is retryable', () async {
    var offline = true;
    final api = _Api((_) {
      if (offline) throw const TenraiApiException('offline');
      return [];
    });
    final c = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(api)],
    );
    const target = ShowCatalogTarget(title: 'Missing');
    await expectLater(resolve(c, target), throwsA(isA<TenraiApiException>()));
    offline = false;
    c.invalidate(showCatalogMatchProvider(target));
    final result = await resolve(c, target);
    expect(result.entry, isNull);
    expect(result.userSelected, false);
    expect(result.candidates, isEmpty);
  });
  test('a slow automatic lookup cannot overwrite a correction', () async {
    final started = Completer<void>();
    final lookup = Completer<List<TenraiAnimeSearchResult>>();
    final api = _Api((_) {
      if (!started.isCompleted) started.complete();
      return lookup.future;
    });
    final container = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(api)],
    );
    const target = ShowCatalogTarget(title: 'Link Click');
    final provider = showCatalogMatchProvider(target);
    container.listen(provider, (_, _) {});
    await started.future;
    await container
        .read(catalogMatchOverridesProvider.notifier)
        .save(target, sideStory);
    expect((await resolve(container, target)).entry, sideStory);
    lookup.complete([mainSeries]);
    await container.pump();
    expect((await resolve(container, target)).entry, sideStory);
  });

  test(
    'a show added from catalog search keeps its selected entry offline',
    () async {
      final chosen = mainSeries.copyWith(
        imageUrl: 'https://example.org/poster.jpg',
      );
      final c = ProviderContainer.test();
      await c
          .read(bookmarkedSeriesProvider.notifier)
          .add(
            bookmark.copyWith(
              malId: chosen.malId,
              catalogEntry: chosen,
              source: BookmarkedShowSource.manual,
            ),
          );
      final offline = _Api((_) => throw StateError('unexpected search'));
      final restored = ProviderContainer.test(
        overrides: [
          tenraiApiProvider.overrideWithValue(offline),
          catalogEntryByIdProvider(chosen.malId)
              .overrideWith((_) => throw StateError('unexpected lookup')),
        ],
      );
      await restored.read(catalogCacheReadyProvider.future);
      final regular = ShowCatalogTarget.fromRelease(release('03'));
      expect(
        restored.read(cachedShowCatalogMatchProvider(regular))?.entry,
        chosen,
      );
      expect((await resolve(restored, regular)).userSelected, true);
      expect(restored.read(cachedShowCatalogMatchProvider(firstSP)), isNull);
      expect(offline.queries, isEmpty);
    },
  );

  test(
    'regular episodes share a persisted title and poster without a new search',
    () async {
      final entry = mainSeries.copyWith(
        title: 'Link Click',
        titleEnglish: 'Link Click English',
        imageUrl: 'https://example.org/cover.jpg',
        largeImageUrl: 'https://example.org/large.jpg',
      );
      final api = _Api((_) => [entry]);
      final c = ProviderContainer.test(
        overrides: [tenraiApiProvider.overrideWithValue(api)],
      );
      final first = ShowCatalogTarget.fromRelease(release('01'));
      final second = ShowCatalogTarget.fromRelease(release('02'));
      final matches = await Future.wait([
        resolve(c, first),
        resolve(c, second),
      ]);
      expect(matches.map((match) => match.entry), [entry, entry]);
      expect(api.queries, ['Link Click']);
      final offline = _Api(
        (_) => throw StateError('unexpected catalog search'),
      );
      final restarted = ProviderContainer.test(
        overrides: [tenraiApiProvider.overrideWithValue(offline)],
      );
      await restarted.read(catalogCacheReadyProvider.future);
      expect(
        restarted.read(cachedShowCatalogMatchProvider(second))?.entry,
        entry,
      );
      expect(restarted.read(cachedShowCatalogMatchProvider(firstSP)), isNull);
      final stored = await resolve(
        restarted,
        ShowCatalogTarget.fromSchedule(bookmark),
      );
      expect(stored.entry, entry);
      expect(stored.userSelected, isFalse);
      expect(stored.evidence, isNotEmpty);
      await restarted
          .read(catalogMatchOverridesProvider.notifier)
          .save(first, sideStory);
      expect(
        restarted.read(cachedShowCatalogMatchProvider(second))?.entry,
        sideStory,
      );
      await restarted
          .read(catalogMatchOverridesProvider.notifier)
          .save(first, null);
      expect(
        restarted.read(cachedShowCatalogMatchProvider(second))?.entry,
        isNull,
      );
      expect(offline.queries, isEmpty);
    },
  );

  test('a catalog special selected on episode 13 affects only that episode, including after restart', () async {
    final offline = _Api((_) => throw StateError('Unnecessary catalog lookup'));
    final c = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(offline)],
    );
    final choices = c.read(catalogMatchOverridesProvider.notifier);
    final ep13 = ShowCatalogTarget.fromRelease(release('13'));
    final ep12 = ShowCatalogTarget.fromRelease(release('12'));
    final season = ShowCatalogTarget.fromSchedule(bookmark);
    const ova = TenraiAnimeSearchResult(
      malId: 81,
      title: 'A winter reunion',
      type: 'OVA',
    );
    await choices.save(season, mainSeries);
    await choices.save(ep13, ova);
    expect((await resolve(c, ep13)).entry, ova);
    expect((await resolve(c, ep13)).releaseOnly, isTrue);
    expect((await resolve(c, ep12)).entry, mainSeries);
    expect((await resolve(c, season)).entry, mainSeries);
    expect((await resolve(c, ep12)).releaseOnly, isFalse);
    // A later edit from this release remains pinned to the release even if
    // the selected replacement has an ordinary catalog format.
    await choices.save(ep13, sideStory);
    await choices.save(season, mainSeries.copyWith(title: 'Updated series'));
    final reopened = ProviderContainer.test(
      overrides: [tenraiApiProvider.overrideWithValue(offline)],
    );
    expect((await resolve(reopened, ep13)).entry, sideStory);
    expect((await resolve(reopened, ep12)).entry!.title, 'Updated series');
    expect((await resolve(reopened, season)).entry!.title, 'Updated series');
    expect(offline.queries, isEmpty);
  });

  test('an explicit exact unmatched masks the season and manual release-only applies to arbitrary formats', () async {
    final c = ProviderContainer.test();
    final choices = c.read(catalogMatchOverridesProvider.notifier);
    final regular = ShowCatalogTarget.fromRelease(release('04'));
    final other = ShowCatalogTarget.fromRelease(release('05'));
    final series = ShowCatalogTarget.fromSchedule(bookmark);
    await choices.save(series, mainSeries);
    await choices.save(regular.forThisRelease, sideStory);
    c.listen(showCatalogMatchProvider(regular), (_, _) {});
    expect((await resolve(c, regular)).entry, sideStory);
    await choices.save(regular.forThisRelease, null);
    await c.pump();
    final result = await resolve(c, regular);
    expect(result.entry, isNull);
    expect(result.userSelected, isTrue);
    expect(result.releaseOnly, isTrue);
    expect((await resolve(c, other)).entry, mainSeries);
    expect((await resolve(c, series)).entry, mainSeries);
    final persisted = await c.read(catalogMatchOverridesProvider.future);
    expect(regular.effectiveOverride(persisted), (
      exists: true,
      entry: null,
      releaseOnly: true,
    ));
    expect(firstSP.effectiveOverride(persisted).exists, isFalse);
  });

  test(
    'unrelated fuzzy hits leave a regular release without suggestions',
    () async {
      const target = ShowCatalogTarget(
        title: 'Hyouken no Majutsushi ga Sekai wo Suberu S2',
      );
      final api = _Api(
        (_) => const [
          TenraiAnimeSearchResult(
            malId: 49612,
            title:
                'Ningen Fushin no Boukensha-tachi ga Sekai wo Sukuu you desu',
            titleEnglish:
                'Apparently, Disillusioned Adventurers Will Save the World',
          ),
          mainSeries,
        ],
      );
      final c = ProviderContainer.test(
        overrides: [tenraiApiProvider.overrideWithValue(api)],
      );
      final result = await resolve(c, target);
      expect(result.entry, isNull);
      expect(result.candidates, isEmpty);
    },
  );

  test(
    'suggestions keep alternate seasons, English aliases and short titles',
    () {
      expect(catalogSuggestions(sword, [base, sequel]), [base, sequel]);
      const hero = TenraiAnimeSearchResult(
        malId: 31964,
        title: 'Boku no Hero Academia',
        titleEnglish: 'My Hero Academia',
      );
      expect(
        catalogSuggestions(const ShowCatalogTarget(title: 'Hero'), [
          base,
          hero,
        ]),
        [hero],
      );
      expect(
        catalogSuggestions(const ShowCatalogTarget(title: 'My Hero Academia'), [
          hero,
        ]),
        [hero],
      );
      const numeric = TenraiAnimeSearchResult(malId: 41457, title: '86');
      expect(
        catalogSuggestions(const ShowCatalogTarget(title: '86 Part 2'), [
          numeric,
        ]),
        [numeric],
      );
    },
  );

  test(
    'previously selected bookmark ID is preserved when Tenrai is unavailable',
    () async {
      final manual = ShowCatalogTarget.fromSchedule(
        bookmark.copyWith(
          source: BookmarkedShowSource.manual,
          malId: 44074,
          imageUrl: 'cover.jpg',
        ),
      );
      final c = ProviderContainer.test(
        overrides: [
          catalogEntryByIdProvider(44074).overrideWith(
            (_) async => throw const TenraiApiException('offline'),
          ),
        ],
      );
      final result = await resolve(c, manual);
      expect(result.entry!.malId, 44074);
      expect(result.entry!.imageUrl, 'cover.jpg');
      expect(result.userSelected, true);
    },
  );
}
