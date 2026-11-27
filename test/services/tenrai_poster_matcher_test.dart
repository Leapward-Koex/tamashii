import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/services/tenrai_poster_matcher.dart';

const _posterUrl = 'https://cdn.example.com/large.jpg';

TenraiAnimeSearchResult _anime(
  int id,
  String title, {
  String? english,
  String type = 'TV',
  String? largeImageUrl = _posterUrl,
  String imageUrl = '',
}) => TenraiAnimeSearchResult(
  malId: id,
  title: title,
  titleEnglish: english,
  type: type,
  imageUrl: imageUrl,
  largeImageUrl: largeImageUrl,
);

void main() {
  test('matches the full romanized title despite case and punctuation', () {
    final series = _anime(63042, 'Meitantei Precure!');
    final movie = _anime(
      63903,
      'Meitantei Precure! Movie: Fushigi na Niwa to 2-ri no Himitsu',
      type: 'Movie',
    );

    expect(
      matchTenraiPoster('  MEITANTEI  Precure  ', [movie, series]),
      series,
    );
    expect(matchTenraiPoster('Meitantei Precure!', [movie]), isNull);
  });

  test('keeps Unicode titles distinct', () {
    final shoujo = _anime(1, '少女');
    final other = _anime(2, '少年');

    expect(matchTenraiPoster('少女！', [other, shoujo]), shoujo);
    expect(matchTenraiPoster('！', [other, shoujo]), isNull);
  });

  test('matches a unique English title', () {
    final series = _anime(
      52991,
      'Sousou no Frieren',
      english: 'Frieren: Beyond Journey’s End',
    );

    expect(
      matchTenraiPoster("Frieren - Beyond Journey's End", [series]),
      series,
    );
  });

  test('prefers a full numbered season over a partial series title', () {
    final first = _anime(52991, 'Sousou no Frieren');
    final second = _anime(59978, 'Sousou no Frieren 2nd Season');
    final third = _anime(63816, 'Sousou no Frieren: Ougonkyou-hen');

    expect(
      matchTenraiPoster('Sousou no Frieren S2', [first, third, second]),
      second,
    );
    expect(matchTenraiPoster('Sousou no Frieren Season 02', [first]), isNull);
  });

  test('compares a terminal roman numeral to a season marker', () {
    const baseTitle = 'Hyouken no Majutsushi ga Sekai wo Suberu';
    final first = _anime(51711, baseTitle);
    final second = _anime(64254, '$baseTitle II');

    expect(matchTenraiPoster('$baseTitle S2', [first, second]), second);
    expect(matchTenraiPoster(baseTitle, [second, first]), first);
    expect(matchTenraiPoster('$baseTitle Part 2', [second]), isNull);
  });

  test('rejects an alias that omits an explicit installment', () {
    final numbered = _anime(3, 'Shiroi Ryuu II', english: 'White Dragon');
    final part = _anime(
      4,
      'Shiroi Ryuu 2nd Season Part 2',
      english: 'White Dragon Season 2',
    );

    expect(matchTenraiPoster('White Dragon', [numbered]), isNull);
    expect(matchTenraiPoster('White Dragon S2', [part]), isNull);
  });

  test('accepts an explicit season in the matching English alias', () {
    final sequel = _anime(
      6,
      'Shiroi Ryuu: Shinsekai',
      english: 'White Dragon Season 2',
    );

    expect(matchTenraiPoster('White Dragon S2', [sequel]), sequel);
  });

  test('rejects an unqualified title used by a film', () {
    final movie = _anime(7, 'Made Up Show', type: 'Movie');
    final explicitMovie = _anime(8, 'Made Up Show: The Movie', type: 'Movie');

    expect(matchTenraiPoster('Made Up Show', [movie]), isNull);
    expect(
      matchTenraiPoster('Made Up Show - The Movie', [explicitMovie]),
      explicitMovie,
    );
  });

  test('fails closed on different IDs sharing the title', () {
    final series = _anime(1, 'The Show');
    final differentSeries = _anime(
      2,
      'Show no Anime',
      english: 'The Show',
      largeImageUrl: null,
    );

    expect(matchTenraiPoster('The Show', [series, differentSeries]), isNull);
  });

  test('uses the duplicate with large artwork for the same ID', () {
    final thumbnailOnly = _anime(
      5,
      'Sample',
      imageUrl: 'https://cdn.example.com/thumbnail.jpg',
      largeImageUrl: null,
    );
    final blankArtwork = _anime(5, 'Sample', largeImageUrl: ' ');
    final largeArtwork = _anime(5, 'Sample');

    expect(matchTenraiPoster('Sample', [thumbnailOnly, blankArtwork]), isNull);
    expect(
      matchTenraiPoster('Sample', [thumbnailOnly, blankArtwork, largeArtwork]),
      largeArtwork,
    );
  });
}
