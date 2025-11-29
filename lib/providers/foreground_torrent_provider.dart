// lib/providers/foreground_torrent_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/services/torrent_foreground_task.dart';
import 'package:tamashii/services/notification_service.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';

part 'foreground_torrent_provider.g.dart';

// Provider for managing the foreground service state
@Riverpod(keepAlive: true)
class ForegroundTorrentManager extends _$ForegroundTorrentManager {
  bool _isServiceRunning = false;
  StreamSubscription<dynamic>? _dataSubscription;
  final Map<String, String> _downloadPaths = {}; // torrentKey -> downloadPath

  @override
  TorrentManagerState build() {
    if (Platform.isAndroid) {
      // Add callback to receive data from the foreground service
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

      ref.onDispose(() {
        _dataSubscription?.cancel();
        // Remove the callback when disposing
        FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
        _stopForegroundService();
      });

      // Initialize permissions and communication port but don't start service
      _initializeWithoutStarting();
    }

    return const TorrentManagerState();
  }

  Future<void> _initializeWithoutStarting() async {
    if (!Platform.isAndroid) return;

    // Initialize communication port first
    FlutterForegroundTask.initCommunicationPort();

    // Request permissions
    await _requestPermissions();

    // Initialize the service configuration but don't start it
    _initService();
  }

  // Callback to receive data sent from the TaskHandler
  void _onReceiveTaskData(Object data) {
    print('📨 Received data from foreground service: $data');
    handleServiceData(data);
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    if (!Platform.isAndroid) return;

    if (_isServiceRunning) return;

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Tamashii - Starting Downloads',
        notificationText: 'Initializing torrent downloads...',
        notificationButtons: [
          const NotificationButton(id: 'pause_all', text: 'Pause All'),
          const NotificationButton(id: 'resume_all', text: 'Resume All'),
        ],
        callback: startTorrentCallback,
      );
    }

    _isServiceRunning = true;
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    if (Platform.isAndroid) {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
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

  Future<void> _stopForegroundService() async {
    if (!Platform.isAndroid) return;

    if (_isServiceRunning) {
      await FlutterForegroundTask.stopService();
      _isServiceRunning = false;
    }
  }

  void _checkAndStopServiceIfIdle() {
    // Stop service if no active downloads and all torrents are complete or removed
    final activeTorrents =
        state.torrents.values
            .where(
              (torrent) => torrent.torrentId != null && !torrent.isCompleted,
            )
            .length;

    if (activeTorrents == 0 && _isServiceRunning) {
      _stopForegroundService();
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
      // Check storage permissions before starting download
      print('🔐 Checking storage permissions for $torrentKey');
      final hasPermissions = await PermissionService.hasStoragePermissions();

      if (!hasPermissions) {
        print('🔒 Storage permissions not granted, requesting...');
        final granted = await PermissionService.requestStoragePermissions();

        if (!granted) {
          throw Exception(
            'Storage permissions are required to download torrents. Please grant storage access in app settings.',
          );
        }
        print('✅ Storage permissions granted');
      }

      // Start the service only when we actually need to download something
      if (!_isServiceRunning) {
        await _startForegroundServiceIfNeeded();
      }

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
    }
  }

  Future<void> pauseDownload(String torrentKey) async {
    if (!Platform.isAndroid) {
      await ref.read(torrentManagerProvider.notifier).pauseDownload(torrentKey);
      return;
    }

    FlutterForegroundTask.sendDataToTask({
      'type': 'pause_download',
      'torrentKey': torrentKey,
    });
  }

  Future<void> resumeDownload(String torrentKey) async {
    if (!Platform.isAndroid) {
      await ref
          .read(torrentManagerProvider.notifier)
          .resumeDownload(torrentKey);
      return;
    }

    FlutterForegroundTask.sendDataToTask({
      'type': 'resume_download',
      'torrentKey': torrentKey,
    });
  }

  Future<void> removeDownload(String torrentKey) async {
    if (!Platform.isAndroid) {
      await ref.read(torrentManagerProvider.notifier).stopDownload(torrentKey);
      return;
    }

    FlutterForegroundTask.sendDataToTask({
      'type': 'remove_download',
      'torrentKey': torrentKey,
    });
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
    if (data is Map<String, dynamic>) {
      final String? type = data['type'];

      switch (type) {
        case 'service_ready':
          print('✅ Foreground service is ready');
          break;

        case 'download_started':
          _handleDownloadStarted(data);
          break;

        case 'download_paused':
        case 'download_resumed':
        case 'download_removed':
          _handleTorrentStatusUpdate(data);
          break;

        case 'stats_update':
          _handleStatsUpdate(data);
          break;

        case 'metadata_update':
          _handleMetadataUpdate(data);
          break;

        case 'bulk_torrent_states':
          _handleBulkStates(data);
          break;

        case 'all_paused':
        case 'all_resumed':
          print(
            '📢 ${type == 'all_paused' ? 'All torrents paused' : 'All torrents resumed'}',
          );
          break;

        case 'error':
          _handleError(data);
          break;

        case 'show_completion_notification':
          _handleCompletionNotification(data);
          break;

        default:
          print('🔍 Unknown data type from service: $type');
      }
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

      // Persist completed download and stop service if idle
      if (stats.progress >= 1.0) {
        if (_downloadPaths.containsKey(torrentKey)) {
          ref
              .read(downloadedTorrentsProvider.notifier)
              .addDownloaded(torrentKey);
        }
        _checkAndStopServiceIfIdle();
      }

      // Log the stats for debugging
      print(
        '📊 Stats update for $torrentKey: ${(stats.progress * 100).toStringAsFixed(1)}% (${_formatBytes(stats.downloadRate)}/s) - State: ${stats.state.name ?? 'unknown'}',
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
