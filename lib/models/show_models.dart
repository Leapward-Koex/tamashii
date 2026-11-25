// lib/models/show_models.dart

// Freezed copies the JSON key annotation onto the generated field.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'show_models.freezed.dart';
part 'show_models.g.dart';

/// The allowed torrent resolutions.
enum ShowResolution { r480, r540, r720, r1080 }

extension ShowResolutionJson on ShowResolution {
  /// Convert enum to the string value expected by the API.
  String toJson() {
    switch (this) {
      case ShowResolution.r480:
        return '480';
      case ShowResolution.r540:
        return '540';
      case ShowResolution.r720:
        return '720';
      case ShowResolution.r1080:
        return '1080';
    }
  }

  /// Parse the API string into our enum.
  static ShowResolution fromJson(String json) {
    switch (json) {
      case '480':
        return ShowResolution.r480;
      case '540':
        return ShowResolution.r540;
      case '720':
        return ShowResolution.r720;
      case '1080':
        return ShowResolution.r1080;
      default:
        throw ArgumentError('Unknown ShowResolution: $json');
    }
  }
}

/// Contains a magnet link at a given resolution.
class ShowDownloadInfo {
  final ShowResolution resolution;
  final String magnet;

  ShowDownloadInfo({required this.resolution, required this.magnet});

  factory ShowDownloadInfo.fromJson(Map<String, dynamic> json) {
    return ShowDownloadInfo(
      resolution: ShowResolutionJson.fromJson(json['res'] as String),
      magnet: json['magnet'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'res': resolution.toJson(), 'magnet': magnet};
  }
}

/// The main show/episode info from the API.
class ShowInfo {
  static final _feedDate = DateFormat('EEE, dd MMM yyyy HH:mm:ss Z', 'en_US');
  static final _shortCacheDate = DateFormat('MM/dd/yy', 'en_US');
  static final _shortCacheDatePrefix = RegExp(r'^\d+/');
  final List<ShowDownloadInfo> downloads;
  final String episode;
  final String imageUrl;
  final String page;
  final DateTime releaseDate;
  final String show;
  final String timeLabel;
  final String xdcc;

  ShowInfo({
    required this.downloads,
    required this.episode,
    required this.imageUrl,
    required this.page,
    required this.releaseDate,
    required this.show,
    required this.timeLabel,
    required this.xdcc,
  });

  factory ShowInfo.fromJson(Map<String, dynamic> json) {
    final String rawDate = json['release_date'] as String;
    late DateTime parsedDate;
    try {
      // Older cached releases start with a numeric month. Dispatching here
      // avoids throwing and catching an exception for each legacy episode.
      parsedDate = _shortCacheDatePrefix.hasMatch(rawDate)
          ? _shortCacheDate.parse(rawDate)
          : _feedDate.parseUTC(rawDate);
    } on FormatException {
      throw FormatException('Invalid release_date format: $rawDate');
    }

    return ShowInfo(
      downloads: (json['downloads'] as List<dynamic>)
          .map(
            (dynamic e) => ShowDownloadInfo.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      episode: json['episode'] as String,
      imageUrl: json['image_url'] as String,
      page: json['page'] as String,
      releaseDate: parsedDate,
      show: json['show'] as String,
      timeLabel: json['time'] as String,
      xdcc: json['xdcc'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    // Use the full format to preserve time information
    final String formattedDate = _feedDate.format(releaseDate);

    return <String, dynamic>{
      'downloads': downloads.map((e) => e.toJson()).toList(),
      'episode': episode,
      'image_url': imageUrl,
      'page': page,
      'release_date': formattedDate,
      'show': show,
      'time': timeLabel,
      'xdcc': xdcc,
    };
  }
}

enum BookmarkedShowSource { subsplease, manual }

@freezed
abstract class BookmarkedShowInfo with _$BookmarkedShowInfo {
  const BookmarkedShowInfo._();

  const factory BookmarkedShowInfo({
    required String imageUrl,
    required int releaseDayOfWeek,
    required String showName,
    // Older installs save MyAnimeList IDs under this key.
    @JsonKey(name: 'jikanId') int? malId,
    @Default(BookmarkedShowSource.subsplease) BookmarkedShowSource source,
  }) = _BookmarkedShowInfo;

  factory BookmarkedShowInfo.fromJson(Map<String, dynamic> json) =>
      _$BookmarkedShowInfoFromJson(json);

  bool get isManualEntry => source == BookmarkedShowSource.manual;

  bool get showsOnHomePage => source == BookmarkedShowSource.subsplease;
}

/// The raw API result is a map from episode-key → [ShowInfo].
typedef SubsPleaseShowApiResult = Map<String, ShowInfo>;
