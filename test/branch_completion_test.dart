import 'support/kss_ids.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/engine/record_store.dart';
import 'package:d30mode/ui/score_card.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/ui/stationery_draw.dart';
import 'package:d30mode/ui/account_widgets.dart';

void finish(EventRun? run) {
  if (run == null) return;
  for (var i = 0; i < 100 && !(run.current?.isEnd ?? true); i++) {
    if (run.current!.choices.isNotEmpty) {
      run.choose(run.current!.choices.first);
    } else {
      run.advance();
    }
  }
  expect(run.current?.isEnd, isTrue);
}

ContentPack scripted(ContentPack base, List<int> ticks) {
  final files = {...base.sourceFiles};
  files.removeWhere(
    (key, _) =>
        key.startsWith('events/') &&
        key != 'events/events.json' &&
        key != 'events/system.json',
  );
  final rules = jsonDecode(files['rules.json']!) as Map<String, dynamic>;
  (rules['events'] as Map<String, dynamic>).addAll(<String, dynamic>{
    'openingEventIds': [],
    'maxEventsPerDay': 100,
    'randomEventChancePerTick': 0,
    'checkAtDayStart': false,
    'chainScheduledEvents': true,
    'deferEveningRollover': base.manifest.storyId == 20,
  });
  files['rules.json'] = jsonEncode(rules);
  files['events/events.json'] = jsonEncode({
    'events': [
      for (final t in ticks)
        {
          'id': 900000 + t,
          'name': 'Tick $t',
          'rootNodeId': 1000 + t * 2,
          'conditionSet': {
            'conditions': [
              {'target': 'TICK', 'targetType': 'eventSwitch', 'value': t},
              {
                'target': 'EVENT_${900000 + t}',
                'targetType': 'event',
                'value': 0,
              },
            ],
          },
        },
    ],
    'nodes': [
      for (final t in ticks) ...[
        {
          'id': 1000 + t * 2,
          'type': 'text',
          'text': 'Tick $t',
          'nextNodeId': 1001 + t * 2,
        },
        {'id': 1001 + t * 2, 'type': 'last', 'text': 'Done $t'},
      ],
    ],
  });
  return ContentPack.fromFiles(files);
}

