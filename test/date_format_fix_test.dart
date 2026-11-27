// test/date_format_fix_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/models/show_models.dart';

void main() {
  group('Date Format Fix Tests', () {
    test('ShowInfo should parse API date format correctly', () {
      final json = {
        'downloads': [],
        'episode': 'Test Episode 01',
        'image_url': 'https://example.com/image.jpg',
        'page': 'https://example.com/page',
        'release_date': 'Sat, 26 Jul 2025 10:15:00 +0000',
        'show': 'Test Show',
        'time': '12:00',
        'xdcc': 'test_xdcc',
      };

      expect(() => ShowInfo.fromJson(json), returnsNormally);
      final showInfo = ShowInfo.fromJson(json);
      expect(showInfo.releaseDate.year, 2025);
      expect(showInfo.releaseDate.month, 7);
      expect(showInfo.releaseDate.day, 26);
      expect(showInfo.releaseDate.isUtc, isTrue);
      expect(showInfo.releaseDate.hour, 10);
      expect(showInfo.releaseDate.minute, 15);
    });

    test('ShowInfo should parse cache date format correctly', () {
      final json = {
        'downloads': [],
        'episode': 'Test Episode 01',
        'image_url': 'https://example.com/image.jpg',
        'page': 'https://example.com/page',
        'release_date': '07/26/25',
        'show': 'Test Show',
        'time': '12:00',
        'xdcc': 'test_xdcc',
      };

      expect(() => ShowInfo.fromJson(json), returnsNormally);
      final showInfo = ShowInfo.fromJson(json);
      expect(showInfo.releaseDate.year, 2025);
      expect(showInfo.releaseDate.month, 7);
      expect(showInfo.releaseDate.day, 26);
      expect(showInfo.releaseDate.isUtc, isFalse);
      final shortMonth = ShowInfo.fromJson({
        ...json,
        'release_date': '7/26/25',
      });
      expect(shortMonth.releaseDate, showInfo.releaseDate);
    });

    test('ShowInfo round-trip serialization should work', () {
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

      final showInfo = ShowInfo.fromJson(originalJson);
      final serializedJson = showInfo.toJson();
      final deserializedShowInfo = ShowInfo.fromJson(serializedJson);

      expect(deserializedShowInfo.show, showInfo.show);
      expect(deserializedShowInfo.episode, showInfo.episode);
      expect(deserializedShowInfo.releaseDate.year, showInfo.releaseDate.year);
      expect(
        deserializedShowInfo.releaseDate.month,
        showInfo.releaseDate.month,
      );
      expect(deserializedShowInfo.releaseDate.day, showInfo.releaseDate.day);
    });

    test('ShowInfo should handle invalid date format gracefully', () {
      final json = {
        'downloads': [],
        'episode': 'Test Episode 01',
        'image_url': 'https://example.com/image.jpg',
        'page': 'https://example.com/page',
        'release_date': 'invalid_date_format',
        'show': 'Test Show',
        'time': '12:00',
        'xdcc': 'test_xdcc',
      };

      expect(() => ShowInfo.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('signed feed offsets and cached copies preserve the release instant across midnight', () {
      final fields = {
        'downloads': [],
        'episode': '01',
        'image_url': '',
        'page': '',
        'show': 'Ferry',
        'time': '',
        'xdcc': '',
      };
      for (final (raw, utc) in [
        ('Fri, 27 Nov 2026 00:15:00 +1300', DateTime.utc(2026, 11, 26, 11, 15)),
        ('Thu, 26 Nov 2026 23:50:00 -0330', DateTime.utc(2026, 11, 27, 3, 20)),
        ('Fri, 27 Nov 2026 03:20:00 Z', DateTime.utc(2026, 11, 27, 3, 20)),
      ]) {
        final show = ShowInfo.fromJson({...fields, 'release_date': raw});
        expect(show.releaseDate, utc);
        expect(ShowInfo.fromJson(show.toJson()).releaseDate, utc);
      }
    });
  });
}
