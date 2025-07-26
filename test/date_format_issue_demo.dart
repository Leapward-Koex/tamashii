// test/date_format_issue_demo.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/models/show_models.dart';

void main() {
  group('Date Format Issue Demonstration', () {
    test('should reproduce the original error scenario', () {
      // This simulates the original error: "Invalid release_date format: 07/26/25"
      // This would have failed before our fix
      final jsonWithShortDate = {
        'downloads': [],
        'episode': 'Test Episode 01',
        'image_url': 'https://example.com/image.jpg',
        'page': 'https://example.com/page',
        'release_date': '07/26/25', // This is what was causing the error
        'show': 'Test Show',
        'time': '12:00',
        'xdcc': 'test_xdcc',
      };

      // Before our fix, this would throw: FormatException: Invalid release_date format: 07/26/25
      // After our fix, this should work correctly
      expect(() => ShowInfo.fromJson(jsonWithShortDate), returnsNormally);
      
      final showInfo = ShowInfo.fromJson(jsonWithShortDate);
      expect(showInfo.releaseDate.year, 2025);
      expect(showInfo.releaseDate.month, 7);
      expect(showInfo.releaseDate.day, 26);
    });

    test('should still handle API format correctly', () {
      // This shows that our fix doesn't break the original API format
      final jsonWithApiDate = {
        'downloads': [],
        'episode': 'Test Episode 01',
        'image_url': 'https://example.com/image.jpg',
        'page': 'https://example.com/page',
        'release_date': 'Sat, 26 Jul 2025 12:00:00 +0000', // Original API format
        'show': 'Test Show',
        'time': '12:00',
        'xdcc': 'test_xdcc',
      };

      expect(() => ShowInfo.fromJson(jsonWithApiDate), returnsNormally);
      
      final showInfo = ShowInfo.fromJson(jsonWithApiDate);
      expect(showInfo.releaseDate.year, 2025);
      expect(showInfo.releaseDate.month, 7);
      expect(showInfo.releaseDate.day, 26);
    });

    test('should demonstrate that cache serialization and deserialization works', () {
      // Start with API format
      final originalJson = {
        'downloads': [],
        'episode': 'Test Episode 01',
        'image_url': 'https://example.com/image.jpg',
        'page': 'https://example.com/page',
        'release_date': 'Sat, 26 Jul 2025 12:00:00 +0000',
        'show': 'Test Show',
        'time': '12:00',
        'xdcc': 'test_xdcc',
      };

      // Parse from API format
      final showInfo = ShowInfo.fromJson(originalJson);
      
      // Serialize to cache format (this produces the "07/26/25" format)
      final cachedJson = showInfo.toJson();
      expect(cachedJson['release_date'], '07/26/25');
      
      // Deserialize from cache format (this would have failed before our fix)
      final restoredShowInfo = ShowInfo.fromJson(cachedJson);
      
      // Verify everything is correct
      expect(restoredShowInfo.show, showInfo.show);
      expect(restoredShowInfo.episode, showInfo.episode);
      expect(restoredShowInfo.releaseDate.year, showInfo.releaseDate.year);
      expect(restoredShowInfo.releaseDate.month, showInfo.releaseDate.month);
      expect(restoredShowInfo.releaseDate.day, showInfo.releaseDate.day);
    });
  });
}
