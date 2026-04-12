import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/jikan_api_controller.dart';
import 'package:tamashii/models/jikan_models.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

class FakeOnDeviceTextGenerator implements OnDeviceTextGenerator {
  int catalogCount = 0;
  int generateCount = 0;

  @override
  Future<OnDeviceModelCatalog> getModelCatalog() async {
    catalogCount += 1;
    return const OnDeviceModelCatalog(
      activeModel: 'gemini-nano',
      availableModels: <String>['gemini-nano'],
      featureStatus: 3,
    );
  }

  @override
  Future<OnDeviceGenerationResponse> generateText({
    required String prompt,
  }) async {
    generateCount += 1;

    if (prompt.contains('You normalize anime series titles')) {
      return const OnDeviceGenerationResponse(
        text:
            '{"search_title":"Solo Leveling","season_hint":"Season 02","reason":"Removed the season suffix."}',
        modelUsed: 'gemini-nano',
      );
    }

    if (prompt.contains('matching a local anime release title')) {
      return const OnDeviceGenerationResponse(
        text:
            '{"mal_id":58567,"reason":"The Season 2 entry is the best match."}',
        modelUsed: 'gemini-nano',
      );
    }

    throw StateError('Unexpected prompt: $prompt');
  }
}

void main() {
  group('Jikan API controller helpers', () {
    test('parses lookup context JSON wrapped in markdown fences', () {
      final context = parseJikanLookupContextResponse(
        '''
```json
{
  "search_title": "Frieren",
  "season_hint": "Part 2",
  "reason": "Dropped the part marker from the search title."
}
```
''',
        fallbackSearchTitle: 'Fallback',
        fallbackSeasonHint: 'Season 01',
      );

      expect(context.searchTitle, 'Frieren');
      expect(context.seasonHint, 'Season 02');
      expect(context.usedAi, isTrue);
    });

    test('hotness scoring favors strong, active series', () {
      final hotShow = JikanAnimeDetails(
        malId: 1,
        title: 'Hot Show',
        titleEnglish: 'Hot Show',
        titleJapanese: null,
        titleSynonyms: const <String>[],
        url: null,
        type: 'TV',
        status: 'Currently Airing',
        airing: true,
        airedFrom: DateTime(2026, 1, 1),
        score: 8.8,
        scoredBy: 600000,
        rank: 120,
        popularity: 80,
        members: 1500000,
        favorites: 30000,
        season: 'winter',
        year: 2026,
      );
      final coldShow = JikanAnimeDetails(
        malId: 2,
        title: 'Cold Show',
        titleEnglish: 'Cold Show',
        titleJapanese: null,
        titleSynonyms: const <String>[],
        url: null,
        type: 'TV Special',
        status: 'Finished Airing',
        airing: false,
        airedFrom: DateTime(2015, 1, 1),
        score: 6.1,
        scoredBy: 3000,
        rank: 9000,
        popularity: 7000,
        members: 12000,
        favorites: 50,
        season: null,
        year: 2015,
      );

      final hotness = computeJikanHotnessValue(
        hotShow,
        now: DateTime(2026, 4, 12),
      );
      final coldness = computeJikanHotnessValue(
        coldShow,
        now: DateTime(2026, 4, 12),
      );

      expect(hotness, greaterThan(coldness));
      expect(hotness, greaterThan(75));
      expect(coldness, lessThan(40));
    });
  });

  group('Jikan API controller', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('dedupes in-flight work and reuses cached mapping and hotness', () async {
      final prefs = await SharedPreferences.getInstance();
      final generator = FakeOnDeviceTextGenerator();
      int searchCalls = 0;
      int fullCalls = 0;

      final client = MockClient((request) async {
        if (request.url.path == '/v4/anime') {
          searchCalls += 1;
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'mal_id': 58567,
                  'title':
                      'Ore dake Level Up na Ken Season 2: Arise from the Shadow',
                  'title_english':
                      'Solo Leveling Season 2: Arise from the Shadow',
                  'title_japanese':
                      '俺だけレベルアップな件 Season 2 -Arise from the Shadow-',
                  'title_synonyms': <String>['Solo Leveling Second Season'],
                  'titles': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'type': 'English',
                      'title': 'Solo Leveling Season 2: Arise from the Shadow',
                    },
                  ],
                  'type': 'TV',
                  'episodes': 13,
                  'status': 'Finished Airing',
                  'score': 8.55,
                  'popularity': 300,
                  'members': 766612,
                  'favorites': 11371,
                  'season': 'winter',
                  'year': 2025,
                  'synopsis': 'Season 2 synopsis',
                },
              ],
            }),
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        if (request.url.path == '/v4/anime/58567/full') {
          fullCalls += 1;
          return http.Response(
            json.encode(<String, dynamic>{
              'data': <String, dynamic>{
                'mal_id': 58567,
                'title':
                    'Ore dake Level Up na Ken Season 2: Arise from the Shadow',
                'title_english':
                    'Solo Leveling Season 2: Arise from the Shadow',
                'title_japanese':
                    '俺だけレベルアップな件 Season 2 -Arise from the Shadow-',
                'title_synonyms': <String>['Solo Leveling Second Season'],
                'url':
                    'https://myanimelist.net/anime/58567/Ore_dake_Level_Up_na_Ken_Season_2__Arise_from_the_Shadow',
                'type': 'TV',
                'status': 'Finished Airing',
                'airing': false,
                'aired': <String, dynamic>{'from': '2025-01-05T13:00:00+13:00'},
                'score': 8.55,
                'scored_by': 491016,
                'rank': 136,
                'popularity': 300,
                'members': 766612,
                'favorites': 11371,
                'season': 'winter',
                'year': 2025,
              },
            }),
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }

        return http.Response('not found', 404);
      });

      final controller = JikanApiController(
        textGenerator: generator,
        httpClient: client,
        preferences: prefs,
        now: () => DateTime(2026, 4, 12),
      );

      addTearDown(controller.dispose);

      final results = await Future.wait(<Future<JikanHotness?>>[
        controller.getHotnessForSeries('Solo Leveling Season 2'),
        controller.getHotnessForSeries('Solo Leveling Season 2'),
      ]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(results[0]!.malId, 58567);
      expect(results[0]!.value, results[1]!.value);
      expect(searchCalls, 1);
      expect(fullCalls, 1);
      expect(generator.catalogCount, 1);
      expect(generator.generateCount, 2);

      final cached = await controller.getHotnessForSeries(
        'Solo Leveling Season 2',
      );

      expect(cached, isNotNull);
      expect(cached!.malId, 58567);
      expect(searchCalls, 1);
      expect(fullCalls, 1);
      expect(generator.generateCount, 2);
    });
  });
}
