import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/services/gemini_nano_catalog_match.dart';
import 'package:tamashii/services/show_catalog_matcher.dart';

part 'show_catalog_match_provider.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// The presence of a null entry means the user explicitly chose "unmatched".
/// A key per choice allows independent releases to be saved without replacing
/// another release's data.
@Riverpod(keepAlive: true)
class CatalogMatchOverrides extends _$CatalogMatchOverrides {
  static const _prefix = 'catalog_match.';
  Future<void> _pending = Future<void>.value();

  @override
  Future<Map<String, TenraiAnimeSearchResult?>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, TenraiAnimeSearchResult?>{};
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      final raw = prefs.get(key);
      if (raw is! String) continue;
      try {
        final value = jsonDecode(raw);
        result[key.substring(_prefix.length)] = value == null
            ? null
            : TenraiAnimeSearchResult.fromJson(value as Map<String, dynamic>);
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return result;
  }

  Future<void> save(ShowCatalogTarget target, TenraiAnimeSearchResult? entry) {
    final result = _pending.then((_) async {
      final current = await future;
      final releaseOnly =
          target.episode != null &&
          (target.effectiveOverride(current).releaseOnly ||
              entry != null && catalogEntryIsSpecial(entry));
      final key = releaseOnly
          ? target.forThisRelease.scopeKey
          : target.scopeKey;
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        '$_prefix$key',
        jsonEncode(entry?.toJson()),
      );
      if (!saved) throw StateError('Unable to save your match.');
      if (ref.mounted) state = AsyncData({...current, key: entry});
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

@Riverpod(retry: _noRetry)
Future<ShowCatalogMatch> showCatalogMatch(
  Ref ref,
  ShowCatalogTarget target,
) async {
  final override = await ref.watch(
    catalogMatchOverridesProvider.selectAsync(target.effectiveOverride),
  );
  if (override.exists) {
    return ShowCatalogMatch(
      entry: override.entry,
      userSelected: true,
      releaseOnly: override.releaseOnly,
    );
  }
  final knownId = target.savedMalId;
  if (knownId != null && knownId > 0 && !target.isReleaseScoped) {
    // Manual bookmarks already contain a user-confirmed ID. Keep that identity
    // accessible when Tenrai has no details or cannot be reached.
    TenraiAnimeSearchResult? details;
    try {
      details = await ref.watch(catalogEntryByIdProvider(knownId).future);
    } on Exception {
      details = null;
    }
    return ShowCatalogMatch(
      entry:
          details ??
          TenraiAnimeSearchResult(
            malId: knownId,
            title: target.title,
            imageUrl: target.savedImageUrl ?? '',
          ),
      userSelected: true,
      evidence: 'This MyAnimeList entry was saved on your schedule.',
    );
  }
  final api = ref.watch(tenraiApiProvider);
  final generator = ref.watch(onDeviceTextGeneratorProvider);
  final title = target.title.trim();
  if (title.isEmpty) return const ShowCatalogMatch();
  final query = target.isReleaseScoped
      ? '$title ${target.episode}'.trim()
      : title;
  final raw = await api.searchAnime(query);
  var suggestions = catalogSuggestions(target, raw);
  List<TenraiAnimeSearchResult> compatible() => suggestions
      .where((entry) => isCatalogCandidateCompatible(target, entry))
      .toList();
  var eligible = compatible();
  var exact = exactCatalogMatch(target, eligible);
  final broader = catalogSeriesQuery(title);
  if (exact == null && broader.isNotEmpty && broader != query) {
    suggestions = catalogSuggestions(target, [
      ...raw,
      ...await api.searchAnime(broader),
    ]);
    eligible = compatible();
    exact = exactCatalogMatch(target, eligible);
  }
  if (exact != null) {
    return ShowCatalogMatch(
      entry: exact,
      candidates: suggestions,
      evidence: target.isReleaseScoped
          ? 'The catalog title identifies both “$title” and release “${target.episode}”.'
          : '“$title” matches the catalog title or its English title, including any season and part markers.',
    );
  }
  if (eligible.isNotEmpty &&
      !eligible.any((entry) => exactCatalogMatch(target, [entry]) != null)) {
    final suggested = await suggestCatalogMatch(
      generator: generator,
      sourceTitle: title,
      episode: target.episode,
      candidates: eligible,
    );
    if (suggested != null) {
      return ShowCatalogMatch(
        entry: suggested,
        candidates: suggestions,
        evidence:
            'The on-device model identified “${suggested.displayTitle}” among the Tenrai entries using the SubsPlease title and release information.',
      );
    }
  }
  return ShowCatalogMatch(candidates: suggestions);
}
