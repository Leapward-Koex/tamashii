import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:simple_torrent/simple_torrent.dart';

part 'torrent_download_provider.g.dart';

// Represents the overall manager state: a mapping of showId -> TorrentDownloadState.
class TorrentManagerState {
  final Map<String, TorrentDownloadState> torrents;
  const TorrentManagerState({this.torrents = const {}});

  TorrentManagerState copyWith({Map<String, TorrentDownloadState>? torrents}) {
    return TorrentManagerState(torrents: torrents ?? this.torrents);
  }
}

class TorrentDownloadState {
  final int? torrentId;
  final TorrentStats? stats;
  final TorrentMetadata? metadata;
  final bool isLoading;
  final bool isPaused;
  final String? errorMessage;
  
  // Custom fields for tracking serialized data from foreground service
  final double? customProgress;
  final int? customDownloadRate;
  final int? customUploadRate;
  final int? customSeeds;
  final int? customPeers;
  final String? customDisplayName;
  final int? customTotalBytes;
  final int? customFileCount;
  final String? customState; // Add custom state tracking

  const TorrentDownloadState({
    this.torrentId, 
    this.stats, 
    this.metadata, 
    this.isLoading = false, 
    this.isPaused = false, 
    this.errorMessage,
    this.customProgress,
    this.customDownloadRate,
    this.customUploadRate,
    this.customSeeds,
    this.customPeers,
    this.customDisplayName,
    this.customTotalBytes,
    this.customFileCount,
    this.customState,
  });

  TorrentDownloadState copyWith({
    int? torrentId,
    TorrentStats? stats,
    TorrentMetadata? metadata,
    bool? isLoading,
    bool? isPaused,
    String? errorMessage,
    bool clearError = false,
    double? customProgress,
    int? customDownloadRate,
    int? customUploadRate,
    int? customSeeds,
    int? customPeers,
    String? customDisplayName,
    int? customTotalBytes,
    int? customFileCount,
    String? customState,
  }) {
    return TorrentDownloadState(
      torrentId: torrentId ?? this.torrentId,
      stats: stats ?? this.stats,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      customProgress: customProgress ?? this.customProgress,
      customDownloadRate: customDownloadRate ?? this.customDownloadRate,
      customUploadRate: customUploadRate ?? this.customUploadRate,
      customSeeds: customSeeds ?? this.customSeeds,
      customPeers: customPeers ?? this.customPeers,
      customDisplayName: customDisplayName ?? this.customDisplayName,
      customTotalBytes: customTotalBytes ?? this.customTotalBytes,
      customFileCount: customFileCount ?? this.customFileCount,
      customState: customState ?? this.customState,
    );
  }

  // Custom copyWith methods for foreground service updates
  TorrentDownloadState copyWithCustomProgress({
    required double progress,
    required int downloadRate,
    required int uploadRate,
    required int seeds,
    required int peers,
    String? state,
  }) {
    return copyWith(
      customProgress: progress,
      customDownloadRate: downloadRate,
      customUploadRate: uploadRate,
      customSeeds: seeds,
      customPeers: peers,
      customState: state,
    );
  }

  TorrentDownloadState copyWithCustomMetadata({
    required String displayName,
    required int totalBytes,
    required int fileCount,
  }) {
    return copyWith(
      customDisplayName: displayName,
      customTotalBytes: totalBytes,
      customFileCount: fileCount,
    );
  }

  double get progressFraction => (customProgress ?? stats?.progress ?? 0) / 100.0;
  int get downloadRate => customDownloadRate ?? stats?.downloadRate ?? 0;
  bool get isCompleted => (customProgress ?? stats?.progress ?? 0) >= 100;
  int get uploadRate => customUploadRate ?? stats?.uploadRate ?? 0;
  bool get isDownloading => torrentId != null && (customProgress ?? stats?.progress ?? 0) < 100;

