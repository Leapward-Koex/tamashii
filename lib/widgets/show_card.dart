import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/widgets/download_preparation_dialog.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';
import 'package:tamashii/widgets/series_folder_confirmation_dialog.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';

typedef SeriesFolderPlanBuilder =
    Future<SeriesFolderResolutionPlan> Function({
      required ShowInfo showInfo,
      required String basePath,
      required OnDeviceTextGenerator textGenerator,
    });

class ShowCard extends ConsumerWidget {
  const ShowCard({
    super.key,
    required this.show,
    this.seriesFolderPlanBuilder = _defaultSeriesFolderPlanBuilder,
    this.featured = false,
    this.posterParallax = 0,
    this.revealIndex = 0,
  });

  final ShowInfo show;
  final SeriesFolderPlanBuilder seriesFolderPlanBuilder;
  final bool featured;
  final double posterParallax;
  final int revealIndex;

  static Key featuredPosterTransformKey(String showName) =>
      ValueKey<String>('featured-show-poster-transform-$showName');

  static Future<SeriesFolderResolutionPlan> _defaultSeriesFolderPlanBuilder({
    required ShowInfo showInfo,
    required String basePath,
    required OnDeviceTextGenerator textGenerator,
  }) {
    return SeriesFolderResolutionService(
      textGenerator: textGenerator,
    ).plan(showTitle: showInfo.show, basePath: basePath);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  Future<String?> _determineDownloadPath({
    required BuildContext context,
    required ShowInfo showInfo,
    required Map<String, String> currentMappings,
    required bool isAutoGenEnabled,
    required String currentBasePath,
    required SeriesFolderMapping seriesMappingNotifier,
    required OnDeviceTextGenerator textGenerator,
  }) async {
    final seriesSpecificPath = currentMappings[showInfo.show];
    if (seriesSpecificPath != null && seriesSpecificPath.isNotEmpty) {
      return seriesSpecificPath;
    }

    if (isAutoGenEnabled) {
      if (currentBasePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Base download folder not set. Please configure it in Settings.',
            ),
          ),
        );
        return null;
      }

      final plan = await runWithDownloadPreparationDialog(
        context: context,
        action:
            () => seriesFolderPlanBuilder(
              showInfo: showInfo,
              basePath: currentBasePath,
              textGenerator: textGenerator,
            ),
      );

      if (!context.mounted) {
        return null;
      }

      String? path = plan.suggestedPath;
      if (plan.usedAi) {
        path = await showSeriesFolderConfirmationDialog(
          context: context,
          showTitle: showInfo.show,
          basePath: currentBasePath,
          plan: plan,
        );
      }

      if (path == null || path.isEmpty) {
        return null;
      }

