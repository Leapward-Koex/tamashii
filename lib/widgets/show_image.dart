import 'package:material_ui/material_ui.dart';
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
    final path = imageUrl.trim();
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
        child: const Center(child: Icon(Icons.broken_image, size: 40)),
      );
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final url = resolved.toString();

    Widget buildImage(double? displayWidth, double? displayHeight) {
      final memoryWidth = _decodePixels(displayWidth, devicePixelRatio);
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        // A single decode dimension preserves the source aspect ratio and lets
        // the same cached image serve different card heights.
        memCacheWidth: memoryWidth,
        memCacheHeight: memoryWidth == null
            ? _decodePixels(displayHeight, devicePixelRatio)
            : null,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
            const Center(child: Icon(Icons.broken_image, size: 40)),
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
