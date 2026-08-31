import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

void main() {
  group('initialTransferPolicySnapshot', () {
    test(
      'defaults both opt-ins to false without blocking an unknown route',
      () {
        expect(initialTransferPolicySnapshot.allowMeteredDownloads, isFalse);
        expect(initialTransferPolicySnapshot.allowMobileData, isFalse);
        expect(initialTransferPolicySnapshot.networkCost, NetworkCost.unknown);
        expect(
          initialTransferPolicySnapshot.networkTransport,
          NetworkTransport.unknown,
        );
        expect(initialTransferPolicySnapshot.isVpn, isFalse);
        expect(
          initialTransferPolicySnapshot.reason,
          TransferSuspensionReason.none,
        );
        expect(initialTransferPolicySnapshot.suspended, isFalse);
      },
    );
  });

  group('evaluateTransferPolicy', () {
    test('obeys the complete cost, transport, VPN, and setting matrix', () {
      for (final cost in NetworkCost.values) {
        for (final transport in NetworkTransport.values) {
          for (final isVpn in <bool>[false, true]) {
            for (final allowMeteredDownloads in <bool>[false, true]) {
              for (final allowMobileData in <bool>[false, true]) {
                final networkStatus = NetworkStatus(
                  cost: cost,
                  transport: transport,
                  isVpn: isVpn,
                );
                final result = evaluateTransferPolicy(
                  networkStatus: networkStatus,
                  allowMeteredDownloads: allowMeteredDownloads,
                  allowMobileData: allowMobileData,
                );
                final expectedReason = _expectedReason(
                  networkStatus: networkStatus,
                  allowMeteredDownloads: allowMeteredDownloads,
                  allowMobileData: allowMobileData,
                );
                final caseDescription = <String, Object>{
                  'cost': cost.name,
                  'transport': transport.name,
                  'isVpn': isVpn,
                  'allowMeteredDownloads': allowMeteredDownloads,
                  'allowMobileData': allowMobileData,
                };

                expect(
                  result.reason,
                  expectedReason,
                  reason: '$caseDescription',
                );
                expect(
                  result.suspended,
                  expectedReason != TransferSuspensionReason.none,
                  reason: '$caseDescription',
                );
                expect(result.networkCost, cost, reason: '$caseDescription');
                expect(
                  result.networkTransport,
                  transport,
                  reason: '$caseDescription',
                );
                expect(result.isVpn, isVpn, reason: '$caseDescription');
                expect(
                  result.allowMeteredDownloads,
                  allowMeteredDownloads,
                  reason: '$caseDescription',
                );
                expect(
                  result.allowMobileData,
                  allowMobileData,
                  reason: '$caseDescription',
                );
              }
            }
          }
        }
      }
    });

    test('blocks unmetered cellular data until explicitly allowed', () {
      final blocked = _evaluate(status: _unmeteredCellular);
      final allowed = _evaluate(
        status: _unmeteredCellular,
        allowMobileData: true,
      );

      expect(blocked.reason, TransferSuspensionReason.mobileData);
      expect(transferPolicyStatusText(blocked), 'Waiting for Wi-Fi');
      expect(allowed.reason, TransferSuspensionReason.none);
      expect(allowed.suspended, isFalse);
      expect(transferPolicyStatusText(allowed), 'Downloading over mobile data');
    });

    test('keeps the metered and mobile-data opt-ins independent', () {
      final mobileAllowedButMeteredBlocked = _evaluate(
        status: _meteredCellular,
        allowMobileData: true,
      );
      final meteredAllowedButMobileBlocked = _evaluate(
        status: _meteredCellular,
        allowMeteredDownloads: true,
      );
      final bothAllowed = _evaluate(
        status: _meteredCellular,
        allowMeteredDownloads: true,
        allowMobileData: true,
      );

      expect(
        mobileAllowedButMeteredBlocked.reason,
        TransferSuspensionReason.metered,
      );
      expect(
        meteredAllowedButMobileBlocked.reason,
        TransferSuspensionReason.mobileData,
      );
      expect(bothAllowed.reason, TransferSuspensionReason.none);
      expect(bothAllowed.suspended, isFalse);
    });

    test(
      'blocks cellular-backed VPNs even when Android calls them unmetered',
      () {
        final result = _evaluate(
          status: const NetworkStatus(
            cost: NetworkCost.unmetered,
            transport: NetworkTransport.cellular,
            isVpn: true,
          ),
        );

        expect(result.reason, TransferSuspensionReason.mobileData);
        expect(result.suspended, isTrue);
      },
    );

    test('allows known Wi-Fi-backed VPNs subject to metering policy', () {
      final unmetered = _evaluate(
        status: const NetworkStatus(
          cost: NetworkCost.unmetered,
          transport: NetworkTransport.wifi,
          isVpn: true,
        ),
      );
      final metered = _evaluate(
        status: const NetworkStatus(
          cost: NetworkCost.metered,
          transport: NetworkTransport.wifi,
          isVpn: true,
        ),
      );

      expect(unmetered.reason, TransferSuspensionReason.none);
      expect(unmetered.suspended, isFalse);
      expect(metered.reason, TransferSuspensionReason.metered);
      expect(metered.suspended, isTrue);
    });

    test('fails closed only when a VPN underlay is unknown', () {
      const vpnUnknown = NetworkStatus(
        cost: NetworkCost.unknown,
        transport: NetworkTransport.unknown,
        isVpn: true,
      );
      const ordinaryUnknown = NetworkStatus(
        cost: NetworkCost.unknown,
        transport: NetworkTransport.unknown,
        isVpn: false,
      );

      final blockedVpn = _evaluate(status: vpnUnknown);
      final allowedVpn = _evaluate(status: vpnUnknown, allowMobileData: true);
      final allowedOrdinaryRoute = _evaluate(status: ordinaryUnknown);

      expect(blockedVpn.reason, TransferSuspensionReason.vpnTransportUnknown);
      expect(
        transferPolicyStatusText(blockedVpn),
        'Waiting for Wi-Fi (VPN transport unknown)',
      );
      expect(allowedVpn.reason, TransferSuspensionReason.none);
      expect(
        transferPolicyStatusText(allowedVpn),
        'VPN transport unknown; mobile data allowed',
      );
      expect(allowedOrdinaryRoute.reason, TransferSuspensionReason.none);
      expect(
        transferPolicyStatusText(allowedOrdinaryRoute),
        'Network cost unknown; downloads allowed',
      );
    });

    test('offline takes precedence over every opt-in and route', () {
      for (final allowMeteredDownloads in <bool>[false, true]) {
        for (final allowMobileData in <bool>[false, true]) {
          final costOffline = _evaluate(
            status: const NetworkStatus(
              cost: NetworkCost.offline,
              transport: NetworkTransport.cellular,
              isVpn: true,
            ),
            allowMeteredDownloads: allowMeteredDownloads,
            allowMobileData: allowMobileData,
          );
          final transportOffline = _evaluate(
            status: const NetworkStatus(
              cost: NetworkCost.metered,
              transport: NetworkTransport.offline,
              isVpn: true,
            ),
            allowMeteredDownloads: allowMeteredDownloads,
            allowMobileData: allowMobileData,
          );

          expect(costOffline.reason, TransferSuspensionReason.offline);
          expect(transportOffline.reason, TransferSuspensionReason.offline);
          expect(transferPolicyStatusText(costOffline), 'Waiting for network');
          expect(
            transferPolicyStatusText(transportOffline),
            'Waiting for network',
          );
        }
      }
    });
  });

  group('transfer-policy serialization', () {
    test('round trips false values and every policy input field', () {
      final snapshots = <TransferPolicySnapshot>[
        initialTransferPolicySnapshot,
        _evaluate(status: _meteredWifi),
        _evaluate(status: _unmeteredCellular),
        _evaluate(
          status: const NetworkStatus(
            cost: NetworkCost.unknown,
            transport: NetworkTransport.unknown,
            isVpn: true,
          ),
        ),
        _evaluate(
          status: _meteredCellular,
          allowMeteredDownloads: true,
          allowMobileData: true,
        ),
      ];

      for (final snapshot in snapshots) {
        final serialized = serializeTransferPolicy(snapshot);

        expect(serialized['allowMeteredDownloads'], isA<bool>());
        expect(serialized['allowMobileData'], isA<bool>());
        expect(serialized['isVpn'], isA<bool>());
        expect(serialized['networkCost'], snapshot.networkCost.name);
        expect(serialized['networkTransport'], snapshot.networkTransport.name);
        expect(serialized['reason'], snapshot.reason.name);
        expect(serialized['suspended'], snapshot.suspended);
        expect(serialized['statusText'], transferPolicyStatusText(snapshot));
        expect(deserializeTransferPolicy(serialized), snapshot);
      }
    });

    test('rejects missing, mistyped, and unknown authoritative fields', () {
      final valid = <String, dynamic>{
        'allowMeteredDownloads': false,
        'allowMobileData': false,
        'networkCost': 'unmetered',
        'networkTransport': 'wifi',
        'isVpn': false,
      };
      final malformed = <Map<String, dynamic>>[
        <String, dynamic>{...valid}..remove('allowMeteredDownloads'),
        <String, dynamic>{...valid}..remove('allowMobileData'),
        <String, dynamic>{...valid}..remove('networkCost'),
        <String, dynamic>{...valid}..remove('networkTransport'),
        <String, dynamic>{...valid}..remove('isVpn'),
        <String, dynamic>{...valid, 'allowMeteredDownloads': 0},
        <String, dynamic>{...valid, 'allowMobileData': 'false'},
        <String, dynamic>{...valid, 'networkCost': 'mobile'},
        <String, dynamic>{...valid, 'networkTransport': 'ethernet'},
        <String, dynamic>{...valid, 'isVpn': 1},
      ];

      for (final message in malformed) {
        expect(
          () => deserializeTransferPolicy(message),
          throwsFormatException,
          reason: '$message',
        );
      }
    });

    test('recomputes derived fields instead of trusting wire claims', () {
      final message = serializeTransferPolicy(_evaluate(status: _unmeteredWifi))
        ..addAll(<String, Object>{
          'reason': TransferSuspensionReason.none.name,
          'suspended': false,
          'statusText': 'Downloads allowed',
          'networkCost': NetworkCost.metered.name,
        });

      final result = deserializeTransferPolicy(message);

      expect(result.reason, TransferSuspensionReason.metered);
      expect(result.suspended, isTrue);
      expect(
        transferPolicyStatusText(result),
        'Waiting for an unmetered connection',
      );
    });
  });

  group('TransferPolicyController', () {
    test(
      'initializes, reads both persisted settings, then applies policy',
      () async {
        final events = <String>[];
        final runtime = _FakeTorrentRuntime(events: events);
        final network = _FakeNetworkStatusSource(
          _meteredCellular,
          events: events,
        );
        final snapshots = <TransferPolicySnapshot>[];
        final controller = TransferPolicyController(
          runtime: runtime,
          networkStatusSource: network,
          readAllowMeteredDownloads: () async {
            events.add('readMeteredPreference');
            return true;
          },
          readAllowMobileData: () async {
            events.add('readMobilePreference');
            return false;
          },
          onChanged: snapshots.add,
        );

        await controller.initialize();

        expect(events, <String>[
          'initialize',
          'readMeteredPreference',
          'readMobilePreference',
          'currentNetworkStatus',
          'suspend:true',
        ]);
        expect(runtime.suspensionValues, <bool>[true]);
        expect(controller.snapshot.allowMeteredDownloads, isTrue);
        expect(controller.snapshot.allowMobileData, isFalse);
        expect(controller.snapshot.reason, TransferSuspensionReason.mobileData);
        expect(snapshots, <TransferPolicySnapshot>[controller.snapshot]);

        await controller.dispose();
        await network.close();
      },
    );

    test('keeps both persisted opt-ins independent', () async {
      final runtime = _FakeTorrentRuntime();
      final network = _FakeNetworkStatusSource(_meteredCellular);
      final snapshots = <TransferPolicySnapshot>[];
      final controller = TransferPolicyController(
        runtime: runtime,
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
        onChanged: snapshots.add,
      );
      await controller.initialize();

      await controller.setAllowMeteredDownloads(true);
      expect(controller.snapshot.reason, TransferSuspensionReason.mobileData);
      await controller.setAllowMobileData(true);
      expect(controller.snapshot.reason, TransferSuspensionReason.none);
      await controller.setAllowMobileData(false);
      expect(controller.snapshot.reason, TransferSuspensionReason.mobileData);
      await controller.setAllowMeteredDownloads(false);
      expect(controller.snapshot.reason, TransferSuspensionReason.mobileData);
      await controller.setAllowMobileData(true);
      expect(controller.snapshot.reason, TransferSuspensionReason.metered);
      await controller.setAllowMeteredDownloads(true);
      expect(controller.snapshot.reason, TransferSuspensionReason.none);

      // Calls are made only when the session-wide suspension value changes.
      // TorrentTransferRuntime intentionally exposes no per-torrent operations.
      expect(runtime.suspensionValues, <bool>[true, false, true, false]);
      expect(snapshots, hasLength(7));

      await controller.dispose();
      await network.close();
    });

    test(
      'de-duplicates full statuses without dropping transport changes',
      () async {
        final runtime = _FakeTorrentRuntime();
        final network = _FakeNetworkStatusSource(_unmeteredWifi);
        final snapshots = <TransferPolicySnapshot>[];
        final controller = TransferPolicyController(
          runtime: runtime,
          networkStatusSource: network,
          readAllowMeteredDownloads: () async => false,
          readAllowMobileData: () async => false,
          onChanged: snapshots.add,
        );
        await controller.initialize();

        network.emit(_unmeteredWifi);
        await _flushNetworkEvent(controller);
        expect(snapshots, hasLength(1));

        network.emit(
          const NetworkStatus(
            cost: NetworkCost.unmetered,
            transport: NetworkTransport.wifi,
            isVpn: true,
          ),
        );
        await _flushNetworkEvent(controller);
        expect(snapshots, hasLength(2));
        expect(runtime.suspensionValues, <bool>[false]);

        network.emit(
          const NetworkStatus(
            cost: NetworkCost.unmetered,
            transport: NetworkTransport.cellular,
            isVpn: true,
          ),
        );
        await _flushNetworkEvent(controller);
        expect(controller.snapshot.networkTransport, NetworkTransport.cellular);
        expect(controller.snapshot.isVpn, isTrue);
        expect(controller.snapshot.suspended, isTrue);

        network.emit(
          const NetworkStatus(
            cost: NetworkCost.unmetered,
            transport: NetworkTransport.cellular,
            isVpn: true,
          ),
        );
        await _flushNetworkEvent(controller);
        expect(snapshots, hasLength(3));

        network.emit(_unmeteredWifi);
        await _flushNetworkEvent(controller);

        expect(runtime.suspensionValues, <bool>[false, true, false]);
        expect(snapshots, hasLength(4));
        expect(controller.snapshot.networkTransport, NetworkTransport.wifi);
        expect(controller.snapshot.suspended, isFalse);

        await controller.dispose();
        await network.close();
      },
    );

    test('serializes a transport event with a rapid setting update', () async {
      final runtime = _FakeTorrentRuntime();
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final controller = TransferPolicyController(
        runtime: runtime,
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
      );
      await controller.initialize();

      final releaseMobileSuspension = Completer<void>();
      runtime.blockNextSuspension = releaseMobileSuspension.future;
      network.emit(_unmeteredCellular);
      final allowFuture = controller.setAllowMobileData(true);

      await Future<void>.delayed(Duration.zero);
      expect(runtime.suspensionValues, <bool>[false, true]);

      releaseMobileSuspension.complete();
      await allowFuture;

      expect(runtime.suspensionValues, <bool>[false, true, false]);
      expect(controller.snapshot.allowMobileData, isTrue);
      expect(controller.snapshot.networkTransport, NetworkTransport.cellular);
      expect(controller.snapshot.suspended, isFalse);

      await controller.dispose();
      await network.close();
    });

    test('fails closed and reports a network-status stream failure', () async {
      final runtime = _FakeTorrentRuntime();
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final errors = <Object>[];
      final controller = TransferPolicyController(
        runtime: runtime,
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
        onError: (error, _) => errors.add(error),
      );
      await controller.initialize();

      network.emitError(StateError('detector disconnected'));
      await _flushNetworkEvent(controller);

      expect(controller.snapshot.reason, TransferSuspensionReason.offline);
      expect(controller.snapshot.suspended, isTrue);
      expect(runtime.suspensionValues, <bool>[false, true]);
      expect(errors, hasLength(1));

      await controller.dispose();
      await network.close();
    });

    test('reports a native gate failure from an async route change', () async {
      final runtime = _FakeTorrentRuntime();
      final network = _FakeNetworkStatusSource(_unmeteredWifi);
      final errors = <Object>[];
      final controller = TransferPolicyController(
        runtime: runtime,
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
        onError: (error, _) => errors.add(error),
      );
      await controller.initialize();
      runtime.failNextSuspension = StateError('native gate unavailable');

      network.emit(_unmeteredCellular);
      await _flushNetworkEvent(controller);

      expect(errors, hasLength(1));
      expect(controller.snapshot.networkTransport, NetworkTransport.wifi);
      expect(controller.snapshot.suspended, isFalse);

      await controller.dispose();
      await network.close();
    });

    test('recreation rereads and reapplies both persisted settings', () async {
      var allowMeteredDownloads = false;
      var allowMobileData = false;
      var meteredReadCount = 0;
      var mobileReadCount = 0;

      Future<bool> readMetered() async {
        meteredReadCount += 1;
        return allowMeteredDownloads;
      }

      Future<bool> readMobile() async {
        mobileReadCount += 1;
        return allowMobileData;
      }

      final firstRuntime = _FakeTorrentRuntime();
      final firstNetwork = _FakeNetworkStatusSource(_meteredCellular);
      final firstController = TransferPolicyController(
        runtime: firstRuntime,
        networkStatusSource: firstNetwork,
        readAllowMeteredDownloads: readMetered,
        readAllowMobileData: readMobile,
      );
      await firstController.initialize();
      expect(firstController.snapshot.suspended, isTrue);
      await firstController.dispose();
      await firstNetwork.close();

      allowMeteredDownloads = true;
      allowMobileData = true;

      final secondRuntime = _FakeTorrentRuntime();
      final secondNetwork = _FakeNetworkStatusSource(_meteredCellular);
      final secondController = TransferPolicyController(
        runtime: secondRuntime,
        networkStatusSource: secondNetwork,
        readAllowMeteredDownloads: readMetered,
        readAllowMobileData: readMobile,
      );
      await secondController.initialize();

      expect(firstRuntime.suspensionValues, <bool>[true]);
      expect(secondRuntime.suspensionValues, <bool>[false]);
      expect(secondController.snapshot.allowMeteredDownloads, isTrue);
      expect(secondController.snapshot.allowMobileData, isTrue);
      expect(secondController.snapshot.suspended, isFalse);
      expect(meteredReadCount, 2);
      expect(mobileReadCount, 2);

      await secondController.dispose();
      await secondNetwork.close();
    });

    test('reapply touches only the global transfer gate', () async {
      final runtime = _FakeTorrentRuntime();
      final network = _FakeNetworkStatusSource(_unmeteredCellular);
      final controller = TransferPolicyController(
        runtime: runtime,
        networkStatusSource: network,
        readAllowMeteredDownloads: () async => false,
        readAllowMobileData: () async => false,
      );
      await controller.initialize();

      await controller.reapply();

      expect(runtime.initializeCount, 1);
      expect(runtime.suspensionValues, <bool>[true, true]);
      expect(controller.snapshot.suspended, isTrue);

      await controller.dispose();
      await network.close();
    });
  });
}

