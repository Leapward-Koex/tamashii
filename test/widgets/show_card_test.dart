import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';

const String _standardShowName = 'Layout Test Show';
const String _featuredShowName =
    'A Surprisingly Long Anime Show Title For Small Screens';
const String _episode = '12';

const TorrentStats _downloadingStats = TorrentStats(
  id: 41,
  downloadRate: 2 * 1024 * 1024,
  uploadRate: 128 * 1024,
  pieces: 40,
  piecesTotal: 100,
  progress: 0.4,
  seeds: 8,
  peers: 3,
  state: TorrentState.downloading,
);

const TorrentStats _completedStats = TorrentStats(
  id: 41,
  downloadRate: 0,
  uploadRate: 0,
  pieces: 100,
  piecesTotal: 100,
  progress: 1,
  seeds: 1,
  peers: 0,
  state: TorrentState.seeding,
);

void main() {
  for (final isDownloaded in [false, true]) {
    testWidgets(
      '${isDownloaded ? 'Rechecking' : 'Downloading'} chooses the highest quality',
      (tester) async {
        final manager = _RecordingForegroundTorrentManager();
        await _pumpShowCard(
          tester,
          showName: _standardShowName,
          torrentState: isDownloaded
              ? const TorrentDownloadState(
                  torrentId: 41,
                  stats: _completedStats,
                )
              : const TorrentDownloadState(),
          isDownloaded: isDownloaded,
          downloads: [
            ShowDownloadInfo(resolution: ShowResolution.r480, magnet: '480'),
            ShowDownloadInfo(resolution: ShowResolution.r1080, magnet: '1080'),
            ShowDownloadInfo(resolution: ShowResolution.r720, magnet: '720'),
          ],
          manager: manager,
        );

        final action = isDownloaded ? Icons.replay : Icons.download_rounded;
        await tester.tap(find.byIcon(action));
        await tester.pumpAndSettle();

        expect(manager.magnets, ['1080']);
      },
    );
  }

  testWidgets('recheck reports unavailable download links', (tester) async {
    final manager = _RecordingForegroundTorrentManager();
    await _pumpShowCard(
      tester,
      showName: _standardShowName,
      torrentState: const TorrentDownloadState(),
      isDownloaded: true,
      manager: manager,
    );

    await tester.tap(find.byIcon(Icons.replay));
    await tester.pumpAndSettle();

    expect(find.text('No download links available.'), findsOneWidget);
    expect(manager.magnets, isEmpty);
  });

  testWidgets('standard card keeps transfer details clear of its actions', (
    WidgetTester tester,
  ) async {
    await _pumpShowCard(
      tester,
      showName: _standardShowName,
      torrentState: const TorrentDownloadState(
        torrentId: 41,
        stats: _downloadingStats,
      ),
    );

    final statusRect = tester.getRect(
      find.byKey(ShowCard.standardStatusKey(_standardShowName)),
    );
    final actionsRect = tester.getRect(
      find.byKey(ShowCard.standardActionsKey(_standardShowName)),
    );

    expect(actionsRect.top - statusRect.bottom, greaterThanOrEqualTo(16));
    expect(
      tester
          .getSize(find.byKey(ShowCard.standardCardKey(_standardShowName)))
          .height,
      greaterThanOrEqualTo(180),
    );
    expect(find.text('DOWNLOADING'), findsOneWidget);
    final poster = find.byType(ShowImage);
    expect(tester.getSize(poster).width, 132);
    expect(
      find.ancestor(of: poster, matching: find.byType(IntrinsicHeight)),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('show-progress-fill-Layout Test Show-12'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle cards skip action settings and unrelated state updates', (
    tester,
  ) async {
    await _pumpShowCard(
      tester,
      showName: _standardShowName,
      torrentState: const TorrentDownloadState(),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShowCard)),
    );
    final mountedProviders = container.allProviders().map(
      (item) => item.provider,
    );
    expect(mountedProviders, isNot(contains(seriesFolderMappingProvider)));
    expect(mountedProviders, isNot(contains(autoGenerateFoldersProvider)));
    expect(mountedProviders, isNot(contains(downloadBasePathProvider)));

    final reveal = find.byType(StaggeredReveal);
    final initial = tester.widget(reveal);
    await container
        .read(downloadedTorrentsProvider.notifier)
        .addDownloaded('Another show-1');
    await tester.pumpAndSettle();
    expect(tester.widget(reveal), same(initial));

    await container
        .read(bookmarkedSeriesProvider.notifier)
        .add(
          const BookmarkedShowInfo(
            imageUrl: '',
            releaseDayOfWeek: DateTime.monday,
            showName: 'Another show',
          ),
        );
    await tester.pumpAndSettle();
    expect(tester.widget(reveal), same(initial));

    await container
        .read(downloadedTorrentsProvider.notifier)
        .addDownloaded('$_standardShowName-$_episode');
    await tester.pumpAndSettle();
    expect(tester.widget(reveal), isNot(same(initial)));
    expect(find.text('DONE'), findsOneWidget);
  });

  testWidgets('active standard card shows the progress track at zero', (
    WidgetTester tester,
  ) async {
    await _pumpShowCard(
      tester,
      showName: _standardShowName,
      torrentState: const TorrentDownloadState(torrentId: 41),
    );

    expect(find.byType(GlowingProgressBar), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('show-progress-fill-Layout Test Show-12'),
            ),
          )
          .width,
      0,
    );
  });

  testWidgets('completed standard card drops stale transfer details', (
    WidgetTester tester,
  ) async {
    await _pumpShowCard(
      tester,
      showName: _standardShowName,
      torrentState: const TorrentDownloadState(
        torrentId: 41,
        stats: _completedStats,
      ),
      isDownloaded: true,
    );

    expect(
      find.byKey(ShowCard.standardStatusKey(_standardShowName)),
      findsNothing,
    );
    expect(find.byType(GlowingProgressBar), findsNothing);
    expect(find.text('SEEDING'), findsNothing);
    expect(find.text('DONE'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(ShowCard.standardCardKey(_standardShowName)))
          .height,
      inInclusiveRange(180, 220),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured card makes room for active transfer details', (
    WidgetTester tester,
  ) async {
    await _pumpShowCard(
      tester,
      showName: _featuredShowName,
      torrentState: const TorrentDownloadState(
        torrentId: 41,
        stats: _downloadingStats,
      ),
      featured: true,
      surfaceSize: const Size(320, 760),
    );

    final cardRect = tester.getRect(
      find.byKey(ShowCard.featuredCardKey(_featuredShowName)),
    );
    final badgeRect = tester.getRect(
      find.byKey(ShowCard.featuredTopBadgeKey(_featuredShowName)),
    );
    final contentRect = tester.getRect(
      find.byKey(ShowCard.featuredContentKey(_featuredShowName)),
    );

    expect(cardRect.height, greaterThanOrEqualTo(424));
    expect(contentRect.top - badgeRect.bottom, greaterThanOrEqualTo(12));
    expect(cardRect.left, lessThanOrEqualTo(contentRect.left));
    expect(cardRect.right, greaterThanOrEqualTo(contentRect.right));
    expect(cardRect.bottom, greaterThanOrEqualTo(contentRect.bottom));
    expect(find.text('DOWNLOADING'), findsOneWidget);
    expect(find.byType(GlowingProgressBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed featured card returns to its compact layout', (
    WidgetTester tester,
  ) async {
    await _pumpShowCard(
      tester,
      showName: _featuredShowName,
      torrentState: const TorrentDownloadState(
        torrentId: 41,
        stats: _completedStats,
      ),
      isDownloaded: true,
      featured: true,
      surfaceSize: const Size(320, 760),
    );

    expect(
      tester
          .getSize(find.byKey(ShowCard.featuredCardKey(_featuredShowName)))
          .height,
      lessThan(380),
    );
    expect(find.text('DOWNLOADED'), findsOneWidget);
    expect(find.text('SEEDING'), findsNothing);
    expect(find.byType(GlowingProgressBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpShowCard(
  WidgetTester tester, {
  required String showName,
  required TorrentDownloadState torrentState,
  bool featured = false,
  bool isDownloaded = false,
  Size surfaceSize = const Size(390, 760),
  List<ShowDownloadInfo> downloads = const [],
  _RecordingForegroundTorrentManager? manager,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final torrentKey = '$showName-$_episode';
  final preferences = <String, Object>{
    'auto_generate_folders': true,
    'download_base_path': '',
    'series_folder_mapping': jsonEncode({showName: '/shows'}),
    'bookmarked_series': <String>[],
    'downloaded_torrents': jsonEncode(
      isDownloaded ? <String>[torrentKey] : <String>[],
    ),
  };
  SharedPreferences.setMockInitialValues(preferences);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(preferences);

  final show = ShowInfo(
    downloads: downloads,
    episode: _episode,
    imageUrl: '',
    page: 'layout-test-show',
    releaseDate: DateTime(2026, 8, 31),
    show: showName,
    timeLabel: '20:30',
    xdcc: 'xdcc',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (manager != null)
          foregroundTorrentManagerProvider.overrideWith(() => manager),
        torrentManagerProvider.overrideWithValue(
          TorrentManagerState(
            torrents: <String, TorrentDownloadState>{torrentKey: torrentState},
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShowCard(show: show, featured: featured),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingForegroundTorrentManager extends ForegroundTorrentManager {
  final magnets = <String>[];

  @override
  TorrentManagerState build() => const TorrentManagerState();

  @override
  Future<void> startDownload(
    String torrentKey,
    String magnetUri,
    String downloadPath, {
    bool redownload = false,
  }) async {
    magnets.add(magnetUri);
  }
}
