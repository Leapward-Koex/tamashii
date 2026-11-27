import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/add_schedule_show_sheet.dart';
import 'package:tamashii/widgets/schedule_show_actions_sheet.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/widgets/show_info_match_sheet.dart';
import 'package:tamashii/theme/paper_lantern.dart';

class FakeSubsPleaseApi extends SubsPleaseApi {
  FakeSubsPleaseApi([this.releases = const []]);

  final List<ShowInfo> releases;

  @override
  Future<List<ShowInfo>> getLatestShowList() async => releases;

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async =>
      releases.where((show) => show.show == searchTerm).toList();

  @override
  Future<String?> getShowSynopsis(String showPage) async => null;
}

class FakeTenraiApi extends TenraiApi {
  FakeTenraiApi({required this.resultsByQuery, this.failFirstSearch = false});

  final Map<String, List<TenraiAnimeSearchResult>> resultsByQuery;
  final bool failFirstSearch;
  final List<String> searchedQueries = <String>[];

  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searchedQueries.add(query);
    if (failFirstSearch && searchedQueries.length == 1) {
      throw const TenraiApiException('Tenrai search timed out.');
    }
    return resultsByQuery[query] ?? const <TenraiAnimeSearchResult>[];
  }
}

void main() {
  Future<void> pumpSchedulePage(
    WidgetTester tester, {
    required FakeTenraiApi tenraiApi,
    List<BookmarkedShowInfo> initialBookmarks = const <BookmarkedShowInfo>[],
    List<ShowInfo> releases = const [],
    bool openAddSheet = true,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': true,
      'download_base_path': '',
      'series_folder_mapping': '{}',
      'bookmarked_series': initialBookmarks
          .map((bookmark) => jsonEncode(bookmark.toJson()))
          .toList(),
      'downloaded_torrents': <String>[],
      'show_filter': 'all',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(FakeSubsPleaseApi(releases)),
          tenraiApiProvider.overrideWithValue(tenraiApi),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        ],
        child: MaterialApp(theme: PaperLantern.theme, home: const HomePage()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    if (openAddSheet) {
      await tester.tap(find.byKey(HomePage.scheduleAddFabKey));
      await tester.pumpAndSettle();
    }
  }

  FakeTenraiApi createFakeTenraiApi({bool failFirstSearch = false}) {
    return FakeTenraiApi(
      failFirstSearch: failFirstSearch,
      resultsByQuery: <String, List<TenraiAnimeSearchResult>>{
        'hero': const <TenraiAnimeSearchResult>[
          TenraiAnimeSearchResult(
            malId: 31964,
            title: 'Boku no Hero Academia',
            titleEnglish: 'My Hero Academia',
            type: 'TV',
            episodes: 13,
          ),
        ],
      },
    );
  }

  testWidgets(
    'fixing a Home special leaves its Schedule series and sibling special alone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const series = 'Link Click';
      const regular = TenraiAnimeSearchResult(
        malId: 44074,
        title: 'Shiguang Dailiren',
        titleEnglish: series,
        type: 'ONA',
      );
      const special = TenraiAnimeSearchResult(
        malId: 49200,
        title: 'Link Click Episode 5.5',
        type: 'ONA',
      );
      final shows = [
        for (final (ep, day) in [('SP1', 3), ('03', 2), ('SP2', 1)])
          ShowInfo(
            downloads: [],
            episode: ep,
            imageUrl: '',
            page: 'link-click',
            releaseDate: DateTime.utc(2026, 11, day),
            show: series,
            timeLabel: '',
            xdcc: '',
          ),
      ];
      await pumpSchedulePage(
        tester,
        tenraiApi: FakeTenraiApi(
          resultsByQuery: {
            series: [regular, special],
            '$series SP1': [special],
            '$series SP2': [special],
          },
        ),
        openAddSheet: false,
        releases: shows,
        initialBookmarks: [
          BookmarkedShowInfo(
            showName: series,
            imageUrl: '',
            releaseDayOfWeek: DateTime.now().weekday,
          ),
        ],
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(ShowCard.featuredCardKey(series)),
          matching: find.text(series),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShowInfoPage), findsOneWidget);
      await tester.tap(find.text('Review 1 match'));
      await tester.pumpAndSettle();
      expect(find.text('Applies only to this release.'), findsOneWidget);
      await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(special.malId)));
      await tester.pump();
      await tester.tap(find.text('Use this match'));
      await tester.pumpAndSettle();
      expect(find.text('Tenrai · MAL #49200'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // The standard Home card also opens its own release.
      final standardTitle = find.descendant(
        of: find.byKey(ShowCard.standardCardKey(series)).first,
        matching: find.text(series),
      );
      await tester.ensureVisible(standardTitle);
      await tester.tap(standardTitle);
      await tester.pumpAndSettle();
      expect(find.text('Tenrai · MAL #44074'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SchedulePage.showTileKey(series)));
      await tester.pumpAndSettle();
      expect(find.text('Tenrai · MAL #44074'), findsOneWidget);
      expect(find.text('Matched automatically'), findsOneWidget);

      for (final ep in ['SP2', 'SP1']) {
        final release = find.widgetWithText(ListTile, ep);
        await tester.ensureVisible(release);
        await tester.tap(release);
        await tester.pumpAndSettle();
        if (ep == 'SP1') {
          expect(find.text('Chosen by you'), findsOneWidget);
          expect(find.text('Tenrai · MAL #49200'), findsOneWidget);
        } else {
          expect(find.text('Review 1 match'), findsOneWidget);
          expect(find.text('Chosen by you'), findsNothing);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'weekly listings show dated weekdays and the next scheduled day',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSchedulePage(
        tester,
        tenraiApi: createFakeTenraiApi(),
        openAddSheet: false,
        initialBookmarks: const [
          BookmarkedShowInfo(
            showName: 'Monday series',
            releaseDayOfWeek: DateTime.monday,
            imageUrl: '',
          ),
          BookmarkedShowInfo(
            showName: 'Thursday series',
            releaseDayOfWeek: DateTime.thursday,
            imageUrl: '',
          ),
        ],
      );
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
      expect(
        find.bySemanticsLabel(RegExp(DateFormat.yMMMMEEEEd().format(monday))),
        findsOneWidget,
      );
      expect(
        find.byKey(SchedulePage.showTileKey('Monday series')),
        findsOneWidget,
      );
      final mondayName = tester.widget<Text>(find.text('Monday series'));
      expect(mondayName.style?.fontFamily, PaperLantern.serif);
      await tester.ensureVisible(
        find.text('Next · Thursday', skipOffstage: false).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Next · Thursday'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.fling(find.byType(PageView), const Offset(-275, 0), 650);
      await tester.pumpAndSettle();
      expect(find.text('No shows scheduled for Tuesday'), findsOneWidget);
    },
  );

  testWidgets(
    'a new week follows today and keeps an explicitly browsed weekday',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      Future<void> show(DateTime now) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: PaperLantern.theme,
              home: Scaffold(body: SchedulePage(today: now)),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(DateTime(2023, 12, 31));
      expect(find.text('Sunday'), findsOneWidget);
      expect(find.text('25–31 DECEMBER'), findsOneWidget);
      await show(DateTime(2024));
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('1–7 JANUARY'), findsOneWidget);
      await tester.tap(find.text('Fri'));
      await tester.pumpAndSettle();
      await show(DateTime(2024, 1, 2));
      expect(find.text('Friday'), findsOneWidget);
      await show(DateTime(2024, 1, 30));
      expect(find.text('29 JAN–4 FEBRUARY'), findsOneWidget);
    },
  );

  testWidgets(
    'landscape Schedule can browse a day and save a title with the keyboard open',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(680, 320);
      addTearDown(tester.view.reset);
      await pumpSchedulePage(
        tester,
        tenraiApi: createFakeTenraiApi(),
        openAddSheet: false,
      );
      final week = find.byType(PageView);
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();
      await tester.fling(week, const Offset(-550, 0), 850);
      await tester.pumpAndSettle();
      final day = find.text('Tuesday', skipOffstage: false);
      await tester.ensureVisible(day.first);
      await tester.pumpAndSettle();
      expect(find.text('Tuesday'), findsOneWidget);
      await tester.drag(week, const Offset(0, 440));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomePage.scheduleAddFabKey).hitTestable());
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      final input = find.byKey(AddScheduleShowSheet.searchFieldKey);
      await tester.ensureVisible(input);
      await tester.enterText(input, 'My show');
      await tester.pumpAndSettle();
      final save = find.text('Add by title');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.byType(AddScheduleShowSheet), findsNothing);
      expect(find.textContaining('Added "My show"'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('schedule search waits 2 seconds before querying Tenrai', (
    WidgetTester tester,
  ) async {
    final tenraiApi = createFakeTenraiApi();
    await pumpSchedulePage(tester, tenraiApi: tenraiApi);

    expect(find.byType(AddScheduleShowSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(AddScheduleShowSheet.searchFieldKey),
      'hero',
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tenraiApi.searchedQueries, isEmpty);
    expect(find.text('My Hero Academia'), findsNothing);
    expect(find.text('Add by title'), findsOneWidget);
    expect(
      find.textContaining('Search for a show to add it to'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(tenraiApi.searchedQueries, <String>['hero']);
    expect(find.text('My Hero Academia'), findsOneWidget);
  });

  testWidgets('can retry a failed Tenrai search without changing the title', (
    WidgetTester tester,
  ) async {
    final tenraiApi = createFakeTenraiApi(failFirstSearch: true);
    await pumpSchedulePage(tester, tenraiApi: tenraiApi);
    await tester.enterText(
      find.byKey(AddScheduleShowSheet.searchFieldKey),
      'hero',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Tenrai search timed out.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(tenraiApi.searchedQueries, ['hero', 'hero']);
    expect(find.text('My Hero Academia'), findsOneWidget);
  });

  testWidgets('can save a title after a timeout and match it from Schedule', (
    WidgetTester tester,
  ) async {
    final tenraiApi = createFakeTenraiApi(failFirstSearch: true);
    await pumpSchedulePage(tester, tenraiApi: tenraiApi);
    await tester.tap(find.byKey(AddScheduleShowSheet.dayDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(AddScheduleShowSheet.searchFieldKey),
      '  hero  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Tenrai search timed out.'), findsOneWidget);

    await tester.tap(find.text('Add by title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    final tile = find.byKey(SchedulePage.showTileKey('hero'));
    expect(tile, findsOneWidget);
    await tester.tap(find.byKey(SchedulePage.showActionsKey('hero')));
    await tester.pumpAndSettle();
    expect(find.text('Edit catalog match'), findsOneWidget);
    await tester.tap(find.byKey(ScheduleShowActionsSheet.matchButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(ShowInfoMatchSheet), findsOneWidget);
    expect(find.text('Add by title'), findsNothing);
    await tester.tap(find.byKey(ShowInfoMatchSheet.entryKey(31964)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this match'));
    await tester.pumpAndSettle();
    expect(find.text('Tenrai · MAL #31964'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    final storedEntry = preferences.getStringList('bookmarked_series')!.single;
    final bookmark = BookmarkedShowInfo.fromJson(jsonDecode(storedEntry));
    expect(bookmark.showName, 'hero');
    expect(bookmark.releaseDayOfWeek, DateTime.monday);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(ShowInfoPage), findsOneWidget);
    expect(find.text('Tenrai · MAL #31964'), findsOneWidget);
    expect(find.text('Chosen by you'), findsOneWidget);
  });

  testWidgets('schedule page can add and remove a manual watching show', (
    WidgetTester tester,
  ) async {
    final tenraiApi = createFakeTenraiApi();
    await pumpSchedulePage(tester, tenraiApi: tenraiApi);

    expect(find.byType(AddScheduleShowSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(AddScheduleShowSheet.searchFieldKey),
      'hero',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(tenraiApi.searchedQueries, <String>['hero']);
    expect(find.text('My Hero Academia'), findsOneWidget);

    await tester.tap(find.text('My Hero Academia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Added "My Hero Academia"'), findsOneWidget);
    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsOneWidget,
    );
    expect(find.text('Manual entry'), findsOneWidget);

    await tester.tap(
      find.byKey(SchedulePage.showActionsKey('My Hero Academia')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleShowActionsSheet), findsOneWidget);

    await tester.tap(find.byKey(ScheduleShowActionsSheet.removeButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsNothing,
    );
  });

  testWidgets('schedule page can move a watching show to another day', (
    WidgetTester tester,
  ) async {
    final tenraiApi = createFakeTenraiApi();
    await pumpSchedulePage(
      tester,
      tenraiApi: tenraiApi,
      openAddSheet: false,
      initialBookmarks: const <BookmarkedShowInfo>[
        BookmarkedShowInfo(
          imageUrl: '',
          releaseDayOfWeek: 1,
          showName: 'My Hero Academia',
          malId: 31964,
          source: BookmarkedShowSource.manual,
        ),
      ],
    );

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    const targetWeekday = 5;

    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(SchedulePage.showActionsKey('My Hero Academia')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ScheduleShowActionsSheet.changeDayButtonKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(ScheduleShowActionsSheet.dayButtonKey(targetWeekday)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ScheduleShowActionsSheet.dayButtonKey(targetWeekday)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Moved "My Hero Academia"'), findsOneWidget);
    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsNothing,
    );

    await tester.tap(find.text('Fri'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsOneWidget,
    );
    expect(find.text('Manual entry'), findsOneWidget);
  });

  testWidgets('schedule show action rows are horizontally aligned', (
    WidgetTester tester,
  ) async {
    final tenraiApi = createFakeTenraiApi();
    await pumpSchedulePage(
      tester,
      tenraiApi: tenraiApi,
      openAddSheet: false,
      initialBookmarks: const <BookmarkedShowInfo>[
        BookmarkedShowInfo(
          imageUrl: '',
          releaseDayOfWeek: 1,
          showName: 'My Hero Academia',
          malId: 31964,
          source: BookmarkedShowSource.manual,
        ),
      ],
    );

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(SchedulePage.showActionsKey('My Hero Academia')),
    );
    await tester.pumpAndSettle();

    final changeDayLeft = tester
        .getTopLeft(find.text('Change schedule day'))
        .dx;
    final removeLeft = tester
        .getTopLeft(find.text('Remove from watching list'))
        .dx;

    expect(changeDayLeft, removeLeft);
  });
}
