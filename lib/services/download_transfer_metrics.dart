import 'dart:math' as math;

import 'package:tamashii/models/download_transfer_metrics.dart';

/// Produces display-ready torrent transfer metrics from normalized snapshots.
///
/// This class intentionally has no Flutter or Riverpod dependency. It is used
/// by both the Android foreground isolate and the app UI so their speed,
/// progress, ETA, and lifecycle displays cannot drift apart.
class DownloadTransferMetrics {
  const DownloadTransferMetrics._();

  /// Builds a report in the order supplied by [snapshots].
  ///
  /// A transfer whose explicit completion flag is true, or whose torrent stats
  /// have reached 100%, is counted in [DownloadTransferSummary.completedCount]
  /// but excluded from [DownloadTransferReport.items] unless it also has an
  /// error. A finalisation failure after the bytes arrive still needs user
  /// attention, so it remains visible as failed.
  static DownloadTransferReport build(
    Iterable<DownloadTransferSnapshot> snapshots,
  ) {
    final snapshotList = List<DownloadTransferSnapshot>.unmodifiable(snapshots);
    final items = <DownloadTransferItem>[];
    var completedCount = 0;

    for (final snapshot in snapshotList) {
      if (_isCompleted(snapshot)) {
        completedCount++;
        continue;
      }
      items.add(_buildItem(snapshot));
    }

    return DownloadTransferReport(
      items: List<DownloadTransferItem>.unmodifiable(items),
      summary: _buildSummary(
        trackedCount: snapshotList.length,
        completedCount: completedCount,
        items: items,
      ),
    );
  }

  static DownloadTransferItem _buildItem(DownloadTransferSnapshot snapshot) {
    final stats = snapshot.stats;
    final metadata = snapshot.metadata;
    final totalBytes = _validTotalBytes(metadata?.totalBytes);
    final progressFraction = _normaliseProgress(stats?.progress);
    final receivedBytes = totalBytes == null
        ? null
        : (totalBytes * progressFraction).round().clamp(0, totalBytes);
    final remainingBytes = totalBytes == null
        ? null
        : totalBytes - receivedBytes!;
    final status = _statusFor(snapshot);
    final downloadRate = _normaliseRate(stats?.downloadRate);
    final uploadRate = _normaliseRate(stats?.uploadRate);
    final eta = status == DownloadTransferStatus.downloading
        ? _calculateEta(remainingBytes, downloadRate)
        : null;
    final metadataName = metadata?.name.trim();

    return DownloadTransferItem(
      key: snapshot.key,
      displayName: metadataName == null || metadataName.isEmpty
          ? snapshot.key
          : metadataName,
      status: status,
      progressFraction: progressFraction,
      totalBytes: totalBytes,
      receivedBytes: receivedBytes,
      remainingBytes: remainingBytes,
      downloadRate: downloadRate,
      uploadRate: uploadRate,
      eta: eta,
      seeds: stats?.seeds,
      peers: stats?.peers,
      errorMessage: snapshot.errorMessage,
    );
  }

  static DownloadTransferSummary _buildSummary({
    required int trackedCount,
    required int completedCount,
    required List<DownloadTransferItem> items,
  }) {
    var downloadingCount = 0;
    var preparingCount = 0;
    var pausedCount = 0;
    var waitingForNetworkCount = 0;
    var failedCount = 0;
    var downloadRate = 0;
    var uploadRate = 0;

    for (final item in items) {
      switch (item.status) {
        case DownloadTransferStatus.downloading:
          downloadingCount++;
          downloadRate += item.downloadRate ?? 0;
          uploadRate += item.uploadRate ?? 0;
          break;
        case DownloadTransferStatus.preparing:
          preparingCount++;
          break;
        case DownloadTransferStatus.paused:
          pausedCount++;
          break;
        case DownloadTransferStatus.waitingForNetwork:
          waitingForNetworkCount++;
          break;
        case DownloadTransferStatus.failed:
          failedCount++;
          break;
      }
    }

    final allSizesKnown =
        items.isNotEmpty && items.every((item) => item.totalBytes != null);
    final totalBytes = allSizesKnown
        ? items.fold<int>(0, (sum, item) => sum + item.totalBytes!)
        : null;
    final receivedBytes = allSizesKnown
        ? items.fold<int>(0, (sum, item) => sum + item.receivedBytes!)
        : null;
    final remainingBytes = allSizesKnown
        ? items.fold<int>(0, (sum, item) => sum + item.remainingBytes!)
        : null;
    final progressFraction = allSizesKnown
        ? _safeFraction(receivedBytes!, totalBytes!)
        : _averageProgress(items);
    final activeItems = items
        .where(
          (item) =>
              item.status == DownloadTransferStatus.preparing ||
              item.status == DownloadTransferStatus.downloading,
        )
        .toList(growable: false);

    return DownloadTransferSummary(
      trackedCount: trackedCount,
      liveCount: items.length,
      completedCount: completedCount,
      activeCount: activeItems.length,
      downloadingCount: downloadingCount,
      preparingCount: preparingCount,
      pausedCount: pausedCount,
      waitingForNetworkCount: waitingForNetworkCount,
      failedCount: failedCount,
      progressFraction: progressFraction,
      progressIsEstimated: items.isNotEmpty && !allSizesKnown,
      totalBytes: totalBytes,
      receivedBytes: receivedBytes,
      remainingBytes: remainingBytes,
      downloadRate: downloadRate,
      uploadRate: uploadRate,
      eta: _aggregateEta(activeItems),
    );
  }

