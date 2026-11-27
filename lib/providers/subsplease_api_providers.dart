// lib/providers/subsplease_api_providers.dart

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/models/show_models.dart';

part 'subsplease_api_providers.g.dart';

// Keep complete responses available on the first frame of a return visit.
void _cacheShowDetails(Ref ref) {
  if (!ref.mounted) return;
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);
}

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
  final releases = await api.getShowsFromSearch(searchTerm);
  if (releases.isNotEmpty) _cacheShowDetails(ref);
  return releases;
}

@riverpod
Future<List<ShowInfo>> filteredShows(Ref ref, String searchTerm) async {
  final combined = filteredCombinedEpisodesProvider(searchTerm);
  if (searchTerm.isEmpty) {
    final combinedState = ref.watch(combined);
    if ((combinedState.isLoading || combinedState.hasError) &&
        (combinedState.value?.isEmpty ?? true)) {
      final preview = watchCachedEpisodeFeedPreview(ref);
      if (preview != null && preview.isNotEmpty) {
        return preview;
      }
    }
  }
  return ref.watch(combined.future);
}

@riverpod
Future<String?> showSynopsis(Ref ref, String showPage) async {
  final api = ref.watch(subsPleaseApiProvider);
  final synopsis = await api.getShowSynopsis(showPage);
  if (synopsis != null && synopsis.trim().isNotEmpty) _cacheShowDetails(ref);
  return synopsis;
}
