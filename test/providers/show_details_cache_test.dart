import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';

class _ShowApi extends SubsPleaseApi {
  var synopsisRequests = 0;
  var releaseRequests = 0;
  String? synopsis;
  List<ShowInfo> releases = [];

  @override
  Future<String?> getShowSynopsis(String showPage) async {
    synopsisRequests++;
    return synopsis;
  }

  @override
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async {
    releaseRequests++;
    return releases;
  }
}

void main() {
  final release = ShowInfo(
    downloads: [],
    episode: '1',
    imageUrl: '',
    page: 'cowboy-bebop',
    releaseDate: DateTime.utc(2026),
    show: 'Cowboy Bebop',
    timeLabel: '',
    xdcc: '',
  );
  final synopsis = showSynopsisProvider(release.page);
  final releases = searchShowsProvider(release.show);

  testWidgets('a return visit immediately has details until they expire', (
    tester,
  ) async {
    final api = _ShowApi()
      ..synopsis = 'A crew of bounty hunters.'
      ..releases = [release];
    final container = ProviderContainer(
      overrides: [subsPleaseApiProvider.overrideWithValue(api)],
    );
    try {
      final firstSynopsis = container.listen(synopsis, (_, _) {});
      final firstReleases = container.listen(releases, (_, _) {});
      await container.read(synopsis.future);
      await container.read(releases.future);
      firstSynopsis.close();
      firstReleases.close();
      await tester.pump(const Duration(minutes: 9));

      final warmSynopsis = container.listen(synopsis, (_, _) {});
      final warmReleases = container.listen(releases, (_, _) {});
      expect(warmSynopsis.read().requireValue, api.synopsis);
      expect(warmReleases.read().requireValue, [release]);
      expect(api.synopsisRequests, 1);
      expect(api.releaseRequests, 1);
      warmSynopsis.close();
      warmReleases.close();

      api.synopsis = 'An updated synopsis.';
      await tester.pump(const Duration(minutes: 2));
      expect(await container.read(synopsis.future), api.synopsis);
      expect(await container.read(releases.future), [release]);
      expect(api.synopsisRequests, 2);
      expect(api.releaseRequests, 2);
    } finally {
      container.dispose();
    }
  });

  test('a return visit retries missing synopsis and releases', () async {
    final api = _ShowApi();
    final container = ProviderContainer.test(
      overrides: [subsPleaseApiProvider.overrideWithValue(api)],
    );
    final firstSynopsis = container.listen(synopsis, (_, _) {});
    final firstReleases = container.listen(releases, (_, _) {});
    expect(await container.read(synopsis.future), isNull);
    expect(await container.read(releases.future), isEmpty);
    firstSynopsis.close();
    firstReleases.close();
    await container.pump();

    api.synopsis = 'A crew of bounty hunters.';
    api.releases = [release];
    expect(await container.read(synopsis.future), api.synopsis);
    expect(await container.read(releases.future), [release]);
    expect(api.synopsisRequests, 2);
    expect(api.releaseRequests, 2);
  });
}
