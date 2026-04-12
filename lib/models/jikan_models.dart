import 'package:freezed_annotation/freezed_annotation.dart';

part 'jikan_models.freezed.dart';
part 'jikan_models.g.dart';

@freezed
abstract class JikanAnimeSearchResult with _$JikanAnimeSearchResult {
  const JikanAnimeSearchResult._();

  const factory JikanAnimeSearchResult({
    @JsonKey(name: 'mal_id') required int malId,
    required String title,
    @JsonKey(name: 'title_english') String? titleEnglish,
    String? type,
    int? episodes,
    @JsonKey(
      name: 'images',
      fromJson: _jikanImageUrlFromJson,
      toJson: _jikanImageUrlToJson,
    )
    @Default('')
    String imageUrl,
  }) = _JikanAnimeSearchResult;

  factory JikanAnimeSearchResult.fromJson(Map<String, dynamic> json) =>
      _$JikanAnimeSearchResultFromJson(json);

  String get displayTitle {
    final englishTitle = titleEnglish?.trim();
    if (englishTitle != null && englishTitle.isNotEmpty) {
      return englishTitle;
    }
    return title;
  }
}

String _jikanImageUrlFromJson(Object? images) {
  if (images is! Map) {
    return '';
  }

  final jpg = images['jpg'];
  if (jpg is! Map) {
    return '';
  }

  return (jpg['large_image_url'] ?? jpg['image_url'] ?? '') as String;
}

Map<String, dynamic> _jikanImageUrlToJson(String imageUrl) {
  return <String, dynamic>{
    'jpg': <String, dynamic>{'image_url': imageUrl},
  };
}
