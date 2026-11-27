import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/services/torrent_service_options.dart';

part 'widget_catalog.g.dart';

const _widgetChannel = MethodChannel('tamashii/widget');

String _artworkUrl(String path, Uri base) {
  final uri = Uri.tryParse(path.trim());
  if (uri == null || path.trim().isEmpty) return '';
  final resolved = base.resolveUri(uri);
  return resolved.hasAuthority &&
          (resolved.scheme == 'http' || resolved.scheme == 'https')
      ? resolved.toString()
      : '';
}

// Keep enough instants for a local date or time-zone change. Android selects
// the current calendar day both when drawing a row and when accepting its tap.
List<Map<String, Object>> _releaseRows(
  Iterable<ShowInfo> releases,
  DateTime now,
  Uri imageBase,
  ShowCatalogMatch? Function(ShowCatalogTarget)? matchFor,
) {
  final oldest = now.subtract(const Duration(days: 2));
  final rows = <String, Map<String, Object>>{};
  for (final show in releases) {
    if (show.releaseDate.isBefore(oldest) || show.releaseDate.isAfter(now)) {
      continue;
    }
    final download = show.bestDownload;
    if (download == null) continue;
    final entry = matchFor?.call(ShowCatalogTarget.fromRelease(show))?.entry;
    rows[show.torrentKey] = {
      'key': show.torrentKey,
      'title': show.show,
      if (entry != null) 'displayTitle': entry.displayTitle,
      'episode': show.episode,
      'releasedAt': show.releaseDate.millisecondsSinceEpoch,
      'magnet': download.magnet.trim(),
      'imageUrl': _artworkUrl(show.imageUrl, imageBase),
      if (entry?.posterUrl case final String poster) 'catalogImageUrl': poster,
    };
  }
  return rows.values.toList();
}

Map<String, Object> buildWidgetCatalog({
  required List<BookmarkedShowInfo> watching,
  required List<ShowInfo> releases,
  required Map<String, String> folders,
  required Set<String> downloaded,
  required DateTime now,
  required Uri imageBase,
  ShowCatalogMatch? Function(ShowCatalogTarget)? matchFor,
}) {
  final feedTitles = watching
      .where((show) => show.showsOnHomePage)
      .map((show) => show.showName)
      .toSet();
  return {
    'watching': watching.map((show) {
      final entry = matchFor?.call(ShowCatalogTarget.fromSchedule(show))?.entry;
      return {
        'title': show.showName,
        if (entry != null) 'displayTitle': entry.displayTitle,
        'weekday': show.releaseDayOfWeek,
        'manual': show.isManualEntry,
        'folder': folders[show.showName] ?? '',
        'imageUrl': _artworkUrl(entry?.posterUrl ?? show.imageUrl, imageBase),
      };
    }).toList(),
    'releases': _releaseRows(
      releases.where((episode) => feedTitles.contains(episode.show)),
      now,
      imageBase,
      matchFor,
    ),
    'downloaded': downloaded.toList(),
  };
}

/// Also used by a newly added widget when an app upgrade has never opened the UI.
@riverpod
Future<Map<String, Object>> widgetCatalog(Ref ref) async {
  final imageBase = Uri.parse(
    ref.watch(subsPleaseApiProvider.select((api) => api.baseUrl)),
  );
  final (watching, releases, folders, downloaded, _) = await (
    ref.watch(bookmarkedSeriesProvider.future),
    ref.watch(cachedEpisodesProvider.future),
    ref.watch(seriesFolderMappingProvider.future),
    ref.watch(downloadedTorrentsProvider.future),
    ref.watch(catalogCacheReadyProvider.future),
  ).wait;
  if (!ref.mounted) return {};
  return buildWidgetCatalog(
    watching: watching,
    releases: releases,
    folders: folders,
    downloaded: downloaded,
    now: DateTime.now(),
    imageBase: imageBase,
    matchFor: (target) => ref.watch(cachedShowCatalogMatchProvider(target)),
  );
}

Future<void> publishWidgetCatalog(Map<String, Object> catalog) async {
  try {
    await _widgetChannel.invokeMethod<void>('publishCatalog', {
      ...catalog,
      'serviceOptions': torrentWidgetStartOptions(),
    });
  } on PlatformException catch (error) {
    debugPrint('Could not update the Android widget: $error');
  }
}

/// Starts in a dedicated Flutter engine launched by Android's widget scheduler.
@pragma('vm:entry-point')
Future<void> refreshWidgetCatalog() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = http.Client();
  final api = SubsPleaseApi(httpClient: client);
  final container = ProviderContainer();
  try {
    await runWidgetRefresh(
      channel: _widgetChannel,
      fetch: () async {
        await container.read(catalogCacheReadyProvider.future);
        return api.fetchLatestReleases();
      },
      imageBase: Uri.parse(api.baseUrl),
      matchFor: (target) =>
          container.read(cachedShowCatalogMatchProvider(target)),
      serviceOptions: torrentWidgetStartOptions(),
      readSavedCatalog: () {
        // The headless engine has its own preferences cache and providers.
        final saved = container.listen(widgetCatalogProvider.future, (_, _) {});
        return saved.read();
      },
    );
  } finally {
    client.close();
    container.dispose();
  }
}

Future<void> runWidgetRefresh({
  required MethodChannel channel,
  required Future<List<ShowInfo>> Function() fetch,
  required Future<Map<String, Object>> Function() readSavedCatalog,
  required Uri imageBase,
  required Map<String, dynamic> serviceOptions,
  ShowCatalogMatch? Function(ShowCatalogTarget)? matchFor,
}) async {
  var success = false;
  try {
    final hasCatalog = await channel.invokeMethod<bool>('hasCatalog') ?? false;
    if (!hasCatalog) {
      await channel.invokeMethod<void>('publishCatalog', {
        ...await readSavedCatalog(),
        'serviceOptions': serviceOptions,
        'bootstrap': true,
      });
    }
    final releases = await fetch().timeout(const Duration(seconds: 20));
    // A delayed response must never replace bookmarks, folders or completion
    // history changed by the user while this refresh was in flight.
    await channel.invokeMethod<void>('publishCatalog', {
      'releases': _releaseRows(releases, DateTime.now(), imageBase, matchFor),
      'serviceOptions': serviceOptions,
    });
    success = true;
  } catch (error) {
    debugPrint('Could not refresh Android widget releases: $error');
  } finally {
    await channel.invokeMethod<void>('refreshFinished', success);
  }
}
