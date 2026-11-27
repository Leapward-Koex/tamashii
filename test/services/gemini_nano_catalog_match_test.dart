import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/services/gemini_nano_catalog_match.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

class _Generator implements OnDeviceTextGenerator {
  _Generator(this.reply);

  final FutureOr<String> Function() reply;
  String? prompt;

  @override
  Future<OnDeviceGenerationResponse> generateText({
    required String prompt,
    bool allowModelDownload = true,
  }) async {
    expect(allowModelDownload, isFalse);
    this.prompt = prompt;
    return OnDeviceGenerationResponse(text: await reply(), modelUsed: 'nano');
  }

  @override
  Future<OnDeviceModelCatalog> getModelCatalog() => throw UnimplementedError();
}

const special = TenraiAnimeSearchResult(
  malId: 10,
  title: 'Kumo no Yume',
  titleEnglish: 'Cloud Dream',
  type: 'Special',
  episodes: 1,
);
const sideStory = TenraiAnimeSearchResult(
  malId: 11,
  title: 'Kumo no Natsu',
  titleEnglish: 'Cloud Summer',
  type: 'Special',
  episodes: 1,
);

void main() {
  Future<TenraiAnimeSearchResult?> suggest(
    _Generator generator, {
    String source = 'Kumo',
    String episode = 'Dream Special',
    List<TenraiAnimeSearchResult> candidates = const [special, sideStory],
  }) => suggestCatalogMatch(
    generator: generator,
    sourceTitle: source,
    episode: episode,
    candidates: candidates,
  );

  test(
    'uses a listed ID corroborated by a title or release subtitle',
    () async {
      final generator = _Generator(() => '{"mal_id":10}');
      final match = await suggest(generator, source: 'Cloud');
      expect(match, special);
      expect(generator.prompt, contains('"episode_label":"Dream Special"'));
      expect(generator.prompt, contains('"format":"Special"'));
      expect(generator.prompt, contains('"english":"Cloud Summer"'));
    },
  );

  test('accepts an exact distinctive single-word alias', () async {
    final generator = _Generator(() => '```json\n{"mal_id":10}\n```');
    expect(
      await suggest(
        generator,
        source: 'フリーレン',
        episode: '08',
        candidates: [special.copyWith(title: 'フリーレン')],
      ),
      isNotNull,
    );
  });

  test(
    'returns no suggestion for uncorroborated or malformed output',
    () async {
      for (final response in [
        '{"mal_id":11}',
        '{"mal_id":999}',
        '{"mal_id":null}',
        '{"mal_id":"10"}',
        '{"mal_id":10,"uncertain":true}',
        '10',
        'unknown',
      ]) {
        expect(
          await suggest(_Generator(() => response), source: 'Cloud'),
          isNull,
        );
      }
    },
  );

  test(
    'abstains when only the common series or format is identified',
    () async {
      final generator = _Generator(() => '{"mal_id":10}');
      expect(
        await suggest(generator, source: 'Special', episode: 'OVA'),
        isNull,
      );
      expect(
        await suggest(
          generator,
          source: 'Cloud Dream',
          episode: 'SP',
          candidates: [
            special,
            special.copyWith(malId: 12, title: 'Kumo no Yume: Extra'),
          ],
        ),
        isNull,
      );
      expect(generator.prompt, isNull);
    },
  );

  test('leaves disambiguation to the user when generation fails', () async {
    final generator = _Generator(
      () => throw PlatformException(code: 'model_not_ready'),
    );
    expect(await suggest(generator, source: 'Cloud'), isNull);
    expect(generator.prompt, isNotNull);
    expect(await suggest(generator, candidates: []), isNull);
  });
}
