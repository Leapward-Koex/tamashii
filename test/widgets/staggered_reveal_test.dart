import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';

void main() {
  testWidgets('staggered reveal fades and slides into place', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StaggeredReveal(
            index: 2,
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );

    final fadeFinder = find.byKey(StaggeredReveal.fadeKeyForIndex(2));

    expect(tester.widget<FadeTransition>(fadeFinder).opacity.value, equals(0));
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(StaggeredReveal.slideKeyForIndex(2)),
          )
          .position
          .value
          .dy,
      closeTo(0.08, 0.001),
    );

    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      tester.widget<FadeTransition>(fadeFinder).opacity.value,
      greaterThan(0),
    );

    await tester.pumpAndSettle();

    expect(tester.widget<FadeTransition>(fadeFinder).opacity.value, equals(1));
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(StaggeredReveal.slideKeyForIndex(2)),
          )
          .position
          .value,
      Offset.zero,
    );
  });
}
