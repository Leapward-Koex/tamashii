import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/gemini_nano_prompts.dart';

void main() {
  group('Gemini Nano prompts', () {
    test('season inference prompt includes the raw title', () {
      final prompt = buildSeasonInferencePrompt('Show Name Season 4');

      expect(prompt, contains('Title: Show Name Season 4'));
      expect(prompt, contains('Season: Season NN or Unknown'));
    });

    test('series folder prompt includes existing folder context', () {
      final prompt = buildSeriesFolderPrompt(
        showTitle: 'Show Name part 4',
        existingSeriesFolders: const ['Show Name', 'Another Series'],
      );

      expect(prompt, contains('Raw title:\nShow Name part 4'));
      expect(prompt, contains('"series_name"'));
      expect(prompt, contains('Show Name'));
      expect(prompt, contains('Another Series'));
    });

    test('jikan lookup prompt includes raw title and JSON fields', () {
      final prompt = buildJikanLookupPreparationPrompt(
        'Solo Leveling Season 2',
      );

      expect(prompt, contains('Raw title:\nSolo Leveling Season 2'));
      expect(prompt, contains('"search_title"'));
      expect(prompt, contains('"season_hint"'));
    });

    test('jikan candidate selection prompt includes candidate payload', () {
      final prompt = buildJikanCandidateSelectionPrompt(
        rawTitle: 'Solo Leveling Season 2',
        searchTitle: 'Solo Leveling',
        seasonHint: 'Season 02',
        candidates: const <Map<String, dynamic>>[
          <String, dynamic>{
            'mal_id': 58567,
            'titles': <String>['Solo Leveling Season 2: Arise from the Shadow'],
          },
        ],
      );

      expect(prompt, contains('Raw title:\nSolo Leveling Season 2'));
      expect(prompt, contains('Season hint:\nSeason 02'));
      expect(prompt, contains('"mal_id": 58567'));
    });
  });
}
