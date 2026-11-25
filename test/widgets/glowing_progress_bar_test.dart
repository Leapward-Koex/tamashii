import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';

const _fillKey = ValueKey<String>('test-progress-fill');

Widget _bar(
  double progress, {
  double width = 200,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: direction,
            child: SizedBox(
              width: width,
              child: GlowingProgressBar(progress: progress, fillKey: _fillKey),
            ),
          ),
        ),
      ),
    ),
  );
}

double _fillWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(_fillKey)).width;

void main() {
  testWidgets('progress eases to each value across multiple frames', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(0.25));
    final start = _fillWidth(tester);
    expect(start, 50);

    await tester.pumpWidget(_bar(0.75));
    expect(_fillWidth(tester), start);

    final positions = <double>[];
    var previous = start;
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 48));
      final position = _fillWidth(tester);
      expect(position, greaterThan(previous));
      positions.add(position);
      previous = position;
    }

    expect(positions.first, lessThan(150));
    expect(positions[1] - positions.first, greaterThan(150 - positions[3]));
    expect(positions.last, 150);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('frequent updates continue from the visible progress', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(0));
    await tester.pumpWidget(_bar(0.5));
    await tester.pump(const Duration(milliseconds: 80));

    final firstSample = _fillWidth(tester);
    expect(firstSample, inExclusiveRange(0, 100));

    await tester.pumpWidget(_bar(0.75));
    expect(_fillWidth(tester), closeTo(firstSample, 0.001));
    await tester.pump(const Duration(milliseconds: 80));
    final secondSample = _fillWidth(tester);
    expect(secondSample, inExclusiveRange(firstSample, 150));

    await tester.pumpWidget(_bar(0.35));
    expect(_fillWidth(tester), closeTo(secondSample, 0.001));
    await tester.pumpAndSettle();
    expect(_fillWidth(tester), 70);
  });

  testWidgets('resizing retains the visible progress fraction', (tester) async {
    await tester.pumpWidget(_bar(0.25));
    await tester.pumpWidget(_bar(0.75));
    await tester.pump(const Duration(milliseconds: 100));
    final originalWidth = _fillWidth(tester);

    await tester.pumpWidget(_bar(0.75, width: 120));

    expect(_fillWidth(tester), closeTo(originalWidth * 0.6, 0.001));
    await tester.pumpAndSettle();
    expect(_fillWidth(tester), 90);
  });

  testWidgets('reduced motion settles immediately, including mid-flight', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_bar(0.2));
    await tester.pumpWidget(_bar(0.8));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_fillWidth(tester), inExclusiveRange(40, 160));

    await tester.pumpWidget(_bar(0.8, reduceMotion: true));
    expect(_fillWidth(tester), 160);

    await tester.pumpWidget(_bar(0.4, reduceMotion: true));
    expect(_fillWidth(tester), 80);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Download progress')).value,
      '40%',
    );
    semantics.dispose();
  });

  testWidgets('the fill starts at the right edge in RTL layouts', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(0.25, direction: TextDirection.rtl));

    final track = tester.getRect(find.byType(GlowingProgressBar));
    final fill = tester.getRect(find.byKey(_fillKey));
    expect(fill.right, track.right);
    expect(fill.width, 50);
  });

  testWidgets('progress clamps out-of-range and non-finite values', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(-0.5));
    expect(_fillWidth(tester), 0);

    await tester.pumpWidget(_bar(1.5));
    await tester.pumpAndSettle();
    expect(_fillWidth(tester), 200);

    await tester.pumpWidget(_bar(double.nan));
    await tester.pumpAndSettle();
    expect(_fillWidth(tester), 0);
  });
}
