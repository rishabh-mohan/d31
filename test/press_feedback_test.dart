import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/ui/press_feedback.dart';
import 'package:d30mode/ui/theme.dart';

void main() {
  testWidgets('press moves over time, releases and keeps one click', (
    tester,
  ) async {
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressFeedback(
              child: FilledButton(
                key: const ValueKey('button'),
                onPressed: () => clicks++,
                child: const Text('Confirm'),
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('button'));
    final start = tester.getCenter(button);
    final width = tester.getTopRight(button).dx - tester.getTopLeft(button).dx;
    final height =
        tester.getBottomLeft(button).dy - tester.getTopLeft(button).dy;
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    final halfway = tester.getCenter(button).dy;
    expect(halfway, greaterThan(start.dy));
    expect(halfway, lessThan(start.dy + 3));
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getCenter(button).dy, closeTo(start.dy + 3, .01));
    expect(
      tester.getTopRight(button).dx - tester.getTopLeft(button).dx,
      closeTo(width, .01),
    );
    expect(
      tester.getBottomLeft(button).dy - tester.getTopLeft(button).dy,
      closeTo(height, .01),
    );
    await gesture.up();
    expect(clicks, 1);
    await tester.pumpAndSettle();
    expect(tester.getCenter(button), start);
  });

  testWidgets(
    'raised face covers its fixed lower face and keeps border thickness',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: D30RaisedButton(
                onPressed: () {},
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      final face = find.byType(FilledButton);
      final base = find
          .ancestor(
            of: find.byType(PressFeedback),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final basePosition = tester.getTopLeft(base);
      final facePosition = tester.getTopLeft(face);
      final faceWidth = tester.getTopRight(face).dx - facePosition.dx;
      final gesture = await tester.startGesture(tester.getCenter(face));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(base), basePosition);
      expect(tester.getTopLeft(face).dy, closeTo(facePosition.dy + 6, .01));
      expect(
        tester.getTopRight(face).dx - tester.getTopLeft(face).dx,
        closeTo(faceWidth, .01),
      );
      final shape = tester
          .widget<FilledButton>(face)
          .style!
          .shape!
          .resolve({})!;
      expect(shape.side.width, 2);
      final decoration =
          tester.widget<DecoratedBox>(base).decoration as BoxDecoration;
      expect(decoration.boxShadow!.first.offset.dy, 6);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(face), facePosition);
    },
  );

  testWidgets('cancel and leaving restore the button; disabled stays still', (
    tester,
  ) async {
    var clicks = 0;
    Future<void> show(bool enabled) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressFeedback(
              child: FilledButton(
                key: const ValueKey('button'),
                onPressed: enabled ? () => clicks++ : null,
                child: const Text('Confirm'),
              ),
            ),
          ),
        ),
      ),
    );
    await show(true);
    final button = find.byKey(const ValueKey('button'));
    final start = tester.getCenter(button);
    var gesture = await tester.startGesture(start);
    await tester.pumpAndSettle();
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.getCenter(button), start);
    await gesture.cancel();
    gesture = await tester.startGesture(start);
    await tester.pumpAndSettle();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getCenter(button), start);
    expect(clicks, 0);
    await show(false);
    gesture = await tester.startGesture(start);
    await tester.pumpAndSettle();
    expect(tester.getCenter(button), start);
    await gesture.up();
    expect(clicks, 0);
  });
}