  // Enhanced state information
  String get displayName => customDisplayName ?? metadata?.name ?? 'Unknown';
  String get formattedSize {
    final totalBytes = customTotalBytes ?? metadata?.totalBytes;
    return totalBytes != null ? _formatBytes(totalBytes) : 'Unknown';
  }
  TorrentState get currentState {
    // Use custom state from foreground service if available
    if (customState != null) {
      return _parseTorrentState(customState!);
    }
    // Fall back to stats state
    return stats?.state ?? TorrentState.starting;
  }
  
  // Additional getters for custom stats
  int get seeds => customSeeds ?? 0;
  int get peers => customPeers ?? 0;
  int get fileCount => customFileCount ?? 0;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024;
    int index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(1)} ${units[index]}';
  }

  static TorrentState _parseTorrentState(String stateName) {
    switch (stateName.toLowerCase()) {
      case 'starting':
        return TorrentState.starting;
      case 'downloadingmetadata':
        return TorrentState.downloadingMetadata;
      case 'downloading':
        return TorrentState.downloading;
      case 'seeding':
        return TorrentState.seeding;
      case 'paused':
        return TorrentState.paused;
      case 'error':
        return TorrentState.error;
      case 'stopped':
        return TorrentState.stopped;
      default:
        return TorrentState.starting;
    }
  }
}

// The manager provider that tracks *all* torrents in a single map.
@Riverpod(keepAlive: true)
class TorrentManager extends _$TorrentManager {
  final Map<int, StreamSubscription<TorrentStats>> _statsSubs = {};
  StreamSubscription<TorrentMetadata>? _metadataSub;

  @override
  TorrentManagerState build() {
    ref.onDispose(() {
      // Clean up all subscriptions
      for (final sub in _statsSubs.values) {
        sub.cancel();
      }
      _metadataSub?.cancel();
    });

    // Listen to metadata updates for all torrents
    _metadataSub = SimpleTorrent.metadataStream.listen((metadata) {
      _handleMetadataUpdate(metadata);
    });

    return const TorrentManagerState();
  }

  // Handle metadata updates
  void _handleMetadataUpdate(TorrentMetadata metadata) {
    // Find the show that corresponds to this torrent ID
    for (final entry in state.torrents.entries) {
      final showId = entry.key;
      final torrentState = entry.value;

      if (torrentState.torrentId == metadata.id) {
        _update(showId, torrentState.copyWith(metadata: metadata));
        break;
      }
    }
  }

  // Start a download for showId with enhanced error handling
  Future<void> startDownload(String showId, String magnetLink, String path) async {
    final current = state.torrents[showId] ?? const TorrentDownloadState();
    if (current.isLoading || current.torrentId != null) return;

    _update(showId, current.copyWith(isLoading: true, clearError: true));

    try {
      // Use SimpleTorrentHelpers for enhanced functionality
      final (id, statsStream) = await SimpleTorrentHelpers.startAndWatch(
        magnet: magnetLink,
        path: path,
        displayName: 'Anime Episode', // Could be customized per show
      );

      _listenToTorrent(id, showId, statsStream);
      _update(showId, current.copyWith(torrentId: id, isLoading: false));

      debugPrint('🎬 Started torrent for $showId with ID: $id');
    } catch (e) {
      debugPrint('❌ Failed to start torrent for $showId: $e');
      _update(showId, current.copyWith(errorMessage: e.toString(), isLoading: false));
    }
  }

