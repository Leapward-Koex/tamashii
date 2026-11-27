import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';

void main() {
  const alias = BookmarkedShowInfo(
    showName: 'My alias',
    imageUrl: '',
    releaseDayOfWeek: DateTime.monday,
    source: BookmarkedShowSource.manual,
  );
  const catalog = TenraiAnimeSearchResult(
    malId: 12,
    title: 'Catalog title',
    imageUrl: 'cover.jpg',
  );
  final target = ShowCatalogTarget.fromSchedule(alias);
  test('manual series corrections update schedule artwork, duplicate checks and explicit unmatched across restart', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer.test();
    final bookmarks = c.read(bookmarkedSeriesProvider.notifier);
    await bookmarks.add(alias);
    final choices = c.read(catalogMatchOverridesProvider.notifier);
    await bookmarks.saveCatalogChoice(target, catalog);
    final other = alias.copyWith(showName: 'Other alias', malId: catalog.malId);
    expect(await bookmarks.add(other), isFalse);
    expect(
      (await c.read(bookmarkedSeriesProvider.future)).single,
      alias.copyWith(malId: 12, imageUrl: 'cover.jpg'),
    );
    await bookmarks.saveCatalogChoice(
      target,
      catalog.copyWith(malId: 13, imageUrl: 'corrected.jpg'),
    );
    expect(await bookmarks.add(other), isTrue);
    expect(
      (await c.read(bookmarkedSeriesProvider.future)).first,
      alias.copyWith(malId: 13, imageUrl: 'corrected.jpg'),
    );
    await expectLater(
      bookmarks.saveCatalogChoice(target, catalog),
      throwsA(isA<DuplicateScheduleMatch>()),
    );
    await choices.save(target.copyWith(episode: 'SP1', page: 'alias'), catalog);
    expect((await c.read(bookmarkedSeriesProvider.future)).first.malId, 13);
    await bookmarks.saveCatalogChoice(target, null);
    final restored = ProviderContainer.test();
    final items = await restored.read(bookmarkedSeriesProvider.future);
    expect(items, [alias, other]);
  });
  test('adding a manual title honors a saved correction while a feed bookmark keeps its source artwork', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer.test();
    final choices = c.read(catalogMatchOverridesProvider.notifier);
    await choices.save(target, catalog);
    final bookmarks = c.read(bookmarkedSeriesProvider.notifier);
    expect(await bookmarks.add(alias), isTrue);
    expect(
      (await c.read(bookmarkedSeriesProvider.future)).single.imageUrl,
      'cover.jpg',
    );
    expect(await bookmarks.remove(alias.showName), isTrue);
    final source = alias.copyWith(
      source: BookmarkedShowSource.subsplease,
      imageUrl: 'subs.jpg',
    );
    expect(await bookmarks.add(source), isTrue);
    expect((await c.read(bookmarkedSeriesProvider.future)).single, source);
  });
  test(
    'concurrent correction and alias addition cannot leave duplicate IDs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer.test();
      final bookmarks = c.read(bookmarkedSeriesProvider.notifier);
      await bookmarks.add(alias);
      final correction = bookmarks
          .saveCatalogChoice(target, catalog)
          .then(
            (_) => true,
            onError: (Object error) {
              expect(error, isA<DuplicateScheduleMatch>());
              return false;
            },
          );
      final addition = bookmarks.add(
        alias.copyWith(showName: 'Other alias', malId: 12),
      );
      final saved = await Future.wait([correction, addition]);
      expect(saved.where((yes) => yes), hasLength(1));
      expect(
        (await c.read(bookmarkedSeriesProvider.future))
            .where((show) => show.malId == 12),
        hasLength(1),
      );
    },
  );
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
