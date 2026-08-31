// lib/services/torrent_foreground_task.dart

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/config/torrent_config.dart';
import 'package:tamashii/config/torrent_download_config.dart';
import 'package:tamashii/services/foreground_service_lifecycle.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

// The callback function should always be a top-level or static function.
@pragma('vm:entry-point')
void startTorrentCallback() {
  FlutterForegroundTask.setTaskHandler(TorrentTaskHandler());
}

class TorrentTaskHandler extends TaskHandler {
  final Map<String, int> _torrentIds = {}; // torrentKey -> torrentId mapping
  final Map<int, StreamSubscription<TorrentStats>> _statsSubs = {};
  StreamSubscription<TorrentMetadata>? _metadataSub;
  Timer? _updateTimer;
  final DelayedServiceStopController _completionStopController =
      DelayedServiceStopController();

  // Track current torrent states for notification updates
  final Map<String, TorrentStats> _currentStats = {};
  final Map<String, TorrentMetadata> _currentMetadata = {};
  final Map<String, bool> _completedTorrents = {};
  final Set<String> _finalisingTorrents = {};
  Future<void> _commandQueue = Future<void>.value();
  TransferPolicyController? _transferPolicyController;
  MutableNetworkStatusSource? _testNetworkStatusSource;
  TransferPolicySnapshot _transferPolicy = initialTransferPolicySnapshot;
  bool _serviceReady = false;
  late final String _serviceInstanceId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TorrentTaskHandler onStart');
    _serviceInstanceId =
        '${timestamp.microsecondsSinceEpoch}-${identityHashCode(this)}';

