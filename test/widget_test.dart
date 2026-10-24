/// Widget tests for the panels. These catch layout faults that are invisible
/// on a device (a shrink-wrapped list in an unbounded box renders nothing but
/// logs no error), without needing to tap anything.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/day_transition.dart';
import 'package:d30mode/ui/dev_panel.dart';
import 'package:d30mode/ui/day_menu.dart';
import 'package:d30mode/ui/location_picker.dart';
import 'package:d30mode/ui/game_screen.dart';
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
      // A fresh goal announces itself over the hub; acknowledge it first.
      expect(find.text('Check your Weekly Goals'), findsOneWidget);
      await tester.tap(find.text("Let's do this!"));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Traits'), findsOneWidget);
      expect(find.text('Stationery'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hub-traits-scroll')),
        findsOneWidget,
        reason:
            'only the trait list scrolls inside the fitted preparation menu',
      );
      for (final title in ['Books', 'Score Card', 'Calendar']) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (title == 'Score Card') {
          expect(find.text('No Score Card yet!'), findsOneWidget);
        }
        if (title == 'Calendar') {
          expect(find.text('Calendar'), findsNWidgets(2));
          expect(
            tester.getSize(find.byType(Dialog)).width,
            greaterThan(width - 80),
          );
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

  testWidgets('the handoff out of setup shows a dash, not the goal', (
    tester,
  ) async {
    final game = Game.newRun(pack);
    final goal = game.state.weeklyGoal!;
    await tester.pumpWidget(
      host(
        DayTransition(
          game: game,
          before: DayTransition.snapshot(game.state),
          initial: true,
        ),
      ),
    );
    // UIR-08: the objective is announced over the hub afterwards, not here.
    expect(find.text('-'), findsOneWidget);
    expect(
      find.textContaining('Reach ${goal.targetValue}'),
      findsNothing,
      reason: 'the initial handoff carries no goal row',
    );
    expect(find.text('D-${game.state.daysRemaining}'), findsOneWidget);
  });

  for (final size in [const Size(320, 740), const Size(393, 873)]) {
    testWidgets('player portrait tucks behind action panel at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      game.state.date = GameDate(game.state.date.day, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            game: game,
            packLocation: PackLocation('kss16', null, false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final portrait = tester.getRect(
        find.byKey(const ValueKey('game-character')),
      );
      final panel = tester.getRect(find.byKey(const ValueKey('action-panel')));
      expect(portrait.bottom - panel.top, closeTo(76, 1));
      expect(portrait.height, greaterThan(120));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (label, tick, restricted) in [
    ('between days', 0, false),
    ('mid-day', 4, true),
  ]) {
    testWidgets('the menu restricts Main Menu and Save $label', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      game.state.saveSlot = 0;
      game.state.date = GameDate(game.state.date.day, tick);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            game: game,
            packLocation: PackLocation('kss16', null, false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (tick == 0) {
        // The goal announcement opens over the hub; dismiss it first.
        await tester.tap(find.text("Let's do this!"));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Main Menu'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // UIR-30: the restriction is explained in words, not just greyed out.
      final matcher = restricted ? findsOneWidget : findsNothing;
      expect(find.text('You may leave once the day is over.'), matcher);
      expect(find.text('You may save once the day is over.'), matcher);
      expect(tester.takeException(), isNull);
    });
  }

  group('the dev panel Traits tab', () {
    /// The tab's own list, which is the last one built: the State tab stays
    /// in the tree behind it.
    Finder list() => find.byType(ListView).last;

    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
        await tester.drag(list(), const Offset(0, -260));
        await tester.pumpAndSettle();
      }
    }

    Future<void> scrollToTop(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.drag(list(), const Offset(0, 400));
        await tester.pumpAndSettle();
      }
    }

    Future<Game> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final game = Game.newRun(pack);
      await tester.pumpWidget(
        host(
          DevPanel(
            game: game,
            packLocation: PackLocation('kss16', null, false),
            onStateChanged: () {},
            playEvent: (run) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Six tabs do not fit a phone width, so the bar scrolls -- which is
      // how it behaves on the device too.
      await tester.ensureVisible(find.text('Traits'));
      await tester.tap(find.text('Traits'));
      await tester.pumpAndSettle();
      return game;
    }

    /// Filters the catalog down to one trait and taps its row.
    Future<void> tapTrait(WidgetTester tester, String title) async {
      final field = find.ancestor(
        of: find.text('Filter by id, name or description'),
        matching: find.byType(TextField),
      );
      await scrollTo(tester, field);
      await tester.enterText(field, title.split('  ·  ').first);
      await tester.pumpAndSettle();

      final row = find.text(title);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('renders the live readout, not just a tab', (tester) async {
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Trait effects'), findsOneWidget);
      expect(find.text('What they are doing right now'), findsOneWidget);
      expect(find.text('Held (0)'), findsOneWidget);
      // Every payout a trait can reach is reported.
      for (final row in [
        'Study',
        'Class',
        'Stamina',
        'Sleep restore',
        'Part-time pay',
        'Workout exp',
        'Goal reward',
      ]) {
        expect(find.text(row), findsOneWidget, reason: 'missing $row');
      }
    });

    testWidgets('grants a trait by tapping it, and the readout follows', (
      tester,
    ) async {
      final game = await open(tester);
      // 63 "Indestructible" is Stamina Cost -3, unconditional.
      await tapTrait(tester, 'Indestructible  ·  63');
      expect(game.state.traits, contains(63));

      await scrollToTop(tester);
      expect(find.text('Held (1)'), findsOneWidget);
      expect(
        find.textContaining('study -3'),
        findsOneWidget,
        reason: 'the stamina readout should show the discount',
      );
    });

    testWidgets('says why a trait from another story is refused', (
      tester,
    ) async {
      final game = await open(tester);
      // 202 "Genius of the Generation" is story 20's, and hidden by default.
      final toggle = find.byType(CheckboxListTile);
      await scrollTo(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      await tapTrait(tester, 'Genius of the Generation  ·  202');
      expect(game.state.traits, isNot(contains(202)));
      expect(find.textContaining('belongs to story 20'), findsOneWidget);
    });

    testWidgets('shows a temporary trait clock, and clears all', (
      tester,
    ) async {
      final game = await open(tester);
      await tapTrait(tester, 'Flu  ·  10'); // Flu lasts 4 days
      expect(game.state.traits, contains(10));
      expect(find.text('Granted Flu, for 4 days.'), findsOneWidget);

      await scrollToTop(tester);
      expect(find.text('Flu · 4d'), findsOneWidget);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(game.state.traits, isEmpty);
      expect(find.text('Held (0)'), findsOneWidget);
    });
  });

  testWidgets('My Info names a temporary trait and its days left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final game = Game.newRun(pack);
    // Trait 10 "Flu" is bad and lasts 4 days.
    expect(game.state.grantTrait(10), isTrue);
    await tester.pumpWidget(host(MyInfoPanel(game: game)));
    await tester.pumpAndSettle();

    expect(find.text('Flu (4 d)'), findsOneWidget);
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
    expect(find.text('—'), findsWidgets, reason: 'no traits held yet');
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
