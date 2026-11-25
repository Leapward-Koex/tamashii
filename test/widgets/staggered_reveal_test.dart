import 'package:material_ui/material_ui.dart';
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

  testWidgets('reduced motion skips the delayed fade and slide', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StaggeredReveal(index: 5, child: Text('Visible immediately')),
        ),
      ),
    );

    expect(find.text('Visible immediately'), findsOneWidget);
    expect(find.byKey(StaggeredReveal.fadeKeyForIndex(5)), findsNothing);
    expect(find.byKey(StaggeredReveal.slideKeyForIndex(5)), findsNothing);
  });

  testWidgets('rows mounted during scrolling skip the entrance animation', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemExtent: 100,
                itemBuilder: (context, index) =>
                    StaggeredReveal(index: index, child: Text('Row $index')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(StaggeredReveal.fadeKeyForIndex(0)), findsOneWidget);
    expect(find.text('Row 7'), findsNothing);
    await tester.pumpAndSettle();
    final animation = controller.animateTo(
      740,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));

    expect(controller.position.isScrollingNotifier.value, isTrue);
    expect(find.text('Row 7'), findsOneWidget);
    expect(find.byKey(StaggeredReveal.fadeKeyForIndex(7)), findsNothing);
    await tester.pumpAndSettle();
    await animation;
    expect(find.text('Row 7'), findsOneWidget);
    expect(find.byKey(StaggeredReveal.fadeKeyForIndex(7)), findsNothing);
  });
}
