import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';
import 'package:tamashii/widgets/show_card.dart';

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
    expect(
      find.byKey(
        const ValueKey<String>('show-progress-fill-Layout Test Show-12'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final torrentKey = '$showName-$_episode';
  SharedPreferences.setMockInitialValues(<String, Object>{
    'auto_generate_folders': true,
    'download_base_path': '',
    'series_folder_mapping': '{}',
    'bookmarked_series': <String>[],
    'downloaded_torrents': jsonEncode(
      isDownloaded ? <String>[torrentKey] : <String>[],
    ),
  });

  final show = ShowInfo(
    downloads: const <ShowDownloadInfo>[],
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
