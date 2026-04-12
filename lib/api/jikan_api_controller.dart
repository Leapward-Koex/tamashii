import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/jikan_models.dart';
import 'package:tamashii/services/gemini_nano_prompts.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

class JikanLookupContext {
  const JikanLookupContext({
    required this.searchTitle,
    required this.seasonHint,
    this.reason,
    this.usedAi = false,
  });

  final String searchTitle;
  final String seasonHint;
  final String? reason;
  final bool usedAi;
}

class JikanCandidateSelection {
  const JikanCandidateSelection({required this.malId, this.reason});

  final int? malId;
  final String? reason;
}

class JikanApiController {
  JikanApiController({
    required OnDeviceTextGenerator textGenerator,
    http.Client? httpClient,
    SharedPreferences? preferences,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? delay,
  }) : _textGenerator = textGenerator,
       _httpClient = httpClient ?? http.Client(),
       _preferences = preferences,
       _ownsHttpClient = httpClient == null,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  static const String _baseHost = 'api.jikan.moe';
  static const String _mappingStorageKey = 'jikan_series_mapping_cache';
  static const String _hotnessStorageKey = 'jikan_hotness_cache';
  static const Duration _hotnessCacheTtl = Duration(days: 7);
  static const Duration _jikanRequestSpacing = Duration(milliseconds: 1200);
  static const Duration _jikanRateLimitCooldown = Duration(seconds: 20);
  static const Duration _aiFailureCooldown = Duration(minutes: 10);

  final OnDeviceTextGenerator _textGenerator;
  final http.Client _httpClient;
  final SharedPreferences? _preferences;
  final bool _ownsHttpClient;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _delay;

  Future<SharedPreferences>? _preferencesFuture;
  Future<OnDeviceModelCatalog>? _modelCatalogFuture;
  Future<void>? _cacheLoadFuture;

  Map<String, JikanSeriesMapping> _mappingCache =
      <String, JikanSeriesMapping>{};
  Map<int, JikanHotness> _hotnessCache = <int, JikanHotness>{};

  final Map<String, Future<JikanSeriesMapping?>> _mappingRequests =
      <String, Future<JikanSeriesMapping?>>{};
  final Map<String, Future<JikanHotness?>> _seriesHotnessRequests =
      <String, Future<JikanHotness?>>{};
  final Map<int, Future<JikanHotness?>> _animeHotnessRequests =
      <int, Future<JikanHotness?>>{};
  Future<void> _jikanRequestQueue = Future<void>.value();
  DateTime _nextJikanRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _jikanCooldownUntil;
  DateTime? _aiDisabledUntil;