  // Enhanced pause functionality with state tracking
  Future<void> pauseDownload(String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != null && !(current?.isPaused ?? true)) {
      try {
        await SimpleTorrent.pause(current!.torrentId!);
        _update(showId, current.copyWith(isPaused: true));
        debugPrint('⏸️ Paused torrent for $showId');
      } catch (e) {
        debugPrint('❌ Failed to pause torrent for $showId: $e');
        _update(showId, current!.copyWith(errorMessage: e.toString()));
      }
    }
  }

  // Enhanced resume functionality with state tracking
  Future<void> resumeDownload(String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != null && (current?.isPaused ?? false)) {
      try {
        await SimpleTorrent.resume(current!.torrentId!);
        _update(showId, current.copyWith(isPaused: false));
        debugPrint('▶️ Resumed torrent for $showId');
      } catch (e) {
        debugPrint('❌ Failed to resume torrent for $showId: $e');
        _update(showId, current!.copyWith(errorMessage: e.toString()));
      }
    }
  }

  // Enhanced torrent listening with dedicated stream
  void _listenToTorrent(int torrentId, String showId, Stream<TorrentStats> statsStream) {
    _statsSubs[torrentId]?.cancel();

    final sub = statsStream.listen(
      (stats) {
        final current = state.torrents[showId] ?? const TorrentDownloadState();
        _update(showId, current.copyWith(stats: stats));

        // Auto-cleanup completed torrents
        if (stats.progress >= 100) {
          debugPrint('✅ Torrent completed for $showId');
          _statsSubs[torrentId]?.cancel();
          _statsSubs.remove(torrentId);
        }
      },
      onError: (error) {
        debugPrint('❌ Stats stream error for $showId: $error');
        final current = state.torrents[showId] ?? const TorrentDownloadState();
        _update(showId, current.copyWith(errorMessage: error.toString()));
      },
    );

    _statsSubs[torrentId] = sub;
  }

  // Enhanced stop functionality with proper cleanup
  Future<void> stopDownload(String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != null) {
      try {
        await SimpleTorrent.cancel(current!.torrentId!);
        _statsSubs[current.torrentId!]?.cancel();
        _statsSubs.remove(current.torrentId!);
        _update(showId, const TorrentDownloadState());
        debugPrint('🛑 Stopped and removed torrent for $showId');
      } catch (e) {
        debugPrint('❌ Failed to stop torrent for $showId: $e');
        _update(showId, current!.copyWith(errorMessage: e.toString()));
      }
    }
  }

  // Bulk operations using SimpleTorrentHelpers
  Future<void> pauseAllDownloads() async {
    try {
      await SimpleTorrentHelpers.pauseAll();
      // Update all active torrents to paused state
      final newTorrents = <String, TorrentDownloadState>{};
      for (final entry in state.torrents.entries) {
        if (entry.value.torrentId != null && !entry.value.isCompleted) {
          newTorrents[entry.key] = entry.value.copyWith(isPaused: true);
        } else {
          newTorrents[entry.key] = entry.value;
        }
      }
      state = state.copyWith(torrents: newTorrents);
      debugPrint('⏸️ Paused all active downloads');
    } catch (e) {
      debugPrint('❌ Failed to pause all downloads: $e');
    }
  }

  Future<void> resumeAllDownloads() async {
    try {
      await SimpleTorrentHelpers.resumeAll();
      // Update all paused torrents to resumed state
      final newTorrents = <String, TorrentDownloadState>{};
      for (final entry in state.torrents.entries) {
        if (entry.value.isPaused) {
          newTorrents[entry.key] = entry.value.copyWith(isPaused: false);
        } else {
          newTorrents[entry.key] = entry.value;
        }
      }
      state = state.copyWith(torrents: newTorrents);
      debugPrint('▶️ Resumed all paused downloads');
    } catch (e) {
      debugPrint('❌ Failed to resume all downloads: $e');
    }
  }

  void _update(String showId, TorrentDownloadState newState) {
    final newMap = Map<String, TorrentDownloadState>.from(state.torrents);
    newMap[showId] = newState;
    state = state.copyWith(torrents: newMap);
  }
}

// A family provider that returns the TorrentDownloadState for a specific showId.
@riverpod
TorrentDownloadState torrentForShow(Ref ref, String showId) {
  final manager = ref.watch(torrentManagerProvider);
  return manager.torrents[showId] ?? const TorrentDownloadState();
}
