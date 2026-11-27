// lib/providers/downloaded_torrents_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/services/downloaded_episode_store.dart';

part 'downloaded_torrents_provider.g.dart';

/// Stores a set of torrent keys that have completed downloading.
@riverpod
class DownloadedTorrentsNotifier extends _$DownloadedTorrentsNotifier {
  @override
  Future<Set<String>> build() => readDownloadedTorrentKeys();

  Future<void> addDownloaded(String torrentKey) async {
    await writeDownloadedTorrentKey(torrentKey, true);
    if (ref.mounted) state = AsyncValue.data({...?state.value, torrentKey});
  }

  Future<void> removeDownloaded(String torrentKey) async {
    await writeDownloadedTorrentKey(torrentKey, false);
    if (ref.mounted) {
      state = AsyncValue.data({...?state.value}..remove(torrentKey));
    }
  }

  /// Remove all torrent keys that correspond to [showId] prefix.
  Future<void> removeByShow(String showId) async {
    final current = await readDownloadedTorrentKeys();
    final removed = current.where((k) => k.startsWith('$showId-')).toSet();
    await Future.wait(removed.map((k) => writeDownloadedTorrentKey(k, false)));
    if (ref.mounted) {
      state = AsyncValue.data({...?state.value}..removeAll(removed));
    }
  }
}
