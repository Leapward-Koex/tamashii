// lib/widgets/show_card.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:simple_torrent/simple_torrent.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsPleaseApiProvider);
    final List<String> bookmarks = ref.watch(bookmarkedSeriesNotifierProvider).valueOrNull ?? <String>[];
    final bool isBookmarked = bookmarks.contains(show.show);
    final bookmarkedNotifier = ref.read(bookmarkedSeriesNotifierProvider.notifier);

    // --- Torrent state (hook-managed) -------------------------------------------------
    final torrentIdState = useState<int?>(null);
    final torrentStatsState = useState<TorrentStats?>(null);
    final StreamSubscription<TorrentStats>? statsSub = useMemoized<StreamSubscription<TorrentStats>?>(() {
      if (torrentIdState.value == null) {
        return null;
      }
      // listen only to updates that match our torrent id
      return SimpleTorrent.statsStream.listen((TorrentStats s) {
        if (s.id == torrentIdState.value) {
          torrentStatsState.value = s;
        }
      });
    }, [torrentIdState.value]);

    // Clean up subscription on unmount / id change
    useEffect(() {
      return () {
        statsSub?.cancel();
      };
    }, [statsSub]);

    // Derived values from stats
    final double progressFraction = (torrentStatsState.value?.progress ?? 0) / 100.0;
    final int downloadRate = torrentStatsState.value?.downloadRate ?? 0;
    final int uploadRate = torrentStatsState.value?.uploadRate ?? 0;

    // Resolve relative image URL
    final String imageUrl = show.imageUrl.startsWith('http') ? show.imageUrl : '${api.baseUrl}${show.imageUrl}';

    // Default download path (replace with setting when available)
    const String downloadPath = '/storage/emulated/0/Download';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Poster
          CachedNetworkImage(
            imageUrl: imageUrl,
            height: 180,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
            errorWidget: (context, url, error) => const SizedBox(height: 180, child: Center(child: Icon(Icons.broken_image))),
          ),
          // Title & episode
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(show.show, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Episode: ${show.episode}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          // Progress bar (visible only while downloading)
          if (progressFraction > 0 && progressFraction < 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(value: progressFraction, minHeight: 4),
            ),
          // Stats row
          if (torrentIdState.value != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('↓ ${_formatBytes(downloadRate)}/s', style: Theme.of(context).textTheme.bodySmall),
                  Text('↑ ${_formatBytes(uploadRate)}/s', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () async {
                    if (torrentIdState.value != null) {
                      // Already downloading
                      return;
                    }
                    if (show.downloads.isEmpty) {
                      return;
                    }
                    // Highest resolution magnet
                    final best = show.downloads.reduce((a, b) {
                      final int aRes = int.parse(a.resolution.toJson());
                      final int bRes = int.parse(b.resolution.toJson());
                      return aRes >= bRes ? a : b;
                    });
                    try {
                      final int id = await SimpleTorrent.start(magnet: best.magnet, path: downloadPath);
                      torrentIdState.value = id;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start torrent: $e')));
                    }
                  },
                ),
                IconButton(
                  icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () {
                    if (isBookmarked) {
                      bookmarkedNotifier.remove(show.show);
                    } else {
                      bookmarkedNotifier.add(show.show);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
