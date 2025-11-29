// test/cache_duplicate_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/models/show_models.dart';

void main() {
  group('Cache Duplicate Integration Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should prevent storing duplicate episodes in real cache', () async {
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      
      // Add initial episode
      final episode1 = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'version1.jpg',
        page: 'page-version1',
        releaseDate: DateTime(2025, 7, 26, 10),
        show: 'Attack on Titan',
        timeLabel: '10:00',
        xdcc: 'version1',
      );
      
      await cachedNotifier.cacheEpisodes([episode1]);
      
      // Verify initial state
      var cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(1));
      expect(cachedState[0].imageUrl, 'version1.jpg');
      
      // Add updated version of same episode
      final episode1Updated = ShowInfo(
        downloads: [],
        episode: '1', // Same episode
        imageUrl: 'version2.jpg', // Updated content
        page: 'page-version2',
        releaseDate: DateTime(2025, 7, 26, 12),
        show: 'Attack on Titan', // Same show
        timeLabel: '12:00',
        xdcc: 'version2',
      );
      
      await cachedNotifier.cacheEpisodes([episode1Updated]);
      
      // Should still have only 1 episode, but updated
      cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(1));
      expect(cachedState[0].imageUrl, 'version2.jpg'); // Should be updated version
      expect(cachedState[0].timeLabel, '12:00');
    });

    test('should preserve episodes from different shows with same episode numbers', () async {
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      
      final episode1ShowA = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'showA-ep1.jpg',
        page: 'show-a-page',
        releaseDate: DateTime(2025, 7, 26, 10),
        show: 'Attack on Titan',
        timeLabel: '10:00',
        xdcc: 'showA-ep1',
      );
      
      final episode1ShowB = ShowInfo(
        downloads: [],
        episode: '1', // Same episode number
        imageUrl: 'showB-ep1.jpg',
        page: 'show-b-page',
        releaseDate: DateTime(2025, 7, 26, 11),
        show: 'One Piece', // Different show
        timeLabel: '11:00',
        xdcc: 'showB-ep1',
      );
      
      await cachedNotifier.cacheEpisodes([episode1ShowA, episode1ShowB]);
      
      final cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(2));
      
      final showNames = cachedState.map((e) => e.show).toSet();
      expect(showNames, containsAll(['Attack on Titan', 'One Piece']));
    });

    test('should maintain duplicate prevention across cache rebuilds', () async {
      final cachedNotifier = container.read(cachedEpisodesNotifierProvider.notifier);
      
      // Add episodes with duplicates
      final episodes = [
        ShowInfo(
          downloads: [],
          episode: '1',
          imageUrl: 'ep1v1.jpg',
          page: 'page1v1',
          releaseDate: DateTime(2025, 7, 26, 10),
          show: 'Test Show',
          timeLabel: '10:00',
          xdcc: 'ep1v1',
        ),
        ShowInfo(
          downloads: [],
          episode: '1', // Duplicate
          imageUrl: 'ep1v2.jpg',
          page: 'page1v2',
          releaseDate: DateTime(2025, 7, 26, 12),
          show: 'Test Show',
          timeLabel: '12:00',
          xdcc: 'ep1v2',
        ),
        ShowInfo(
          downloads: [],
          episode: '2',
          imageUrl: 'ep2.jpg',
          page: 'page2',
          releaseDate: DateTime(2025, 7, 26, 14),
          show: 'Test Show',
          timeLabel: '14:00',
          xdcc: 'ep2',
        ),
      ];
      
      await cachedNotifier.cacheEpisodes(episodes);
      
      // Verify only unique episodes are cached
      var cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(2));
      
      // Dispose and recreate container to simulate app restart
      container.dispose();
      container = ProviderContainer();
      
      // Episodes should still be unique after reload
      cachedState = await container.read(cachedEpisodesNotifierProvider.future);
      expect(cachedState, hasLength(2));
      
      final episodeNumbers = cachedState.map((e) => e.episode).toSet();
      expect(episodeNumbers, containsAll(['1', '2']));
      
      // Verify the correct version of episode 1 is preserved
      final episode1 = cachedState.firstWhere((e) => e.episode == '1');
      expect(episode1.timeLabel, '12:00'); // Should be the later version
    });
  });
}
