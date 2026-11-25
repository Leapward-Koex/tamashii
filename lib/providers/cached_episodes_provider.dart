// lib/providers/cached_episodes_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/filter_provider.dart';

part 'cached_episodes_provider.g.dart';

typedef _EpisodeKey = (String show, String episode);

_EpisodeKey _episodeKey(ShowInfo episode) => (episode.show, episode.episode);

List<ShowInfo> _decodeCachedEpisodes(List<String> cachedData) => [
  for (final row in cachedData)
    ShowInfo.fromJson(json.decode(row) as Map<String, dynamic>),
];

Set<String> _homePageBookmarkNames(Iterable<BookmarkedShowInfo> bookmarks) =>
    bookmarks
        .where((bookmark) => bookmark.showsOnHomePage)
        .map((bookmark) => bookmark.showName)
        .toSet();

List<ShowInfo> _newestFirst(Iterable<ShowInfo> episodes) =>
    episodes.toList()..sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

bool _sameEpisodeMetadata(ShowInfo cached, ShowInfo incoming) {
  if (identical(cached, incoming)) {
    return true;
  }
  if (cached.imageUrl != incoming.imageUrl ||
      cached.page != incoming.page ||
      !cached.releaseDate.isAtSameMomentAs(incoming.releaseDate) ||
      cached.timeLabel != incoming.timeLabel ||
      cached.xdcc != incoming.xdcc ||
      cached.downloads.length != incoming.downloads.length) {
    return false;
  }
  for (var index = 0; index < cached.downloads.length; index++) {
    final previous = cached.downloads[index];
    final next = incoming.downloads[index];
    if (previous.resolution != next.resolution ||
        previous.magnet != next.magnet) {
      return false;
    }
  }
  return true;
}

/// Manages cached episodes from bookmarked series
@riverpod
class CachedEpisodesNotifier extends _$CachedEpisodesNotifier {
  static const String _storageKey = 'cached_episodes';
  static const int _backgroundDecodeThreshold = 256;
  Future<void> _pendingUpdate = Future<void>.value();

