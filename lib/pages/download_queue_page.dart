import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/services/download_transfer_metrics.dart';
import 'package:tamashii/widgets/transfer_policy_banner.dart';

/// A live view of transfers which are still being prepared, transferred,
/// paused, or need attention.
///
/// Completed downloads intentionally leave this view. This screen is a live
/// monitor rather than a download-history page.
class DownloadQueuePage extends ConsumerStatefulWidget {
  const DownloadQueuePage({this.platform, super.key});

  static const Key emptyStateKey = ValueKey<String>('download-queue-empty');
  static const Key summaryCardKey = ValueKey<String>('download-queue-summary');
  static const Key pauseAllButtonKey = ValueKey<String>(
    'download-queue-pause-all',
  );
  static const Key resumeAllButtonKey = ValueKey<String>(
    'download-queue-resume-all',
  );

  static Key itemKey(String torrentKey) =>
      ValueKey<String>('download-queue-item-$torrentKey');

  final TargetPlatform? platform;

  @override
  ConsumerState<DownloadQueuePage> createState() => _DownloadQueuePageState();
}

class _DownloadQueuePageState extends ConsumerState<DownloadQueuePage> {
  bool _isPausing = false;
  bool _isResuming = false;

  Future<void> _runBulkAction({required bool pause}) async {
    setState(() {
      if (pause) {
        _isPausing = true;
      } else {
        _isResuming = true;
      }
    });

    try {
      final controls = ref.read(downloadQueueControlsProvider);
      if (pause) {
        await controls.pauseAllDownloads();
      } else {
        await controls.resumeAllDownloads();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not ${pause ? 'pause' : 'resume'} downloads: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (pause) {
            _isPausing = false;
          } else {
            _isResuming = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(downloadQueueProvider);
    final effectivePlatform = widget.platform ?? defaultTargetPlatform;
    final transferPolicy = effectivePlatform == TargetPlatform.android
        ? ref.watch(foregroundTransferPolicyStatusProvider)
        : null;
    final summary = report.summary;
    final activeItems = report.items
        .where(
          (item) =>
              item.status == DownloadTransferStatus.preparing ||
              item.status == DownloadTransferStatus.downloading ||
              item.status == DownloadTransferStatus.waitingForNetwork,
        )
        .toList(growable: false);
    final pausedItems = report.items
        .where((item) => item.status == DownloadTransferStatus.paused)
        .toList(growable: false);
    final failedItems = report.items
        .where((item) => item.status == DownloadTransferStatus.failed)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Column(
        children: [
          TransferPolicyBanner(
            snapshot: transferPolicy,
            platform: effectivePlatform,
          ),
          Expanded(
            child: report.items.isEmpty
                ? const _EmptyDownloadsState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _DownloadSummaryCard(
                        summary: summary,
                        isPausing: _isPausing,
                        isResuming: _isResuming,
                        onPauseAll:
                            (summary.activeCount +
                                        summary.waitingForNetworkCount) >
                                    0 &&
                                !_isPausing &&
                                !_isResuming
                            ? () => _runBulkAction(pause: true)
                            : null,
                        onResumeAll:
                            summary.pausedCount > 0 &&
                                !_isPausing &&
                                !_isResuming
                            ? () => _runBulkAction(pause: false)
                            : null,
                      ),
                      if (activeItems.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DownloadSection(
                          title: 'Downloading',
                          items: activeItems,
                        ),
                      ],
                      if (pausedItems.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DownloadSection(title: 'Paused', items: pausedItems),
                      ],
                      if (failedItems.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DownloadSection(
                          title: 'Needs attention',
                          items: failedItems,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloadsState extends StatelessWidget {
  const _EmptyDownloadsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: DownloadQueuePage.emptyStateKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_done_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No active downloads',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'New episode downloads will appear here while they are running.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadSummaryCard extends StatelessWidget {
  const _DownloadSummaryCard({
    required this.summary,
    required this.isPausing,
    required this.isResuming,
    required this.onPauseAll,
    required this.onResumeAll,
  });

  final DownloadTransferSummary summary;
  final bool isPausing;
  final bool isResuming;
  final VoidCallback? onPauseAll;
  final VoidCallback? onResumeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressLabel =
        '${(summary.progressFraction * 100).toStringAsFixed(1)}%${summary.progressIsEstimated ? ' estimated' : ''}';
    final etaLabel = summary.eta != null
        ? DownloadTransferFormatters.formatEta(summary.eta)
        : summary.activeCount > 0
        ? 'Calculating…'
        : '—';

    return Card(
      key: DownloadQueuePage.summaryCardKey,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live downloads', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: summary.progressFraction),
            const SizedBox(height: 8),
            Text(
              '$progressLabel • ${_summaryTransferText(summary)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.downloading_outlined,
                    label: '${summary.activeCount} active',
                    value: _formatRate(summary.downloadRate),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.upload_outlined,
                    label: 'Upload',
                    value: _formatRate(summary.uploadRate),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.schedule_outlined,
                    label: 'ETA',
                    value: etaLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: DownloadQueuePage.pauseAllButtonKey,
                  onPressed: onPauseAll,
                  icon: isPausing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.pause_circle_outline),
                  label: const Text('Pause all'),
                ),
                FilledButton.icon(
                  key: DownloadQueuePage.resumeAllButtonKey,
                  onPressed: onResumeAll,
                  icon: isResuming
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline),
                  label: const Text('Resume all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadSection extends StatelessWidget {
  const _DownloadSection({required this.title, required this.items});

  final String title;
  final List<DownloadTransferItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in items) ...[
          _DownloadItemCard(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DownloadItemCard extends StatelessWidget {
  const _DownloadItemCard({required this.item});

  final DownloadTransferItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusPresentation(context, item.status);
    final hasRates = item.downloadRate != null || item.uploadRate != null;
    final showLiveTransferMetrics =
        item.status == DownloadTransferStatus.preparing ||
        item.status == DownloadTransferStatus.downloading;
    final errorMessage = item.errorMessage;
    final eta = item.eta == null
        ? 'Calculating…'
        : DownloadTransferFormatters.formatEta(item.eta);

    return Card(
      key: DownloadQueuePage.itemKey(item.key),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(status.icon, color: status.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: status.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: item.progressFraction),
            const SizedBox(height: 8),
            Text(
              '${(item.progressFraction * 100).toStringAsFixed(1)}% • ${_itemTransferText(item)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasRates ||
                item.eta != null ||
                item.seeds != null ||
                item.peers != null ||
                showLiveTransferMetrics) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (item.downloadRate != null || showLiveTransferMetrics)
                    Text('↓ ${_formatRate(item.downloadRate)}'),
                  if (item.uploadRate != null)
                    Text('↑ ${_formatRate(item.uploadRate)}'),
                  if (showLiveTransferMetrics) Text('ETA $eta'),
                  if (item.seeds != null || item.peers != null)
                    Text('${item.seeds ?? 0} seeds • ${item.peers ?? 0} peers'),
                ],
              ),
            ],
            if (item.status == DownloadTransferStatus.waitingForNetwork) ...[
              const SizedBox(height: 12),
              Text(
                'Transfers will continue when your network allows them.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

({IconData icon, Color color, String label}) _statusPresentation(
  BuildContext context,
  DownloadTransferStatus status,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    DownloadTransferStatus.preparing => (
      icon: Icons.hourglass_top_outlined,
      color: colors.primary,
      label: 'Preparing',
    ),
    DownloadTransferStatus.downloading => (
      icon: Icons.downloading_outlined,
      color: colors.primary,
      label: 'Downloading',
    ),
    DownloadTransferStatus.paused => (
      icon: Icons.pause_circle_outline,
      color: colors.onSurfaceVariant,
      label: 'Paused',
    ),
    DownloadTransferStatus.waitingForNetwork => (
      icon: Icons.wifi_off_outlined,
      color: colors.tertiary,
      label: 'Waiting for network',
    ),
    DownloadTransferStatus.failed => (
      icon: Icons.error_outline,
      color: colors.error,
      label: 'Needs attention',
    ),
  };
}

String _summaryTransferText(DownloadTransferSummary summary) {
  if (summary.totalBytes == null) {
    return 'Calculating…';
  }
  return '${DownloadTransferFormatters.formatBytes(summary.receivedBytes ?? 0)} of ${DownloadTransferFormatters.formatBytes(summary.totalBytes)}';
}

String _itemTransferText(DownloadTransferItem item) {
  if (item.totalBytes == null) {
    return 'Calculating…';
  }
  return '${DownloadTransferFormatters.formatBytes(item.receivedBytes ?? 0)} of ${DownloadTransferFormatters.formatBytes(item.totalBytes)}';
}

String _formatRate(int? bytesPerSecond) {
  if (bytesPerSecond == null) {
    return '—';
  }
  return DownloadTransferFormatters.formatRate(bytesPerSecond);
}
