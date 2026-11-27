import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/download_queue_page.dart';
import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/show_card.dart';
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
      await tester.tap(find.text('Refresh releases'));
      await tester.pumpAndSettle();
      expect(api.searches, ['Link Click', 'Link Click']);

      await tester.tap(find.byTooltip('Release options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watching only'));
      await tester.pumpAndSettle();
      expect(find.text('Watching only · Clear'), findsOneWidget);
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
