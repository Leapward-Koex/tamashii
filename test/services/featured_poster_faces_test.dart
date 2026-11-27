import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/services/featured_poster_faces.dart';

const _poster = 'https://cdn.example.test/poster.jpg';
const _channel = MethodChannel('tamashii/featured_poster_faces');
const _detection = {
  'width': 427,
  'height': 600,
  'faces': [
    [0.1, 0.2, 0.4, 0.5, 0.9],
  ],
};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _ImageCache cache;
  late List<MethodCall> calls;

  void respondWith(Future<Object?> Function() response) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) {
      calls.add(call);
      return response();
    });
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    calls = [];
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
    cache = _ImageCache()..add(_poster, '/poster.jpg', 'tenrai');
    // The static cache belongs to this test file's isolate.
    CachedNetworkImageProvider.defaultCacheManager = cache;
    respondWith(() async => _detection);
  });

  test(
    'uses the renderer cache and shares simultaneous poster requests',
    () async {
      final detector = FeaturedPosterFaces();
      final results = await Future.wait([
        detector.detectForUrl(_poster),
        detector.detectForUrl(_poster),
      ]);

      expect(cache.requests, [_poster]);
      expect(calls.single.method, 'detectFaces');
      expect(calls.single.arguments, {'path': '/poster.jpg'});
      expect(results.first?.imageSize, const Size(427, 600));
      expect(results.first?.faces.single, (
        left: 0.1,
        top: 0.2,
        right: 0.4,
        bottom: 0.5,
        confidence: 0.9,
      ));
      expect(results.last, results.first);
    },
  );

  test(
    'persists successful empty results until the image bytes change',
    () async {
      respondWith(() async => {'width': 427, 'height': 600, 'faces': []});
      expect(
        (await FeaturedPosterFaces().detectForUrl(_poster))?.faces,
        isEmpty,
      );
      expect(
        (await FeaturedPosterFaces().detectForUrl(_poster))?.faces,
        isEmpty,
      );
      expect(calls, hasLength(1));

      cache.add(_poster, '/poster.jpg', 'updated poster');
      expect(
        (await FeaturedPosterFaces().detectForUrl(_poster))?.faces,
        isEmpty,
      );
      expect(calls, hasLength(2));
    },
  );

  test(
    'a cache miss falls back without fetching or analyzing artwork',
    () async {
      const missing = 'https://cdn.example.test/missing.jpg';
      expect(await FeaturedPosterFaces().detectForUrl(missing), isNull);
      expect(cache.requests, [missing]);
      expect(calls, isEmpty);
    },
  );

  test(
    'reuses geometry when different URLs point to identical bytes',
    () async {
      const alternate = 'https://second.example.test/poster.jpg';
      cache.add(alternate, '/alternate.jpg', 'tenrai');
      final detector = FeaturedPosterFaces();

      await Future.wait([
        detector.detectForUrl(_poster),
        detector.detectForUrl(alternate),
      ]);
      expect(calls, hasLength(1));
    },
  );

  test('a failed detector response stays eligible for a later retry', () async {
    final detector = FeaturedPosterFaces();
    respondWith(() async => throw PlatformException(code: 'temporary'));
    expect(await detector.detectForUrl(_poster), isNull);
    respondWith(() async => _detection);
    expect(await detector.detectForUrl(_poster), isNotNull);
    expect(calls, hasLength(2));
  });

  test('bounds the disk cache as distinct artworks are analyzed', () async {
    final detector = FeaturedPosterFaces();
    for (var index = 0; index < 100; index++) {
      cache.add(_poster, '/poster.jpg', 'poster version $index');
      expect(await detector.detectForUrl(_poster), isNotNull);
    }
    final prefs = SharedPreferencesAsync();
    final contents = await prefs.getString('featured_poster_faces_v1');
    expect(jsonDecode(contents!) as Map, hasLength(96));
  });

  test('other platforms skip both the image cache and native calls', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await FeaturedPosterFaces().detectForUrl(_poster), isNull);
    expect(cache.requests, isEmpty);
    expect(calls, isEmpty);
  });
}

class _ImageCache extends Fake implements BaseCacheManager {
  final _files = MemoryFileSystem.test();
  final _responses = <String, FileInfo>{};
  final requests = <String>[];

  void add(String url, String path, String bytes) {
    final file = _files.file(path)..writeAsStringSync(bytes);
    _responses[url] = FileInfo(file, FileSource.Cache, DateTime(2030), url);
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    requests.add(key);
    return _responses[key];
  }
}
