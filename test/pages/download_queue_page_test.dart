import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/pages/download_queue_page.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii/widgets/transfer_policy_banner.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

void main() {
  test(
    'queue report adapts the desktop torrent manager through shared metrics',
    () {
      final container = ProviderContainer(
        overrides: [
          torrentManagerProvider.overrideWithValue(
            const TorrentManagerState(
              torrents: <String, TorrentDownloadState>{
                'active-episode': TorrentDownloadState(
                  torrentId: 1,
                  stats: _downloadingStats,
                ),
                'completed-episode': TorrentDownloadState(
                  torrentId: 2,
                  stats: _completedStats,
                ),
                'preparing-episode': TorrentDownloadState(isLoading: true),
                'removed-episode': TorrentDownloadState(),
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final report = container.read(downloadQueueProvider);

      expect(report.summary.trackedCount, 3);
      expect(report.summary.completedCount, 1);
      expect(report.summary.activeCount, 2);
      expect(report.items.map((item) => item.key), <String>[
        'active-episode',
        'preparing-episode',
      ]);
      expect(report.items.first.status, DownloadTransferStatus.downloading);
      expect(report.items.last.status, DownloadTransferStatus.preparing);
    },
  );

  testWidgets('shows an explicit empty live-download state', (
    WidgetTester tester,
  ) async {
    await _pumpPage(tester, report: _report());

    expect(find.byKey(DownloadQueuePage.emptyStateKey), findsOneWidget);
    expect(find.text('No active downloads'), findsOneWidget);
    expect(find.byKey(DownloadQueuePage.summaryCardKey), findsNothing);
  });

  testWidgets('groups live, paused, and failed transfers with shared metrics', (
    WidgetTester tester,
  ) async {
    final report = _report(
      items: <DownloadTransferItem>[
        _item(
          key: 'downloading',
          displayName: 'Episode 1',
          status: DownloadTransferStatus.downloading,
          progressFraction: 0.4,
          totalBytes: 100 * 1024 * 1024,
          receivedBytes: 40 * 1024 * 1024,
          downloadRate: 2 * 1024 * 1024,
          uploadRate: 64 * 1024,
          eta: const Duration(seconds: 30),
          seeds: 7,
          peers: 4,
        ),
        _item(
          key: 'paused',
          displayName: 'Episode 2',
          status: DownloadTransferStatus.paused,
          progressFraction: 0.1,
          totalBytes: 100 * 1024 * 1024,
          receivedBytes: 10 * 1024 * 1024,
        ),
        _item(
          key: 'failed',
          displayName: 'Episode 3',
          status: DownloadTransferStatus.failed,
          errorMessage: 'Torrent tracker did not respond.',
        ),
      ],
      activeCount: 1,
      downloadingCount: 1,
      pausedCount: 1,
      failedCount: 1,
      totalBytes: 200 * 1024 * 1024,
      receivedBytes: 50 * 1024 * 1024,
      remainingBytes: 150 * 1024 * 1024,
      downloadRate: 2 * 1024 * 1024,
      uploadRate: 64 * 1024,
      eta: const Duration(seconds: 30),
    );

    await _pumpPage(tester, report: report);

    expect(find.byKey(DownloadQueuePage.summaryCardKey), findsOneWidget);
    expect(find.text('Downloading'), findsWidgets);
    expect(find.text('Paused'), findsWidgets);
    expect(
      find.byKey(DownloadQueuePage.itemKey('downloading')),
      findsOneWidget,
    );
    expect(find.byKey(DownloadQueuePage.itemKey('paused')), findsOneWidget);
    expect(find.textContaining('2.0 MB/s'), findsNWidgets(2));

    await tester.scrollUntilVisible(
      find.byKey(DownloadQueuePage.itemKey('failed')),
      200,
    );

    expect(find.text('Needs attention'), findsWidgets);
    expect(find.byKey(DownloadQueuePage.itemKey('failed')), findsOneWidget);
    expect(find.text('Torrent tracker did not respond.'), findsOneWidget);
  });

  testWidgets('shows unknown transfer values as calculating rather than zero', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      report: _report(
        items: <DownloadTransferItem>[
          _item(
            key: 'preparing',
            displayName: 'Episode pending metadata',
            status: DownloadTransferStatus.preparing,
          ),
        ],
        activeCount: 1,
        preparingCount: 1,
        progressIsEstimated: true,
      ),
    );

    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Calculating…'), findsWidgets);
    expect(find.textContaining('estimated'), findsOneWidget);
  });

  testWidgets('shows policy-blocked transfers separately from manual pause', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      platform: TargetPlatform.android,
      policy: (
        allowMeteredDownloads: false,
        allowMobileData: false,
        networkCost: NetworkCost.offline,
        networkTransport: NetworkTransport.offline,
        isVpn: false,
        reason: TransferSuspensionReason.offline,
        suspended: true,
      ),
      report: _report(
        items: <DownloadTransferItem>[
          _item(
            key: 'network',
            displayName: 'Episode waiting for Wi-Fi',
            status: DownloadTransferStatus.waitingForNetwork,
          ),
        ],
        waitingForNetworkCount: 1,
      ),
    );

    expect(find.byKey(TransferPolicyBanner.bannerKey), findsOneWidget);
    expect(find.text('Waiting for network'), findsNWidgets(2));
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('global controls invoke the replaceable command boundary', (
    WidgetTester tester,
  ) async {
    final controls = _FakeDownloadQueueControls();
    await _pumpPage(
      tester,
      controls: controls,
      report: _report(
        items: <DownloadTransferItem>[
          _item(
            key: 'active',
            displayName: 'Active episode',
            status: DownloadTransferStatus.downloading,
          ),
          _item(
            key: 'paused',
            displayName: 'Paused episode',
            status: DownloadTransferStatus.paused,
          ),
        ],
        activeCount: 1,
        downloadingCount: 1,
        pausedCount: 1,
      ),
    );

    await tester.tap(find.byKey(DownloadQueuePage.pauseAllButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DownloadQueuePage.resumeAllButtonKey));
    await tester.pumpAndSettle();

    expect(controls.pauseCalls, 1);
    expect(controls.resumeCalls, 1);
  });

  testWidgets('global control errors are surfaced to the user', (
    WidgetTester tester,
  ) async {
    final controls = _FakeDownloadQueueControls(
      pauseError: StateError('The service is unavailable.'),
    );
    await _pumpPage(
      tester,
      controls: controls,
      report: _report(
        items: <DownloadTransferItem>[
          _item(
            key: 'active',
            displayName: 'Active episode',
            status: DownloadTransferStatus.downloading,
          ),
        ],
        activeCount: 1,
        downloadingCount: 1,
      ),
    );

    await tester.tap(find.byKey(DownloadQueuePage.pauseAllButtonKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not pause downloads'), findsOneWidget);
    expect(controls.pauseCalls, 1);
  });

  testWidgets('resume command errors are surfaced to the user', (
    WidgetTester tester,
  ) async {
    final controls = _FakeDownloadQueueControls(
      resumeError: StateError('The service is unavailable.'),
    );
    await _pumpPage(
      tester,
      controls: controls,
      report: _report(
        items: <DownloadTransferItem>[
          _item(
            key: 'paused',
            displayName: 'Paused episode',
            status: DownloadTransferStatus.paused,
          ),
        ],
        pausedCount: 1,
      ),
    );

    await tester.tap(find.byKey(DownloadQueuePage.resumeAllButtonKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not resume downloads'), findsOneWidget);
    expect(controls.resumeCalls, 1);
  });
}

const TorrentStats _downloadingStats = TorrentStats(
  id: 1,
  downloadRate: 2 * 1024 * 1024,
  uploadRate: 0,
  pieces: 40,
  piecesTotal: 100,
  progress: 0.4,
  seeds: 7,
  peers: 4,
  state: TorrentState.downloading,
);

const TorrentStats _completedStats = TorrentStats(
  id: 2,
  downloadRate: 0,
  uploadRate: 0,
  pieces: 100,
  piecesTotal: 100,
  progress: 1,
  seeds: 0,
  peers: 0,
  state: TorrentState.seeding,
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required DownloadTransferReport report,
  DownloadQueueControls? controls,
  TargetPlatform platform = TargetPlatform.windows,
  TransferPolicySnapshot? policy,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadQueueProvider.overrideWithValue(report),
        if (controls != null)
          downloadQueueControlsProvider.overrideWithValue(controls),
        if (policy != null)
          foregroundTransferPolicyStatusProvider.overrideWithValue(policy),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: DownloadQueuePage(platform: platform),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DownloadTransferItem _item({
  required String key,
  required String displayName,
  required DownloadTransferStatus status,
  double progressFraction = 0,
  int? totalBytes,
  int? receivedBytes,
  int? downloadRate,
  int? uploadRate,
  Duration? eta,
  int? seeds,
  int? peers,
  String? errorMessage,
}) {
  return DownloadTransferItem(
    key: key,
    displayName: displayName,
    status: status,
    progressFraction: progressFraction,
    totalBytes: totalBytes,
    receivedBytes: receivedBytes,
    remainingBytes: totalBytes == null || receivedBytes == null
        ? null
        : totalBytes - receivedBytes,
    downloadRate: downloadRate,
    uploadRate: uploadRate,
    eta: eta,
    seeds: seeds,
    peers: peers,
    errorMessage: errorMessage,
  );
}

DownloadTransferReport _report({
  List<DownloadTransferItem> items = const <DownloadTransferItem>[],
  int activeCount = 0,
  int downloadingCount = 0,
  int preparingCount = 0,
  int pausedCount = 0,
  int waitingForNetworkCount = 0,
  int failedCount = 0,
  double progressFraction = 0,
  bool progressIsEstimated = false,
  int? totalBytes,
  int? receivedBytes,
  int? remainingBytes,
  int downloadRate = 0,
  int uploadRate = 0,
  Duration? eta,
}) {
  return DownloadTransferReport(
    items: items,
    summary: DownloadTransferSummary(
      trackedCount: items.length,
      liveCount: items.length,
      completedCount: 0,
      activeCount: activeCount,
      downloadingCount: downloadingCount,
      preparingCount: preparingCount,
      pausedCount: pausedCount,
      waitingForNetworkCount: waitingForNetworkCount,
      failedCount: failedCount,
      progressFraction: progressFraction,
      progressIsEstimated: progressIsEstimated,
      totalBytes: totalBytes,
      receivedBytes: receivedBytes,
      remainingBytes: remainingBytes,
      downloadRate: downloadRate,
      uploadRate: uploadRate,
      eta: eta,
    ),
  );
}

class _FakeDownloadQueueControls implements DownloadQueueControls {
  _FakeDownloadQueueControls({this.pauseError, this.resumeError});

  final Object? pauseError;
  final Object? resumeError;
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  Future<void> pauseAllDownloads() async {
    pauseCalls++;
    if (pauseError != null) {
      throw pauseError!;
    }
  }

  @override
  Future<void> resumeAllDownloads() async {
    resumeCalls++;
    if (resumeError != null) {
      throw resumeError!;
    }
  }
}
