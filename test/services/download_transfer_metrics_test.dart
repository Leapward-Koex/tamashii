import 'package:flutter_test/flutter_test.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/services/download_transfer_metrics.dart';

void main() {
  group('DownloadTransferMetrics', () {
    test(
      'calculates byte-weighted progress, summed rates, and longest ETA',
      () {
        final report = DownloadTransferMetrics.build([
          DownloadTransferSnapshot(
            key: 'episode-one',
            stats: _stats(progress: 0.5, downloadRate: 50, uploadRate: 10),
            metadata: _metadata(name: 'Episode One', totalBytes: 1000),
          ),
          DownloadTransferSnapshot(
            key: 'episode-two',
            stats: _stats(progress: 0.25, downloadRate: 100, uploadRate: 20),
            metadata: _metadata(name: 'Episode Two', totalBytes: 9000),
          ),
        ]);

        expect(report.items, hasLength(2));
        expect(report.items.first.displayName, 'Episode One');
        expect(report.items.first.status, DownloadTransferStatus.downloading);
        expect(report.items.first.receivedBytes, 500);
        expect(report.items.first.remainingBytes, 500);
        expect(report.items.first.eta, const Duration(seconds: 10));
        expect(report.items.last.eta, const Duration(seconds: 68));

        final summary = report.summary;
        expect(summary.trackedCount, 2);
        expect(summary.liveCount, 2);
        expect(summary.completedCount, 0);
        expect(summary.activeCount, 2);
        expect(summary.downloadingCount, 2);
        expect(summary.progressIsEstimated, isFalse);
        expect(summary.totalBytes, 10000);
        expect(summary.receivedBytes, 2750);
        expect(summary.remainingBytes, 7250);
        expect(summary.progressFraction, 0.275);
        expect(summary.downloadRate, 150);
        expect(summary.uploadRate, 30);
        expect(summary.eta, const Duration(seconds: 68));
      },
    );

    test(
      'uses an explicitly estimated progress fallback for unknown sizes',
      () {
        final report = DownloadTransferMetrics.build([
          DownloadTransferSnapshot(
            key: 'metadata-pending',
            stats: _stats(progress: 0.25, downloadRate: 100),
          ),
          DownloadTransferSnapshot(
            key: 'known-size',
            stats: _stats(progress: 0.5, downloadRate: 100),
            metadata: _metadata(name: 'Known', totalBytes: 100),
          ),
        ]);

        final summary = report.summary;
        expect(summary.progressIsEstimated, isTrue);
        expect(summary.progressFraction, 0.375);
        expect(summary.totalBytes, isNull);
        expect(summary.receivedBytes, isNull);
        expect(summary.remainingBytes, isNull);
        expect(summary.eta, isNull);
        expect(report.items.first.eta, isNull);
        expect(report.items.last.eta, const Duration(seconds: 1));
      },
    );

    test(
      'classifies paused, policy-blocked, failed, and preparing transfers',
      () {
        final report = DownloadTransferMetrics.build([
          DownloadTransferSnapshot(
            key: 'downloading',
            stats: _stats(progress: 0.5, downloadRate: 100, uploadRate: 10),
            metadata: _metadata(name: 'Downloading', totalBytes: 1000),
          ),
          DownloadTransferSnapshot(
            key: 'paused',
            isPaused: true,
            stats: _stats(progress: 0.5, downloadRate: 500, uploadRate: 50),
            metadata: _metadata(name: 'Paused', totalBytes: 1000),
          ),
          DownloadTransferSnapshot(
            key: 'network',
            isPaused: true,
            isPolicyBlocked: true,
            stats: _stats(progress: 0.5, downloadRate: 500, uploadRate: 50),
            metadata: _metadata(name: 'Network', totalBytes: 1000),
          ),
          DownloadTransferSnapshot(
            key: 'failed',
            errorMessage: 'Tracker rejected connection',
            stats: _stats(progress: 0.5, downloadRate: 500, uploadRate: 50),
            metadata: _metadata(name: 'Failed', totalBytes: 1000),
          ),
          const DownloadTransferSnapshot(key: 'preparing', isPreparing: true),
        ]);

        expect(report.items.map((item) => item.status), [
          DownloadTransferStatus.downloading,
          DownloadTransferStatus.paused,
          DownloadTransferStatus.waitingForNetwork,
          DownloadTransferStatus.failed,
          DownloadTransferStatus.preparing,
        ]);
        expect(report.items[1].eta, isNull);
        expect(report.items[2].eta, isNull);
        expect(report.items[3].eta, isNull);
        expect(report.items[4].eta, isNull);
        expect(report.summary.activeCount, 2);
        expect(report.summary.downloadingCount, 1);
        expect(report.summary.preparingCount, 1);
        expect(report.summary.pausedCount, 1);
        expect(report.summary.waitingForNetworkCount, 1);
        expect(report.summary.failedCount, 1);
        expect(report.summary.downloadRate, 100);
        expect(report.summary.uploadRate, 10);
        expect(report.summary.eta, isNull);
      },
    );

    test('filters completed transfers while retaining their summary count', () {
      final report = DownloadTransferMetrics.build([
        DownloadTransferSnapshot(
          key: 'completed-by-stats',
          stats: _stats(progress: 1, downloadRate: 0),
          metadata: _metadata(name: 'Done', totalBytes: 1000),
        ),
        const DownloadTransferSnapshot(
          key: 'completed-explicitly',
          isCompleted: true,
        ),
        DownloadTransferSnapshot(
          key: 'still-live',
          stats: _stats(progress: 0.5, downloadRate: 0),
          metadata: _metadata(name: 'Still live', totalBytes: 1000),
        ),
      ]);

      expect(report.items.map((item) => item.key), ['still-live']);
      expect(report.summary.trackedCount, 3);
      expect(report.summary.liveCount, 1);
      expect(report.summary.completedCount, 2);
      expect(report.summary.eta, isNull);
    });

    test('keeps a completed transfer visible when finalisation fails', () {
      final report = DownloadTransferMetrics.build([
        DownloadTransferSnapshot(
          key: 'needs-finalisation',
          stats: _stats(progress: 1, downloadRate: 0),
          metadata: _metadata(name: 'Needs finalisation', totalBytes: 1000),
          errorMessage: 'Failed to finalise download.',
        ),
      ]);

      expect(report.items, hasLength(1));
      expect(report.items.single.status, DownloadTransferStatus.failed);
      expect(report.summary.completedCount, 0);
      expect(report.summary.failedCount, 1);
    });

    test('does not invent an ETA when a transfer has no positive rate', () {
      final report = DownloadTransferMetrics.build([
        DownloadTransferSnapshot(
          key: 'stalled',
          stats: _stats(progress: 0.5, downloadRate: 0),
          metadata: _metadata(name: 'Stalled', totalBytes: 1000),
        ),
      ]);

      expect(report.items.single.status, DownloadTransferStatus.downloading);
      expect(report.items.single.eta, isNull);
      expect(report.summary.eta, isNull);
      expect(report.summary.downloadRate, 0);
    });
  });

  group('DownloadTransferFormatters', () {
    test('formats bytes, rates, ETAs, and unknown values consistently', () {
      expect(DownloadTransferFormatters.formatBytes(512), '512 B');
      expect(DownloadTransferFormatters.formatBytes(1536), '1.5 KB');
      expect(DownloadTransferFormatters.formatRate(2048), '2.0 KB/s');
      expect(
        DownloadTransferFormatters.formatEta(const Duration(seconds: 45)),
        '< 1m',
      );
      expect(
        DownloadTransferFormatters.formatEta(const Duration(minutes: 65)),
        '1h 5m',
      );
      expect(
        DownloadTransferFormatters.formatEta(const Duration(hours: 26)),
        '1d 2h',
      );
      expect(
        DownloadTransferFormatters.formatEta(null, unknown: 'Calculating…'),
        'Calculating…',
      );
      expect(
        DownloadTransferFormatters.formatRate(null, unknown: 'Calculating…'),
        'Calculating…',
      );
    });
  });
}

TorrentStats _stats({
  required double progress,
  required int downloadRate,
  int uploadRate = 0,
}) {
  return TorrentStats(
    id: 1,
    downloadRate: downloadRate,
    uploadRate: uploadRate,
    pieces: (progress * 100).round(),
    piecesTotal: 100,
    progress: progress,
    seeds: 4,
    peers: 2,
    state: TorrentState.downloading,
  );
}

TorrentMetadata _metadata({required String name, required int totalBytes}) {
  return TorrentMetadata(
    id: 1,
    name: name,
    totalBytes: totalBytes,
    pieceSize: 1024,
    pieceCount: 1,
    fileCount: 1,
    creationDate: 0,
    isPrivate: false,
  );
}
