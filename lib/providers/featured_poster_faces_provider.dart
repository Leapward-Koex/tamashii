import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamashii/services/featured_poster_faces.dart';

part 'featured_poster_faces_provider.g.dart';

@Riverpod(keepAlive: true)
FeaturedPosterFaces featuredPosterFaceDetector(Ref ref) =>
    FeaturedPosterFaces();

@riverpod
Future<FeaturedPosterFaceResult?> featuredPosterFaces(
  Ref ref,
  String imageUrl,
) {
  return ref.watch(featuredPosterFaceDetectorProvider).detectForUrl(imageUrl);
}
