import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/widgets/download_preparation_dialog.dart';
import 'package:tamashii/widgets/series_folder_confirmation_dialog.dart';

typedef SeriesFolderPlanBuilder = Future<SeriesFolderResolutionPlan> Function({
  required ShowInfo showInfo,
  required String basePath,
  required OnDeviceTextGenerator textGenerator,
});

class ReleaseDownloadButton extends ConsumerWidget {
  const ReleaseDownloadButton({
    super.key,
    required this.show,
    this.displayTitle,
    this.withLabel = false,
    this.seriesFolderPlanBuilder = defaultSeriesFolderPlanBuilder,
  });

  final ShowInfo show;
  final String? displayTitle;
  final bool withLabel;
  final SeriesFolderPlanBuilder seriesFolderPlanBuilder;

  static Future<SeriesFolderResolutionPlan> defaultSeriesFolderPlanBuilder({
    required ShowInfo showInfo,
    required String basePath,
    required OnDeviceTextGenerator textGenerator,
  }) {
    return SeriesFolderResolutionService(textGenerator: textGenerator)
        .plan(showTitle: showInfo.show, basePath: basePath);
  }

  Future<String?> _determineDownloadPath({
    required BuildContext context,
    required ShowInfo showInfo,
    required Map<String, String> currentMappings,
    required String displayTitle,
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
          showTitle: displayTitle,
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
      dialogTitle: 'Select download folder for "$displayTitle"',
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
        displayTitle:
            displayTitle ??
            ref
                .read(
                  cachedShowCatalogMatchProvider(
                    ShowCatalogTarget.fromRelease(show),
                  ),
                )
                ?.entry
                ?.displayTitle ??
            show.show,
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
    return withLabel
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