  @override
  Future<List<ShowInfo>> build() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    try {
      final cachedData = preferences.getStringList(_storageKey);
      if (cachedData == null) {
        return <ShowInfo>[];
      }
      if (cachedData.length >= _backgroundDecodeThreshold) {
        return await compute(
          _decodeCachedEpisodes,
          cachedData,
          debugLabel: 'Decode saved episodes',
        );
      }
      return _decodeCachedEpisodes(cachedData);
    } catch (_) {
      await preferences.remove(_storageKey);
      return <ShowInfo>[];
    }
  }

  /// Cache new episodes from bookmarked series.
  Future<void> cacheNewBookmarkedEpisodes(List<ShowInfo> apiEpisodes) {
    if (apiEpisodes.isEmpty) {
      return Future<void>.value();
    }

    return _update((currentCached) async {
      final bookmarks = await ref.read(bookmarkedSeriesProvider.future);
      final bookmarkedNames = _homePageBookmarkNames(bookmarks);
      final candidates = apiEpisodes
          .where((episode) => bookmarkedNames.contains(episode.show))
          .toList(growable: false);
      final newKeys = candidates.map(_episodeKey).toSet();
      if (newKeys.isEmpty) {
        return null;
      }
      for (final episode in currentCached) {
        newKeys.remove(_episodeKey(episode));
        if (newKeys.isEmpty) {
          return null;
        }
      }
      return _mergeEpisodes(
        currentCached,
        candidates.where((episode) => newKeys.contains(_episodeKey(episode))),
      );
    });
  }

  /// Manually cache episodes (for initial sync or manual operations).
  Future<void> cacheEpisodes(List<ShowInfo> episodes) =>
      _update((currentCached) => _mergeEpisodes(currentCached, episodes));

  List<ShowInfo>? _mergeEpisodes(
    List<ShowInfo> currentCached,
    Iterable<ShowInfo> episodes,
  ) {
    final episodeMap = {
      for (final episode in currentCached) _episodeKey(episode): episode,
    };
    final replacements = {
      for (final episode in episodes) _episodeKey(episode): episode,
    };
    if (episodeMap.length == currentCached.length &&
        replacements.entries.every((entry) {
          final previous = episodeMap[entry.key];
          return previous != null &&
              _sameEpisodeMetadata(previous, entry.value);
        })) {
      return null;
    }
    episodeMap.addAll(replacements);
    return _newestFirst(episodeMap.values);
  }

  /// Remove episodes of a series from cache (when unbookmarking).
  Future<void> removeSeriesFromCache(String seriesName) {
    return _update((currentCached) {
      final filtered = currentCached
          .where((episode) => episode.show != seriesName)
          .toList();
      return filtered.length == currentCached.length ? null : filtered;
    });
  }

  /// Clean up old episodes (keep only last 100 episodes per series).
  Future<void> cleanupOldEpisodes() {
    return _update((currentCached) {
      final episodesByShow = <String, List<ShowInfo>>{};
      for (final episode in currentCached) {
        episodesByShow.putIfAbsent(episode.show, () => []).add(episode);
      }
      final cleanedEpisodes = <ShowInfo>[];
      for (final episodes in episodesByShow.values) {
        episodes.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
        cleanedEpisodes.addAll(episodes.take(100));
      }
      cleanedEpisodes.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
      return cleanedEpisodes;
    });
  }

  /// Clear all cached episodes.
  Future<void> clearCache() => _update((_) => const <ShowInfo>[], clear: true);

  Future<void> _update(
    FutureOr<List<ShowInfo>?> Function(List<ShowInfo>) update, {
    bool clear = false,
  }) {
    final link = ref.keepAlive();
    final result = _pendingUpdate
        .then((_) async {
          if (state.isLoading) {
            await future;
          }
          final updated = await update(state.requireValue);
          if (updated == null) {
            return;
          }

          state = AsyncValue.data(updated);
          final preferences = await SharedPreferences.getInstance();
          if (clear) {
            await preferences.remove(_storageKey);
            return;
          }
          final uniqueEpisodes = {
            for (final episode in updated) _episodeKey(episode): episode,
          };
          final jsonStrings = uniqueEpisodes.values
              .map((episode) => json.encode(episode.toJson()))
              .toList();
          await preferences.setStringList(_storageKey, jsonStrings);
        })
        .whenComplete(link.close);
    _pendingUpdate = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

/// Combined provider that merges API data with cached episodes
@riverpod
Future<List<ShowInfo>> combinedEpisodes(Ref ref, String searchTerm) async {
  final apiEpisodes = searchTerm.isEmpty
      ? ref.watch(latestShowsProvider.future)
      : ref.watch(searchShowsProvider(searchTerm).future);
  final sources = searchTerm.isEmpty
      ? await Future.wait([
          ref.watch(cachedEpisodesProvider.future),
          apiEpisodes,
        ])
      : [await apiEpisodes];
  final episodeMap = {
    for (final episodes in sources)
      for (final episode in episodes) _episodeKey(episode): episode,
  };
  return _newestFirst(episodeMap.values);
}

/// Read locally available episodes while an unfiltered query awaits the feed.
List<ShowInfo>? watchCachedEpisodeFeedPreview(Ref ref) {
  final filter = ref.watch(showFilterProvider).value;
  final cachedEpisodes = ref.watch(cachedEpisodesProvider).value;
  if (filter == null || cachedEpisodes == null || cachedEpisodes.isEmpty) {
    return null;
  }
  if (filter == ShowFilter.saved) {
    final bookmarks = ref.watch(bookmarkedSeriesProvider).value;
    if (bookmarks == null) {
      return null;
    }
    final bookmarkedNames = _homePageBookmarkNames(bookmarks);
    return _newestFirst(
      cachedEpisodes.where((episode) => bookmarkedNames.contains(episode.show)),
    );
  }
  return _newestFirst(cachedEpisodes);
}

/// Filtered combined episodes provider (replaces the existing filteredShows)
@riverpod
Future<List<ShowInfo>> filteredCombinedEpisodes(
  Ref ref,
  String searchTerm,
) async {
  // Get the current filter
  final filterAsync = ref.watch(showFilterProvider);
  final filter = filterAsync.value ?? ShowFilter.all;

  // For saved filter, use only bookmarked series
  if (filter == ShowFilter.saved) {
    final bookmarkedSeriesAsync = ref.watch(bookmarkedSeriesProvider);

    // If bookmarks are still loading, return empty list
    if (bookmarkedSeriesAsync.isLoading) {
      return <ShowInfo>[];
    }

    // Get bookmarked series
    final bookmarkedSeries =
        bookmarkedSeriesAsync.value ?? <BookmarkedShowInfo>[];

    final bookmarkedNames = _homePageBookmarkNames(bookmarkedSeries);
    if (bookmarkedNames.isEmpty) {
      return <ShowInfo>[];
    }

    // Get combined episodes and filter by bookmarked series
    final combinedEpisodes = await ref.watch(
      combinedEpisodesProvider(searchTerm).future,
    );
    return combinedEpisodes
        .where((episode) => bookmarkedNames.contains(episode.show))
        .toList();
  }

  // For "all" filter, get combined episodes directly
  return await ref.watch(combinedEpisodesProvider(searchTerm).future);
}
