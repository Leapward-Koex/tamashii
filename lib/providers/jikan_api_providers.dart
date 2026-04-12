import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/jikan_api.dart';
import 'package:tamashii/models/jikan_models.dart';

part 'jikan_api_providers.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
JikanApi jikanApi(Ref ref) {
  return JikanApi();
}

/// Cache Jikan search results per query so rebuilds/navigation do not re-hit
/// the API unless the query actually changes.
@Riverpod(keepAlive: true, retry: _noRetry)
Future<List<JikanAnimeSearchResult>> searchJikanShows(
  Ref ref,
  String query,
) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return const <JikanAnimeSearchResult>[];
  }

  final api = ref.read(jikanApiProvider);
  return api.searchAnime(trimmedQuery);
}
