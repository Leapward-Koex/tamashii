// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'show_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookmarkedShowInfo _$BookmarkedShowInfoFromJson(Map<String, dynamic> json) =>
    _BookmarkedShowInfo(
      imageUrl: json['imageUrl'] as String,
      releaseDayOfWeek: (json['releaseDayOfWeek'] as num).toInt(),
      showName: json['showName'] as String,
      jikanId: (json['jikanId'] as num?)?.toInt(),
      source:
          $enumDecodeNullable(_$BookmarkedShowSourceEnumMap, json['source']) ??
          BookmarkedShowSource.subsplease,
    );

Map<String, dynamic> _$BookmarkedShowInfoToJson(_BookmarkedShowInfo instance) =>
    <String, dynamic>{
      'imageUrl': instance.imageUrl,
      'releaseDayOfWeek': instance.releaseDayOfWeek,
      'showName': instance.showName,
      'jikanId': instance.jikanId,
      'source': _$BookmarkedShowSourceEnumMap[instance.source]!,
    };

const _$BookmarkedShowSourceEnumMap = {
  BookmarkedShowSource.subsplease: 'subsplease',
  BookmarkedShowSource.manual: 'manual',
};
