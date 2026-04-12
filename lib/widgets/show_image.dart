// lib/widgets/show_image.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';

/// A widget that displays a show's image, resolving either full URLs or API-relative paths.
class ShowImage extends ConsumerWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ShowImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsPleaseApiProvider);
    final resolvedImageUrl = _resolveImageUrl(api.baseUrl, imageUrl);

    if (resolvedImageUrl == null) {
      return SizedBox(
        width: width,
        height: height,
        child: const Center(child: Icon(Icons.broken_image, size: 40)),
      );
    }

    return CachedNetworkImage(
      imageUrl: resolvedImageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder:
          (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget:
          (context, url, error) =>
              const Center(child: Icon(Icons.broken_image, size: 40)),
    );
  }

  String? _resolveImageUrl(String baseUrl, String rawImageUrl) {
    final trimmed = rawImageUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final directUri = Uri.tryParse(trimmed);
    if (directUri != null && directUri.hasScheme) {
      if (!directUri.hasAuthority) {
        return null;
      }
      return directUri.toString();
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null) {
      return null;
    }

    final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final resolvedUri = baseUri.resolve(normalizedPath);
    if (!resolvedUri.hasAuthority) {
      return null;
    }
    return resolvedUri.toString();
  }
}
