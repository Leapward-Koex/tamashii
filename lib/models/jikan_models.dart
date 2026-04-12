class JikanAnimeTitle {
  const JikanAnimeTitle({required this.type, required this.title});

  factory JikanAnimeTitle.fromJson(Map<String, dynamic> json) {
    return JikanAnimeTitle(
      type: (json['type'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
    );
  }

  final String type;
  final String title;
}

class JikanAnimeSearchHit {
  const JikanAnimeSearchHit({
    required this.malId,
    required this.title,
    required this.titleEnglish,
    required this.titleJapanese,
    required this.titleSynonyms,
    required this.titles,
    required this.type,
    required this.episodes,
    required this.status,
    required this.score,
    required this.popularity,
    required this.members,
    required this.favorites,
    required this.season,
    required this.year,
    required this.synopsis,
  });

  factory JikanAnimeSearchHit.fromJson(Map<String, dynamic> json) {
    return JikanAnimeSearchHit(
      malId: (json['mal_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      titleEnglish: (json['title_english'] as String?)?.trim(),
      titleJapanese: (json['title_japanese'] as String?)?.trim(),
      titleSynonyms:
          (json['title_synonyms'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(),
      titles:
          (json['titles'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(JikanAnimeTitle.fromJson)
              .toList(),
      type: (json['type'] as String?)?.trim(),
      episodes: (json['episodes'] as num?)?.toInt(),
      status: (json['status'] as String?)?.trim(),
      score: (json['score'] as num?)?.toDouble(),
      popularity: (json['popularity'] as num?)?.toInt(),
      members: (json['members'] as num?)?.toInt(),
      favorites: (json['favorites'] as num?)?.toInt(),
      season: (json['season'] as String?)?.trim(),
      year: (json['year'] as num?)?.toInt(),
      synopsis: (json['synopsis'] as String?)?.trim(),
    );
  }

  final int malId;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String> titleSynonyms;
  final List<JikanAnimeTitle> titles;
  final String? type;
  final int? episodes;
  final String? status;
  final double? score;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? season;
  final int? year;
  final String? synopsis;

  List<String> get allTitles {
    final values = <String>[
      title,
      if (titleEnglish != null) titleEnglish!,
      if (titleJapanese != null) titleJapanese!,
      ...titleSynonyms,
      ...titles.map((entry) => entry.title),
    ];

    final seen = <String>{};
    final deduped = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        deduped.add(trimmed);
      }
    }
    return deduped;
  }

  Map<String, dynamic> toPromptJson() {
    return <String, dynamic>{
      'mal_id': malId,
      'titles': allTitles,
      'type': type,
      'episodes': episodes,
      'status': status,
      'score': score,
      'popularity': popularity,
      'members': members,
      'favorites': favorites,
      'season': season,
      'year': year,
      'synopsis': synopsis,
    };
  }
}

class JikanAnimeDetails {
  const JikanAnimeDetails({
    required this.malId,
    required this.title,
    required this.titleEnglish,
    required this.titleJapanese,
    required this.titleSynonyms,
    required this.url,
    required this.type,
    required this.status,
    required this.airing,
    required this.airedFrom,
    required this.score,
    required this.scoredBy,
    required this.rank,
    required this.popularity,
    required this.members,
    required this.favorites,
    required this.season,
    required this.year,
  });

  factory JikanAnimeDetails.fromJson(Map<String, dynamic> json) {
    final aired = json['aired'];
    final airedMap = aired is Map<String, dynamic> ? aired : null;
    final airedFromValue = airedMap?['from'] as String?;

    return JikanAnimeDetails(
      malId: (json['mal_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      titleEnglish: (json['title_english'] as String?)?.trim(),
      titleJapanese: (json['title_japanese'] as String?)?.trim(),
      titleSynonyms:
          (json['title_synonyms'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(),
      url: (json['url'] as String?)?.trim(),
      type: (json['type'] as String?)?.trim(),
      status: (json['status'] as String?)?.trim(),
      airing: json['airing'] == true,
      airedFrom:
          airedFromValue == null ? null : DateTime.tryParse(airedFromValue),
      score: (json['score'] as num?)?.toDouble(),
      scoredBy: (json['scored_by'] as num?)?.toInt(),
      rank: (json['rank'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      members: (json['members'] as num?)?.toInt(),
      favorites: (json['favorites'] as num?)?.toInt(),
      season: (json['season'] as String?)?.trim(),
      year: (json['year'] as num?)?.toInt(),
    );
  }

  final int malId;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String> titleSynonyms;
  final String? url;
  final String? type;
  final String? status;
  final bool airing;
  final DateTime? airedFrom;
  final double? score;
  final int? scoredBy;
  final int? rank;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? season;
  final int? year;

  String get displayTitle {
    if (titleEnglish != null && titleEnglish!.isNotEmpty) {
      return titleEnglish!;
    }
    return title;
  }
}

class JikanSeriesMapping {
  const JikanSeriesMapping({
    required this.localTitle,
    required this.searchTitle,
    required this.seasonHint,
    required this.malId,
    required this.matchedTitle,
    required this.updatedAt,
    this.reason,
  });

  factory JikanSeriesMapping.fromJson(Map<String, dynamic> json) {
    return JikanSeriesMapping(
      localTitle: (json['localTitle'] as String? ?? '').trim(),
      searchTitle: (json['searchTitle'] as String? ?? '').trim(),
      seasonHint: (json['seasonHint'] as String? ?? '').trim(),
      malId: (json['malId'] as num?)?.toInt() ?? 0,
      matchedTitle: (json['matchedTitle'] as String? ?? '').trim(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reason: (json['reason'] as String?)?.trim(),
    );
  }

  final String localTitle;
  final String searchTitle;
  final String seasonHint;
  final int malId;
  final String matchedTitle;
  final DateTime updatedAt;
  final String? reason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localTitle': localTitle,
      'searchTitle': searchTitle,
      'seasonHint': seasonHint,
      'malId': malId,
      'matchedTitle': matchedTitle,
      'updatedAt': updatedAt.toIso8601String(),
      'reason': reason,
    };
  }
}

class JikanHotness {
  const JikanHotness({
    required this.malId,
    required this.title,
    required this.value,
    required this.updatedAt,
    this.url,
  });

  factory JikanHotness.fromJson(Map<String, dynamic> json) {
    return JikanHotness(
      malId: (json['malId'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      value: (json['value'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      url: (json['url'] as String?)?.trim(),
    );
  }

  final int malId;
  final String title;
  final int value;
  final DateTime updatedAt;
  final String? url;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'malId': malId,
      'title': title,
      'value': value,
      'updatedAt': updatedAt.toIso8601String(),
      'url': url,
    };
  }
}
