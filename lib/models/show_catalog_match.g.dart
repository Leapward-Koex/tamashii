// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'show_catalog_match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShowCatalogMatch _$ShowCatalogMatchFromJson(Map<String, dynamic> json) =>
    _ShowCatalogMatch(
      entry: json['entry'] == null
          ? null
          : TenraiAnimeSearchResult.fromJson(
              json['entry'] as Map<String, dynamic>,
            ),
      candidates:
          (json['candidates'] as List<dynamic>?)
              ?.map(
                (e) =>
                    TenraiAnimeSearchResult.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <TenraiAnimeSearchResult>[],
      userSelected: json['userSelected'] as bool? ?? false,
      releaseOnly: json['releaseOnly'] as bool? ?? false,
      evidence: json['evidence'] as String?,
    );

Map<String, dynamic> _$ShowCatalogMatchToJson(_ShowCatalogMatch instance) =>
    <String, dynamic>{
      'entry': instance.entry,
      'candidates': instance.candidates,
      'userSelected': instance.userSelected,
      'releaseOnly': instance.releaseOnly,
      'evidence': instance.evidence,
    };
