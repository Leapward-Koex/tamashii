// lib/providers/subsplease_api_providers.dart

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/api_client.dart';
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
Future<String?> showSynopsis(Ref ref, String showPage) async {
  final api = ref.watch(subsPleaseApiProvider);
  return await api.getShowSynopsis(showPage);
}
