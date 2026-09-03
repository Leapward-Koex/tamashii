import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/config/torrent_config.dart';
import 'package:tamashii/config/torrent_download_config.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/services/torrent_runtime.dart';

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

  const TorrentDownloadState({
    this.torrentId,
    this.stats,
    this.metadata,
    this.isLoading = false,
    this.isPaused = false,
    this.errorMessage,
  });

  TorrentDownloadState copyWith({
    int? torrentId,
    TorrentStats? stats,
    TorrentMetadata? metadata,
    bool? isLoading,
    bool? isPaused,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TorrentDownloadState(
      torrentId: torrentId ?? this.torrentId,
      stats: stats ?? this.stats,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  // Custom copyWith methods for foreground service updates (removed - using proper objects now)

  double get progressFraction => stats?.progress ?? 0;
  int get downloadRate => stats?.downloadRate ?? 0;
  bool get isCompleted => (stats?.progress ?? 0) >= 1.0;
  int get uploadRate => stats?.uploadRate ?? 0;
  bool get isDownloading =>
      torrentId != null && !isPaused && (stats?.progress ?? 0) < 1.0;

  // Enhanced state information
  String get displayName => metadata?.name ?? 'Unknown';
  String get formattedSize {
    final totalBytes = metadata?.totalBytes;
    return totalBytes != null ? _formatBytes(totalBytes) : 'Unknown';
  }

  TorrentState get currentState => stats?.state ?? TorrentState.starting;

  // Additional getters for stats
  int get seeds => stats?.seeds ?? 0;
  int get peers => stats?.peers ?? 0;
  int get fileCount => metadata?.fileCount ?? 0;

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
}

// The manager provider that tracks *all* torrents in a single map.
@Riverpod(keepAlive: true)
class TorrentManager extends _$TorrentManager {
  final Map<int, StreamSubscription<TorrentStats>> _statsSubs = {};
  final Map<int, Future<void>> _finaliseOperations = {};
  final Set<int> _finalisedTorrentIds = {};
  final Set<int> _stoppingTorrentIds = {};
  StreamSubscription<TorrentMetadata>? _metadataSub;
  late TorrentRuntime _runtime;

  @override
  TorrentManagerState build() {
    _runtime = ref.read(torrentRuntimeProvider);

    ref.onDispose(() {
      // Clean up all subscriptions
      for (final sub in _statsSubs.values) {
        sub.cancel();
      }
      _metadataSub?.cancel();
    });

    // Listen to metadata updates for all torrents
    _metadataSub = _runtime.metadataStream.listen((metadata) {
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
  Future<void> startDownload(
    String showId,
    String magnetLink,
    String path,
  ) async {
    final current = state.torrents[showId] ?? const TorrentDownloadState();
    if (current.isLoading || current.torrentId != null) return;

    _update(showId, current.copyWith(isLoading: true, clearError: true));

    try {
      // Check storage permissions before starting download
      debugPrint('🔐 Checking storage permissions for $showId');
      final hasPermissions = await PermissionService.hasStoragePermissions();

      if (!hasPermissions) {
        debugPrint('🔒 Storage permissions not granted, requesting...');
        final granted = await PermissionService.requestStoragePermissions();

        if (!granted) {
          throw Exception(
            'Storage permissions are required to download torrents. Please grant storage access in app settings.',
          );
        }
        debugPrint('✅ Storage permissions granted');
      }

      final directoryError = await PermissionService.validateDownloadDirectory(
        path,
      );
      if (directoryError != null) {
        throw FileSystemException(directoryError, path);
      }

      // Use SimpleTorrentHelpers for enhanced functionality
      final (id, statsStream) = await _runtime.startAndWatch(
        magnet: resolveTorrentMagnetUri(magnetLink),
        path: path,
        displayName: 'Anime Episode', // Could be customized per show
      );

      // Native IDs are normally monotonic, but do not let an implementation
      // that recycles IDs inherit completion state from an older torrent.
      _finalisedTorrentIds.remove(id);
      _listenToTorrent(id, showId, statsStream, path);
      _update(showId, current.copyWith(torrentId: id, isLoading: false));

      debugPrint('🎬 Started torrent for $showId with ID: $id');
    } catch (e) {
      final message = describeTorrentError(e);
      debugPrint('❌ Failed to start torrent for $showId: $message');
      _update(
        showId,
        current.copyWith(errorMessage: message, isLoading: false),
      );
    }
  }

  // Enhanced pause functionality with state tracking
  Future<void> pauseDownload(String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != null && !(current?.isPaused ?? true)) {
      try {
        await _runtime.pause(current!.torrentId!);
        _update(showId, current.copyWith(isPaused: true));
        debugPrint('⏸️ Paused torrent for $showId');
      } catch (e) {
        debugPrint('❌ Failed to pause torrent for $showId: $e');
        _update(
          showId,
          current!.copyWith(errorMessage: describeTorrentError(e)),
        );
      }
    }
  }

  // Enhanced resume functionality with state tracking
  Future<void> resumeDownload(String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != null && (current?.isPaused ?? false)) {
      try {
        await _runtime.resume(current!.torrentId!);
        _update(showId, current.copyWith(isPaused: false));
        debugPrint('▶️ Resumed torrent for $showId');
      } catch (e) {
        debugPrint('❌ Failed to resume torrent for $showId: $e');
        _update(
          showId,
          current!.copyWith(errorMessage: describeTorrentError(e)),
        );
      }
    }
  }

  // Enhanced torrent listening with dedicated stream
  void _listenToTorrent(
    int torrentId,
    String showId,
    Stream<TorrentStats> statsStream,
    String downloadDir,
  ) {
    _statsSubs[torrentId]?.cancel();

    final sub = statsStream.listen(
      (stats) {
        final current = state.torrents[showId] ?? const TorrentDownloadState();
        _update(showId, current.copyWith(stats: stats));

        // Finalise removes the completed torrent from the native active set
        // while retaining its downloaded files. The operation is single-flight
        // because a seeding torrent can emit several 100% stats events.
        if (stats.progress >= 1.0) {
          unawaited(_finaliseCompletedTorrent(torrentId, showId));
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

  Future<void> _finaliseCompletedTorrent(int torrentId, String showId) {
    if (_finalisedTorrentIds.contains(torrentId) ||
        _stoppingTorrentIds.contains(torrentId)) {
      return Future<void>.value();
    }

    final existing = _finaliseOperations[torrentId];
    if (existing != null) {
      return existing;
    }

    late final Future<void> operation;
    operation = _performFinalise(torrentId, showId).whenComplete(() {
      if (identical(_finaliseOperations[torrentId], operation)) {
        _finaliseOperations.remove(torrentId);
      }
    });
    _finaliseOperations[torrentId] = operation;
    return operation;
  }

  Future<void> _performFinalise(int torrentId, String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != torrentId || !current!.isCompleted) {
      return;
    }

    try {
      await _runtime.finalise(torrentId);
    } catch (error) {
      final latest = state.torrents[showId];
      if (latest?.torrentId == torrentId) {
        _update(
          showId,
          latest!.copyWith(
            errorMessage:
                'Failed to finalise download: ${describeTorrentError(error)}',
          ),
        );
      }
      debugPrint('❌ Failed to finalise torrent for $showId: $error');
      return;
    }

    _finalisedTorrentIds.add(torrentId);
    await _statsSubs[torrentId]?.cancel();
    _statsSubs.remove(torrentId);

    try {
      // Record completion only after native finalisation has succeeded. This
      // ensures a persisted "downloaded" marker never hides an active native
      // torrent that failed to leave the session.
      await ref.read(downloadedTorrentsProvider.notifier).addDownloaded(showId);

      final latest = state.torrents[showId];
      if (latest?.torrentId == torrentId) {
        _update(showId, latest!.copyWith(clearError: true));
      }
      debugPrint('✅ Finalised completed torrent for $showId');
    } catch (error) {
      final latest = state.torrents[showId];
      if (latest?.torrentId == torrentId) {
        _update(
          showId,
          latest!.copyWith(
            errorMessage:
                'Download completed, but Tamashii could not save its '
                'completion status: $error',
          ),
        );
      }
      debugPrint('❌ Failed to persist completion for $showId: $error');
    }
  }

  // Enhanced stop functionality with proper cleanup
  Future<void> stopDownload(String showId) async {
    final current = state.torrents[showId];
    if (current?.torrentId != null) {
      final torrentId = current!.torrentId!;
      if (!_stoppingTorrentIds.add(torrentId)) {
        return;
      }

      try {
        // If completion won the race, let finalise finish and retain the
        // payload. Otherwise an explicit stop still cancels the active torrent.
        await _finaliseOperations[torrentId];
        if (!_finalisedTorrentIds.contains(torrentId)) {
          await _runtime.cancel(torrentId);
        }
        await _statsSubs[torrentId]?.cancel();
        _statsSubs.remove(torrentId);
        _finalisedTorrentIds.remove(torrentId);
        _update(showId, const TorrentDownloadState());
        debugPrint('🛑 Stopped and removed torrent for $showId');
      } catch (e) {
        debugPrint('❌ Failed to stop torrent for $showId: $e');
        _update(
          showId,
          current.copyWith(errorMessage: describeTorrentError(e)),
        );
      } finally {
        _stoppingTorrentIds.remove(torrentId);
      }
    }
  }

  // Bulk operations using SimpleTorrentHelpers
  Future<void> pauseAllDownloads() async {
    try {
      await _runtime.pauseAll();
      // Update all active torrents to paused state
      final newTorrents = <String, TorrentDownloadState>{};
      for (final entry in state.torrents.entries) {
        if (entry.value.torrentId != null && !entry.value.isCompleted) {
          newTorrents[entry.key] = entry.value.copyWith(
            isPaused: true,
            clearError: true,
          );
        } else {
          newTorrents[entry.key] = entry.value;
        }
      }
      state = state.copyWith(torrents: newTorrents);
      debugPrint('⏸️ Paused all active downloads');
    } catch (e) {
      debugPrint('❌ Failed to pause all downloads: $e');
      rethrow;
    }
  }

  Future<void> resumeAllDownloads() async {
    try {
      await _runtime.resumeAll();
      // Update all paused torrents to resumed state
      final newTorrents = <String, TorrentDownloadState>{};
      for (final entry in state.torrents.entries) {
        if (entry.value.isPaused) {
          newTorrents[entry.key] = entry.value.copyWith(
            isPaused: false,
            clearError: true,
          );
        } else {
          newTorrents[entry.key] = entry.value;
        }
      }
      state = state.copyWith(torrents: newTorrents);
      debugPrint('▶️ Resumed all paused downloads');
    } catch (e) {
      debugPrint('❌ Failed to resume all downloads: $e');
      rethrow;
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
