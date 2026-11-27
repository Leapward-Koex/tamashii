// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenrai_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TenraiAnimeSearchResult _$TenraiAnimeSearchResultFromJson(
  Map<String, dynamic> json,
) => _TenraiAnimeSearchResult(
  malId: (json['mal_id'] as num).toInt(),
  title: json['title'] as String,
  titleEnglish: json['title_english'] as String?,
  type: json['type'] as String?,
  episodes: (json['episodes'] as num?)?.toInt(),
  imageUrl: json['images'] == null
      ? ''
      : _tenraiImageUrlFromJson(json['images']),
  largeImageUrl: _readTenraiLargeImageUrl(json, 'largeImageUrl') as String?,
);

Map<String, dynamic> _$TenraiAnimeSearchResultToJson(
  _TenraiAnimeSearchResult instance,
) => <String, dynamic>{
  'mal_id': instance.malId,
  'title': instance.title,
  'title_english': instance.titleEnglish,
  'type': instance.type,
  'episodes': instance.episodes,
  'images': _tenraiImageUrlToJson(instance.imageUrl),
  'largeImageUrl': ?instance.largeImageUrl,
};
