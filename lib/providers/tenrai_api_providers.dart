import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/services/tenrai_poster_matcher.dart';
import 'package:tamashii/services/show_catalog_matcher.dart';

part 'tenrai_api_providers.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
TenraiApi tenraiApi(Ref ref) {
  final api = TenraiApi();
  ref.onDispose(api.close);
  return api;
}

/// Retain successful searches across navigation and discard transient failures.
@Riverpod(retry: _noRetry)
Future<List<TenraiAnimeSearchResult>> searchTenraiShows(
  Ref ref,
  String query,
) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return const <TenraiAnimeSearchResult>[];
  }

  final results = await ref.watch(tenraiApiProvider).searchAnime(trimmedQuery);
  if (ref.mounted) {
    ref.keepAlive();
  }
  return results;
}

@Riverpod(retry: _noRetry)
Future<TenraiAnimeSearchResult?> catalogEntryById(Ref ref, int malId) async {
  final entry = await ref.watch(tenraiApiProvider).getAnimeById(malId);
  if (ref.mounted && entry != null) ref.keepAlive();
  return entry;
}

@Riverpod(retry: _noRetry)
Future<List<TenraiAnimeSearchResult>> relatedTenraiShows(
  Ref ref,
  int malId,
  String title,
) async {
  final api = ref.watch(tenraiApiProvider);
  final related = await api.relatedAnime(malId);
  if (related.any((entry) => entry.malId != malId)) return related;
  // Some titles have no catalogued relations. A family search can still
  // surface a different season or a similarly named series for correction.
  return api.searchAnime(catalogSeriesQuery(title));
}

@Riverpod(retry: _noRetry)
Future<String?> featuredTenraiPoster(Ref ref, String showTitle) async {
  final results = await ref.watch(
    searchTenraiShowsProvider(showTitle.trim()).future,
  );
  final url = matchTenraiPoster(showTitle, results)?.largeImageUrl?.trim();
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return url;
}
