// lib/providers/subsplease_api_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/models/show_models.dart';

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

// Updated to use the new combined provider instead of raw API data
@riverpod
Future<List<ShowInfo>> filteredShows(Ref ref, String searchTerm) async {
  return await ref.watch(filteredCombinedEpisodesProvider(searchTerm).future);
}

@riverpod
Future<String?> showSynopsis(Ref ref, String showPage) async {
  final api = ref.watch(subsPleaseApiProvider);
  return await api.getShowSynopsis(showPage);
}
