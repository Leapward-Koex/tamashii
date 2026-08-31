// lib/providers/foreground_torrent_provider.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/foreground_service_lifecycle.dart';
import 'package:tamashii/services/notification_service.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/services/torrent_foreground_task.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

part 'foreground_torrent_provider.g.dart';

class ForegroundTorrentCommandException implements Exception {
  const ForegroundTorrentCommandException({
    required this.operation,
    required this.torrentKey,
    required this.message,
  });

  final String operation;
  final String torrentKey;
  final String message;

  @override
  String toString() => 'Unable to $operation torrent "$torrentKey": $message';
}

class ForegroundNotificationPermissionException implements Exception {
  const ForegroundNotificationPermissionException();

  @override
  String toString() =>
      'Notification permission is required for background downloads. '
      'Enable notifications for Tamashii in Android Settings, then start the '
      'download again.';
}

class _PendingTorrentCommand {
  _PendingTorrentCommand({
    required this.operation,
    required this.torrentKey,
    required this.expectedResponseType,
  });

  final String operation;
  final String torrentKey;
  final String expectedResponseType;
  final Completer<void> completer = Completer<void>();
}

@Riverpod(keepAlive: true)
class ForegroundTransferPolicyStatus extends _$ForegroundTransferPolicyStatus {
  TransferPolicyStatusMonitor? _localMonitor;
  bool _serviceSnapshotIsAuthoritative = false;

  @override
  TransferPolicySnapshot build() {
    if (Platform.isAndroid) {
      final monitor = TransferPolicyStatusMonitor(
        networkStatusSource: const PluginNetworkStatusSource(),
        readAllowMeteredDownloads: readAllowMeteredDownloadsPreference,
        readAllowMobileData: readAllowMobileDataPreference,
        onChanged: _replaceFromLocalMonitor,
        onError: (error, stackTrace) {
          print(
            'Unable to refresh the foreground transfer policy: '
            '$error\n$stackTrace',
          );
        },
      );
      final lifecycleObserver = TransferPolicyLifecycleObserver(
        onResume: () => unawaited(refresh()),
      );
      _localMonitor = monitor;
      WidgetsBinding.instance.addObserver(lifecycleObserver);

      ref.onDispose(() {
        WidgetsBinding.instance.removeObserver(lifecycleObserver);
        unawaited(monitor.dispose());
      });
      unawaited(monitor.initialize());
    }

    return initialTransferPolicySnapshot;
  }

  void _replaceFromLocalMonitor(TransferPolicySnapshot snapshot) {
    if (!_serviceSnapshotIsAuthoritative) {
      _replaceState(snapshot);
    }
  }

  /// Applies an authoritative status acknowledgement from the live service.
  void replace(TransferPolicySnapshot snapshot) {
    _serviceSnapshotIsAuthoritative = true;
    _replaceState(snapshot);
  }

  /// Returns display ownership to the UI monitor after the service stops.
  Future<void> useLocalStatus() async {
    _serviceSnapshotIsAuthoritative = false;
    await refresh();
  }

  /// Re-queries status for page loads, app resumes, and explicit refreshes.
  Future<void> refresh() async {
    final monitor = _localMonitor;
    if (monitor == null) {
      return;
    }

    await monitor.refresh();
    if (!ref.mounted) {
      return;
    }
    // The monitor de-duplicates unchanged snapshots. Publish its latest value
    // explicitly when switching back from an authoritative service snapshot.
    if (!_serviceSnapshotIsAuthoritative) {
      _replaceState(monitor.snapshot);
    }
  }

  void _replaceState(TransferPolicySnapshot snapshot) {
    if (state != snapshot) {
      state = snapshot;
    }
  }
}

// Provider for managing the foreground service state
@Riverpod(keepAlive: true)
class ForegroundTorrentManager extends _$ForegroundTorrentManager {
  bool _isServiceRunning = false;
  Future<void>? _initialization;
  Future<void> _serviceLifecycleQueue = Future<void>.value();
  Future<void>? _startOrAttachOperation;
  Completer<void>? _serviceReadyCompleter;
  int _nextServiceRequestId = 1;
  int? _expectedServiceReadyRequestId;
  final ForegroundServiceInstanceTracker _serviceInstanceTracker =
      ForegroundServiceInstanceTracker();
  Future<void> _policyUpdateQueue = Future<void>.value();
  Completer<void>? _policyUpdateCompleter;
  bool? _expectedAllowMeteredDownloads;
  bool? _expectedAllowMobileData;
  NetworkStatus? _expectedNetworkStatus;
  final Map<int, Completer<Map<String, dynamic>>> _testQueryCompleters = {};
  final Map<int, _PendingTorrentCommand> _pendingTorrentCommands = {};
  final Map<String, String> _downloadPaths = {}; // torrentKey -> downloadPath

