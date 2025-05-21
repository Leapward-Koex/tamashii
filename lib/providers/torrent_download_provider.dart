import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:simple_torrent/simple_torrent.dart';

part 'torrent_download_provider.g.dart';

class TorrentDownloadState {
  final int? torrentId;
  final TorrentStats? stats;
  final String? errorMessage;
  final bool isLoading;

  const TorrentDownloadState({this.torrentId, this.stats, this.errorMessage, this.isLoading = false});

  TorrentDownloadState copyWith({int? torrentId, TorrentStats? stats, String? errorMessage, bool? isLoading, bool clearError = false}) {
    return TorrentDownloadState(
      torrentId: torrentId ?? this.torrentId,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  double get progressFraction => (stats?.progress ?? 0) / 100.0;
  int get downloadRate => stats?.downloadRate ?? 0;
  int get uploadRate => stats?.uploadRate ?? 0;
  bool get isDownloading => torrentId != null && (stats?.progress ?? 0) < 100;
  bool get isCompleted => stats?.progress == 100;
}

@Riverpod(keepAlive: true)
class TorrentDownload extends _$TorrentDownload {
  StreamSubscription<TorrentStats>? _statsSubscription;

  @override
  TorrentDownloadState build(String showId) {
    // showId is the family argument, e.g., show.show
    // The initial state can be empty.
    // If you had persistence for torrent tasks, you might load initial state here.
    if (showId == "Shiunji-ke no Kodomotachi") {
      var a = 1;
    }
    ref.onDispose(() {
      _statsSubscription?.cancel();
      final currentTorrentId = state.torrentId;
      if (currentTorrentId != null && !state.isCompleted) {
        SimpleTorrent.cancel(currentTorrentId);
      }
    });
    return const TorrentDownloadState();
  }

  Future<void> startDownloadTask(String magnetLink, String downloadPath) async {
    if (state.isLoading || state.torrentId != null) return; // Already processing or started

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final id = await SimpleTorrent.start(magnet: magnetLink, path: downloadPath);
      state = state.copyWith(torrentId: id, isLoading: false);
      _listenToStats(id);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  void _listenToStats(int torrentId) {
    _statsSubscription?.cancel(); // Cancel previous subscription if any
    _statsSubscription = SimpleTorrent.statsStream.listen((stats) {
      if (stats.id == torrentId) {
        state = state.copyWith(stats: stats);
        if (stats.progress == 100) {
          _statsSubscription?.cancel();
        }
      }
    });
  }

  Future<void> stopDownloadTask() async {
    if (state.torrentId != null) {
      await SimpleTorrent.cancel(state.torrentId!);
      _statsSubscription?.cancel();
      state = const TorrentDownloadState(); // Reset state
    }
  }

  Future<void> pauseDownloadTask() async {
    if (state.torrentId != null) {
      await SimpleTorrent.pause(state.torrentId!);
    }
  }

  Future<void> resumeDownloadTask() async {
    if (state.torrentId != null) {
      await SimpleTorrent.resume(state.torrentId!);
    }
  }
}
