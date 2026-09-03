import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:simple_torrent/simple_torrent.dart';

part 'download_transfer_metrics.freezed.dart';

/// The user-facing lifecycle of an incomplete torrent transfer.
///
/// Completed transfers are deliberately omitted from [DownloadTransferReport]
/// items. They are retained only in the report summary counts so consumers
/// such as the foreground notification can distinguish an idle service from a
/// service that has just completed all of its work.
enum DownloadTransferStatus {
  preparing,
  downloading,
  paused,
  waitingForNetwork,
  failed,
}

/// A platform-neutral description of one torrent's current state.
///
/// Platform and Riverpod adapters should convert their local state into these
/// snapshots before asking [DownloadTransferMetrics] to derive display data.
/// Keeping native transport details out of this model lets the Android
/// foreground task and Flutter UI share exactly the same calculations.
@freezed
abstract class DownloadTransferSnapshot with _$DownloadTransferSnapshot {
  const factory DownloadTransferSnapshot({
    required String key,
    TorrentStats? stats,
    TorrentMetadata? metadata,
    @Default(false) bool isCompleted,
    @Default(false) bool isPaused,
    @Default(false) bool isPreparing,
    @Default(false) bool isPolicyBlocked,
    String? errorMessage,
  }) = _DownloadTransferSnapshot;
}

/// Calculated display metrics for one incomplete transfer.
@freezed
abstract class DownloadTransferItem with _$DownloadTransferItem {
  const factory DownloadTransferItem({
    required String key,
    required String displayName,
    required DownloadTransferStatus status,
    required double progressFraction,
    int? totalBytes,
    int? receivedBytes,
    int? remainingBytes,
    int? downloadRate,
    int? uploadRate,
    Duration? eta,
    int? seeds,
    int? peers,
    String? errorMessage,
  }) = _DownloadTransferItem;
}

/// Aggregate metrics for all snapshots used to make a report.
@freezed
abstract class DownloadTransferSummary with _$DownloadTransferSummary {
  const factory DownloadTransferSummary({
    required int trackedCount,
    required int liveCount,
    required int completedCount,
    required int activeCount,
    required int downloadingCount,
    required int preparingCount,
    required int pausedCount,
    required int waitingForNetworkCount,
    required int failedCount,
    required double progressFraction,
    required bool progressIsEstimated,
    int? totalBytes,
    int? receivedBytes,
    int? remainingBytes,
    required int downloadRate,
    required int uploadRate,
    Duration? eta,
  }) = _DownloadTransferSummary;
}

/// A reusable transfer view shared by the notification and Downloads UI.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class DownloadTransferReport with _$DownloadTransferReport {
  const factory DownloadTransferReport({
    required List<DownloadTransferItem> items,
    required DownloadTransferSummary summary,
  }) = _DownloadTransferReport;
}
