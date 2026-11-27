import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/widgets/widget_download_setup.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(WidgetDownloadSetup.channel, null),
  );

  testWidgets('launcher setup targets the selected show and can be cancelled', (
    tester,
  ) async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(WidgetDownloadSetup.channel, (
      call,
    ) async {
      calls.add(call.method);
      return 'Night Ferry';
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedShowCatalogMatchProvider(
            const ShowCatalogTarget(title: 'Night Ferry'),
          ).overrideWithValue(
            const ShowCatalogMatch(
              entry: TenraiAnimeSearchResult(
                malId: 4,
                title: 'The Night Ferry',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: WidgetDownloadSetup(child: Scaffold(body: Text('Home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set up downloads for The Night Ferry'), findsOneWidget);
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
      isTrue,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, ['takeSetupTitle']);
  });

  testWidgets('a normal launch takes the user directly to Home', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      WidgetDownloadSetup.channel,
      (_) async => null,
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WidgetDownloadSetup(child: Scaffold(body: Text('Home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
