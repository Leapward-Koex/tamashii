import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tamashii/api/jikan_api.dart';

void main() {
  group('JikanApi', () {
    test('searchAnime parses anime search results', () async {
      final api = JikanApi(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v4/anime');
          expect(request.url.queryParameters['q'], 'naruto');
          expect(request.url.queryParameters['limit'], '10');

          return http.Response('''
{
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

      final results = await api.searchAnime('naruto');

      expect(results, hasLength(1));
      expect(results.single.malId, 20);
      expect(results.single.displayTitle, 'Naruto');
      expect(results.single.imageUrl, 'https://cdn.example.com/naruto.jpg');
    });

    test('searchAnime throws a readable message for API failures', () async {
      final api = JikanApi(
        httpClient: MockClient((request) async {
          return http.Response('''
{
  "message": "Jikan failed to connect to MyAnimeList."
}
''', 504);
        }),
      );

      expect(
        () => api.searchAnime('naruto'),
        throwsA(
          isA<JikanApiException>().having(
            (error) => error.message,
            'message',
            'Jikan failed to connect to MyAnimeList.',
          ),
        ),
      );
    });

    test('searchAnime short-circuits blank queries', () async {
      var requestCount = 0;
      final api = JikanApi(
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
