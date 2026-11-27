// lib/services/torrent_foreground_task.dart

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/config/torrent_config.dart';
import 'package:tamashii/config/torrent_download_config.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/services/download_transfer_metrics.dart';
import 'package:tamashii/services/downloaded_episode_store.dart';
import 'package:tamashii/services/foreground_service_lifecycle.dart';
import 'package:tamashii/services/notification_service.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/services/torrent_runtime.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii/services/widget_transfer_bridge.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

// The callback function should always be a top-level or static function.
@pragma('vm:entry-point')
void startTorrentCallback() {
  FlutterForegroundTask.setTaskHandler(TorrentTaskHandler());
}

class TorrentTaskHandler extends TaskHandler {
  TorrentTaskHandler({
    this._runtime = const SimpleTorrentRuntime(),
    this._policyRuntime = const SimpleTorrentTransferRuntime(),
    this._network = const PluginNetworkStatusSource(),
    WidgetTransferBridge? widget,
    DelayedActionScheduler? scheduleStop,
  }) : _widget = widget ?? WidgetTransferBridge(),
       _completionStopController = DelayedServiceStopController(
         scheduler: scheduleStop,
       );

  final TorrentRuntime _runtime;
  final TorrentTransferRuntime _policyRuntime;
  final NetworkStatusSource _network;
  final WidgetTransferBridge _widget;
  final Map<String, int> _torrentIds = {}; // torrentKey -> torrentId mapping
  final Map<int, StreamSubscription<TorrentStats>> _statsSubs = {};
  StreamSubscription<TorrentMetadata>? _metadataSub;
  Timer? _updateTimer;
  final DelayedServiceStopController _completionStopController;

