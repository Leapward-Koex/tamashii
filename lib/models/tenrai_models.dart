// Freezed copies these constructor annotations onto generated fields.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'tenrai_models.freezed.dart';
part 'tenrai_models.g.dart';

@freezed
abstract class TenraiAnimeSearchResult with _$TenraiAnimeSearchResult {
  const TenraiAnimeSearchResult._();

  const factory TenraiAnimeSearchResult({
    @JsonKey(name: 'mal_id') required int malId,
    required String title,
    @JsonKey(name: 'title_english') String? titleEnglish,
    String? type,
    int? episodes,
    String? status,
    bool? airing,
    @JsonKey(
      name: 'images',
      fromJson: _tenraiImageUrlFromJson,
      toJson: _tenraiImageUrlToJson,
    )
    @Default('')
    String imageUrl,
    @JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false)
    String? largeImageUrl,
  }) = _TenraiAnimeSearchResult;

  factory TenraiAnimeSearchResult.fromJson(Map<String, dynamic> json) =>
      _$TenraiAnimeSearchResultFromJson(json);

  String get displayTitle {
    final englishTitle = titleEnglish?.trim();
    if (englishTitle != null && englishTitle.isNotEmpty) {
      return englishTitle;
    }
    return title;
  }

  String? get posterUrl {
    for (final value in [?largeImageUrl, imageUrl]) {
      final url = value.trim();
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.host.isNotEmpty &&
          (uri.isScheme('https') || uri.isScheme('http'))) {
        return url;
      }
    }
    return null;
  }

  String get airingLabel {
    final label = status?.trim();
    if (label != null && label.isNotEmpty) return label;
    return switch (airing) {
      true => 'Currently Airing',
      false => 'Not currently airing',
      null => 'Airing status unknown',
    };
  }

  bool get isCurrentlyAiring =>
      airing == true || status?.trim().toLowerCase() == 'currently airing';
}

Object? _readTenraiLargeImageUrl(Map<dynamic, dynamic> json, String key) {
  return json[key] ?? _tenraiImageVariant(json['images'], 'large_image_url');
}

String? _tenraiImageVariant(Object? images, String sizeKey) {
  if (images is! Map) {
    return null;
  }

  for (final format in const ['jpg', 'webp']) {
    final image = images[format];
    final url = image is Map ? image[sizeKey] : null;
    if (url is String && url.trim().isNotEmpty) {
      return url.trim();
    }
  }
  return null;
}

String _tenraiImageUrlFromJson(Object? images) {
  if (images is! Map) {
    return '';
  }

  for (final format in const ['jpg', 'webp']) {
    final image = images[format];
    if (image is Map) {
      for (final key in const ['large_image_url', 'image_url']) {
        final url = image[key];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }
  }

  return '';
}

Map<String, dynamic> _tenraiImageUrlToJson(String imageUrl) {
  return <String, dynamic>{
    'jpg': <String, dynamic>{'image_url': imageUrl},
  };
}
