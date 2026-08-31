import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

void main() {
  test('TransferPolicyLifecycleObserver refreshes only on resume', () {
    var resumeCount = 0;
    final observer = TransferPolicyLifecycleObserver(
      onResume: () => resumeCount += 1,
    );

    for (final state in AppLifecycleState.values) {
      if (state != AppLifecycleState.resumed) {
        observer.didChangeAppLifecycleState(state);
      }
    }
    expect(resumeCount, 0);

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumeCount, 1);
  });

  group('TransferPolicyStatusMonitor', () {
    test(
      'queries immediately and schedules the default 30 second refresh',
      () async {
        final network = _FakeNetworkStatusSource(_meteredCellular);
        final scheduler = _FakePeriodicRefreshScheduler();
        final snapshots = <TransferPolicySnapshot>[];
        var meteredPreferenceReads = 0;
        var mobilePreferenceReads = 0;
        final monitor = TransferPolicyStatusMonitor(
          networkStatusSource: network,
          readAllowMeteredDownloads: () async {
            meteredPreferenceReads += 1;
            return true;
          },
          readAllowMobileData: () async {
            mobilePreferenceReads += 1;
            return false;
          },
          onChanged: snapshots.add,
          schedulePeriodicRefresh: scheduler.schedule,
        );

        await monitor.initialize();
        await monitor.initialize();

        expect(network.currentCallCount, 1);
        expect(network.hasListener, isTrue);
        expect(meteredPreferenceReads, 1);
        expect(mobilePreferenceReads, 1);
        expect(scheduler.scheduleCount, 1);
        expect(scheduler.interval, const Duration(seconds: 30));
        expect(snapshots, <TransferPolicySnapshot>[monitor.snapshot]);
        expect(monitor.snapshot.allowMeteredDownloads, isTrue);
        expect(monitor.snapshot.allowMobileData, isFalse);
        expect(monitor.snapshot.reason, TransferSuspensionReason.mobileData);

        await monitor.dispose();
        await network.close();
      },
    );

    test(
      'initial failure publishes a conservative status and later recovers',
      () async {
        final network = _FakeNetworkStatusSource(_unmeteredWifi)
          ..failNextCurrent = StateError('route query failed');
        final scheduler = _FakePeriodicRefreshScheduler();
        final snapshots = <TransferPolicySnapshot>[];
        final errors = <Object>[];
        final monitor = TransferPolicyStatusMonitor(
          networkStatusSource: network,
          readAllowMeteredDownloads: () async => false,
          readAllowMobileData: () async => false,
          onChanged: snapshots.add,
          onError: (error, _) => errors.add(error),
          schedulePeriodicRefresh: scheduler.schedule,
        );

        await monitor.initialize();

        expect(errors, hasLength(1));
        expect(monitor.snapshot.reason, TransferSuspensionReason.offline);
        expect(monitor.snapshot.suspended, isTrue);
        expect(
          transferPolicyStatusText(monitor.snapshot),
          'Waiting for network',
        );

        await scheduler.tick();

        expect(monitor.snapshot.networkTransport, NetworkTransport.wifi);
        expect(monitor.snapshot.suspended, isFalse);
        expect(snapshots, hasLength(2));

        await monitor.dispose();
        await network.close();
      },
    );

    test('updates from route changes and rereads both preferences', () async {
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final scheduler = _FakePeriodicRefreshScheduler();
      final snapshots = <TransferPolicySnapshot>[];
      var allowMeteredDownloads = false;
      var allowMobileData = false;
      var meteredPreferenceReads = 0;
      var mobilePreferenceReads = 0;
      final monitor = TransferPolicyStatusMonitor(
        networkStatusSource: network,
        readAllowMeteredDownloads: () async {
          meteredPreferenceReads += 1;
          return allowMeteredDownloads;
        },
        readAllowMobileData: () async {
          mobilePreferenceReads += 1;
          return allowMobileData;
        },
        onChanged: snapshots.add,
        schedulePeriodicRefresh: scheduler.schedule,
      );
      await monitor.initialize();

      allowMeteredDownloads = true;
      allowMobileData = true;
      network.emit(_meteredCellular);
      await _flushAsyncWork();

      expect(network.currentCallCount, 1);
      expect(meteredPreferenceReads, 2);
      expect(mobilePreferenceReads, 2);
      expect(snapshots, hasLength(2));
      expect(monitor.snapshot.networkTransport, NetworkTransport.cellular);
      expect(monitor.snapshot.allowMeteredDownloads, isTrue);
      expect(monitor.snapshot.allowMobileData, isTrue);
      expect(monitor.snapshot.suspended, isFalse);

      await monitor.dispose();
      await network.close();
    });

    test(
      'periodic and explicit refreshes query changes without events',
      () async {
        final network = _FakeNetworkStatusSource(_unmeteredWifi);
        final scheduler = _FakePeriodicRefreshScheduler();
        final snapshots = <TransferPolicySnapshot>[];
        final monitor = TransferPolicyStatusMonitor(
          networkStatusSource: network,
          readAllowMeteredDownloads: () async => false,
          readAllowMobileData: () async => false,
          onChanged: snapshots.add,
          schedulePeriodicRefresh: scheduler.schedule,
        );
        await monitor.initialize();

        network.value = _unmeteredCellular;
        await scheduler.tick();
        expect(network.currentCallCount, 2);
        expect(monitor.snapshot.networkTransport, NetworkTransport.cellular);
        expect(monitor.snapshot.suspended, isTrue);

        network.value = _unmeteredWifi;
        await monitor.refresh();
        expect(network.currentCallCount, 3);
        expect(monitor.snapshot.networkTransport, NetworkTransport.wifi);
        expect(monitor.snapshot.suspended, isFalse);
        expect(snapshots, hasLength(3));

        await monitor.dispose();
        await network.close();
      },
    );

    test('serializes delayed refreshes in request order', () async {
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final scheduler = _FakePeriodicRefreshScheduler();
      final snapshots = <TransferPolicySnapshot>[];
      final monitor = TransferPolicyStatusMonitor(
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
        onChanged: snapshots.add,
        schedulePeriodicRefresh: scheduler.schedule,
      );
      await monitor.initialize();
      snapshots.clear();

      final firstResult = Completer<NetworkStatus>();
      network.currentResults.add(firstResult.future);
      network.currentResults.add(Future<NetworkStatus>.value(_unmeteredWifi));
      final firstRefresh = monitor.refresh();
      await _flushAsyncWork();
      final secondRefresh = monitor.refresh();
      await _flushAsyncWork();

      expect(network.currentCallCount, 2);

      firstResult.complete(_unmeteredCellular);
      await Future.wait(<Future<void>>[firstRefresh, secondRefresh]);

      expect(network.currentCallCount, 3);
      expect(
        snapshots.map((snapshot) => snapshot.networkTransport),
        <NetworkTransport>[NetworkTransport.cellular, NetworkTransport.wifi],
      );
      expect(monitor.snapshot.networkTransport, NetworkTransport.wifi);

      await monitor.dispose();
      await network.close();
    });

    test('a newer stream failure wins over an in-flight refresh', () async {
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final scheduler = _FakePeriodicRefreshScheduler();
      final snapshots = <TransferPolicySnapshot>[];
      final errors = <Object>[];
      final monitor = TransferPolicyStatusMonitor(
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
        onChanged: snapshots.add,
        onError: (error, _) => errors.add(error),
        schedulePeriodicRefresh: scheduler.schedule,
      );
      await monitor.initialize();
      snapshots.clear();

      final currentResult = Completer<NetworkStatus>();
      network.currentResults.add(currentResult.future);
      final refresh = monitor.refresh();
      await _flushAsyncWork();

      network.emitError(StateError('network stream failed'));
      await _flushAsyncWork();
      currentResult.complete(_unmeteredWifi);
      await refresh;
      await _flushAsyncWork();

      expect(errors, hasLength(1));
      expect(monitor.snapshot.reason, TransferSuspensionReason.offline);
      expect(monitor.snapshot.suspended, isTrue);
      expect(snapshots, hasLength(1));

      await monitor.dispose();
      await network.close();
    });

    test('reports refresh failures while active', () async {
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final scheduler = _FakePeriodicRefreshScheduler();
      final errors = <Object>[];
      final monitor = TransferPolicyStatusMonitor(
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
        onError: (error, _) => errors.add(error),
        schedulePeriodicRefresh: scheduler.schedule,
      );
      await monitor.initialize();

      final failedResult = Completer<NetworkStatus>();
      network.currentResults.add(failedResult.future);
      final refresh = monitor.refresh();
      await _flushAsyncWork();
      failedResult.completeError(StateError('route query failed'));
      await refresh;

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());

      await monitor.dispose();
      await network.close();
    });

    test(
      'dispose cancels sources and suppresses in-flight notifications',
      () async {
        final network = _FakeNetworkStatusSource(_unmeteredWifi);
        final scheduler = _FakePeriodicRefreshScheduler();
        final snapshots = <TransferPolicySnapshot>[];
        final errors = <Object>[];
        final monitor = TransferPolicyStatusMonitor(
          networkStatusSource: network,
          readAllowMeteredDownloads: () async => false,
          readAllowMobileData: () async => false,
          onChanged: snapshots.add,
          onError: (error, _) => errors.add(error),
          schedulePeriodicRefresh: scheduler.schedule,
        );
        await monitor.initialize();
        snapshots.clear();

        final changedResult = Completer<NetworkStatus>();
        network.currentResults.add(changedResult.future);
        final changedRefresh = monitor.refresh();
        final queuedRefresh = monitor.refresh();
        await _flushAsyncWork();

        final dispose = monitor.dispose();
        changedResult.complete(_unmeteredCellular);
        await Future.wait(<Future<void>>[
          changedRefresh,
          queuedRefresh,
          dispose,
        ]);

        expect(scheduler.cancelCount, 1);
        expect(network.hasListener, isFalse);
        expect(network.currentCallCount, 2);
        expect(snapshots, isEmpty);
        expect(errors, isEmpty);

        network.emit(_meteredCellular);
        await scheduler.tick();
        expect(network.currentCallCount, 2);
        expect(snapshots, isEmpty);
        expect(errors, isEmpty);
        await expectLater(monitor.refresh(), throwsStateError);

        await network.close();
      },
    );
  });
}

