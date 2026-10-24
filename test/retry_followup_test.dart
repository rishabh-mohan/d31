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
import 'package:d30mode/ui/event_screen.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/ui/theme.dart';

void main() {
  late ContentPack retry;
  late ContentPack standard;
  late ContentPack fixture;
  setUpAll(() async {
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    standard = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    final files = <String, String>{
      for (final name in ContentPack.allFiles)
        if (File('packs/kss20/$name').existsSync())
          name: File('packs/kss20/$name').readAsStringSync(),
    };
    final rules = jsonDecode(files['rules.json']!) as Map;
    rules['events']['openingEventIds'] = [];
    rules['events']['chainScheduledEvents'] = false;
    rules['events']['executeFakeEvents'] = false;
    files['rules.json'] = jsonEncode(rules);
    files['events/events.json'] = jsonEncode({
      'speakers': jsonDecode(files['events/events.json']!)['speakers'],
      'events': [
        {'id': 1, 'name': 'Workout reward test', 'rootNodeId': 1},
        {'id': 2, 'name': 'Unknown speaker test', 'rootNodeId': 3},
      ],
      'nodes': [
        {
          'id': 1,
          'type': 'text',
          'text': 'Workout reward',
          'nextNodeId': 2,
          'changer': retry.nodes[107012]!.changer,
        },
        {'id': 2, 'type': 'last', 'text': 'Workout reward complete'},
        {
          'id': 3,
          'type': 'text',
          'text': 'A stranger speaks',
          'speakerId': 9,
          'standingId': 9,
          'isHideSpeakerName': true,
          'nextNodeId': 4,
        },
        {
          'id': 4,
          'type': 'text',
          'text': 'Hello',
          'speakerId': 9,
          'nextNodeId': 5,
        },
        {
          'id': 5,
          'type': 'last',
          'text': 'The room quietens',
          'isHideSpeakerName': true,
        },
      ],
    });
    fixture = ContentPack.fromFiles(files);
  });

  void finish(EventRun run) {
    for (var i = 0; i < 500 && !run.current!.isEnd; i++) {
      if (run.current!.choices.isEmpty) {
        run.advance();
      } else {
        run.choose(run.current!.choices.first);
      }
    }
    expect(run.current!.isEnd, isTrue);
  }

  Game ready(ContentPack pack) {
    final game = Game.newRun(pack, random: Random(1));
    game.state.openingComplete = true;
    game.state.date = GameDate.parse('DATE_2024101607');
    game.state.locationId = 1000;
    game.state.setSwitch('DOK_BANG_ON', 0);
    return game;
  }

  test(
    'stamina caps at 100 across levels, direct edits, recovery and old saves',
    () {
      for (final pack in [standard, retry]) {
        final game = Game.newRun(pack);
        for (final tier in pack.exerciseLevels.tiers) {
          game.state.exerciseExp = tier.exp;
          expect(game.state.hpMax, 100);
          game.state.hp = 104;
          expect(game.state.hp, 100);
          game.state.addHp(100);
          expect(game.state.hp, 100);
          game.state.addHp(-1);
          expect(game.state.hp, 99);
        }
        final legacy = game.state.toJson()..['hp'] = 104;
        final loaded = GameState.fromJson(pack, legacy);
        expect(loaded.hp, 100);
        loaded.addHp(-10);
        expect(loaded.hp, 90);
      }
    },
  );

  test('Jian Lee has both complete portrait variants', () {
    for (final id in ['9', '27']) {
      final actor = (retry.presentation['npcs'] as Map)[id] as Map;
      for (final path in [
        actor['skeleton'],
        ...(actor['expressions'] as Map).values,
        ...(actor['clothes'] as Map).values,
      ]) {
        expect(path, isNotNull);
        expect(File('assets/images/$path').existsSync(), isTrue);
      }
    }
  });

  testWidgets(
    'hidden person has a dark ??? tag until revealed; narration stays unnamed',
    (tester) async {
      final game = ready(fixture);
      final run = game.events.begin(fixture.events[2]!, game.state);
      expect(run.current!.speakerName, '???');
      await tester.pumpWidget(MaterialApp(home: EventScreen(run: run)));
      await tester.pumpAndSettle();
      final chip = tester.widget<D30Chip>(find.byType(D30Chip));
      expect(chip.text, '???');
      expect(chip.color, const Color(0xFF3C3C3C));
      run.advance();
      expect(run.current!.speakerName, fixture.speakers[9]);
      expect(run.current!.speakerName, isNot('???'));
      run.advance();
      expect(run.current!.speakerName, isNull);
    },
  );

  test(
    'event workout XP queues one global scene without spending time or stamina',
    () {
      final game = ready(fixture);
      game.state.exerciseExp = fixture.exerciseLevels.tiers[1].exp - 1;
      final levelBefore = game.state.exerciseLevel.level;
      game.state.eventsFiredToday = 99;
      final clock = game.state.date;
      final hp = game.state.hp;
      final reward = game.events.begin(fixture.events[1]!, game.state);
      finish(reward);
      expect(game.state.exerciseLevel.level, greaterThan(levelBefore));
      final pending = game.beginPendingLevelUpEvent()!;
      expect(pending.event.id, 10000002);
      expect(game.state.eventsFiredToday, 100);
      finish(pending);
      expect(game.beginPendingLevelUpEvent(), isNull);
      expect(game.state.date, clock);
      expect(game.state.hp, hp);
      expect(game.state.switchValue('EXERCISE_LEVEL_UP'), 0);
    },
  );

  testWidgets(
    'workout level-up scene follows an XP reward dialogue in the game',
    (tester) async {
      final game = ready(fixture);
      game.state.exerciseExp = fixture.exerciseLevels.tiers[1].exp - 1;
      // A lesson is deterministic and keeps this check about event-awarded XP.
      game.state.date = GameDate.parse('DATE_2024101603');
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            game: game,
            packLocation: PackLocation('kss20', null, false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 4'));
      await tester.pumpAndSettle();
      expect(find.text('Workout reward test'), findsOneWidget);
      await tester.tap(find.text('Workout reward'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout reward complete'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise Level Up'), findsOneWidget);
      expect(game.state.date.tick, 4);
      expect(tester.takeException(), isNull);
    },
  );

  test('first tick-12 return is Hurry, later roll calls offer choices and reset daily', () {
    final game = ready(retry);
    for (final id in retry.events.keys) {
      game.state.eventStates[id] = 2;
    }
    for (final id in [10, 11, 12]) {
      game.state.eventStates[id] = 0;
    }
    game.state.date = GameDate.parse('DATE_2024101511');
    final sleep = retry.locations[1000]!.actions.firstWhere(
      (a) => a.actionType == 'sleep',
    );
    final first = game.act(sleep).event!;
    expect(first.event.id, 10);
    expect(game.state.date.tick, 12);
    finish(first);
    expect(game.state.locationId, 2000);
    expect(game.nextScheduledEvent(), isNull);
    game.state.date = GameDate.parse('DATE_2024101600');
    game.nextScheduledEvent();
    game.state.date = GameDate.parse('DATE_2024101611');
    game.state.locationId = 1000;
    game.state.hp = 100;
    final roll = game.act(sleep).event!;
    expect(roll.event.id, 11);
    while (roll.current!.choices.isEmpty && !roll.current!.isEnd) {
      roll.advance();
    }
    expect(roll.current!.choices.map((c) => c.text), ['Return.', 'Stay.']);
    roll.choose(roll.current!.choices.firstWhere((c) => c.text == 'Stay.'));
    finish(roll);
    expect(game.state.locationId, 1000);
    expect(game.state.switchValue('BAD_COUNT'), 1);
    game.state.date = GameDate.parse('DATE_2024101700');
    game.nextScheduledEvent();
    expect(game.state.eventStates[11], 0);
    game.state.date = GameDate.parse('DATE_2024101712');
    final next = game.nextScheduledEvent()!;
    expect(next.event.id, 11);
    while (next.current!.choices.isEmpty && !next.current!.isEnd) {
      next.advance();
    }
    expect(
      next.current!.choices.single.text,
      "Return to prepare for tomorrow's test.",
    );
    next.choose(next.current!.choices.single);
    finish(next);
    expect(game.state.locationId, 2000);
  });

  test(
    'second missed roll call confines until the authored next-day evening',
    () {
      final game = ready(retry);
      for (final id in retry.events.keys) { game.state.eventStates[id] = 2; }
      for (final id in [4, 11, 12]) { game.state.eventStates[id] = 0; }
      game.state.date = GameDate.parse('DATE_2024101612');
      game.state.eventStates[10] = 2;
      game.state.setSwitch('BAD_COUNT', 1);
      expect(
        game.conditions.evaluate(retry.events[11]!.conditionSet, game.state),
        isTrue,
      );
      final roll = game.events.begin(retry.events[11]!, game.state);
      while (roll.current!.choices.isEmpty && !roll.current!.isEnd) {
        roll.advance();
      }
      roll.choose(roll.current!.choices.firstWhere((c) => c.text == 'Stay.'));
      finish(roll);
      expect(game.state.locationId, 20007);
      expect(game.state.switchValue('DOK_BANG_ON'), 1);
      expect(game.state.taskDeadlines[5], GameDate.parse('DATE_2024101714'));
      game.state.date = GameDate.parse('DATE_2024101714');
      final release = game.nextScheduledEvent()!;
      expect(release.event.id, 4);
      finish(release);
      expect(game.state.switchValue('DOK_BANG_ON'), 0);
      expect(game.state.taskDeadlines.containsKey(5), isFalse);
    },
  );
}
