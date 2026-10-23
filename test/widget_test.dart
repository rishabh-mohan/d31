/// Widget tests for the panels. These catch layout faults that are invisible
/// on a device (a shrink-wrapped list in an unbounded box renders nothing but
/// logs no error), without needing to tap anything.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/day_transition.dart';
import 'package:d30mode/ui/day_menu.dart';
import 'package:d30mode/ui/location_picker.dart';
import 'package:d30mode/ui/my_info.dart';

late ContentPack pack;

Future<void> main() async {
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  for (final width in [320.0, 393.0]) {
    testWidgets('day menu and detail panels render at $width logical pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      final date = game.state.date;
      var started = false;
      await tester.pumpWidget(
        host(DayMenu(game: game, onStart: () => started = true)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Traits'), findsOneWidget);
      expect(find.text('Stationery'), findsOneWidget);
      expect(
        find.byType(Scrollable),
        findsNothing,
        reason: 'the preparation menu must fit without scrolling',
      );
      for (final title in ['Books', 'Score Card', 'Schedule']) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (title == 'Score Card') {
          expect(find.text('No Score Card yet!'), findsOneWidget);
        }
        if (title == 'Schedule') {
          expect(find.text('Calendar'), findsOneWidget);
          expect(
            tester.getSize(find.byType(Dialog)).height,
            greaterThan(852 * .75),
          );
        }
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
      }
      expect(
        game.state.date,
        date,
        reason: 'Browsing the menu must not consume time',
      );
      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(started, isTrue);
    });
  }

  testWidgets('night recap uses the completed day after engine rollover', (
    tester,
  ) async {
    final game = Game.newRun(pack);
    final day = game.state.date.day;
    final countdown = game.state.daysRemaining;
    final before = DayTransition.snapshot(game.state);
    game.state.date = game.state.date.nextDay();
    await tester.pumpWidget(
      host(
        DayTransition(
          game: game,
          before: before,
          completedDay: day,
          countdown: countdown,
        ),
      ),
    );
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('D-$countdown'), findsOneWidget);
  });

  testWidgets('My Info renders its content, not just a barrier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final game = Game.newRun(pack);
    await tester.pumpWidget(host(MyInfoPanel(game: game)));
    await tester.pumpAndSettle();

    expect(find.text('My Info'), findsOneWidget);
    expect(find.text('Traits'), findsOneWidget);
    expect(find.text('Stationery'), findsOneWidget);
    // The name comes from the pack manifest.
    expect(
      find.text('${pack.manifest.firstName} ${pack.manifest.lastName}'),
      findsOneWidget,
    );
    // Every subject tile is present.
    for (final s in pack.manifest.subjects) {
      expect(
        find.text('${(game.state.stats[s] ?? 0).round()}'),
        findsWidgets,
        reason: 'missing a tile for $s',
      );
    }
  });

  testWidgets('the day transition shows the countdown and the weekday', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final game = Game.newRun(pack);
    final before = DayTransition.snapshot(game.state);
    game.state.stats['korean'] = (game.state.stats['korean'] ?? 0) + 186;

    await tester.pumpWidget(host(DayTransition(game: game, before: before)));
    await tester.pumpAndSettle();

    expect(find.text('D-${game.state.daysRemaining}'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Weekly Goals'), findsOneWidget);
    expect(
      find.text('+186'),
      findsOneWidget,
      reason: 'the day\'s gain should be shown under the subject',
    );
  });

  testWidgets('the location picker lists the unlocked locations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final game = Game.newRun(pack);
    await tester.pumpWidget(
      host(LocationPicker(game: game, title: 'Class is over. Where do I go?')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Class is over. Where do I go?'), findsOneWidget);
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    // Locked locations must not appear.
    expect(find.text('Gold Mine'), findsNothing);
  });
}
