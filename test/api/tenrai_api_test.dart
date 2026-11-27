import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/tenrai_models.dart';

void main() {
  group('TenraiApi', () {
    test('loads one exact MAL ID and distinguishes a missing entry', () async {
      final api = TenraiApi(
        httpClient: MockClient((request) async {
          expect(request.url.query, isEmpty);
          if (request.url.path == '/v1/anime/20') {
            return http.Response(
              '{"data":{"mal_id":20,"title":"Naruto"}}',
              200,
            );
          }
          expect(request.url.path, '/v1/anime/999');
          return http.Response('Not found', 404);
        }),
      );
      addTearDown(api.close);
      expect((await api.getAnimeById(20))?.title, 'Naruto');
      expect(await api.getAnimeById(999), isNull);
      expect(await api.getAnimeById(0), isNull);
    });

    test('an unexpected ID or malformed result never becomes a link', () async {
      for (final data in ['{"mal_id":21,"title":"Other"}', '[]', 'null']) {
        final api = TenraiApi(
          httpClient: MockClient(
            (_) async => http.Response('{"data":$data}', 200),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          api.getAnimeById(20),
          throwsA(isA<TenraiApiException>()),
        );
      }
    });

    test('searchAnime parses anime search results', () async {
      final api = TenraiApi(
        httpClient: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'api.tenrai.org');
          expect(request.url.path, '/v1/anime');
          expect(request.url.queryParameters['q'], 'naruto');
          expect(request.url.queryParameters['limit'], '10');
          expect(request.headers['accept'], 'application/json');
          expect(request.headers.containsKey('x-server-key'), isFalse);

          return http.Response('''
{
  "pagination": {"current_page": 1},
  "data": [
    {
      "mal_id": 20,
      "title": "Naruto",
      "title_english": "Naruto",
      "type": "TV",
      "episodes": 220,
      "images": {
        "jpg": {
          "image_url": "https://cdn.example.com/naruto.jpg"
        }
      }
    }
  ]
}
''', 200);
        }),
      );
      addTearDown(api.close);

      final results = await api.searchAnime('  naruto  ');

      expect(results, hasLength(1));
      expect(results.single.malId, 20);
      expect(results.single.displayTitle, 'Naruto');
      expect(results.single.type, 'TV');
      expect(results.single.episodes, 220);
      expect(results.single.imageUrl, 'https://cdn.example.com/naruto.jpg');
      expect(results.single.largeImageUrl, isNull);
    });

    test(
      'searchAnime decodes Unicode titles in an unlabelled response',
      () async {
        final api = TenraiApi(
          httpClient: MockClient(
            (_) async => http.Response.bytes(
              utf8.encode('{"data":[{"mal_id":1,"title":"葬送のフリーレン"}]}'),
              200,
            ),
          ),
        );
        addTearDown(api.close);

        final results = await api.searchAnime('フリーレン');
        expect(results.single.displayTitle, '葬送のフリーレン');
      },
    );

    test('searchAnime uses WebP artwork when JPEG is unavailable', () async {
      final api = TenraiApi(
        httpClient: MockClient(
          (_) async => http.Response('''
{
  "data": [{
    "mal_id": 52991,
    "title": "Sousou no Frieren",
    "title_english": "Frieren: Beyond Journey's End",
    "images": {
      "jpg": {"large_image_url": ""},
      "webp": {"large_image_url": "https://cdn.example.com/frieren.webp"}
    }
  }]
}
''', 200),
        ),
      );
      addTearDown(api.close);

      final results = await api.searchAnime('Frieren');
      expect(results.single.displayTitle, "Frieren: Beyond Journey's End");
      expect(results.single.imageUrl, 'https://cdn.example.com/frieren.webp');
      expect(
        results.single.largeImageUrl,
        'https://cdn.example.com/frieren.webp',
      );
    });

    test('loads related anime with full metadata in a single batch', () async {
      final requests = <Uri>[];
      final api = TenraiApi(
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path.endsWith('/relations')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'entry': [
                      {'type': 'manga', 'mal_id': 22},
                      {'type': 'anime', 'mal_id': 23},
                      {'type': 'anime', 'mal_id': 23},
                    ],
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'mal_id': 23,
                  'title': 'Another title',
                  'status': 'Currently Airing',
                  'airing': true,
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final result = (await api.relatedAnime(12)).single;
      expect(requests.map((uri) => uri.path), [
        '/v1/anime/12/relations',
        '/v1/anime',
      ]);
      expect(requests.last.queryParameters, {'ids': '12,23', 'limit': '2'});
      expect(result.airingLabel, 'Currently Airing');
      expect(result.isCurrentlyAiring, isTrue);
      expect(TenraiAnimeSearchResult.fromJson(result.toJson()), result);
    });

    test(
      'legacy entries retain unknown status and use the best valid poster',
      () {
        final result = TenraiAnimeSearchResult.fromJson({
          'mal_id': 1,
          'title': 'Legacy',
        });
        expect(result.airingLabel, 'Airing status unknown');
        expect(result.posterUrl, isNull);
        expect(
          result.copyWith(airing: false).airingLabel,
          'Not currently airing',
        );
        expect(
          result.copyWith(status: 'Not yet aired').airingLabel,
          'Not yet aired',
        );
        expect(
          result
              .copyWith(
                largeImageUrl: 'bad.jpg',
                imageUrl: 'https://example.org/show.jpg',
              )
              .posterUrl,
          'https://example.org/show.jpg',
        );
      },
    );

    test('preserves the large poster alongside the schedule artwork', () {
      final result = TenraiAnimeSearchResult.fromJson({
        'mal_id': 52991,
        'title': 'Sousou no Frieren',
        'images': {
          'jpg': {'image_url': 'https://cdn.example.com/frieren.jpg'},
          'webp': {'large_image_url': 'https://cdn.example.com/frieren.webp'},
        },
      });

      expect(result.imageUrl, 'https://cdn.example.com/frieren.jpg');
      expect(result.largeImageUrl, 'https://cdn.example.com/frieren.webp');
      expect(result.posterUrl, 'https://cdn.example.com/frieren.webp');
      expect(TenraiAnimeSearchResult.fromJson(result.toJson()), result);
    });

    test(
      'searchAnime cancels a stalled response body after the deadline',
      () async {
        final aborted = Completer<void>();
        final api = TenraiApi(
          timeout: const Duration(milliseconds: 10),
          httpClient: MockClient.streaming((request, _) async {
            final body = StreamController<List<int>>();
            final abortTrigger =
                (request as http.AbortableRequest).abortTrigger!;
            unawaited(
              abortTrigger.then((_) async {
                aborted.complete();
                await body.close();
              }),
            );
            return http.StreamedResponse(body.stream, 200);
          }),
        );
        addTearDown(api.close);

        await expectLater(
          api.searchAnime('naruto'),
          throwsA(
            isA<TenraiApiException>().having(
              (error) => error.message,
              'message',
              'Tenrai search timed out.',
            ),
          ),
        );
        await aborted.future.timeout(const Duration(seconds: 1));
      },
    );

    test('searchAnime throws a readable message for API failures', () async {
      final api = TenraiApi(
        httpClient: MockClient((request) async {
          return http.Response('''
{
  "status": 504,
  "message": "The upstream service did not respond in time.",
  "path": "/v1/anime"
}
''', 504);
        }),
      );

      expect(
        () => api.searchAnime('naruto'),
        throwsA(
          isA<TenraiApiException>().having(
            (error) => error.message,
            'message',
            'The upstream service did not respond in time.',
          ),
        ),
      );
    });

    final start = DateTime.utc(2026, 11, 25);
    final retryHeaders = {
      'delay seconds': '3',
      'HTTP date': HttpDate.format(start.add(const Duration(seconds: 3))),
    };
    for (final retryHeader in retryHeaders.entries) {
      test('searchAnime respects Retry-After as ${retryHeader.key}', () async {
        var now = start;
        var requestCount = 0;
        final api = TenraiApi(
          now: () => now,
          httpClient: MockClient((_) async {
            requestCount += 1;
            if (requestCount == 1) {
              return http.Response(
                '',
                429,
                headers: {'retry-after': retryHeader.value},
              );
            }
            return http.Response('{"data":[]}', 200);
          }),
        );
        addTearDown(api.close);

        await expectLater(
          api.searchAnime('Naruto'),
          throwsA(
            isA<TenraiApiException>().having(
              (error) => error.message,
              'message',
              contains('Try again in 3 seconds'),
            ),
          ),
        );

        now = start.add(const Duration(seconds: 2));
        await expectLater(
          api.searchAnime('Frieren'),
          throwsA(
            isA<TenraiApiException>().having(
              (error) => error.message,
              'message',
              contains('Try again in 1 second.'),
            ),
          ),
        );
        expect(requestCount, 1);

        now = start.add(const Duration(seconds: 3));
        expect(await api.searchAnime('Frieren'), isEmpty);
        expect(requestCount, 2);
      });
    }

    test('searchAnime short-circuits blank queries', () async {
      var requestCount = 0;
      final api = TenraiApi(
        httpClient: MockClient((request) async {
          requestCount += 1;
          return http.Response('{"data":[]}', 200);
        }),
      );

      final results = await api.searchAnime('   ');

      expect(results, isEmpty);
      expect(requestCount, 0);
    });
  });
}
