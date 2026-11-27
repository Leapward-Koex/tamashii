import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/api/tenrai_api.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/featured_poster_faces_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/featured_poster_faces.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/widgets/show_image.dart';

const _showTitle = 'Meitantei Precure!';
const _posterPath = '/images/featured-subsplease.jpg';
const _subsPleasePoster = 'https://subsplease.org$_posterPath';
const _tenraiPoster = 'https://example.test/featured-tenrai.jpg';
const _detectedFace = (
  imageSize: Size(40, 60),
  faces: [(left: .20, top: .10, right: .46, bottom: .24, confidence: .95)],
);

void main() {
  late _PosterCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
    cache = _PosterCache();
    CachedNetworkImageProvider.defaultCacheManager = cache;
  });

  testWidgets('a watched featured card uses Tenrai when lookup completes', (
    tester,
  ) async {
    final lookup = Completer<String?>();
    var lookups = 0;
    await _pumpCard(
      tester,
      isBookmarked: true,
      findPoster: () {
        lookups++;
        return lookup.future;
      },
    );

    expect(lookups, 1);
    expect(_imageFor(_subsPleasePoster), findsOneWidget);
    expect(_showImageFor(tester, _posterPath).faceAware, isFalse);
    expect(_imageFor(_tenraiPoster), findsNothing);

    lookup.complete(_tenraiPoster);
    await tester.pump();

    expect(_imageFor(_tenraiPoster), findsOneWidget);
    expect(_showImageFor(tester, _tenraiPoster).faceAware, isTrue);
  });

  for (final (featured, watched) in [(true, false), (false, true)]) {
    testWidgets(
      'uses only SubsPlease when featured is $featured and watching is $watched',
      (tester) async {
        var lookups = 0;
        await _pumpCard(
          tester,
          featured: featured,
          isBookmarked: watched,
          findPoster: () async {
            lookups++;
            return _tenraiPoster;
          },
        );

        expect(lookups, 0);
        expect(_imageFor(_subsPleasePoster), findsOneWidget);
        expect(_showImageFor(tester, _posterPath).faceAware, isFalse);
        expect(_imageFor(_tenraiPoster), findsNothing);
      },
    );
  }

  testWidgets(
    'a featured special uses only its own saved match until explicitly left unmatched',
    (tester) async {
      var lookups = 0;
      await _pumpCard(
        tester,
        isBookmarked: true,
        episode: 'SP1',
        findPoster: () async {
          lookups++;
          return _tenraiPoster;
        },
      );
      final card = tester.widget<ShowCard>(find.byType(ShowCard));
      final target = ShowCatalogTarget.fromRelease(card.show);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShowCard)),
      );
      final choices = container.read(catalogMatchOverridesProvider.notifier);
      const special = TenraiAnimeSearchResult(
        malId: 42,
        title: 'Special',
        imageUrl: _tenraiPoster,
      );

      expect(_imageFor(_subsPleasePoster), findsOneWidget);
      await choices.save(target.copyWith(episode: '03'), special);
      await choices.save(target.copyWith(episode: 'SP2'), special);
      await tester.pump();
      expect(_imageFor(_tenraiPoster), findsNothing);
      await choices.save(target, special);
      await tester.pump();
      expect(_imageFor(_tenraiPoster), findsOneWidget);
      await choices.save(target, null);
      await tester.pump();
      expect(_imageFor(_subsPleasePoster), findsOneWidget);
      expect(_imageFor(_tenraiPoster), findsNothing);
      expect(lookups, 0);
    },
  );

  testWidgets(
    'a regular series correction replaces the automatic poster across regular releases',
    (tester) async {
      var lookups = 0;
      await _pumpCard(
        tester,
        isBookmarked: true,
        findPoster: () async {
          lookups++;
          return _tenraiPoster;
        },
      );
      final card = tester.widget<ShowCard>(find.byType(ShowCard));
      final season = ShowCatalogTarget.fromRelease(card.show)
          .copyWith(episode: '02');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShowCard)),
      );
      final choices = container.read(catalogMatchOverridesProvider.notifier);
      const preferred = 'https://example.test/correct-season.jpg';
      await choices.save(
        season,
        const TenraiAnimeSearchResult(
          malId: 2,
          title: 'Season',
          largeImageUrl: preferred,
        ),
      );
      await tester.pump();
      expect(_imageFor(preferred), findsOneWidget);
      await choices.save(season, null);
      await tester.pump();
      expect(_imageFor(_subsPleasePoster), findsOneWidget);
      expect(_imageFor(_tenraiPoster), findsNothing);
      final numberedExtra = ShowCatalogTarget.fromRelease(card.show)
          .forThisRelease;
      await choices.save(
        numberedExtra,
        const TenraiAnimeSearchResult(
          malId: 9,
          title: 'Bonus',
          imageUrl: preferred,
        ),
      );
      await tester.pump();
      expect(_imageFor(preferred), findsOneWidget);
      await choices.save(numberedExtra, null);
      await tester.pump();
      expect(_imageFor(_subsPleasePoster), findsOneWidget);
      expect(lookups, 1);
    },
  );

  testWidgets(
    'removing a featured show from watching keeps its catalog identity',
    (tester) async {
      await _pumpCard(
        tester,
        isBookmarked: true,
        findPoster: () async => _tenraiPoster,
      );
      expect(_imageFor(_tenraiPoster), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShowCard)),
      );
      await container
          .read(bookmarkedSeriesProvider.notifier)
          .remove(_showTitle);
      await tester.pump();

      expect(_imageFor(_tenraiPoster), findsOneWidget);
      expect(_showImageFor(tester, _tenraiPoster).faceAware, isFalse);
      expect(find.text('Star Detective'), findsOneWidget);
    },
  );

  testWidgets('unwatched index rows use the saved canonical title and poster', (
    tester,
  ) async {
    final target = const ShowCatalogTarget(title: _showTitle);
    SharedPreferences.setMockInitialValues({
      'catalog_match.${target.scopeKey}':
          '{"mal_id":1,"title":"Star Detective","images":{"jpg":{"image_url":"$_tenraiPoster"}}}',
    });
    await _pumpCard(
      tester,
      featured: false,
      isBookmarked: false,
      findPoster: () => throw StateError('unexpected discovery'),
    );
    expect(find.text('Star Detective'), findsOneWidget);
    expect(_imageFor(_tenraiPoster), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as watching'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShowCard)),
    );
    expect(
      (await container.read(bookmarkedSeriesProvider.future)).single.showName,
      _showTitle,
    );
  });

  testWidgets('no matching Tenrai poster keeps the SubsPlease artwork', (
    tester,
  ) async {
    await _pumpCard(tester, isBookmarked: true, findPoster: () async => null);

    expect(_imageFor(_subsPleasePoster), findsOneWidget);
    expect(_showImageFor(tester, _posterPath).faceAware, isTrue);
    expect(_imageFor(_tenraiPoster), findsNothing);
  });

  testWidgets('a failed Tenrai lookup keeps the SubsPlease artwork', (
    tester,
  ) async {
    final lookup = Completer<String?>();
    await _pumpCard(
      tester,
      isBookmarked: true,
      findPoster: () => lookup.future,
    );

    lookup.completeError(StateError('Tenrai is unavailable'));
    await tester.pump();

    expect(_imageFor(_subsPleasePoster), findsOneWidget);
    expect(_showImageFor(tester, _posterPath).faceAware, isTrue);
    expect(_imageFor(_tenraiPoster), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unavailable Tenrai image falls back to SubsPlease artwork', (
    tester,
  ) async {
    cache.failingUrl = _tenraiPoster;
    await _pumpCard(
      tester,
      isBookmarked: true,
      findPoster: () async => _tenraiPoster,
    );
    await tester.pump();

    expect(
      cache.requestedUrls,
      containsAll([_subsPleasePoster, _tenraiPoster]),
    );
    expect(_imageFor(_subsPleasePoster), findsOneWidget);
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded Tenrai artwork reframes after its face result arrives', (
    tester,
  ) async {
    await _primeDecodedPoster(tester, _tenraiPoster);
    final detection = Completer<FeaturedPosterFaceResult?>();
    final inspectedUrls = <String>[];
    await _pumpCard(
      tester,
      isBookmarked: true,
      findPoster: () async => _tenraiPoster,
      detectFaces: (url) {
        inspectedUrls.add(url);
        return detection.future;
      },
    );

    expect(inspectedUrls, [_tenraiPoster]);
    final renderedPhoto = _renderedPoster(_tenraiPoster);
    expect(tester.widget<RawImage>(renderedPhoto).alignment, Alignment.center);

    detection.complete(_detectedFace);
    await tester.pumpAndSettle();

    final alignment = tester.widget<RawImage>(renderedPhoto).alignment;
    expect(alignment.resolve(TextDirection.ltr).y, lessThan(-.5));
    expect(tester.widget<RawImage>(renderedPhoto).fit, BoxFit.cover);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('an unavailable Tenrai image analyzes only the fallback poster', (
    tester,
  ) async {
    await _primeDecodedPoster(tester, _subsPleasePoster);
    final failure = Completer<void>();
    cache.failingUrl = _tenraiPoster;
    cache.failureGate = failure.future;
    final inspectedUrls = <String>[];
    await _pumpCard(
      tester,
      isBookmarked: true,
      findPoster: () async => _tenraiPoster,
      detectFaces: (url) async {
        inspectedUrls.add(url);
        return _detectedFace;
      },
    );

    expect(inspectedUrls, isEmpty);
    expect(_renderedPoster(_subsPleasePoster), findsNothing);

    failure.complete();
    await tester.pumpAndSettle();

    expect(inspectedUrls, [_subsPleasePoster]);
    final alignment = tester
        .widget<RawImage>(_renderedPoster(_subsPleasePoster))
        .alignment;
    expect(alignment.resolve(TextDirection.ltr).y, lessThan(-.5));
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('non-Android artwork keeps its centered crop', (tester) async {
    await _primeDecodedPoster(tester, _tenraiPoster);
    final inspectedUrls = <String>[];
    await _pumpCard(
      tester,
      isBookmarked: true,
      findPoster: () async => _tenraiPoster,
      detectFaces: (url) async {
        inspectedUrls.add(url);
        return _detectedFace;
      },
    );
    await tester.pumpAndSettle();

    expect(inspectedUrls, isEmpty);
    expect(
      tester.widget<RawImage>(_renderedPoster(_tenraiPoster)).alignment,
      Alignment.center,
    );
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
}

Finder _imageFor(String url) => find.byWidgetPredicate(
  (widget) => widget is CachedNetworkImage && widget.imageUrl == url,
  description: 'poster at $url',
);

ShowImage _showImageFor(WidgetTester tester, String url) =>
    tester.widget<ShowImage>(
      find.byWidgetPredicate(
        (widget) => widget is ShowImage && widget.imageUrl == url,
      ),
    );

Finder _renderedPoster(String url) => find.descendant(
  of: find.byWidgetPredicate((widget) {
    if (widget is! Image) return false;
    final image = widget.image;
    final provider = image is ResizeImage ? image.imageProvider : image;
    return provider is CachedNetworkImageProvider && provider.url == url;
  }),
  matching: find.byWidgetPredicate(
    (widget) => widget is RawImage && widget.image != null,
  ),
);

Future<void> _primeDecodedPoster(WidgetTester tester, String url) async {
  // The two-column feature uses the 192px decode bucket at this viewport.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(422, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final decoded = picture.toImageSync(40, 60);
  picture.dispose();
  final resized = ResizeImage(CachedNetworkImageProvider(url), width: 192);
  final key = await resized.obtainKey(ImageConfiguration.empty);
  PaintingBinding.instance.imageCache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: decoded)),
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  bool featured = true,
  String episode = '1',
  required bool isBookmarked,
  required Future<String?> Function() findPoster,
  Future<FeaturedPosterFaceResult?> Function(String)? detectFaces,
}) async {
  final show = ShowInfo(
    downloads: const [],
    episode: episode,
    imageUrl: _posterPath,
    page: 'meitantei-precure',
    releaseDate: DateTime(2026, 2),
    show: _showTitle,
    timeLabel: '20:30',
    xdcc: '',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookmarkedSeriesProvider.overrideWith(
          () => _BookmarkedSeries(isBookmarked),
        ),
        torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
        tenraiApiProvider.overrideWithValue(_PosterCatalog(findPoster)),
        for (final url in [_subsPleasePoster, _tenraiPoster])
          featuredPosterFacesProvider(url)
              .overrideWith((ref) async => detectFaces?.call(url)),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShowCard(show: show, featured: featured),
          ),
        ),
      ),
    ),
  );
  // The saved watching state and scoped match are read before starting
  // the optional catalog poster lookup.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

