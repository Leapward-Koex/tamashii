import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/services/featured_poster_crop.dart';

typedef FeaturedPosterFaceResult = ({Size imageSize, List<PosterFace> faces});

/// Finds faces in the same original artwork file used by CachedNetworkImage.
class FeaturedPosterFaces {
  FeaturedPosterFaces({
    this._imageCache,
    SharedPreferencesAsync? preferences,
    MethodChannel? channel,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _channel =
           channel ?? const MethodChannel('tamashii/featured_poster_faces');

  // Change this key when the detector or its input preprocessing changes.
  static const _cacheKey = 'featured_poster_faces_v1';
  static const _maxCachedPosters = 96;
  static const _timeout = Duration(seconds: 15);

  final BaseCacheManager? _imageCache;
  final SharedPreferencesAsync _preferences;
  final MethodChannel _channel;
  final _loading = <String, Future<FeaturedPosterFaceResult?>>{};
  final _detecting = <String, Future<FeaturedPosterFaceResult?>>{};
  late final _cache = _readCache();
  Future<void> _pendingWrite = Future<void>.value();

  Future<FeaturedPosterFaceResult?> detectForUrl(String resolvedUrl) async {
    final uri = Uri.tryParse(resolvedUrl);
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return _loading.putIfAbsent(
      resolvedUrl,
      () => _detectForUrl(resolvedUrl).whenComplete(() {
        _loading.remove(resolvedUrl);
      }),
    );
  }

  Future<FeaturedPosterFaceResult?> _detectForUrl(String url) async {
    try {
      // This runs after image decoding. Use the renderer's original cache
      // entry and let the renderer own all downloads and revalidation.
      final imageCache =
          _imageCache ?? CachedNetworkImageProvider.defaultCacheManager;
      final response = await imageCache.getFileFromCache(url);
      if (response == null) {
        return null;
      }
      final file = response.file;
      final digest = await sha256.bind(file.openRead()).single;
      final contentKey = digest.toString();
      final cache = await _cache;
      final saved = cache[contentKey];
      if (saved != null) {
        return saved;
      }
      return await _detecting.putIfAbsent(
        contentKey,
        () => _detect(file.path, contentKey, cache).whenComplete(() {
          _detecting.remove(contentKey);
        }),
      );
    } catch (_) {
      // Artwork and detection are optional. A later visit can try again.
      return null;
    }
  }

  Future<FeaturedPosterFaceResult?> _detect(
    String path,
    String contentKey,
    Map<String, FeaturedPosterFaceResult> cache,
  ) async {
    final FeaturedPosterFaceResult? result;
    try {
      final raw = await _channel
          .invokeMapMethod<String, Object?>('detectFaces', {'path': path})
          .timeout(_timeout);
      result = _decode(raw);
    } catch (_) {
      return null;
    }
    if (result == null) {
      return null;
    }
    cache[contentKey] = result;
    if (cache.length > _maxCachedPosters) {
      cache.remove(cache.keys.first);
    }
    final snapshot = jsonEncode(
      cache.map(
        (key, value) => MapEntry(key, {
          'width': value.imageSize.width,
          'height': value.imageSize.height,
          'faces': [
            for (final face in value.faces)
              [face.left, face.top, face.right, face.bottom, face.confidence],
          ],
        }),
      ),
    );
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _preferences.setString(_cacheKey, snapshot);
      } catch (_) {
        // The current service can still reuse the in-memory entry.
      }
    });
    await _pendingWrite;
    return result;
  }

  Future<Map<String, FeaturedPosterFaceResult>> _readCache() async {
    final cache = <String, FeaturedPosterFaceResult>{};
    try {
      final saved = await _preferences.getString(_cacheKey);
      final decoded = saved == null ? null : jsonDecode(saved);
      if (decoded is Map<String, dynamic>) {
        final startingIndex = decoded.length > _maxCachedPosters
            ? decoded.length - _maxCachedPosters
            : 0;
        for (final entry in decoded.entries.skip(startingIndex)) {
          final result = _decode(entry.value);
          if (result != null) {
            cache[entry.key] = result;
          }
        }
      }
    } catch (_) {
      // Missing or corrupted cache data just means recomputing the geometry.
    }
    return cache;
  }

  static FeaturedPosterFaceResult? _decode(Object? raw) {
    if (raw
        case {
          'width': final num width,
          'height': final num height,
          'faces': final List<Object?> rawFaces,
        }
        when width.isFinite && width > 0 && height.isFinite && height > 0) {
      final faces = <PosterFace>[];
      for (final face in rawFaces) {
        if (face
            case [
              final num left,
              final num top,
              final num right,
              final num bottom,
              final num confidence,
            ]
            when left >= 0 &&
                left < right &&
                right <= 1 &&
                top >= 0 &&
                top < bottom &&
                bottom <= 1 &&
                confidence >= 0 &&
                confidence <= 1) {
          faces.add((
            left: left.toDouble(),
            top: top.toDouble(),
            right: right.toDouble(),
            bottom: bottom.toDouble(),
            confidence: confidence.toDouble(),
          ));
        } else {
          return null;
        }
      }
      return (
        imageSize: Size(width.toDouble(), height.toDouble()),
        faces: List.unmodifiable(faces),
      );
    }
    return null;
  }
}
