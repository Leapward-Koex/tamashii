import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/services/gemini_nano_catalog_match.dart';
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/show_catalog_matcher.dart';

part 'show_catalog_match_provider.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

Future<Map<String, T>> _loadRecords<T>(
  String prefix,
  T Function(dynamic) decode,
) async {
  final prefs = await SharedPreferences.getInstance();
  final records = <String, T>{};
  for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
    final raw = prefs.get(key);
    if (raw is! String) continue;
    try {
      records[key.substring(prefix.length)] = decode(jsonDecode(raw));
    } on FormatException {
      continue;
    } on TypeError {
      continue;
    }
  }
  return records;
}

/// The presence of a null entry means the user explicitly chose "unmatched".
/// A key per choice allows independent releases to be saved without replacing
/// another release's data.
@Riverpod(keepAlive: true)
class CatalogMatchOverrides extends _$CatalogMatchOverrides {
  static const _prefix = 'catalog_match.';
  Future<void> _pending = Future<void>.value();

  @override
  Future<Map<String, TenraiAnimeSearchResult?>> build() => _loadRecords(
    _prefix,
    (value) => value == null
        ? null
        : TenraiAnimeSearchResult.fromJson(value as Map<String, dynamic>),
  );

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

/// Successful lookups are shared by ordinary episodes in a series. Manual
/// choices (including "unmatched") live separately and always take priority.
@Riverpod(keepAlive: true)
class ResolvedCatalogMatches extends _$ResolvedCatalogMatches {
  static const _prefix = 'catalog_resolved.';
  final _inFlight = <(String, int?), Future<ShowCatalogMatch>>{};

  @override
  Future<Map<String, ShowCatalogMatch>> build() => _loadRecords(
    _prefix,
    (value) => ShowCatalogMatch.fromJson(value as Map<String, dynamic>),
  );

  Future<ShowCatalogMatch> resolve(
    ShowCatalogTarget target,
    Future<ShowCatalogMatch> Function() lookup,
  ) {
    final request = (target.scopeKey, target.savedMalId);
    return _inFlight.putIfAbsent(request, () async {
      try {
        final resolved = await lookup();
        if (resolved.entry == null || !ref.mounted) return resolved;
        final prefs = await SharedPreferences.getInstance();
        final key = target.scopeKey;
        final saved = await prefs.setString(
          '$_prefix$key',
          jsonEncode(resolved.copyWith(candidates: const []).toJson()),
        );
        if (!saved) throw StateError('Unable to save the catalog entry.');
        if (ref.mounted) {
          state = AsyncData({...state.requireValue, key: resolved});
        }
        return resolved;
      } finally {
        _inFlight.remove(request);
      }
    });
  }
}

@Riverpod(keepAlive: true)
Future<void> catalogCacheReady(Ref ref) async {
  await Future.wait([
    ref.read(catalogMatchOverridesProvider.future),
    ref.read(resolvedCatalogMatchesProvider.future),
    ref.watch(bookmarkedSeriesProvider.selectAsync((_) => true)),
  ]);
}

@riverpod
Map<String, BookmarkedShowInfo> _catalogBookmarks(Ref ref) {
  final bookmarks = ref.watch(bookmarkedSeriesProvider).value;
  return {
    for (final bookmark in bookmarks ?? const <BookmarkedShowInfo>[])
      if (bookmark.isManualEntry && bookmark.malId != null)
        bookmark.showName.trim().toLowerCase(): bookmark,
  };
}

BookmarkedShowInfo? _bookmarkFor(Ref ref, ShowCatalogTarget target) {
  if (target.isReleaseScoped) return null;
  final key = target.title.trim().toLowerCase();
  return ref.watch(
    _catalogBookmarksProvider.select((bookmarks) => bookmarks[key]),
  );
}

@riverpod
ShowCatalogMatch? cachedShowCatalogMatch(Ref ref, ShowCatalogTarget target) {
  final choice = ref.watch(
    catalogMatchOverridesProvider.select(
      (v) => target.effectiveOverride(v.value ?? const {}),
    ),
  );
  if (choice.exists) {
    return ShowCatalogMatch(
      entry: choice.entry,
      userSelected: true,
      releaseOnly: choice.releaseOnly,
    );
  }
  final bookmark = _bookmarkFor(ref, target);
  final knownId = target.savedMalId ?? bookmark?.malId;
  final confirmed = bookmark?.catalogEntry;
  if (confirmed != null && confirmed.malId == knownId) {
    return ShowCatalogMatch(entry: confirmed, userSelected: true);
  }
  final saved = ref.watch(
    resolvedCatalogMatchesProvider.select((v) => v.value?[target.scopeKey]),
  );
  if ((knownId ?? 0) > 0 && !target.isReleaseScoped) {
    if (knownId != saved?.entry?.malId) return null;
    return saved?.copyWith(userSelected: true);
  }
  return saved;
}

@Riverpod(retry: _noRetry)
Future<ShowCatalogMatch> showCatalogMatch(
  Ref ref,
  ShowCatalogTarget target,
) async {
  // Manual corrections invalidate an outstanding lookup, including when the
  // user explicitly chooses to keep a release unmatched.
  final choice = await ref.watch(
    catalogMatchOverridesProvider.selectAsync(target.effectiveOverride),
  );
  if (choice.exists) {
    return ShowCatalogMatch(
      entry: choice.entry,
      releaseOnly: choice.releaseOnly,
      userSelected: true,
    );
  }
  await ref.read(catalogCacheReadyProvider.future);
  if (!ref.mounted) return const ShowCatalogMatch();
  final cached = ref.read(cachedShowCatalogMatchProvider(target));
  if (cached != null) return cached;
  final bookmark = _bookmarkFor(ref, target);
  final knownId = target.savedMalId ?? bookmark?.malId;
  if (knownId != null && knownId > 0 && !target.isReleaseScoped) {
    // Manual bookmarks already contain a user-confirmed ID. Keep that identity
    // accessible when Tenrai has no details or cannot be reached.
    TenraiAnimeSearchResult? details;
    try {
      details = await ref.watch(catalogEntryByIdProvider(knownId).future);
    } on Exception {
      details = null;
    }
    final match = ShowCatalogMatch(
      entry:
          details ??
          TenraiAnimeSearchResult(
            malId: knownId,
            title: target.title,
            imageUrl: target.savedImageUrl ?? bookmark?.imageUrl ?? '',
          ),
      userSelected: true,
      evidence: 'This MyAnimeList entry was saved on your schedule.',
    );
    if (details == null || !ref.mounted) return match;
    return ref
        .read(resolvedCatalogMatchesProvider.notifier)
        .resolve(target.copyWith(savedMalId: knownId), () async => match);
  }
  final api = ref.watch(tenraiApiProvider);
  final generator = ref.watch(onDeviceTextGeneratorProvider);
  return ref
      .read(resolvedCatalogMatchesProvider.notifier)
      .resolve(target, () => _discover(target, api, generator));
}

Future<ShowCatalogMatch> _discover(
  ShowCatalogTarget target,
  TenraiApi api,
  OnDeviceTextGenerator generator,
) async {
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
