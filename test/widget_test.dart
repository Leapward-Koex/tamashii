// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/models/download_transfer_metrics.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/services/download_transfer_metrics.dart';

import 'package:tamashii/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadQueueProvider.overrideWithValue(
            DownloadTransferMetrics.build(const <DownloadTransferSnapshot>[]),
          ),
        ],
        child: const TamashiiApp(),
      ),
    );

    // Verify that our app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