  Future<List<JikanAnimeSearchHit>> searchAnime(
    String query, {
    int limit = 8,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const <JikanAnimeSearchHit>[];
    }

    final uri = Uri.https(_baseHost, '/v4/anime', <String, String>{
      'q': trimmedQuery,
      'limit': '${limit.clamp(1, 25)}',
    });

    final response = await _safeGet(uri);
    if (response == null) {
      return const <JikanAnimeSearchHit>[];
    }

    final payload = _decodeJsonMap(response.bodyBytes);
    final data = payload['data'];
    if (data is! List<dynamic>) {
      return const <JikanAnimeSearchHit>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(JikanAnimeSearchHit.fromJson)
        .where((entry) => entry.malId > 0)
        .toList();
  }

  Future<JikanAnimeDetails?> getAnimeById(int malId) async {
    if (malId <= 0) {
      return null;
    }

    final uri = Uri.https(_baseHost, '/v4/anime/$malId/full');
    final response = await _safeGet(uri);
    if (response == null) {
      return null;
    }

    final payload = _decodeJsonMap(response.bodyBytes);
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    return JikanAnimeDetails.fromJson(data);
  }

  Future<JikanHotness?> getHotnessForSeries(String localShowTitle) async {
    await _ensureCacheLoaded();

    final cacheKey = localShowTitle.trim();
    if (cacheKey.isEmpty) {
      return null;
    }

    final inFlight = _seriesHotnessRequests[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _resolveHotnessForSeries(cacheKey);
    _seriesHotnessRequests[cacheKey] = request;

    try {
      return await request;
    } finally {
      _seriesHotnessRequests.remove(cacheKey);
    }
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<JikanHotness?> _resolveHotnessForSeries(String localShowTitle) async {
    final mapping = await _resolveMapping(localShowTitle);
    if (mapping == null) {
      return null;
    }

    return _resolveHotnessForAnime(mapping);
  }

  Future<JikanSeriesMapping?> _resolveMapping(String localShowTitle) async {
    final cached = _mappingCache[localShowTitle];
    if (cached != null && cached.malId > 0) {
      return cached;
    }

    final inFlight = _mappingRequests[localShowTitle];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _buildMapping(localShowTitle);
    _mappingRequests[localShowTitle] = request;

    try {
      return await request;
    } finally {
      _mappingRequests.remove(localShowTitle);
    }
  }

  Future<JikanSeriesMapping?> _buildMapping(String localShowTitle) async {
    final fallbackLookupContext = JikanLookupContext(
      searchTitle: fallbackJikanSearchTitle(localShowTitle),
      seasonHint: inferSeasonHintFromTitle(localShowTitle),
    );
    var lookupContext = fallbackLookupContext;

    List<JikanAnimeSearchHit> candidates = await searchAnime(
      fallbackLookupContext.searchTitle,
    );

    final normalizedRawTitle = _normalizeComparisonText(localShowTitle);
    final normalizedSearchTitle = _normalizeComparisonText(
      fallbackLookupContext.searchTitle,
    );
    if (candidates.isEmpty && normalizedRawTitle != normalizedSearchTitle) {
      final rawCandidates = await searchAnime(localShowTitle);
      if (rawCandidates.isNotEmpty) {
        lookupContext = JikanLookupContext(
          searchTitle: localShowTitle,
          seasonHint: fallbackLookupContext.seasonHint,
        );
        candidates = rawCandidates;
      }
    }

    if (candidates.isEmpty) {
      final aiLookupContext = await _prepareLookupContext(
        localShowTitle,
        fallback: fallbackLookupContext,
      );
      final normalizedAiSearchTitle = _normalizeComparisonText(
        aiLookupContext.searchTitle,
      );

      if (aiLookupContext.usedAi &&
          normalizedAiSearchTitle.isNotEmpty &&
          normalizedAiSearchTitle != normalizedSearchTitle) {
        final aiCandidates = await searchAnime(aiLookupContext.searchTitle);
        if (aiCandidates.isNotEmpty) {
          lookupContext = aiLookupContext;
          candidates = aiCandidates;
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    final selected = await _selectBestCandidate(
      localShowTitle: localShowTitle,
      lookupContext: lookupContext,
      candidates: candidates,
    );
    if (selected == null) {
      return null;
    }

    final mapping = JikanSeriesMapping(
      localTitle: localShowTitle,
      searchTitle: lookupContext.searchTitle,
      seasonHint: lookupContext.seasonHint,
      malId: selected.malId,
      matchedTitle:
          selected.titleEnglish?.isNotEmpty == true
              ? selected.titleEnglish!
              : selected.title,
      updatedAt: _now(),
      reason: lookupContext.reason,
    );

    _mappingCache[localShowTitle] = mapping;
    await _persistMappingCache();
    return mapping;
  }

  Future<JikanHotness?> _resolveHotnessForAnime(
    JikanSeriesMapping mapping,
  ) async {
    final cached = _hotnessCache[mapping.malId];
    if (cached != null && !_isHotnessExpired(cached)) {
      return cached;
    }

    final inFlight = _animeHotnessRequests[mapping.malId];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _buildHotness(mapping);
    _animeHotnessRequests[mapping.malId] = request;

    try {
      return await request;
    } finally {
      _animeHotnessRequests.remove(mapping.malId);
    }
  }

  Future<JikanHotness?> _buildHotness(JikanSeriesMapping mapping) async {
    final cached = _hotnessCache[mapping.malId];
    if (cached != null && !_isHotnessExpired(cached)) {
      return cached;
    }

    final details = await getAnimeById(mapping.malId);
    if (details == null) {
      return null;
    }

    final hotness = JikanHotness(
      malId: details.malId,
      title: details.displayTitle,
      value: computeJikanHotnessValue(details, now: _now()),
      updatedAt: _now(),
      url: details.url,
    );

    _hotnessCache[mapping.malId] = hotness;
    await _persistHotnessCache();
    return hotness;
  }

  Future<JikanLookupContext> _prepareLookupContext(
    String localShowTitle, {
    required JikanLookupContext fallback,
  }) async {
    if (!await _hasUsableModel()) {
      return fallback;
    }

    try {
      final response = await _textGenerator.generateText(
        prompt: buildJikanLookupPreparationPrompt(localShowTitle),
      );

      return parseJikanLookupContextResponse(
        response.text,
        fallbackSearchTitle: fallback.searchTitle,
        fallbackSeasonHint: fallback.seasonHint,
      );
    } catch (error) {
      _recordAiFailure(error);
      debugPrint(
        'Jikan lookup normalization failed for "$localShowTitle": $error',
      );
      return fallback;
    }
  }

  Future<JikanAnimeSearchHit?> _selectBestCandidate({
    required String localShowTitle,
    required JikanLookupContext lookupContext,
    required List<JikanAnimeSearchHit> candidates,
  }) async {
    final fallback = fallbackSelectBestJikanCandidate(
      localShowTitle: localShowTitle,
      searchTitle: lookupContext.searchTitle,
      seasonHint: lookupContext.seasonHint,
      candidates: candidates,
    );
    if (fallback != null) {
      return fallback;
    }

    if (!await _hasUsableModel()) {
      return null;
    }

    try {
      final response = await _textGenerator.generateText(
        prompt: buildJikanCandidateSelectionPrompt(
          rawTitle: localShowTitle,
          searchTitle: lookupContext.searchTitle,
          seasonHint: lookupContext.seasonHint,
          candidates: candidates.map((entry) => entry.toPromptJson()).toList(),
        ),
      );

      final selection = parseJikanCandidateSelectionResponse(response.text);
      if (selection == null) {
        return fallback;
      }

      if (selection.malId == null) {
        return null;
      }

      for (final candidate in candidates) {
        if (candidate.malId == selection.malId) {
          return candidate;
        }
      }

      return fallback;
    } catch (error) {
      _recordAiFailure(error);
      debugPrint(
        'Jikan candidate selection failed for "$localShowTitle": $error',
      );
      return null;
    }
  }

  Future<bool> _hasUsableModel() async {
    final disabledUntil = _aiDisabledUntil;
    if (disabledUntil != null) {
      if (_now().isBefore(disabledUntil)) {
        return false;
      }
      _aiDisabledUntil = null;
    }

    final catalog =
        await (_modelCatalogFuture ??= _textGenerator.getModelCatalog());
    return catalog.hasUsableModel;
  }

  Future<http.Response?> _safeGet(Uri uri) async {
    return _enqueueJikanRequest<http.Response?>(() async {
      try {
        final response = await _httpClient.get(
          uri,
          headers: const <String, String>{
            'accept': 'application/json',
            'user-agent': 'Tamashii/1.0',
          },
        );
        if (response.statusCode == 200) {
          return response;
        }

        if (response.statusCode == 429) {
          _recordJikanRateLimit(response);
        }

        debugPrint(
          'Jikan request failed (${response.statusCode}) for $uri: ${response.reasonPhrase}',
        );
        return null;
      } catch (error) {
        debugPrint('Jikan request failed for $uri: $error');
        return null;
      }
    });
  }

  Future<void> _ensureCacheLoaded() {
    return _cacheLoadFuture ??= _loadCaches();
  }

  Future<void> _loadCaches() async {
    final prefs = await _getPreferences();
    _mappingCache = _decodeMappingCache(prefs.getString(_mappingStorageKey));
    _hotnessCache = _decodeHotnessCache(prefs.getString(_hotnessStorageKey));
  }

  Future<SharedPreferences> _getPreferences() {
    return _preferencesFuture ??=
        _preferences != null
            ? Future<SharedPreferences>.value(_preferences)
            : SharedPreferences.getInstance();
  }

  Future<void> _persistMappingCache() async {
    final prefs = await _getPreferences();
    final encoded = json.encode(
      _mappingCache.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_mappingStorageKey, encoded);
  }

  Future<void> _persistHotnessCache() async {
    final prefs = await _getPreferences();
    _hotnessCache.removeWhere((_, value) => _isHotnessExpired(value));
    final encoded = json.encode(
      _hotnessCache.map(
        (key, value) => MapEntry(key.toString(), value.toJson()),
      ),
    );
    await prefs.setString(_hotnessStorageKey, encoded);
  }

  bool _isHotnessExpired(JikanHotness hotness) {
    return _now().difference(hotness.updatedAt) > _hotnessCacheTtl;
  }

  Future<T> _enqueueJikanRequest<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _jikanRequestQueue = _jikanRequestQueue
        .then((_) async {
          await _waitForJikanWindow();
          final result = await action();
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        });

    return completer.future;
  }

  Future<void> _waitForJikanWindow() async {
    var target = _nextJikanRequestAt;
    final cooldownUntil = _jikanCooldownUntil;
    if (cooldownUntil != null && cooldownUntil.isAfter(target)) {
      target = cooldownUntil;
    }

    final now = _now();
    if (target.isAfter(now)) {
      await _delay(target.difference(now));
    }

    _nextJikanRequestAt = _now().add(_jikanRequestSpacing);
    final remainingCooldown = _jikanCooldownUntil;
    if (remainingCooldown != null && !remainingCooldown.isAfter(_now())) {
      _jikanCooldownUntil = null;
    }
  }

  void _recordJikanRateLimit(http.Response response) {
    final retryAfter = _parseRetryAfterSeconds(response.headers['retry-after']);
    final cooldownDuration =
        retryAfter == null
            ? _jikanRateLimitCooldown
            : Duration(seconds: math.max(retryAfter, 1));
    final cooldownUntil = _now().add(cooldownDuration);
    if (_jikanCooldownUntil == null ||
        cooldownUntil.isAfter(_jikanCooldownUntil!)) {
      _jikanCooldownUntil = cooldownUntil;
    }
  }

  void _recordAiFailure(Object error) {
    if (error is! PlatformException) {
      return;
    }

    final disabledUntil = _now().add(_aiFailureCooldown);
    if (_aiDisabledUntil == null || disabledUntil.isAfter(_aiDisabledUntil!)) {
      _aiDisabledUntil = disabledUntil;
    }
  }
}

JikanLookupContext parseJikanLookupContextResponse(
  String response, {
  required String fallbackSearchTitle,
  required String fallbackSeasonHint,
}) {
  final jsonObject = _extractJsonObject(response);
  if (jsonObject == null) {
    return JikanLookupContext(
      searchTitle: fallbackSearchTitle,
      seasonHint: fallbackSeasonHint,
    );
  }

  try {
    final decoded = json.decode(jsonObject);
    if (decoded is! Map<String, dynamic>) {
      return JikanLookupContext(
        searchTitle: fallbackSearchTitle,
        seasonHint: fallbackSeasonHint,
      );
    }

    final searchTitle =
        (decoded['search_title'] ?? decoded['searchTitle'] ?? '')
            .toString()
            .trim();
    final seasonHint =
        (decoded['season_hint'] ?? decoded['seasonHint'] ?? '')
            .toString()
            .trim();
    final reason = (decoded['reason'] ?? '').toString().trim();

    return JikanLookupContext(
      searchTitle: searchTitle.isEmpty ? fallbackSearchTitle : searchTitle,
      seasonHint: normalizeSeasonHint(
        seasonHint.isEmpty ? fallbackSeasonHint : seasonHint,
      ),
      reason: reason.isEmpty ? null : reason,
      usedAi: true,
    );
  } catch (_) {
    return JikanLookupContext(
      searchTitle: fallbackSearchTitle,
      seasonHint: fallbackSeasonHint,
    );
  }
}

JikanCandidateSelection? parseJikanCandidateSelectionResponse(String response) {
  final jsonObject = _extractJsonObject(response);
  if (jsonObject == null) {
    return null;
  }

  try {
    final decoded = json.decode(jsonObject);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final malIdValue = decoded['mal_id'] ?? decoded['malId'];
    final malId = malIdValue is num ? malIdValue.toInt() : null;
    final reason = (decoded['reason'] ?? '').toString().trim();
    return JikanCandidateSelection(
      malId: malId,
      reason: reason.isEmpty ? null : reason,
    );
  } catch (_) {
    return null;
  }
}

JikanAnimeSearchHit? fallbackSelectBestJikanCandidate({
  required String localShowTitle,
  required String searchTitle,
  required String seasonHint,
  required List<JikanAnimeSearchHit> candidates,
}) {
  final normalizedSearchTitle = _normalizeComparisonText(searchTitle);
  final normalizedLocalTitle = _normalizeComparisonText(localShowTitle);
  final requestedSeason = _extractSeasonNumberOrNull(seasonHint);
  final rawLooksSpecial = _looksLikeSpecial(localShowTitle);

  double bestScore = double.negativeInfinity;
  JikanAnimeSearchHit? bestCandidate;

  for (final candidate in candidates) {
    double score = 0;
    final candidateTitles =
        candidate.allTitles.map(_normalizeComparisonText).toList();

    if (candidateTitles.contains(normalizedSearchTitle)) {
      score += 60;
    }

    if (candidateTitles.any((title) => title.contains(normalizedSearchTitle))) {
      score += 25;
    }

    if (candidateTitles.any((title) => normalizedLocalTitle.contains(title))) {
      score += 12;
    }

    score += _bestTokenOverlap(normalizedSearchTitle, candidateTitles) * 25;
    score += _bestTokenOverlap(normalizedLocalTitle, candidateTitles) * 10;

    final candidateSeason = _inferCandidateSeason(candidate);
    if (candidateSeason != null && requestedSeason != null) {
      if (candidateSeason == requestedSeason) {
        score += 30;
      } else {
        score -= 18;
      }
    } else if (requestedSeason == 1 && candidateSeason == null) {
      score += 8;
    }

    final type = (candidate.type ?? '').toLowerCase();
    if (type == 'tv' || type == 'ona') {
      score += 6;
    }
    if ((type.contains('special') ||
            type.contains('movie') ||
            type.contains('ova')) &&
        !rawLooksSpecial) {
      score -= 25;
    }

    final loweredTitles = candidate.allTitles.join(' ').toLowerCase();
    if (!rawLooksSpecial &&
        (loweredTitles.contains('recap') ||
            loweredTitles.contains('summary') ||
            loweredTitles.contains('movie'))) {
      score -= 30;
    }

    score += ((candidate.score ?? 0) / 10.0) * 4;

    if (score > bestScore) {
      bestScore = score;
      bestCandidate = candidate;
    }
  }

  if (bestScore < 30) {
    return null;
  }

  return bestCandidate;
}

String fallbackJikanSearchTitle(String rawTitle) {
  var candidate = rawTitle.trim();
  final patterns = <RegExp>[
    RegExp(r'\bseason\s+\d+\b', caseSensitive: false),
    RegExp(r'\b\d+(?:st|nd|rd|th)\s+season\b', caseSensitive: false),
    RegExp(r'\bs\d+\b', caseSensitive: false),
    RegExp(r'\bpart\s+\d+\b', caseSensitive: false),
    RegExp(r'\bcour\s+\d+\b', caseSensitive: false),
    RegExp(
      r'\b(?:first|second|third|fourth|fifth)\s+season\b',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    candidate = candidate.replaceAll(pattern, ' ');
  }

  candidate = candidate.replaceAll(RegExp(r'\s+'), ' ').trim();
  return candidate.isEmpty ? rawTitle.trim() : candidate;
}

String inferSeasonHintFromTitle(String rawTitle) {
  final seasonNumber = _extractSeasonNumber(rawTitle);
  return 'Season ${seasonNumber.toString().padLeft(2, '0')}';
}

String normalizeSeasonHint(String value) {
  final seasonNumber = _extractSeasonNumber(value);
  return 'Season ${seasonNumber.toString().padLeft(2, '0')}';
}

int computeJikanHotnessValue(JikanAnimeDetails anime, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  final scoreComponent = ((anime.score ?? 0) / 10).clamp(0, 1).toDouble();
  final popularityComponent = _rankScore(anime.popularity, maxRank: 10000);
  final rankComponent = _rankScore(anime.rank, maxRank: 5000);
  final membersComponent = _logScore(anime.members ?? 0, maxValue: 2000000);
  final favoritesComponent = _logScore(anime.favorites ?? 0, maxValue: 50000);
  final scoredByComponent = _logScore(anime.scoredBy ?? 0, maxValue: 500000);
  final airingComponent = anime.airing ? 1.0 : 0.0;
  final recencyComponent = _recencyScore(anime.airedFrom, currentTime);

  final value =
      (scoreComponent * 0.32) +
      (popularityComponent * 0.18) +
      (rankComponent * 0.12) +
      (membersComponent * 0.16) +
      (favoritesComponent * 0.10) +
      (scoredByComponent * 0.07) +
      (airingComponent * 0.03) +
      (recencyComponent * 0.02);

  return (value * 100).round().clamp(0, 100);
}

Map<String, JikanSeriesMapping> _decodeMappingCache(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) {
    return <String, JikanSeriesMapping>{};
  }

  try {
    final decoded = json.decode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      return <String, JikanSeriesMapping>{};
    }

    final entries = <String, JikanSeriesMapping>{};
    for (final entry in decoded.entries) {
      if (entry.value is Map<String, dynamic>) {
        entries[entry.key] = JikanSeriesMapping.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return entries;
  } catch (_) {
    return <String, JikanSeriesMapping>{};
  }
}

Map<int, JikanHotness> _decodeHotnessCache(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) {
    return <int, JikanHotness>{};
  }

  try {
    final decoded = json.decode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      return <int, JikanHotness>{};
    }

    final entries = <int, JikanHotness>{};
    for (final entry in decoded.entries) {
      final malId = int.tryParse(entry.key);
      if (malId == null || entry.value is! Map<String, dynamic>) {
        continue;
      }
      entries[malId] = JikanHotness.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    return entries;
  } catch (_) {
    return <int, JikanHotness>{};
  }
}

Map<String, dynamic> _decodeJsonMap(List<int> bytes) {
  final decoded = json.decode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic>) {
    return <String, dynamic>{};
  }
  return decoded;
}

String _normalizeComparisonText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double _bestTokenOverlap(String source, List<String> candidates) {
  double best = 0;
  for (final candidate in candidates) {
    best = math.max(best, _tokenOverlap(source, candidate));
  }
  return best;
}

double _tokenOverlap(String lhs, String rhs) {
  if (lhs.isEmpty || rhs.isEmpty) {
    return 0;
  }

  final lhsTokens = lhs.split(' ').where((token) => token.isNotEmpty).toSet();
  final rhsTokens = rhs.split(' ').where((token) => token.isNotEmpty).toSet();
  if (lhsTokens.isEmpty || rhsTokens.isEmpty) {
    return 0;
  }

  final intersection = lhsTokens.intersection(rhsTokens).length;
  final denominator = math.max(lhsTokens.length, rhsTokens.length);
  return intersection / denominator;
}

bool _looksLikeSpecial(String value) {
  final lowered = value.toLowerCase();
  return lowered.contains('movie') ||
      lowered.contains('special') ||
      lowered.contains('recap') ||
      lowered.contains('ova') ||
      lowered.contains('ona');
}

int? _inferCandidateSeason(JikanAnimeSearchHit candidate) {
  for (final title in candidate.allTitles) {
    final seasonNumber = _extractSeasonNumberOrNull(title);
    if (seasonNumber != null) {
      return seasonNumber;
    }
  }

  return null;
}

int? _parseRetryAfterSeconds(String? rawValue) {
  if (rawValue == null) {
    return null;
  }

  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return int.tryParse(trimmed);
}

int _extractSeasonNumber(String value) {
  return _extractSeasonNumberOrNull(value) ?? 1;
}

int? _extractSeasonNumberOrNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final patterns = <RegExp>[
    RegExp(r'\bseason\s*(\d+)\b', caseSensitive: false),
    RegExp(r'\bs(\d+)\b', caseSensitive: false),
    RegExp(r'\bpart\s*(\d+)\b', caseSensitive: false),
    RegExp(r'\bcour\s*(\d+)\b', caseSensitive: false),
    RegExp(r'\b(\d+)(?:st|nd|rd|th)\s+season\b', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(trimmed);
    if (match != null) {
      final number = int.tryParse(match.group(1)!);
      if (number != null && number > 0) {
        return number;
      }
    }
  }

  final lowered = trimmed.toLowerCase();
  const namedOrdinals = <String, int>{
    'first season': 1,
    'second season': 2,
    'third season': 3,
    'fourth season': 4,
    'fifth season': 5,
  };
  for (final entry in namedOrdinals.entries) {
    if (lowered.contains(entry.key)) {
      return entry.value;
    }
  }

  return null;
}

double _rankScore(int? rank, {required int maxRank}) {
  if (rank == null || rank <= 0) {
    return 0;
  }
  if (rank > maxRank) {
    return 0;
  }
  return (1 - (math.log(rank) / math.log(maxRank))).clamp(0, 1).toDouble();
}

double _logScore(int value, {required int maxValue}) {
  if (value <= 0) {
    return 0;
  }
  return (math.log(value + 1) / math.log(maxValue + 1)).clamp(0, 1).toDouble();
}

double _recencyScore(DateTime? airedFrom, DateTime now) {
  if (airedFrom == null) {
    return 0;
  }

  final ageInDays = now.difference(airedFrom).inDays;
  if (ageInDays <= 0) {
    return 1;
  }
  if (ageInDays >= 1095) {
    return 0;
  }
  return (1 - (ageInDays / 1095)).clamp(0, 1).toDouble();
}

String? _extractJsonObject(String response) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(response);
  return match?.group(0);
}
