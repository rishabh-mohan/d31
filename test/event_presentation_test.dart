import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/engine/event_text.dart';
import 'package:d30mode/ui/event_text.dart';
import 'package:d30mode/ui/event_screen.dart';

void main() {
  late ContentPack pack;
  late ContentPack dialogue;
  setUpAll(() {
    final files = <String, String>{};
    for (final name in ContentPack.allFiles) {
      final file = File('packs/kss16/$name');
      if (file.existsSync()) files[name] = file.readAsStringSync();
    }
    final rules = jsonDecode(files['rules.json']!) as Map<String, dynamic>;
    (rules['events'] as Map)['maxEventsPerDay'] = 0;
    files['rules.json'] = jsonEncode(rules);
    pack = ContentPack.fromFiles(files);
    files['events/events.json'] = jsonEncode({
      'events': [
        {'id': 1, 'name': 'Formatting', 'rootNodeId': 1},
      ],
      'nodes': [
        {
          'id': 1,
          'boxId': 1,
          'type': 'text',
          'speakerId': 0,
          'text': '<bi>Hello, {이름}!</bi>',
          'nextNodeId': 2,
        },
        {
          'id': 2,
          'boxId': 1,
          'type': 'option',
          'text': 'Choose, {성이름}.',
          'options': [
            {'text': '<b>Train</b> with {성}', 'nextNodeId': 3},
          ],
        },
        {
          'id': 3,
          'boxId': 2,
          'type': 'text',
          'text': 'Wrong branch',
          'elseText': '<i>{성}</i> alternative',
          'nextNodeId': 4,
          'conditionSet': {
            'conditions': [
              {
                'target': 'TEST_FLAG',
                'type': 'defaults',
                'targetType': 'event',
                'compareType': 'equal',
                'value': 1,
              },
            ],
          },
        },
        {'id': 4, 'boxId': 2, 'type': 'last', 'text': '<b>Goodbye, {성이름}.</b>'},
      ],
    });
    dialogue = ContentPack.fromFiles(files);
  });

  test(
    'name macros cover text, choices, alternate text and final messages',
    () {
      final game = Game.newRun(dialogue);
      game.state.firstName = 'Greg';
      game.state.lastName = 'Fiasco';
      final run = game.events.begin(dialogue.events[1]!, game.state);
      expect(run.current!.text, '<bi>Hello, Greg!</bi>');
      run.advance();
      expect(run.current!.text, 'Choose, Greg Fiasco.');
      expect(run.current!.choices.single.text, '<b>Train</b> with Fiasco');
      run.choose(run.current!.choices.single);
      expect(run.current!.text, '<i>Fiasco</i> alternative');
      run.advance();
      expect(run.current!.isEnd, isTrue);
      expect(run.current!.text, '<b>Goodbye, Greg Fiasco.</b>');
      final restored = GameState.fromJson(pack, game.state.toJson());
      expect(restored.fullName, 'Greg Fiasco');
      final legacy = game.state.toJson()
        ..remove('firstName')
        ..remove('lastName');
      expect(
        GameState.fromJson(pack, legacy).firstName,
        pack.manifest.firstName,
      );
    },
  );

  test('formatting preserves nested styles, entities and literal player names', () {
    final span = EventText.span(
      'Plain <bi>both <b>nested</b> still both</bi> plain<br>Next &amp; &#33;',
    );
    expect(span.toPlainText(), 'Plain both nested still both plain\nNext & !');
    final spans = span.children!.cast<TextSpan>().toList();
    final both = spans.firstWhere((s) => s.text == 'both ');
    expect(both.style!.fontWeight, FontWeight.bold);
    expect(both.style!.fontStyle, FontStyle.italic);
    final after = spans.firstWhere((s) => s.text == ' plain');
    expect(after.style!.fontWeight, isNull);
    expect(after.style!.fontStyle, isNull);
    final game = Game.newRun(pack);
    game.state.firstName = '<b>Greg</b> & Co';
    final literal = EventText.span(expandEventText('{이름}', game.state));
    expect(literal.toPlainText(), '<b>Greg</b> & Co');
    expect((literal.children!.single as TextSpan).style!.fontWeight, isNull);
  });

  test(
    'workout level-up is global, repeats on new levels and clears its flag',
    () {
      final game = Game.newRun(pack, random: Random(13));
      final workout = pack.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'exercise',
      );
      for (final level in [1, 2]) {
        game.state.exerciseExp = pack.exerciseLevels.tiers[level].exp - 1;
        game.state.hp = game.state.hpMax;
        final outcome = game.act(workout);
        final run = outcome.beforeEvents.single;
        expect(run.event.id, 10000002);
        expect(run.event.name, 'Exercise Level Up');
        expect(run.current!.text, 'A sudden burst of energy rushes in me…!');
        expect(game.state.eventsFiredToday, 0);
        run.advance();
        expect(run.current!.text, 'GYAAAAAAAH...!');
        run.advance();
        expect(run.current!.text, 'Exercise Level became Level $level!!!');
        expect(game.state.switches['EXERCISE_LEVEL_UP'], 0);
        expect(game.effects.unknownFuncCodes, isEmpty);
      }
      game.state.hp = game.state.hpMax;
      expect(game.act(workout).beforeEvents, isEmpty);
      expect(
        game.events.eligible(game.state).any((e) => e.id == 10000002),
        isFalse,
      );
    },
  );

  test(
    'workout level-up is preserved when the same action exhausts stamina',
    () {
      final game = Game.newRun(pack);
      final workout = pack.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'exercise',
      );
      game.state.exerciseExp = pack.exerciseLevels.tiers[1].exp - 1;
      game.state.hp = 1;
      final outcome = game.act(workout, deferExhaustion: true);
      expect(outcome.beforeEvents.single.event.id, 10000002);
      expect(outcome.event!.event.id, 10000000);
      expect(outcome.exhausted, isTrue);
      expect(game.state.date.tick, 1);
    },
  );

  testWidgets(
    'dialogue, choices and log render formatted text without raw tags',
    (tester) async {
      final game = Game.newRun(dialogue);
      game.state.firstName = 'Greg';
      game.state.lastName = 'Fiasco';
      final run = game.events.begin(dialogue.events[1]!, game.state);
      await tester.pumpWidget(MaterialApp(home: EventScreen(run: run)));
      expect(find.text('Hello, Greg!'), findsOneWidget);
      expect(find.textContaining('<bi>'), findsNothing);
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Train with Fiasco'), findsOneWidget);
      await tester.tap(find.byTooltip('Log').last);
      await tester.pumpAndSettle();
      expect(find.text('Hello, Greg!'), findsWidgets);
      expect(find.textContaining('{이름}'), findsNothing);
      expect(find.textContaining('<bi>'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
