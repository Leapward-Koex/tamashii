import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tamashii/models/jikan_models.dart';

class JikanApiException implements Exception {
  const JikanApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JikanApi {
  JikanApi({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String _host = 'api.jikan.moe';

  final http.Client _httpClient;

  Future<List<JikanAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const <JikanAnimeSearchResult>[];
    }

    final uri = Uri.https(_host, '/v4/anime', <String, String>{
      'q': trimmedQuery,
      'limit': '$limit',
    });

    late final http.Response response;
    try {
      response = await _httpClient.get(uri);
    } catch (_) {
      throw const JikanApiException(
        'Unable to reach Jikan right now. Please try again.',
      );
    }

    if (response.statusCode != 200) {
      throw JikanApiException(_errorMessageForResponse(response));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? const <dynamic>[];
    return data
        .map(
          (entry) =>
              JikanAnimeSearchResult.fromJson(entry as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  String _errorMessageForResponse(http.Response response) {
    String? apiMessage;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      apiMessage = json['message'] as String?;
    } catch (_) {
      apiMessage = null;
    }

    if (response.statusCode == 429) {
      return 'Jikan is rate limiting requests right now. Please try again shortly.';
    }

    if (apiMessage != null && apiMessage.trim().isNotEmpty) {
      return apiMessage.trim();
    }

    return 'Jikan search failed (${response.statusCode}).';
  }
}
