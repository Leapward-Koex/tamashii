import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:http/http.dart' as http;
import 'package:tamashii/models/tenrai_models.dart';

class TenraiApiException implements Exception {
  const TenraiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TenraiApi {
  TenraiApi({
    http.Client? httpClient,
    this._timeout = const Duration(seconds: 8),
    this._now = DateTime.now,
  }) : _httpClient = httpClient ?? http.Client();

  static const String _host = 'api.tenrai.org';

  final http.Client _httpClient;
  final Duration _timeout;
  final DateTime Function() _now;
  DateTime? _retryAt;

  void close() => _httpClient.close();

  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const <TenraiAnimeSearchResult>[];
    }

    final uri = Uri.https(_host, '/v1/anime', <String, String>{
      'q': trimmedQuery,
      'limit': '$limit',
    });
    return _get(uri, (data) {
      final rows = data as List<dynamic>;
      return rows
          .map(
            (row) =>
                TenraiAnimeSearchResult.fromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false);
    });
  }

  Future<TenraiAnimeSearchResult?> getAnimeById(int malId) async {
    if (malId <= 0) return null;
    return _get<TenraiAnimeSearchResult?>(
      Uri.https(_host, '/v1/anime/$malId'),
      (data) {
        final entry = TenraiAnimeSearchResult.fromJson(
          data as Map<String, dynamic>,
        );
        if (entry.malId != malId) {
          throw const FormatException('Unexpected MAL ID');
        }
        return entry;
      },
      onNotFound: () => null,
    );
  }

  Future<T> _get<T>(
    Uri uri,
    T Function(Object?) parse, {
    T Function()? onNotFound,
  }) async {
    final retryAt = _retryAt;
    if (retryAt != null && _now().isBefore(retryAt)) {
      throw _rateLimitError();
    }
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abort.future,
    )..headers['Accept'] = 'application/json';

    late final http.Response response;
    try {
      response = await _httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            _timeout,
            onTimeout: () {
              abort.complete();
              throw const TenraiApiException('Tenrai search timed out.');
            },
          );
    } on http.ClientException {
      throw const TenraiApiException(
        'Unable to reach Tenrai right now. Please try again.',
      );
    }

    if (response.statusCode == 429) {
      final nextRetryAt = _readRetryAt(response.headers['retry-after']);
      final activeRetryAt = _retryAt;
      if (nextRetryAt != null &&
          (activeRetryAt == null || nextRetryAt.isAfter(activeRetryAt))) {
        _retryAt = nextRetryAt;
      }
      throw _rateLimitError();
    }

    if (response.statusCode == 404 && onNotFound != null) return onNotFound();
    if (response.statusCode != 200) {
      throw TenraiApiException(_errorMessageForResponse(response));
    }

    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return parse(json['data']);
    } on FormatException {
      throw const TenraiApiException('Tenrai returned an unreadable response.');
    } on TypeError {
      throw const TenraiApiException('Tenrai returned an unreadable response.');
    }
  }

  DateTime? _readRetryAt(String? header) {
    if (header == null) {
      return null;
    }
    final value = header.trim();
    final delaySeconds = int.tryParse(value, radix: 10);
    if (delaySeconds != null && delaySeconds >= 0) {
      return _now().add(Duration(seconds: delaySeconds));
    }

    try {
      return HttpDate.parse(value);
    } on HttpException {
      return null;
    }
  }

  TenraiApiException _rateLimitError() {
    final remaining = _retryAt?.difference(_now());
    if (remaining == null || remaining <= Duration.zero) {
      return const TenraiApiException(
        'Tenrai has received too many searches. Please try again shortly.',
      );
    }
    final seconds = (remaining.inMicroseconds / Duration.microsecondsPerSecond)
        .ceil();
    final duration = seconds == 1 ? '1 second' : '$seconds seconds';
    return TenraiApiException(
      'Tenrai has received too many searches. Try again in $duration.',
    );
  }

  String _errorMessageForResponse(http.Response response) {
    String? apiMessage;
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      apiMessage = json['message'] as String?;
    } catch (_) {
      apiMessage = null;
    }

    if (apiMessage != null && apiMessage.trim().isNotEmpty) {
      return apiMessage.trim();
    }

    return 'Tenrai search failed (${response.statusCode}).';
  }
}