  // Track current torrent states for notification updates
  final Map<String, TorrentStats> _currentStats = {};
  final Map<String, TorrentMetadata> _currentMetadata = {};
  final Set<String> _completedTorrents = {};
  final Set<String> _pausedTorrents = {};
  final Map<String, String> _torrentErrors = {};
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
        runtime: _policyRuntime,
        networkStatusSource: testNetworkStatusSource ?? _network,
        readAllowMeteredDownloads: readAllowMeteredDownloadsPreference,
        readAllowMobileData: readAllowMobileDataPreference,
        onChanged: _handleTransferPolicyChanged,
        onError: _handleTransferPolicyError,
      );
      _transferPolicyController = transferPolicyController;
      await transferPolicyController.initialize();

      // This engine owns its own v2 manager, so streams must only be observed
      // after initialization and the current network policy has been applied.
      _metadataSub = _runtime.metadataStream.listen(_handleMetadataUpdate);

      // Stats, metadata and control changes already stream to the UI. A full
      // snapshot is needed only when an engine attaches to a running service.
      _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _updateNotificationWithProgress();
      });

      _serviceReady = true;
      _sendServiceReady(timestamp);
      _enqueueCommand(_consumeWidgetDownloads);
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
        await _consumeWidgetDownloads();
        _updateNotificationWithProgress();
      }
    });
  }

  void _updateNotificationWithProgress() {
    if (!_serviceReady) return;
    for (final key in _torrentIds.keys) {
      unawaited(_publishWidgetState(key));
    }
    final report = _buildTransferReport();
    final summary = report.summary;
    final activeTorrents = summary.trackedCount;

    final empty = _torrentIds.isEmpty;
    if (_allTrackedTorrentsCompleted || empty) {
      // A tap can expire at midnight or finish elsewhere before this engine
      // starts. Allow time for a concurrent UI attach and its first command.
      _completionStopController.schedule(
        delay: empty ? const Duration(seconds: 45) : const Duration(seconds: 5),
        onElapsed: (generation) {
          _enqueueCommand(() => _stopServiceIfIdle(generation));
        },
      );
      if (!empty) return;
    }

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

    if (summary.liveCount > 0) {
      final progressLabel =
          '${(summary.progressFraction * 100).toStringAsFixed(1)}%'
          '${summary.progressIsEstimated ? ' estimated' : ''}';
      final title = 'Tamashii - $progressLabel Complete';
      String text;

      if (summary.downloadingCount > 0) {
        text =
            '${summary.downloadingCount} downloading • '
            '↓${DownloadTransferFormatters.formatRate(summary.downloadRate)} '
            '• ↑${DownloadTransferFormatters.formatRate(summary.uploadRate)}';
        if (summary.eta != null) {
          text += ' • ETA ${DownloadTransferFormatters.formatEta(summary.eta)}';
        }
      } else if (summary.preparingCount > 0) {
        text = '${summary.preparingCount} preparing download(s)';
      } else if (summary.pausedCount > 0) {
        text = '${summary.pausedCount} download(s) paused';
      } else if (summary.failedCount > 0) {
        text = '${summary.failedCount} download(s) need attention';
      } else {
        text = 'Managing $activeTorrents torrent(s)';
      }

      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  DownloadTransferReport _buildTransferReport() {
    // Errors can occur before a native torrent ID is allocated (for example,
    // while resolving a magnet) and after it reaches 100% (during finalise).
    // Include every tracking map so the notification sees the same failed
    // transfer states that the app UI receives over the service channel.
    final torrentKeys = <String>{
      ..._torrentIds.keys,
      ..._currentStats.keys,
      ..._currentMetadata.keys,
      ..._completedTorrents,
      ..._torrentErrors.keys,
    };
    return DownloadTransferMetrics.build(
      torrentKeys.map(
        (torrentKey) => DownloadTransferSnapshot(
          key: torrentKey,
          stats: _currentStats[torrentKey],
          metadata: _currentMetadata[torrentKey],
          isCompleted: _completedTorrents.contains(torrentKey),
          isPaused: _pausedTorrents.contains(torrentKey),
          isPreparing: _currentStats[torrentKey] == null,
          isPolicyBlocked: _transferPolicy.suspended,
          errorMessage: _torrentErrors[torrentKey],
        ),
      ),
    );
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
    _pausedTorrents.clear();
    _torrentErrors.clear();
    _finalisingTorrents.clear();
    await _widget.serviceStopped();
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
      if (command['type'] == 'start_download' ||
          command['type'] == 'widget_downloads_pending' ||
          (_torrentIds.isEmpty && command['type'] == 'request_service_state')) {
        _completionStopController.invalidate();
      }
      _enqueueCommand(() => _handleCommand(command));
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause_all') {
      _enqueueCommand(() => _pauseAllTorrents());
    } else if (id == 'resume_all') {
      _enqueueCommand(() => _resumeAllTorrents());
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
      case 'widget_downloads_pending':
        await _consumeWidgetDownloads();
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
      case 'pause_all_downloads':
        await _pauseAllTorrents(requestId: command['requestId'] as int?);
        break;
      case 'resume_all_downloads':
        await _resumeAllTorrents(requestId: command['requestId'] as int?);
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
        _sendServiceSnapshot();
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

  Future<void> _consumeWidgetDownloads() async {
    if (!_serviceReady) return;
    late final List<Map<String, dynamic>> pending;
    try {
      pending = await _widget.pendingDownloads();
    } catch (error) {
      // Launcher state can be temporarily unavailable while engines attach.
      // The next repeat event retries without interrupting in-app transfers.
      print('Could not read pending widget downloads: $error');
      return;
    }
    for (final command in pending) {
      if (!_serviceReady) return;
      await _startDownload(command, fromWidget: true);
    }
  }

  Future<void> _publishWidgetState(String key, {bool force = false}) {
    final stats = _currentStats[key];
    final status = switch (stats?.state) {
      _ when _torrentErrors.containsKey(key) => 'failed',
      _ when _completedTorrents.contains(key) => 'completed',
      TorrentState.error || TorrentState.stopped => 'failed',
      _ when _transferPolicy.suspended => 'waiting',
      _ when _pausedTorrents.contains(key) => 'paused',
      TorrentState.paused => 'paused',
      null ||
      TorrentState.starting ||
      TorrentState.downloadingMetadata => 'queued',
      _ => 'downloading',
    };
    return _widget.publish(
      key,
      status,
      fraction: status == 'queued' ? null : stats?.progress,
      force: force,
    );
  }

  Future<void> _startDownload(
    Map<String, dynamic> command, {
    bool fromWidget = false,
  }) async {
    _completionStopController.invalidate();
    try {
      final String torrentKey = command['torrentKey'];
      final String magnetUri = command['magnetUri'];
      final String downloadPath = command['downloadPath'];

      final existing = _torrentIds[torrentKey];
      if (_completedTorrents.contains(torrentKey) &&
          _torrentErrors.containsKey(torrentKey)) {
        // If saving history failed after native finalisation, a retry only
        // needs to persist the marker. The completed payload is already safe.
        await _recordCompletion(torrentKey);
        _updateNotificationWithProgress();
        return;
      }
      if (existing != null && !_completedTorrents.contains(torrentKey)) {
        // Both the app and launcher use this serialized command queue. Keep a
        // single native handle even if a second tap arrived during startup.
        final previous = _currentStats[torrentKey];
        final failed =
            _torrentErrors.containsKey(torrentKey) ||
            previous?.state == TorrentState.error ||
            previous?.state == TorrentState.stopped;
        if (failed && fromWidget) {
          if ((_currentStats[torrentKey]?.progress ?? 0) >= 1) {
            await _finaliseCompletedTorrent(existing, torrentKey);
            await _publishWidgetState(torrentKey, force: true);
            return;
          }
          await _runtime.resume(existing);
          _currentStats.remove(torrentKey); // Await a fresh native sample.
          _pausedTorrents.remove(torrentKey);
          _torrentErrors.remove(torrentKey);
        }
        await _publishWidgetState(torrentKey, force: true);
        _sendDownloadStarted(torrentKey, existing);
        return;
      }
      if ((fromWidget || command['redownload'] != true) &&
          (await readDownloadedTorrentKeys()).contains(torrentKey)) {
        await _widget.publish(
          torrentKey,
          'completed',
          fraction: 1,
          force: true,
        );
        _sendFinalised(torrentKey);
        return;
      }
      if (fromWidget) {
        if (!await PermissionService.hasStoragePermissions()) {
          throw StateError('Grant storage access in Tamashii to download.');
        }
        final error = await PermissionService.validateDownloadDirectory(
          downloadPath,
        );
        if (error != null) throw StateError(error);
      }

      if (!_serviceReady) return;
      final (id, statsStream) = await _runtime.startAndWatch(
        magnet: resolveTorrentMagnetUri(magnetUri),
        path: downloadPath,
        displayName: torrentKey, // Use torrentKey as display name
      );
      // The Android engine may be shutting down while the magnet is opening.
      // Its manager will detach without deleting any files.
      if (!_serviceReady) return;

      // Store mapping
      _completionStopController.invalidate();
      _torrentIds[torrentKey] = id;

      // Initialize tracking
      _completedTorrents.remove(torrentKey);
      _finalisingTorrents.remove(torrentKey);
      _currentStats.remove(torrentKey);
      _currentMetadata.remove(torrentKey);
      _pausedTorrents.remove(torrentKey);
      _torrentErrors.remove(torrentKey);

      // Listen to stats updates
      _listenToTorrent(id, torrentKey, statsStream);

      await _publishWidgetState(torrentKey, force: true);
      _sendDownloadStarted(torrentKey, id);
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(
        torrentKey,
        'Failed to start download: ${describeTorrentError(e)}',
      );
    }
  }

  void _sendDownloadStarted(String key, int id) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'download_started',
      'torrentKey': key,
      'torrentId': id,
      'success': true,
    });
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

      await _runtime.pause(torrentId);
      _pausedTorrents.add(torrentKey);
      _torrentErrors.remove(torrentKey);
      await _publishWidgetState(torrentKey);

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

      await _runtime.resume(torrentId);
      _pausedTorrents.remove(torrentKey);
      _torrentErrors.remove(torrentKey);
      await _publishWidgetState(torrentKey);

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

      await _runtime.cancel(torrentId);

      // Clean up subscriptions and tracking data
      await _statsSubs[torrentId]?.cancel();
      _statsSubs.remove(torrentId);
      _torrentIds.remove(torrentKey);
      _currentStats.remove(torrentKey);
      _currentMetadata.remove(torrentKey);
      _completedTorrents.remove(torrentKey);
      _pausedTorrents.remove(torrentKey);
      _torrentErrors.remove(torrentKey);
      _finalisingTorrents.remove(torrentKey);
      await _widget.publish(torrentKey, 'removed', force: true);

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
        _torrentErrors.remove(torrentKey);
        unawaited(_publishWidgetState(torrentKey));

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
      await _runtime.finalise(torrentId);
      await _statsSubs[torrentId]?.cancel();
      _statsSubs.remove(torrentId);
    } catch (error) {
      _finalisingTorrents.remove(torrentKey);
      _sendError(
        torrentKey,
        'Failed to finalise download: ${describeTorrentError(error)}',
      );
      return;
    }

    _finalisingTorrents.remove(torrentKey);
    _completedTorrents.add(torrentKey);
    if (!await _recordCompletion(torrentKey)) return;

    try {
      // This engine remains alive in the background. The separate Android
      // notification stays visible after the foreground service is stopped.
      await NotificationService.showDownloadCompletion(
        torrentKey: torrentKey,
        displayName: _currentMetadata[torrentKey]?.name ?? torrentKey,
        completedCount: _allTrackedTorrentsCompleted
            ? _completedTorrents.length
            : 1,
      );
    } catch (error) {
      print('Failed to show download completion notification: $error');
    }
    _updateNotificationWithProgress();
  }

  void _sendFinalised(String torrentKey) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'download_finalised',
      'torrentKey': torrentKey,
      'serviceInstanceId': _serviceInstanceId,
    });
  }

  Future<bool> _recordCompletion(String torrentKey) async {
    try {
      await writeDownloadedTorrentKey(torrentKey, true);
    } catch (error) {
      _sendError(torrentKey, 'Could not record completed download: $error');
      return false;
    }
    _torrentErrors.remove(torrentKey);
    _sendFinalised(torrentKey);
    await _widget.publish(torrentKey, 'completed', fraction: 1, force: true);
    return true;
  }

  void _sendServiceSnapshot() {
    final Map<String, dynamic> allStates = {};
    for (final entry in _torrentIds.entries) {
      final String torrentKey = entry.key;
      final int torrentId = entry.value;

      if (_completedTorrents.contains(torrentKey)) {
        continue;
      }

      allStates[torrentKey] = {
        'torrentId': torrentId,
        'stats': _currentStats[torrentKey]?.toMap(),
        'metadata': _currentMetadata[torrentKey]?.toMap(),
        'isPaused': _pausedTorrents.contains(torrentKey),
        'errorMessage': _torrentErrors[torrentKey],
      };
    }

    // Send empty authoritative snapshots too: a reattached UI needs to know
    // that an earlier live transfer no longer belongs to this service rather
    // than retaining a stale downloading card.
    FlutterForegroundTask.sendDataToMain({
      'type': 'bulk_torrent_states',
      'serviceInstanceId': _serviceInstanceId,
      'states': allStates,
      'isServiceSnapshot': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  bool get _allTrackedTorrentsCompleted =>
      _torrentIds.isNotEmpty &&
      _torrentErrors.isEmpty &&
      _torrentIds.keys.every(_completedTorrents.contains);

  Future<void> _stopServiceIfIdle(int generation) async {
    if (!_completionStopController.isCurrent(generation) || !_serviceReady) {
      return;
    }
    await _consumeWidgetDownloads();
    if (!_completionStopController.isCurrent(generation) ||
        !_serviceReady ||
        (_torrentIds.isNotEmpty && !_allTrackedTorrentsCompleted)) {
      return;
    }

    print('No active downloads, stopping foreground service');
    // Do not await task destruction from inside the serialized task queue:
    // onDestroy itself drains this queue before releasing the native manager.
    unawaited(FlutterForegroundTask.stopService());
  }

  Future<void> _pauseAllTorrents({int? requestId}) async {
    final torrentKeys = _incompleteTorrentKeys();
    try {
      await _runtime.pauseAll();
      _pausedTorrents.addAll(torrentKeys);
      for (final torrentKey in torrentKeys) {
        _torrentErrors.remove(torrentKey);
      }
      FlutterForegroundTask.sendDataToMain({
        'type': 'all_paused',
        'torrentKeys': torrentKeys,
        'requestId': requestId,
        'serviceInstanceId': _serviceInstanceId,
        'success': true,
      });
      _updateNotificationWithProgress();
    } catch (e) {
      print('Error pausing all torrents: $e');
      _sendError(
        'all downloads',
        'Failed to pause all downloads: ${describeTorrentError(e)}',
        requestId: requestId,
        isBulkCommand: true,
      );
    }
  }

  Future<void> _resumeAllTorrents({int? requestId}) async {
    final torrentKeys = _incompleteTorrentKeys();
    try {
      await _runtime.resumeAll();
      _pausedTorrents.removeAll(torrentKeys);
      for (final torrentKey in torrentKeys) {
        _torrentErrors.remove(torrentKey);
      }
      FlutterForegroundTask.sendDataToMain({
        'type': 'all_resumed',
        'torrentKeys': torrentKeys,
        'requestId': requestId,
        'serviceInstanceId': _serviceInstanceId,
        'success': true,
      });
      _updateNotificationWithProgress();
    } catch (e) {
      print('Error resuming all torrents: $e');
      _sendError(
        'all downloads',
        'Failed to resume all downloads: ${describeTorrentError(e)}',
        requestId: requestId,
        isBulkCommand: true,
      );
    }
  }

  List<String> _incompleteTorrentKeys() {
    return _torrentIds.keys
        .where((torrentKey) => !_completedTorrents.contains(torrentKey))
        .toList(growable: false);
  }

  void _sendError(
    String torrentKey,
    String message, {
    int? requestId,
    bool isBulkCommand = false,
  }) {
    // Bulk command failures are surfaced through their request-correlated
    // response. They do not belong to a real torrent row or notification
    // report entry.
    if (!isBulkCommand) {
      _torrentErrors[torrentKey] = message;
      unawaited(_publishWidgetState(torrentKey, force: true));
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'error',
      'torrentKey': torrentKey,
      'message': message,
      'requestId': requestId,
      'isBulkCommand': isBulkCommand,
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
}
