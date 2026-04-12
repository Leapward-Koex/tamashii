import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tamashii/services/gemini_nano_service.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';

class FakeOnDeviceTextGenerator implements OnDeviceTextGenerator {
  FakeOnDeviceTextGenerator({
    required this.catalog,
    this.response,
    this.throwOnGenerate = false,
  });

  final OnDeviceModelCatalog catalog;
  final OnDeviceGenerationResponse? response;
  final bool throwOnGenerate;

  @override
  Future<OnDeviceGenerationResponse> generateText({
    required String prompt,
  }) async {
    if (throwOnGenerate) {
      throw Exception('generation failed');
    }
    return response!;
  }

  @override
  Future<OnDeviceModelCatalog> getModelCatalog() async => catalog;
}

class FakeDirectoryLister extends BaseFolderDirectoryLister {
  FakeDirectoryLister(this.folders);

  final List<String> folders;

  @override
  Future<List<String>> listSeriesFolders(String basePath) async => folders;
}

void main() {
  group('Series folder resolution', () {
    test('parses JSON wrapped in markdown fences', () {
      final suggestion = parseAiSuggestion('''
```json
{
  "series_name": "Frieren",
  "season_folder": "Part 2",
  "matched_existing_folder": false,
  "reason": "Part 2 maps cleanly to a season folder."
}
```
''', fallbackSeriesFolderName: 'Fallback');

      expect(suggestion, isNotNull);
      expect(suggestion!.seriesName, 'Frieren');
      expect(suggestion.seasonFolder, 'Season 02');
    });

    test('falls back to Season 01 when AI omits season information', () {
      final suggestion = parseAiSuggestion(
        '{"series_name":"Dungeon Meshi","season_folder":"","matched_existing_folder":false}',
        fallbackSeriesFolderName: 'Fallback',
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.seasonFolder, 'Season 01');
    });

    test(
      'uses AI suggestion and preserves an existing series folder name',
      () async {
        final service = SeriesFolderResolutionService(
          textGenerator: FakeOnDeviceTextGenerator(
            catalog: const OnDeviceModelCatalog(
              activeModel: 'gemini-nano',
              availableModels: <String>['gemini-nano'],
              featureStatus: 3,
            ),
            response: const OnDeviceGenerationResponse(
              text:
                  '{"series_name":"My Existing Series","season_folder":"Season 4","matched_existing_folder":true,"reason":"Clear sequel."}',
              modelUsed: 'gemini-nano',
            ),
          ),
          directoryLister: FakeDirectoryLister(const ['My Existing Series']),
        );

        final plan = await service.plan(
          showTitle: 'My Existing Series S4',
          basePath: '/downloads',
        );

        expect(plan.usedAi, isTrue);
        expect(plan.seriesFolderName, 'My Existing Series');
        expect(plan.seasonFolderName, 'Season 04');
        expect(
          plan.suggestedPath,
          p.join('/downloads', 'My Existing Series', 'Season 04'),
        );
        expect(
          plan.fallbackPath,
          p.join('/downloads', 'My Existing Series S4'),
        );
      },
    );

    test(
      'falls back to the plain series folder when no model is available',
      () async {
        final service = SeriesFolderResolutionService(
          textGenerator: FakeOnDeviceTextGenerator(
            catalog: const OnDeviceModelCatalog(
              activeModel: null,
              availableModels: <String>[],
              featureStatus: 0,
            ),
          ),
          directoryLister: FakeDirectoryLister(const ['Existing Show']),
        );

        final plan = await service.plan(
          showTitle: 'Fresh Show Season 2',
          basePath: '/downloads',
        );

        expect(plan.usedAi, isFalse);
        expect(plan.suggestedPath, p.join('/downloads', 'Fresh Show Season 2'));
        expect(plan.seasonFolderName, isNull);
      },
    );

    test('falls back when AI returns invalid JSON', () async {
      final service = SeriesFolderResolutionService(
        textGenerator: FakeOnDeviceTextGenerator(
          catalog: const OnDeviceModelCatalog(
            activeModel: 'gemini-nano',
            availableModels: <String>['gemini-nano'],
            featureStatus: 3,
          ),
          response: const OnDeviceGenerationResponse(
            text: 'not json',
            modelUsed: 'gemini-nano',
          ),
        ),
        directoryLister: FakeDirectoryLister(const <String>[]),
      );

      final plan = await service.plan(
        showTitle: 'Broken Response Show',
        basePath: '/downloads',
      );

      expect(plan.usedAi, isFalse);
      expect(plan.suggestedPath, p.join('/downloads', 'Broken Response Show'));
    });
  });
}
