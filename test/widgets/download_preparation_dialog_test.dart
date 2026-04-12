import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/widgets/download_preparation_dialog.dart';

void main() {
  testWidgets('shows progress text while download preparation is running', (
    WidgetTester tester,
  ) async {
    final operationCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Center(
                  child: FilledButton(
                    onPressed: () {
                      runWithDownloadPreparationDialog<void>(
                        context: context,
                        action: () => operationCompleter.future,
                      );
                    },
                    child: const Text('Start'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Preparing download'), findsOneWidget);
    expect(find.text('Working out download folder...'), findsOneWidget);

    operationCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Preparing download'), findsNothing);
    expect(find.text('Working out download folder...'), findsNothing);
  });
}