      try {
        await Directory(path).create(recursive: true);
        await seriesMappingNotifier.setFolder(showInfo.show, path);
        return path;
      } catch (e) {
        if (!context.mounted) {
          return null;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating folder: $e')));
        return null;
      }
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select download folder for "${showInfo.show}"',
    );
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      await seriesMappingNotifier.setFolder(showInfo.show, selectedDirectory);
      return selectedDirectory;
    }

    if (!context.mounted) {
      return null;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No folder selected. Download cancelled.')),
    );
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks =
        ref.watch(bookmarkedSeriesProvider).value ?? <BookmarkedShowInfo>[];
    final isBookmarked = bookmarks.any(
      (bookmark) => bookmark.showName == show.show,
    );
    final bookmarkedNotifier = ref.read(bookmarkedSeriesProvider.notifier);
    final seriesMappingSettings = ref.watch(seriesFolderMappingProvider);
    final autoGenSettings = ref.watch(autoGenerateFoldersProvider);
    final basePathSettings = ref.watch(downloadBasePathProvider);
    final seriesMappingNotifier = ref.read(
      seriesFolderMappingProvider.notifier,
    );
    final textGenerator = ref.read(onDeviceTextGeneratorProvider);

    final torrentKey = '${show.show}-${show.episode}';
    final torrentDownloadState = ref.watch(
      foregroundTorrentForShowProvider(torrentKey),
    );
    final downloadedSet =
        ref.watch(downloadedTorrentsProvider).value ?? <String>{};
    final isDownloaded = downloadedSet.contains(torrentKey);

    final progressFraction = torrentDownloadState.progressFraction;
    final downloadRate = torrentDownloadState.downloadRate;
    final uploadRate = torrentDownloadState.uploadRate;
    final isLoadingTorrent = torrentDownloadState.isLoading;
    final isDownloading = torrentDownloadState.isDownloading;
    final isPaused = torrentDownloadState.isPaused;
    final hasActiveTorrent = torrentDownloadState.torrentId != null;
    final showProgress =
        hasActiveTorrent && progressFraction > 0 && progressFraction < 1;
    final torrentStateColor = _getTorrentStateColor(
      torrentDownloadState.currentState,
    );

    Future<void> handleDownloadPressed() async {
      if (isDownloading) {
        await ref
            .read(foregroundTorrentManagerProvider.notifier)
            .pauseDownload(torrentKey);
        return;
      }

      if (hasActiveTorrent &&
          !isDownloading &&
          !torrentDownloadState.isCompleted) {
        await ref
            .read(foregroundTorrentManagerProvider.notifier)
            .resumeDownload(torrentKey);
        return;
      }

      if (isDownloaded && !isDownloading) {
        final seriesDownloadPath = await _determineDownloadPath(
          context: context,
          showInfo: show,
          currentMappings: seriesMappingSettings.value ?? <String, String>{},
          isAutoGenEnabled: autoGenSettings.value ?? true,
          currentBasePath: basePathSettings.value ?? '',
          seriesMappingNotifier: seriesMappingNotifier,
          textGenerator: textGenerator,
        );
        if (seriesDownloadPath != null && seriesDownloadPath.isNotEmpty) {
          await ref
              .read(foregroundTorrentManagerProvider.notifier)
              .startDownload(
                torrentKey,
                show.downloads.first.magnet,
                seriesDownloadPath,
              );
        }
        return;
      }

      if (torrentDownloadState.isCompleted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Download completed.')));
        return;
      }

      final seriesDownloadPath = await _determineDownloadPath(
        context: context,
        showInfo: show,
        currentMappings: seriesMappingSettings.value ?? <String, String>{},
        isAutoGenEnabled: autoGenSettings.value ?? true,
        currentBasePath: basePathSettings.value ?? '',
        seriesMappingNotifier: seriesMappingNotifier,
        textGenerator: textGenerator,
      );

      if (seriesDownloadPath == null || seriesDownloadPath.isEmpty) {
        return;
      }

      if (show.downloads.isEmpty) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download links available.')),
        );
        return;
      }

      final best = show.downloads.reduce((a, b) {
        final aRes = int.parse(a.resolution.toJson());
        final bRes = int.parse(b.resolution.toJson());
        return aRes >= bRes ? a : b;
      });

      await ref
          .read(foregroundTorrentManagerProvider.notifier)
          .startDownload(torrentKey, best.magnet, seriesDownloadPath);

      if (!context.mounted) {
        return;
      }
      if (torrentDownloadState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${torrentDownloadState.errorMessage}'),
          ),
        );
      } else if (torrentDownloadState.torrentId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started to: $seriesDownloadPath')),
        );
      }
    }

    Future<void> handleBookmarkPressed() async {
      if (isBookmarked) {
        await bookmarkedNotifier.remove(show.show);
        return;
      }

      await bookmarkedNotifier.add(
        BookmarkedShowInfo(
          imageUrl: show.imageUrl,
          releaseDayOfWeek: show.releaseDate.weekday,
          showName: show.show,
        ),
      );
    }

    final cardBody =
        featured
            ? _buildFeaturedCard(
              context: context,
              isBookmarked: isBookmarked,
              isDownloaded: isDownloaded,
              isLoadingTorrent: isLoadingTorrent,
              isPaused: isPaused,
              isDownloading: isDownloading,
              progressFraction: progressFraction,
              showProgress: showProgress,
              torrentDownloadState: torrentDownloadState,
              torrentStateColor: torrentStateColor,
              downloadRate: downloadRate,
              uploadRate: uploadRate,
              onDownloadPressed:
                  isLoadingTorrent ? null : () => handleDownloadPressed(),
              onBookmarkPressed: () => handleBookmarkPressed(),
            )
            : _buildStandardCard(
              context: context,
              isBookmarked: isBookmarked,
              isDownloaded: isDownloaded,
              isLoadingTorrent: isLoadingTorrent,
              isPaused: isPaused,
              isDownloading: isDownloading,
              progressFraction: progressFraction,
              showProgress: showProgress,
              torrentDownloadState: torrentDownloadState,
              torrentStateColor: torrentStateColor,
              downloadRate: downloadRate,
              uploadRate: uploadRate,
              onDownloadPressed:
                  isLoadingTorrent ? null : () => handleDownloadPressed(),
              onBookmarkPressed: () => handleBookmarkPressed(),
            );

    return StaggeredReveal(index: revealIndex, child: cardBody);
  }

  Widget _buildFeaturedCard({
    required BuildContext context,
    required bool isBookmarked,
    required bool isDownloaded,
    required bool isLoadingTorrent,
    required bool isPaused,
    required bool isDownloading,
    required double progressFraction,
    required bool showProgress,
    required TorrentDownloadState torrentDownloadState,
    required Color torrentStateColor,
    required int downloadRate,
    required int uploadRate,
    required Future<void> Function()? onDownloadPressed,
    required Future<void> Function() onBookmarkPressed,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: 324,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Transform.translate(
                key: featuredPosterTransformKey(show.show),
                offset: Offset(0, posterParallax),
                child: ShowImage(imageUrl: show.imageUrl),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.24),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _buildInfoPill(
                label: 'Latest release',
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            if (isDownloaded)
              Positioned(
                top: 18,
                right: 18,
                child: _buildInfoPill(
                  label: 'DOWNLOADED',
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green.withValues(alpha: 0.85),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.show,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoPill(
                          label: 'Episode ${show.episode}',
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                        ),
                        _buildInfoPill(
                          label:
                              '${DateFormat.MMMd().format(show.releaseDate)} • ${show.timeLabel}',
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                        ),
                        if (torrentDownloadState.torrentId != null)
                          _buildInfoPill(
                            label:
                                torrentDownloadState.currentState.name
                                    .toUpperCase(),
                            foregroundColor: Colors.white,
                            backgroundColor: torrentStateColor.withValues(
                              alpha: 0.28,
                            ),
                          ),
                      ],
                    ),
                    if (torrentDownloadState.torrentId != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            _getTorrentStateIcon(
                              torrentDownloadState.currentState,
                            ),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _featuredStatusText(
                                torrentDownloadState: torrentDownloadState,
                                downloadRate: downloadRate,
                                uploadRate: uploadRate,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.84),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showProgress) ...[
                      const SizedBox(height: 14),
                      GlowingProgressBar(
                        progress: progressFraction,
                        height: 8,
                        color: const Color(0xFF74F5FF),
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: onDownloadPressed,
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.16,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon:
                                isLoadingTorrent
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(
                                      _downloadActionIcon(
                                        isDownloading: isDownloading,
                                        isPaused: isPaused,
                                        isDownloaded: isDownloaded,
                                      ),
                                    ),
                            label: Text(
                              _downloadActionLabel(
                                isLoadingTorrent: isLoadingTorrent,
                                isDownloading: isDownloading,
                                isPaused: isPaused,
                                isDownloaded: isDownloaded,
                                isCompleted: torrentDownloadState.isCompleted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: onBookmarkPressed,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(52, 52),
                            foregroundColor: Colors.white,
                            backgroundColor:
                                isBookmarked
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardCard({
    required BuildContext context,
    required bool isBookmarked,
    required bool isDownloaded,
    required bool isLoadingTorrent,
    required bool isPaused,
    required bool isDownloading,
    required double progressFraction,
    required bool showProgress,
    required TorrentDownloadState torrentDownloadState,
    required Color torrentStateColor,
    required int downloadRate,
    required int uploadRate,
    required Future<void> Function()? onDownloadPressed,
    required Future<void> Function() onBookmarkPressed,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ShowImage(imageUrl: show.imageUrl),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isDownloaded)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildInfoPill(
                          label: 'DONE',
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        show.show,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoPill(
                            label: 'Ep ${show.episode}',
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                          ),
                          _buildInfoPill(
                            label: DateFormat.MMMd().format(show.releaseDate),
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                          ),
                        ],
                      ),
                      if (showProgress) ...[
                        const SizedBox(height: 14),
                        GlowingProgressBar(
                          progress: progressFraction,
                          fillKey: ValueKey<String>(
                            'show-progress-fill-${show.show}-${show.episode}',
                          ),
                        ),
                      ],
                      if (torrentDownloadState.torrentId != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.72,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getTorrentStateIcon(
                                      torrentDownloadState.currentState,
                                    ),
                                    size: 16,
                                    color: torrentStateColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    torrentDownloadState.currentState.name
                                        .toUpperCase(),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: torrentStateColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _compactStatusText(
                                  torrentDownloadState: torrentDownloadState,
                                  downloadRate: downloadRate,
                                  uploadRate: uploadRate,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.tonal(
                            onPressed: onDownloadPressed,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.all(0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child:
                                isLoadingTorrent
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(
                                      _downloadActionIcon(
                                        isDownloading: isDownloading,
                                        isPaused: isPaused,
                                        isDownloaded: isDownloaded,
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: onBookmarkPressed,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.all(0),
                              backgroundColor:
                                  isBookmarked
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Icon(
                              isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required Color foregroundColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _featuredStatusText({
    required TorrentDownloadState torrentDownloadState,
    required int downloadRate,
    required int uploadRate,
  }) {
    if (torrentDownloadState.metadata != null) {
      return '${torrentDownloadState.displayName} • ↓ ${_formatBytes(downloadRate)}/s • ↑ ${_formatBytes(uploadRate)}/s';
    }
    return '↓ ${_formatBytes(downloadRate)}/s • ↑ ${_formatBytes(uploadRate)}/s';
  }

  String _compactStatusText({
    required TorrentDownloadState torrentDownloadState,
    required int downloadRate,
    required int uploadRate,
  }) {
    final stats = <String>[
      '↓ ${_formatBytes(downloadRate)}/s',
      '↑ ${_formatBytes(uploadRate)}/s',
    ];

    if (torrentDownloadState.stats != null) {
      stats.add(
        'S:${torrentDownloadState.stats!.seeds} P:${torrentDownloadState.stats!.peers}',
      );
    }

    if (torrentDownloadState.metadata != null) {
      stats.insert(0, torrentDownloadState.formattedSize);
    }

    return stats.join(' • ');
  }

  IconData _downloadActionIcon({
    required bool isDownloading,
    required bool isPaused,
    required bool isDownloaded,
  }) {
    if (isDownloading) {
      return Icons.pause_circle_filled_rounded;
    }
    if (isPaused) {
      return Icons.play_circle_filled_rounded;
    }
    if (isDownloaded) {
      return Icons.replay;
    }
    return Icons.download_rounded;
  }

  String _downloadActionLabel({
    required bool isLoadingTorrent,
    required bool isDownloading,
    required bool isPaused,
    required bool isDownloaded,
    required bool isCompleted,
  }) {
    if (isLoadingTorrent) {
      return 'Preparing';
    }
    if (isDownloading) {
      return 'Pause';
    }
    if (isPaused) {
      return 'Resume';
    }
    if (isCompleted) {
      return 'Open';
    }
    if (isDownloaded) {
      return 'Redownload';
    }
    return 'Download';
  }

  IconData _getTorrentStateIcon(TorrentState state) {
    switch (state) {
      case TorrentState.starting:
        return Icons.play_circle_outline;
      case TorrentState.downloadingMetadata:
        return Icons.info_outline;
      case TorrentState.downloading:
        return Icons.download;
      case TorrentState.seeding:
        return Icons.upload;
      case TorrentState.paused:
        return Icons.pause_circle_outline;
      case TorrentState.error:
        return Icons.error_outline;
      case TorrentState.stopped:
        return Icons.stop;
    }
  }

  Color _getTorrentStateColor(TorrentState state) {
    switch (state) {
      case TorrentState.starting:
        return Colors.orange;
      case TorrentState.downloadingMetadata:
        return Colors.blue;
      case TorrentState.downloading:
        return Colors.green;
      case TorrentState.seeding:
        return Colors.purple;
      case TorrentState.paused:
        return Colors.grey;
      case TorrentState.error:
        return Colors.red;
      case TorrentState.stopped:
        return Colors.black54;
    }
  }
}
