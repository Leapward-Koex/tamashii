import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/release_download_button.dart';
import 'package:tamashii/widgets/show_info_match_sheet.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/theme/paper_lantern.dart';

const special = TenraiAnimeSearchResult(
  malId: 49200,
  title: 'Shiguang Dailiren Fanwai Pian',
  titleEnglish: 'Link Click Episode 5.5',
  type: 'ONA',
  episodes: 1,
);

const bonus = TenraiAnimeSearchResult(
  malId: 199,
  title: 'A quiet afternoon',
  type: 'OVA',
);

ShowInfo episode(
  String label, {
  String imageUrl = '',
  String page = 'link-click',
  int day = 1,
  List<ShowDownloadInfo> downloads = const [],
}) => ShowInfo(
  downloads: downloads,
  episode: label,
  imageUrl: imageUrl,
  page: page,
  releaseDate: DateTime.utc(2026, 3, day),
  show: 'Link Click',
  timeLabel: '',
  xdcc: '',
);

class _Feed extends SubsPleaseApi {
  _Feed({this.results});
  final List<ShowInfo>? results;
  @override
  Future<List<ShowInfo>> getLatestShowList() async => [episode('03')];
  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async =>
      results ?? [episode('03'), episode('SP')];
  @override
  Future<String?> getShowSynopsis(String showPage) async =>
      'Two friends revisit the past through photographs.';
}

class _DelayedFeed extends _Feed {
  final search = Completer<List<ShowInfo>>();

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) => search.future;
}

class _Downloads extends ForegroundTorrentManager {
  final singles = <(String, String, String)>[];
  final batches = <(List<String>, String)>[];
  @override
  TorrentManagerState build() => const TorrentManagerState();

  @override
  Future<void> startDownload(
    String key,
    String magnet,
    String path, {
    bool redownload = false,
  }) async {
    singles.add((key, magnet, path));
  }

  @override
  Future<void> startSeriesDownloads(
    List<ShowInfo> releases,
    String path,
  ) async {
    batches.add(([for (final release in releases) release.episode], path));
  }
}

