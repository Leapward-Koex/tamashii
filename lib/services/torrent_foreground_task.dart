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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('TorrentTaskHandler onStart');
    
    // Listen to metadata updates for all torrents
    _metadataSub = SimpleTorrent.metadataStream.listen((metadata) {
      _handleMetadataUpdate(metadata);
    });
    
    // Set up periodic updates every 1 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _broadcastTorrentStates();
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
    final activeTorrents = _torrentIds.length;
    FlutterForegroundTask.updateService(
      notificationTitle: 'Tamashii - Torrent Service',
      notificationText: activeTorrents > 0 
        ? 'Managing $activeTorrents torrent(s)'
        : 'Ready for downloads',
    );
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
      final (id, statsStream) = await SimpleTorrentHelpers.startAndWatch(
        magnet: magnetUri,
        path: downloadPath,
        displayName: torrentKey, // Use torrentKey as display name
      );
      
      // Store mapping
      _torrentIds[torrentKey] = id;
      
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
      
      // Clean up subscriptions
      _statsSubs[torrentId]?.cancel();
      _statsSubs.remove(torrentId);
      _torrentIds.remove(torrentKey);
      
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
        FlutterForegroundTask.sendDataToMain({
          'type': 'metadata_update',
          'torrentKey': torrentKey,
          'torrentId': torrentId,
          'metadata': _serializeTorrentMetadata(metadata),
        });
        break;
      }
    }
  }

  void _listenToTorrent(int torrentId, String torrentKey, Stream<TorrentStats> statsStream) {
    _statsSubs[torrentId]?.cancel();

    final sub = statsStream.listen(
      (stats) {
        FlutterForegroundTask.sendDataToMain({
          'type': 'stats_update',
          'torrentKey': torrentKey,
          'torrentId': torrentId,
          'stats': _serializeTorrentStats(stats),
        });

        // Auto-cleanup completed torrents
        if (stats.progress >= 100) {
          print('✅ Torrent completed for $torrentKey');
          _statsSubs[torrentId]?.cancel();
          _statsSubs.remove(torrentId);
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
        final TorrentInfo? info = await SimpleTorrent.getTorrentInfo(torrentId);
        
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
    return {
      'toString': info.toString(),
    };
  }

  Map<String, dynamic>? _serializeTorrentStats(TorrentStats? stats) {
    if (stats == null) return null;
    return {
      'progress': stats.progress,
      'downloadRate': stats.downloadRate,
      'uploadRate': stats.uploadRate,
      'seeds': stats.seeds,
      'peers': stats.peers,
      'phase': stats.phase,
      'state': stats.state?.name ?? 'unknown',
    };
  }

  Map<String, dynamic>? _serializeTorrentMetadata(TorrentMetadata? metadata) {
    if (metadata == null) return null;
    return {
      'id': metadata.id,
      'name': metadata.name,
      'totalBytes': metadata.totalBytes,
      'fileCount': metadata.fileCount,
    };
  }
}
