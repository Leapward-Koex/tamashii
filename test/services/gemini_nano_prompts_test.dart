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
  });
}
