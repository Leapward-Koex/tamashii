import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/download_preparation_dialog.dart';
import 'package:tamashii/widgets/series_folder_confirmation_dialog.dart';

typedef SeriesFolderPlanBuilder = Future<SeriesFolderResolutionPlan> Function({
  required String showTitle,
  required String basePath,
  required OnDeviceTextGenerator textGenerator,
});

class ReleaseDownloadButton extends HookConsumerWidget {
  const ReleaseDownloadButton({
    super.key,
    required this.show,
    this.displayTitle,
    this.withLabel = false,
    this.seriesFolderPlanBuilder = defaultSeriesFolderPlanBuilder,
  }) : _episodeTile = false;

  const ReleaseDownloadButton.episode({
    super.key,
    required this.show,
    required this.displayTitle,
  }) : _episodeTile = true,
       withLabel = false,
       seriesFolderPlanBuilder = defaultSeriesFolderPlanBuilder;

  final bool _episodeTile;
  final ShowInfo show;
  final String? displayTitle;
  final bool withLabel;
  final SeriesFolderPlanBuilder seriesFolderPlanBuilder;

  static Future<SeriesFolderResolutionPlan> defaultSeriesFolderPlanBuilder({
    required String showTitle,
    required String basePath,
    required OnDeviceTextGenerator textGenerator,
  }) {
    return SeriesFolderResolutionService(textGenerator: textGenerator)
        .plan(showTitle: showTitle, basePath: basePath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preparing = useState(false);
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

      await _startReleaseDownload(
        context,
        ref,
        target: ShowCatalogTarget.fromRelease(show),
        torrentKey: torrentKey,
        magnet: bestDownload.magnet,
        displayTitle: displayTitle,
        seriesFolderPlanBuilder: seriesFolderPlanBuilder,
        redownload: isDownloaded,
      );
    }

    Future<void> handleDownloadPressed() async {
      if (preparing.value) return;
      preparing.value = true;
      try {
        await _runDownloadAction(context, performDownloadAction);
      } finally {
        if (context.mounted) preparing.value = false;
      }
    }

    final busy = preparing.value || torrentDownloadState.isLoading;
    final downloadLabel = _downloadActionLabel(
      isLoadingTorrent: busy,
      isDownloading: isDownloading,
      isPaused: showTorrentDetails && !isDownloading,
      isDownloaded: isDownloaded,
      isCompleted: torrentDownloadState.isCompleted,
    );
    final actionIcon = busy
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
    if (_episodeTile) {
      final available = hasActiveTorrent || show.bestDownload != null;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        titleAlignment: ListTileTitleAlignment.center,
        shape: const Border(bottom: BorderSide(color: PaperLantern.rule)),
        title: Text(formatEpisodeLabel(show.episode)),
        subtitle: Text(DateFormat.yMMMd().format(show.releaseDate.toLocal())),
        enabled: available && !busy,
        trailing: Tooltip(
          message: available ? downloadLabel : 'No download available',
          child: SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: Center(
              child: available
                  ? actionIcon
                  : const Icon(Icons.file_download_off_outlined, size: 19),
            ),
          ),
        ),
        onTap: available && !busy ? handleDownloadPressed : null,
      );
    }
    return withLabel
        ? FilledButton.icon(
            onPressed: busy ? null : handleDownloadPressed,
            icon: actionIcon,
            label: Text(downloadLabel),
          )
        : IconButton(
            tooltip: downloadLabel,
            onPressed: busy ? null : handleDownloadPressed,
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

/// The series page supplies releases in oldest-first queue order.
class DownloadAllButton extends HookConsumerWidget {
  const DownloadAllButton({
    super.key,
    required this.releases,
    required this.displayTitle,
    required this.loadingReleases,
  });

  final List<ShowInfo> releases;
  final String displayTitle;
  final bool loadingReleases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitting = useState(false);
    final completed = ref.watch(downloadedTorrentsProvider).value;
    final manager = Platform.isAndroid
        ? foregroundTorrentManagerProvider
        : torrentManagerProvider;
    final candidates = [
      if (completed != null)
        for (final release in releases)
          if (release.bestDownload != null &&
              !completed.contains(release.torrentKey))
            release.torrentKey,
    ];
    final hasPending = ref.watch(
      manager.select(
        (state) =>
            candidates.any((key) => state.torrents[key]?.canQueue ?? true),
      ),
    );

    Future<void> downloadAll() async {
      if (submitting.value) return;
      submitting.value = true;
      try {
        await _runDownloadAction(context, () async {
          final path = await _resolveSeriesDownloadPath(
            context,
            ref,
            ShowCatalogTarget.fromRelease(releases.first),
            displayTitle: displayTitle,
          );
          if (path == null || !context.mounted) return;
          await ref
              .read(foregroundTorrentManagerProvider.notifier)
              .startSeriesDownloads(releases, path);
        });
      } finally {
        if (context.mounted) submitting.value = false;
      }
    }

    return TextButton.icon(
      onPressed: hasPending && !loadingReleases && !submitting.value
          ? downloadAll
          : null,
      icon: const Icon(Icons.download_rounded),
      label: const Text('Download all'),
    );
  }
}

