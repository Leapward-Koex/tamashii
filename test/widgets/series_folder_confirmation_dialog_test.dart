import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/release_download_button.dart';
import 'package:tamashii/widgets/series_folder_confirmation_dialog.dart';

void main() {
  testWidgets(
    'widget setup asks before using an automatically generated folder',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'download_base_path': 'Library',
            'auto_generate_folders': true,
            'series_folder_mapping': '{"Night Ferry":"Old location"}',
          });
      final container = ProviderContainer.test();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => setUpWidgetDownload(
                    context,
                    ref,
                    target: const ShowCatalogTarget(title: 'Night Ferry'),
                    torrentKey: 'Night Ferry-09',
                    magnet: 'test-magnet',
                    seriesFolderPlanBuilder:
                        ({
                          required showTitle,
                          required basePath,
                          required textGenerator,
                        }) async {
                          expect(showTitle, 'Night Ferry');
                          expect(basePath, 'Library');
                          return const SeriesFolderResolutionPlan(
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
                          );
                        },
                  ),
                  child: const Text('Download'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Series Folder'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await container.read(seriesFolderMappingProvider.future), {
        'Night Ferry': 'Old location',
      });
    },
  );

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
