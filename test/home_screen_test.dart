/// Home (MM-01) and the pages it opens, at the reference phone size.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/ui/home_pages.dart';
import 'package:d30mode/ui/home_screen.dart';

void main() {
  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1080 / 390;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
  }

  testWidgets('Home has the menu stack without Rank', (tester) async {
    await pumpPhone(tester, const HomeScreen());
    await tester.pump();
    for (final label in [
      'Traits',
      'Puzzles',
      'Records',
      'Missions',
      'Achievements',
      'Start',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Rank'), findsNothing);
    expect(find.byKey(const ValueKey('home-balance')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-settings')), findsOneWidget);
    // The stack runs off the right edge, with each label on screen. (The
    // test font draws every glyph square, so widths here overstate.)
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final key in ['home-traits', 'home-achievements', 'home-start']) {
      final box = tester.getRect(find.byKey(ValueKey(key)));
      expect(box.right, greaterThanOrEqualTo(width), reason: key);
      expect(box.left, greaterThan(0), reason: key);
    }
  });

  testWidgets('the four arrows show the scene; a tap brings the menu back', (
    tester,
  ) async {
    await pumpPhone(tester, const HomeScreen());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-scene')));
    await tester.pump();
    expect(find.text('Start'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-scene-only')));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('History lays out under its header', (tester) async {
    await pumpPhone(tester, const HistoryPage());
    await tester.pump();
    expect(find.text('History'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-back')), findsOneWidget);
  });

  testWidgets('Select Game lays out its plus tile', (tester) async {
    await pumpPhone(
      tester,
      SelectGamePage(onNewGame: () async {}, onContinue: (_) async {}),
    );
    await tester.pump();
    expect(find.text('Select Game'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-game')), findsOneWidget);
  });
}