  @override
  TorrentManagerState build() {
    if (Platform.isAndroid) {
      // Add callback to receive data from the foreground service
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

      ref.onDispose(() {
        FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
        _failPendingTorrentCommands(
          StateError('Torrent manager was disposed.'),
        );
      });

      // Initialize communication and attach to an existing service, but do not
      // start a new service until the first download.
      _initialization = _initializeWithoutStarting();
    }

    return const TorrentManagerState();
  }

  Future<void> _initializeWithoutStarting() async {
    if (!Platform.isAndroid) return;

    // Initialize communication port first
    FlutterForegroundTask.initCommunicationPort();

    // Initialize the service configuration but don't start it
    _initService();

    // A service can outlive the UI engine. Attach to it in place so active
    // downloads are never disrupted merely because the app was reopened.
    if (await FlutterForegroundTask.isRunningService) {
      _isServiceRunning = true;
      try {
        await _requestServiceReady(allowRestart: true);
      } catch (error) {
        // A subsequent download start retries attachment and surfaces the
        // failure in its torrent state rather than creating an unhandled
        // asynchronous error during provider construction.
        _isServiceRunning = false;
        print('❌ Failed to attach to torrent service: $error');
      }
    }
  }

  // Callback to receive data sent from the TaskHandler
  void _onReceiveTaskData(Object data) {
    print('📨 Received data from foreground service: $data');
    handleServiceData(data);
  }

  Future<void> _startForegroundServiceIfNeeded() {
    if (!Platform.isAndroid) {
      return Future<void>.value();
    }

    final existingOperation = _startOrAttachOperation;
    if (existingOperation != null) {
      return existingOperation;
    }

    late final Future<void> operation;
    operation = _runServiceLifecycle(_startOrAttachService).whenComplete(() {
      if (identical(_startOrAttachOperation, operation)) {
        _startOrAttachOperation = null;
      }
    });
    _startOrAttachOperation = operation;
    return operation;
  }

