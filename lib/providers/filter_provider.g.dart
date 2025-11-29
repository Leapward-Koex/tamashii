// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that manages the current filter state and persists it

@ProviderFor(ShowFilterNotifier)
const showFilterProvider = ShowFilterNotifierProvider._();

/// Provider that manages the current filter state and persists it
final class ShowFilterNotifierProvider
    extends $AsyncNotifierProvider<ShowFilterNotifier, ShowFilter> {
  /// Provider that manages the current filter state and persists it
  const ShowFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showFilterNotifierHash();

  @$internal
  @override
  ShowFilterNotifier create() => ShowFilterNotifier();
}

String _$showFilterNotifierHash() =>
    r'9fc1c346952354c4548898681c3b3e261c2b4151';

/// Provider that manages the current filter state and persists it

abstract class _$ShowFilterNotifier extends $AsyncNotifier<ShowFilter> {
  FutureOr<ShowFilter> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<ShowFilter>, ShowFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ShowFilter>, ShowFilter>,
              AsyncValue<ShowFilter>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
