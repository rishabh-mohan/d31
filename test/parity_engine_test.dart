import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_text.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/goals.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/traits.dart';

/// Regressions for the original-game parity audit's engine defects
/// (TODO 81 / 86). Each test names the audit item it pins.
void main() {
  late ContentPack retry;
  late ContentPack original;
  setUpAll(() async {
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    original = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  group('A01 FUNC_IS_IN_CHARACTER_LIST', () {
    test('matches the playing character against the listed ids', () {
      final game = Game.newRun(retry, random: Random(1));
      final inList = game.conditions.funcs['FUNC_IS_IN_CHARACTER_LIST']!;
      game.state.characterId = 66;
      expect(inList(game.state, const [66]), 1);
      expect(inList(game.state, const [58]), 0);
      expect(inList(game.state, const [58, 66]), 1);
      game.state.characterId = null;
      expect(inList(game.state, const [66]), 0);
    });

    test("character 58's branch in #189 now follows the character", () {
      final game = Game.newRun(retry, random: Random(2));
      final node = retry.nodes[189002]!;
      game.state.characterId = 58;
      expect(game.conditions.evaluate(node.conditionSet, game.state), isTrue);
      game.state.characterId = 66;
      expect(game.conditions.evaluate(node.conditionSet, game.state), isFalse);
    });
  });

  group('A12 the Scouter', () {
    test("forecasts character 67's guaranteed sing-off win", () {
      final game = Game.newRun(retry, random: Random(3));
      game.state.addItem(90021);
      game.state.setSwitch('SING_TARGET', 15);
      game.state.setSwitch('SING_COUNT', 0);
      final win = game.conditions.funcs['FUNC_SING_TARGET']!;

      game.state.characterId = 1;
      expect(win(game.state, const []), 0);
      expect(expandEventText('{IS_SING_WIN}', game.state), contains('lose'));

      game.state.characterId = 67;
      expect(win(game.state, const []), 1);
      expect(expandEventText('{IS_SING_WIN}', game.state), contains('win'));
    });
  });

  group('A03 held passive conditions', () {
    test('Level 8 Suit pays nothing below exercise level 8', () {
      final game = Game.newRun(original, random: Random(4));
      game.state.openingComplete = true;
      game.state.date = GameDate(game.state.date.day, 7);
      game.state.locationId = 1000;
      final study = original.locations[1000]!.actions.firstWhere(
        (action) => action.actionType == 'study',
      );
      final book = original
          .booksFor('korean')
          .firstWhere((book) => book.bookRank == '1');
      game.state.addItem(3028);
      expect(game.state.exerciseLevel.level, lessThan(8));
      expect(game.state.passiveSum('studyEfficiency', subject: 'korean'), 0);
      expect(game.preview(study, book: book).gain, 15);

      game.state.exerciseExp = original.exerciseLevels.tiers
          .firstWhere((t) => t.level == 8)
          .exp;
      expect(game.state.exerciseLevel.level, 8);
      expect(game.state.passiveSum('studyEfficiency', subject: 'korean'), 3);
      expect(game.preview(study, book: book).gain, 18);
    });
  });

  group('A06 shop maxCount', () {
    test('Book Stand cannot be bought past its cap of one', () {
      final game = Game.newRun(original, random: Random(6));
      expect(original.items[3005]!.maxCount, 1);
      game.state.money = 100000;
      expect(game.shopItemAtCap(3005), isFalse);
      expect(game.purchase(3005), isNull);
      expect(game.state.itemCount(3005), 1);
      expect(game.shopItemAtCap(3005), isTrue);

      // Owned some other way, with shop stock left: still refused, unpaid.
      final other = Game.newRun(original, random: Random(6));
      other.state.money = 100000;
      other.state.addItem(3005);
      expect(other.shopStock(3005), 1);
      expect(other.purchase(3005), isNotNull);
      expect(other.state.itemCount(3005), 1);
      expect(other.state.money, 100000);
    });
  });

  group('A07 Weekly Goal completion', () {
    test('an event stat gain meets the goal as it lands', () {
      final game = Game.newRun(original, random: Random(7));
      final goal = game.state.weeklyGoal!;
      final index = original.manifest.subjects.indexOf(goal.targetSubject);
      final short = goal.targetValue - game.state.stats[goal.targetSubject]!;
      game.effects.applyChanger({
        'funcCode': 'INCREASE_STAT',
        'args': [index, short + 10],
      }, game.state);
      expect(goal.met, isTrue);
    });

    test('a consumable stat gain meets the goal too', () {
      final game = Game.newRun(original, random: Random(8));
      final goal = game.state.weeklyGoal!;
      // Item 16 is Korean +450; aim the goal at Korean just within reach.
      game.state.weeklyGoal = WeeklyGoal(
        weekIndex: goal.weekIndex,
        targetSubject: 'korean',
        targetValue: (game.state.stats['korean']! + 400).round(),
        rewardSubject: goal.rewardSubject,
        rewardValue: goal.rewardValue,
        startValue: game.state.stats['korean']!,
      );
      game.state.addItem(16);
      expect(game.useItem(16), isTrue);
      expect(game.state.weeklyGoal!.met, isTrue);
    });

    test('the action that reaches the goal still announces it', () {
      final game = Game.newRun(original, random: Random(9));
      game.state.openingComplete = true;
      game.state.date = GameDate(game.state.date.day, 7);
      game.state.locationId = 1000;
      final goal = game.state.weeklyGoal!;
      final study = original.locations[1000]!.actions.firstWhere(
        (action) => action.actionType == 'study',
      );
      final book = original
          .booksFor(goal.targetSubject)
          .firstWhere((book) => book.bookRank == '1');
      game.state.stats[goal.targetSubject] = goal.targetValue - 1.0;
      final outcome = game.act(study, book: book);
      expect(goal.met, isTrue);
      expect(outcome.summary, contains('Weekly goal met!'));
    });
  });

  group('L01 tamgoo effects', () {
    test('touch only the two elective subjects, positions 3 and 4', () {
      final game = Game.newRun(original, random: Random(10));
      final subjects = original.manifest.subjects;
      expect(subjects.sublist(3), ['science', 'society']);
      for (final s in subjects) {
        game.state.stats[s] = 1000;
      }
      // Korean is the global highest, which must not be the one cut.
      game.state.stats['korean'] = 5000;
      game.state.stats['society'] = 1200;

      game.effects.applyChanger({
        'funcCode': 'INCREASE_TAMGOO_STAT',
        'args': [50],
      }, game.state);
      expect(game.state.stats['science'], 1050);
      expect(game.state.stats['society'], 1250);
      expect(game.state.stats['math'], 1000);
      expect(game.state.stats['korean'], 5000);

      game.effects.applyChanger({
        'funcCode': 'DECREASE_TAMGOO_STAT',
        'args': [20],
      }, game.state);
      expect(game.state.stats['science'], 1030);
      expect(game.state.stats['society'], 1230);
      expect(game.state.stats['english'], 1000);

      game.effects.applyChanger({
        'funcCode': 'DECREASE_TAMGOO_HIGH_STAT',
        'args': [100],
      }, game.state);
      expect(game.state.stats['society'], 1130);
      expect(game.state.stats['science'], 1030);
      expect(game.state.stats['korean'], 5000);
    });
  });

  group('L02 a gated final line', () {
    // No shipped final node carries an elseText today, so the graph is
    // written here: one `last` node gated on a switch.
    String finalLine({required int gate}) {
      final game = Game.newRun(original, random: Random(11));
      const nodeId = 990000001;
      original.nodes[nodeId] = EventNode.fromJson({
        'id': nodeId,
        'boxId': 990000001,
        'type': 'last',
        'text': 'Primary.',
        'elseText': 'Otherwise.',
        'conditionSet': {
          'conditions': [
            {
              'targetType': 'eventSwitch',
              'target': 'L02_GATE',
              'compareType': 'equal',
              'value': 1,
            },
          ],
        },
      });
      addTearDown(() => original.nodes.remove(nodeId));
      game.state.setSwitch('L02_GATE', gate);
      final event = GameEvent.fromJson({
        'id': 990000001,
        'name': 'L02',
        'rootNodeId': nodeId,
      });
      final run = game.events.begin(event, game.state);
      expect(run.current!.isEnd, isTrue);
      return run.current!.text;
    }

    test('says its elseText when the gate fails', () {
      expect(finalLine(gate: 1), 'Primary.');
      expect(finalLine(gate: 0), 'Otherwise.');
    });
  });

  group('L04 trait conditions fail closed', () {
    test('every gate in the shipped catalogs is one the engine reads', () {
      for (final pack in [original, retry]) {
        final game = Game.newRun(pack, random: Random(12));
        final engine = TraitEngine(pack: pack);
        final effects = [
          for (final t in pack.traits.values) ...t.effects,
          for (final c in pack.characters.values) ...c.effects,
          for (final b in pack.badges.values) ...b.effects,
        ];
        var gated = 0;
        for (final e in effects) {
          final conditions = e['conditions'] as List? ?? const [];
          for (final c in conditions.whereType<Map>()) {
            gated++;
            expect(
              TraitEngine.supportedConditionTargets,
              contains(c['target']),
            );
            engine.conditionsHold(
              {
                'conditions': [c],
              },
              game.state,
              TraitContext.none,
            );
          }
        }
        expect(gated, greaterThan(50));
        expect(engine.unknownConditions, isEmpty);
      }
    });

    test('an unread target or comparison withholds the effect', () {
      final game = Game.newRun(original, random: Random(13));
      final engine = TraitEngine(pack: original);
      bool holds(Map<String, dynamic> c) => engine.conditionsHold(
        {
          'conditions': [c],
        },
        game.state,
        TraitContext.none,
      );

      expect(holds({'target': 'TICK', 'compareType': 'greaterEqual'}), isTrue);
      expect(
        holds({'target': 'NOT_A_TARGET', 'compareType': 'equal'}),
        isFalse,
      );
      expect(holds({'target': 'TICK', 'compareType': 'sortOf'}), isFalse);
      expect(engine.unknownConditions, {'NOT_A_TARGET', 'TICK/sortOf'});
    });
  });
}
