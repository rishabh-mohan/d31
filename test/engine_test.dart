/// Exercises the engine against the real pack, headlessly.
///
/// The point of the simulation tests is coverage you cannot get by tapping
/// through the app: a few hundred full runs touch far more of the 322 events
/// and 13,173 nodes than hand-play ever would, and they fail loudly on the
/// things that are invisible on a device -- a graph that loops, a node link
/// that goes nowhere, an effect verb with no handler.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/conditions.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/effects.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/goals.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/engine/traits.dart';

late ContentPack pack;

/// Moves the clock past the weekday class ticks, where the hand is pinned and
/// the player is held at School.
void _leaveClass(Game game) {
  game.state.date = GameDate(game.state.date.day, game.classTicks);
  game.invalidateHand();
}

Future<void> main() async {
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  group('pack', () {
    test('loads the whole of story 16', () {
      expect(pack.manifest.id, 'kss16');
      expect(pack.manifest.totalDays, 32); // 2023-10-16 .. 2023-11-16
      expect(pack.locations, hasLength(11));
      // English 1.29.0 campaign: 147 events, 3444 records / 3094 unique nodes.
      expect(
        pack.events.values.where((e) => !e.isCharacterEvent),
        hasLength(147),
      );
      expect(
        pack.nodes.keys.where(
          (id) => !(pack.events[id ~/ 1000]?.isCharacterEvent ?? false),
        ),
        hasLength(3094),
      );
      // Campaign defaults plus the imported global character-event switches.
      expect(pack.switchDefaults, hasLength(235));
      expect(pack.items, hasLength(177));
      expect(pack.traits, hasLength(244));
      expect(pack.books, hasLength(54));
    });

    test('every event roots at a node that exists', () {
      final missing = pack.events.values
          .where((e) => !pack.nodes.containsKey(e.rootNodeId))
          .map((e) => '${e.id}:${e.name}')
          .toList();
      expect(
        missing,
        isEmpty,
        reason: 'events rooted at a missing node: $missing',
      );
    });

    test('option nodes parse their inline branches', () {
      final optionNodes = pack.nodes.values
          .where((n) => n.type == 'option')
          .where((n) => !(pack.events[n.id ~/ 1000]?.isCharacterEvent ?? false))
          .toList();
      expect(optionNodes, hasLength(74));
      // Every option node must offer at least one labelled branch -- an
      // option node with an empty list would stall the player on a dead beat.
      for (final n in optionNodes) {
        expect(
          n.options,
          isNotEmpty,
          reason: 'option node ${n.id} has no branches',
        );
        for (final o in n.options) {
          expect(
            o.text,
            isNotEmpty,
            reason: 'unlabelled branch on node ${n.id}',
          );
        }
      }
    });

    test('every option branch points at a node that exists', () {
      final dangling = <String>[];
      for (final n in pack.nodes.values) {
        if (n.type != 'option') continue;
        for (final o in n.options) {
          final byId =
              o.nextNodeId != null && pack.nodes.containsKey(o.nextNodeId);
          final byBox =
              o.nextBoxId != null &&
              (pack.nodesByBox[o.nextBoxId]?.isNotEmpty ?? false);
          if (!byId && !byBox) {
            dangling.add('node ${n.id} -> "${o.text}"');
          }
        }
      }
      expect(dangling, isEmpty, reason: 'dangling option branches: $dangling');
    });

    test('the engine handles every verb the pack uses', () {
      // Statically, not by playing: random coverage reaches ~a third of the
      // events, so a missing handler on a rare node would slip through.
      final usedFuncCodes = <String>{};
      void collect(Map<String, dynamic>? changer) {
        final code = changer?['funcCode'];
        if (code is String) usedFuncCodes.add(code);
      }

      for (final n in pack.nodes.values) {
        collect(n.changer);
        collect(n.actionChanger);
      }
      for (final l in pack.locations.values) {
        for (final a in l.actions) {
          collect(a.changer);
        }
      }

      final handled = EffectEngine.defaultHandlers.keys.toSet();
      expect(
        usedFuncCodes.difference(handled),
        isEmpty,
        reason: 'funcCodes with no handler do nothing, silently',
      );

      final usedTargets = <String>{};
      void walk(Map<String, dynamic>? set) {
        if (set == null) return;
        for (final c in (set['conditions'] as List? ?? const [])) {
          if (c is Map && c['targetType'] == 'func' && c['target'] is String) {
            usedTargets.add(c['target'] as String);
          }
        }
        walk((set['left'] as Map?)?.cast<String, dynamic>());
        walk((set['right'] as Map?)?.cast<String, dynamic>());
      }

      for (final e in pack.events.values) {
        walk(e.conditionSet);
      }
      for (final n in pack.nodes.values) {
        walk(n.conditionSet);
        for (final o in n.options) {
          walk(o.conditionSet);
        }
        for (final ch in [n.changer, n.actionChanger]) {
          for (final g in (ch?['changes'] as List? ?? const [])) {
            if (g is Map) {
              walk((g['conditionSet'] as Map?)?.cast<String, dynamic>());
            }
          }
        }
      }

      final knownFuncs = ConditionEvaluator.defaultFuncs.keys.toSet();
      expect(
        usedTargets.difference(knownFuncs),
        isEmpty,
        reason: 'FUNC_ targets with no handler evaluate false, silently',
      );
    });

    test('every item has structured effects or is marked flavour', () {
      final gaps = pack.items.values
          .where(
            (i) => i.effects.isEmpty && !i.flavour && i.effectText.isNotEmpty,
          )
          .map((i) => '${i.id}:${i.effectText}')
          .toList();
      expect(gaps, isEmpty, reason: 'items with unconverted effects: $gaps');
    });
  });

  group('calendar', () {
    test('parses and round-trips date codes', () {
      final d = GameDate.parse('DATE_2023101605');
      expect(d.day, DateTime(2023, 10, 16));
      expect(d.tick, 5);
      expect(d.code, 'DATE_2023101605');
    });

    test('rejects malformed codes instead of throwing', () {
      expect(GameDate.tryParse('nonsense'), isNull);
      expect(GameDate.tryParse(null), isNull);
    });

    test('advancing rolls over into the next day', () {
      final d = GameDate.parse('DATE_2023101614').advance(1, 15);
      expect(d.tick, 0);
      expect(d.day, DateTime(2023, 10, 17));
    });
  });

  group('conditions', () {
    test('an empty set is true', () {
      final state = GameState.newRun(pack);
      expect(ConditionEvaluator().evaluate(null, state), isTrue);
      expect(ConditionEvaluator().evaluate({'conditions': []}, state), isTrue);
    });

    test('reads event progress, switches and locations', () {
      final state = GameState.newRun(pack);
      final ev = ConditionEvaluator();

      Map<String, dynamic> cond(String target, String type, num value) => {
        'operator': 'and',
        'left': {'conditions': []},
        'right': {
          'conditions': [
            {
              'type': 'defaults',
              'target': target,
              'targetType': type,
              'compareType': 'equal',
              'value': value,
            },
          ],
        },
      };

      // EVENT_<id> is progress, not a count: 0 unseen, 1 playing, 2 done.
      expect(ev.evaluate(cond('EVENT_159', 'event', 0), state), isTrue);
      state.eventStates[159] = 1;
      expect(ev.evaluate(cond('EVENT_159', 'event', 0), state), isFalse);
      expect(ev.evaluate(cond('EVENT_159', 'event', 2), state), isFalse);
      state.eventStates[159] = 2;
      expect(ev.evaluate(cond('EVENT_159', 'event', 2), state), isTrue);

      state.setSwitch('PART_TIME_JOB_LEVEL_UP', 1);
      expect(
        ev.evaluate(cond('PART_TIME_JOB_LEVEL_UP', 'eventSwitch', 1), state),
        isTrue,
      );

      // A location condition asks where you ARE, not what you have unlocked.
      state.unlockedLocations.add(16002);
      expect(
        ev.evaluate(cond('LOCATION_16002', 'location', 1), state),
        isFalse,
        reason: 'unlocking the Park must not satisfy "at the Park"',
      );
      state.locationId = 16002;
      expect(ev.evaluate(cond('LOCATION_16002', 'location', 1), state), isTrue);
      expect(ev.evaluate(cond('LOCATION_1000', 'location', 1), state), isFalse);
    });

    test('or does not short-circuit to true on an empty side', () {
      final state = GameState.newRun(pack);
      final set = {
        'operator': 'or',
        'left': {'conditions': []},
        'right': {
          'conditions': [
            {
              'type': 'defaults',
              'target': 'EVENT_999999',
              'targetType': 'event',
              'compareType': 'equal',
              'value': 5,
            },
          ],
        },
      };
      expect(ConditionEvaluator().evaluate(set, state), isFalse);
    });
  });

  group('effects', () {
    test('INCREASE_STAT addresses subjects by index', () {
      // The order is recovered from the Dart enum ordinals in the AOT object
      // dump: korean=0, math=1, english=2, then the two elective slots.
      expect(pack.manifest.subjects, [
        'korean',
        'math',
        'english',
        'science',
        'society',
      ]);

      final game = Game.newRun(pack);
      // `stats.initial` is a per-subject map, so read the starting value off
      // a fresh run rather than through the scalar accessor.
      final start = game.state.stats['math']!;
      expect(start, 50, reason: 'subjects start at 50');

      game.effects.applyChanger({
        'funcCode': 'INCREASE_STAT',
        'args': [1, 150],
        'changes': [],
      }, game.state);
      expect(
        game.state.stats['math'],
        start + 150,
        reason: 'index 1 is math, not english',
      );
      expect(game.state.stats['english'], start);

      game.effects.applyChanger({
        'funcCode': 'INCREASE_STAT',
        'args': [2, 40],
        'changes': [],
      }, game.state);
      expect(game.state.stats['english'], start + 40);
    });

    test('changes[] set and add drive switches', () {
      final game = Game.newRun(pack);
      game.effects.applyChanger({
        'funcCode': null,
        'args': null,
        'changes': [
          {'type': 'set', 'target': 'ENDING_SW', 'value': 9},
          {'type': 'add', 'target': 'FRIENDSTEP', 'value': 2},
          {'type': 'add', 'target': 'FRIENDSTEP', 'value': 2},
        ],
      }, game.state);
      expect(game.state.switchValue('ENDING_SW'), 9);
      expect(game.state.switchValue('FRIENDSTEP'), 4);
    });

    test('END_GAME stops the run and records the ending', () {
      final game = Game.newRun(pack);
      game.effects.applyChanger({
        'funcCode': 'END_GAME',
        'args': [160005, 'Elite Ending'],
        'changes': [],
      }, game.state);
      expect(game.effects.endRequested, isTrue);
      expect(game.effects.endLabel, 'Elite Ending');
    });

    test('a consumable applies its recovered effects and is spent', () {
      final game = Game.newRun(pack);
      game.state.addItem(1); // Coffee: "Stamina +25"
      game.state.hp = 50;
      expect(game.useItem(1), isTrue);
      expect(game.state.hp, 75);
      expect(game.state.itemCount(1), 0);
    });

    test('a held normal item feeds passiveSum', () {
      final game = Game.newRun(pack);
      // NORMAL_STAT_2 adds two stats, one per efficiency unit.
      game.state.addItem(3026);
      game.state.locationId = 16003; // Reading Room, type "study"
      expect(game.state.passiveSum('studyEfficiency'), 2);
      game.state.locationId = 1000; // School, type "school" -- out of scope
      expect(game.state.passiveSum('studyEfficiency'), 0);
    });
  });

  group('the block hand', () {
    test('deals blocksPerTick blocks, drawn with replacement', () {
      final game = Game.newRun(pack, random: Random(11));
      _leaveClass(game);
      final hand = game.hand();
      expect(hand, hasLength(game.blocksPerTick));
      // Every dealt block must come from this location's own list.
      final pool = game.availableActions().toSet();
      expect(hand.every(pool.contains), isTrue);
    });

    test('a hand can repeat a block, and rerolls at a full-pool location', () {
      // School has exactly 4 ungated actions and blocksPerTick is 4. Drawn
      // without replacement that is always the whole pool, so the hand could
      // never change and a Refresh Ticket would do nothing. The reference
      // hands show duplicates, so the draw takes replacement.
      final game = Game.newRun(pack, random: Random(14));
      _leaveClass(game);
      expect(game.availableActions(), hasLength(game.blocksPerTick));

      final seen = <String>{};
      var sawDuplicate = false;
      game.state.rerolls = 60;
      for (var i = 0; i < 60; i++) {
        final hand = game.hand();
        seen.add(hand.map((a) => a.actionType).join(','));
        if (hand.toSet().length < hand.length) sawDuplicate = true;
        game.refreshHand();
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: 'a refresh must be able to change the hand',
      );
      expect(
        sawDuplicate,
        isTrue,
        reason: 'with replacement, a block should sometimes repeat',
      );
    });

    test('the same hand is returned until something invalidates it', () {
      final game = Game.newRun(pack, random: Random(12));
      _leaveClass(game);
      expect(identical(game.hand(), game.hand()), isTrue);
      game.invalidateHand();
      // A redeal may coincidentally match, so compare identity of the list.
      expect(identical(game.hand(), game.hand()), isTrue);
    });

    test('weight is a draw probability, not a payout multiplier', () {
      // The Reading Room is study 12 / sleep 0.3, so study should dominate
      // its hands -- and a study block there must not pay more than the same
      // book studied anywhere else.
      //
      // Note the gates: with no special blocks unlocked the Reading Room has
      // exactly 4 ungated actions, which is blocksPerTick, so the whole pool
      // is dealt and weights cannot show. Unlock the two special blocks a
      // character would grant, so the pool (6) exceeds the hand (4).
      final counts = <String, int>{};
      const deals = 300;
      for (var seed = 0; seed < deals; seed++) {
        final game = Game.newRun(pack, random: Random(seed));
        _leaveClass(game);
        game.state.unlockedLocations.add(16003);
        game.state.setSwitch('MECHANIC_BLOCK_CONDITION', 1);
        game.state.setSwitch('MEDICAL_BLOCK_CONDITION', 1);
        game.move(16003);
        final hand = game.hand();
        expect(hand, hasLength(4));
        for (final a in hand) {
          counts[a.actionType] = (counts[a.actionType] ?? 0) + 1;
        }
      }
      final study = counts['study'] ?? 0;
      final sleep = counts['sleep'] ?? 0;
      expect(
        study,
        greaterThan(sleep),
        reason: 'study 12 vs sleep 0.3 should dominate the draw: $counts',
      );
      expect(
        study,
        greaterThan(deals * 0.9),
        reason: 'weight 12 of 16.8 should appear in nearly every hand',
      );

      // Same book, two locations with very different study weights.
      final book = pack.books.values.first;
      final a = Game.newRun(pack, random: Random(1));
      _leaveClass(a);
      a.state.unlockedLocations.add(16003);
      a.move(16003);
      final readingRoom = a.preview(
        a.pack.locations[16003]!.actions.firstWhere(
          (x) => x.actionType == 'study',
        ),
        book: book,
      );

      final b = Game.newRun(pack, random: Random(1));
      final school = b.preview(
        b.pack.locations[1000]!.actions.firstWhere(
          (x) => x.actionType == 'study',
        ),
        book: book,
      );

      expect(
        readingRoom.gain,
        school.gain,
        reason: 'location weight must not change the payout',
      );
    });

    test('refreshing costs a ticket and stops at zero', () {
      final game = Game.newRun(pack, random: Random(13));
      _leaveClass(game);
      game.state.rerolls = 1;
      expect(game.refreshHand(), isTrue);
      expect(game.state.rerolls, 0);
      expect(game.refreshHand(), isFalse);
    });
  });

  group('the day', () {
    test('gives 14 player actions, then an evening slot', () {
      final game = Game.newRun(pack, random: Random(21));
      expect(game.actionTicksPerDay, 14);
      expect(pack.manifest.ticksPerDay, 15);

      final startDay = game.state.date.day;
      for (var i = 0; i < 14; i++) {
        game.state.hp = game.state.hpMax; // isolate the clock from stamina
        expect(
          game.state.date.day,
          startDay,
          reason: 'the day ended early, after $i actions',
        );
        expect(game.state.date.tick, i);
        final hand = game.hand();
        // Avoid study so no book juggling is needed.
        final action = hand.firstWhere(
          (a) => a.actionType != 'study',
          orElse: () => hand.first,
        );
        game.act(
          action,
          book: action.actionType == 'study' ? pack.books.values.first : null,
        );
      }
      expect(
        game.state.date.day,
        startDay.add(const Duration(days: 1)),
        reason: 'the 14th action should roll the day over',
      );
      expect(game.state.date.tick, 0);
    });

    test('tick 14 is where the evening condition becomes true', () {
      final game = Game.newRun(pack, random: Random(22));
      final condition = <String, dynamic>{
        'conditions': [
          {
            'type': 'defaults',
            'target': 'DATE_PROGRESS',
            'targetType': 'eventSwitch',
            'compareType': 'equal',
            'value': 14,
          },
        ],
      };
      game.state.date = GameDate(game.state.date.day, 0);
      expect(game.conditions.evaluate(condition, game.state), isFalse);
      game.state.date = GameDate(game.state.date.day, 14);
      expect(game.conditions.evaluate(condition, game.state), isTrue);
    });

    test('sleeping restores stamina without ending the day', () {
      final game = Game.newRun(pack, random: Random(23));
      _leaveClass(game);
      final sleep = game.availableActions().firstWhere(
        (a) => a.actionType == 'sleep',
      );

      final day = game.state.date.day;
      final tick = game.state.date.tick;
      game.state.hp = 20;

      final outcome = game.act(sleep);

      expect(game.state.hp, greaterThan(20));
      expect(outcome.dayEnded, isFalse, reason: 'sleep must not end the day');
      expect(game.state.date.day, day);
      expect(
        game.state.date.tick,
        tick + 1,
        reason: 'sleep still costs one tick',
      );
    });
  });

  group('class lessons', () {
    test('a weekday starts in class with a pinned lesson block', () {
      final game = Game.newRun(pack, random: Random(31));
      // The run starts Monday 2023-10-16 at tick 0.
      expect(game.state.date.day.weekday, DateTime.monday);
      expect(game.inClass, isTrue);

      final hand = game.hand();
      expect(hand.first.actionType, 'lesson');
      expect(hand, hasLength(game.blocksPerTick));
      // Only one lesson, and it is the first slot.
      expect(hand.where((a) => a.actionType == 'lesson'), hasLength(1));
    });

    test('a refresh never rerolls the lesson away', () {
      final game = Game.newRun(pack, random: Random(32));
      game.state.rerolls = 10;
      for (var i = 0; i < 10; i++) {
        expect(game.hand().first.actionType, 'lesson');
        game.refreshHand();
      }
    });

    test('the player cannot leave school during class', () {
      final game = Game.newRun(pack, random: Random(33));
      game.state.unlockedLocations.add(16002);
      expect(game.move(16002), isFalse);
      expect(game.availableLocations().map((l) => l.id), [1000]);

      _leaveClass(game);
      expect(game.move(16002), isTrue);
    });

    test('class ends after classTicks, and not at weekends', () {
      final game = Game.newRun(pack, random: Random(34));
      game.state.date = GameDate(game.state.date.day, game.classTicks - 1);
      expect(game.inClass, isTrue);
      game.state.date = GameDate(game.state.date.day, game.classTicks);
      expect(game.inClass, isFalse);

      // 2023-10-21 is the first Saturday of the run.
      game.state.date = GameDate(DateTime(2023, 10, 21), 0);
      expect(game.inClass, isFalse, reason: 'no class at the weekend');
    });

    test('a lesson teaches a subject at a real book rate', () {
      final game = Game.newRun(pack, random: Random(35));
      final lesson = game.lessonFor(game.state.date);
      expect(lesson, isNotNull);
      expect(pack.manifest.subjects, contains(lesson!.subject));
      expect(lesson.book.subject, lesson.subject);

      final before = game.state.stats[lesson.subject]!;
      final block = game.hand().first;
      expect(block.actionType, 'lesson');
      final shown = game.preview(block);

      // The card shows a band; the payout is rolled inside it.
      expect(shown.gain, isNotNull);
      expect(shown.gainMax, isNotNull);
      expect(shown.gainMax!, greaterThan(shown.gain!));
      expect(shown.title, 'Period 1');

      game.act(block);
      final gained = game.state.stats[lesson.subject]! - before;
      expect(gained, greaterThanOrEqualTo(shown.gain!));
      expect(gained, lessThanOrEqualTo(shown.gainMax!));
    });

    test('the lesson is stable within a tick but varies across them', () {
      final game = Game.newRun(pack, random: Random(36));
      final a = game.lessonFor(game.state.date);
      final b = game.lessonFor(game.state.date);
      expect(a!.book.id, b!.book.id, reason: 'same tick, same lesson');

      final seen = <int>{};
      for (var t = 0; t < 6; t++) {
        final l = game.lessonFor(GameDate(game.state.date.day, t));
        if (l != null) seen.add(l.book.id);
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: 'the lesson should vary tick to tick',
      );
    });
  });

  group('weekly goals', () {
    test('a goal is issued at run start, targeting a real subject', () {
      final game = Game.newRun(pack, random: Random(41));
      final goal = game.state.weeklyGoal;
      expect(goal, isNotNull);
      expect(pack.manifest.subjects, contains(goal!.targetSubject));
      expect(pack.manifest.subjects, contains(goal.rewardSubject));
      expect(
        goal.targetValue,
        greaterThan(game.state.stats[goal.targetSubject] ?? 0),
      );
    });

    test('meeting the goal pays its reward on the Monday rollover', () {
      final game = Game.newRun(pack, random: Random(42));
      final goal = game.state.weeklyGoal!;
      game.state.stats[goal.targetSubject] = goal.targetValue.toDouble();
      expect(Goals.checkMet(game.state), isTrue);
      expect(goal.met, isTrue);

      final before = game.state.stats[goal.rewardSubject] ?? 0;
      Goals.payReward(game.state);
      expect(game.state.stats[goal.rewardSubject]! - before, goal.rewardValue);
    });

    test('study after the goal is met still weights the next goal', () {
      // Two runs, identical except that one keeps studying after the goal is
      // already met. The next week's bar must be higher for that one.
      int nextTargetAfter({required int surplusBlocks}) {
        final game = Game.newRun(pack, random: Random(43));
        final goal = game.state.weeklyGoal!;
        game.state.stats[goal.targetSubject] = goal.targetValue.toDouble();
        Goals.checkMet(game.state);
        for (var i = 0; i < surplusBlocks; i++) {
          Goals.recordStudyBlock(game.state);
        }
        // Monday of week 1.
        game.state.date = GameDate(DateTime(2023, 10, 23), 0);
        Goals.rollOver(game.state);
        return game.state.weeklyGoal!.targetValue;
      }

      final lazy = nextTargetAfter(surplusBlocks: 0);
      final diligent = nextTargetAfter(surplusBlocks: 20);
      expect(
        diligent,
        greaterThan(lazy),
        reason: 'surplus study must raise the next bar, not be wasted',
      );

      // And those surplus blocks are counted as surplus.
      final game = Game.newRun(pack, random: Random(43));
      game.state.weeklyGoal!.met = true;
      Goals.recordStudyBlock(game.state);
      expect(game.state.surplusStudyBlocks, 1);
      expect(game.state.studyBlocksThisWeek, 1);
    });
  });

  group('traits', () {
    /// A run parked out of class at one location, with one trait granted.
    Game withTrait(int id, {int locationId = 16005, int tick = 7}) {
      final game = Game.newRun(pack, random: Random(51));
      game.state.date = GameDate(game.state.date.day, tick);
      game.state.locationId = locationId;
      expect(game.state.grantTrait(id), isTrue, reason: 'trait $id refused');
      game.invalidateHand();
      return game;
    }

    LocationAction actionOf(Game game, String type) =>
        game.state.location!.actions.firstWhere((a) => a.actionType == type);

    int studyCost(Game game) =>
        game.preview(actionOf(game, 'study')).hpCost.round();

    int plainStudyCost({int locationId = 16005, int tick = 7}) {
      final game = Game.newRun(pack, random: Random(53));
      game.state.date = GameDate(game.state.date.day, tick);
      game.state.locationId = locationId;
      return studyCost(game);
    }

    test('the catalog loads and the system is on', () {
      expect(pack.traits, hasLength(244));
      final game = Game.newRun(pack, random: Random(51));
      expect(game.state.traitsEnabled, isTrue);
    });

    test('firstPlusStat applies once, at run start', () {
      // Trait 1 "TOEIC 800": Initial English Stats +100.
      final game = Game.newRun(pack, random: Random(52));
      final before = game.state.stats['english']!;
      game.state.grantTrait(1);
      game.state.applyStartingTraitEffects();
      expect(game.state.stats['english'], before + 100);
    });

    test('a stat effect uses one stat per story efficiency unit', () {
      // Trait 104 "Bookworm": "+STAT_1 at [Study Locations]", shipped as
      // extraStat 3 / storyStat 1. So +1, and only at a study location.
      final atReadingRoom = withTrait(104, locationId: 16003);
      expect(atReadingRoom.state.location!.type, 'study');
      expect(atReadingRoom.traits.studyBonus(atReadingRoom.state), 1);

      final atGym = withTrait(104, locationId: 16005);
      expect(atGym.traits.studyBonus(atGym.state), 0);
    });

    test('an effect with extraStat 0 falls back to storyStat', () {
      // Trait 160011 "High Potential" reads "+STAT_5" and ships
      // extraStat 15 / storyStat 0, so the live number is 15.
      final game = withTrait(160011);
      expect(game.traits.studyBonus(game.state), 15);

      // And the other way round: story 3's "Western Taste" ships
      // extraStat 0 / storyStat 1 and its description reads "+1".
      final westernTaste = pack.traits[30004]!.effects.first;
      expect(game.traits.statValue(westernTaste), 1);
    });

    test('badges use the same unscaled study efficiency units', () {
      // Boryeong carries storyStat 2 / extraStat 7; efficiency is +2.
      final boryeong = pack.badges[33]!;
      expect(boryeong.name, 'Boryeong University');
      final game = Game.newRun(pack, random: Random(59));
      expect(game.traits.statValue(boryeong.effects.first), 2);
    });

    test('scope and conditions both gate a trait to its place', () {
      // Trait 24 "Hikikomori": +STAT_1 at {HOME}, written twice over --
      // locationIdList [2000] on the trait and LOCATION_ID == 2000 on the
      // effect. Either spelling alone must be enough.
      final atHome = withTrait(24, locationId: 2000);
      expect(atHome.traits.studyBonus(atHome.state), 1);
      final atSchool = withTrait(24, locationId: 1000);
      expect(atSchool.traits.studyBonus(atSchool.state), 0);
    });

    test('a subject-specific effect only pays that subject', () {
      // Trait 17 "Gifted and Talented": Science +STAT_2.
      final game = withTrait(17);
      expect(game.traits.studyBonus(game.state, subject: 'science'), 2);
      expect(game.traits.studyBonus(game.state, subject: 'korean'), 0);
    });

    test('tamgoos means the two elective slots', () {
      // Trait 88 "Interdisciplinary Student": Humanities and Science +STAT_1.
      final game = withTrait(88);
      for (final subject in ['science', 'society']) {
        expect(game.traits.studyBonus(game.state, subject: subject), 1);
      }
      for (final subject in ['korean', 'math', 'english']) {
        expect(game.traits.studyBonus(game.state, subject: subject), 0);
      }
    });

    test('lowSubject follows the weakest subject as it moves', () {
      // Trait 66 "Inferiority Complex": weakest subject +STAT_5.
      final game = withTrait(66);
      game.state.stats['math'] = 10; // now the weakest
      expect(game.traits.studyBonus(game.state, subject: 'math'), 5);
      expect(game.traits.studyBonus(game.state, subject: 'korean'), 0);
      game.state.stats['korean'] = 1;
      expect(game.traits.studyBonus(game.state, subject: 'korean'), 5);
      expect(game.traits.studyBonus(game.state, subject: 'math'), 0);
    });

    test('a stamina discount reaches the action cost', () {
      // Trait 63 "Indestructible": Stamina Cost -3. The reference's buffed
      // screenshots sit exactly 3 lower, which is where the un-buffed
      // baseline in rules.staminaCost came from.
      final buffed = withTrait(63);
      expect(studyCost(buffed), plainStudyCost() - 3);
    });

    test('a tick-gated discount applies only in the last five ticks', () {
      // Trait 5 "Night Owl": -3 in the last five ticks, as TICK >= 10 --
      // itself evidence that 14 of the 15 ticks are the player's.
      expect(studyCost(withTrait(5, tick: 3)), plainStudyCost(tick: 3));
      expect(studyCost(withTrait(5, tick: 11)), plainStudyCost(tick: 11) - 3);
    });

    test('Out of Shape costs stamina, and exercising clears it', () {
      final game = withTrait(GameState.outOfShapeTraitId);
      expect(studyCost(game), plainStudyCost() + 3);
      game.clearOutOfShape();
      expect(studyCost(game), plainStudyCost());
    });

    test('percent fields are factors, not percentages', () {
      // "Workaholic: Part-Time earnings +20%" ships percentPlusMoney 1.2,
      // and "Getting Fitter!: Workout EXP +20%" ships percentPlusExp 1.2.
      final game = withTrait(23, locationId: 16001); // Gold Mine
      final (flat, factor) = game.traits.partTimeMoney(game.state);
      expect(flat, 0);
      expect(factor, closeTo(1.2, 0.0001));

      final fitter = withTrait(25);
      final (exFlat, exFactor) = fitter.traits.exerciseExp(fitter.state);
      expect(exFlat, 0);
      expect(exFactor, closeTo(1.2, 0.0001));

      // And a flat one is flat: "All jobs are mine!: +100".
      final flatPay = withTrait(22, locationId: 16001);
      expect(flatPay.traits.partTimeMoney(flatPay.state).$1, 100);
    });

    test('sleep and goal rewards take their traits', () {
      final sleeper = withTrait(14); // Deep Sleep: Stamina Recovery +1
      expect(sleeper.traits.sleepHp(sleeper.state), 1);

      final judger = withTrait(38); // MBTI J. Judger: rewards +10%
      expect(
        judger.traits.goalRewardFactor(judger.state),
        closeTo(1.1, 0.0001),
      );
    });

    test('a predicate condition can require a trait to be absent', () {
      // Trait 212 "Superiority" wants trait 200010 NOT held, 213
      // "Motivated" wants it held. Both belong to story 20, so they can
      // never be granted in this run -- the evaluator is tested directly.
      final game = Game.newRun(pack, random: Random(57));
      final wantsAbsent = pack.traits[212]!.effects.first;
      final wantsPresent = pack.traits[213]!.effects.first;

      expect(
        game.traits.conditionsHold(wantsAbsent, game.state, TraitContext.none),
        isTrue,
      );
      expect(
        game.traits.conditionsHold(wantsPresent, game.state, TraitContext.none),
        isFalse,
      );

      game.state.traits.add(200010);
      expect(
        game.traits.conditionsHold(wantsAbsent, game.state, TraitContext.none),
        isFalse,
      );
      expect(
        game.traits.conditionsHold(wantsPresent, game.state, TraitContext.none),
        isTrue,
      );
    });

    test('a held item can be a condition too', () {
      // Trait 138 "Overdresser": +6 per Winter Equipment, one effect per
      // item (70002, 70003, 70008). Story 18's, so again evaluated directly.
      final game = Game.newRun(pack, random: Random(58));
      final effect = pack.traits[138]!.effects.first;
      expect(
        game.traits.conditionsHold(effect, game.state, TraitContext.none),
        isFalse,
      );
      game.state.addItem(70002);
      expect(
        game.traits.conditionsHold(effect, game.state, TraitContext.none),
        isTrue,
      );
    });

    test('a temporary trait ages out, and only then stops counting', () {
      // Trait 10 "Flu": Stamina Cost +4, initialLifeTime 4.
      final game = withTrait(10);
      expect(game.state.traitDaysLeft[10], 4);
      expect(game.traits.hpCostDelta(game.state), 4);

      for (var day = 0; day < 3; day++) {
        game.state.expireTraitsForNewDay();
        expect(game.state.traits, contains(10), reason: 'day $day');
        expect(game.traits.hpCostDelta(game.state), 4);
      }
      game.state.expireTraitsForNewDay();
      expect(game.state.traits, isNot(contains(10)));
      expect(game.traits.hpCostDelta(game.state), 0);
    });

    test('a trait from another story is refused', () {
      // Trait 202 "Genius of the Generation" belongs to story 20.
      final game = Game.newRun(pack, random: Random(56));
      expect(pack.traits[202]!.storyId, 20);
      expect(game.state.grantTrait(202), isFalse);
      expect(game.state.traits, isNot(contains(202)));
      // Story 16's own traits are fine.
      expect(pack.traits[160003]!.storyId, 16);
      expect(game.state.grantTrait(160003), isTrue);
    });

    test('a granted trait survives save and load, clock and all', () {
      final game = withTrait(10);
      game.state.expireTraitsForNewDay();
      final restored = GameState.fromJson(pack, game.state.toJson());
      expect(restored.traits, contains(10));
      expect(restored.traitDaysLeft[10], 3);
    });

    test('every effect type in the catalog is one the engine reads', () {
      const known = {
        'plusStat',
        'schoolStudyPlusStat',
        'hpCost',
        'partTimeJobMoney',
        'exerciseExp',
        'plusSleepHp',
        'goalReward',
        'firstPlusStat',
        'firstPlusMoney',
        'firstExerciseLevel',
        'firstPlusPartTimeJobLevel',
      };
      final unknown = <String>{};
      for (final trait in pack.traits.values) {
        for (final e in trait.effects) {
          final type = e['type'] as String?;
          if (type != null && !known.contains(type)) unknown.add(type);
        }
      }
      expect(unknown, isEmpty, reason: 'unhandled trait effects: $unknown');
    });

    test('every condition target in the catalog is one the engine reads', () {
      const known = {
        'LOCATION_ID',
        'LOCATION_TYPE',
        'TICK',
        'TICK_RANDOM',
        'WEEKCODE',
        'DATE_WEEK',
        'DATE_INT',
        'COMBO_STUDY',
        'PREV_STUDY_SUBJECT',
        'IS_BEFORE_SAT_EXAM',
        'EXERCISE_LEVEL',
        'PART_TIME_JOB_LEVEL',
        'STUDY_LEVEL',
        'IS_HAVE_ITEM',
        'IS_HAVE_TRAIT',
        'IS_TODAY_IN_DATE_LIST',
      };
      final unknown = <String>{};
      for (final trait in pack.traits.values) {
        for (final e in trait.effects) {
          for (final c in (e['conditions'] as List? ?? const [])) {
            final target = (c as Map)['target'] as String?;
            if (target != null && !known.contains(target)) {
              unknown.add(target);
            }
          }
        }
      }
      expect(unknown, isEmpty, reason: 'unhandled trait conditions: $unknown');
    });

    test('a dice-roll trait rolls the same for the card and the block', () {
      // Trait 33 "Monty Hall Problem": 2/3 chance of an extra +STAT_7 when
      // studying Maths. If that roll came from the run's RNG the action card
      // would show one number and the block would pay another.
      final game = withTrait(33, locationId: 16003);
      final first = game.traits.studyBonus(game.state, subject: 'math');
      for (var i = 0; i < 20; i++) {
        expect(game.traits.studyBonus(game.state, subject: 'math'), first);
      }
      expect(first, anyOf(0, 21));

      // And it does move from tick to tick, which is what TICK_RANDOM means.
      final seen = <num>{};
      for (var tick = 0; tick < 14; tick++) {
        game.state.date = GameDate(game.state.date.day, tick);
        seen.add(game.traits.studyBonus(game.state, subject: 'math'));
      }
      expect(seen.length, greaterThan(1));
    });

    test('a study card promises what a trait-buffed block delivers', () {
      final game = withTrait(33, locationId: 16003);
      final study = game.state.location!.actions.firstWhere(
        (a) => a.actionType == 'study',
      );
      final book = game.bookForSlot(0);
      final promised = game.preview(study, book: book).gain;
      final before = game.state.stats[book!.subject]!;
      game.act(study, book: book);
      expect(game.state.stats[book.subject]! - before, promised);
    });

    test('the day before the exam is what IS_BEFORE_SAT_EXAM means', () {
      // Trait 35 "Procrastinator": all subjects +STAT_15 the day before the
      // CSAT, which story 16 schedules on 2023-11-16.
      final game = withTrait(35);
      game.state.date = GameDate(DateTime(2023, 11, 15), 7);
      expect(game.state.isDayBeforeExam, isTrue);
      expect(game.traits.studyBonus(game.state), 15);

      game.state.date = GameDate(DateTime(2023, 11, 10), 7);
      expect(game.state.isDayBeforeExam, isFalse);
      expect(game.traits.studyBonus(game.state), 0);
    });
  });

  group('engine switches', () {
    test('expose the calendar to content', () {
      final game = Game.newRun(pack, random: Random(61));
      game.state.date = GameDate(DateTime(2023, 10, 18), 7);
      expect(game.state.switchValue('DATE_PROGRESS'), 7);
      expect(game.state.switchValue('TICK'), 7);
      expect(game.state.switchValue('DATE_DAY'), 18);
      expect(game.state.switchValue('DATE_MONTH'), 10);
      expect(game.state.switchValue('WEEKCODE'), DateTime.wednesday);
    });

    test('cannot be overwritten by content', () {
      final game = Game.newRun(pack, random: Random(62));
      game.state.date = GameDate(DateTime(2023, 10, 18), 3);
      game.state.setSwitch('DATE_PROGRESS', 99);
      expect(game.state.switchValue('DATE_PROGRESS'), 3);
    });
  });

  group('location-gated events', () {
    test('only fire while you are actually at that location', () {
      // #200 "I've Been Watching" is LOCATION_16004 (Cafe) in section one. It
      // must not be eligible from School just because the Cafe is unlocked.
      final game = Game.newRun(pack, random: Random(71));
      _leaveClass(game);
      game.state.unlockedLocations.addAll([16004, 16002]);
      game.state.setSwitch('SON_NIM', 0);

      bool eligibleAt(int locationId) {
        game.state.locationId = locationId;
        return game.events.eligible(game.state).any((e) => e.id == 200);
      }

      expect(
        eligibleAt(1000),
        isFalse,
        reason: 'cafe content must not fire at School',
      );
      expect(
        eligibleAt(16002),
        isFalse,
        reason: 'cafe content must not fire at the Park',
      );
      expect(
        eligibleAt(16004),
        isTrue,
        reason: 'cafe content should fire at the Cafe',
      );
    });

    test('every location-gated event names a location that exists', () {
      final bad = <String>[];
      void walk(Map<String, dynamic>? set, int eventId) {
        if (set == null) return;
        for (final c in (set['conditions'] as List? ?? const [])) {
          if (c is Map && c['targetType'] == 'location') {
            final id = int.tryParse(
              (c['target'] as String).replaceFirst('LOCATION_', ''),
            );
            if (id == null || !pack.locations.containsKey(id)) {
              bad.add('#$eventId -> ${c['target']}');
            }
          }
        }
        walk((set['left'] as Map?)?.cast<String, dynamic>(), eventId);
        walk((set['right'] as Map?)?.cast<String, dynamic>(), eventId);
      }

      for (final e in pack.events.values) {
        walk(e.conditionSet, e.id);
      }
      expect(bad, isEmpty);
    });
  });

  group('storyline prerequisites', () {
    // #189 "Come On!" -- the teacher walking you over to the comic club --
    // is gated in the shipped data on nothing but its date, because KSS runs
    // an event set one beat at a time in compiled code. Without #188 "School
    // Comics Contest" behind it, the teacher reacts to a comic you never
    // drew. tools/build_pack.py adds the prerequisite the set logic implied.
    Game atComeOnDay() {
      final game = Game.newRun(pack, random: Random(189));
      game.state.date = GameDate(DateTime(2023, 10, 20), 0);
      return game;
    }

    bool comeOnEligible(Game game) =>
        game.events.eligible(game.state).any((e) => e.id == 189);

    test('"Come On!" waits for the comics contest it follows', () {
      final game = atComeOnDay();
      expect(
        comeOnEligible(game),
        isFalse,
        reason: 'the comic club beat must not fire before the contest',
      );

      // Mid-play is not good enough either: the prerequisite is completion.
      game.state.eventStates[188] = 1;
      expect(comeOnEligible(game), isFalse);

      game.state.eventStates[188] = 2;
      expect(comeOnEligible(game), isTrue);
    });

    test('playing the contest through is what unlocks it', () {
      final game = atComeOnDay();
      final run = game.events.begin(pack.events[188]!, game.state);
      var steps = 0;
      while (!run.current!.isEnd && steps++ < 200) {
        final choices = run.current!.choices;
        if (choices.isEmpty) {
          run.advance();
        } else {
          run.choose(choices.first);
        }
      }
      expect(run.current!.isEnd, isTrue);
      expect(game.state.eventStates[188], 2);
      expect(comeOnEligible(game), isTrue);
    });

    test('an event reports 0, then 1 while playing, then 2', () {
      final game = Game.newRun(pack, random: Random(188));
      expect(game.state.eventStates[1] ?? 0, 0);
      final run = game.events.begin(pack.events[1]!, game.state);
      expect(game.state.eventStates[1], 1);
      var steps = 0;
      while (!run.current!.isEnd && steps++ < 200) {
        final choices = run.current!.choices;
        choices.isEmpty ? run.advance() : run.choose(choices.first);
      }
      expect(game.state.eventStates[1], 2);
    });
  });

  group('a maxed exercise level', () {
    Game maxedAt(int locationId) {
      final game = Game.newRun(pack, random: Random(10));
      _leaveClass(game);
      game.state.locationId = locationId;
      game.state.exerciseExp = pack.exerciseLevels.tiers.last.exp;
      game.invalidateHand();
      return game;
    }

    test('tops out at level 10', () {
      expect(pack.exerciseLevels.maxLevel, 10);
      final game = maxedAt(16005);
      expect(game.state.exerciseLevel.level, 10);
      expect(game.state.exerciseMaxed, isTrue);
    });

    test('retires the workout block from every location that offers it', () {
      // All ten locations with a workout action -- every one but the Gold
      // Mine, which deals only part-time work and sleep.
      final offering = pack.locations.values
          .where((l) => l.actions.any((a) => a.actionType == 'exercise'))
          .map((l) => l.id)
          .toList();
      expect(offering, hasLength(10));

      for (final id in offering) {
        final game = maxedAt(id);
        expect(
          game.availableActions().any((a) => a.actionType == 'exercise'),
          isFalse,
          reason: 'location $id still offers a workout at level 10',
        );
        expect(
          game.availableActions(),
          isNotEmpty,
          reason: 'location $id must still deal something',
        );
        game.state.rerolls = 40;
        for (var i = 0; i < 40; i++) {
          expect(
            game.hand().any((a) => a.actionType == 'exercise'),
            isFalse,
            reason: 'a workout was dealt at level 10 in location $id',
          );
          game.refreshHand();
        }
      }
    });

    test('is still offered a workout below the cap', () {
      final game = Game.newRun(pack, random: Random(10));
      _leaveClass(game);
      game.state.locationId = 16005; // Gym
      game.invalidateHand();
      expect(
        game.availableActions().any((a) => a.actionType == 'exercise'),
        isTrue,
      );
    });

    test('can never go Out of Shape', () {
      // The global trait event 10010003 "Out of Shape" has exactly one
      // condition, TRAIT_EVENT_7 == 1. Pinning that switch to 0 at the cap
      // is what makes the event unreachable there.
      final game = maxedAt(16005);
      game.state.setSwitch(GameState.outOfShapeSwitch, 1);
      expect(game.state.switchValue(GameState.outOfShapeSwitch), 0);
      game.state.addSwitch(GameState.outOfShapeSwitch, 1);
      expect(game.state.switchValue(GameState.outOfShapeSwitch), 0);

      // Below the cap the switch behaves normally -- the rule is the cap,
      // not a blanket ban.
      final fresh = Game.newRun(pack, random: Random(10));
      fresh.state.setSwitch(GameState.outOfShapeSwitch, 1);
      expect(fresh.state.switchValue(GameState.outOfShapeSwitch), 1);
    });

    test('exercising clears an Out of Shape already held', () {
      final game = Game.newRun(pack, random: Random(10));
      game.state.setSwitch(GameState.outOfShapeSwitch, 1);
      game.state.traits.add(GameState.outOfShapeTraitId);
      game.clearOutOfShape();
      expect(game.state.switchValue(GameState.outOfShapeSwitch), 0);
      expect(game.state.traits, isNot(contains(GameState.outOfShapeTraitId)));
    });
  });

  group('book tiers and unlocking', () {
    test('ranks display as letters, weakest to strongest', () {
      const expected = {
        '1': 'E',
        '2': 'D',
        '3': 'C',
        '4': 'B',
        '5': 'A',
        '6': 'S',
      };
      for (final book in pack.books.values) {
        final want = expected[book.bookRank];
        if (want != null) expect(book.tier, want);
      }
      // E really is the weakest: it must not out-power the tier above it.
      final korean = pack.booksFor('korean');
      expect(korean.first.tier, 'E');
      if (korean.length > 1) {
        expect(korean.first.power, lessThanOrEqualTo(korean[1].power));
      }
    });

    test('only the lowest tier is unlocked at the start of a run', () {
      final game = Game.newRun(pack, random: Random(91));
      for (final subject in pack.manifest.subjects) {
        final unlocked = game.unlockedBooksFor(subject);
        expect(
          unlocked,
          hasLength(1),
          reason: '$subject should start with only its E-tier book',
        );
        expect(unlocked.single.tier, 'E');
      }
    });

    test('finishing a book unlocks exactly the next tier', () {
      final game = Game.newRun(pack, random: Random(92));
      final korean = pack.booksFor('korean');
      final first = korean.first;

      expect(game.isBookComplete(first), isFalse);
      game.state.bookReadCounts[first.id] = first.doneCount;
      expect(game.isBookComplete(first), isTrue);

      final unlocked = game.unlockedBooksFor('korean');
      expect(unlocked, hasLength(2), reason: 'one tier opens, not all of them');
      expect(unlocked.last.id, korean[1].id);
      // Other subjects are unaffected.
      expect(game.unlockedBooksFor('math'), hasLength(1));
    });

    test('the block lottery never offers a locked book', () {
      final game = Game.newRun(pack, random: Random(93));
      final allowed = game.studiableBooks().map((b) => b.id).toSet();
      expect(allowed, isNotEmpty);
      // Every subject contributes exactly its E-tier book at run start.
      expect(allowed, hasLength(pack.manifest.subjects.length));

      for (var slot = 0; slot < 400; slot++) {
        final book = game.bookForSlot(slot);
        expect(book, isNotNull);
        expect(
          allowed.contains(book!.id),
          isTrue,
          reason: '${book.name} (${book.tier}) is locked but was dealt',
        );
      }
    });

    test('a finished book still studies, and reports itself complete', () {
      final game = Game.newRun(pack, random: Random(94));
      _leaveClass(game);
      final book = pack.booksFor('korean').first;
      game.state.bookReadCounts[book.id] = book.doneCount;

      final study = pack.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'study',
      );
      final preview = game.preview(study, book: book);

      expect(preview.bookComplete, isTrue);
      expect(
        preview.gain,
        greaterThan(0),
        reason: 'a read-through book still pays out',
      );
    });

    test('progress saturates rather than wrapping past completion', () {
      final game = Game.newRun(pack, random: Random(95));
      _leaveClass(game);
      final book = pack.booksFor('korean').first;
      final study = pack.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'study',
      );

      game.state.bookReadCounts[book.id] = book.doneCount ~/ 2;
      final half = game.preview(study, book: book).progress;
      expect(half, greaterThan(0));
      expect(half, lessThan(1));

      // Past the finish line the bar must stay full, not reset to empty.
      game.state.bookReadCounts[book.id] = book.doneCount * 2;
      expect(game.preview(study, book: book).progress, 1);
    });
  });

  group('the stamina and study economy', () {
    // These are fitted to the reference screenshots and are the numbers the
    // whole run balances on, so they get a regression guard.
    test('action costs match the reference, within rounding', () {
      final game = Game.newRun(pack, random: Random(81));
      _leaveClass(game);
      final school = pack.locations[1000]!;

      num costOf(String type) => game
          .preview(
            school.actions.firstWhere((a) => a.actionType == type),
            book: pack.books.values.first,
          )
          .hpCost;

      expect(costOf('study'), closeTo(16, 1));
      expect(costOf('exercise'), closeTo(24, 1.5));
      expect(costOf('partTimeJob'), closeTo(29, 1));
      expect(costOf('sleep'), 0, reason: 'sleep restores, it does not cost');
    });

    test('a Class block starts at -9 stamina', () {
      // The reference's first Class block of a run reads -9: no exercise
      // level, no trait discount, no item.
      final game = Game.newRun(pack, random: Random(91));
      expect(game.inClass, isTrue);
      final lesson = game.hand().first;
      expect(lesson.actionType, 'lesson');
      expect(game.preview(lesson).hpCost, 9);
    });

    test('an E-tier textbook is worth +15, as the Books panel shows', () {
      final game = Game.newRun(pack, random: Random(82));
      _leaveClass(game);
      final study = pack.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'study',
      );
      // Rank "1" is the E tier; Korean Textbook is power 5.
      final book = pack.booksFor('korean').firstWhere((b) => b.bookRank == '1');
      expect(book.power, 5);
      expect(game.preview(study, book: book).gain, 15);
    });

    test('a sleep block restores a small amount, more at sleep locations', () {
      final game = Game.newRun(pack, random: Random(83));
      _leaveClass(game);

      final atSchool = game.preview(
        pack.locations[1000]!.actions.firstWhere(
          (a) => a.actionType == 'sleep',
        ),
      );
      expect(atSchool.gain, 10);

      game.move(2000); // Home, type "sleep"
      final atHome = game.preview(
        pack.locations[2000]!.actions.firstWhere(
          (a) => a.actionType == 'sleep',
        ),
      );
      expect(atHome.gain, greaterThan(atSchool.gain!));
    });

    test('stamina runs out well before the 14 action slots', () {
      // The reference run is at 6% stamina with 6 slots left, so a day
      // cannot be spent entirely on paid actions.
      final game = Game.newRun(pack, random: Random(84));
      _leaveClass(game);
      var spent = 0;
      while (game.state.hp > 0 && spent < 14) {
        final study = game.availableActions().firstWhere(
          (a) => a.actionType == 'study',
        );
        game.act(study, book: pack.books.values.first);
        spent++;
        if (game.state.date.tick == 0) break; // day rolled over
      }
      expect(
        spent,
        lessThan(14),
        reason: 'stamina should bite before the slots run out',
      );
    });
  });

  group('action previews', () {
    test('a study card promises what tapping it delivers', () {
      final game = Game.newRun(pack, random: Random(3));
      _leaveClass(game);
      final action = game.availableActions().firstWhere(
        (a) => a.actionType == 'study',
      );
      final book = pack.books.values.firstWhere((b) => b.subject == 'math');

      final preview = game.preview(action, book: book);
      final before = game.state.stats['math']!;
      final hpBefore = game.state.hp;

      game.act(action, book: book);

      expect(game.state.stats['math']! - before, preview.gain);
      expect(hpBefore - game.state.hp, preview.hpCost);
      expect(preview.subject, 'math');
      // Cards show the tier letter, not the raw rank the data ships.
      expect(preview.rank, book.tier);
      expect(book.tier, 'E', reason: 'rank "1" is the E tier');
    });

    test('a part-time card promises the pay it delivers', () {
      final game = Game.newRun(pack, random: Random(4));
      _leaveClass(game);
      final cafe = pack.locations[16004]!;
      game.state.unlockedLocations.add(cafe.id);
      game.move(cafe.id);
      final action = game.availableActions().firstWhere(
        (a) => a.actionType == 'partTimeJob',
      );

      final preview = game.preview(action);
      final before = game.state.money;
      game.act(action);

      expect(game.state.money - before, preview.money);
      expect(preview.kind, ActionKind.partTimeJob);
      // The label comes from the pack's per-location job names.
      expect(preview.title, isNotEmpty);
    });
  });

  group('full runs', () {
    /// Plays a whole run with a fixed seed, auto-advancing every event and
    /// always taking the first choice.
    ({int ticks, int events, Game game}) simulate(
      int seed, {
      int tickBudget = 4000,
    }) {
      final game = Game.newRun(pack, random: Random(seed));
      var ticks = 0;
      var eventsSeen = 0;

      while (!game.state.finished && ticks < tickBudget) {
        ticks++;
        final actions = game.hand();
        if (actions.isEmpty && game.examEnabled && game.isExamDay) {
          // Exam day: the Graduation Exam, the CSAT, the best realistic
          // applications, then the endings until one closes the run.
          void finish(EventRun run) {
            eventsSeen++;
            var beats = 0;
            while (run.current != null && !run.current!.isEnd) {
              if (++beats > 5000) fail('event ${run.event.id} did not end');
              final beat = run.current!;
              beat.choices.isNotEmpty
                  ? run.choose(beat.choices.first)
                  : run.advance();
            }
          }

          final opening = game.beginDay();
          if (opening != null) finish(opening);
          game.takeCsat();
          final admitted = game.submitApplications([
            for (final d in game.departmentsByCutoff())
              if (game.canApply(d) && game.admissionChance(d) >= .5) d.id,
          ]);
          game.enroll(admitted.firstOrNull);
          for (
            var run = game.nextEndingEvent();
            run != null;
            run = game.nextEndingEvent()
          ) {
            finish(run);
          }
          game.concludeRun();
          break;
        }
        if (actions.isEmpty) {
          // Nowhere to act: move somewhere that has actions, else stop.
          final elsewhere = game
              .availableLocations()
              .where((l) => l.id != game.state.locationId)
              .toList();
          if (elsewhere.isEmpty) break;
          game.move(elsewhere[game.state.random.nextInt(elsewhere.length)].id);
          continue;
        }

        final action = actions[game.state.random.nextInt(actions.length)];
        final book = action.actionType == 'study'
            ? (pack.books.values.toList()..shuffle(game.state.random)).first
            : null;
        final outcome = game.act(action, book: book);

        var run = outcome.event;
        while (run != null) {
          eventsSeen++;
          var beats = 0;
          while (run.current != null && !run.current!.isEnd) {
            if (++beats > 5000) {
              fail('event ${run.event.id} did not terminate');
            }
            final beat = run.current!;
            if (beat.choices.isNotEmpty) {
              run.choose(beat.choices.first);
            } else {
              run.advance();
            }
          }
          run = null;
        }
      }

      return (ticks: ticks, events: eventsSeen, game: game);
    }

    test('a run reaches exam day without hanging', () {
      final r = simulate(1);
      expect(
        r.game.state.finished,
        isTrue,
        reason:
            'run stalled after ${r.ticks} ticks on '
            'day ${r.game.state.dayNumber}',
      );
      expect(r.ticks, lessThan(4000));
    });

    test('200 seeded runs all terminate, and report engine gaps', () {
      final unknownFuncs = <String>{};
      final unknownTargets = <String>{};
      var totalEvents = 0;
      final eventIds = <int>{};

      for (var seed = 0; seed < 200; seed++) {
        final r = simulate(seed);
        expect(
          r.game.state.finished,
          isTrue,
          reason: 'seed $seed stalled on day ${r.game.state.dayNumber}',
        );
        totalEvents += r.events;
        eventIds.addAll(r.game.state.eventCounts.keys);
        unknownFuncs.addAll(r.game.gaps['funcCodes']!);
        unknownTargets.addAll(r.game.gaps['conditionTargets']!);
      }

      // Not an assertion -- a report. These are the verbs still to implement.
      // ignore: avoid_print
      print(
        '200 runs: $totalEvents events fired, '
        '${eventIds.length}/${pack.events.length} distinct events reached',
      );
      if (unknownFuncs.isNotEmpty) {
        // ignore: avoid_print
        print('unhandled funcCodes: ${unknownFuncs.toList()..sort()}');
      }
      if (unknownTargets.isNotEmpty) {
        // ignore: avoid_print
        print(
          'unhandled condition targets: ${unknownTargets.toList()..sort()}',
        );
      }

      expect(
        unknownTargets,
        isEmpty,
        reason: 'condition targets with no handler silently evaluate false',
      );
    });

    test('stats, stamina and money stay inside their bounds', () {
      final r = simulate(42);
      final s = r.game.state;
      expect(s.hp, greaterThanOrEqualTo(pack.rules.hpMin));
      expect(s.hp, lessThanOrEqualTo(s.hpMax));
      expect(s.money, greaterThanOrEqualTo(pack.rules.moneyMin));
      for (final v in s.stats.values) {
        expect(v, greaterThanOrEqualTo(0));
      }
    });

    test('a run round-trips through save and load', () {
      final game = Game.newRun(pack, random: Random(7));
      for (var i = 0; i < 20; i++) {
        final actions = game.hand();
        if (actions.isEmpty) break;
        game.act(
          actions.first,
          book: actions.first.actionType == 'study'
              ? pack.books.values.first
              : null,
        );
      }
      final restored = GameState.fromJson(pack, game.state.toJson());
      expect(restored.date, game.state.date);
      expect(restored.stats, game.state.stats);
      expect(restored.hp, game.state.hp);
      expect(restored.money, game.state.money);
      expect(restored.switches.length, game.state.switches.length);
      expect(restored.unlockedLocations, game.state.unlockedLocations);
    });
  });
}
