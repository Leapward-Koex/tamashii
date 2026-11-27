import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/series_folder_confirmation_dialog.dart';

void main() {
  testWidgets(
    'folder confirmation previews an edited destination before saving',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showSeriesFolderConfirmationDialog(
                    context: context,
                    showTitle: 'Night Ferry',
                    basePath: 'Library',
                    plan: const SeriesFolderResolutionPlan(
                      usedAi: false,
                      seriesFolderName: 'Night Ferry',
                      seasonFolderName: null,
                      suggestedPath: 'Library/Night Ferry',
                      fallbackSeriesFolderName: 'Night Ferry',
                      fallbackPath: 'Library/Night Ferry',
                      existingSeriesFolders: [],
                      rawAiResponse: null,
                      modelUsed: null,
                      reason: null,
                    ),
                  );
                },
                child: const Text('Choose folder'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Suggested Path')).style,
        PaperLantern.folio,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Season Folder Name'),
        '2',
      );
      await tester.pump();
      final destination = buildPath(
        basePath: 'Library',
        seriesFolderName: 'Night Ferry',
        seasonFolderName: 'Season 02',
      );
      expect(find.text(destination), findsOneWidget);
      await tester.tap(find.text('Use This Folder'));
      await tester.pumpAndSettle();
      expect(selected, destination);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
