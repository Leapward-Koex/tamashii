import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/release_reader_index.dart';
import 'package:tamashii/widgets/show_image.dart';

ShowInfo _release(String name, String episode) => ShowInfo(
  downloads: const [],
  episode: episode,
  imageUrl: '',
  page: name,
  releaseDate: DateTime.utc(2026),
  show: name,
  timeLabel: '',
  xdcc: '',
);

void main() {
  testWidgets('uses cached posters and selects the exact tapped release', (
    tester,
  ) async {
    final first = _release('Source title', '04');
    final second = _release('Source title', '05');
    final special = _release('Unmatched release', 'Movie');
    final releases = [first, second, special];
    var selected = first;
    const poster = 'https://example.org/art.jpg';
    const match = ShowCatalogMatch(
      entry: TenraiAnimeSearchResult(
        title: 'Canonical title',
        malId: 123,
        imageUrl: poster,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          for (final release in releases)
            cachedShowCatalogMatchProvider(
              ShowCatalogTarget.fromRelease(release),
            ).overrideWithValue(release == special ? null : match),
        ],
        child: MaterialApp(
          theme: PaperLantern.theme,
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: StatefulBuilder(
                builder: (context, setState) => ReleaseReaderIndex(
                  releases: releases,
                  selectedRelease: selected,
                  onSelected: (release) => setState(() => selected = release),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Canonical title'), findsNWidgets(2));
    expect(find.text('Source title'), findsNothing);
    expect(find.text('Episode 04'), findsOneWidget);
    expect(find.text('Movie'), findsOneWidget);
    final row = find.byKey(ReleaseReaderIndex.rowKey(second.torrentKey));
    expect(
      tester
          .widget<ShowImage>(
            find.descendant(of: row, matching: find.byType(ShowImage)),
          )
          .imageUrl,
      poster,
    );
    final semantics = find
        .descendant(of: row, matching: find.byType(Semantics))
        .first;
    expect(tester.widget<Semantics>(semantics).properties.selected, false);
    await tester.tap(row);
    await tester.pump();
    expect(selected, same(second));
    expect(tester.widget<Semantics>(semantics).properties.selected, true);
    final container = ProviderScope.containerOf(tester.element(row));
    for (final release in releases) {
      expect(
        container.read(
          showCatalogMatchProvider(ShowCatalogTarget.fromRelease(release))
              .exists,
        ),
        false,
      );
    }
  });

  testWidgets(
    'reveals a distant selection on first unfold and restores the previous index scroll',
    (tester) async {
      final releases = List.generate(24, (i) => _release('Show $i', '03'));
      var selected = releases[18];
      var visible = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            for (final release in releases)
              cachedShowCatalogMatchProvider(
                ShowCatalogTarget.fromRelease(release),
              ).overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: PaperLantern.theme,
            home: Scaffold(
              body: SizedBox(
                width: 280,
                height: 380,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return visible
                        ? ReleaseReaderIndex(
                            releases: releases,
                            selectedRelease: selected,
                            onSelected: (_) {},
                          )
                        : const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find
            .byKey(ReleaseReaderIndex.rowKey(releases[18].torrentKey))
            .hitTestable(),
        findsOneWidget,
      );
      final view = find.byKey(ReleaseReaderIndex.scrollKey);
      final controller = tester.widget<ListView>(view).controller!;
      expect(controller.offset, greaterThan(0));
      // A user may deliberately scroll away from the selected show to browse.
      controller.jumpTo(125);
      await tester.pump();
      rebuild(() => visible = false);
      await tester.pump();
      rebuild(() => visible = true);
      await tester.pump();
      expect(tester.widget<ListView>(view).controller!.offset, 125);
      rebuild(() => visible = false);
      await tester.pump();
      selected = releases[22];
      rebuild(() => visible = true);
      await tester.pump();
      expect(
        find
            .byKey(ReleaseReaderIndex.rowKey(selected.torrentKey))
            .hitTestable(),
        findsOneWidget,
      );
    },
  );
}
