// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'featured_poster_faces_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(featuredPosterFaceDetector)
final featuredPosterFaceDetectorProvider =
    FeaturedPosterFaceDetectorProvider._();

final class FeaturedPosterFaceDetectorProvider
    extends
        $FunctionalProvider<
          FeaturedPosterFaces,
          FeaturedPosterFaces,
          FeaturedPosterFaces
        >
    with $Provider<FeaturedPosterFaces> {
  FeaturedPosterFaceDetectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featuredPosterFaceDetectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featuredPosterFaceDetectorHash();

  @$internal
  @override
  $ProviderElement<FeaturedPosterFaces> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeaturedPosterFaces create(Ref ref) {
    return featuredPosterFaceDetector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeaturedPosterFaces value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeaturedPosterFaces>(value),
    );
  }
}

String _$featuredPosterFaceDetectorHash() =>
    r'e0edf300ca0a4988fecac124c298aa2fc775fdce';

@ProviderFor(featuredPosterFaces)
final featuredPosterFacesProvider = FeaturedPosterFacesFamily._();

final class FeaturedPosterFacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<FeaturedPosterFaceResult?>,
          FeaturedPosterFaceResult?,
          FutureOr<FeaturedPosterFaceResult?>
        >
    with
        $FutureModifier<FeaturedPosterFaceResult?>,
        $FutureProvider<FeaturedPosterFaceResult?> {
  FeaturedPosterFacesProvider._({
    required FeaturedPosterFacesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'featuredPosterFacesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$featuredPosterFacesHash();

  @override
  String toString() {
    return r'featuredPosterFacesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FeaturedPosterFaceResult?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FeaturedPosterFaceResult?> create(Ref ref) {
    final argument = this.argument as String;
    return featuredPosterFaces(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FeaturedPosterFacesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$featuredPosterFacesHash() =>
    r'7e7878d159191128033e091d3068270670209939';

final class FeaturedPosterFacesFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<FeaturedPosterFaceResult?>, String> {
  FeaturedPosterFacesFamily._()
    : super(
        retry: null,
        name: r'featuredPosterFacesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FeaturedPosterFacesProvider call(String imageUrl) =>
      FeaturedPosterFacesProvider._(argument: imageUrl, from: this);

  @override
  String toString() => r'featuredPosterFacesProvider';
}
