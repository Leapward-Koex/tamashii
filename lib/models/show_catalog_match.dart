import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';

part 'show_catalog_match.freezed.dart';
part 'show_catalog_match.g.dart';

@freezed
abstract class ShowCatalogTarget with _$ShowCatalogTarget {
  const ShowCatalogTarget._();

  const factory ShowCatalogTarget({
    required String title,
    String? episode,
    String? page,
    @Default(false) bool forceReleaseScope,
    int? savedMalId,
    String? savedImageUrl,
  }) = _ShowCatalogTarget;

  factory ShowCatalogTarget.fromRelease(ShowInfo release) => ShowCatalogTarget(
    title: release.show,
    episode: release.episode,
    page: release.page,
  );

  factory ShowCatalogTarget.fromSchedule(
    BookmarkedShowInfo bookmark, {
    ShowInfo? latestRelease,
  }) => ShowCatalogTarget(
    title: bookmark.showName,
    page: latestRelease?.page,
    savedMalId: bookmark.malId,
    savedImageUrl: bookmark.imageUrl,
  );

  /// Integer episodes (including corrected releases) share a season match.
  /// Episode zero, fractional episodes and unfamiliar labels get their own.
  bool get isReleaseScoped {
    final label = episode;
    if (label == null) return false;
    if (forceReleaseScope) return true;
    final number = _regularEpisode.firstMatch(label.trim())?[1];
    return number == null ||
        (int.tryParse(number) ?? 0) == 0 ||
        _specialTitle.hasMatch(title.trim());
  }

  /// A schedule bookmark only knows its title. Keep its key identical to
  /// regular releases even when the feed page is unavailable on first visit.
  String get scopeKey {
    final source = title.trim().toLowerCase();
    return jsonEncode(
      isReleaseScoped ? ['release', source, page, episode] : ['series', source],
    );
  }

  /// Even an ordinary number can be a special, e.g. a recap labeled "13".
  ShowCatalogTarget get forThisRelease => episode == null || isReleaseScoped
      ? this
      : copyWith(forceReleaseScope: true);

  ({bool exists, TenraiAnimeSearchResult? entry, bool releaseOnly})
  effectiveOverride(Map<String, TenraiAnimeSearchResult?> choices) {
    if (episode != null) {
      final exact = forThisRelease.scopeKey;
      if (choices.containsKey(exact)) {
        return (exists: true, entry: choices[exact], releaseOnly: true);
      }
    }
    final key = scopeKey;
    return (
      exists: choices.containsKey(key),
      entry: choices[key],
      releaseOnly: isReleaseScoped,
    );
  }
}

final _regularEpisode = RegExp(
  r'^(?:ep(?:isode)?\s*)?(\d+)(?:v\d+)?$',
  caseSensitive: false,
);
final _specialTitle = RegExp(
  r'\b(?:ova|oad|sp)\d*\b'
  r'|\b(?:specials?|recap|movie|film|gekijouban|preview)\s*[:–—-]'
  r'|[:–—-]\s*(?:specials?|recap|movie|film|gekijouban|preview)\b'
  r'|\S\s+(?:specials?|recap|movie|film|gekijouban|preview)(?:\s+\d+)?$',
  caseSensitive: false,
);

bool hasSpecialTitleMarker(String title) =>
    _specialTitle.hasMatch(title.trim());

@freezed
abstract class ShowCatalogMatch with _$ShowCatalogMatch {
  const factory ShowCatalogMatch({
    TenraiAnimeSearchResult? entry,
    @Default(<TenraiAnimeSearchResult>[])
    List<TenraiAnimeSearchResult> candidates,
    @Default(false) bool userSelected,
    @Default(false) bool releaseOnly,
    String? evidence,
  }) = _ShowCatalogMatch;

  factory ShowCatalogMatch.fromJson(Map<String, dynamic> json) =>
      _$ShowCatalogMatchFromJson(json);
}
