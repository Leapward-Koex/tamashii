// lib/providers/cached_episodes_provider.dart

import 'dart:convert';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/show_models.dart';
import 'bookmarked_series_provider.dart';
import 'subsplease_api_providers.dart';
import 'filter_provider.dart';

part 'cached_episodes_provider.g.dart';

/// Manages cached episodes from bookmarked series
@riverpod
class CachedEpisodesNotifier extends _$CachedEpisodesNotifier {
  static const String _storageKey = 'cached_episodes';

  @override
  Future<List<ShowInfo>> build() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    
    try {
      // First check if the key exists and what type it is
      final keys = preferences.getKeys();
      if (!keys.contains(_storageKey)) {
        return <ShowInfo>[];
      }
      
      // Try to get as string list first
      final cachedData = preferences.getStringList(_storageKey);
      
      if (cachedData == null) {
        // If getStringList returns null, the data might be stored as a different type
        // Clear it and start fresh
        await preferences.remove(_storageKey);
        return <ShowInfo>[];
      }

      return cachedData
          .map((jsonString) => ShowInfo.fromJson(json.decode(jsonString) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If there's any error (including type casting), clear the cache and start fresh
      await preferences.remove(_storageKey);
      return <ShowInfo>[];
    }
  }

  /// Cache new episodes from bookmarked series
  Future<void> cacheNewBookmarkedEpisodes(List<ShowInfo> apiEpisodes) async {
    final bookmarkedSeries = await ref.read(bookmarkedSeriesNotifierProvider.future);
    
    // Get current cached episodes, defaulting to empty list if null
    final stateValue = state.value;
    final currentCached = stateValue ?? <ShowInfo>[];
    
    // Find new episodes from bookmarked series
    final newBookmarkedEpisodes = apiEpisodes.where((episode) => 
        bookmarkedSeries.contains(episode.show) &&
        !currentCached.any((cached) => 
            cached.show == episode.show && 
            cached.episode == episode.episode
        )
    ).toList();

    if (newBookmarkedEpisodes.isNotEmpty) {
      await _addEpisodesToCache(newBookmarkedEpisodes);
    }
  }

  /// Add episodes to cache
  Future<void> _addEpisodesToCache(List<ShowInfo> episodes) async {
    final stateValue = state.value;
    final currentCached = stateValue ?? <ShowInfo>[];
    final updatedCache = [...currentCached, ...episodes];
    
    // Sort by release date (newest first)
    updatedCache.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    
    // Update state
    state = AsyncValue.data(updatedCache);
    
    // Save to storage
    await _saveToStorage(updatedCache);
  }

  /// Remove episodes of a series from cache (when unbookmarking)
  Future<void> removeSeriesFromCache(String seriesName) async {
    final stateValue = state.value;
    final currentCached = stateValue ?? <ShowInfo>[];
    final filteredCache = currentCached.where((episode) => episode.show != seriesName).toList();
    
    state = AsyncValue.data(filteredCache);
    await _saveToStorage(filteredCache);
  }

  /// Clean up old episodes (keep only last 100 episodes per series)
  Future<void> cleanupOldEpisodes() async {
    final stateValue = state.value;
    final currentCached = stateValue ?? <ShowInfo>[];
    final Map<String, List<ShowInfo>> episodesByShow = {};
    
    // Group episodes by show
    for (final episode in currentCached) {
      episodesByShow.putIfAbsent(episode.show, () => []).add(episode);
    }
    
    // Keep only the latest 100 episodes per show
    final cleanedEpisodes = <ShowInfo>[];
    for (final episodes in episodesByShow.values) {
      episodes.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
      cleanedEpisodes.addAll(episodes.take(100));
    }
    
    // Sort all episodes by release date
    cleanedEpisodes.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    
    state = AsyncValue.data(cleanedEpisodes);
    await _saveToStorage(cleanedEpisodes);
  }

  /// Save episodes to storage
  Future<void> _saveToStorage(List<ShowInfo> episodes) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    
    // Remove duplicates based on show name and episode
    final Map<String, ShowInfo> uniqueEpisodes = {};
    for (final episode in episodes) {
      final key = '${episode.show}-${episode.episode}';
      uniqueEpisodes[key] = episode;
    }
    
    final List<String> jsonStrings = uniqueEpisodes.values
        .map((episode) => json.encode(episode.toJson()))
        .toList();
    
    await preferences.setStringList(_storageKey, jsonStrings);
  }

  /// Manually cache episodes (for initial sync or manual operations)
  Future<void> cacheEpisodes(List<ShowInfo> episodes) async {
    await _addEpisodesToCache(episodes);
  }

  /// Clear all cached episodes
  Future<void> clearCache() async {
    state = const AsyncValue.data(<ShowInfo>[]);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}

/// Combined provider that merges API data with cached episodes
@riverpod
Future<List<ShowInfo>> combinedEpisodes(Ref ref, String searchTerm) async {
  final cachedEpisodes = await ref.watch(cachedEpisodesNotifierProvider.future);
  
  // Get API data
  final List<ShowInfo> apiEpisodes;
  if (searchTerm.isEmpty) {
    apiEpisodes = await ref.watch(latestShowsProvider.future);
  } else {
    apiEpisodes = await ref.watch(searchShowsProvider(searchTerm).future);
  }
  
  // Combine cached and API episodes, removing duplicates
  final Map<String, ShowInfo> episodeMap = {};
  
  // Add cached episodes first
  for (final episode in cachedEpisodes) {
    final key = '${episode.show}-${episode.episode}';
    episodeMap[key] = episode;
  }
  
  // Add API episodes (will override cached if same episode)
  for (final episode in apiEpisodes) {
    final key = '${episode.show}-${episode.episode}';
    episodeMap[key] = episode;
  }
  
  // Convert back to list and sort by release date
  final combinedList = episodeMap.values.toList();
  combinedList.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
  
  return combinedList;
}

/// Filtered combined episodes provider (replaces the existing filteredShows)
@riverpod
Future<List<ShowInfo>> filteredCombinedEpisodes(Ref ref, String searchTerm) async {
  // Get the current filter
  final filterAsync = ref.watch(showFilterNotifierProvider);
  final filter = filterAsync.value ?? ShowFilter.all;
  
  // For saved filter, use only bookmarked series
  if (filter == ShowFilter.saved) {
    final bookmarkedSeriesAsync = ref.watch(bookmarkedSeriesNotifierProvider);
    
    // If bookmarks are still loading, return empty list
    if (bookmarkedSeriesAsync.isLoading) {
      return <ShowInfo>[];
    }
    
    // Get bookmarked series
    final bookmarkedSeries = bookmarkedSeriesAsync.value ?? <String>[];
    
    // If no bookmarks, return empty list
    if (bookmarkedSeries.isEmpty) {
      return <ShowInfo>[];
    }
    
    // Get combined episodes and filter by bookmarked series
    final combinedEpisodes = await ref.watch(combinedEpisodesProvider(searchTerm).future);
    return combinedEpisodes.where((episode) => bookmarkedSeries.contains(episode.show)).toList();
  }
  
  // For "all" filter, get combined episodes directly
  return await ref.watch(combinedEpisodesProvider(searchTerm).future);
}
