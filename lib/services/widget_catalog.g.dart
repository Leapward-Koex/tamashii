// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_catalog.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Also used by a newly added widget when an app upgrade has never opened the UI.

@ProviderFor(widgetCatalog)
final widgetCatalogProvider = WidgetCatalogProvider._();

/// Also used by a newly added widget when an app upgrade has never opened the UI.

final class WidgetCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Object>>,
          Map<String, Object>,
          FutureOr<Map<String, Object>>
        >
    with
        $FutureModifier<Map<String, Object>>,
        $FutureProvider<Map<String, Object>> {
  /// Also used by a newly added widget when an app upgrade has never opened the UI.
  WidgetCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetCatalogHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Object>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Object>> create(Ref ref) {
    return widgetCatalog(ref);
  }
}

String _$widgetCatalogHash() => r'cc15b615dd141f7f718a541d35e268ccfd716ec4';