const NetworkStatus _unmeteredWifi = NetworkStatus(
  cost: NetworkCost.unmetered,
  transport: NetworkTransport.wifi,
  isVpn: false,
);

const NetworkStatus _meteredWifi = NetworkStatus(
  cost: NetworkCost.metered,
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

TransferPolicySnapshot _evaluate({
  required NetworkStatus status,
  bool allowMeteredDownloads = false,
  bool allowMobileData = false,
}) {
  return evaluateTransferPolicy(
    networkStatus: status,
    allowMeteredDownloads: allowMeteredDownloads,
    allowMobileData: allowMobileData,
  );
}

TransferSuspensionReason _expectedReason({
  required NetworkStatus networkStatus,
  required bool allowMeteredDownloads,
  required bool allowMobileData,
}) {
  if (networkStatus.cost == NetworkCost.offline ||
      networkStatus.transport == NetworkTransport.offline) {
    return TransferSuspensionReason.offline;
  }
  if (!allowMobileData &&
      networkStatus.transport == NetworkTransport.cellular) {
    return TransferSuspensionReason.mobileData;
  }
  if (!allowMobileData &&
      networkStatus.isVpn &&
      networkStatus.transport == NetworkTransport.unknown) {
    return TransferSuspensionReason.vpnTransportUnknown;
  }
  if (!allowMeteredDownloads && networkStatus.cost == NetworkCost.metered) {
    return TransferSuspensionReason.metered;
  }
  return TransferSuspensionReason.none;
}

Future<void> _flushNetworkEvent(TransferPolicyController controller) async {
  // This no-op is enqueued after the synchronous fake stream event, so awaiting
  // it deterministically waits for the preceding network update.
  await controller.setAllowMeteredDownloads(
    controller.snapshot.allowMeteredDownloads,
  );
  // Error reporting happens in the outer async event handler after the queued
  // policy operation settles.
  await Future<void>.delayed(Duration.zero);
}

final class _FakeTorrentRuntime implements TorrentTransferRuntime {
  _FakeTorrentRuntime({this.events});

  final List<String>? events;
  final List<bool> suspensionValues = <bool>[];
  Future<void>? blockNextSuspension;
  Object? failNextSuspension;
  int initializeCount = 0;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
    events?.add('initialize');
  }

  @override
  Future<void> setTransfersSuspended(bool suspended) async {
    suspensionValues.add(suspended);
    events?.add('suspend:$suspended');
    final blocker = blockNextSuspension;
    blockNextSuspension = null;
    if (blocker != null) {
      await blocker;
    }
    final failure = failNextSuspension;
    failNextSuspension = null;
    if (failure != null) {
      throw failure;
    }
  }
}

final class _FakeNetworkStatusSource implements NetworkStatusSource {
  _FakeNetworkStatusSource(this.value, {this.events});

  NetworkStatus value;
  final List<String>? events;
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast(sync: true);

  @override
  Stream<NetworkStatus> get changes => _controller.stream;

  @override
  Future<NetworkStatus> current() async {
    events?.add('currentNetworkStatus');
    return value;
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
