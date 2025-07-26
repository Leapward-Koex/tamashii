// test/cache_isolated_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
void main() {
  group('Cache Isolated Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should handle date format correctly in cache operations', () async {
      // Test episode with the date format that was causing issues
      final episode = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test.jpg',
        page: 'test-page',
        releaseDate: DateTime(2025, 7, 26), // This will be serialized as "07/26/25"
        show: 'Test Show',
        timeLabel: '12:00',
        xdcc: 'test',
      );

      // Cache the episode manually
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      await cachedNotifier.cacheEpisodes([episode]);
      
      // Check that it was cached correctly
      final cachedState = container.read(cachedEpisodesNotifierProvider);
      expect(cachedState.hasValue, isTrue);
      expect(cachedState.value, hasLength(1));
      expect(cachedState.value![0].show, equals('Test Show'));
      expect(cachedState.value![0].releaseDate.year, equals(2025));
      expect(cachedState.value![0].releaseDate.month, equals(7));
      expect(cachedState.value![0].releaseDate.day, equals(26));
    });

    test('should persist episodes with correct date format', () async {
      final episode = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test.jpg',
        page: 'test-page',
        releaseDate: DateTime(2025, 7, 26),
        show: 'Test Show',
        timeLabel: '12:00',
        xdcc: 'test',
      );

      // Cache the episode
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      await cachedNotifier.cacheEpisodes([episode]);
      
      // Dispose the container to simulate app restart
      container.dispose();
      
      // Create a new container (simulating app restart)
      container = ProviderContainer();
      
      // Check that the episode is still cached after "restart"
      final cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(1));
      expect(cachedState[0].show, equals('Test Show'));
      expect(cachedState[0].releaseDate.year, equals(2025));
      expect(cachedState[0].releaseDate.month, equals(7));
      expect(cachedState[0].releaseDate.day, equals(26));
    });
  });
}
