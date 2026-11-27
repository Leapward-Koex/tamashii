import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/providers/featured_poster_faces_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/services/featured_poster_crop.dart';

/// A widget that displays a show's image, resolving either full URLs or API-relative paths.
class ShowImage extends ConsumerWidget {
  final String imageUrl;
  final String? fallbackImageUrl;
  final bool faceAware;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ShowImage({
    super.key,
    required this.imageUrl,
    this.fallbackImageUrl,
    this.faceAware = false,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = imageUrl.trim();
    final fallbackUrl = fallbackImageUrl?.trim();
    final canFrameFaces =
        faceAware &&
        fit == BoxFit.cover &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    Widget? fallback() {
      if (fallbackUrl == null || fallbackUrl == path) return null;
      return ShowImage(
        imageUrl: fallbackUrl,
        width: width,
        height: height,
        fit: fit,
        faceAware: canFrameFaces,
      );
    }

    const brokenImage = Center(child: Icon(Icons.broken_image, size: 40));
    final parsed = Uri.tryParse(path);
    final Uri? resolved;
    if (path.isEmpty || parsed == null) {
      resolved = null;
    } else if (parsed.hasScheme) {
      resolved = parsed;
    } else {
      final baseUrl = ref.watch(
        subsPleaseApiProvider.select((api) => api.baseUrl),
      );
      final base = Uri.tryParse(baseUrl);
      resolved = base?.resolve(path.startsWith('/') ? path : '/$path');
    }

    if (resolved == null || !resolved.hasAuthority) {
      return SizedBox(
        width: width,
        height: height,
        child: fallback() ?? brokenImage,
      );
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final url = resolved.toString();

    Widget buildImage(double? displayWidth, double? displayHeight) {
      final memoryWidth = _decodePixels(displayWidth, devicePixelRatio);
      final memoryHeight = memoryWidth == null
          ? _decodePixels(displayHeight, devicePixelRatio)
          : null;
      final target = Size(displayWidth ?? 0, displayHeight ?? 0);
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        // A single decode dimension preserves the source aspect ratio and lets
        // the same cached image serve different card heights.
        memCacheWidth: memoryWidth,
        memCacheHeight: memoryHeight,
        imageBuilder: canFrameFaces && target.isFinite && !target.isEmpty
            ? (context, provider) => Consumer(
                builder: (context, ref, child) {
                  final detection = ref
                      .watch(featuredPosterFacesProvider(url))
                      .asData
                      ?.value;
                  final alignment = detection == null
                      ? Alignment.center
                      : featuredPosterAlignment(
                          source: detection.imageSize,
                          target: target,
                          faces: detection.faces,
                        );
                  // OctoImage already loaded this key before invoking imageBuilder.
                  return Image(
                    image: ResizeImage.resizeIfNeeded(
                      memoryWidth,
                      memoryHeight,
                      provider,
                    ),
                    width: width,
                    height: height,
                    fit: fit,
                    alignment: alignment,
                    errorBuilder: (context, error, stackTrace) =>
                        fallback() ?? brokenImage,
                  );
                },
              )
            : null,
        // A cached catalog match should never flash the source artwork while
        // the selected cover decodes. Use the alternate only on failure.
        placeholder: (context, url) => const SizedBox.expand(),
        errorWidget: (context, url, error) => fallback() ?? brokenImage,
      );
    }

    if (width != null && height != null) {
      return buildImage(width, height);
    }
    return LayoutBuilder(
      builder: (context, constraints) => buildImage(
        width ?? constraints.maxWidth,
        height ?? constraints.maxHeight,
      ),
    );
  }

  int? _decodePixels(double? logicalPixels, double devicePixelRatio) {
    if (logicalPixels == null ||
        !logicalPixels.isFinite ||
        logicalPixels <= 0) {
      return null;
    }
    // Group nearby render sizes to reuse decoded images during window resizing.
    const bucketSize = 32;
    return (logicalPixels * devicePixelRatio / bucketSize).ceil() * bucketSize;
  }
}
