// lib/providers/foreground_torrent_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/torrent_foreground_task.dart';
import '../providers/torrent_download_provider.dart';

part 'foreground_torrent_provider.g.dart';

// Provider for managing the foreground service state
@Riverpod(keepAlive: true)
class ForegroundTorrentManager extends _$ForegroundTorrentManager {
  bool _isServiceRunning = false;
  StreamSubscription<dynamic>? _dataSubscription;

  @override
  TorrentManagerState build() {
    // Add callback to receive data from the foreground service
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    
    ref.onDispose(() {
      _dataSubscription?.cancel();
      // Remove the callback when disposing
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      _stopForegroundService();
    });

    return const TorrentManagerState();
  }

  // Callback to receive data sent from the TaskHandler
  void _onReceiveTaskData(Object data) {
    print('📨 Received data from foreground service: $data');
    handleServiceData(data);
  }

  Future<void> initializeForegroundService() async {
    // Initialize communication port first
    FlutterForegroundTask.initCommunicationPort();
    
    // Request permissions
    await _requestPermissions();
    
    // Initialize the service
    _initService();
    
    // Start the service if not already running
    if (!_isServiceRunning) {
      await _startForegroundService();
    }
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
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
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Update every 5 seconds
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Tamashii - Torrent Service',
        notificationText: 'Managing torrent downloads',
        notificationIcon: null,
        notificationButtons: [
          const NotificationButton(id: 'pause_all', text: 'Pause All'),
          const NotificationButton(id: 'resume_all', text: 'Resume All'),
        ],
        callback: startTorrentCallback,
      );
      
      // Assume success since startService completed without exception
      _isServiceRunning = true;
    }
  }

  Future<void> _stopForegroundService() async {
    if (_isServiceRunning) {
      await FlutterForegroundTask.stopService();
      _isServiceRunning = false;
    }
  }

  // Public methods to control downloads
  Future<void> startDownload(String torrentKey, String magnetUri, String downloadPath) async {
    if (!_isServiceRunning) {
      await initializeForegroundService();
    }
    
    // Set loading state immediately
    final currentState = state.torrents[torrentKey] ?? const TorrentDownloadState();
    _updateTorrentState(torrentKey, currentState.copyWith(isLoading: true, clearError: true));
    
    // Send command to service
    FlutterForegroundTask.sendDataToTask({
      'type': 'start_download',
      'torrentKey': torrentKey,
      'magnetUri': magnetUri,
      'downloadPath': downloadPath,
    });
  }

  Future<void> pauseDownload(String torrentKey) async {
    FlutterForegroundTask.sendDataToTask({
      'type': 'pause_download',
      'torrentKey': torrentKey,
    });
  }

  Future<void> resumeDownload(String torrentKey) async {
    FlutterForegroundTask.sendDataToTask({
      'type': 'resume_download',
      'torrentKey': torrentKey,
    });
  }

  Future<void> removeDownload(String torrentKey) async {
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
          print('📢 ${type == 'all_paused' ? 'All torrents paused' : 'All torrents resumed'}');
          break;
          
        case 'error':
          _handleError(data);
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
      final currentState = state.torrents[torrentKey] ?? const TorrentDownloadState();
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
    
    final currentState = state.torrents[torrentKey] ?? const TorrentDownloadState();
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
  }

  void _handleStatsUpdate(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final Map<String, dynamic>? statsData = data['stats'];
    
    if (torrentKey == null || statsData == null) return;
    
    final currentState = state.torrents[torrentKey] ?? const TorrentDownloadState();
    
    // Extract progress information from serialized data
    final progress = (statsData['progress'] as num?)?.toDouble() ?? 0.0;
    final downloadRate = statsData['downloadRate'] ?? 0;
    final uploadRate = statsData['uploadRate'] ?? 0;
    final seeds = statsData['seeds'] ?? 0;
    final peers = statsData['peers'] ?? 0;
    final torrentState = statsData['state'] as String?; // Extract state
    
    // Create a new state with custom progress tracking
    final newState = currentState.copyWithCustomProgress(
      progress: progress,
      downloadRate: downloadRate,
      uploadRate: uploadRate,
      seeds: seeds,
      peers: peers,
      state: torrentState, // Pass the state
    );
    
    _updateTorrentState(torrentKey, newState);
    
    // Log the stats for debugging
    print('📊 Stats update for $torrentKey: ${progress.toStringAsFixed(1)}% (${_formatBytes(downloadRate)}/s) - State: ${torrentState ?? 'unknown'}');
  }

  void _handleMetadataUpdate(Map<String, dynamic> data) {
    final String? torrentKey = data['torrentKey'];
    final Map<String, dynamic>? metadataData = data['metadata'];
    
    if (torrentKey == null || metadataData == null) return;
    
    final currentState = state.torrents[torrentKey] ?? const TorrentDownloadState();
    
    // Extract metadata information from serialized data
    final name = metadataData['name'] as String? ?? 'Unknown';
    final totalBytes = metadataData['totalBytes'] as int? ?? 0;
    final fileCount = metadataData['fileCount'] as int? ?? 0;
    
    // Create a new state with custom metadata tracking
    final newState = currentState.copyWithCustomMetadata(
      displayName: name,
      totalBytes: totalBytes,
      fileCount: fileCount,
    );
    
    _updateTorrentState(torrentKey, newState);
    
    print('📋 Metadata updated for $torrentKey: $name');
  }

  void _handleBulkStates(Map<String, dynamic> data) {
    final Map<String, dynamic>? states = data['states'];
    if (states == null) return;
    
    final Map<String, TorrentDownloadState> newTorrents = Map.from(state.torrents);
    
    for (final entry in states.entries) {
      final String torrentKey = entry.key;
      final Map<String, dynamic> stateData = entry.value;
      final int? torrentId = stateData['torrentId'];
      
      if (torrentId != null) {
        final currentState = newTorrents[torrentKey] ?? const TorrentDownloadState();
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
      final currentState = state.torrents[torrentKey] ?? const TorrentDownloadState();
      final newState = currentState.copyWith(
        errorMessage: message,
        isLoading: false,
      );
      _updateTorrentState(torrentKey, newState);
      print('❌ Error for $torrentKey: $message');
    }
  }
}

// Provider for individual torrent states
@riverpod
TorrentDownloadState foregroundTorrentForShow(Ref ref, String showId) {
  final manager = ref.watch(foregroundTorrentManagerProvider);
  return manager.torrents[showId] ?? const TorrentDownloadState();
}