const NetworkStatus _unmeteredWifi = NetworkStatus(
  cost: NetworkCost.unmetered,
  transport: NetworkTransport.wifi,
  isVpn: false,
);

const NetworkStatus _unmeteredCellular = NetworkStatus(
  cost: NetworkCost.unmetered,
  transport: NetworkTransport.cellular,
  isVpn: false,
);

const NetworkStatus _meteredCellular = NetworkStatus(
  cost: NetworkCost.metered,
  transport: NetworkTransport.cellular,
  isVpn: false,
);

Future<void> _flushAsyncWork() async {
  for (var index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _FakePeriodicRefreshScheduler {
  Duration? interval;
  Future<void> Function()? _refresh;
  int scheduleCount = 0;
  int cancelCount = 0;

  TransferPolicyRefreshCancellation schedule(
    Duration nextInterval,
    Future<void> Function() refresh,
  ) {
    interval = nextInterval;
    _refresh = refresh;
    scheduleCount += 1;
    return () {
      cancelCount += 1;
      _refresh = null;
    };
  }

  Future<void> tick() => _refresh?.call() ?? Future<void>.value();
}

final class _FakeNetworkStatusSource implements NetworkStatusSource {
  _FakeNetworkStatusSource(this.value);

  NetworkStatus value;
  final List<Future<NetworkStatus>> currentResults = <Future<NetworkStatus>>[];
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast(sync: true);
  int currentCallCount = 0;
  Object? failNextCurrent;

  bool get hasListener => _controller.hasListener;

  @override
  Stream<NetworkStatus> get changes => _controller.stream;

  @override
  Future<NetworkStatus> current() {
    currentCallCount += 1;
    final failure = failNextCurrent;
    failNextCurrent = null;
    if (failure != null) {
      return Future<NetworkStatus>.error(failure);
    }
    if (currentResults.isNotEmpty) {
      return currentResults.removeAt(0);
    }
    return Future<NetworkStatus>.value(value);
  }

  void emit(NetworkStatus next) {
    value = next;
    _controller.add(next);
  }

  void emitError(Object error) {
    _controller.addError(error, StackTrace.current);
  }

  Future<void> close() => _controller.close();
}
