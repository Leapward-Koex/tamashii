import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';

void main() {
  test('saved Jikan matches load and block duplicate Tenrai matches', () async {
    const savedImage = 'https://cdn.example.com/frieren.jpg';
    SharedPreferences.setMockInitialValues({
      'bookmarked_series': [
        jsonEncode({
          'showName': 'Frieren',
          'releaseDayOfWeek': DateTime.friday,
          'imageUrl': savedImage,
          'source': 'manual',
          'jikanId': 52991,
        }),
      ],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bookmarks = await container.read(bookmarkedSeriesProvider.future);
    expect(bookmarks.single.malId, 52991);
    expect(bookmarks.single.imageUrl, savedImage);
    expect(bookmarks.single.toJson()['jikanId'], 52991);

    final notifier = container.read(bookmarkedSeriesProvider.notifier);
    const title = 'Sousou no Frieren';
    expect(
      await notifier.add(
        const BookmarkedShowInfo(
          showName: title,
          releaseDayOfWeek: DateTime.monday,
          imageUrl: '',
          source: BookmarkedShowSource.manual,
        ),
      ),
      isTrue,
    );
    expect(
      await notifier.matchManualEntry(
        title,
        malId: 52991,
        imageUrl: savedImage,
      ),
      isFalse,
    );
  });

  test(
    'concurrent schedule writes preserve legacy shows and match in place',
    () async {
      SharedPreferences.setMockInitialValues({
        'bookmarked_series': [
          '{"showName":"Legacy","releaseDayOfWeek":1,"imageUrl":""}',
        ],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(bookmarkedSeriesProvider.notifier);
      const plainTitle = BookmarkedShowInfo(
        showName: 'Frieren',
        imageUrl: '',
        releaseDayOfWeek: DateTime.monday,
        source: BookmarkedShowSource.manual,
      );
      const malId = 52991;
      const imageUrl = 'https://cdn.example.com/frieren.jpg';

      final results = await Future.wait([
        notifier.add(plainTitle),
        notifier.add(plainTitle.copyWith(showName: 'FRIEREN')),
        notifier.updateReleaseDay(plainTitle.showName, DateTime.friday),
        notifier.matchManualEntry(
          plainTitle.showName,
          malId: malId,
          imageUrl: imageUrl,
        ),
        notifier.add(
          plainTitle.copyWith(showName: 'Sousou no Frieren', malId: malId),
        ),
      ]);

      expect(results, [true, false, true, true, false]);
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList('bookmarked_series')!;
      expect(stored, hasLength(2));
      final bookmarks = stored.map(
        (row) => BookmarkedShowInfo.fromJson(jsonDecode(row)),
      );
      expect(bookmarks.first.showName, 'Legacy');
      expect(bookmarks.first.showsOnHomePage, isTrue);
      expect(
        bookmarks.last,
        plainTitle.copyWith(
          releaseDayOfWeek: DateTime.friday,
          malId: malId,
          imageUrl: imageUrl,
        ),
      );
    },
  );
}
