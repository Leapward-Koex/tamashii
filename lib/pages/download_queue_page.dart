import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/services/download_transfer_metrics.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';
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
    final activeItems = <DownloadTransferItem>[];
    final pausedItems = <DownloadTransferItem>[];
    final failedItems = <DownloadTransferItem>[];
    for (final item in report.items) {
      switch (item.status) {
        case DownloadTransferStatus.preparing:
        case DownloadTransferStatus.downloading:
        case DownloadTransferStatus.waitingForNetwork:
          activeItems.add(item);
        case DownloadTransferStatus.paused:
          pausedItems.add(item);
        case DownloadTransferStatus.failed:
          failedItems.add(item);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: PaperLantern.ink),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              TransferPolicyBanner(
                snapshot: transferPolicy,
                platform: effectivePlatform,
              ),
              Expanded(
                child: report.items.isEmpty
                    ? const _EmptyDownloadsState()
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: _TransferSummary(
                                summary: summary,
                                isPausing: _isPausing,
                                isResuming: _isResuming,
                                onPauseAll:
                                    (summary.activeCount +
                                                summary
                                                    .waitingForNetworkCount) >
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
                            ),
                          ),
                          if (activeItems.isNotEmpty)
                            _DownloadSection(
                              key: const ValueKey(
                                DownloadTransferStatus.downloading,
                              ),
                              title: 'Downloading',
                              items: activeItems,
                            ),
                          if (pausedItems.isNotEmpty)
                            _DownloadSection(
                              key: const ValueKey(
                                DownloadTransferStatus.paused,
                              ),
                              title: 'Paused',
                              items: pausedItems,
                            ),
                          if (failedItems.isNotEmpty)
                            _DownloadSection(
                              key: const ValueKey(
                                DownloadTransferStatus.failed,
                              ),
                              title: 'Needs attention',
                              items: failedItems,
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDownloadsState extends StatelessWidget {
  const _EmptyDownloadsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: DownloadQueuePage.emptyStateKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.download_done_outlined,
              size: 40,
              color: PaperLantern.red,
            ),
            const SizedBox(height: 16),
            Text(
              'No active downloads',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
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

class _TransferSummary extends StatelessWidget {
  const _TransferSummary({
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
    final progressLabel =
        '${(summary.progressFraction * 100).toStringAsFixed(1)}%${summary.progressIsEstimated ? ' estimated' : ''}';
    final etaLabel = summary.eta != null
        ? DownloadTransferFormatters.formatEta(summary.eta)
        : summary.activeCount > 0
        ? 'Calculating…'
        : '—';

    return Column(
      key: DownloadQueuePage.summaryCardKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PaperSectionHeading('Live downloads'),
        const SizedBox(height: 12),
        Text(
          '$progressLabel • ${_summaryTransferText(summary)}',
          style: PaperLantern.folio.copyWith(color: PaperLantern.ink),
        ),
        const SizedBox(height: 8),
        GlowingProgressBar(progress: summary.progressFraction, height: 4),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 10,
          children: [
            _SummaryMetric(
              label: '${summary.activeCount} active',
              value: _formatRate(summary.downloadRate),
            ),
            _SummaryMetric(
              label: 'Upload',
              value: _formatRate(summary.uploadRate),
            ),
            _SummaryMetric(label: 'ETA', value: etaLabel),
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
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PaperLantern.folio),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _DownloadSection extends StatelessWidget {
  const _DownloadSection({super.key, required this.title, required this.items});

  final String title;
  final List<DownloadTransferItem> items;

  @override
  Widget build(BuildContext context) {
    // Flutter requests existing keys when the report changes. Preserve the
    // progress animation of a transfer when an earlier one leaves the queue.
    late final indices = {
      for (var i = 0; i < items.length; i++)
        DownloadQueuePage.itemKey(items[i].key): i,
    };
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: PaperSectionHeading(
              title,
              trailing: Text(
                items.length.toString().padLeft(2, '0'),
                style: PaperLantern.folio,
                semanticsLabel: '${items.length} transfers',
              ),
            ),
          ),
          SliverList.builder(
            itemCount: items.length,
            findChildIndexCallback: (key) => indices[key],
            itemBuilder: (context, index) {
              final item = items[index];
              return _TransferRow(
                key: DownloadQueuePage.itemKey(item.key),
                item: item,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({super.key, required this.item});

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

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaperLantern.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(status.icon, color: status.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: PaperLantern.serif,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.label,
                        style: PaperLantern.folio.copyWith(color: status.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlowingProgressBar(
              progress: item.progressFraction,
              color: status.color,
              height: 3,
            ),
            const SizedBox(height: 8),
            Text(
              '${(item.progressFraction * 100).toStringAsFixed(1)}% • ${_itemTransferText(item)}',
              style: PaperLantern.folio,
            ),
            if (hasRates ||
                item.eta != null ||
                item.seeds != null ||
                item.peers != null ||
                showLiveTransferMetrics) ...[
              const SizedBox(height: 12),
              DefaultTextStyle(
                style: PaperLantern.folio.copyWith(color: PaperLantern.ink),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (item.downloadRate != null || showLiveTransferMetrics)
                      Text('↓ ${_formatRate(item.downloadRate)}'),
                    if (item.uploadRate != null)
                      Text('↑ ${_formatRate(item.uploadRate)}'),
                    if (showLiveTransferMetrics) Text('ETA $eta'),
                    if (item.seeds != null || item.peers != null)
                      Text(
                        '${item.seeds ?? 0} seeds • ${item.peers ?? 0} peers',
                      ),
                  ],
                ),
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
