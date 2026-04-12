import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/api/jikan_api_controller.dart';
import 'package:tamashii/models/jikan_models.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';

final jikanApiControllerProvider = Provider<JikanApiController>((ref) {
  final controller = JikanApiController(
    textGenerator: ref.watch(onDeviceTextGeneratorProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final seriesHotnessProvider = FutureProvider.family<JikanHotness?, String>((
  ref,
  localShowTitle,
) async {
  final controller = ref.watch(jikanApiControllerProvider);
  return controller.getHotnessForSeries(localShowTitle);
});
