import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';

void main() {
  testWidgets('glowing progress bar animates its filled width', (
    WidgetTester tester,
  ) async {
    final fillKey = UniqueKey();

    Widget buildBar(double progress) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: GlowingProgressBar(progress: progress, fillKey: fillKey),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildBar(0.25));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final initialWidth = tester.getSize(find.byKey(fillKey)).width;
    expect(initialWidth, closeTo(50, 0.5));

    await tester.pumpWidget(buildBar(0.75));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final updatedWidth = tester.getSize(find.byKey(fillKey)).width;
    expect(updatedWidth, greaterThan(initialWidth));
    expect(updatedWidth, closeTo(150, 0.5));
  });

  testWidgets('glowing progress bar keeps in-flight animation continuous', (
    WidgetTester tester,
  ) async {
    final fillKey = UniqueKey();

    Widget buildBar(double progress) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: GlowingProgressBar(progress: progress, fillKey: fillKey),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildBar(0));
    await tester.pumpWidget(buildBar(1));
    await tester.pump(const Duration(milliseconds: 100));

    final inFlightWidth = tester.getSize(find.byKey(fillKey)).width;
    expect(inFlightWidth, greaterThan(0));
    expect(inFlightWidth, lessThan(200));

    await tester.pumpWidget(buildBar(0.75));
    await tester.pump();

    final retargetedWidth = tester.getSize(find.byKey(fillKey)).width;
    expect(retargetedWidth, closeTo(inFlightWidth, 0.5));
  });

  testWidgets('glowing progress bar clamps invalid progress values', (
    WidgetTester tester,
  ) async {
    final fillKey = UniqueKey();

    Widget buildBar(double progress) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: GlowingProgressBar(progress: progress, fillKey: fillKey),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildBar(-0.5));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(fillKey)).width, 0);

    await tester.pumpWidget(buildBar(1.5));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(fillKey)).width, 200);

    await tester.pumpWidget(buildBar(double.nan));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(fillKey)).width, 0);
  });
}
