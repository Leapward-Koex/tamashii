import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/download_preparation_dialog.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';
import 'package:tamashii/widgets/series_folder_confirmation_dialog.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';

typedef SeriesFolderPlanBuilder = Future<SeriesFolderResolutionPlan> Function({
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
    this.posterParallax,
    this.revealIndex = 0,
  });

  final ShowInfo show;
  final SeriesFolderPlanBuilder seriesFolderPlanBuilder;
  final bool featured;
  final ValueListenable<double>? posterParallax;
  final int revealIndex;

  static Key featuredPosterTransformKey(String showName) =>
      ValueKey<String>('featured-show-poster-transform-$showName');

  static Key featuredCardKey(String showName) =>
      ValueKey<String>('featured-show-card-$showName');

  static Key featuredTopBadgeKey(String showName) =>
      ValueKey<String>('featured-show-top-badge-$showName');

  static Key featuredContentKey(String showName) =>
      ValueKey<String>('featured-show-content-$showName');

  static Key standardCardKey(String showName) =>
      ValueKey<String>('standard-show-card-$showName');

  static Key standardStatusKey(String showName) =>
      ValueKey<String>('standard-show-status-$showName');

  static Key standardActionsKey(String showName) =>
      ValueKey<String>('standard-show-actions-$showName');

  static Future<SeriesFolderResolutionPlan> _defaultSeriesFolderPlanBuilder({
    required ShowInfo showInfo,
    required String basePath,
    required OnDeviceTextGenerator textGenerator,
  }) {
    return SeriesFolderResolutionService(textGenerator: textGenerator)
        .plan(showTitle: showInfo.show, basePath: basePath);
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
    required Future<void> Function(String path) saveFolder,
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
        action: () => seriesFolderPlanBuilder(
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
        if (!context.mounted) {
          return null;
        }
        await saveFolder(path);
        return path;
      } catch (e) {
        if (!context.mounted) {
          return null;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error creating folder: $e')));
        return null;
      }
    }

    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select download folder for "${showInfo.show}"',
    );
    if (!context.mounted) {
      return null;
    }
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      await saveFolder(selectedDirectory);
      return selectedDirectory;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No folder selected. Download cancelled.')),
    );
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrentKey = show.torrentKey;
    final isBookmarked = ref.watch(
      bookmarkedSeriesProvider.select(
        (bookmarks) =>
            bookmarks.value?.any(
              (bookmark) => bookmark.showName == show.show,
            ) ??
            false,
      ),
    );
    final torrentDownloadState = ref.watch(
      foregroundTorrentForShowProvider(torrentKey),
    );
    final isDownloaded = ref.watch(
      downloadedTorrentsProvider.select(
        (downloads) => downloads.value?.contains(torrentKey) ?? false,
      ),
    );

    final isDownloading = torrentDownloadState.isDownloading;
    final hasActiveTorrent = torrentDownloadState.torrentId != null;
    final showTorrentDetails =
        hasActiveTorrent && !torrentDownloadState.isCompleted;

    Future<void> performDownloadAction() async {
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

      if (torrentDownloadState.isCompleted && !isDownloaded) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Download completed.')));
        return;
      }

      final bestDownload = show.bestDownload;
      if (bestDownload == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download links available.')),
        );
        return;
      }

      final (mappings, autoGenerate, basePath) = await (
        ref.read(seriesFolderMappingProvider.future),
        ref.read(autoGenerateFoldersProvider.future),
        ref.read(downloadBasePathProvider.future),
      ).wait;
      if (!context.mounted) {
        return;
      }

      final seriesDownloadPath = await _determineDownloadPath(
        context: context,
        showInfo: show,
        currentMappings: mappings,
        isAutoGenEnabled: autoGenerate,
        currentBasePath: basePath,
        saveFolder: (path) => ref
            .read(seriesFolderMappingProvider.notifier)
            .setFolder(show.show, path),
        textGenerator: ref.read(onDeviceTextGeneratorProvider),
      );

      if (seriesDownloadPath == null ||
          seriesDownloadPath.isEmpty ||
          !context.mounted) {
        return;
      }

      await ref
          .read(foregroundTorrentManagerProvider.notifier)
          .startDownload(
            torrentKey,
            bestDownload.magnet,
            seriesDownloadPath,
            redownload: isDownloaded,
          );

      if (!context.mounted || isDownloaded) {
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

    Future<void> handleDownloadPressed() async {
      try {
        await performDownloadAction();
      } on ForegroundNotificationPermissionException catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            action: const SnackBarAction(
              label: 'Settings',
              onPressed: PermissionService.openSettings,
            ),
          ),
        );
      } on ForegroundTorrentCommandException catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update download: $error')),
        );
      }
    }

    Future<void> handleBookmarkPressed() async {
      final bookmarkedNotifier = ref.read(bookmarkedSeriesProvider.notifier);
      if (isBookmarked) {
        await bookmarkedNotifier.remove(show.show);
        return;
      }

      await bookmarkedNotifier.add(
        BookmarkedShowInfo(
          imageUrl: show.imageUrl,
          releaseDayOfWeek: show.releaseDate.toLocal().weekday,
          showName: show.show,
        ),
      );
    }

    final posterLookup = featured && isBookmarked
        ? _watchFeaturedPoster(ref)
        : null;
    final preferredPoster = posterLookup?.asData?.value;
    final poster = ShowImage(
      imageUrl: preferredPoster ?? show.imageUrl,
      fallbackImageUrl: preferredPoster == null ? null : show.imageUrl,
      faceAware: posterLookup != null && !posterLookup.isLoading,
    );
    final downloadLabel = _downloadActionLabel(
      isLoadingTorrent: torrentDownloadState.isLoading,
      isDownloading: isDownloading,
      isPaused: showTorrentDetails && !isDownloading,
      isDownloaded: isDownloaded,
      isCompleted: torrentDownloadState.isCompleted,
    );
    final actionIcon = torrentDownloadState.isLoading
        ? const SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            _downloadActionIcon(
              isDownloading: isDownloading,
              isPaused: showTorrentDetails && !isDownloading,
              isDownloaded: isDownloaded,
            ),
            size: 19,
          );
    final download = featured
        ? FilledButton.icon(
            onPressed: torrentDownloadState.isLoading
                ? null
                : handleDownloadPressed,
            icon: actionIcon,
            label: Text(downloadLabel),
          )
        : IconButton(
            tooltip: downloadLabel,
            onPressed: torrentDownloadState.isLoading
                ? null
                : handleDownloadPressed,
            icon: actionIcon,
          );
    final watching = IconButton(
      tooltip: isBookmarked ? 'Remove from watching' : 'Mark as watching',
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        size: 20,
      ),
      color: isBookmarked ? PaperLantern.red : PaperLantern.muted,
      onPressed: handleBookmarkPressed,
    );
    final status = showTorrentDetails
        ? _transferStatus(context, torrentDownloadState)
        : null;
    final card = featured
        ? _feature(context, poster, download, watching, isDownloaded, status)
        : _releaseRow(
            context,
            poster,
            download,
            watching,
            isDownloaded,
            status,
          );
    return StaggeredReveal(index: revealIndex, child: card);
  }

  AsyncValue<String?> _watchFeaturedPoster(WidgetRef ref) {
    final target = ShowCatalogTarget.fromRelease(show);
    final overrides = ref.watch(catalogMatchOverridesProvider);
    if (!overrides.hasValue) return overrides.whenData((_) => null);
    final choice = target.effectiveOverride(overrides.requireValue);
    if (!target.isReleaseScoped && !choice.exists) {
      return ref.watch(featuredTenraiPosterProvider(show.show));
    }
    // A title-only lookup identifies the regular season, even when the
    // featured release is a special with its own MyAnimeList identity.
    final entry = choice.entry;
    for (final url in [entry?.largeImageUrl, entry?.imageUrl]) {
      final uri = Uri.tryParse(url?.trim() ?? '');
      if (uri != null &&
          uri.host.isNotEmpty &&
          (uri.isScheme('https') || uri.isScheme('http'))) {
        return AsyncData(uri.toString());
      }
    }
    return const AsyncData(null);
  }

  Widget _releaseSurface(
    BuildContext context, {
    required Key key,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        key: key,
        color: PaperLantern.paper,
        child: InkWell(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => ShowInfoPage.release(show)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: featured
                    ? const BorderSide(color: PaperLantern.ink)
                    : BorderSide.none,
                bottom: BorderSide(
                  color: featured ? PaperLantern.ink : PaperLantern.rule,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: featured ? 14 : 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  String get _episodeLine {
    final resolution = show.bestDownload?.resolution;
    return [
      'Episode ${show.episode}',
      if (resolution != null) '${resolution.toJson()}p',
    ].join(' · ');
  }

  Widget _feature(
    BuildContext context,
    Widget poster,
    Widget download,
    Widget watching,
    bool isDownloaded,
    Widget? status,
  ) {
    final theme = Theme.of(context);
    final parallax = posterParallax;
    final editionDate = DateFormat.MMMd().format(show.releaseDate.toLocal());
    final title = show.show.trim();
    final lastWord = title.lastIndexOf(' ');
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Featured release',
          key: featuredTopBadgeKey(show.show),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: PaperLantern.serif,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: PaperLantern.red,
          ),
        ),
        const SizedBox(height: 9),
        Column(
          key: featuredContentKey(show.show),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  if (lastWord != -1)
                    TextSpan(text: title.substring(0, lastWord + 1)),
                  TextSpan(
                    text: title.substring(lastWord + 1),
                    style: lastWord == -1
                        ? null
                        : const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: PaperLantern.red,
                          ),
                  ),
                ],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: PaperLantern.serif,
                color: PaperLantern.ink,
                height: 1.04,
              ),
            ),
            const SizedBox(height: 9),
            Text(_episodeLine, style: PaperLantern.folio),
            Text(
              [
                editionDate,
                if (show.timeLabel.trim().isNotEmpty) show.timeLabel,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: PaperLantern.muted,
              ),
            ),
            if (isDownloaded)
              Text(
                'DOWNLOADED',
                style: PaperLantern.folio.copyWith(color: PaperLantern.red),
              ),
            const SizedBox(height: 7),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [download, watching],
            ),
          ],
        ),
      ],
    );
    final portrait = ClipRect(
      child: parallax == null
          ? poster
          : Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  top: -28,
                  child: ValueListenableBuilder<double>(
                    valueListenable: parallax,
                    child: poster,
                    builder: (context, offset, child) => Transform.translate(
                      key: featuredPosterTransformKey(show.show),
                      offset: Offset(0, offset.clamp(0.0, 28.0)),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
    );
    return _releaseSurface(
      context,
      key: featuredCardKey(show.show),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final posterWidth = (width * .42).clamp(0.0, 220.0);
              final frame = SizedBox(
                width: posterWidth,
                height: posterWidth * 1.32,
                child: ColoredBox(color: PaperLantern.wash, child: portrait),
              );
              // Give large accessibility type the entire column on a narrow phone.
              if (width < 260 ||
                  width < 440 &&
                      MediaQuery.textScalerOf(context).scale(16) >= 26) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [frame, const SizedBox(height: 14), copy],
                );
              }
              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  frame,
                ],
              );
            },
          ),
          if (status != null) ...[const SizedBox(height: 10), status],
        ],
      ),
    );
  }

  Widget _releaseRow(
    BuildContext context,
    Widget poster,
    Widget download,
    Widget watching,
    bool isDownloaded,
    Widget? status,
  ) {
    final theme = Theme.of(context);
    return _releaseSurface(
      context,
      key: standardCardKey(show.show),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 60,
                child: ColoredBox(color: PaperLantern.wash, child: poster),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.show,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: PaperLantern.serif,
                        fontSize: 18,
                        height: 1.12,
                        color: PaperLantern.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_episodeLine · ${DateFormat.MMMd().format(show.releaseDate.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PaperLantern.muted,
                      ),
                    ),
                    if (isDownloaded)
                      Text(
                        'DONE',
                        style: PaperLantern.folio.copyWith(
                          color: PaperLantern.red,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                key: standardActionsKey(show.show),
                mainAxisSize: MainAxisSize.min,
                children: [download, watching],
              ),
            ],
          ),
          if (status != null) ...[const SizedBox(height: 8), status],
        ],
      ),
    );
  }

  Widget _transferStatus(BuildContext context, TorrentDownloadState state) {
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: PaperLantern.muted);
    final progress = state.progressFraction.isFinite
        ? state.progressFraction.clamp(0.0, 1.0)
        : 0.0;
    final rateText = [
      if (state.metadata != null)
        featured ? state.displayName : state.formattedSize,
      'Down ${_formatBytes(state.downloadRate)}/s',
      'Up ${_formatBytes(state.uploadRate)}/s',
      if (!featured && state.stats != null)
        '${state.seeds} seeds · ${state.peers} peers',
    ].join(' · ');
    return Column(
      key: featured ? null : standardStatusKey(show.show),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _torrentStateLabel(state.currentState),
                style: PaperLantern.folio.copyWith(color: PaperLantern.red),
              ),
            ),
            Text('${(progress * 100).round()}%', style: PaperLantern.folio),
          ],
        ),
        const SizedBox(height: 4),
        GlowingProgressBar(
          progress: progress,
          height: 3,
          color: PaperLantern.red,
          backgroundColor: PaperLantern.wash,
          fillKey: ValueKey<String>(
            'show-progress-fill-${show.show}-${show.episode}',
          ),
        ),
        const SizedBox(height: 4),
        Text(rateText, style: muted),
      ],
    );
  }

  String _torrentStateLabel(TorrentState state) {
    switch (state) {
      case TorrentState.starting:
        return 'STARTING';
      case TorrentState.downloadingMetadata:
        return 'GETTING INFO';
      case TorrentState.downloading:
        return 'DOWNLOADING';
      case TorrentState.seeding:
        return 'SEEDING';
      case TorrentState.paused:
        return 'PAUSED';
      case TorrentState.error:
        return 'ERROR';
      case TorrentState.stopped:
        return 'STOPPED';
    }
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
    if (isDownloaded) {
      return 'Redownload';
    }
    if (isCompleted) {
      return 'Completed';
    }
    return 'Download';
  }
}
