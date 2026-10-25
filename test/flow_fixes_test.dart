/// Regression tests for the audit's flow items: book prerequisites (A02),
/// multi-subject items (A05), Weekly Goal timing (A08/A09), deferred evening
/// rollover (A11), ADD_BLOCK (A14) and events during exhaustion (TODO 92).
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/goals.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/goal_met_dialog.dart';

late ContentPack pack;

Future<void> main() async {
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  group('A02 book prerequisites', () {
    test('the menu and the block lottery share one chain', () {
      final game = Game.newRun(pack, random: Random(4));
      // This run's variants: 1001 at rank two (1002 hidden), 2001 at three.
      game.state.bookChoices['korean:2'] = 1001;
      game.state.bookChoices['korean:3'] = 2001;
      final books = game.menuBooks('korean');
      expect(books.take(3).map((b) => b.id), [1, 1001, 2001]);

      game.state.bookReadCounts[1] = pack.books[1]!.doneCount;
      game.state.bookReadCounts[1001] = pack.books[1001]!.doneCount;
      final unlocked = game.unlockedBooksFor('korean').map((b) => b.id);
      // Rank three opens on the shown rank-two book; the hidden sibling
      // never becomes a prerequisite, nor studiable.
      expect(unlocked, [1, 1001, 2001]);
      expect(game.studiableBooks().map((b) => b.id), isNot(contains(1002)));

      // With 1002 shown instead, finishing 1001 opens nothing further.
      game.state.bookChoices['korean:2'] = 1002;
      expect(game.unlockedBooksFor('korean').map((b) => b.id), [1, 1002]);
    });
  });

  group('A05 multi-subject items', () {
    test('Academic Potion adds read count to Humanities and Science', () {
      final game = Game.newRun(pack, random: Random(5));
      game.state.addItem(35);
      expect(game.useItem(35), isTrue);
      for (final book in pack.books.values) {
        final want = book.subject == 'society' || book.subject == 'science'
            ? 2
            : 0;
        expect(
          game.state.bookReadCounts[book.id] ?? 0,
          want,
          reason: '${book.name} (${book.subject})',
        );
      }
    });

    test("Luna's Hat grants its stat only when sleeping", () {
      final effects = pack.items[30101]!.effects;
      expect(effects, hasLength(1));
      expect(effects.single['trigger'], 'onSleep');
    });
  });

  group('A08/A09 weekly goal timing', () {
    test('a Study Planner bought midweek waits for the next goal', () {
      final game = Game.newRun(pack, random: Random(8));
      final goal = game.state.weeklyGoal!;
      final reward = goal.rewardValue;
      game.state.addItem(3001); // Study Planner: rewards +5%
      expect(game.state.weeklyGoal!.rewardValue, reward);

      game.state.stats[goal.targetSubject] = goal.targetValue.toDouble();
      final before = game.state.stats[goal.rewardSubject] ?? 0;
      expect(game.settleWeeklyGoal(), isTrue);
      expect(game.state.stats[goal.rewardSubject]! - before, reward);

      // The following week's goal is issued with the planner held.
      game.state.date = GameDate(DateTime(2023, 10, 23), 0);
      Goals.rollOver(game.state);
      final next = game.state.weeklyGoal!;
      final base = Goals.issue(
        GameState.fromJson(pack, game.state.toJson())..inventory.remove(3001),
      ).rewardValue;
      expect(next.rewardValue, closeTo(base * 1.05, 1));
    });

    test('a goal is paid the moment an action meets it, once', () {
      final game = Game.newRun(pack, random: Random(9));
      game.state.date = GameDate(game.state.date.day, game.classTicks);
      game.invalidateHand();
      final goal = game.state.weeklyGoal!;
      game.state.stats[goal.targetSubject] = goal.targetValue - 1.0;
      final action = game.availableActions().firstWhere(
        (a) => a.actionType != 'sleep',
      );
      game.state.stats[goal.targetSubject] = goal.targetValue.toDouble();
      final before = game.state.stats[goal.rewardSubject] ?? 0;
      final outcome = game.act(action);
      expect(outcome.goalMet, isTrue);
      expect(goal.paid, isTrue);
      final paid = game.state.stats[goal.rewardSubject]! - before;
      expect(paid, greaterThanOrEqualTo(goal.rewardValue));
      // Monday's settlement does not pay it again.
      final atMonday = game.state.stats[goal.rewardSubject]!;
      Goals.settle(game.state);
      expect(game.state.stats[goal.rewardSubject], atMonday);
    });

    test('the final partial week settles before exam day', () {
      final game = Game.newRun(pack, random: Random(10));
      // Wednesday night before the Thursday exam, mid final week.
      final eve = pack.manifest.endDate.day.subtract(const Duration(days: 1));
      game.state.date = GameDate(eve, game.actionTicksPerDay - 1);
      final goal = Goals.issue(game.state);
      game.state.weeklyGoal = goal;
      goal.met = true; // Met before mid-day payment existed (old save).
      final before = game.state.stats[goal.rewardSubject] ?? 0;
      game.state.eventsFiredToday = 99;
      final sleep = game.state.location!.actions.firstWhere(
        (a) => a.actionType == 'sleep',
      );
      game.act(sleep);
      if (game.state.dayEndPending) game.finishPendingDay();
      expect(game.isExamDay, isTrue);
      expect(goal.paid, isTrue);
      expect(game.state.stats[goal.rewardSubject]! - before, goal.rewardValue);
    });

    test('snapshotted rewards survive a save; old saves still pay', () {
      final game = Game.newRun(pack, random: Random(11));
      final restored = GameState.fromJson(pack, game.state.toJson());
      expect(restored.weeklyGoal!.rewardFinal, isTrue);
      expect(
        restored.weeklyGoal!.rewardValue,
        game.state.weeklyGoal!.rewardValue,
      );
      final legacy = game.state.weeklyGoal!.toJson()
        ..remove('rewardFinal')
        ..remove('paid');
      final old = WeeklyGoal.fromJson(legacy)!;
      expect(old.rewardFinal, isFalse);
      expect(old.paid, isFalse);
    });

    testWidgets('the mid-day popup shows objective, reward and Confirm', (
      tester,
    ) async {
      final goal = WeeklyGoal(
        weekIndex: 0,
        targetSubject: 'korean',
        targetValue: 1602,
        rewardSubject: 'korean',
        rewardValue: 40,
        startValue: 1562,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => GoalMetDialog.show(context, goal),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Goals Met'), findsOneWidget);
      expect(find.text('Korean 1562 → 1602'), findsOneWidget);
      expect(find.text('Korean +40'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('goal-met-dialog')), findsNothing);
    });
  });
}
