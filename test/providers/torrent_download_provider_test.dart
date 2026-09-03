import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
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
}

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
  }) async => (torrentId, _stats.stream);

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
