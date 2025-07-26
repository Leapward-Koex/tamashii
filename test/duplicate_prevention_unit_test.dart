// test/duplicate_prevention_unit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:tamashii/models/show_models.dart';

void main() {
  group('Duplicate Prevention Logic Tests', () {
    test('should demonstrate duplicate removal logic', () {
      // Create test episodes with duplicates
      final episode1v1 = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test1v1.jpg',
        page: 'test-page-1v1',
        releaseDate: DateTime(2025, 7, 26, 10, 0),
        show: 'Test Show',
        timeLabel: '10:00',
        xdcc: 'test1v1',
      );
      
      final episode1v2 = ShowInfo(
        downloads: [],
        episode: '1', // Same episode
        imageUrl: 'test1v2.jpg',
        page: 'test-page-1v2',
        releaseDate: DateTime(2025, 7, 26, 12, 0),
        show: 'Test Show', // Same show
        timeLabel: '12:00',
        xdcc: 'test1v2',
      );
      
      final episode2 = ShowInfo(
        downloads: [],
        episode: '2', // Different episode
        imageUrl: 'test2.jpg',
        page: 'test-page-2',
        releaseDate: DateTime(2025, 7, 26, 14, 0),
        show: 'Test Show',
        timeLabel: '14:00',
        xdcc: 'test2',
      );
      
      final episodes = [episode1v1, episode1v2, episode2];
      
      // Apply the same duplicate removal logic as in _saveToStorage
      final Map<String, ShowInfo> uniqueEpisodes = {};
      for (final episode in episodes) {
        final key = '${episode.show}-${episode.episode}';
        uniqueEpisodes[key] = episode;
      }
      
      // Should only have 2 unique episodes
      expect(uniqueEpisodes.length, 2);
      expect(uniqueEpisodes.keys, containsAll(['Test Show-1', 'Test Show-2']));
      
      // The last version of episode 1 should be kept (episode1v2)
      final keptEpisode1 = uniqueEpisodes['Test Show-1']!;
      expect(keptEpisode1.timeLabel, '12:00');
      expect(keptEpisode1.imageUrl, 'test1v2.jpg');
    });

    test('should handle episodes from different shows correctly', () {
      final episode1ShowA = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'showA.jpg',
        page: 'show-a-page',
        releaseDate: DateTime(2025, 7, 26, 10, 0),
        show: 'Show A',
        timeLabel: '10:00',
        xdcc: 'showA',
      );
      
      final episode1ShowB = ShowInfo(
        downloads: [],
        episode: '1', // Same episode number
        imageUrl: 'showB.jpg',
        page: 'show-b-page',
        releaseDate: DateTime(2025, 7, 26, 12, 0),
        show: 'Show B', // Different show
        timeLabel: '12:00',
        xdcc: 'showB',
      );
      
      final episodes = [episode1ShowA, episode1ShowB];
      
      // Apply duplicate removal logic
      final Map<String, ShowInfo> uniqueEpisodes = {};
      for (final episode in episodes) {
        final key = '${episode.show}-${episode.episode}';
        uniqueEpisodes[key] = episode;
      }
      
      // Should have both episodes since they're from different shows
      expect(uniqueEpisodes.length, 2);
      expect(uniqueEpisodes.keys, containsAll(['Show A-1', 'Show B-1']));
    });

    test('should serialize and deserialize correctly after duplicate removal', () {
      final episode1 = ShowInfo(
        downloads: [],
        episode: '1',
        imageUrl: 'test1.jpg',
        page: 'test-page-1',
        releaseDate: DateTime(2025, 7, 26, 10, 0),
        show: 'Test Show',
        timeLabel: '10:00',
        xdcc: 'test1',
      );
      
      final episode2 = ShowInfo(
        downloads: [],
        episode: '1', // Duplicate
        imageUrl: 'test2.jpg',
        page: 'test-page-2',
        releaseDate: DateTime(2025, 7, 26, 12, 0),
        show: 'Test Show',
        timeLabel: '12:00',
        xdcc: 'test2',
      );
      
      final episodes = [episode1, episode2];
      
      // Apply the storage logic
      final Map<String, ShowInfo> uniqueEpisodes = {};
      for (final episode in episodes) {
        final key = '${episode.show}-${episode.episode}';
        uniqueEpisodes[key] = episode;
      }
      
      // Simulate serialization (like in _saveToStorage)
      final List<String> jsonStrings = uniqueEpisodes.values
          .map((episode) => json.encode(episode.toJson()))
          .toList();
      
      expect(jsonStrings.length, 1);
      
      // Simulate deserialization (like in build method)
      final deserializedEpisodes = jsonStrings
          .map((jsonString) => ShowInfo.fromJson(json.decode(jsonString) as Map<String, dynamic>))
          .toList();
      
      expect(deserializedEpisodes.length, 1);
      expect(deserializedEpisodes[0].timeLabel, '12:00'); // Should be the last version
    });
  });
}