  static bool _isCompleted(DownloadTransferSnapshot snapshot) {
    if (_hasError(snapshot.errorMessage)) {
      return false;
    }
    return snapshot.isCompleted ||
        _normaliseProgress(snapshot.stats?.progress) >= 1;
  }

  static DownloadTransferStatus _statusFor(DownloadTransferSnapshot snapshot) {
    if (_hasError(snapshot.errorMessage)) {
      return DownloadTransferStatus.failed;
    }
    // A policy suspension applies to every in-progress torrent. It takes
    // precedence over the manual state so the UI never misrepresents a network
    // restriction as the user's own pause action.
    if (snapshot.isPolicyBlocked) {
      return DownloadTransferStatus.waitingForNetwork;
    }
    if (snapshot.isPaused) {
      return DownloadTransferStatus.paused;
    }
    if (snapshot.isPreparing || snapshot.stats == null) {
      return DownloadTransferStatus.preparing;
    }
    return DownloadTransferStatus.downloading;
  }

  static bool _hasError(String? message) => message?.trim().isNotEmpty ?? false;

  static int? _validTotalBytes(int? value) {
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  static double _normaliseProgress(double? value) {
    if (value == null || !value.isFinite) {
      return 0;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  static int? _normaliseRate(int? value) {
    if (value == null) {
      return null;
    }
    return value < 0 ? 0 : value;
  }

  static Duration? _calculateEta(int? remainingBytes, int? downloadRate) {
    if (remainingBytes == null || downloadRate == null || downloadRate <= 0) {
      return null;
    }
    return Duration(seconds: (remainingBytes / downloadRate).ceil());
  }

  static Duration? _aggregateEta(List<DownloadTransferItem> activeItems) {
    if (activeItems.isEmpty || activeItems.any((item) => item.eta == null)) {
      return null;
    }

    return activeItems
        .map((item) => item.eta!)
        .reduce((longest, eta) => eta.compareTo(longest) > 0 ? eta : longest);
  }

  static double _averageProgress(List<DownloadTransferItem> items) {
    if (items.isEmpty) {
      return 0;
    }
    return items.fold<double>(0, (sum, item) => sum + item.progressFraction) /
        items.length;
  }

  static double _safeFraction(int receivedBytes, int totalBytes) {
    if (totalBytes <= 0) {
      return 0;
    }
    return (receivedBytes / totalBytes).clamp(0.0, 1.0).toDouble();
  }
}

/// Shared presentation formatting for transfer values.
///
/// Consumers can choose the fallback wording appropriate to their context:
/// for example `Calculating…` in a row and `—` in a compact notification.
class DownloadTransferFormatters {
  const DownloadTransferFormatters._();

  static String formatBytes(int? bytes, {String unknown = '—'}) {
    if (bytes == null) {
      return unknown;
    }

    final value = bytes < 0 ? 0 : bytes;
    if (value < 1024) {
      return '$value B';
    }

    const units = <String>['KB', 'MB', 'GB', 'TB'];
    var displayValue = value / 1024;
    var unitIndex = 0;
    while (displayValue >= 1024 && unitIndex < units.length - 1) {
      displayValue /= 1024;
      unitIndex++;
    }
    return '${displayValue.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  static String formatRate(int? bytesPerSecond, {String unknown = '—'}) {
    if (bytesPerSecond == null) {
      return unknown;
    }
    return '${formatBytes(bytesPerSecond)}/s';
  }

  static String formatEta(Duration? eta, {String unknown = '—'}) {
    if (eta == null) {
      return unknown;
    }

    final seconds = math.max(0, eta.inSeconds);
    if (seconds < 60) {
      return '< 1m';
    }

    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours < 24) {
      return remainingMinutes == 0
          ? '${hours}h'
          : '${hours}h ${remainingMinutes}m';
    }

    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return remainingHours == 0 ? '${days}d' : '${days}d ${remainingHours}h';
  }
}
