import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/widgets/show_info_match_sheet.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/theme/paper_lantern.dart';

const special = TenraiAnimeSearchResult(
  malId: 49200,
  title: 'Shiguang Dailiren Fanwai Pian',
  titleEnglish: 'Link Click Episode 5.5',
  type: 'ONA',
  episodes: 1,
);

const bonus = TenraiAnimeSearchResult(
  malId: 199,
  title: 'A quiet afternoon',
  type: 'OVA',
);

ShowInfo episode(String label, {String imageUrl = ''}) => ShowInfo(
  downloads: [],
  episode: label,
  imageUrl: imageUrl,
  page: 'link-click',
  releaseDate: DateTime.utc(2026, 3),
  show: 'Link Click',
  timeLabel: '',
  xdcc: '',
);

class _Feed extends SubsPleaseApi {
  @override
  Future<List<ShowInfo>> getLatestShowList() async => [episode('03')];
  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async => [
    episode('03'),
    episode('SP'),
  ];
  @override
  Future<String?> getShowSynopsis(String showPage) async =>
      'Two friends revisit the past through photographs.';
}

class _Catalog extends TenraiApi {
  _Catalog({this.fail = false});
  bool fail;
  final searches = <String>[];
  final ids = <int>[];
  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searches.add(query);
    if (fail) throw const TenraiApiException('Tenrai search timed out.');
    return query == 'side story' ? [special] : [];
  }

  @override
  Future<TenraiAnimeSearchResult?> getAnimeById(int malId) async {
    ids.add(malId);
    return [special, bonus].where((entry) => entry.malId == malId).firstOrNull;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester,
    ShowInfoPage page,
    _Catalog catalog,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(_Feed()),
          tenraiApiProvider.overrideWithValue(catalog),
        ],
        child: MaterialApp(theme: PaperLantern.theme, home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'series title and portrait reflow together on a narrow display with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(
        tester,
        ShowInfoPage.release(episode('03', imageUrl: 'urn:poster')),
        _Catalog(),
      );
      final title = find.text('Link Click');
      final poster = find.byType(ShowImage);
      expect(
        tester.getRect(title).right,
        lessThanOrEqualTo(tester.getRect(poster).left),
      );
      expect(tester.widget<Text>(title).style?.fontFamily, PaperLantern.serif);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(title).top,
        greaterThanOrEqualTo(tester.getRect(poster).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed lookup preserves release information and can recover to an explicit no-match choice',
    (tester) async {
      final api = _Catalog(fail: true);
      await open(tester, ShowInfoPage.release(episode('SP')), api);
      expect(find.text('Catalog lookup unavailable'), findsOneWidget);
      expect(
        find.text('Two friends revisit the past through photographs.'),
        findsOneWidget,
      );
      expect(find.text('SP'), findsOneWidget);
      expect(find.text('Episode 03'), findsNothing);
      api.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No catalog match found'), findsOneWidget);
      await tester.tap(find.text('Leave unmatched'));
      await tester.pumpAndSettle();
      expect(find.text('Kept unmatched'), findsOneWidget);
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(find.text('Watching'), findsOneWidget);
      expect(find.text('Kept unmatched'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a result requires confirmation and a changed query clears stale selection',
    (tester) async {
      final api = _Catalog();
      await open(tester, ShowInfoPage.release(episode('SP')), api);
      await tester.tap(find.text('Find a match'));
      await tester.pumpAndSettle();
      expect(find.text('Applies only to this release.'), findsOneWidget);
      final field = find.byKey(ShowInfoMatchSheet.searchFieldKey);
      await tester.enterText(field, 'side story');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(49200)));
      await tester.pump();
      await tester.enterText(field, '999');
      await tester.pump();
      FilledButton saveButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use this match'),
      );
      expect(saveButton().onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('No entries found'), findsOneWidget);
      await tester.enterText(field, '49200');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(api.ids, [999, 49200]);
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(49200)));
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
      await tester.tap(find.text('Use this match'));
      await tester.pumpAndSettle();
      expect(find.text('Tenrai · MAL #49200'), findsOneWidget);
      expect(find.text('Chosen by you'), findsOneWidget);
      expect(find.text('Watch'), findsOneWidget);
      await tester.tap(find.text('Fix match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave unmatched').last);
      await tester.pumpAndSettle();
      expect(find.text('Kept unmatched'), findsOneWidget);
    },
  );

  testWidgets(
    'manual schedule match opens its picker and retains its saved MAL entry on close',
    (tester) async {
      const saved = BookmarkedShowInfo(
        imageUrl: '',
        releaseDayOfWeek: 5,
        showName: 'My Link Click special',
        malId: 49200,
        source: BookmarkedShowSource.manual,
      );
      final api = _Catalog();
      await open(
        tester,
        const ShowInfoPage.schedule(saved, openMatchPicker: true),
        api,
      );
      expect(find.byType(ShowInfoMatchSheet), findsOneWidget);
      expect(api.ids, [49200]);
      expect(api.searches, isEmpty);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Tenrai · MAL #49200'), findsOneWidget);
      expect(find.text('Added manually · Friday'), findsOneWidget);
      expect(find.text('SubsPlease releases'), findsNothing);
    },
  );

  testWidgets(
    'an integer-labeled bonus uses its own catalog entry and keeps its scope on reopening',
    (tester) async {
      final catalog = _Catalog();
      await open(tester, ShowInfoPage.release(episode('13')), catalog);
      await tester.tap(find.text('Find a match'));
      await tester.pumpAndSettle();
      FilterChip chip() => tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Only this release'),
      );
      expect(chip().selected, isFalse);
      await tester.enterText(
        find.byKey(ShowInfoMatchSheet.searchFieldKey),
        '199',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(199)));
      await tester.pump();
      expect(chip().selected, isTrue);
      expect(chip().onSelected, isNull);
      await tester.tap(find.text('Use this match'));
      await tester.pumpAndSettle();
      expect(find.text('Tenrai · MAL #199'), findsOneWidget);
      expect(find.text('Episode 03'), findsNothing);
      await tester.tap(find.text('Fix match'));
      await tester.pumpAndSettle();
      expect(chip().selected, isTrue);
      await tester.tap(find.text('Leave unmatched').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Your choice is saved for this release.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await open(tester, ShowInfoPage.release(episode('03')), catalog);
      expect(find.text('No catalog match found'), findsOneWidget);
      await tester.tap(find.text('Find a match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only this release'));
      await tester.pump();
      await tester.tap(find.text('Leave unmatched').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Your choice is saved for this release.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a duplicate catalog selection explains the conflict and keeps the picker open',
    (tester) async {
      const first = BookmarkedShowInfo(
        imageUrl: '',
        showName: 'My show',
        releaseDayOfWeek: 2,
        source: BookmarkedShowSource.manual,
      );
      final existing = first.copyWith(showName: 'Another show', malId: 199);
      SharedPreferences.setMockInitialValues({
        'bookmarked_series': [
          for (final entry in [first, existing]) jsonEncode(entry.toJson()),
        ],
      });
      await open(
        tester,
        const ShowInfoPage.schedule(first, openMatchPicker: true),
        _Catalog(),
      );
      expect(find.text('Only this release'), findsNothing);
      await tester.enterText(
        find.byKey(ShowInfoMatchSheet.searchFieldKey),
        '199',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(199)));
      await tester.pump();
      await tester.tap(find.text('Use this match'));
      await tester.pumpAndSettle();
      expect(
        find.text('That catalog entry is already on your schedule.'),
        findsOneWidget,
      );
      expect(find.byType(ShowInfoMatchSheet), findsOneWidget);
    },
  );

  testWidgets(
    'picker fits a narrow phone and remains scrollable with a landscape keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await open(tester, ShowInfoPage.release(episode('SP')), _Catalog());
      await tester.tap(find.text('Find a match'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(640, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.widgetWithText(TextButton, 'Leave unmatched').last;
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
