// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jikan_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JikanAnimeSearchResult _$JikanAnimeSearchResultFromJson(
  Map<String, dynamic> json,
) => _JikanAnimeSearchResult(
  malId: (json['mal_id'] as num).toInt(),
  title: json['title'] as String,
  titleEnglish: json['title_english'] as String?,
  type: json['type'] as String?,
  episodes: (json['episodes'] as num?)?.toInt(),
  imageUrl:
      json['images'] == null ? '' : _jikanImageUrlFromJson(json['images']),
);

Map<String, dynamic> _$JikanAnimeSearchResultToJson(
  _JikanAnimeSearchResult instance,
) => <String, dynamic>{
  'mal_id': instance.malId,
  'title': instance.title,
  'title_english': instance.titleEnglish,
  'type': instance.type,
  'episodes': instance.episodes,
  'images': _jikanImageUrlToJson(instance.imageUrl),
};