  Future<void> _startOrAttachService() async {
    if (!Platform.isAndroid) return;

    await (_initialization ?? Future<void>.value());

    if (await FlutterForegroundTask.isRunningService) {
      _isServiceRunning = true;
      await _requestServiceReady(allowRestart: true);
    } else {
      await _requestPermissions();
      _serviceReadyCompleter = Completer<void>();
      _expectedServiceReadyRequestId = null;
      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Tamashii - Starting Downloads',
        notificationText: 'Initializing torrent downloads...',
        notificationButtons: [
          const NotificationButton(id: 'pause_all', text: 'Pause All'),
          const NotificationButton(id: 'resume_all', text: 'Resume All'),
        ],
        callback: startTorrentCallback,
      );
      _throwIfServiceRequestFailed(result);
      _isServiceRunning = true;
      await _waitUntilServiceReady();
    }
  }

  Future<void> _requestServiceReady({required bool allowRestart}) async {
    final requestId = _nextServiceRequestId++;
    _serviceReadyCompleter = Completer<void>();
    _expectedServiceReadyRequestId = requestId;
    FlutterForegroundTask.sendDataToTask({
      'type': 'request_service_state',
      'requestId': requestId,
    });

    try {
      await _waitUntilServiceReady();
    } on TimeoutException {
      if (!allowRestart) {
        rethrow;
      }

      // A running service with no responsive handler is stale. Restart once,
      // then require the recreated manager to initialize and reapply policy.
      _serviceInstanceTracker.beginRestart();
      _serviceReadyCompleter = Completer<void>();
      _expectedServiceReadyRequestId = null;
      final result = await FlutterForegroundTask.restartService();
      _throwIfServiceRequestFailed(result);
      await _waitUntilServiceReady();
    }
  }

  Future<void> _runServiceLifecycle(Future<void> Function() operation) {
    final result = _serviceLifecycleQueue.then((_) => operation());
    _serviceLifecycleQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _waitUntilServiceReady() async {
    final completer = _serviceReadyCompleter;
    if (completer == null) {
      throw StateError('Torrent service readiness was not initialized.');
    }
    await completer.future.timeout(const Duration(seconds: 15));
  }

  void _throwIfServiceRequestFailed(ServiceRequestResult result) {
    if (result case ServiceRequestFailure(:final error)) {
      _isServiceRunning = false;
      throw StateError('Torrent service request failed: $error');
    }
  }

  Future<void> _requestPermissions() async {
    if (networkPolicyTestHookEnabled) {
      return;
    }

    // Request notification permission
    if (Platform.isAndroid) {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        final requestedPermission =
            await FlutterForegroundTask.requestNotificationPermission();
        if (requestedPermission != NotificationPermission.granted) {
          throw const ForegroundNotificationPermissionException();
        }
      }

      // Request battery optimization exemption
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tamashii_torrent_service',
        channelName: 'Tamashii Torrent Service',
        channelDescription: 'Manages torrent downloads in the background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          5000,
        ), // Update every 5 seconds
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _stopForegroundService() {
    return _runServiceLifecycle(_stopForegroundServiceNow);
  }

  Future<void> _stopForegroundServiceNow() async {
    if (!Platform.isAndroid) return;

    if (_isServiceRunning || await FlutterForegroundTask.isRunningService) {
      _serviceInstanceTracker.retireCurrent();
      final result = await FlutterForegroundTask.stopService();
      _throwIfServiceRequestFailed(result);
      _isServiceRunning = false;
      _serviceReadyCompleter = null;
      _expectedServiceReadyRequestId = null;
      _failPendingTestQueries(
        StateError('Torrent service stopped before the query completed.'),
      );
      _failPendingTorrentCommands(StateError('Torrent service stopped.'));
    }
    await ref
        .read(foregroundTransferPolicyStatusProvider.notifier)
        .useLocalStatus();
  }

  /// Applies a persisted setting change to the live background manager.
  ///
  /// This does not start a service just to apply policy. A future service reads
  /// the uncached preference before accepting its first torrent.
  Future<void> setAllowMeteredDownloads(bool allow) async {
    if (!Platform.isAndroid) {
      return;
    }

    final sendOperation = _policyUpdateQueue.then(
      (_) => _sendAllowMeteredDownloads(allow),
    );
    final operation = _applyPolicyUpdateWithSafetyFallback(
      sendOperation,
      restrictsTransfers: !allow,
      settingName: 'metered-network',
    );
    _policyUpdateQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await operation;
  }

  Future<void> _sendAllowMeteredDownloads(bool allow) async {
    await (_initialization ?? Future<void>.value());
    await (_startOrAttachOperation ?? Future<void>.value());
    if (!await FlutterForegroundTask.isRunningService) {
      _isServiceRunning = false;
      await ref
          .read(foregroundTransferPolicyStatusProvider.notifier)
          .useLocalStatus();
      return;
    }

    _isServiceRunning = true;
    if (!(_serviceReadyCompleter?.isCompleted ?? false)) {
      await _runServiceLifecycle(() async {
        if (await FlutterForegroundTask.isRunningService) {
          await _requestServiceReady(allowRestart: true);
        }
      });
    }
    final currentPolicy = ref.read(foregroundTransferPolicyStatusProvider);
    if (currentPolicy.allowMeteredDownloads == allow) {
      return;
    }

    _expectedAllowMeteredDownloads = allow;
    _expectedAllowMobileData = null;
    _expectedNetworkStatus = null;
    _policyUpdateCompleter = Completer<void>();
    FlutterForegroundTask.sendDataToTask({
      'type': 'update_transfer_policy',
      'allowMeteredDownloads': allow,
    });
    try {
      await _policyUpdateCompleter!.future.timeout(const Duration(seconds: 15));
    } finally {
      _policyUpdateCompleter = null;
      _expectedAllowMeteredDownloads = null;
      _expectedAllowMobileData = null;
      _expectedNetworkStatus = null;
    }
  }

  /// Applies the persisted mobile-data permission to the live engine.
  ///
  /// This is independent from Android's metered-network classification, so a
  /// cellular-backed VPN cannot bypass the user's mobile-data preference.
  Future<void> setAllowMobileData(bool allow) async {
    if (!Platform.isAndroid) {
      return;
    }

    final sendOperation = _policyUpdateQueue.then(
      (_) => _sendAllowMobileData(allow),
    );
    final operation = _applyPolicyUpdateWithSafetyFallback(
      sendOperation,
      restrictsTransfers: !allow,
      settingName: 'mobile-data',
    );
    _policyUpdateQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await operation;
  }

  /// A failed opt-out must not leave a stale permissive session transferring.
  ///
  /// Stopping the engine retains partial files. Its next start rereads the
  /// already-persisted preference before it accepts torrent commands.
  Future<void> _applyPolicyUpdateWithSafetyFallback(
    Future<void> operation, {
    required bool restrictsTransfers,
    required String settingName,
  }) async {
    try {
      await operation;
    } on Object catch (updateError, updateStackTrace) {
      if (!restrictsTransfers) {
        Error.throwWithStackTrace(updateError, updateStackTrace);
      }

      try {
        await _stopForegroundService();
      } on Object catch (stopError, stopStackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'Unable to apply the stricter $settingName policy and unable to '
            'stop the download service. Update error: $updateError; '
            'stop error: $stopError',
          ),
          stopStackTrace,
        );
      }
    }
  }

  Future<void> _sendAllowMobileData(bool allow) async {
    await (_initialization ?? Future<void>.value());
    await (_startOrAttachOperation ?? Future<void>.value());
    if (!await FlutterForegroundTask.isRunningService) {
      _isServiceRunning = false;
      await ref
          .read(foregroundTransferPolicyStatusProvider.notifier)
          .useLocalStatus();
      return;
    }

    _isServiceRunning = true;
    if (!(_serviceReadyCompleter?.isCompleted ?? false)) {
      await _runServiceLifecycle(() async {
        if (await FlutterForegroundTask.isRunningService) {
          await _requestServiceReady(allowRestart: true);
        }
      });
    }
    final currentPolicy = ref.read(foregroundTransferPolicyStatusProvider);
    if (currentPolicy.allowMobileData == allow) {
      return;
    }

    _expectedAllowMeteredDownloads = null;
    _expectedAllowMobileData = allow;
    _expectedNetworkStatus = null;
    _policyUpdateCompleter = Completer<void>();
    FlutterForegroundTask.sendDataToTask({
      'type': 'update_transfer_policy',
      'allowMobileData': allow,
    });
    try {
      await _policyUpdateCompleter!.future.timeout(const Duration(seconds: 15));
    } finally {
      _policyUpdateCompleter = null;
      _expectedAllowMeteredDownloads = null;
      _expectedAllowMobileData = null;
      _expectedNetworkStatus = null;
    }
  }

  /// Starts the real foreground torrent engine without adding a torrent.
  /// Available only in builds compiled with the integration-test hook.
  Future<void> startNetworkPolicyTestService() async {
    _requireNetworkPolicyTestHook();
    await _startForegroundServiceIfNeeded();
  }

  /// Injects a deterministic network status and waits until native suspension
  /// has been applied and reported by the foreground engine.
  Future<void> setTestNetworkStatus(NetworkStatus networkStatus) async {
    _requireNetworkPolicyTestHook();

    final operation = _policyUpdateQueue.then((_) async {
      await _startForegroundServiceIfNeeded();
      final currentPolicy = ref.read(foregroundTransferPolicyStatusProvider);
      if (_networkStatusForPolicy(currentPolicy) == networkStatus) {
        return;
      }

      _expectedAllowMeteredDownloads = null;
      _expectedAllowMobileData = null;
      _expectedNetworkStatus = networkStatus;
      _policyUpdateCompleter = Completer<void>();
      FlutterForegroundTask.sendDataToTask({
        'type': 'set_test_network_status',
        'networkCost': networkStatus.cost.name,
        'networkTransport': networkStatus.transport.name,
        'isVpn': networkStatus.isVpn,
      });
      try {
        await _policyUpdateCompleter!.future.timeout(
          const Duration(seconds: 15),
        );
      } finally {
        _policyUpdateCompleter = null;
        _expectedAllowMeteredDownloads = null;
        _expectedAllowMobileData = null;
        _expectedNetworkStatus = null;
      }
    });
    _policyUpdateQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await operation;
  }

  Future<void> stopNetworkPolicyTestService() async {
    _requireNetworkPolicyTestHook();
    await _stopForegroundService();
  }

  Future<bool> queryTestTransfersSuspended() async {
    final response = await _performTestQuery('query_test_transfers_suspended');
    final suspended = response['suspended'];
    if (suspended is! bool) {
      throw const FormatException(
        'Torrent service returned an invalid suspension value.',
      );
    }
    return suspended;
  }

  Future<TorrentState> queryTestTorrentState(String torrentKey) async {
    final response = await _performTestQuery(
      'query_test_torrent_state',
      <String, Object>{'torrentKey': torrentKey},
    );
    final stateName = response['torrentState'];
    final matches = TorrentState.values.where(
      (value) => value.name == stateName,
    );
    if (matches.length != 1) {
      throw const FormatException(
        'Torrent service returned an invalid torrent state.',
      );
    }
    return matches.single;
  }

  Future<Map<String, dynamic>> _performTestQuery(
    String type, [
    Map<String, Object> arguments = const <String, Object>{},
  ]) async {
    _requireNetworkPolicyTestHook();
    await _startForegroundServiceIfNeeded();

    final requestId = _nextServiceRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _testQueryCompleters[requestId] = completer;
    FlutterForegroundTask.sendDataToTask({
      'type': type,
      'requestId': requestId,
      ...arguments,
    });
    try {
      return await completer.future.timeout(const Duration(seconds: 15));
    } finally {
      _testQueryCompleters.remove(requestId);
    }
  }

  void _completeTestQuery(Map<String, dynamic> message) {
    final requestId = message['requestId'];
    if (requestId is! int) {
      return;
    }
    final completer = _testQueryCompleters[requestId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(message);
    }
  }

  void _failPendingTestQueries(Object error) {
    for (final completer in _testQueryCompleters.values.toList()) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _testQueryCompleters.clear();
  }

  void _requireNetworkPolicyTestHook() {
    if (!networkPolicyTestHookEnabled) {
      throw UnsupportedError(
        'Rebuild with TAMASHII_ENABLE_NETWORK_POLICY_TEST_HOOK=true.',
      );
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('The network-policy test hook is Android-only.');
    }
  }

  void _checkAndStopServiceIfIdle() {
    // Stop service if no active downloads and all torrents are complete or removed
    final activeTorrents = state.torrents.values
        .where((torrent) => torrent.torrentId != null && !torrent.isCompleted)
        .length;

    if (activeTorrents == 0 && _isServiceRunning) {
      unawaited(
        _stopForegroundService().catchError((Object error) {
          print('❌ Failed to stop idle torrent service: $error');
        }),
      );
    }
  }

  // Public methods to control downloads
  Future<void> startDownload(
    String torrentKey,
    String magnetUri,
    String downloadPath,
  ) async {
    if (!Platform.isAndroid) {
      // On non-Android platforms, fall back to the standard torrent manager
      await ref
          .read(torrentManagerProvider.notifier)
          .startDownload(torrentKey, magnetUri, downloadPath);
      return;
    }

    // Android: proceed with foreground-service based logic

    // Set loading state immediately
    final currentState =
        state.torrents[torrentKey] ?? const TorrentDownloadState();
    _updateTorrentState(
      torrentKey,
      currentState.copyWith(isLoading: true, clearError: true),
    );

    try {
      if (!networkPolicyTestHookEnabled) {
        // Integration tests use an app-writable temporary directory and never
        // bypass storage permission checks in production builds.
        print('🔐 Checking storage permissions for $torrentKey');
        final hasPermissions = await PermissionService.hasStoragePermissions();

        if (!hasPermissions) {
          print('🔒 Storage permissions not granted, requesting...');
          final granted = await PermissionService.requestStoragePermissions();

          if (!granted) {
            throw Exception(
              'Storage permissions are required to download torrents. '
              'Please grant storage access in app settings.',
            );
          }
          print('✅ Storage permissions granted');
        }
      }

      final directoryError = await PermissionService.validateDownloadDirectory(
        downloadPath,
      );
      if (directoryError != null) {
        throw FileSystemException(directoryError, downloadPath);
      }

      // A pending stricter network-policy update must take effect before a
      // start can cross into the background engine.
      await _policyUpdateQueue;

      // Re-check the platform service rather than trusting UI-isolate state;
      // the foreground task may have stopped after all earlier downloads.
      await _startForegroundServiceIfNeeded();
      await _policyUpdateQueue;

      // Record download path for later persistence
      _downloadPaths[torrentKey] = downloadPath;

      // Send command to service
      FlutterForegroundTask.sendDataToTask({
        'type': 'start_download',
        'torrentKey': torrentKey,
        'magnetUri': magnetUri,
        'downloadPath': downloadPath,
      });
    } catch (e) {
      // Handle permission errors
      print('❌ Failed to start download for $torrentKey: $e');
      _updateTorrentState(
        torrentKey,
        currentState.copyWith(errorMessage: e.toString(), isLoading: false),
      );
      if (e is ForegroundNotificationPermissionException) {
        rethrow;
      }
    }
  }

  Future<void> pauseDownload(String torrentKey) async {
    if (!Platform.isAndroid) {
      await ref.read(torrentManagerProvider.notifier).pauseDownload(torrentKey);
      return;
    }

    await _sendTorrentCommand(
      type: 'pause_download',
      operation: 'pause',
      expectedResponseType: 'download_paused',
      torrentKey: torrentKey,
    );
  }

  Future<void> resumeDownload(String torrentKey) async {
    if (!Platform.isAndroid) {
      await ref
          .read(torrentManagerProvider.notifier)
          .resumeDownload(torrentKey);
      return;
    }

    await _sendTorrentCommand(
      type: 'resume_download',
      operation: 'resume',
      expectedResponseType: 'download_resumed',
      torrentKey: torrentKey,
    );
  }

  Future<void> removeDownload(String torrentKey) async {
    if (!Platform.isAndroid) {
      await ref.read(torrentManagerProvider.notifier).stopDownload(torrentKey);
      return;
    }

    await _sendTorrentCommand(
      type: 'remove_download',
      operation: 'remove',
      expectedResponseType: 'download_removed',
      torrentKey: torrentKey,
    );
  }

  Future<void> _sendTorrentCommand({
    required String type,
    required String operation,
    required String expectedResponseType,
    required String torrentKey,
  }) async {
    // Control operations use the same attach/restart barrier as starts. This
    // turns a dead or stale task into an explicit failure instead of silently
    // updating only the UI's optimistic state.
    await _startForegroundServiceIfNeeded();

    final requestId = _nextServiceRequestId++;
    final pending = _PendingTorrentCommand(
      operation: operation,
      torrentKey: torrentKey,
      expectedResponseType: expectedResponseType,
    );
    _pendingTorrentCommands[requestId] = pending;
    FlutterForegroundTask.sendDataToTask({
      'type': type,
      'torrentKey': torrentKey,
      'requestId': requestId,
    });

    try {
      await pending.completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ForegroundTorrentCommandException(
        operation: operation,
        torrentKey: torrentKey,
        message: 'the foreground service did not acknowledge the command',
      );
    } finally {
      if (identical(_pendingTorrentCommands[requestId], pending)) {
        _pendingTorrentCommands.remove(requestId);
      }
    }
  }

  void _completeTorrentCommand(Map<String, dynamic> message) {
    final requestId = message['requestId'];
    if (requestId is! int) {
      return;
    }
    final pending = _pendingTorrentCommands[requestId];
    if (pending == null ||
        pending.completer.isCompleted ||
        message['type'] != pending.expectedResponseType) {
      return;
    }
    pending.completer.complete();
  }

  void _failTorrentCommand(Map<String, dynamic> message) {
    final requestId = message['requestId'];
    if (requestId is! int) {
      return;
    }
    final pending = _pendingTorrentCommands[requestId];
    if (pending == null || pending.completer.isCompleted) {
      return;
    }
    pending.completer.completeError(
      ForegroundTorrentCommandException(
        operation: pending.operation,
        torrentKey: pending.torrentKey,
        message: message['message'] as String? ?? 'the command failed',
      ),
    );
  }

  void _failPendingTorrentCommands(Object error) {
    for (final pending in _pendingTorrentCommands.values.toList()) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
    _pendingTorrentCommands.clear();
  }

  void _updateTorrentState(String torrentKey, TorrentDownloadState newState) {
    final newTorrents = Map<String, TorrentDownloadState>.from(state.torrents);
    newTorrents[torrentKey] = newState;
    state = state.copyWith(torrents: newTorrents);
  }

  // Helper method to format bytes for display
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Method to handle data from the foreground service
  void handleServiceData(dynamic data) {
    if (data is Map) {
      final message = Map<String, dynamic>.from(data);
      final String? type = message['type'];

      switch (type) {
        case 'service_ready':
          print('✅ Foreground service is ready');
          final serviceInstanceId = message['serviceInstanceId'];
          if (serviceInstanceId is! String || serviceInstanceId.isEmpty) {
            print('❌ Ignoring service readiness without an instance ID');
            break;
          }
          final responseRequestId = message['requestId'];
          final expectedRequestId = _expectedServiceReadyRequestId;
          final isExpectedResponse = expectedRequestId == null
              ? responseRequestId == null
              : responseRequestId == expectedRequestId;
          final completer = _serviceReadyCompleter;
          if (!isExpectedResponse) {
            print('⏭️ Ignoring stale service readiness response');
            break;
          }
          _serviceInstanceTracker.markReady(serviceInstanceId);
          _isServiceRunning = true;
          _updateTransferPolicyStatus(message);
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
          break;

        case 'transfer_policy_status':
          _updateTransferPolicyStatus(message);
          break;

        case 'download_started':
          _handleDownloadStarted(message);
          break;

        case 'download_paused':
        case 'download_resumed':
        case 'download_removed':
          _handleTorrentStatusUpdate(message);
          _completeTorrentCommand(message);
          break;

        case 'stats_update':
          _handleStatsUpdate(message);
          break;

        case 'metadata_update':
          _handleMetadataUpdate(message);
          break;

        case 'bulk_torrent_states':
          _handleBulkStates(message);
          break;

        case 'all_paused':
        case 'all_resumed':
          print(
            '📢 ${type == 'all_paused' ? 'All torrents paused' : 'All torrents resumed'}',
          );
          break;

        case 'error':
          _handleError(message);
          _failTorrentCommand(message);
          break;

        case 'service_error':
          final errorServiceInstanceId = message['serviceInstanceId'];
          if (!_serviceInstanceTracker.acceptsMessage(
            errorServiceInstanceId is String ? errorServiceInstanceId : null,
          )) {
            print('⏭️ Ignoring error from a stale torrent service');
            break;
          }
          final error = StateError(
            message['message'] as String? ?? 'Torrent service failed.',
          );
          final completer = _serviceReadyCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.completeError(error);
          }
          final policyCompleter = _policyUpdateCompleter;
          if (policyCompleter != null && !policyCompleter.isCompleted) {
            policyCompleter.completeError(error);
          }
          _failPendingTestQueries(error);
          _failPendingTorrentCommands(error);
          print('❌ $error');
          break;

        case 'service_stopped':
          final stoppedServiceInstanceId = message['serviceInstanceId'];
          if (!_serviceInstanceTracker.acceptStopped(
            stoppedServiceInstanceId is String
                ? stoppedServiceInstanceId
                : null,
          )) {
            print('⏭️ Ignoring stop from a stale torrent service');
            break;
          }
          final error = StateError('Torrent service stopped.');
          _isServiceRunning = false;
          _serviceReadyCompleter = null;
          _expectedServiceReadyRequestId = null;
          final policyCompleter = _policyUpdateCompleter;
          if (policyCompleter != null && !policyCompleter.isCompleted) {
            policyCompleter.completeError(error);
          }
          _failPendingTestQueries(error);
          _failPendingTorrentCommands(error);
          unawaited(
            ref
                .read(foregroundTransferPolicyStatusProvider.notifier)
                .useLocalStatus(),
          );
          break;

        case 'test_transfers_suspended_result':
        case 'test_torrent_state_result':
          _completeTestQuery(message);
          break;

        case 'show_completion_notification':
          _handleCompletionNotification(message);
          break;

        default:
          print('🔍 Unknown data type from service: $type');
      }
    }
  }

  void _updateTransferPolicyStatus(Map<String, dynamic> data) {
    final serviceInstanceId = data['serviceInstanceId'];
    if (!_serviceInstanceTracker.acceptsMessage(
      serviceInstanceId is String ? serviceInstanceId : null,
    )) {
      return;
    }
    try {
      final snapshot = deserializeTransferPolicy(data);
      ref
          .read(foregroundTransferPolicyStatusProvider.notifier)
          .replace(snapshot);
      final policyCompleter = _policyUpdateCompleter;
      if (policyCompleter != null &&
          !policyCompleter.isCompleted &&
          (_expectedAllowMeteredDownloads == null ||
              snapshot.allowMeteredDownloads ==
                  _expectedAllowMeteredDownloads) &&
          (_expectedAllowMobileData == null ||
              snapshot.allowMobileData == _expectedAllowMobileData) &&
          (_expectedNetworkStatus == null ||
              _networkStatusForPolicy(snapshot) == _expectedNetworkStatus)) {
        policyCompleter.complete();
        _policyUpdateCompleter = null;
        _expectedAllowMeteredDownloads = null;
        _expectedAllowMobileData = null;
        _expectedNetworkStatus = null;
      }
    } on FormatException catch (error) {
      print('❌ Ignoring malformed transfer-policy status: $error');
    }
  }

  void _handleDownloadStarted(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final int? torrentId = data['torrentId'];

    if (torrentKey != null && torrentId != null) {
      final currentState =
          state.torrents[torrentKey] ?? const TorrentDownloadState();
      final newState = currentState.copyWith(
        torrentId: torrentId,
        isLoading: false,
        clearError: true,
      );
      _updateTorrentState(torrentKey, newState);
      print('🚀 Download started for $torrentKey (ID: $torrentId)');
    }
  }

  void _handleTorrentStatusUpdate(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final String? type = data['type'];

    if (torrentKey == null || type == null) return;

    final currentState =
        state.torrents[torrentKey] ?? const TorrentDownloadState();
    TorrentDownloadState newState;

    switch (type) {
      case 'download_paused':
        newState = currentState.copyWith(isPaused: true);
        print('⏸️ Download paused for $torrentKey');
        break;
      case 'download_resumed':
        newState = currentState.copyWith(isPaused: false);
        print('▶️ Download resumed for $torrentKey');
        break;
      case 'download_removed':
        newState = const TorrentDownloadState();
        print('🗑️ Download removed for $torrentKey');
        break;
      default:
        return;
    }

    _updateTorrentState(torrentKey, newState);

    // Check if we should stop the service after a torrent is removed
    if (type == 'download_removed') {
      _checkAndStopServiceIfIdle();
    }
  }

  void _handleStatsUpdate(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final Map<String, dynamic>? statsData = data['stats'];

    if (torrentKey == null || statsData == null) return;

    final currentState =
        state.torrents[torrentKey] ?? const TorrentDownloadState();

    // Recreate TorrentStats from serialized data using fromMap()
    try {
      final stats = TorrentStats.fromMap(statsData);
      final newState = currentState.copyWith(stats: stats);

      _updateTorrentState(torrentKey, newState);

      // Persist completion. The task awaits native finalise before it stops
      // itself; stopping here would race manager teardown against finalise.
      if (stats.progress >= 1.0) {
        if (_downloadPaths.containsKey(torrentKey)) {
          ref
              .read(downloadedTorrentsProvider.notifier)
              .addDownloaded(torrentKey);
        }
      }

      // Log the stats for debugging
      print(
        '📊 Stats update for $torrentKey: ${(stats.progress * 100).toStringAsFixed(1)}% (${_formatBytes(stats.downloadRate)}/s) - State: ${stats.state.name}',
      );
    } catch (e) {
      print('❌ Failed to recreate TorrentStats from serialized data: $e');
    }
  }

  void _handleMetadataUpdate(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final Map<String, dynamic>? metadataData = data['metadata'];

    if (torrentKey == null || metadataData == null) return;

    final currentState =
        state.torrents[torrentKey] ?? const TorrentDownloadState();

    // Recreate TorrentMetadata from serialized data using fromMap()
    try {
      final metadata = TorrentMetadata.fromMap(metadataData);
      final newState = currentState.copyWith(metadata: metadata);

      _updateTorrentState(torrentKey, newState);

      print('📋 Metadata updated for $torrentKey: ${metadata.name}');
    } catch (e) {
      print('❌ Failed to recreate TorrentMetadata from serialized data: $e');
    }
  }

  void _handleBulkStates(Map<String, dynamic> data) {
    final Map<String, dynamic>? states = data['states'];
    if (states == null) return;

    final Map<String, TorrentDownloadState> newTorrents = Map.from(
      state.torrents,
    );

    for (final entry in states.entries) {
      final String torrentKey = entry.key;
      final Map<String, dynamic> stateData = entry.value;
      final int? torrentId = stateData['torrentId'];

      if (torrentId != null) {
        final currentState =
            newTorrents[torrentKey] ?? const TorrentDownloadState();
        // Update with current torrent ID if it's different
        if (currentState.torrentId != torrentId) {
          newTorrents[torrentKey] = currentState.copyWith(torrentId: torrentId);
        }
      }
    }

    state = state.copyWith(torrents: newTorrents);
  }

  void _handleError(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final String? message = data['message'];

    if (torrentKey != null && message != null) {
      final currentState =
          state.torrents[torrentKey] ?? const TorrentDownloadState();
      final newState = currentState.copyWith(
        errorMessage: message,
        isLoading: false,
      );
      _updateTorrentState(torrentKey, newState);
      print('❌ Error for $torrentKey: $message');
    }
  }

  void _handleCompletionNotification(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final String? displayName = data['displayName'];
    final String? message = data['message'];

    if (torrentKey != null && displayName != null && message != null) {
      print('🎉 Torrent completed: $displayName');

      // Persist completion info
      if (_downloadPaths.containsKey(torrentKey)) {
        ref.read(downloadedTorrentsProvider.notifier).addDownloaded(torrentKey);
      }

      // Show a local notification using flutter_foreground_task's notification capability
      // We can send a separate notification by temporarily updating the service notification
      // with completion info, then reverting back to the main notification
      _showCompletionNotificationToUser(displayName, message);
    }
  }

  void _showCompletionNotificationToUser(
    String displayName,
    String message,
  ) async {
    // Show a proper local notification using flutter_local_notifications
    try {
      await NotificationService.showTorrentCompletionNotification(
        torrentName: displayName,
        message: message,
      );
      print('📱 Local notification shown for: $displayName');
    } catch (e) {
      print('❌ Failed to show notification: $e');
    }
  }
}

NetworkStatus _networkStatusForPolicy(TransferPolicySnapshot snapshot) {
  return NetworkStatus(
    cost: snapshot.networkCost,
    transport: snapshot.networkTransport,
    isVpn: snapshot.isVpn,
  );
}

// Provider for individual torrent states
@riverpod
TorrentDownloadState foregroundTorrentForShow(Ref ref, String showId) {
  if (Platform.isAndroid) {
    final manager = ref.watch(foregroundTorrentManagerProvider);
    return manager.torrents[showId] ?? const TorrentDownloadState();
  } else {
    final manager = ref.watch(torrentManagerProvider);
    return manager.torrents[showId] ?? const TorrentDownloadState();
  }
}
