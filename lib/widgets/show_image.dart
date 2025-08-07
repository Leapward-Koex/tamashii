// lib/widgets/show_image.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/show_models.dart';
import '../providers/subsplease_api_providers.dart';

/// A widget that displays a show's image, resolving either full URLs or API-relative paths.
class ShowImage extends ConsumerWidget {
  final ShowInfo show;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ShowImage({
    Key? key,
    required this.show,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsPleaseApiProvider);
    final imageUrl =
        show.imageUrl.startsWith('http')
            ? show.imageUrl
            : '${api.baseUrl}${show.imageUrl}';

    return CachedNetworkImage(
      imageUrl: imageUrl,
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
