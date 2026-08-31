import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final providerSource = File('lib/providers/foreground_torrent_provider.dart')
      .readAsStringSync();
  final taskSource = File('lib/services/torrent_foreground_task.dart')
      .readAsStringSync();
  final transferPolicySource = File('lib/services/transfer_policy.dart')
      .readAsStringSync();
  final androidNetworkSource = File(
    'plugins/tamashii_network_cost/android/src/main/kotlin/'
    'com/leapwardkoex/tamashii/network_cost/AndroidNetworkStateSource.kt',
  ).readAsStringSync();

  test('service readiness is single-flight and request-correlated', () {
    expect(providerSource, contains('_startOrAttachOperation'));
    expect(providerSource, contains('_serviceLifecycleQueue'));
    expect(providerSource, contains('_expectedServiceReadyRequestId'));
    expect(providerSource, contains("'requestId': requestId"));
    expect(taskSource, contains("requestId: command['requestId'] as int?"));
    expect(providerSource, contains('_serviceInstanceTracker.beginRestart()'));
    expect(taskSource, contains("'serviceInstanceId': _serviceInstanceId"));
  });

  test(
    'torrent controls cross readiness barrier and await acknowledgements',
    () {
      expect(
        providerSource,
        contains('await _startForegroundServiceIfNeeded()'),
      );
      expect(providerSource, contains('_pendingTorrentCommands[requestId]'));
      expect(
        providerSource,
        contains("expectedResponseType: 'download_paused'"),
      );
      expect(
        providerSource,
        contains("expectedResponseType: 'download_resumed'"),
      );
      expect(
        providerSource,
        contains("expectedResponseType: 'download_removed'"),
      );
      expect(taskSource, contains("'requestId': command['requestId']"));
    },
  );

  test('task commands are serialized and awaited broadcasts use snapshots', () {
    expect(taskSource, contains('_commandQueue.then((_) => command())'));
    expect(taskSource, contains('await _commandQueue;'));
    expect(taskSource, contains('Map<String, int>.of(_torrentIds)'));
    expect(taskSource, contains('Map<String, bool>.of(_completedTorrents)'));
  });

  test('repeat and service-state events refresh the transfer policy', () {
    final onRepeatEvent = _between(
      taskSource,
      'void onRepeatEvent',
      'void _updateNotificationWithProgress',
    );
    _expectOrdered(onRepeatEvent, <String>[
      '_enqueueCommand(() async {',
      'await _transferPolicyController?.refresh()',
      '_updateNotificationWithProgress()',
    ]);

    final requestServiceState = _between(
      taskSource,
      "case 'request_service_state':",
      "case 'set_test_network_status':",
    );
    _expectOrdered(requestServiceState, <String>[
      'await _transferPolicyController!.refresh()',
      'if (!_serviceReady)',
      '_sendServiceReady(',
    ]);
  });

  test('idle UI monitoring does not start the torrent service', () {
    final policyStatusProvider = _between(
      providerSource,
      'class ForegroundTransferPolicyStatus',
      '// Provider for managing the foreground service state',
    );

    expect(policyStatusProvider, contains('TransferPolicyStatusMonitor('));
    expect(policyStatusProvider, contains('monitor.initialize()'));
    expect(policyStatusProvider, contains('onResume:'));
    expect(
      policyStatusProvider,
      contains('WidgetsBinding.instance.addObserver'),
    );
    expect(
      policyStatusProvider,
      contains('WidgetsBinding.instance.removeObserver'),
    );
    expect(policyStatusProvider, contains('if (!ref.mounted)'));
    expect(policyStatusProvider, isNot(contains('startService(')));
    expect(providerSource, contains('.useLocalStatus()'));
    expect(
      providerSource,
      isNot(contains('.replace(initialTransferPolicySnapshot)')),
    );
  });

  test('engine teardown retains files and completion awaits finalise', () {
    final onDestroy = _between(
      taskSource,
      'Future<void> onDestroy',
      'void onReceiveData',
    );

    expect(onDestroy, isNot(contains('await SimpleTorrent.cancel')));
    expect(taskSource, contains('await SimpleTorrent.finalise(torrentId)'));
  });

  test('test hooks are compile-time gated and query native state', () {
    expect(
      providerSource,
      contains('TAMASHII_ENABLE_NETWORK_POLICY_TEST_HOOK=true'),
    );
    expect(taskSource, contains('SimpleTorrent.areTransfersSuspended()'));
    expect(taskSource, contains('SimpleTorrent.getState(torrentId)'));
  });

  test('both persisted policies are applied before service readiness', () {
    final onStart = _between(
      taskSource,
      'Future<void> onStart',
      'void onRepeatEvent',
    );

    expect(
      onStart,
      contains(
        'readAllowMeteredDownloads: readAllowMeteredDownloadsPreference',
      ),
    );
    expect(
      onStart,
      contains('readAllowMobileData: readAllowMobileDataPreference'),
    );
    _expectOrdered(onStart, <String>[
      'await transferPolicyController.initialize()',
      '_serviceReady = true',
      '_sendServiceReady(timestamp)',
    ]);

    final transferPolicyController = _between(
      transferPolicySource,
      'final class TransferPolicyController',
      'NetworkStatus _networkStatusFromSnapshot',
    );
    final policyInitialization = _between(
      transferPolicyController,
      'Future<void> initialize()',
      'Future<void> setAllowMeteredDownloads',
    );
    _expectOrdered(policyInitialization, <String>[
      'await _runtime.initialize()',
      'await _readAllowMeteredDownloads()',
      'await _readAllowMobileData()',
      'await _networkStatusSource.current()',
      'await _runtime.setTransfersSuspended(_snapshot.suspended)',
      '_initialized = true',
    ]);
  });

  test('network-policy test hook sends one complete network status', () {
    final providerHook = _between(
      providerSource,
      'Future<void> setTestNetworkStatus',
      'Future<bool> queryTestTransfersSuspended',
    );
    final taskHook = _between(
      taskSource,
      "case 'set_test_network_status':",
      "case 'query_test_transfers_suspended':",
    );

    expect(providerHook, contains("'type': 'set_test_network_status'"));
    expect(providerHook, contains("'networkCost': networkStatus.cost.name"));
    expect(
      providerHook,
      contains("'networkTransport': networkStatus.transport.name"),
    );
    expect(providerHook, contains("'isVpn': networkStatus.isVpn"));
    expect(
      taskHook,
      contains("final networkTransportName = command['networkTransport']"),
    );
    expect(taskHook, contains("final isVpn = command['isVpn']"));
    expect(taskHook, contains('_testNetworkStatusSource!.set('));
    expect(taskHook, contains('cost: costMatches.single'));
    expect(taskHook, contains('transport: transportMatches.single'));
    expect(taskHook, contains('isVpn: isVpn'));
    expect(
      RegExp(r'_testNetworkStatusSource!\.set\(').allMatches(taskHook),
      hasLength(1),
    );
    expect(providerSource, isNot(contains('set_test_network_cost')));
    expect(taskSource, isNot(contains('set_test_network_cost')));
  });

  test('network policy exclusively controls the global transfer gate', () {
    final policyCommand = _between(
      taskSource,
      "case 'update_transfer_policy':",
      "case 'request_service_state':",
    );

    expect(
      transferPolicySource,
      contains('SimpleTorrent.setTransfersSuspended(suspended)'),
    );
    expect(transferPolicySource, isNot(contains('SimpleTorrentHelpers')));
    expect(policyCommand, isNot(contains('_pauseAllTorrents')));
    expect(policyCommand, isNot(contains('_resumeAllTorrents')));
    expect(policyCommand, isNot(contains('SimpleTorrentHelpers.pauseAll')));
    expect(policyCommand, isNot(contains('SimpleTorrentHelpers.resumeAll')));

    // Explicit notification controls remain per-torrent operations and are
    // intentionally separate from automatic network policy changes.
    expect(taskSource, contains("id == 'pause_all'"));
    expect(taskSource, contains("id == 'resume_all'"));
  });

  test('suspended notifications use the shared policy status text', () {
    final notificationUpdate = _between(
      taskSource,
      'void _updateNotificationWithProgress()',
      '// Check if all torrents are completed',
    );

    expect(
      taskSource,
      contains("notificationTitle: 'Tamashii - Downloads paused'"),
    );
    expect(
      taskSource,
      contains('notificationText: transferPolicyStatusText(_transferPolicy)'),
    );
    _expectOrdered(notificationUpdate, <String>[
      'if (_transferPolicy.suspended)',
      'if (activeTorrents == 0)',
    ]);
  });

  test('Android route changes fail closed until fresh capabilities arrive', () {
    final onAvailable = _between(
      androidNetworkSource,
      'override fun onAvailable',
      'override fun onLost',
    );
    final onCapabilitiesChanged = _between(
      androidNetworkSource,
      'override fun onCapabilitiesChanged',
      'override fun onBlockedStatusChanged',
    );

    expect(onAvailable, contains('NetworkSnapshot(hasActiveNetwork = false)'));
    expect(onAvailable, contains('notifyChanged()'));
    expect(onCapabilitiesChanged, contains('if (callbackNetwork != network)'));
  });

  test('starts wait for policy updates and opt-out failures stop safely', () {
    final startDownload = _between(
      providerSource,
      'Future<void> startDownload',
      'Future<void> pauseDownload',
    );

    expect(
      RegExp(r'await _policyUpdateQueue;').allMatches(startDownload),
      hasLength(2),
    );
    expect(providerSource, contains('_applyPolicyUpdateWithSafetyFallback'));
    expect(providerSource, contains('await _stopForegroundService()'));
  });

  test(
    'policy acknowledgements cover both settings and full network status',
    () {
      final acknowledgement = _between(
        providerSource,
        'void _updateTransferPolicyStatus',
        'void _handleDownloadStarted',
      );

      expect(providerSource, contains('bool? _expectedAllowMeteredDownloads'));
      expect(providerSource, contains('bool? _expectedAllowMobileData'));
      expect(providerSource, contains('NetworkStatus? _expectedNetworkStatus'));
      expect(acknowledgement, contains('snapshot.allowMeteredDownloads =='));
      expect(acknowledgement, contains('snapshot.allowMobileData =='));
      expect(
        acknowledgement,
        contains('_networkStatusForPolicy(snapshot) == _expectedNetworkStatus'),
      );
      expect(acknowledgement, contains('policyCompleter.complete()'));

      for (final field in <String>[
        "'allowMeteredDownloads'",
        "'allowMobileData'",
        "'networkCost'",
        "'networkTransport'",
        "'isVpn'",
        "'suspended'",
      ]) {
        expect(transferPolicySource, contains(field));
      }
    },
  );

  test('notification permission denial is surfaced with recovery guidance', () {
    expect(
      providerSource,
      contains('requestedPermission != NotificationPermission.granted'),
    );
    expect(
      providerSource,
      contains('Enable notifications for Tamashii in Android Settings'),
    );
  });
}

void _expectOrdered(String source, List<String> snippets) {
  var previousIndex = -1;
  for (final snippet in snippets) {
    final index = source.indexOf(snippet);
    expect(
      index,
      greaterThan(previousIndex),
      reason: 'Missing/out of order: $snippet',
    );
    previousIndex = index;
  }
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Unable to locate source-contract boundaries.');
  }
  return source.substring(startIndex, endIndex);
}
