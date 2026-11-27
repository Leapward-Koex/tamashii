import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/widgets/widget_download_setup.dart';

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
      const ProviderScope(
        child: MaterialApp(
          home: WidgetDownloadSetup(child: Scaffold(body: Text('Home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set up downloads for Night Ferry'), findsOneWidget);
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
