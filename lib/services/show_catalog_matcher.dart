import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/services/tenrai_poster_matcher.dart';

final _season = RegExp(r'\bseason (\d+)\b');
final _part = RegExp(r'\b(?:part|cour) (\d+)\b');
final _special = RegExp(r'\b(?:specials?|sp|ova|oad|recap|preview|extras?)\b');
final _movie = RegExp(r'\b(?:movie|film|gekijouban)\b');
final _specialFormats = {'special', 'tv special', 'ova', 'oad'};

bool catalogEntryIsSpecial(TenraiAnimeSearchResult entry) {
  final format = entry.type?.trim().toLowerCase();
  return _specialFormats.contains(format) ||
      format == 'movie' ||
      [entry.title, ?entry.titleEnglish].any(
        (title) =>
            hasSpecialTitleMarker(title) ||
            RegExp(
              r'\bepisode\s+\d+\.\d+\b',
              caseSensitive: false,
            ).hasMatch(title),
      );
}

/// Search a parent title when the feed's release-group spelling doesn't
/// return the installment. The original qualifiers are still used to match.
String catalogSeriesQuery(String title) => title
    .trim()
    .replaceFirst(
      RegExp(
        r'\s+[-:]?\s*(?:(?:s(?:eason)?|part|cour)\s*\d+|\d+(?:st|nd|rd|th)\s+season)'
        r'(?:\s+(?:part|cour)\s*\d+)?$',
        caseSensitive: false,
      ),
      '',
    )
    .trim();

bool isCatalogCandidateCompatible(
  ShowCatalogTarget target,
  TenraiAnimeSearchResult entry,
) {
  final title = catalogTitleKey(target.title);
  final source = catalogTitleKey('${target.title} ${target.episode ?? ''}');
  final titles = [
    catalogTitleKey(entry.title),
    catalogTitleKey(entry.titleEnglish ?? ''),
  ];
  final type = entry.type?.trim().toLowerCase();
  if ((type == 'movie' || titles.any(_movie.hasMatch)) !=
      _movie.hasMatch(source)) {
    return false;
  }
  if (!target.isReleaseScoped &&
      (_specialFormats.contains(type) || titles.any(_special.hasMatch)) &&
      !_special.hasMatch(title)) {
    return false;
  }
  if (_special.hasMatch(title) &&
      !_specialFormats.contains(type) &&
      !titles.any(_special.hasMatch)) {
    return false;
  }

  // A model or a translated alias cannot add, drop or swap a numbered
  // installment. Exceptions such as an explicitly named first season can
  // safely be resolved in the picker.
  for (final marker in [_season, _part]) {
    final expected = marker.firstMatch(title)?[1];
    final numbers = titles
        .expand(marker.allMatches)
        .map((match) => match[1])
        .toSet();
    if (expected == null
        ? numbers.isNotEmpty
        : numbers.length != 1 || !numbers.contains(expected)) {
      return false;
    }
  }
  if (!target.isReleaseScoped) return true;

  final release = target.episode!.trim().toLowerCase();
  if (RegExp(r'^\d+\.\d+(?:v\d+)?$').hasMatch(release)) {
    final number = release.split('v').first;
    final literal = RegExp(
      '(?:^|[^0-9.])${RegExp.escape(number)}(?:\$|[^0-9.])',
    );
    return [entry.title, entry.titleEnglish ?? ''].any(literal.hasMatch);
  }
  // A generic label cannot identify which special belongs to the release.
  if (_genericSpecial.hasMatch(release)) {
    return false;
  }
  final releaseKey = catalogTitleKey(release);
  return releaseKey.isNotEmpty &&
      titles.any((alias) => (' $alias ').contains(' $releaseKey '));
}

TenraiAnimeSearchResult? exactCatalogMatch(
  ShowCatalogTarget target,
  List<TenraiAnimeSearchResult> compatible,
) {
  if (!target.isReleaseScoped) {
    return matchTenraiTitle(target.title, compatible);
  }
  final label = target.episode!;
  return matchTenraiTitle('${target.title} $label', compatible) ??
      matchTenraiTitle('${target.title} Episode $label', compatible);
}

/// Narrows fuzzy Tenrai search results to suggestions for the source series.
/// Free-form searches in the match picker use the unfiltered catalog results.
List<TenraiAnimeSearchResult> catalogSuggestions(
  ShowCatalogTarget target,
  Iterable<TenraiAnimeSearchResult> entries,
) {
  final seen = <int>{};
  final series = catalogTitleKey(catalogSeriesQuery(target.title));
  final words = catalogTitleWords(series);
  return [
    for (final entry in entries)
      if (entry.malId > 0 &&
          (target.isReleaseScoped
              ? _isPossibleSpecial(target, entry)
              : [
                  entry.title,
                  ?entry.titleEnglish,
                ].any((alias) => _looksLikeSeries(series, words, alias))) &&
          seen.add(entry.malId))
        entry,
  ];
}

bool _looksLikeSeries(String series, Set<String> words, String alias) {
  if (series.isEmpty) return false;
  final key = catalogTitleKey(catalogSeriesQuery(alias));
  if (series == key) return true;
  if (words.isEmpty) return false;
  final candidateWords = catalogTitleWords(key);
  final common = words.intersection(candidateWords).length;
  // A feed can use a short title such as "Hero" for "My Hero Academia".
  // For partial titles, require most of the source words and some coverage
  // of the catalog title to avoid a chance overlap in long titles.
  return common == words.length ||
      (common >= 2 &&
          common * 2 > words.length &&
          common * 2 >= candidateWords.length);
}

final _words = RegExp(r'[\p{L}\p{M}]+', unicode: true);
const _nonIdentifyingWords = {
  'a',
  'an',
  'and',
  'of',
  'the',
  'to',
  'in',
  'on',
  'from',
  'for',
  'with',
  'no',
  'ga',
  'de',
  'wa',
  'ni',
  'wo',
  'season',
  'part',
  'cour',
  's',
  'ii',
  'iii',
  'iv',
  'nd',
  'th',
  'st',
  'rd',
  'episode',
  'ep',
  'sp',
  'special',
  'recap',
  'ova',
  'ona',
  'movie',
  'film',
};

/// Words that identify a series across its different installment titles.
Set<String> catalogTitleWords(String text) => {
  for (final word in _words.allMatches(text.toLowerCase()))
    if (!_nonIdentifyingWords.contains(word[0]!)) word[0]!,
};

final _genericSpecial = RegExp(
  r'^(?:sp(?:ecial)?|ova|oad|extra|preview|recap)(?:[\s._-]*\d+)?$',
  caseSensitive: false,
);

bool _isPossibleSpecial(
  ShowCatalogTarget target,
  TenraiAnimeSearchResult entry,
) {
  if (isCatalogCandidateCompatible(target, entry)) return true;
  final label = target.episode!.trim();
  if (!_genericSpecial.hasMatch(label)) return false;
  final aliases = [
    catalogTitleKey(entry.title),
    catalogTitleKey(entry.titleEnglish ?? ''),
  ];
  final source = catalogTitleKey(target.title);
  final type = entry.type?.trim().toLowerCase();
  // A generic SP label can refer to a side story without a catalog "Special"
  // type, e.g. the Link Click 5.5 ONA. Exclude the parent and numbered sequels.
  if (aliases.contains(source) && !_special.hasMatch(source)) return false;
  return aliases.any((alias) => alias.contains(source)) &&
      !aliases.any(
        (alias) => _season.hasMatch(alias) || _part.hasMatch(alias),
      ) &&
      (_specialFormats.contains(type) ||
          type == 'ona' ||
          aliases.any(_special.hasMatch));
}
