import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/tenrai_models.dart';

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
