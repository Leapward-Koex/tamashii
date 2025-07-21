// lib/providers/subsplease_api_providers.dart

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import '../models/show_models.dart';

part 'subsplease_api_providers.g.dart';

@riverpod
SubsPleaseApi subsPleaseApi(Ref ref) {
  return SubsPleaseApi();
}

@riverpod
Future<List<ShowInfo>> latestShows(Ref ref) async {
  final api = ref.watch(subsPleaseApiProvider);
  return await api.getLatestShowList();
}

@riverpod
Future<List<ShowInfo>> searchShows(Ref ref, String searchTerm) async {
  final api = ref.watch(subsPleaseApiProvider);
  return await api.getShowsFromSearch(searchTerm);
}

@riverpod
Future<List<ShowInfo>> filteredShows(Ref ref, String searchTerm) async {
  // Get the current filter
  final filterAsync = ref.watch(showFilterNotifierProvider);
  final filter = filterAsync.value ?? ShowFilter.all;
  
  // For saved filter, check if bookmarks are still loading
  if (filter == ShowFilter.saved) {
    final bookmarkedSeriesAsync = ref.watch(bookmarkedSeriesNotifierProvider);
    
    // If bookmarks are still loading, return empty list to avoid hanging
    if (bookmarkedSeriesAsync.isLoading) {
      return <ShowInfo>[];
    }
    
    // Get bookmarked series
    final bookmarkedSeries = bookmarkedSeriesAsync.value ?? <String>[];
    
    // If no bookmarks, return empty list
    if (bookmarkedSeries.isEmpty) {
      return <ShowInfo>[];
    }
    
    // Get API data and filter by bookmarked series
    final List<ShowInfo> shows;
    if (searchTerm.isEmpty) {
      shows = await ref.watch(latestShowsProvider.future);
    } else {
      shows = await ref.watch(searchShowsProvider(searchTerm).future);
    }
    
    return shows.where((show) => bookmarkedSeries.contains(show.show)).toList();
  }
  
  // For "all" filter, get API data directly
  final List<ShowInfo> shows;
  if (searchTerm.isEmpty) {
    shows = await ref.watch(latestShowsProvider.future);
  } else {
    shows = await ref.watch(searchShowsProvider(searchTerm).future);
  }
  
  return shows;
}

@riverpod
Future<String?> showSynopsis(Ref ref, String showPage) async {
  final api = ref.watch(subsPleaseApiProvider);
  return await api.getShowSynopsis(showPage);
}