class _BookmarkedSeries extends BookmarkedSeriesNotifier {
  _BookmarkedSeries(this.isBookmarked);

  final bool isBookmarked;

  @override
  Future<List<BookmarkedShowInfo>> build() async => [
    if (isBookmarked)
      const BookmarkedShowInfo(
        imageUrl: _posterPath,
        releaseDayOfWeek: DateTime.sunday,
        showName: _showTitle,
      ),
  ];
}

class _PosterCatalog extends Fake implements TenraiApi {
  _PosterCatalog(this.findPoster);
  final Future<String?> Function() findPoster;

  @override
  Future<List<TenraiAnimeSearchResult>> searchAnime(
    String query, {
    int limit = 10,
  }) async {
    final poster = await findPoster();
    return [
      if (poster != null)
        TenraiAnimeSearchResult(
          malId: 1,
          title: _showTitle,
          titleEnglish: 'Star Detective',
          type: 'TV',
          largeImageUrl: poster,
        ),
    ];
  }
}

class _PosterCache extends Fake implements BaseCacheManager {
  final requestedUrls = <String>[];
  String? failingUrl;
  Future<void>? failureGate;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    requestedUrls.add(url);
    if (url != failingUrl) return const Stream.empty();
    final failure = StateError('Poster is unavailable');
    final gate = failureGate;
    return gate == null
        ? Stream.error(failure)
        : Stream.fromFuture(gate.then<FileResponse>((_) => throw failure));
  }
}
