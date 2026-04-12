import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/show_card.dart';

class FakeSubsPleaseApi extends SubsPleaseApi {
  FakeSubsPleaseApi({required this.latestEpisodes});

  final List<ShowInfo> latestEpisodes;

  @override
  Future<List<ShowInfo>> getLatestShowList() async => latestEpisodes;

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async =>
      latestEpisodes;

  @override
  Future<String?> getShowSynopsis(String showPage) async => null;
}

void main() {
  ShowInfo createEpisode({
    required String showName,
    required String episode,
    required DateTime releaseDate,
  }) {
    return ShowInfo(
      downloads: const <ShowDownloadInfo>[],
      episode: episode,
      imageUrl: '',
      page: showName.toLowerCase().replaceAll(' ', '-'),
      releaseDate: releaseDate,
      show: showName,
      timeLabel: '20:30',
      xdcc: 'xdcc',
    );
  }

  testWidgets('home page compresses the search bar and parallaxes the hero', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': true,
      'download_base_path': '',
      'series_folder_mapping': '{}',
      'bookmarked_series': <String>[],
      'downloaded_torrents': <String>[],
      'show_filter': 'all',
    });

    final shows = <ShowInfo>[
      createEpisode(
        showName: 'Featured Show',
        episode: '12',
        releaseDate: DateTime(2026, 4, 12),
      ),
      createEpisode(
        showName: 'Second Show',
        episode: '4',
        releaseDate: DateTime(2026, 4, 11),
      ),
      createEpisode(
        showName: 'Third Show',
        episode: '9',
        releaseDate: DateTime(2026, 4, 10),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsPleaseApiProvider.overrideWithValue(
            FakeSubsPleaseApi(latestEpisodes: shows),
          ),
          torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const HomePage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final initialSearchHeight =
        tester.getSize(find.byKey(HomePage.searchBarShellKey)).height;
    final heroTransformFinder = find.byKey(
      ShowCard.featuredPosterTransformKey('Featured Show'),
    );
    final initialHeroOffset =
        tester.widget<Transform>(heroTransformFinder).transform.storage[13];

    await tester.drag(
      find.byKey(HomePage.scrollViewKey),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    final collapsedSearchHeight =
        tester.getSize(find.byKey(HomePage.searchBarShellKey)).height;
    final updatedHeroOffset =
        tester.widget<Transform>(heroTransformFinder).transform.storage[13];

    expect(collapsedSearchHeight, lessThan(initialSearchHeight));
    expect(updatedHeroOffset, greaterThan(initialHeroOffset));
    expect(find.text('Featured Show'), findsWidgets);
    expect(find.text('Second Show'), findsOneWidget);
  });
}
