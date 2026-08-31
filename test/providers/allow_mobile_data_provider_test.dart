import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'mobile data defaults to false and persists across provider containers',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();

      final firstContainer = ProviderContainer();
      expect(
        await firstContainer.read(allowMobileDataProvider.future),
        isFalse,
      );

      await firstContainer
          .read(allowMobileDataProvider.notifier)
          .setAllowed(true);
      expect(
        await firstContainer.read(allowMobileDataProvider.future),
        isTrue,
      );
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      expect(
        await secondContainer.read(allowMobileDataProvider.future),
        isTrue,
      );
    },
  );
}
