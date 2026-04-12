import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/api/jikan_api.dart';
import 'package:tamashii/models/jikan_models.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/providers/jikan_api_providers.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/add_schedule_show_sheet.dart';
import 'package:tamashii/widgets/schedule_show_actions_sheet.dart';

class FakeSubsPleaseApi extends SubsPleaseApi {
  FakeSubsPleaseApi();

  @override
  Future<List<ShowInfo>> getLatestShowList() async => const <ShowInfo>[];

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async =>
      const <ShowInfo>[];

  @override
  Future<String?> getShowSynopsis(String showPage) async => null;
}

class FakeJikanApi extends JikanApi {
  FakeJikanApi({required this.resultsByQuery});

  final Map<String, List<JikanAnimeSearchResult>> resultsByQuery;
  final List<String> searchedQueries = <String>[];

  @override
  Future<List<JikanAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    searchedQueries.add(query);
    return resultsByQuery[query] ?? const <JikanAnimeSearchResult>[];
  }
}

void main() {
  Future<void> pumpSchedulePage(
    WidgetTester tester, {
    required FakeJikanApi jikanApi,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': true,
      'download_base_path': '',
      'series_folder_mapping': '{}',
      'bookmarked_series': <String>[],
      'downloaded_torrents': <String>[],
      'show_filter': 'all',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(FakeSubsPleaseApi()),
          jikanApiProvider.overrideWithValue(jikanApi),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const HomePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomePage.scheduleAddFabKey));
    await tester.pumpAndSettle();
  }

  FakeJikanApi createFakeJikanApi() {
    return FakeJikanApi(
      resultsByQuery: <String, List<JikanAnimeSearchResult>>{
        'hero': const <JikanAnimeSearchResult>[
          JikanAnimeSearchResult(
            malId: 31964,
            title: 'Boku no Hero Academia',
            titleEnglish: 'My Hero Academia',
            type: 'TV',
            episodes: 13,
            imageUrl: '',
          ),
        ],
      },
    );
  }

  testWidgets('schedule search waits 2 seconds before querying Jikan', (
    WidgetTester tester,
  ) async {
    final jikanApi = createFakeJikanApi();
    await pumpSchedulePage(tester, jikanApi: jikanApi);

    expect(find.byType(AddScheduleShowSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(AddScheduleShowSheet.searchFieldKey),
      'hero',
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(jikanApi.searchedQueries, isEmpty);
    expect(find.text('My Hero Academia'), findsNothing);
    expect(
      find.text('Press search or wait 2 seconds to search for "hero".'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(jikanApi.searchedQueries, <String>['hero']);
    expect(find.text('My Hero Academia'), findsOneWidget);
  });

  testWidgets('schedule page can add and remove a manual watching show', (
    WidgetTester tester,
  ) async {
    final jikanApi = createFakeJikanApi();
    await pumpSchedulePage(tester, jikanApi: jikanApi);

    expect(find.byType(AddScheduleShowSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(AddScheduleShowSheet.searchFieldKey),
      'hero',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(jikanApi.searchedQueries, <String>['hero']);
    expect(find.text('My Hero Academia'), findsOneWidget);

    await tester.tap(find.text('My Hero Academia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Added "My Hero Academia"'), findsOneWidget);
    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsOneWidget,
    );
    expect(find.text('Manual entry'), findsOneWidget);

    await tester.tap(find.byKey(SchedulePage.showTileKey('My Hero Academia')));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleShowActionsSheet), findsOneWidget);

    await tester.tap(find.byKey(ScheduleShowActionsSheet.removeButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(SchedulePage.showTileKey('My Hero Academia')),
      findsNothing,
    );
  });
}
