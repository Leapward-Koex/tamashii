// test/cache_fix_verification.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';

void main() {
  group('Cache Type Safety Fix Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('handles type casting errors gracefully', () async {
      // Simulate corrupted data that could cause the original error
      SharedPreferences.setMockInitialValues({
        'cached_episodes':
            'invalid_string_instead_of_list', // This would cause the error
      });

      final container = ProviderContainer();

      // This should not throw the TypeError anymore
      final episodes = await container.read(cachedEpisodesProvider.future);

      // Should return empty list instead of crashing
      expect(episodes, isEmpty);

      container.dispose();
    });

    test('works correctly with valid data', () async {
      final container = ProviderContainer();
      final notifier = container.read(cachedEpisodesProvider.notifier);

      final testEpisode = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test.jpg',
        page: 'test-show',
        releaseDate: DateTime(2024),
        show: 'Test Show',
        timeLabel: '12:00',
        xdcc: 'test',
      );

      // Add episode
      await notifier.cacheEpisodes([testEpisode]);

      // Verify it works
      final episodes = await container.read(cachedEpisodesProvider.future);
      expect(episodes, hasLength(1));
      expect(episodes[0].show, equals('Test Show'));

      container.dispose();
    });

    test('handles null state gracefully', () async {
      final container = ProviderContainer();
      final notifier = container.read(cachedEpisodesProvider.notifier);

      // These operations should work even if state.value is null initially
      await notifier.removeSeriesFromCache('NonExistent Show');
      await notifier.cleanupOldEpisodes();

      // Should not throw errors
      final episodes = await container.read(cachedEpisodesProvider.future);
      expect(episodes, isEmpty);

      container.dispose();
    });
  });
}
