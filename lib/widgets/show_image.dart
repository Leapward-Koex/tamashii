// lib/widgets/show_image.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/models/show_models.dart';
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
    final resolvedImageUrl =
        imageUrl.startsWith('http') ? imageUrl : '${api.baseUrl}$imageUrl';

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
}
