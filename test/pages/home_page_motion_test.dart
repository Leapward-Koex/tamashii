import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/download_queue_page.dart';
import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/widgets/release_reader_index.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';
import 'package:tamashii/theme/paper_lantern.dart';

class FakeSubsPleaseApi extends SubsPleaseApi {
  FakeSubsPleaseApi({required this.latestEpisodes});

  final List<ShowInfo> latestEpisodes;
  final searches = <String>[];

  @override
  Future<List<ShowInfo>> getLatestShowList() async => latestEpisodes;

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async {
    searches.add(searchTerm);
    return latestEpisodes;
  }

  @override
  Future<String?> getShowSynopsis(String showPage) async => null;
}

void main() {
  ShowInfo createEpisode({
    required String showName,
    required String episode,
    required DateTime releaseDate,
  }) {
    return ShowInfo(
      downloads: const <ShowDownloadInfo>[],
      episode: episode,
      imageUrl: '',
      page: showName.toLowerCase().replaceAll(' ', '-'),
      releaseDate: releaseDate,
      show: showName,
      timeLabel: '20:30',
      xdcc: 'xdcc',
    );
  }

  testWidgets(
    'edition offers on-demand search and parallaxes the featured poster',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auto_generate_folders': true,
        'download_base_path': '',
        'series_folder_mapping': '{}',
        'bookmarked_series': <String>[],
        'downloaded_torrents': <String>[],
        'show_filter': 'all',
      });

      final shows = <ShowInfo>[
        createEpisode(
          showName: 'Featured Show',
          episode: '12',
          releaseDate: DateTime(2026, 4, 12),
        ),
        createEpisode(
          showName: 'Second Show',
          episode: '4',
          releaseDate: DateTime(2026, 4, 11),
        ),
        createEpisode(
          showName: 'Third Show',
          episode: '9',
          releaseDate: DateTime(2026, 4, 10),
        ),
        for (var i = 0; i < 3; i++)
          createEpisode(
            showName: 'Archive $i',
            episode: '1',
            releaseDate: DateTime(2026, 4, 9 - i),
          ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subsPleaseApiProvider.overrideWithValue(
              FakeSubsPleaseApi(latestEpisodes: shows),
            ),
            torrentManagerProvider.overrideWithValue(
              const TorrentManagerState(),
            ),
          ],
          child: MaterialApp(theme: PaperLantern.theme, home: const HomePage()),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(HomePage.searchBarShellKey), findsNothing);
      expect(find.text('Release index'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expect(find.bySemanticsLabel('Tamashii'), findsOneWidget);
      await tester.tap(find.byTooltip('Search shows'));
      await tester.pumpAndSettle();

      final heroTransform = find.byKey(
        ShowCard.featuredPosterTransformKey('Featured Show'),
      );
      final hero = find.ancestor(
        of: heroTransform,
        matching: find.byType(ShowCard),
      );
      final heroBefore = tester.widget(hero);
      final fieldBefore = tester.widget(find.byType(TextField));
      final initialOffset = tester
          .widget<Transform>(heroTransform)
          .transform
          .storage[13];
      final scroll = tester
          .widget<CustomScrollView>(find.byKey(HomePage.scrollViewKey))
          .controller!;
      scroll.jumpTo(70);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Transform>(heroTransform).transform.storage[13],
        greaterThan(initialOffset),
      );
      expect(tester.widget(hero), same(heroBefore));
      expect(tester.widget(find.byType(TextField)), same(fieldBefore));
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byKey(HomePage.searchBarShellKey), findsNothing);
      expect(find.text('Featured Show'), findsWidgets);
      expect(find.text('Second Show'), findsOneWidget);
    },
  );

  final foldReleases = [
    for (var i = 0; i < 18; i++)
      createEpisode(
        showName: 'Series $i',
        episode: '02',
        releaseDate: DateTime.utc(2026, 11, 26).subtract(Duration(hours: i)),
      ),
  ];
  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(Size(width, 845));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(
            FakeSubsPleaseApi(latestEpisodes: foldReleases),
          ),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
          for (final show in foldReleases) ...[
            showCatalogMatchProvider(ShowCatalogTarget.fromRelease(show))
                .overrideWith((_) async => const ShowCatalogMatch()),
            showCatalogMatchProvider(
              ShowCatalogTarget(title: show.show, page: show.page),
            ).overrideWith((_) async => const ShowCatalogMatch()),
          ],
          filteredShowsProvider('just one')
              .overrideWith((_) async => [foldReleases.last]),
          filteredShowsProvider('missing').overrideWith((_) async => []),
        ],
        child: MaterialApp(theme: PaperLantern.theme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ShowInfo displayedSeriesSource(WidgetTester tester) =>
      tester.widget<ShowInfoPage>(find.byType(ShowInfoPage)).release!;

  testWidgets(
    'opening a series from a home card animates into place and Back returns to the feed',
    (tester) async {
      await pumpAtWidth(tester, 370);
      await tester.tap(
        find.byKey(ShowCard.featuredCardKey(foldReleases.first.show)),
      );
      await tester.pump();
      final fade = find.ancestor(
        of: find.byType(ShowInfoPage),
        matching: find.byKey(StaggeredReveal.fadeKeyForIndex(0)),
      );
      double opacity() => tester.widget<FadeTransition>(fade).opacity.value;
      expect(opacity(), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(displayedSeriesSource(tester), foldReleases.first);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ShowInfoPage), findsNothing);
      expect(find.byType(ShowCard), findsWidgets);
    },
  );

  testWidgets('reduced motion opens the series immediately', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpAtWidth(tester, 370);
    await tester.tap(
      find.byKey(ShowCard.featuredCardKey(foldReleases.first.show)),
    );
    await tester.pump();
    expect(displayedSeriesSource(tester), foldReleases.first);
    expect(find.byKey(StaggeredReveal.fadeKeyForIndex(0)), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'folding and unfolding preserve the selected release and index position',
    (tester) async {
      await pumpAtWidth(tester, 755);
      final index = find.byType(ReleaseReaderIndex);
      expect(index, findsOneWidget);
      expect(displayedSeriesSource(tester), foldReleases.first);
      final indexScrollable = find.descendant(
        of: index,
        matching: find.byType(Scrollable),
      );
      final row = find.byKey(
        ReleaseReaderIndex.rowKey(foldReleases[10].torrentKey),
      );
      await tester.scrollUntilVisible(row, 220, scrollable: indexScrollable);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final offset = tester
          .state<ScrollableState>(indexScrollable)
          .position
          .pixels;
      expect(offset, greaterThan(0));
      expect(displayedSeriesSource(tester), foldReleases[10]);

      await tester.binding.setSurfaceSize(const Size(370, 845));
      await tester.pumpAndSettle();
      expect(index, findsNothing);
      expect(find.text('Series info'), findsOneWidget);
      expect(displayedSeriesSource(tester), foldReleases[10]);
      await tester.binding.setSurfaceSize(const Size(755, 845));
      await tester.pumpAndSettle();
      expect(index, findsOneWidget);
      expect(displayedSeriesSource(tester), foldReleases[10]);
      expect(
        tester.state<ScrollableState>(indexScrollable).position.pixels,
        closeTo(offset, 1),
      );

      await tester.binding.setSurfaceSize(const Size(370, 845));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ShowInfoPage), findsNothing);
      expect(find.byType(ShowCard), findsWidgets);
      expect(
        find
            .byKey(ShowCard.standardCardKey(foldReleases[10].show))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ShowCard.standardCardKey(foldReleases[11].show)),
      );
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(755, 845));
      await tester.pumpAndSettle();
      expect(displayedSeriesSource(tester), foldReleases[11]);
    },
  );

  testWidgets(
    'wide search selects a result and clears details for empty results',
    (tester) async {
      await pumpAtWidth(tester, 600);
      await tester.tap(find.byTooltip('Search shows'));
      await tester.pumpAndSettle();
      for (final query in ['just one', 'missing']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pump(const Duration(milliseconds: 501));
        await tester.pumpAndSettle();
        if (query == 'just one') {
          expect(displayedSeriesSource(tester), foldReleases.last);
        } else {
          expect(find.text('No series found'), findsOneWidget);
          expect(find.byType(ShowInfoPage), findsNothing);
        }
      }
    },
  );

  testWidgets('larger text uses a single readable column at fold width', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.7;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAtWidth(tester, 700);
    expect(find.byType(ReleaseReaderIndex), findsNothing);
    expect(find.byType(ShowCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home opens Downloads and badges active transfers', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': true,
      'download_base_path': '',
      'series_folder_mapping': '{}',
      'bookmarked_series': <String>[],
      'downloaded_torrents': <String>[],
      'show_filter': 'all',
    });
    const report = DownloadTransferReport(
      items: <DownloadTransferItem>[
        DownloadTransferItem(
          key: 'episode-1',
          displayName: 'Episode 1',
          status: DownloadTransferStatus.downloading,
          progressFraction: 0.25,
        ),
        DownloadTransferItem(
          key: 'episode-2',
          displayName: 'Episode 2',
          status: DownloadTransferStatus.preparing,
          progressFraction: 0,
        ),
      ],
      summary: DownloadTransferSummary(
        trackedCount: 2,
        liveCount: 2,
        completedCount: 0,
        activeCount: 2,
        downloadingCount: 1,
        preparingCount: 1,
        pausedCount: 0,
        waitingForNetworkCount: 0,
        failedCount: 0,
        progressFraction: 0.125,
        progressIsEstimated: true,
        downloadRate: 0,
        uploadRate: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(
            FakeSubsPleaseApi(latestEpisodes: const <ShowInfo>[]),
          ),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
          activeDownloadCountProvider.overrideWithValue(2),
          downloadQueueProvider.overrideWithValue(report),
        ],
        child: MaterialApp(theme: PaperLantern.theme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(HomePage.downloadsButtonKey), findsOneWidget);
    final badge = tester.widget<Badge>(
      find.descendant(
        of: find.byKey(HomePage.downloadsButtonKey),
        matching: find.byType(Badge),
      ),
    );
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(HomePage.downloadsButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(DownloadQueuePage), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Episode 1'), findsOneWidget);
  });

  testWidgets(
    'release options refresh the current search and clear the watching filter',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_filter': 'all'});
      final api = FakeSubsPleaseApi(latestEpisodes: const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subsPleaseApiProvider.overrideWithValue(api),
            torrentManagerProvider.overrideWithValue(
              const TorrentManagerState(),
            ),
          ],
          child: MaterialApp(theme: PaperLantern.theme, home: const HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search shows'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Link Click');
      await tester.pump(const Duration(milliseconds: 501));
      await tester.pumpAndSettle();
      expect(api.searches, ['Link Click']);

      await tester.tap(find.byTooltip('Release options'));
      await tester.pumpAndSettle();
      void expectAlignedMenu({required bool checked}) {
        expect(
          tester
              .widget<CheckboxMenuButton>(find.byType(CheckboxMenuButton))
              .value,
          checked,
        );
        expect(
          tester.getTopLeft(find.text('Watching only')).dx,
          tester.getTopLeft(find.text('Refresh releases')).dx,
        );
      }

      expectAlignedMenu(checked: false);
      await tester.tap(find.text('Refresh releases'));
      await tester.pumpAndSettle();
      expect(api.searches, ['Link Click', 'Link Click']);

      await tester.tap(find.byTooltip('Release options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watching only'));
      await tester.pumpAndSettle();
      expect(find.text('Watching only · Clear'), findsOneWidget);
      await tester.tap(find.byTooltip('Release options'));
      await tester.pumpAndSettle();
      expectAlignedMenu(checked: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watching only · Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Watching only · Clear'), findsNothing);
    },
  );

  testWidgets('builds tabs on first visit and keeps visited state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': false,
      'show_filter': 'all',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(
            FakeSubsPleaseApi(latestEpisodes: const <ShowInfo>[]),
          ),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    final schedule = find.byType(SchedulePage, skipOffstage: false);
    final settings = find.byType(SettingsPage, skipOffstage: false);
    expect((schedule.evaluate().length, settings.evaluate().length), (0, 0));

    await tester.tap(find.byTooltip('Search shows'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Retained search');
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final settingsElement = tester.element(settings);
    expect(TickerMode.valuesOf(settingsElement).enabled, isTrue);
    expect(schedule, findsNothing);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(schedule, findsOneWidget);
    expect(tester.element(settings), same(settingsElement));
    expect(TickerMode.valuesOf(settingsElement).enabled, isFalse);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Retained search'), findsOneWidget);
  });
}