Future<void> _runDownloadAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ForegroundNotificationPermissionException catch (error) {
    if (!context.mounted) return;
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to update download: $error')),
    );
  }
}

/// Completes a Download tap from the launcher after its series page opens.
Future<void> setUpWidgetDownload(
  BuildContext context,
  WidgetRef ref, {
  required ShowCatalogTarget target,
  required String torrentKey,
  required String magnet,
  String? displayTitle,
  SeriesFolderPlanBuilder seriesFolderPlanBuilder =
      ReleaseDownloadButton.defaultSeriesFolderPlanBuilder,
}) => _runDownloadAction(context, () async {
  final allowed = await PermissionService.requestStoragePermissions();
  if (!context.mounted) return;
  if (!allowed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Allow folder access to set up this download.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: PermissionService.openSettings,
        ),
      ),
    );
    return;
  }
  await _startReleaseDownload(
    context,
    ref,
    target: target,
    torrentKey: torrentKey,
    magnet: magnet,
    displayTitle: displayTitle,
    chooseNewFolder: true,
    seriesFolderPlanBuilder: seriesFolderPlanBuilder,
  );
});

Future<void> _startReleaseDownload(
  BuildContext context,
  WidgetRef ref, {
  required ShowCatalogTarget target,
  required String torrentKey,
  required String magnet,
  required SeriesFolderPlanBuilder seriesFolderPlanBuilder,
  String? displayTitle,
  bool redownload = false,
  bool chooseNewFolder = false,
}) async {
  final seriesDownloadPath = await _resolveSeriesDownloadPath(
    context,
    ref,
    target,
    displayTitle: displayTitle,
    chooseNewFolder: chooseNewFolder,
    seriesFolderPlanBuilder: seriesFolderPlanBuilder,
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
        magnet,
        seriesDownloadPath,
        redownload: redownload,
      );

  if (!context.mounted || redownload) {
    return;
  }
  final current = ref.read(foregroundTorrentForShowProvider(torrentKey));
  if (current.errorMessage != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(current.errorMessage!)));
  } else if (current.torrentId != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download started to: $seriesDownloadPath')),
    );
  }
}

Future<String?> _resolveSeriesDownloadPath(
  BuildContext context,
  WidgetRef ref,
  ShowCatalogTarget target, {
  bool chooseNewFolder = false,
  String? displayTitle,
  SeriesFolderPlanBuilder seriesFolderPlanBuilder =
      ReleaseDownloadButton.defaultSeriesFolderPlanBuilder,
}) async {
  final (currentMappings, isAutoGenEnabled, currentBasePath) = await (
    ref.read(seriesFolderMappingProvider.future),
    ref.read(autoGenerateFoldersProvider.future),
    ref.read(downloadBasePathProvider.future),
  ).wait;
  if (!context.mounted) return null;
  final seriesSpecificPath = currentMappings[target.title];
  if (!chooseNewFolder &&
      seriesSpecificPath != null &&
      seriesSpecificPath.isNotEmpty) {
    return seriesSpecificPath;
  }
  final title =
      displayTitle ??
      ref.read(cachedShowCatalogMatchProvider(target))?.entry?.displayTitle ??
      target.title;
  String? path;
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

    final textGenerator = ref.read(onDeviceTextGeneratorProvider);
    final plan = await runWithDownloadPreparationDialog(
      context: context,
      action: () => seriesFolderPlanBuilder(
        showTitle: target.title,
        basePath: currentBasePath,
        textGenerator: textGenerator,
      ),
    );

    if (!context.mounted) {
      return null;
    }

    path = plan.suggestedPath;
    if (chooseNewFolder || plan.usedAi) {
      path = await showSeriesFolderConfirmationDialog(
        context: context,
        showTitle: title,
        basePath: currentBasePath,
        plan: plan,
      );
    }
  } else {
    path = await FilePicker.getDirectoryPath(
      initialDirectory: chooseNewFolder ? currentBasePath : null,
      dialogTitle: 'Select download folder for "$title"',
    );
    if (context.mounted && (path == null || path.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No folder selected. Download cancelled.'),
        ),
      );
    }
  }

  if (path == null || path.isEmpty || !context.mounted) return null;
  if (chooseNewFolder) {
    final error = await PermissionService.validateDownloadDirectory(path);
    if (!context.mounted) return null;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return null;
    }
  } else if (isAutoGenEnabled) {
    await Directory(path).create(recursive: true);
    if (!context.mounted) return null;
  }
  await ref
      .read(seriesFolderMappingProvider.notifier)
      .setFolder(target.title, path);
  return path;
}