    try {
      final testNetworkStatusSource = networkPolicyTestHookEnabled
          ? MutableNetworkStatusSource()
          : null;
      _testNetworkStatusSource = testNetworkStatusSource;
      final transferPolicyController = TransferPolicyController(
        runtime: const SimpleTorrentTransferRuntime(),
        networkStatusSource:
            testNetworkStatusSource ?? const PluginNetworkStatusSource(),
        readAllowMeteredDownloads: readAllowMeteredDownloadsPreference,
        readAllowMobileData: readAllowMobileDataPreference,
        onChanged: _handleTransferPolicyChanged,
        onError: _handleTransferPolicyError,
      );
      _transferPolicyController = transferPolicyController;
      await transferPolicyController.initialize();

      // This engine owns its own v2 manager, so streams must only be observed
      // after initialization and the current network policy has been applied.
      _metadataSub = SimpleTorrent.metadataStream.listen(_handleMetadataUpdate);

      // Set up periodic updates every 2 seconds for responsive notifications.
      _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _enqueueCommand(_broadcastTorrentStates);
        _updateNotificationWithProgress();
      });

      _serviceReady = true;
      _sendServiceReady(timestamp);
    } catch (error, stackTrace) {
      _sendServiceError('Failed to initialize torrent service: $error');
      await _transferPolicyController?.dispose();
      _transferPolicyController = null;
      await _testNetworkStatusSource?.close();
      _testNetworkStatusSource = null;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Re-query as a fallback for a missed Android connectivity callback, then
    // update the notification from the same serialized policy snapshot.
    _enqueueCommand(() async {
      await _transferPolicyController?.refresh();
      if (_serviceReady) {
        _updateNotificationWithProgress();
      }
    });
  }

  void _updateNotificationWithProgress() {
    final activeTorrents = _torrentIds.length;

    if (_transferPolicy.suspended) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tamashii - Downloads paused',
        notificationText: transferPolicyStatusText(_transferPolicy),
      );
      return;
    }

    if (activeTorrents == 0) {
      // The UI may be waiting on service_ready before it can send the first
      // start command, so the task must not stop itself in this short window.
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tamashii - Torrent Service',
        notificationText: 'Ready for downloads',
      );
      return;
    }

    // Check if all torrents are completed (no longer downloading)
    final completedCount = _completedTorrents.values
        .where((completed) => completed)
        .length;
    final downloadingCount = _currentStats.values
        .where((stats) => stats.progress < 1.0)
        .length;

    if (completedCount == activeTorrents &&
        downloadingCount == 0 &&
        activeTorrents > 0) {
      // All torrents finished downloading - show completion notification briefly then stop
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tamashii - Downloads Complete! 🎉',
        notificationText: 'All $activeTorrents torrent(s) finished downloading',
      );

      // Stop the service after a short delay to let user see the completion message
      _completionStopController.schedule(
        delay: const Duration(seconds: 5),
        onElapsed: (generation) {
          _enqueueCommand(() => _stopServiceIfStillComplete(generation));
        },
      );
      return;
    }

    // Calculate overall progress and speeds for active downloads
    double totalProgress = 0;
    int totalDownloadRate = 0;
    int totalUploadRate = 0;

    for (final entry in _currentStats.entries) {
      final stats = entry.value;
      totalProgress += stats.progress;
      totalDownloadRate += stats.downloadRate;
      totalUploadRate += stats.uploadRate;
    }

    if (_currentStats.isNotEmpty) {
      final avgProgress =
          (totalProgress / _currentStats.length) *
          100; // Convert to percentage for display
      final downloadSpeed = _formatBytes(totalDownloadRate);
      final uploadSpeed = _formatBytes(totalUploadRate);

      final String title =
          'Tamashii - ${avgProgress.toStringAsFixed(1)}% Complete';
      String text;

      if (downloadingCount > 0) {
        text =
            '$downloadingCount downloading • ↓$downloadSpeed/s • ↑$uploadSpeed/s';
      } else {
        text = 'Seeding $activeTorrents torrent(s) • ↑$uploadSpeed/s';
      }

      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tamashii - Torrent Service',
        notificationText: 'Managing $activeTorrents torrent(s)',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('TorrentTaskHandler onDestroy');

    // Stop producing new work before awaiting the serialized lifecycle queue.
    _serviceReady = false;
    _updateTimer?.cancel();
    _completionStopController.dispose();
    await _metadataSub?.cancel();

    // Cancelling subscriptions first prevents a late stats callback from
    // queuing finalisation after the queue has already been drained.
    for (final sub in _statsSubs.values.toList()) {
      await sub.cancel();
    }
    _statsSubs.clear();
    await _commandQueue;

    // Destroying a foreground task must never delete partially downloaded
    // files. The engine teardown disposes its native manager; explicit user
    // removal remains the only path that calls SimpleTorrent.cancel().
    await _transferPolicyController?.dispose();
    _transferPolicyController = null;
    await _testNetworkStatusSource?.close();
    _testNetworkStatusSource = null;
    _torrentIds.clear();
    _currentStats.clear();
    _currentMetadata.clear();
    _completedTorrents.clear();
    _finalisingTorrents.clear();
    FlutterForegroundTask.sendDataToMain({
      'type': 'service_stopped',
      'serviceInstanceId': _serviceInstanceId,
    });
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final command = Map<String, dynamic>.from(data);
      // Invalidate a pending all-complete shutdown before this start waits for
      // earlier commands. The delayed callback rechecks the same generation.
      if (command['type'] == 'start_download') {
        _completionStopController.invalidate();
      }
      _enqueueCommand(() => _handleCommand(command));
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause_all') {
      _enqueueCommand(_pauseAllTorrents);
    } else if (id == 'resume_all') {
      _enqueueCommand(_resumeAllTorrents);
    }
  }

  void _enqueueCommand(Future<void> Function() command) {
    final operation = _commandQueue.then((_) => command());
    _commandQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        _sendServiceError('Torrent service command failed: $error');
      },
    );
  }

  @override
  void onNotificationPressed() {
    // User tapped notification - could launch app to main route
  }

  @override
  void onNotificationDismissed() {
    // Notification was dismissed
  }

  Future<void> _handleCommand(Map<String, dynamic> command) async {
    final String? type = command['type'];

    if (!_serviceReady) {
      _sendServiceError(
        'Torrent service received "$type" before it was ready.',
      );
      return;
    }

    switch (type) {
      case 'start_download':
        await _startDownload(command);
        break;
      case 'pause_download':
        await _pauseDownload(command);
        break;
      case 'resume_download':
        await _resumeDownload(command);
        break;
      case 'remove_download':
        await _removeDownload(command);
        break;
      case 'get_torrent_state':
        await _getTorrentState(command);
        break;
      case 'update_transfer_policy':
        final allowMeteredDownloads = command['allowMeteredDownloads'];
        final allowMobileData = command['allowMobileData'];
        final hasMeteredUpdate = command.containsKey('allowMeteredDownloads');
        final hasMobileDataUpdate = command.containsKey('allowMobileData');
        if (hasMeteredUpdate == hasMobileDataUpdate ||
            (hasMeteredUpdate && allowMeteredDownloads is! bool) ||
            (hasMobileDataUpdate && allowMobileData is! bool)) {
          _sendServiceError(
            'A transfer-policy update must contain exactly one Boolean setting.',
          );
          return;
        }
        if (hasMeteredUpdate) {
          await _transferPolicyController!.setAllowMeteredDownloads(
            allowMeteredDownloads as bool,
          );
        } else {
          await _transferPolicyController!.setAllowMobileData(
            allowMobileData as bool,
          );
        }
        break;
      case 'request_service_state':
        await _transferPolicyController!.refresh();
        if (!_serviceReady) {
          return;
        }
        _sendServiceReady(
          DateTime.now(),
          requestId: command['requestId'] as int?,
        );
        await _broadcastTorrentStates();
        break;
      case 'set_test_network_status':
        if (!networkPolicyTestHookEnabled) {
          _sendServiceError('The network-policy test hook is disabled.');
          return;
        }
        final networkCostName = command['networkCost'];
        final networkTransportName = command['networkTransport'];
        final isVpn = command['isVpn'];
        final costMatches = NetworkCost.values.where(
          (value) => value.name == networkCostName,
        );
        final transportMatches = NetworkTransport.values.where(
          (value) => value.name == networkTransportName,
        );
        if (costMatches.length != 1 ||
            transportMatches.length != 1 ||
            isVpn is! bool) {
          _sendServiceError('Invalid test network status value.');
          return;
        }
        _testNetworkStatusSource!.set(
          NetworkStatus(
            cost: costMatches.single,
            transport: transportMatches.single,
            isVpn: isVpn,
          ),
        );
        break;
      case 'query_test_transfers_suspended':
        await _queryTestTransfersSuspended(command);
        break;
      case 'query_test_torrent_state':
        await _queryTestTorrentState(command);
        break;
      default:
        print('Unknown command type: $type');
    }
  }

  Future<void> _startDownload(Map<String, dynamic> command) async {
    _completionStopController.invalidate();
    try {
      final String torrentKey = command['torrentKey'];
      final String magnetUri = command['magnetUri'];
      final String downloadPath = command['downloadPath'];

      // Use SimpleTorrentHelpers for enhanced functionality
      // /storage/emulated/0/Download
      // /storage/emulated/0/SdCardBackUp/Tamashii/Witch Watch
      // "/storage/emulated/0/SdCardBackUp/Tamashii/Ww"

      final (id, statsStream) = await SimpleTorrentHelpers.startAndWatch(
        magnet: resolveTorrentMagnetUri(magnetUri),
        path: downloadPath,
        displayName: torrentKey, // Use torrentKey as display name
      );

      // Store mapping
      _torrentIds[torrentKey] = id;

      // Initialize tracking
      _completedTorrents[torrentKey] = false;

      // Listen to stats updates
      _listenToTorrent(id, torrentKey, statsStream);

      // Send success response
      FlutterForegroundTask.sendDataToMain({
        'type': 'download_started',
        'torrentKey': torrentKey,
        'torrentId': id,
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(
        torrentKey,
        'Failed to start download: ${describeTorrentError(e)}',
      );
    }
  }

  Future<void> _pauseDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(
          torrentKey,
          'Torrent not found',
          requestId: command['requestId'] as int?,
        );
        return;
      }

      await SimpleTorrent.pause(torrentId);

      FlutterForegroundTask.sendDataToMain({
        'type': 'download_paused',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'requestId': command['requestId'],
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(
        torrentKey,
        'Failed to pause download: ${describeTorrentError(e)}',
        requestId: command['requestId'] as int?,
      );
    }
  }

  Future<void> _resumeDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(
          torrentKey,
          'Torrent not found',
          requestId: command['requestId'] as int?,
        );
        return;
      }

      await SimpleTorrent.resume(torrentId);

      FlutterForegroundTask.sendDataToMain({
        'type': 'download_resumed',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'requestId': command['requestId'],
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(
        torrentKey,
        'Failed to resume download: ${describeTorrentError(e)}',
        requestId: command['requestId'] as int?,
      );
    }
  }

  Future<void> _removeDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(
          torrentKey,
          'Torrent not found',
          requestId: command['requestId'] as int?,
        );
        return;
      }

      await SimpleTorrent.cancel(torrentId);

      // Clean up subscriptions and tracking data
      await _statsSubs[torrentId]?.cancel();
      _statsSubs.remove(torrentId);
      _torrentIds.remove(torrentKey);
      _currentStats.remove(torrentKey);
      _currentMetadata.remove(torrentKey);
      _completedTorrents.remove(torrentKey);
      _finalisingTorrents.remove(torrentKey);

      FlutterForegroundTask.sendDataToMain({
        'type': 'download_removed',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'requestId': command['requestId'],
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(
        torrentKey,
        'Failed to remove download: ${describeTorrentError(e)}',
        requestId: command['requestId'] as int?,
      );
    }
  }

  Future<void> _getTorrentState(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(torrentKey, 'Torrent not found');
        return;
      }

      final TorrentInfo info = await SimpleTorrent.getTorrentInfo(torrentId);

      FlutterForegroundTask.sendDataToMain({
        'type': 'torrent_state',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'info': _serializeTorrentInfo(info),
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(
        torrentKey,
        'Failed to get torrent state: ${describeTorrentError(e)}',
      );
    }
  }

  void _handleMetadataUpdate(TorrentMetadata metadata) {
    // Find the torrent key that corresponds to this torrent ID
    for (final entry in _torrentIds.entries) {
      final torrentKey = entry.key;
      final torrentId = entry.value;

      if (torrentId == metadata.id) {
        // Store the metadata for notification updates
        _currentMetadata[torrentKey] = metadata;

        FlutterForegroundTask.sendDataToMain({
          'type': 'metadata_update',
          'torrentKey': torrentKey,
          'torrentId': torrentId,
          'metadata': metadata.toMap(),
        });
        break;
      }
    }
  }

  void _listenToTorrent(
    int torrentId,
    String torrentKey,
    Stream<TorrentStats> statsStream,
  ) {
    _statsSubs[torrentId]?.cancel();

    final sub = statsStream.listen(
      (stats) {
        // Store current stats for notification updates
        _currentStats[torrentKey] = stats;

        // Track completion status
        _completedTorrents[torrentKey] = stats.progress >= 1.0;

        FlutterForegroundTask.sendDataToMain({
          'type': 'stats_update',
          'torrentKey': torrentKey,
          'torrentId': torrentId,
          'stats': stats.toMap(),
        });

        // Auto-cleanup completed torrents but keep them for final notification
        if (stats.progress >= 1.0 && _finalisingTorrents.add(torrentKey)) {
          _enqueueCommand(
            () => _finaliseCompletedTorrent(torrentId, torrentKey),
          );
        }
      },
      onError: (error) {
        print('❌ Stats stream error for $torrentKey: $error');
        _sendError(torrentKey, 'Stats stream error: $error');
      },
    );

    _statsSubs[torrentId] = sub;
  }

  Future<void> _finaliseCompletedTorrent(
    int torrentId,
    String torrentKey,
  ) async {
    print('✅ Torrent completed for $torrentKey');

    // A user removal queued before this completion wins and makes finalisation
    // unnecessary. This also prevents operations against a recycled key.
    if (_torrentIds[torrentKey] != torrentId) {
      _finalisingTorrents.remove(torrentKey);
      return;
    }

    try {
      // Finalise removes the torrent from the native active set while
      // deliberately retaining the completed payload.
      await SimpleTorrent.finalise(torrentId);
      _showTorrentCompletionNotification(torrentKey);

      await _statsSubs[torrentId]?.cancel();
      _statsSubs.remove(torrentId);

      // Check if all torrents are now complete.
      final allComplete = _completedTorrents.values.every(
        (completed) => completed,
      );
      if (allComplete && _torrentIds.isNotEmpty) {
        _updateNotificationWithProgress();
      }
    } catch (error) {
      _finalisingTorrents.remove(torrentKey);
      _sendError(
        torrentKey,
        'Failed to finalise download: ${describeTorrentError(error)}',
      );
    }
  }

  Future<void> _broadcastTorrentStates() async {
    final Map<String, dynamic> allStates = {};
    final torrentEntries = Map<String, int>.of(_torrentIds).entries.toList();
    final completedTorrents = Map<String, bool>.of(_completedTorrents);

    for (final entry in torrentEntries) {
      final String torrentKey = entry.key;
      final int torrentId = entry.value;

      if (completedTorrents[torrentKey] ?? false) {
        continue;
      }

      try {
        final TorrentInfo info = await SimpleTorrent.getTorrentInfo(torrentId);

        allStates[torrentKey] = {
          'torrentId': torrentId,
          'info': _serializeTorrentInfo(info),
        };
      } catch (e) {
        // Torrent might have been removed
        print('Error getting state for $torrentKey: $e');
      }
    }

    if (allStates.isNotEmpty) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'bulk_torrent_states',
        'states': allStates,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _stopServiceIfStillComplete(int generation) async {
    if (!_completionStopController.isCurrent(generation) ||
        !_serviceReady ||
        _torrentIds.isEmpty ||
        !_torrentIds.keys.every(
          (torrentKey) => _completedTorrents[torrentKey] ?? false,
        )) {
      return;
    }

    print('🛑 All downloads complete, stopping foreground service');
    // Do not await task destruction from inside the serialized task queue:
    // onDestroy itself drains this queue before releasing the native manager.
    unawaited(FlutterForegroundTask.stopService());
  }

  Future<void> _pauseAllTorrents() async {
    try {
      await SimpleTorrentHelpers.pauseAll();
      FlutterForegroundTask.sendDataToMain({
        'type': 'all_paused',
        'success': true,
      });
    } catch (e) {
      print('Error pausing all torrents: $e');
    }
  }

  Future<void> _resumeAllTorrents() async {
    try {
      await SimpleTorrentHelpers.resumeAll();
      FlutterForegroundTask.sendDataToMain({
        'type': 'all_resumed',
        'success': true,
      });
    } catch (e) {
      print('Error resuming all torrents: $e');
    }
  }

  void _sendError(String torrentKey, String message, {int? requestId}) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'error',
      'torrentKey': torrentKey,
      'message': message,
      'requestId': requestId,
      'serviceInstanceId': _serviceInstanceId,
      'success': false,
    });
  }

  void _sendServiceError(String message) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'service_error',
      'serviceInstanceId': _serviceInstanceId,
      'message': message,
    });
  }

  void _handleTransferPolicyChanged(TransferPolicySnapshot snapshot) {
    _transferPolicy = snapshot;
    _sendTransferPolicyStatus();
    if (_serviceReady) {
      _updateNotificationWithProgress();
    }
  }

  void _handleTransferPolicyError(Object error, StackTrace stackTrace) {
    _serviceReady = false;
    print('Network transfer policy failure: $error\n$stackTrace');
    _sendServiceError(
      'Network transfer policy failed; stopping downloads safely: $error',
    );
    unawaited(_stopAfterTransferPolicyError());
  }

  Future<void> _stopAfterTransferPolicyError() async {
    try {
      await FlutterForegroundTask.stopService();
    } on Object catch (error) {
      print('Failed to stop torrent service after a policy error: $error');
    }
  }

  Future<void> _queryTestTransfersSuspended(
    Map<String, dynamic> command,
  ) async {
    final requestId = command['requestId'];
    if (!networkPolicyTestHookEnabled || requestId is! int) {
      throw StateError('Invalid or disabled transfer-suspension query.');
    }

    FlutterForegroundTask.sendDataToMain({
      'type': 'test_transfers_suspended_result',
      'requestId': requestId,
      'suspended': await SimpleTorrent.areTransfersSuspended(),
    });
  }

  Future<void> _queryTestTorrentState(Map<String, dynamic> command) async {
    final requestId = command['requestId'];
    final torrentKey = command['torrentKey'];
    if (!networkPolicyTestHookEnabled ||
        requestId is! int ||
        torrentKey is! String) {
      throw StateError('Invalid or disabled torrent-state query.');
    }
    final torrentId = _torrentIds[torrentKey];
    if (torrentId == null) {
      throw StateError('Torrent "$torrentKey" is not active.');
    }

    FlutterForegroundTask.sendDataToMain({
      'type': 'test_torrent_state_result',
      'requestId': requestId,
      'torrentState': (await SimpleTorrent.getState(torrentId)).name,
    });
  }

  void _sendServiceReady(DateTime timestamp, {int? requestId}) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'service_ready',
      'serviceInstanceId': _serviceInstanceId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'requestId': requestId,
      ...serializeTransferPolicy(_transferPolicy),
    });
    _sendTransferPolicyStatus();
  }

  void _sendTransferPolicyStatus() {
    FlutterForegroundTask.sendDataToMain({
      'type': 'transfer_policy_status',
      'serviceInstanceId': _serviceInstanceId,
      ...serializeTransferPolicy(_transferPolicy),
    });
  }

  // Serialization helpers
  Map<String, dynamic>? _serializeTorrentInfo(TorrentInfo? info) {
    if (info == null) return null;
    return {'toString': info.toString()};
  }

  void _showTorrentCompletionNotification(String torrentKey) {
    // Get the metadata for display name
    final metadata = _currentMetadata[torrentKey];
    final displayName = metadata?.name ?? torrentKey;

    // Show a separate completion notification for this specific torrent
    FlutterForegroundTask.sendDataToMain({
      'type': 'show_completion_notification',
      'torrentKey': torrentKey,
      'displayName': displayName,
      'message': 'Download completed: $displayName',
    });

    print('🎉 Showing completion notification for: $displayName');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
