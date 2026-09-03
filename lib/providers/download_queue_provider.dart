import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/download_transfer_metrics.dart';

part 'download_queue_provider.g.dart';

/// Exposes the same normalized transfer report used by the foreground
/// notification to the downloads UI.
///
/// This intentionally only adapts UI manager state. Classification, totals,
/// progress, rate, ETA, and formatting rules all live in
/// [DownloadTransferMetrics], so the page cannot drift from the notification.
@Riverpod(keepAlive: true)
DownloadTransferReport downloadQueue(Ref ref) {
  final TorrentManagerState managerState;
  final bool isPolicyBlocked;
  if (Platform.isAndroid) {
    managerState = ref.watch(foregroundTorrentManagerProvider);
    isPolicyBlocked = ref
        .watch(foregroundTransferPolicyStatusProvider)
        .suspended;
  } else {
    managerState = ref.watch(torrentManagerProvider);
    isPolicyBlocked = false;
  }

  return DownloadTransferMetrics.build(
    managerState.torrents.entries
        .where((entry) => _hasLiveDownloadState(entry.value))
        .map((entry) {
          final download = entry.value;
          return DownloadTransferSnapshot(
            key: entry.key,
            stats: download.stats,
            metadata: download.metadata,
            isCompleted: download.isCompleted,
            isPaused: download.isPaused,
            isPreparing:
                download.isLoading ||
                (download.torrentId != null && download.stats == null),
            isPolicyBlocked: isPolicyBlocked,
            errorMessage: download.errorMessage,
          );
        }),
  );
}

bool _hasLiveDownloadState(TorrentDownloadState download) {
  return download.torrentId != null ||
      download.isLoading ||
      download.stats != null ||
      download.metadata != null ||
      (download.errorMessage?.trim().isNotEmpty ?? false);
}

/// A narrow, replaceable command boundary for the Downloads screen.
///
/// Keeping controls separate from the report provider makes the page easy to
/// exercise without bringing up a native foreground service in widget tests.
abstract interface class DownloadQueueControls {
  Future<void> pauseAllDownloads();

  Future<void> resumeAllDownloads();
}

@riverpod
DownloadQueueControls downloadQueueControls(Ref ref) {
  return _ForegroundDownloadQueueControls(ref);
}

final class _ForegroundDownloadQueueControls implements DownloadQueueControls {
  const _ForegroundDownloadQueueControls(this._ref);

  final Ref _ref;

  @override
  Future<void> pauseAllDownloads() {
    return _ref
        .read(foregroundTorrentManagerProvider.notifier)
        .pauseAllDownloads();
  }

  @override
  Future<void> resumeAllDownloads() {
    return _ref
        .read(foregroundTorrentManagerProvider.notifier)
        .resumeAllDownloads();
  }
}
