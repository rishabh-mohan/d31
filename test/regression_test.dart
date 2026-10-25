import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/event_screen.dart';
import 'package:d30mode/ui/commerce_screen.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/ui/day_transition.dart';
import 'package:d30mode/ui/stationery_draw.dart';
import 'package:d30mode/ui/day_menu.dart';

late ContentPack pack;
late ContentPack dialogue;
late ContentPack quiet;

void main() {
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    final files = <String, String>{};
    for (final name in ContentPack.allFiles) {
      final file = File('packs/kss16/$name');
      if (file.existsSync()) files[name] = file.readAsStringSync();
    }
    final quietFiles = {...files};
    final quietRules =
        jsonDecode(quietFiles['rules.json']!) as Map<String, dynamic>;
    (quietRules['events'] as Map)['maxEventsPerDay'] = 0;
    quietFiles['rules.json'] = jsonEncode(quietRules);
    quiet = ContentPack.fromFiles(quietFiles);
    files['events/events.json'] = jsonEncode({
      'speakers': [
        {'id': 1, 'name': 'Friend'},
      ],
      'events': [
        {'id': 1, 'name': 'Conversation', 'rootNodeId': 1},
      ],
      'nodes': [
        {
          'id': 1,
          'boxId': 1,
          'type': 'text',
          'speakerId': 1,
          'text': 'First line',
          'nextNodeId': 2,
        },
        {
          'id': 2,
          'boxId': 1,
          'type': 'text',
          'speakerId': 0,
          'text': 'Second line',
          'nextNodeId': 3,
        },
        {
          'id': 3,
          'boxId': 1,
          'type': 'option',
          'speakerId': 1,
          'text': 'What next?',
          'options': [
            {'text': 'Choose me', 'nextNodeId': 4},
          ],
        },
        {
          'id': 4,
          'boxId': 2,
          'type': 'text',
          'speakerId': 1,
          'text': 'Selected branch',
          'nextNodeId': 5,
        },
        {'id': 5, 'boxId': 2, 'type': 'last'},
      ],
    });
    dialogue = ContentPack.fromFiles(files);
  });

  test('global exhaustion message is forced, repeatable and outside story eligibility', () {
    final game = Game.newRun(quiet);
    for (var i = 0; i < 2; i++) {
      final event = game.beginExhaustionEvent()!;
      expect(event.event.id, 10000000);
      expect(event.event.name, 'Stamina Depleted');
      expect(event.current!.text, 'You’re out of stamina today…');
      expect(event.current!.speakerName, isNull);
      expect(event.effects.unknownFuncCodes, isEmpty);
      expect(game.state.eventsFiredToday, 0);
    }
    expect(
      game.events.eligible(game.state).any((e) => e.id == 10000000),
      isFalse,
    );
  });

  test(
    'deferred exhaustion consumes lost ticks without actions and resets once',
    () {
      final game = Game.newRun(quiet);
      final work = quiet.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'partTimeJob',
      );
      game.state.date = GameDate(game.state.date.day, 3);
      game.state.hp = 1;
      final day = game.state.date.day;
      final outcome = game.act(work, deferExhaustion: true);
      expect(outcome.exhausted, isTrue);
      expect(outcome.dayEnded, isFalse);
      expect(game.state.date.day, day);
      expect(game.state.date.tick, 4);
      expect(game.state.hp, 0);
      expect(game.state.exhaustionPending, isTrue);
      expect(outcome.event!.event.id, 10000000);
      final money = game.state.money;
      final stats = Map<String, num>.from(game.state.stats);
      final exp = game.state.partTimeExp;
      final tickets = game.state.rerolls;
      expect(game.hand(), isEmpty);
      expect(game.refreshHand(), isFalse);
      expect(game.move(2000), isFalse);
      game.act(work);
      expect(game.state.money, money);
      expect(game.state.stats, stats);
      expect(game.state.partTimeExp, exp);
      expect(game.state.rerolls, tickets);
      final saved = GameState.fromJson(quiet, game.state.toJson());
      expect(saved.exhaustionPending, isTrue);
      while (game.advanceExhaustedTick()) {
        expect(game.state.date.day, day);
        expect(game.state.hp, 0);
        expect(game.state.money, money);
      }
      expect(game.state.date.tick, game.actionTicksPerDay);
      final end = game.finishExhaustedDay();
      expect(end.dayEnded, isTrue);
      expect(game.state.date.day, day.add(const Duration(days: 1)));
      expect(game.state.date.tick, 0);
      expect(game.state.hp, game.state.hpMax);
      expect(game.state.stats, stats);
      expect(game.state.exhaustionPending, isFalse);
      expect(game.finishExhaustedDay().dayEnded, isFalse);
      expect(game.state.date.day, day.add(const Duration(days: 1)));
    },
  );

  testWidgets(
    'Wednesday exhaustion fills ticks, then summary, Thursday draw and day menu',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(quiet, random: Random(211));
      game.state.date = GameDate(DateTime(2023, 10, 18), 3);
      game.state.hp = 1;
      final day = game.state.date.day;
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            game: game,
            packLocation: PackLocation('kss16', null, false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 4'));
      await tester.pumpAndSettle();
      expect(find.text('Stamina Depleted'), findsOneWidget);
      expect(find.text('You’re out of stamina today…'), findsOneWidget);
      expect(find.byKey(const ValueKey('exhausted-blocks')), findsOneWidget);
      expect(find.text('Period 4'), findsNothing);
      expect(game.state.date.day, day);
      expect(game.state.date.tick, 4);
      expect(game.state.hp, 0);
      await tester.tap(find.byTooltip('Next'));
      await tester.pump();
      for (
        var tick = game.state.date.tick + 1;
        tick <= game.actionTicksPerDay;
        tick++
      ) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(game.state.date.tick, tick);
        expect(
          find.byKey(ValueKey('day-tick-${tick - 1}-filled')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('exhausted-blocks')), findsOneWidget);
        expect(game.state.date.day, day);
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(DayTransition), findsOneWidget);
      expect(game.state.date.day, day.add(const Duration(days: 1)));
      expect(game.state.hp, game.state.hpMax);
      expect(game.state.pendingStationery, isEmpty);
      await tester.tap(find.byIcon(Icons.play_arrow));
      // The draw opens rolling, so it never settles until it is stopped.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StationeryDraw), findsOneWidget);
      expect(game.state.stationeryInventory, isEmpty);
      await tester.tap(find.byKey(const ValueKey('stop-all-stationery')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(DayMenu), findsOneWidget);
      expect(
        game.state.stationeryInventory.values.fold(0, (int n, v) => n + v),
        5,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('exhaustion resets stamina, combo and clock for several new days', () {
    final game = Game.newRun(pack, random: Random(211));
    final work = pack.locations[1000]!.actions.firstWhere(
      (a) => a.actionType == 'partTimeJob',
    );
    for (var day = 0; day < 4; day++) {
      final date = game.state.date.day;
      game.state.hp = 1;
      game.state.lastStudySubject = 'korean';
      game.state.studyCombo = 5;
      expect(game.act(work).dayEnded, isTrue);
      expect(game.state.date.day, date.add(const Duration(days: 1)));
      expect(game.state.date.tick, 0);
      expect(game.state.hp, game.state.hpMax);
      expect(game.state.studyCombo, 0);
      expect(game.state.lastStudySubject, isNull);
      expect(game.act(work).dayEnded, isFalse);
      expect(game.state.date.tick, 1);
    }
  });

  test(
    'each exercise level discounts every paid action and max bars are full',
    () {
      final game = Game.newRun(pack);
      final actions = pack.locations[1000]!.actions.where(
        (a) => a.actionType != 'sleep',
      );
      final base = {for (final a in actions) a: game.preview(a).hpCost};
      game.state.exerciseExp = pack.exerciseLevels.tiers[3].exp;
      for (final a in actions) {
        expect(game.preview(a).hpCost, max(0, base[a]! - 3));
      }
      game.state.exerciseExp = pack.exerciseLevels.tiers.last.exp;
      game.state.partTimeExp = pack.partTimeLevels.tiers.last.exp;
      for (final type in ['exercise', 'partTimeJob']) {
        final a = actions.firstWhere((a) => a.actionType == type);
        expect(game.preview(a).progress, 1);
      }
    },
  );

  test('beginner work and home sleep use the reduced economy', () {
    final game = Game.newRun(pack);
    final work = pack.locations[1000]!.actions.firstWhere(
      (a) => a.actionType == 'partTimeJob',
    );
    expect(game.preview(work).money, inExclusiveRange(0, 1000));
    game.state.locationId = 2000;
    final sleep = pack.locations[2000]!.actions.firstWhere(
      (a) => a.actionType == 'sleep',
    );
    expect(game.preview(sleep).gain, 15);
  });

  test('store stat descriptions agree with their reference-scaled effects', () {
    expect(pack.items[8]!.effectText, 'Stats +90 for a random subject');
    expect(pack.items[8]!.effects.first['value'], 90);
    expect(
      pack.items[3005]!.effectText,
      'Study Efficiency for All Subjects +3',
    );
    // Reads +3 as the reference store does; grants the intended +1.
    expect(pack.items[3005]!.effects.first['value'], 1);
    expect(pack.items[21]!.effects.first['value'], 450);
  });

  test('store purchases charge once, track stock, restock Saturday and survive saves', () {
    final game = Game.newRun(pack);
    expect(game.purchase(8), isNotNull);
    expect(game.state.inventory, isEmpty);
    game.state.money = 10000;
    expect(game.purchase(8), isNull);
    expect(game.state.money, 8500);
    expect(game.purchase(8), isNull);
    expect(game.state.itemCount(8), 2);
    expect(game.purchase(8), isNotNull);
    expect(game.state.money, 7000);
    final restored = GameState.fromJson(pack, game.state.toJson());
    final reloaded = Game(pack: pack, state: restored);
    expect(reloaded.shopStock(8), 0);
    restored.date = GameDate(DateTime(2023, 10, 21), 0);
    expect(reloaded.shopStock(8), 2);
  });

  test(
    'book variants are chosen once per subject and rank and survive saves',
    () {
      final game = Game.newRun(pack, random: Random(2));
      for (final s in pack.manifest.subjects) {
        final books = game.menuBooks(s);
        expect(books.map((b) => b.bookRank).toSet().length, books.length);
        expect(game.menuBooks(s).map((b) => b.id), books.map((b) => b.id));
      }
      final restored = Game(
        pack: pack,
        state: GameState.fromJson(pack, game.state.toJson()),
      );
      expect(
        restored.menuBooks('korean').map((b) => b.id),
        game.menuBooks('korean').map((b) => b.id),
      );
    },
  );

  test(
    'stationery can be drawn and equipped and contributes its subject bonus',
    () {
      final game = Game.newRun(pack, random: Random(3));
      expect(game.beginWeeklyStationeryDraw(), isFalse);
      game.state.date = GameDate(DateTime(2023, 10, 19), 0);
      expect(game.beginWeeklyStationeryDraw(), isTrue);
      expect(game.state.stationeryInventory, isEmpty);
      game.claimStationeryDraw();
      expect(game.beginWeeklyStationeryDraw(), isFalse);
      expect(
        game.state.stationeryInventory.values.fold<int>(0, (a, b) => a + b),
        5,
      );
      final id = game.state.stationeryInventory.keys.first;
      expect(game.equipStationery(id), isTrue);
      final bonus = pack.stationery[id]!['studyStats'] as List;
      final subject =
          (bonus.first as Map)['subjectType'] as String? ?? 'korean';
      expect(game.state.stationeryBonus(subject), greaterThan(0));
      final restored = GameState.fromJson(pack, game.state.toJson());
      expect(restored.equippedStationery, game.state.equippedStationery);
    },
  );

  testWidgets(
    'fast-forward renders at 100ms, stops at choices and log includes speakers',
    (tester) async {
      final game = Game.newRun(dialogue);
      final run = game.events.begin(dialogue.events[1]!, game.state);
      await tester.pumpWidget(MaterialApp(home: EventScreen(run: run)));
      expect(find.text('Friend'), findsOneWidget);
      await tester.tap(find.byTooltip('Fast-forward'));
      await tester.pump(const Duration(milliseconds: 99));
      expect(run.current!.text, 'First line');
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Second line'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Choose me'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(run.current!.text, 'What next?');
      await tester.tap(find.byTooltip('Log').last);
      await tester.pumpAndSettle();
      expect(find.text('First line'), findsOneWidget);
      expect(find.text('Friend'), findsWidgets);
      expect(find.text('Me'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose me'));
      await tester.pump();
      expect(find.text('Selected branch'), findsOneWidget);
    },
  );

  testWidgets('fast-forward stops on the last line instead of closing', (
    tester,
  ) async {
    final game = Game.newRun(dialogue);
    final run = game.events.begin(dialogue.events[1]!, game.state);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => EventScreen.show(context, run),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fast-forward'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Choose me'));
    await tester.pump();
    await tester.tap(find.byTooltip('Fast-forward'));
    await tester.pump(const Duration(seconds: 2));
    expect(run.current!.isEnd, isTrue);
    expect(find.byType(EventScreen), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'store and stationery screens render and purchases update wallet',
    (tester) async {
      final game = Game.newRun(pack);
      game.state.money = 2000;
      await tester.pumpWidget(MaterialApp(home: CommerceScreen(game: game)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('buy-8')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('buy-8')));
      await tester.pumpAndSettle();
      expect(game.state.money, 500);
      expect(game.state.itemCount(8), 1);
      await tester.ensureVisible(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-tab-stationery')));
      await tester.pumpAndSettle();
      expect(find.text('No stationery obtained yet.'), findsOneWidget);
      expect(
        find.text('New stationery arrives every Thursday.'),
        findsOneWidget,
      );
      expect(game.state.money, 500);
      await tester.tap(find.widgetWithText(FilledButton, 'Combine'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('combine-slot-3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weekend start immediately presents location selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = Game.newRun(pack);
    game.state.date = GameDate(DateTime(2023, 10, 21), 0);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          game: game,
          packLocation: PackLocation('kss16', null, false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A fresh goal announces itself over the hub; acknowledge it first.
    await tester.tap(find.text("Let's do this!"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(find.text('Where do I go today?'), findsOneWidget);
    expect(game.state.date.tick, 0);
    expect(tester.takeException(), isNull);
  });
}
