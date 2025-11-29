// lib/models/show_models.dart

import 'package:intl/intl.dart';

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
    // parse date from various formats
    final String rawDate = json['release_date'] as String;
    late DateTime parsedDate;
    try {
      // Try RFC format first (from API): EEE, dd MMM yyyy HH:mm:ss Z
      parsedDate = DateFormat(
        'EEE, dd MMM yyyy HH:mm:ss Z',
        'en_US',
      ).parseUTC(rawDate);
    } catch (error) {
      try {
        // Try short format (from cache): MM/dd/yy
        parsedDate = DateFormat('MM/dd/yy', 'en_US').parse(rawDate);
      } catch (secondError) {
        throw FormatException('Invalid release_date format: $rawDate');
      }
    }

    return ShowInfo(
      downloads:
          (json['downloads'] as List<dynamic>)
              .map(
                (dynamic e) =>
                    ShowDownloadInfo.fromJson(e as Map<String, dynamic>),
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
    final String formattedDate = DateFormat(
      'EEE, dd MMM yyyy HH:mm:ss Z',
      'en_US',
    ).format(releaseDate);

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

class BookmarkedShowInfo {
  final String imageUrl;
  final int releaseDayOfWeek;
  final String showName;

  BookmarkedShowInfo({
    required this.imageUrl,
    required this.releaseDayOfWeek,
    required this.showName,
  });

  factory BookmarkedShowInfo.fromJson(Map<String, dynamic> json) {
    return BookmarkedShowInfo(
      imageUrl: json['imageUrl'] as String,
      releaseDayOfWeek: json['releaseDayOfWeek'] as int,
      showName: json['showName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'imageUrl': imageUrl,
      'releaseDayOfWeek': releaseDayOfWeek,
      'showName': showName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkedShowInfo &&
          runtimeType == other.runtimeType &&
          showName == other.showName;

  @override
  int get hashCode => showName.hashCode;
}

/// The raw API result is a map from episode-key → [ShowInfo].
typedef SubsPleaseShowApiResult = Map<String, ShowInfo>;
