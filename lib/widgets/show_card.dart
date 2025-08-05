// lib/widgets/show_card.dart

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart'; // Ensure FilePicker is imported

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart'; // Added
import 'package:tamashii/providers/foreground_torrent_provider.dart'; // Added for background service
import 'package:simple_torrent/simple_torrent.dart'; // For TorrentState

import '../models/show_models.dart';
import '../providers/bookmarked_series_provider.dart';
import '../providers/subsplease_api_providers.dart';

/// A card widget displaying a show's poster, title, episode, torrent progress,
/// upload / download stats, and action buttons (download + bookmark).
class ShowCard extends HookConsumerWidget {
  final ShowInfo show;
  const ShowCard({super.key, required this.show});

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final double kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final double mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final double gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  Future<String?> _determineDownloadPath({
    required BuildContext context,
    required WidgetRef ref,
    required ShowInfo showInfo,
    required Map<String, String> currentMappings,
    required bool isAutoGenEnabled,
    required String currentBasePath,
    required SeriesFolderMapping seriesMappingNotifier,
  }) async {
    final seriesSpecificPath = currentMappings[showInfo.show];

    if (seriesSpecificPath != null && seriesSpecificPath.isNotEmpty) {
      return seriesSpecificPath;
    }

    if (isAutoGenEnabled) {
      if (currentBasePath.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Base download folder not set. Please configure it in Settings.')));
        return null;
      }
      final path = p.join(currentBasePath, showInfo.show.replaceAll(RegExp(r'[^\w\s-]+'), '_')); // Sanitize folder name
      try {
        await Directory(path).create(recursive: true);
        await seriesMappingNotifier.setFolder(showInfo.show, path);
        return path;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating folder: $e')));
        return null;
      }
    } else {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select download folder for "${showInfo.show}"');
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        await seriesMappingNotifier.setFolder(showInfo.show, selectedDirectory);
        return selectedDirectory;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No folder selected. Download cancelled.')));
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsPleaseApiProvider);
    final List<String> bookmarks = ref.watch(bookmarkedSeriesNotifierProvider).valueOrNull ?? <String>[];
    final bool isBookmarked = bookmarks.contains(show.show);
    final bookmarkedNotifier = ref.read(bookmarkedSeriesNotifierProvider.notifier);
    final seriesMappingSettings = ref.watch(seriesFolderMappingProvider);
    final autoGenSettings = ref.watch(autoGenerateFoldersProvider);
    final basePathSettings = ref.watch(downloadBasePathProvider);
    final seriesMappingNotifier = ref.read(seriesFolderMappingProvider.notifier);

    // Construct a unique key for the torrent download based on show and episode
    final String torrentKey = "${show.show}-${show.episode}";

    // Watch the torrent download state for this specific show and episode
    final torrentDownloadState = ref.watch(foregroundTorrentForShowProvider(torrentKey));

    // Derived values from stats
    final double progressFraction = torrentDownloadState.progressFraction;
    final int downloadRate = torrentDownloadState.downloadRate;
    final int uploadRate = torrentDownloadState.uploadRate;
    final bool isLoadingTorrent = torrentDownloadState.isLoading;
    final bool isDownloading = torrentDownloadState.isDownloading;

    // Resolve relative image URL
    final String imageUrl = show.imageUrl.startsWith('http') ? show.imageUrl : '${api.baseUrl}${show.imageUrl}';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Poster - Fixed width to maintain aspect ratio
            SizedBox(
              width: 120, // Maintains roughly 2:3 aspect ratio (120x180)
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox(
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  child: Center(child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            ),
            // Content area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Title & episode
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          show.show, 
                          style: Theme.of(context).textTheme.titleMedium, 
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Episode: ${show.episode}', 
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // Progress bar (visible only while downloading)
                  if (isDownloading && progressFraction < 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(value: progressFraction, minHeight: 4),
                    ),
                  // Enhanced torrent info display
                  if (torrentDownloadState.torrentId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Torrent state and phase
                          Row(
                            children: [
                              Icon(
                                _getTorrentStateIcon(torrentDownloadState.currentState),
                                size: 16,
                                color: _getTorrentStateColor(torrentDownloadState.currentState),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                torrentDownloadState.currentState.name.toUpperCase(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getTorrentStateColor(torrentDownloadState.currentState),
                                ),
                              ),
                              if (torrentDownloadState.stats?.phase != null) ...[
                                const SizedBox(width: 8),
                                Text('• ${torrentDownloadState.stats!.phase}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // File information from metadata
                          if (torrentDownloadState.metadata != null) ...[
                            Text(
                              'File: ${torrentDownloadState.displayName}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Size: ${torrentDownloadState.formattedSize} • Files: ${torrentDownloadState.metadata!.fileCount}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          // Download/upload speeds and peer info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('↓ ${_formatBytes(downloadRate)}/s', style: Theme.of(context).textTheme.bodySmall),
                              Text('↑ ${_formatBytes(uploadRate)}/s', style: Theme.of(context).textTheme.bodySmall),
                              if (torrentDownloadState.stats != null)
                                Text(
                                  'S:${torrentDownloadState.stats!.seeds} P:${torrentDownloadState.stats!.peers}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Spacer to push action buttons to bottom
                  const Spacer(),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        IconButton(
                          icon:
                              isLoadingTorrent
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(isDownloading ? Icons.pause_circle_filled_rounded : Icons.download_rounded),
                          onPressed:
                              isLoadingTorrent
                                  ? null
                                  : () async {
                                    if (isDownloading) {
                                      await ref.read(torrentManagerProvider.notifier).pauseDownload(torrentKey);
                                      return;
                                    }
                                    if (torrentDownloadState.torrentId != null && !isDownloading && !torrentDownloadState.isCompleted) {
                                      await ref.read(torrentManagerProvider.notifier).resumeDownload(torrentKey);
                                      return;
                                    }
                                    if (torrentDownloadState.isCompleted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download completed.')));
                                      return;
                                    }

                                    final String? seriesDownloadPath = await _determineDownloadPath(
                                      context: context,
                                      ref: ref,
                                      showInfo: show,
                                      currentMappings: seriesMappingSettings.valueOrNull ?? <String, String>{},
                                      isAutoGenEnabled: autoGenSettings.valueOrNull ?? true, // Default to true
                                      currentBasePath: basePathSettings.valueOrNull ?? '',
                                      seriesMappingNotifier: seriesMappingNotifier,
                                    );

                                    if (seriesDownloadPath == null || seriesDownloadPath.isEmpty) {
                                      return;
                                    }

                                    if (show.downloads.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No download links available.')));
                                      return;
                                    }
                                    final best = show.downloads.reduce((a, b) {
                                      final int aRes = int.parse(a.resolution.toJson());
                                      final int bRes = int.parse(b.resolution.toJson());
                                      return aRes >= bRes ? a : b;
                                    });

                                    await ref.read(foregroundTorrentManagerProvider.notifier).startDownload(torrentKey, best.magnet, seriesDownloadPath);
                                    if (torrentDownloadState.errorMessage != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(SnackBar(content: Text('Error: ${torrentDownloadState.errorMessage}')));
                                    } else if (torrentDownloadState.torrentId != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(SnackBar(content: Text('Download started to: $seriesDownloadPath')));
                                    }
                                  },
                        ),
                        IconButton(
                          icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                          onPressed: () async {
                            if (isBookmarked) {
                              // Remove from bookmarks
                              await bookmarkedNotifier.remove(show.show);
                            } else {
                              // Add to bookmarks
                              await bookmarkedNotifier.add(show.show);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for torrent state visualization
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
