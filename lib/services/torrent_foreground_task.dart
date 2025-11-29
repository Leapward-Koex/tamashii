// lib/services/torrent_foreground_task.dart

import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:simple_torrent/simple_torrent.dart';

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

  // Track current torrent states for notification updates
  final Map<String, TorrentStats> _currentStats = {};
  final Map<String, TorrentMetadata> _currentMetadata = {};
  final Map<String, bool> _completedTorrents = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TorrentTaskHandler onStart');

    // Listen to metadata updates for all torrents
    _metadataSub = SimpleTorrent.metadataStream.listen((metadata) {
      _handleMetadataUpdate(metadata);
    });

    // Set up periodic updates every 2 seconds for responsive notifications
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _broadcastTorrentStates();
      _updateNotificationWithProgress(); // Update notification with latest progress
    });

    // Send initial ready message to UI
    FlutterForegroundTask.sendDataToMain({
      'type': 'service_ready',
      'timestamp': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Update notification with current download status
    _updateNotificationWithProgress();
  }

  void _updateNotificationWithProgress() {
    final activeTorrents = _torrentIds.length;

    if (activeTorrents == 0) {
      // No active torrents - stop the service
      print('🛑 No active torrents, stopping foreground service');
      FlutterForegroundTask.stopService();
      return;
    }

    // Check if all torrents are completed (no longer downloading)
    final completedCount =
        _completedTorrents.values.where((completed) => completed).length;
    final downloadingCount =
        _currentStats.values.where((stats) => stats.progress < 1.0).length;

    if (completedCount == activeTorrents &&
        downloadingCount == 0 &&
        activeTorrents > 0) {
      // All torrents finished downloading - show completion notification briefly then stop
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tamashii - Downloads Complete! 🎉',
        notificationText: 'All $activeTorrents torrent(s) finished downloading',
      );

      // Stop the service after a short delay to let user see the completion message
      Timer(const Duration(seconds: 5), () {
        print('🛑 All downloads complete, stopping foreground service');
        FlutterForegroundTask.stopService();
      });
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

      final String title = 'Tamashii - ${avgProgress.toStringAsFixed(1)}% Complete';
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

    // Clean up resources
    _updateTimer?.cancel();
    _metadataSub?.cancel();

    // Cancel all subscriptions
    for (final sub in _statsSubs.values) {
      sub.cancel();
    }
    _statsSubs.clear();

    // Stop all torrents
    for (final torrentId in _torrentIds.values) {
      try {
        await SimpleTorrent.cancel(torrentId);
      } catch (e) {
        print('Error removing torrent $torrentId: $e');
      }
    }

    _torrentIds.clear();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      _handleCommand(data);
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause_all') {
      _pauseAllTorrents();
    } else if (id == 'resume_all') {
      _resumeAllTorrents();
    }
  }

  @override
  void onNotificationPressed() {
    // User tapped notification - could launch app to main route
  }

  @override
  void onNotificationDismissed() {
    // Notification was dismissed
  }

  void _handleCommand(Map<String, dynamic> command) async {
    final String? type = command['type'];

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
      default:
        print('Unknown command type: $type');
    }
  }

  Future<void> _startDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final String magnetUri = command['magnetUri'];
      final String downloadPath = command['downloadPath'];

      // Use SimpleTorrentHelpers for enhanced functionality
      // /storage/emulated/0/Download
      // /storage/emulated/0/SdCardBackUp/Tamashii/Witch Watch
      // "/storage/emulated/0/SdCardBackUp/Tamashii/Ww"

      final (id, statsStream) = await SimpleTorrentHelpers.startAndWatch(
        magnet: magnetUri,
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
      _sendError(torrentKey, 'Failed to start download: $e');
    }
  }

  Future<void> _pauseDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(torrentKey, 'Torrent not found');
        return;
      }

      await SimpleTorrent.pause(torrentId);

      FlutterForegroundTask.sendDataToMain({
        'type': 'download_paused',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(torrentKey, 'Failed to pause download: $e');
    }
  }

  Future<void> _resumeDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(torrentKey, 'Torrent not found');
        return;
      }

      await SimpleTorrent.resume(torrentId);

      FlutterForegroundTask.sendDataToMain({
        'type': 'download_resumed',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(torrentKey, 'Failed to resume download: $e');
    }
  }

  Future<void> _removeDownload(Map<String, dynamic> command) async {
    try {
      final String torrentKey = command['torrentKey'];
      final int? torrentId = _torrentIds[torrentKey];

      if (torrentId == null) {
        _sendError(torrentKey, 'Torrent not found');
        return;
      }

      await SimpleTorrent.cancel(torrentId);

      // Clean up subscriptions and tracking data
      _statsSubs[torrentId]?.cancel();
      _statsSubs.remove(torrentId);
      _torrentIds.remove(torrentKey);
      _currentStats.remove(torrentKey);
      _currentMetadata.remove(torrentKey);
      _completedTorrents.remove(torrentKey);

      FlutterForegroundTask.sendDataToMain({
        'type': 'download_removed',
        'torrentKey': torrentKey,
        'torrentId': torrentId,
        'success': true,
      });
    } catch (e) {
      final String torrentKey = command['torrentKey'] ?? 'unknown';
      _sendError(torrentKey, 'Failed to remove download: $e');
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
      _sendError(torrentKey, 'Failed to get torrent state: $e');
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
        if (stats.progress >= 1.0) {
          print('✅ Torrent completed for $torrentKey');

          // Show individual completion notification
          SimpleTorrent.finalise(torrentId);
          _showTorrentCompletionNotification(torrentKey);

          _statsSubs[torrentId]?.cancel();
          _statsSubs.remove(torrentId);

          // Check if all torrents are now complete
          final allComplete = _completedTorrents.values.every(
            (completed) => completed,
          );
          if (allComplete && _torrentIds.isNotEmpty) {
            // Trigger final notification update
            _updateNotificationWithProgress();
          }
        }
      },
      onError: (error) {
        print('❌ Stats stream error for $torrentKey: $error');
        _sendError(torrentKey, 'Stats stream error: $error');
      },
    );

    _statsSubs[torrentId] = sub;
  }

  void _broadcastTorrentStates() async {
    final Map<String, dynamic> allStates = {};

    for (final entry in _torrentIds.entries) {
      final String torrentKey = entry.key;
      final int torrentId = entry.value;

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

  void _pauseAllTorrents() async {
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

  void _resumeAllTorrents() async {
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

  void _sendError(String torrentKey, String message) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'error',
      'torrentKey': torrentKey,
      'message': message,
      'success': false,
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
