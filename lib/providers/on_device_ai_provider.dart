import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

final onDeviceTextGeneratorProvider = Provider<OnDeviceTextGenerator>((ref) {
  return const PlatformGeminiNanoService();
});

final onDeviceModelCatalogProvider = FutureProvider<OnDeviceModelCatalog>((
  ref,
) async {
  final generator = ref.watch(onDeviceTextGeneratorProvider);
  return await generator.getModelCatalog();
});