void main() {
  late ContentPack standard, retry;
  setUpAll(() async {
    standard = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });
  test(
    'A11 evening finishes before date, stamina and trait lifetime roll over',
    () {
      final game = Game.newRun(scripted(standard, [14, 0]), random: Random(9));
      final state = game.state..openingComplete = true;
      state.date = GameDate(DateTime(2023, 10, 18), 13);
      state.hp = 20;
      state.grantTrait(34);
      final age = state.traitDaysLeft[34];
      // Keep the synthetic morning event for tomorrow.
      state.eventStates[900000] = 2;
      final action = LocationAction.fromJson({'locationActionType': 'sleep'});
      final end = game.act(action);
      expect(end.event?.event.id, 900014);
      expect(state.dayEndPending, isTrue);
      expect(state.date.day, DateTime(2023, 10, 18));
      expect(state.traitDaysLeft[34], age);
      expect(state.hp, lessThan(state.hpMax));
      finish(end.event);
      state.eventStates[900000] = 0;
      final morning = game.finishPendingDay();
      expect(state.date.day, DateTime(2023, 10, 19));
      expect(state.date.tick, 0);
      expect(state.hp, state.hpMax);
      expect(state.traitDaysLeft[34], age! - 1);
      expect(morning.event?.event.id, 900000);
      finish(morning.event);
      expect(game.finishPendingDay().dayEnded, isFalse);
    },
  );
  for (final story in [16, 20]) {
    test(
      '92 story $story checks every lost tick, including first and evening',
      () {
        final p = scripted(story == 16 ? standard : retry, [4, 8, 13, 14]);
        final game = Game.newRun(p, random: Random(9));
        final state = game.state..openingComplete = true;
        state.date = GameDate(DateTime(2023, 10, 18), 3);
        state.hp = 1;
        final action = LocationAction.fromJson({
          'locationActionType': 'study',
          'hpWeight': 1,
        });
        final out = game.act(action, deferExhaustion: true);
        expect(out.exhausted, isTrue);
        finish(out.event);
        final money = state.money, xp = state.studyExp;
        final played = <int>[];
        while (true) {
          final run = game.beginExhaustedTickEvent();
          if (run != null) {
            played.add(run.event.id - 900000);
            finish(run);
          }
          expect(game.beginExhaustedTickEvent(), isNull);
          final restored = Game(
            pack: p,
            state: GameState.fromJson(p, state.toJson()),
          );
          expect(restored.beginExhaustedTickEvent(), isNull);
          expect(state.hp, 0);
          expect(state.money, money);
          expect(state.studyExp, xp);
          if (!game.advanceExhaustedTick()) break;
        }
        final end = game.finishExhaustedDay();
        expect(end.event?.event.id, 900014);
        played.add(end.event!.event.id - 900000);
        finish(end.event);
        expect(played, [4, 8, 13, 14]);
        game.finishPendingDay();
        expect(state.date.day, DateTime(2023, 10, 19));
        expect(state.hp, state.hpMax);
        expect(state.exhaustionPending, isFalse);
      },
    );
  }
  test('T11 study adds the seeded Multitasker STAT_1 bonus', () {
    final withTrait = Game.newRun(standard, random: Random(3));
    final plain = Game.newRun(standard, random: Random(3));
    withTrait.state.grantTrait(49);
    for (final g in [withTrait, plain]) {
      g.state.date = GameDate(DateTime(2023, 10, 18), 7);
    }
    final subject = withTrait.traits
        .studyBonuses(withTrait.state)
        .first
        .subject;
    final action = LocationAction.fromJson({
      'locationActionType': 'study',
      'hpWeight': 1,
    });
    expect(withTrait.preview(action).bonusSubject, subject);
    expect(withTrait.preview(action).bonusGain, 3);
    withTrait.act(action);
    plain.act(action);
    for (final key in standard.manifest.subjects) {
      expect(
        withTrait.state.stats[key]! - plain.state.stats[key]!,
        key == subject ? 3 : 0,
      );
    }
  });
  test('T16 Street Performer pays 600 on singing, only in scope', () {
    final game = Game.newRun(retry);
    final s = game.state..locationId = 20002;
    final changer = <String, dynamic>{'funcCode': 'DO_KARAOKE'};
    final before = s.money;
    game.effects.applyChanger(changer, s);
    final baseline = s.money - before;
    expect(s.grantTrait(KssIds.streetPerformer), isTrue);
    var old = s.money;
    game.effects.applyChanger(changer, s);
    expect(s.money - old, baseline + 600);
    s.locationId = 1000;
    old = s.money;
    game.effects.applyChanger(changer, s);
    expect(s.money - old, baseline);
  });
  testWidgets(
    'A15 saved score card displays original scores after live stats change',
    (tester) async {
      final game = Game.newRun(standard);
      final result = game.takeCsat();
      final record = RunRecord.of(42, game.state, ending: 'Test');
      final restored = RunRecord.fromJson(
        42,
        jsonDecode(jsonEncode(record.toJson())),
      );
      game.state.addStat('all', 99999);
      expect(restored.scoreCard!.subjectScores, result.subjectScores);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamScoreCard(
              name: restored.name,
              result: restored.scoreCard!,
            ),
          ),
        ),
      );
      expect(find.text('Graduation Exam Score Card'), findsOneWidget);
      expect(find.text('Top %'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final noCsat = record.toJson()..remove('scoreCard');
      expect(RunRecord.fromJson(42, noCsat).scoreCard, isNull);
    },
  );
  testWidgets('92 exhausted tick progression pauses for player dialogue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = scripted(standard, [4, 8]);
    final game = Game.newRun(p);
    game.state.openingComplete = true;
    game.state.date = GameDate(DateTime(2023, 10, 18), 4);
    game.state.exhaustionPending = true;
    game.state.hp = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          game: game,
          packLocation: PackLocation('kss16', null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Tick 4'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(game.state.date.tick, 4);
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    // The terminal beat stays open for reading until the player closes it.
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    for (var i = 0; i < 10 && game.state.date.tick < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();
    expect(game.state.date.tick, 8);
    expect(find.text('Tick 8'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'F04 stationery results use blue B-tier confetti, without blocking controls',
    (tester) async {
      final game = Game.newRun(standard);
      final b = standard.stationery.entries
          .firstWhere((e) => e.value['rank'] == 'B')
          .key;
      game.state.pendingStationery.addAll([b, b, b, b, b]);
      await tester.pumpWidget(MaterialApp(home: StationeryDraw(game: game)));
      await tester.tap(find.byKey(const ValueKey('stop-all-stationery')));
      await tester.pump();
      final confetti = tester.widget<ConfettiLayer>(find.byType(ConfettiLayer));
      expect(confetti.colors.toSet(), {
        const Color(0xFFCADAF4),
        const Color(0xFFE3E9FA),
      });
      await tester.tap(find.byKey(const ValueKey('draw-card-0')));
      await tester.pump();
      expect(game.state.stationeryLocks, contains(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
