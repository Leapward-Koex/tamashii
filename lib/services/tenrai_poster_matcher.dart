import 'package:tamashii/models/tenrai_models.dart';

/// Finds a single catalog entry with a matching full title and large artwork.
TenraiAnimeSearchResult? matchTenraiPoster(
  String showTitle,
  Iterable<TenraiAnimeSearchResult> candidates,
) {
  final title = _titleKey(showTitle);
  if (title.isEmpty) return null;

  int? matchedId;
  TenraiAnimeSearchResult? poster;
  for (final candidate in candidates) {
    final primary = _titleKey(candidate.title);
    final english = _titleKey(candidate.titleEnglish ?? '');
    final matchesPrimary = _sameTitle(title, primary);
    if (!matchesPrimary && !_sameTitle(title, english)) continue;

    // Count identities even if one of the results has unusable artwork.
    if (matchedId != null && matchedId != candidate.malId) return null;
    matchedId = candidate.malId;

    final isMovie = candidate.type?.trim().toLowerCase() == 'movie';
    if (isMovie && !_movieMarker.hasMatch(title)) continue;
    if (!matchesPrimary && !_aliasKeepsInstallment(title, primary)) continue;
    if (poster == null && candidate.largeImageUrl?.trim().isNotEmpty == true) {
      poster = candidate;
    }
  }
  return poster;
}

final _apostrophes = RegExp("[’']");
final _titleWords = RegExp(r'[\p{L}\p{N}\p{M}]+', unicode: true);
final _seasonSpelling = RegExp(
  r'\b(?:(?:season ?|s ?)([0-9]+)|season (ii|iii|iv|v|vi|vii|viii|ix|x)'
  r'|([0-9]+)(?:st|nd|rd|th) season)\b',
);
final _seasonMarker = RegExp(r'\bseason ([0-9]+)\b');
final _partMarker = RegExp(r'\bpart ([0-9]+)\b');
final _movieMarker = RegExp(r'\b(movie|film|gekijouban)\b');
final _romanSuffix = RegExp(r' (ii|iii|iv|vi|vii|viii|ix)$');
const _romanSeasons = <String, int>{
  'ii': 2,
  'iii': 3,
  'iv': 4,
  'v': 5,
  'vi': 6,
  'vii': 7,
  'viii': 8,
  'ix': 9,
  'x': 10,
};

String _titleKey(String input) {
  final title = input.toLowerCase().replaceAll(_apostrophes, '');
  final words = _titleWords.allMatches(title).map((word) => word[0]!).join(' ');
  return words.replaceAllMapped(_seasonSpelling, (match) {
    final spelling = match[1] ?? match[2] ?? match[3]!;
    final number = int.tryParse(spelling) ?? _romanSeasons[spelling];
    return number == null ? match[0]! : 'season $number';
  });
}

// Tenrai can use a terminal roman numeral where SubsPlease uses an
// explicit season marker. Compare those spellings without stripping either.
bool _sameTitle(String first, String second) =>
    first == second ||
    _seasonMarker.hasMatch(first) && first == _expandRomanSeason(second) ||
    _seasonMarker.hasMatch(second) && _expandRomanSeason(first) == second;

String _expandRomanSeason(String key) => key.replaceFirstMapped(
  _romanSuffix,
  (match) => ' season ${_romanSeasons[match[1]!]!}',
);

// An English alias can omit a sequel marker present in the primary title.
bool _aliasKeepsInstallment(String title, String primary) {
  final expected = _expandRomanSeason(title);
  final catalog = _expandRomanSeason(primary);
  for (final marker in [_seasonMarker, _partMarker]) {
    final catalogNumber = marker.firstMatch(catalog)?[1];
    if (catalogNumber != null &&
        catalogNumber != marker.firstMatch(expected)?[1]) {
      return false;
    }
  }
  return !_movieMarker.hasMatch(primary) || _movieMarker.hasMatch(title);
}
