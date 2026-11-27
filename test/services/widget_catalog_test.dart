import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/services/widget_catalog.dart';

final _imageBase = Uri.parse('https://subsplease.org');
const _bookmark = BookmarkedShowInfo(
  imageUrl: '/poster.png',
  releaseDayOfWeek: DateTime.monday,
  showName: 'Ferry',
);

ShowInfo _episode(
  String title,
  String number,
  DateTime released, {
  bool hasDownload = true,
}) => ShowInfo(
  downloads: [
    if (hasDownload) ...[
      ShowDownloadInfo(resolution: ShowResolution.r480, magnet: '480'),
      ShowDownloadInfo(resolution: ShowResolution.r1080, magnet: ' '),
      ShowDownloadInfo(resolution: ShowResolution.r720, magnet: '720'),
    ],
  ],
  episode: number,
  imageUrl: 'posters/$title.png',
  page: title,
  releaseDate: released,
  show: title,
  timeLabel: '',
  xdcc: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget publication separates canonical names and posters from download keys', () {
    final now = DateTime.utc(2026, 11, 27);
    final catalog = buildWidgetCatalog(
      watching: [_bookmark],
      releases: [_episode('Ferry', '01', now)],
      folders: {'Ferry': '/downloads/ferry'},
      downloaded: {},
      now: now,
      imageBase: _imageBase,
      matchFor: (target) => ShowCatalogMatch(
        entry: TenraiAnimeSearchResult(
          malId: 43,
          title: target.episode == null ? 'Night Ferry' : 'Night Ferry special',
          imageUrl: 'https://mal.test/cover.jpg',
        ),
      ),
    );
    final watching = (catalog['watching'] as List).single as Map;
    final release = (catalog['releases'] as List).single as Map;
    expect(
      [watching['title'], watching['displayTitle'], watching['folder']],
      ['Ferry', 'Night Ferry', '/downloads/ferry'],
    );
    expect(
      [
        release['title'],
        release['displayTitle'],
        release['key'],
        release['catalogImageUrl'],
      ],
      [
        'Ferry',
        'Night Ferry special',
        'Ferry-01',
        'https://mal.test/cover.jpg',
      ],
    );
  });

  test(
    'publishes watched feed titles and editable weekly schedule separately',
    () {
      final now = DateTime.utc(2026, 11, 27);
      final yesterday = now.subtract(const Duration(hours: 1));
      final catalog = buildWidgetCatalog(
        watching: [
          _bookmark,
          _bookmark.copyWith(
            showName: 'Manual',
            source: BookmarkedShowSource.manual,
          ),
        ],
        releases: [
          _episode('Ferry', '01', now.subtract(const Duration(days: 3))),
          _episode('Ferry', '02', yesterday),
          _episode('Ferry', '02', yesterday),
          _episode('Ferry', '03', now, hasDownload: false),
          _episode('Ferry', '04', now.add(const Duration(hours: 1))),
          _episode('Manual', '01', now),
          _episode('Only has folder', '01', now),
        ],
        folders: {'Ferry': '/ferry', 'Only has folder': '/other'},
        downloaded: {'Ferry-02'},
        now: now,
        imageBase: _imageBase,
      );
      expect(catalog['watching'], [
        {
          'title': 'Ferry',
          'weekday': 1,
          'manual': false,
          'folder': '/ferry',
          'imageUrl': 'https://subsplease.org/poster.png',
        },
        {
          'title': 'Manual',
          'weekday': 1,
          'manual': true,
          'folder': '',
          'imageUrl': 'https://subsplease.org/poster.png',
        },
      ]);
      expect(catalog['releases'], [
        {
          'key': 'Ferry-02',
          'title': 'Ferry',
          'episode': '02',
          'releasedAt': yesterday.millisecondsSinceEpoch,
          'magnet': '720',
          'imageUrl': 'https://subsplease.org/posters/Ferry.png',
        },
      ]);
      expect(catalog['downloaded'], ['Ferry-02']);
    },
  );

  test(
    'published catalog tracks booking, mapping and completion changes',
    () async {
      final episode = _episode(
        'Ferry',
        '01',
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      SharedPreferences.setMockInitialValues({
        'cached_episodes': [jsonEncode(episode.toJson())],
      });
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final container = ProviderContainer.test();
      final saved = container.listen(widgetCatalogProvider.future, (_, _) {});
      expect((await saved.read())['releases'], isEmpty);
      await container.read(bookmarkedSeriesProvider.notifier).add(_bookmark);
      final catalog = await saved.read();
      expect(catalog['releases'], hasLength(1));
      await container
          .read(seriesFolderMappingProvider.notifier)
          .setFolder('Ferry', '/series');
      expect(
        ((await saved.read())['watching'] as List).single['folder'],
        '/series',
      );
      await container
          .read(downloadedTorrentsProvider.notifier)
          .addDownloaded(episode.torrentKey);
      expect((await saved.read())['downloaded'], [episode.torrentKey]);
      await container.read(bookmarkedSeriesProvider.notifier).remove('Ferry');
      expect((await saved.read())['releases'], isEmpty);
    },
  );

  group('headless refresh', () {
    const channel = MethodChannel('test/widget_catalog');
    late List<MethodCall> calls;
    late bool hasCatalog;
    setUp(() {
      calls = [];
      hasCatalog = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'hasCatalog') return hasCatalog;
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('hydrates an upgraded install before touching the network', () async {
      await runWidgetRefresh(
        channel: channel,
        fetch: () async {
          expect(calls.last.method, 'publishCatalog');
          expect(calls.last.arguments['watching'], ['Existing']);
          throw const SocketException('offline');
        },
        readSavedCatalog: () async => {
          'watching': ['Existing'],
        },
        imageBase: _imageBase,
        serviceOptions: {'callbackHandle': 101},
      );
      expect(calls.map((call) => call.method), [
        'hasCatalog',
        'publishCatalog',
        'refreshFinished',
      ]);
      expect(calls[1].arguments['bootstrap'], true);
      expect(calls.last.arguments, false);
    });

    test(
      'successful refresh publishes only feed data and service options',
      () async {
        hasCatalog = true;
        await runWidgetRefresh(
          channel: channel,
          fetch: () async => [_episode('Ferry', '09', DateTime.now())],
          readSavedCatalog: () =>
              throw StateError('Would replace a newer bookmark'),
          imageBase: _imageBase,
          serviceOptions: {'callbackHandle': 101},
        );
        expect(calls.map((call) => call.method), [
          'hasCatalog',
          'publishCatalog',
          'refreshFinished',
        ]);
        final payload = calls[1].arguments as Map;
        expect(payload.keys, unorderedEquals(['releases', 'serviceOptions']));
        expect(payload['releases'].single['key'], 'Ferry-09');
        expect(calls.last.arguments, true);
      },
    );
  });

  test(
    'widget feed distinguishes a failed refresh from an empty success',
    () async {
      final unavailable = SubsPleaseApi(
        httpClient: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(
        unavailable.fetchLatestReleases(),
        throwsA(isA<http.ClientException>()),
      );
      expect(await unavailable.getLatestShowList(), isEmpty);
      final empty = SubsPleaseApi(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(await empty.fetchLatestReleases(), isEmpty);
    },
  );
}
