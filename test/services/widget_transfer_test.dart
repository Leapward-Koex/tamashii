import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/services/downloaded_episode_store.dart';
import 'package:tamashii/services/torrent_foreground_task.dart';
import 'package:tamashii/services/torrent_runtime.dart';
import 'package:tamashii/services/torrent_service_options.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii/services/widget_transfer_bridge.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tamashii/widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('widget start configuration selects the same headless entry point and notification controls', () {
    final options = torrentWidgetStartOptions();
    expect(options['callbackHandle'], isA<int>());
    expect(options['serviceId'], torrentServiceId);
    expect(
      options['notificationChannelId'],
      torrentNotificationOptions.channelId,
    );
    expect(
      options['buttons'],
      torrentServiceButtons.map((b) => b.toJson()).toList(),
    );
    expect(options['taskEventAction'], torrentTaskOptions.eventAction.toJson());
  });

  test('legacy and per-episode history coexist and folder deletion preserves other completions', () async {
    SharedPreferences.setMockInitialValues({
      'downloaded_torrents': '["Night-1","Orbit-1"]',
    });
    await Future.wait([
      writeDownloadedTorrentKey('Night-2', true),
      writeDownloadedTorrentKey('Orbit-2', true),
    ]);
    final container = ProviderContainer.test();
    expect(await container.read(downloadedTorrentsProvider.future), {
      'Night-1',
      'Orbit-1',
      'Night-2',
      'Orbit-2',
    });
    final notifier = container.read(downloadedTorrentsProvider.notifier);
    await notifier.removeByShow('Night');
    expect(await readDownloadedTorrentKeys(), {'Orbit-1', 'Orbit-2'});
    await notifier.addDownloaded('Night-1');
    await notifier.removeDownloaded('Orbit-1');
    expect(await readDownloadedTorrentKeys(), {'Night-1', 'Orbit-2'});
  });

  test('widget progress coalesces small updates and sends state changes immediately', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    var now = DateTime(2026);
    final bridge = WidgetTransferBridge(clock: () => now);
    await bridge.publish('Night-2', 'downloading', fraction: .34);
    await bridge.publish('Night-2', 'downloading', fraction: .43);
    now = now.add(const Duration(seconds: 5));
    await bridge.publish('Night-2', 'downloading', fraction: .44);
    await bridge.publish('Night-2', 'paused', fraction: .44);
    await bridge.publish('Night-2', 'completed', fraction: 1);
    expect(calls.map((c) => (c.arguments['status'], c.arguments['progress'])), [
      ('downloading', 34),
      ('downloading', 44),
      ('paused', 44),
      ('completed', 100),
    ]);
  });

  test(
    'an expired tap lets an idle service stop after the UI attach grace period',
    () async {
      const serviceMethods = MethodChannel('flutter_foreground_task/methods');
      var running = true;
      messenger.setMockMethodCallHandler(serviceMethods, (call) async {
        if (call.method == 'isRunningService') return running;
        if (call.method == 'stopService') running = false;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(serviceMethods, null),
      );
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pendingDownloads') {
          reads++;
          return [];
        }
        return null;
      });
      final runtime = _Runtime();
      final network = MutableNetworkStatusSource();
      final stops = <void Function()>[];
      final handler = TorrentTaskHandler(
        runtime: runtime,
        policyRuntime: runtime,
        network: network,
        scheduleStop: (delay, callback) {
          expect(delay, const Duration(seconds: 45));
          stops.add(callback);
          return () {};
        },
      );
      await handler.onStart(DateTime.now(), TaskStarter.developer);
      try {
        handler.onRepeatEvent(DateTime.now());
        await _until(() => stops.isNotEmpty);
        expect(running, isTrue);
        handler.onReceiveData({
          'type': 'request_service_state',
          'requestId': 1,
        });
        stops.first();
        handler.onRepeatEvent(DateTime.now());
        await _until(() => stops.length == 2);
        expect(running, isTrue);
        final previousReads = reads;
        stops.last();
        await _until(() => !running);
        expect(reads, greaterThan(previousReads));
        expect(runtime.starts, 0);
      } finally {
        await handler.onDestroy(DateTime.now(), false);
        await runtime.stats.close();
        await network.close();
      }
    },
  );

  test('a closed-app tap starts once, reports progress, and persists completion without a UI listener', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    var notified = false;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'show') notified = true;
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(notifications, null);
    });
    final folder = await Directory.systemTemp.createTemp('tamashii-widget');
    final request = {
      'torrentKey': 'Night-2',
      'magnetUri': 'sample',
      'downloadPath': folder.path,
    };
    final states = <Map>[];
    var pending = true;
    var stopped = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pendingDownloads') return [if (pending) request];
      if (call.method == 'transferState') {
        states.add(call.arguments as Map);
        pending = false;
      }
      if (call.method == 'serviceStopped') stopped = true;
      return null;
    });
    final runtime = _Runtime();
    final network = MutableNetworkStatusSource();
    final handler = TorrentTaskHandler(
      runtime: runtime,
      policyRuntime: runtime,
      network: network,
    );
    await handler.onStart(DateTime.now(), TaskStarter.developer);
    try {
      handler.onReceiveData({'type': 'start_download', ...request});
      await _until(() => states.length >= 2);
      expect(runtime.starts, 1);
      expect(states.last['status'], 'queued');
      runtime.emit(.5);
      await _until(() => states.last['status'] == 'downloading');
      expect(states.last['progress'], 50);
      network.set(
        const NetworkStatus(
          cost: NetworkCost.metered,
          transport: NetworkTransport.cellular,
          isVpn: false,
        ),
      );
      await _until(() => states.last['status'] == 'waiting');
      network.set(
        const NetworkStatus(
          cost: NetworkCost.unmetered,
          transport: NetworkTransport.wifi,
          isVpn: false,
        ),
      );
      await _until(() => states.last['status'] == 'downloading');
      handler.onReceiveData({'type': 'pause_download', ...request});
      await _until(() => states.last['status'] == 'paused');
      handler.onReceiveData({'type': 'resume_download', ...request});
      await _until(() => states.last['status'] == 'downloading');
      runtime.emit(.5, state: TorrentState.error);
      await _until(() => states.last['status'] == 'failed');
      pending = true;
      handler.onReceiveData({'type': 'widget_downloads_pending'});
      await _until(() => states.last['status'] == 'queued');
      expect(runtime.starts, 1);
      runtime.emit(1);
      await _until(() => states.last['status'] == 'completed' && notified);
      expect(await readDownloadedTorrentKeys(), contains('Night-2'));
      expect(runtime.finalisations, 1);

      // Repeat a stale launcher request after finalisation.
      pending = true;
      handler.onReceiveData({'type': 'widget_downloads_pending'});
      await _until(() => !pending);
      expect(runtime.starts, 1);
      handler.onReceiveData({
        'type': 'start_download',
        ...request,
        'redownload': true,
      });
      await _until(() => runtime.starts == 2);
    } finally {
      await handler.onDestroy(DateTime.now(), false);
      await runtime.stats.close();
      await network.close();
      await folder.delete();
    }
    expect(stopped, isTrue);
  });
}

Future<void> _until(bool Function() matches) async {
  final timer = Stopwatch()..start();
  while (!matches()) {
    if (timer.elapsed > const Duration(seconds: 3)) {
      fail('Timed out waiting for transfer');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

class _Runtime extends Fake implements TorrentRuntime, TorrentTransferRuntime {
  int starts = 0;
  int finalisations = 0;
  final stats = StreamController<TorrentStats>.broadcast();
  @override
  Stream<TorrentMetadata> get metadataStream => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setTransfersSuspended(bool value) async {}
  @override
  Future<(int, Stream<TorrentStats>)> startAndWatch({
    required String magnet,
    required String path,
    String? displayName,
  }) async => (++starts, stats.stream);
  @override
  Future<void> finalise(int id) async {
    finalisations++;
  }

  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> resume(int id) async {}

  void emit(double fraction, {TorrentState state = TorrentState.downloading}) =>
      stats.add(
        TorrentStats(
          id: starts,
          downloadRate: 0,
          uploadRate: 0,
          pieces: 0,
          piecesTotal: 1,
          progress: fraction,
          seeds: 1,
          peers: 0,
          state: state,
        ),
      );
}
