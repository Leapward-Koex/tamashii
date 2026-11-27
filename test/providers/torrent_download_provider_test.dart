import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/torrent_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory downloadDirectory;
  late FakeTorrentRuntime runtime;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<Set<String>>> downloadedSubscription;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    downloadDirectory = await Directory.systemTemp.createTemp(
      'tamashii-torrent-lifecycle-',
    );
    runtime = FakeTorrentRuntime();
    container = ProviderContainer(
      overrides: [torrentRuntimeProvider.overrideWithValue(runtime)],
    );
    downloadedSubscription = container.listen(
      downloadedTorrentsProvider,
      (_, _) {},
    );

    // Resolve persisted state before completion events so the test exercises
    // the same read-modify-write path as an already-running application.
    await container.read(downloadedTorrentsProvider.future);
  });

  tearDown(() async {
    downloadedSubscription.close();
    container.dispose();
    await runtime.dispose();
    if (await downloadDirectory.exists()) {
      await downloadDirectory.delete(recursive: true);
    }
  });

  test(
    'completed stats await one finalise before persisting completion',
    () async {
      final releaseFinalise = Completer<void>();
      runtime.onFinalise = (_) => releaseFinalise.future;
      final manager = container.read(torrentManagerProvider.notifier);
      await manager.startDownload('show-1', _magnet, downloadDirectory.path);

      runtime.emit(_completedStats);
      runtime.emit(_completedStats);
      await _waitUntil(() => runtime.finalisedIds.length == 1);

      expect(runtime.finalisedIds, <int>[FakeTorrentRuntime.torrentId]);
      expect(
        await container.read(downloadedTorrentsProvider.future),
        isNot(contains('show-1')),
      );

      releaseFinalise.complete();
      await _waitUntil(
        () =>
            container
                .read(downloadedTorrentsProvider)
                .value
                ?.contains('show-1') ??
            false,
      );

      expect(runtime.finalisedIds, <int>[FakeTorrentRuntime.torrentId]);
      expect(runtime.cancelledIds, isEmpty);
      expect(runtime.hasStatsListener, isFalse);
      final completed = container
          .read(torrentManagerProvider)
          .torrents['show-1'];
      expect(completed?.isCompleted, isTrue);
      expect(completed?.torrentId, FakeTorrentRuntime.torrentId);
      expect(completed?.errorMessage, isNull);
    },
  );

  test('stop racing completion lets finalise win and retains files', () async {
    final releaseFinalise = Completer<void>();
    runtime.onFinalise = (_) => releaseFinalise.future;
    final manager = container.read(torrentManagerProvider.notifier);
    await manager.startDownload('show-2', _magnet, downloadDirectory.path);

    runtime.emit(_completedStats);
    await _waitUntil(() => runtime.finalisedIds.length == 1);

    final stop = manager.stopDownload('show-2');
    await Future<void>.delayed(Duration.zero);
    expect(runtime.cancelledIds, isEmpty);

    releaseFinalise.complete();
    await stop;

    expect(runtime.cancelledIds, isEmpty);
    expect(
      container.read(torrentManagerProvider).torrents['show-2']?.torrentId,
      isNull,
    );
    expect(
      await container.read(downloadedTorrentsProvider.future),
      contains('show-2'),
    );
  });

  test(
    'typed finalise failure is visible and a later stats event retries',
    () async {
      runtime.onFinalise = (_) async {
        if (runtime.finalisedIds.length == 1) {
          throw const SimpleTorrentException(
            SimpleTorrentErrorCode.nativeError,
            'native finalise failed',
          );
        }
      };
      final manager = container.read(torrentManagerProvider.notifier);
      await manager.startDownload('show-3', _magnet, downloadDirectory.path);

      runtime.emit(_completedStats);
      await _waitUntil(
        () =>
            container
                .read(torrentManagerProvider)
                .torrents['show-3']
                ?.errorMessage
                ?.contains('native_error') ??
            false,
      );

      expect(runtime.hasStatsListener, isTrue);
      expect(
        await container.read(downloadedTorrentsProvider.future),
        isNot(contains('show-3')),
      );

      runtime.emit(_completedStats);
      await _waitUntil(
        () =>
            container
                .read(downloadedTorrentsProvider)
                .value
                ?.contains('show-3') ??
            false,
      );

      expect(runtime.finalisedIds, <int>[
        FakeTorrentRuntime.torrentId,
        FakeTorrentRuntime.torrentId,
      ]);
      expect(
        container.read(torrentManagerProvider).torrents['show-3']?.errorMessage,
        isNull,
      );
    },
  );

  test('bulk pause propagates native failures for page feedback', () async {
    final manager = container.read(torrentManagerProvider.notifier);
    await manager.startDownload('show-4', _magnet, downloadDirectory.path);
    runtime.onPauseAll = () async {
      throw StateError('native bulk pause failed');
    };

    await expectLater(manager.pauseAllDownloads(), throwsA(isA<StateError>()));

    expect(
      container.read(torrentManagerProvider).torrents['show-4']?.errorMessage,
      isNull,
    );
  });

  test('series starts reserve and submit eligible releases in order', () async {
    final manager = container.read(foregroundTorrentManagerProvider.notifier);
    final directory = downloadDirectory.path;
    await manager.startDownload('Show-03', _magnet, directory);
    await manager.pauseDownload('Show-03');
    await manager.startDownload('Show-04', _magnet, directory);
    await container
        .read(downloadedTorrentsProvider.notifier)
        .addDownloaded('Show-02');
    final releases = [
      _release('01'),
      _release('02'),
      _release('03'),
      _release('04'),
      _release('05', hasLink: false),
      _release('06'),
      _release('06'),
      _release('07'),
    ];
    final firstStart = Completer<void>();
    runtime.onStart = (key) async {
      if (key == 'Show-01') await firstStart.future;
      if (key == 'Show-06') throw StateError('native start failed');
    };
    final batch = manager.startSeriesDownloads(releases, directory);
    await _waitUntil(() => runtime.startedKeys.contains('Show-01'));
    final transfers = container.read(torrentManagerProvider).torrents;
    expect(transfers['Show-06']?.isLoading, isTrue);
    expect(transfers['Show-07']?.isLoading, isTrue);
    await manager.startSeriesDownloads(releases, directory);
    await manager.startDownload('Show-07', _magnet, directory);
    expect(runtime.startedKeys, ['Show-03', 'Show-04', 'Show-01']);

    firstStart.complete();
    await expectLater(batch, throwsStateError);
    expect(runtime.startedKeys, [
      'Show-03',
      'Show-04',
      'Show-01',
      'Show-06',
      'Show-07',
    ]);
    expect(
      container.read(torrentManagerProvider).torrents['Show-06']?.errorMessage,
      contains('native start failed'),
    );
    expect(
      container.read(torrentManagerProvider).torrents['Show-03']?.isPaused,
      isTrue,
    );

    runtime.onStart = null;
    await manager.startSeriesDownloads(releases, directory);
    expect(runtime.startedKeys, [
      'Show-03',
      'Show-04',
      'Show-01',
      'Show-06',
      'Show-07',
      'Show-06',
    ]);
    expect(
      container.read(torrentManagerProvider).torrents['Show-06']?.errorMessage,
      isNull,
    );
  });

  test('series folder failures release all rows for retry', () async {
    final manager = container.read(foregroundTorrentManagerProvider.notifier);
    final releases = [_release('01'), _release('02')];
    await expectLater(
      manager.startSeriesDownloads(releases, ''),
      throwsA(isA<FileSystemException>()),
    );
    expect(runtime.startedKeys, isEmpty);
    for (final entry in releases) {
      final row = container
          .read(torrentManagerProvider)
          .torrents[entry.torrentKey]!;
      expect(row.canQueue, isTrue);
      expect(row.errorMessage, contains('Choose a download folder'));
    }
    await manager.startSeriesDownloads(releases, downloadDirectory.path);
    expect(runtime.startedKeys, ['Show-01', 'Show-02']);
  });

  test(
    'only an explicit redownload restarts a completed local transfer',
    () async {
      final manager = container.read(foregroundTorrentManagerProvider.notifier);
      final release = _release('01');
      await manager.startSeriesDownloads([release], downloadDirectory.path);
      final finish = Completer<void>();
      runtime.onFinalise = (_) => finish.future;
      runtime.emit(_completedStats);
      await _waitUntil(() => runtime.finalisedIds.isNotEmpty);
      await manager.startSeriesDownloads([release], downloadDirectory.path);
      await manager.startDownload(
        release.torrentKey,
        _magnet,
        downloadDirectory.path,
      );
      final redownload = manager.startDownload(
        release.torrentKey,
        _magnet,
        downloadDirectory.path,
        redownload: true,
      );
      expect(runtime.startedKeys, [release.torrentKey]);
      finish.complete();
      await redownload;
      expect(runtime.startedKeys, [release.torrentKey, release.torrentKey]);
      expect(
        container
            .read(torrentManagerProvider)
            .torrents[release.torrentKey]
            ?.isDownloading,
        isTrue,
      );
    },
  );
}

