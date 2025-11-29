// test/storage_duplicate_prevention_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/models/show_models.dart';

void main() {
  group('Storage Duplicate Prevention Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should not save duplicate episodes to storage', () async {
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      
      // Create duplicate episodes (same show and episode number)
      final episode1 = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test1.jpg',
        page: 'test-page-1',
        releaseDate: DateTime(2025, 7, 26, 10),
        show: 'Test Show',
        timeLabel: '10:00',
        xdcc: 'test1',
      );
      
      final episode2 = ShowInfo(
        downloads: [],
        episode: '1', // Same episode number
        imageUrl: 'test2.jpg', // Different image
        page: 'test-page-2', // Different page
        releaseDate: DateTime(2025, 7, 26, 12), // Different time
        show: 'Test Show', // Same show
        timeLabel: '12:00',
        xdcc: 'test2',
      );
      
      final episode3 = ShowInfo(
        downloads: [],
        episode: '2', // Different episode
        imageUrl: 'test3.jpg',
        page: 'test-page-3',
        releaseDate: DateTime(2025, 7, 26, 14),
        show: 'Test Show', // Same show
        timeLabel: '14:00',
        xdcc: 'test3',
      );
      
      // Cache episodes with duplicates
      await cachedNotifier.cacheEpisodes([episode1, episode2, episode3]);
      
      // Check cached episodes
      final cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      
      // Should only have 2 episodes (episode1/episode2 are duplicates, only one should remain)
      expect(cachedState, hasLength(2));
      
      // Check that we have episode 1 and episode 2, but not both versions of episode 1
      final episodeNumbers = cachedState.map((e) => e.episode).toSet();
      expect(episodeNumbers, containsAll(['1', '2']));
      
      // Verify that the latest version of episode 1 is kept (episode2 has later time)
      final episode1Stored = cachedState.firstWhere((e) => e.episode == '1');
      expect(episode1Stored.timeLabel, '12:00'); // Should be episode2's time
      expect(episode1Stored.releaseDate.hour, 12); // Should be episode2's hour
    });

    test('should remove duplicates when manually adding episodes', () async {
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      
      // Add initial episode
      final initialEpisode = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'initial.jpg',
        page: 'initial-page',
        releaseDate: DateTime(2025, 7, 26, 10),
        show: 'Test Show',
        timeLabel: '10:00',
        xdcc: 'initial',
      );
      
      await cachedNotifier.cacheEpisodes([initialEpisode]);
      
      // Add updated version of same episode
      final updatedEpisode = ShowInfo(
        downloads: [],
        episode: '1', // Same episode
        imageUrl: 'updated.jpg',
        page: 'updated-page',
        releaseDate: DateTime(2025, 7, 26, 12),
        show: 'Test Show', // Same show
        timeLabel: '12:00',
        xdcc: 'updated',
      );
      
      await cachedNotifier.cacheEpisodes([updatedEpisode]);
      
      // Should only have 1 episode total
      final cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(1));
      
      // Should be the updated version
      expect(cachedState[0].timeLabel, '12:00');
      expect(cachedState[0].imageUrl, 'updated.jpg');
    });

    test('should handle duplicates across different shows correctly', () async {
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      
      // Episodes with same episode number but different shows (not duplicates)
      final episode1Show1 = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test1.jpg',
        page: 'test-page-1',
        releaseDate: DateTime(2025, 7, 26, 10),
        show: 'Show A',
        timeLabel: '10:00',
        xdcc: 'test1',
      );
      
      final episode1Show2 = ShowInfo(
        downloads: [],
        episode: '1', // Same episode number
        imageUrl: 'test2.jpg',
        page: 'test-page-2',
        releaseDate: DateTime(2025, 7, 26, 12),
        show: 'Show B', // Different show
        timeLabel: '12:00',
        xdcc: 'test2',
      );
      
      await cachedNotifier.cacheEpisodes([episode1Show1, episode1Show2]);
      
      // Should have both episodes since they're from different shows
      final cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(2));
      
      final showNames = cachedState.map((e) => e.show).toSet();
      expect(showNames, containsAll(['Show A', 'Show B']));
    });
  });
}
