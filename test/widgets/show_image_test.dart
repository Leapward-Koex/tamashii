import 'package:cached_network_image/cached_network_image.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/api/api_client.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/widgets/show_image.dart';

class _NoIoImageCache extends Fake implements BaseCacheManager {
  @override
  Stream<Never> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream.empty();
}

void main() {
  // Only this file's test isolate uses a cache that never fetches image bytes.
  CachedNetworkImageProvider.defaultCacheManager = _NoIoImageCache();

  testWidgets(
    'poster decode stays in a single width bucket across nearby sizes',
    (tester) async {
      Future<CachedNetworkImage> pumpPoster(double width, double height) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(devicePixelRatio: 3),
                child: Center(
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: const ShowImage(
                      imageUrl: 'https://example.test/poster.jpg',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
      }

      final initial = await pumpPoster(132, 180);
      expect((initial.memCacheWidth, initial.memCacheHeight), (416, null));
      final resized = await pumpPoster(134, 240);
      expect((resized.memCacheWidth, resized.memCacheHeight), (416, null));
      final wider = await pumpPoster(160, 240);
      expect((wider.memCacheWidth, wider.memCacheHeight), (480, null));
    },
  );

  testWidgets('only a relative artwork path initializes the feed API', (
    tester,
  ) async {
    var apiReads = 0;
    final container = ProviderContainer.test(
      overrides: [
        subsPleaseApiProvider.overrideWith((ref) {
          apiReads++;
          return SubsPleaseApi();
        }),
      ],
    );
    Future<void> pumpPoster(String url) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Center(
              child: ShowImage(imageUrl: url, width: 44, height: 60),
            ),
          ),
        ),
      );
    }

    await pumpPoster('');
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    await pumpPoster('https://example.test/small.jpg');
    final poster = find.byType(CachedNetworkImage);
    expect(
      tester.widget<CachedNetworkImage>(poster).imageUrl,
      'https://example.test/small.jpg',
    );
    expect(apiReads, 0);

    await pumpPoster('images/relative.jpg');
    expect(
      tester.widget<CachedNetworkImage>(poster).imageUrl,
      'https://subsplease.org/images/relative.jpg',
    );
    expect(apiReads, 1);
  });
}
