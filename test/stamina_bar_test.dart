import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/ui/stamina_bar.dart';

void main() {
  Widget bar(double value, {bool reducedMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 200, child: StaminaBar(pct: value)),
        ),
      ),
    ),
  );

  double fill(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
      .widthFactor!;

  testWidgets('stamina drains, retargets and refills smoothly with its label', (
    tester,
  ) async {
    await tester.pumpWidget(bar(1));
    expect(fill(tester), 1);
    await tester.pumpWidget(bar(.2));
    expect(fill(tester), 1);
    await tester.pump(const Duration(milliseconds: 100));
    final middle = fill(tester);
    expect(middle, inExclusiveRange(.2, 1));
    expect(find.text('${(middle * 100).round()}%'), findsOneWidget);
    await tester.pumpWidget(bar(.8));
    expect(fill(tester), middle);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill(tester), inExclusiveRange(middle, .8));
    await tester.pumpAndSettle();
    expect(fill(tester), .8);
    await tester.pumpWidget(bar(0));
    await tester.pumpAndSettle();
    expect(fill(tester), 0);
    expect(find.text('0%'), findsOneWidget);
    await tester.pumpWidget(bar(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('reduced motion updates stamina immediately and clamps values', (
    tester,
  ) async {
    await tester.pumpWidget(bar(2, reducedMotion: true));
    expect(fill(tester), 1);
    await tester.pumpWidget(bar(-1, reducedMotion: true));
    await tester.pump();
    expect(fill(tester), 0);
    expect(find.text('0%'), findsOneWidget);
  });
}