ShowInfo _release(String episode, {bool hasLink = true}) => ShowInfo(
  downloads: [
    if (hasLink)
      ShowDownloadInfo(resolution: ShowResolution.r720, magnet: _magnet),
  ],
  episode: episode,
  imageUrl: '',
  page: 'show',
  releaseDate: DateTime.utc(2026),
  show: 'Show',
  timeLabel: '',
  xdcc: '',
);

const String _magnet =
    'magnet:?xt=urn:btih:0123456789012345678901234567890123456789';

const TorrentStats _completedStats = TorrentStats(
  id: FakeTorrentRuntime.torrentId,
  downloadRate: 0,
  uploadRate: 0,
  pieces: 8,
  piecesTotal: 8,
  progress: 1,
  seeds: 1,
  peers: 0,
  state: TorrentState.seeding,
);

Future<void> _waitUntil(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for asynchronous torrent lifecycle state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class FakeTorrentRuntime implements TorrentRuntime {
  static const int torrentId = 41;

  final StreamController<TorrentStats> _stats =
      StreamController<TorrentStats>.broadcast(sync: true);
  final List<int> finalisedIds = <int>[];
  final List<int> cancelledIds = <int>[];
  Future<void> Function(int id)? onFinalise;
  Future<void> Function()? onPauseAll;
  final List<String> startedKeys = [];
  Future<void> Function(String key)? onStart;

  bool get hasStatsListener => _stats.hasListener;

  void emit(TorrentStats stats) => _stats.add(stats);

  Future<void> dispose() => _stats.close();

  @override
  Stream<TorrentMetadata> get metadataStream =>
      const Stream<TorrentMetadata>.empty();

  @override
  Future<(int, Stream<TorrentStats>)> startAndWatch({
    required String magnet,
    required String path,
    String? displayName,
  }) async {
    startedKeys.add(displayName!);
    final id = torrentId + startedKeys.length - 1;
    await onStart?.call(displayName);
    return (id, _stats.stream);
  }

  @override
  Future<void> finalise(int id) async {
    finalisedIds.add(id);
    await onFinalise?.call(id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> pause(int id) async {}

  @override
  Future<void> pauseAll() async {
    await onPauseAll?.call();
  }

  @override
  Future<void> resume(int id) async {}

  @override
  Future<void> resumeAll() async {}
}