class _Catalog extends TenraiApi {
  _Catalog({this.fail = false});
  bool fail;
  final searches = <String>[];
  final ids = <int>[];
  final relatedIds = <int>[];
  List<TenraiAnimeSearchResult> relations = [];
  @override
  Future<List<TenraiAnimeSearchResult>> relatedAnime(int malId) async {
    relatedIds.add(malId);
    return relations;
  }

  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searches.add(query);
    if (fail) throw const TenraiApiException('Tenrai search timed out.');
    return query == 'side story' ? [special] : [];
  }

  @override
  Future<TenraiAnimeSearchResult?> getAnimeById(int malId) async {
    ids.add(malId);
    return [special, bonus].where((entry) => entry.malId == malId).firstOrNull;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester,
    Widget page,
    _Catalog catalog, {
    _Feed? feed,
    _Downloads? downloads,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(feed ?? _Feed()),
          if (downloads != null)
            foregroundTorrentManagerProvider.overrideWith(() => downloads),
          tenraiApiProvider.overrideWithValue(catalog),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        ],
        child: MaterialApp(theme: PaperLantern.theme, home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reader shows the catalog cover, controls and releases together',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 780);
      addTearDown(tester.view.reset);
      final release = episode(
        '03',
        downloads: [
          ShowDownloadInfo(
            resolution: ShowResolution.r1080,
            magnet: 'magnet:?xt=test',
          ),
        ],
      );
      final saved = special.copyWith(
        imageUrl: 'https://catalog.test/cover.jpg',
      );
      SharedPreferences.setMockInitialValues({
        'catalog_match.${ShowCatalogTarget.fromRelease(release).scopeKey}':
            jsonEncode(saved.toJson()),
      });
      Uri? opened;
      await open(
        tester,
        Scaffold(
          body: SizedBox(
            width: 385,
            child: ShowInfoPage.reader(
              release,
              openExternal: (uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
        _Catalog(),
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(saved.displayTitle), findsOneWidget);
      expect(
        tester.widget<ShowImage>(find.byType(ShowImage)).imageUrl,
        saved.imageUrl,
      );
      final image = tester.getSize(find.byType(ShowImage));
      expect(image.width, greaterThan(image.height));
      expect(
        tester.getRect(find.text(saved.displayTitle)).top,
        greaterThan(tester.getRect(find.byType(ShowImage)).bottom),
      );
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(find.text('Watching'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Open MyAnimeList'));
      expect(opened, Uri.parse('https://myanimelist.net/anime/49200'));
      expect(find.widgetWithText(TextButton, 'Fix match'), findsOneWidget);
      expect(find.text('Synopsis'), findsOneWidget);
      expect(find.text('Why this match?'), findsNothing);
      expect(find.textContaining('49200'), findsNothing);
      final download = find.byKey(ValueKey(release.torrentKey));
      await tester.scrollUntilVisible(download, 180);
      expect(
        tester.widget<ReleaseDownloadButton>(download).show,
        same(release),
      );
      expect(find.textContaining('1080p'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reader in [false, true]) {
    testWidgets(
      'opens and closes a full-size poster in the ${reader ? 'reader' : 'series page'}',
      (tester) async {
        final release = episode('03', imageUrl: '/feed-cover.jpg');
        const largeCover = 'https://catalog.test/large.jpg';
        if (reader) {
          SharedPreferences.setMockInitialValues({
            'catalog_match.${ShowCatalogTarget.fromRelease(release).scopeKey}':
                jsonEncode(
                  special
                      .copyWith(
                        imageUrl: 'https://catalog.test/small.jpg',
                        largeImageUrl: largeCover,
                      )
                      .toJson(),
                ),
          });
        }
        await open(
          tester,
          reader
              ? Scaffold(body: ShowInfoPage.reader(release))
              : ShowInfoPage.series(release),
          _Catalog(),
        );
        await tester.tap(find.byTooltip('View full-size poster'));
        await tester.pumpAndSettle();
        final viewer = find.byType(InteractiveViewer);
        final image = tester.widget<ShowImage>(
          find.descendant(of: viewer, matching: find.byType(ShowImage)).first,
        );
        expect(image.fit, BoxFit.contain);
        expect(image.fullResolution, isTrue);
        expect(image.imageUrl, reader ? largeCover : release.imageUrl);
        expect(image.fallbackImageUrl, release.imageUrl);
        expect(tester.getSize(viewer), tester.getSize(find.byType(Dialog)));
        if (reader) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Close poster'));
        }
        await tester.pumpAndSettle();
        expect(viewer, findsNothing);
        expect(find.byTooltip('View full-size poster'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'a release opens the series and rows download without navigating',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 1100);
      addTearDown(tester.view.reset);
      final manager = _Downloads();
      var closed = false;
      final options = [
        ShowDownloadInfo(resolution: ShowResolution.r720, magnet: '720'),
        ShowDownloadInfo(resolution: ShowResolution.r1080, magnet: '1080'),
      ];
      final specialRelease = episode('SP', downloads: options, day: 3);
      final feed = _Feed(
        results: [
          specialRelease,
          episode('10', downloads: options),
          episode('2', downloads: options),
          episode('01', page: 'different-series', downloads: options),
        ],
      );
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'series_folder_mapping': jsonEncode({
              'Link Click': '/library/Link Click',
            }),
          });
      await open(
        tester,
        ShowInfoPage.series(specialRelease, onBack: () => closed = true),
        _Catalog(),
        feed: feed,
        downloads: manager,
      );
      expect(find.text('Episode 01'), findsNothing);
      expect(find.text('SP'), findsOneWidget);
      expect(find.textContaining('1080p'), findsNothing);
      final bulk = find.widgetWithText(TextButton, 'Download all');
      await tester.ensureVisible(bulk);
      await tester.tap(bulk);
      await tester.pumpAndSettle();
      expect(manager.batches, hasLength(1));
      expect(manager.batches.single.$1, ['2', '03', '10', 'SP']);
      expect(manager.batches.single.$2, '/library/Link Click');

      await tester.ensureVisible(find.text('Episode 2'));
      final tile = find.widgetWithText(ListTile, 'Episode 2');
      final icon = find.descendant(
        of: tile,
        matching: find.byIcon(Icons.download_rounded),
      );
      final bounds = tester.getRect(tile);
      expect(tester.getCenter(icon).dy, closeTo(bounds.center.dy, 1));
      expect(
        bounds.right - tester.getCenter(icon).dx,
        closeTo(kMinInteractiveDimension / 2, 1),
      );
      await tester.tap(find.text('Episode 2'));
      await tester.pumpAndSettle();
      expect(manager.singles, [
        ('Link Click-2', '1080', '/library/Link Click'),
      ]);
      expect(find.byType(ShowInfoPage), findsOneWidget);
      expect(find.text('Series info'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      expect(closed, isTrue);
    },
  );

  testWidgets('Download all waits for the series search before queuing', (
    tester,
  ) async {
    final release = episode(
      '10',
      downloads: [
        ShowDownloadInfo(resolution: ShowResolution.r720, magnet: 'newest'),
      ],
    );
    final feed = _DelayedFeed();
    await open(tester, ShowInfoPage.series(release), _Catalog(), feed: feed);
    final button = find.widgetWithText(TextButton, 'Download all');
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    feed.search.complete([release, episode('1')]);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  testWidgets(
    'the first frame uses the saved identity and the MAL link opens that entry',
    (tester) async {
      final release = episode('03', imageUrl: '/original.jpg');
      final target = ShowCatalogTarget.fromRelease(release);
      final saved = special.copyWith(
        imageUrl: 'https://catalog.test/cover.jpg',
      );
      SharedPreferences.setMockInitialValues({
        'catalog_match.${target.scopeKey}': jsonEncode(saved.toJson()),
      });
      final api = _Catalog(fail: true);
      final container = ProviderContainer.test(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(_Feed()),
          tenraiApiProvider.overrideWithValue(api),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        ],
      );
      await container.read(catalogCacheReadyProvider.future);
      Uri? opened;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: PaperLantern.theme,
            home: ShowInfoPage.series(
              release,
              openExternal: (uri) async {
                opened = uri;
                return false;
              },
            ),
          ),
        ),
      );
      expect(find.text(saved.displayTitle), findsOneWidget);
      expect(
        tester.widget<ShowImage>(find.byType(ShowImage)).imageUrl,
        saved.imageUrl,
      );
      final link = find.text('Open MyAnimeList');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();
      expect(opened, Uri.parse('https://myanimelist.net/anime/49200'));
      expect(find.text('Unable to open MyAnimeList.'), findsOneWidget);
      expect(api.searches, isEmpty);
    },
  );

  testWidgets(
    'series title and portrait reflow together on a narrow display with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(
        tester,
        ShowInfoPage.series(episode('03', imageUrl: 'urn:poster')),
        _Catalog(),
      );
      final title = find.text('Link Click');
      final poster = find.byType(ShowImage);
      expect(
        tester.getRect(title).right,
        lessThanOrEqualTo(tester.getRect(poster).left),
      );
      expect(tester.widget<Text>(title).style?.fontFamily, PaperLantern.serif);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(title).top,
        greaterThanOrEqualTo(tester.getRect(poster).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed lookup preserves release information and can recover to an explicit no-match choice',
    (tester) async {
      final api = _Catalog(fail: true);
      await open(tester, ShowInfoPage.series(episode('SP')), api);
      expect(find.text('Catalog lookup unavailable'), findsOneWidget);
      expect(
        find.text('Two friends revisit the past through photographs.'),
        findsOneWidget,
      );
      expect(find.text('SP'), findsOneWidget);
      expect(find.text('Episode 03'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No catalog match found'), findsOneWidget);
      await tester.tap(find.text('Leave unmatched'));
      await tester.pumpAndSettle();
      expect(find.text('Kept unmatched'), findsOneWidget);
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(find.text('Watching'), findsOneWidget);
      expect(find.text('Kept unmatched'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a result requires confirmation and a changed query clears stale selection',
    (tester) async {
      final api = _Catalog();
      await open(tester, ShowInfoPage.series(episode('SP')), api);
      await tester.tap(find.text('Find a match'));
      await tester.pumpAndSettle();
      expect(find.text('Applies to this series.'), findsOneWidget);
      final field = find.byKey(ShowInfoMatchSheet.searchFieldKey);
      await tester.enterText(field, 'side story');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(49200)));
      await tester.pump();
      await tester.enterText(field, '999');
      await tester.pump();
      FilledButton saveButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use this match'),
      );
      expect(saveButton().onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('No entries found'), findsOneWidget);
      await tester.enterText(field, '49200');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(api.ids, [999, 49200]);
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(49200)));
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
      await tester.tap(find.text('Use this match'));
      await tester.pumpAndSettle();
      expect(find.text('Open MyAnimeList'), findsOneWidget);
      expect(find.text('Chosen by you'), findsOneWidget);
      expect(find.text('Watch'), findsOneWidget);
      await tester.tap(find.text('Fix match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave unmatched').last);
      await tester.pumpAndSettle();
      expect(find.text('Kept unmatched'), findsOneWidget);
    },
  );

  testWidgets(
    'reopening a match shows related posters and prioritizes airing alternatives',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 1100);
      addTearDown(tester.view.reset);
      final target = ShowCatalogTarget.fromRelease(episode('03'));
      SharedPreferences.setMockInitialValues({
        'catalog_match.${target.scopeKey}': jsonEncode(special.toJson()),
      });
      final active = bonus.copyWith(
        malId: 201,
        title: 'New season',
        imageUrl: 'https://example.org/active.jpg',
        airing: true,
      );
      final api = _Catalog()..relations = [bonus, active, special];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tenraiApiProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: PaperLantern.theme,
            home: Scaffold(body: ShowInfoMatchSheet(target: target)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final airingTile = find.byKey(ShowInfoMatchSheet.entryKey(201));
      final otherTile = find.byKey(ShowInfoMatchSheet.entryKey(199));
      expect(
        tester.getTopLeft(airingTile).dy,
        lessThan(tester.getTopLeft(otherTile).dy),
      );
      final poster = tester.widget<ShowImage>(
        find.descendant(of: airingTile, matching: find.byType(ShowImage)),
      );
      expect(poster.imageUrl, active.posterUrl);
      expect(api.relatedIds, [49200]);
      expect(api.searches, isEmpty);
    },
  );

  testWidgets(
    'manual schedule match opens its picker and retains its saved MAL entry on close',
    (tester) async {
      const saved = BookmarkedShowInfo(
        imageUrl: '',
        releaseDayOfWeek: 5,
        showName: 'My Link Click special',
        malId: 49200,
        source: BookmarkedShowSource.manual,
      );
      final api = _Catalog()
        ..relations = [special, bonus.copyWith(status: 'Currently Airing')];
      await open(
        tester,
        const ShowInfoPage.schedule(saved, openMatchPicker: true),
        api,
      );
      expect(find.byType(ShowInfoMatchSheet), findsOneWidget);
      expect(api.relatedIds, contains(49200));
      expect(find.byKey(ShowInfoMatchSheet.entryKey(199)), findsOneWidget);
      expect(find.textContaining('Currently Airing'), findsOneWidget);
      expect(find.byKey(ShowInfoMatchSheet.entryKey(49200)), findsOneWidget);
      expect(api.ids, [49200]);
      expect(api.searches, isEmpty);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Open MyAnimeList'), findsOneWidget);
      expect(find.text('Added manually · Friday'), findsOneWidget);
      expect(find.text('Releases'), findsNothing);
    },
  );

  testWidgets(
    'an episode-specific catalog choice does not replace the series identity',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 1000);
      addTearDown(tester.view.reset);
      final selected = episode('13');
      final target = ShowCatalogTarget.fromRelease(selected);
      final series = special.copyWith(malId: 44074, titleEnglish: 'Link Click');
      SharedPreferences.setMockInitialValues({
        'catalog_match.${target.scopeKey}': jsonEncode(series.toJson()),
        'catalog_match.${target.forThisRelease.scopeKey}': jsonEncode(
          bonus.toJson(),
        ),
      });
      Uri? opened;
      await open(
        tester,
        ShowInfoPage.series(
          selected,
          openExternal: (uri) async {
            opened = uri;
            return true;
          },
        ),
        _Catalog(),
      );
      await tester.tap(find.text('Open MyAnimeList'));
      expect(opened?.path, '/anime/44074');
      expect(find.text(bonus.title), findsNothing);
      expect(find.text('Episode 03'), findsOneWidget);
      await tester.tap(find.text('Fix match'));
      await tester.pumpAndSettle();
      expect(find.text('Only this release'), findsNothing);
      expect(find.text('Applies to this series.'), findsOneWidget);
    },
  );

  testWidgets(
    'a duplicate catalog selection explains the conflict and keeps the picker open',
    (tester) async {
      const first = BookmarkedShowInfo(
        imageUrl: '',
        showName: 'My show',
        releaseDayOfWeek: 2,
        source: BookmarkedShowSource.manual,
      );
      final existing = first.copyWith(showName: 'Another show', malId: 199);
      SharedPreferences.setMockInitialValues({
        'bookmarked_series': [
          for (final entry in [first, existing]) jsonEncode(entry.toJson()),
        ],
      });
      await open(
        tester,
        const ShowInfoPage.schedule(first, openMatchPicker: true),
        _Catalog(),
      );
      expect(find.text('Only this release'), findsNothing);
      await tester.enterText(
        find.byKey(ShowInfoMatchSheet.searchFieldKey),
        '199',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(199)));
      await tester.pump();
      await tester.tap(find.text('Use this match'));
      await tester.pumpAndSettle();
      expect(
        find.text('That catalog entry is already on your schedule.'),
        findsOneWidget,
      );
      expect(find.byType(ShowInfoMatchSheet), findsOneWidget);
    },
  );

  testWidgets(
    'picker fits a narrow phone and remains scrollable with a landscape keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await open(tester, ShowInfoPage.series(episode('SP')), _Catalog());
      await tester.tap(find.text('Find a match'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(640, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.widgetWithText(TextButton, 'Leave unmatched').last;
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
