import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/pack_mechanics.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

/// Item effects, 2026-10-25 (docs/EFFECTS-REFERENCE.md): prevention items
/// read by their event graphs, checking tools (Mock Exam Paper, Bizarre
/// Author's Note, Recipe, Scouter) and items that must not be used up for
/// nothing.
void main() {
  late ContentPack original;
  late ContentPack retry;
  late Map<int, Map<String, dynamic>> retryNodes;
  late Map<int, Set<int>> grantedBy16;
  late Map<String, Map<int, Map>> rawItems;

  setUpAll(() async {
    original = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    Map<String, dynamic> graph(String story) =>
        jsonDecode(File('packs/$story/events/events.json').readAsStringSync())
            as Map<String, dynamic>;
    retryNodes = {
      for (final n in (graph('kss20')['nodes'] as List).cast<Map>())
        (n['id'] as num).toInt(): n.cast<String, dynamic>(),
    };
    rawItems = {
      for (final story in ['kss16', 'kss20'])
        story: {
          for (final i
              in ((jsonDecode(
                        File('packs/$story/items.json').readAsStringSync(),
                      ) as Map)['items']
                      as List)
                  .cast<Map>())
            (i['id'] as num).toInt(): i,
        },
    };
    // Item id -> events whose node changers grant it, in story 16's graph.
    grantedBy16 = {};
    for (final n in (graph('kss16')['nodes'] as List).cast<Map>()) {
      final c = n['changer'];
      if (c is! Map) continue;
      if (c['funcCode'] != 'ACQUIRE_ITEM' &&
          c['funcCode'] != 'ACQUIRE_ITEM_RANDOM') {
        continue;
      }
      for (final a in (c['args'] as List? ?? const []).whereType<num>()) {
        grantedBy16
            .putIfAbsent(a.toInt(), () => {})
            .add((n['id'] as num).toInt() ~/ 1000);
      }
    }
  });

  /// Plays [eventId] to its end, choosing the first option, and returns
  /// every line shown. [during] runs after each beat (to use an item).
  List<String> play(
    Game game,
    int eventId, {
    void Function(EventRun run)? during,
  }) {
    final run = game.events.begin(game.pack.events[eventId]!, game.state);
    final lines = <String>[];
    for (var steps = 0; steps < 3000; steps++) {
      final beat = run.current;
      if (beat == null) return lines;
      lines.add(beat.text);
      during?.call(run);
      if (beat.isEnd) return lines;
      beat.choices.isEmpty ? run.advance() : run.choose(beat.choices.first);
    }
    fail('event $eventId did not finish');
  }

  ({num hp, num money, num stats, bool locked}) snapshot(Game game) => (
    hp: game.state.hp,
    money: game.state.money,
    stats: game.state.totalStat,
    locked: !game.state.unlockedLocations.containsAll(game.pack.locations.keys),
  );

  Game fresh(ContentPack pack) {
    final game = Game.newRun(pack, random: Random(5));
    game.state.openingComplete = true;
    game.state.hp = 50;
    game.state.money = 20000;
    game.state.unlockedLocations.addAll(pack.locations.keys);
    return game;
  }

  group('prevention items are read by their event graphs', () {
    const items = {
      16: [30003, 30004, 30008, 30010, 30012],
      20: [90020, 90002, 90005],
    };
    for (final MapEntry(key: story, value: ids) in items.entries) {
      for (final id in ids) {
        test(
          '$story/$id: holding it spares the penalty and is not used up',
          () {
            final pack = story == 16 ? original : retry;
            final item = pack.items[id]!;
            final prevent = item.effects.singleWhere(
              (e) => e['type'] == 'preventEvent',
            );
            expect(prevent['handledBy'], 'eventGraph');
            final events = (prevent['events'] as List).cast<int>();
            expect(events, isNotEmpty);
            expect(item.canUse, isFalse, reason: 'a held passive, not a use');
            for (final eventId in events) {
              final without = fresh(pack);
              final before = snapshot(without);
              play(without, eventId);
              final lost = snapshot(without);
              expect(
                lost.hp < before.hp ||
                    lost.money < before.money ||
                    lost.stats < before.stats ||
                    lost.locked,
                isTrue,
                reason: 'event $eventId without item $id has a penalty',
              );

              final holding = fresh(pack)..state.addItem(id);
              final start = snapshot(holding);
              play(holding, eventId);
              final kept = snapshot(holding);
              expect(kept.hp, greaterThanOrEqualTo(start.hp));
              expect(kept.money, greaterThanOrEqualTo(start.money));
              expect(kept.stats, greaterThanOrEqualTo(start.stats));
              expect(kept.locked, isFalse);
              expect(holding.state.itemCount(id), 1, reason: 'not consumed');
            }
          },
        );
      }
    }
  });

  test('graph-handled items name the events that read them', () {
    // Art of Bargaining halves the Fishy Vendor's price (4000 vs 8000).
    expect(rawItems['kss16']![30011]!['graphEvents'], [18, 207, 208]);
    final cheap = fresh(original)..state.addItem(30011);
    play(cheap, 18);
    expect(cheap.state.money, 20000 - 4000);
    final dear = fresh(original);
    play(dear, 18);
    expect(dear.state.money, 20000 - 8000);
    // Key opens New Location! (22); the comic volume gates Reading (52).
    expect(rawItems['kss20']![90001]!['graphEvents'], containsAll([21, 22]));
    expect(rawItems['kss20']![90003]!['graphEvents'], containsAll([21, 52]));
    // Medicine for Mother is handed over inside the event that grants it.
    final medicine = fresh(retry);
    play(medicine, 106);
    expect(medicine.state.itemCount(90004), 0);
  });

  test("story 16's Korean-only items cannot be obtained or wasted", () {
    // Their consumers (Mineral Appraisal, Upgrade Cookie, the letter and
    // Magic Show events) exist only in the Korean 1.61.0 graph; the
    // imported 1.27.4 graph grants none of them.
    const ids = [
      20202, 20203, 20204, 20205, 20206, 20212, 20215, 20218, 20236, //
      30013, 30014, 30202, 30203, 30206, 30209, 30210,
    ];
    for (final id in ids) {
      expect(grantedBy16[id], isNull, reason: '$id is granted somewhere');
      final item = original.items[id]!;
      expect(item.canUse, isFalse, reason: '$id has nothing to apply');
      final game = fresh(original)..state.addItem(id);
      expect(game.useItem(id), isFalse);
      expect(game.state.itemCount(id), 1);
    }
    // The Museum Ticket and Bouquet are granted, as tokens.
    expect(grantedBy16[30001], contains(29));
    expect(grantedBy16[30002], contains(89));
    expect(original.items[30001]!.canUse, isFalse);
  });

  group('Mock Exam Paper', () {
    test('forecasts the CSAT without sitting it or drawing', () {
      final a = fresh(original), b = fresh(original);
      for (final g in [a, b]) {
        g.state.stats.updateAll((k, v) => 3000);
        g.state.stats['math'] = 9000;
        g.state.addItem(30);
      }
      expect(original.items[30]!.canUse, isTrue);
      expect(a.useItem(30), isTrue);
      final outcome = a.takeItemOutcome();
      expect(outcome.views.single['action'], 'predictedGrades');
      expect(a.state.itemCount(30), 0, reason: 'consumed (no self re-add)');
      expect(a.state.csat, isNull);
      // Same draws afterwards as a run that never looked.
      expect(a.state.random.nextInt(1 << 30), b.state.random.nextInt(1 << 30));
      final forecast = Game.forecastCsat(a.state);
      final sat = a.takeCsat();
      expect(forecast.standardScore, sat.standardScore);
      expect(forecast.subjectScores, sat.subjectScores);
      expect(forecast.grades, sat.grades);
      expect(forecast.grades['math']!, lessThan(forecast.grades['korean']!));
    });
  });

  test("Bizarre Author's Note is kept and opens the abilities view", () {
    final game = fresh(original)..state.addItem(20018);
    expect(game.useItem(20018), isTrue);
    expect(game.state.itemCount(20018), 1);
    final view = game.takeItemOutcome().views.single;
    expect(view['action'], 'checkAbilities');
    expect((view['progress'] as List).length, 5);
    // Checking again is still free.
    expect(game.useItem(20018), isTrue);
    expect(game.state.itemCount(20018), 1);
  });

  group('Recipe (I02)', () {
    test('lists exactly the Foodcraft graph recipes and is kept', () {
      // Every Foodcraft branch that checks three ingredients, mapped to the
      // potion its true path hands over.
      final fromGraph = <int, Set<int>>{};
      for (final n in retryNodes.values) {
        if (n['id'] ~/ 1000 != 120 || n['type'] != 'ifElse') continue;
        final conds =
            ((n['conditionSet'] as Map)['right'] as Map)['conditions'] as List;
        final inputs = {
          for (final c in conds.cast<Map>())
            if (c['target'] == 'FUNC_ITEM_COUNT')
              ((c['args'] as List).first as num).toInt(),
        };
        if (inputs.length != 3) continue;
        var id = (n['nextNodeIdIfTrue'] as num?)?.toInt();
        for (var i = 0; id != null && i < 30; i++) {
          final next = retryNodes[id]!;
          final c = next['changer'];
          if (c is Map && c['funcCode'] == 'ACQUIRE_ITEM') {
            fromGraph[((c['args'] as List).first as num).toInt()] = inputs;
            break;
          }
          id = (next['nextNodeId'] as num?)?.toInt();
        }
      }
      final view = retry.items[80011]!.effects.single;
      final authored = {
        for (final r in (view['recipes'] as List).cast<Map>())
          (r['output'] as num).toInt(): {
            for (final i in r['inputs'] as List) (i as num).toInt(),
          },
      };
      expect(authored, fromGraph);
      expect(authored.keys, {80012, 80013, 80014});

      final game = fresh(retry)..state.addItem(80011);
      expect(game.useItem(80011), isTrue);
      expect(game.state.itemCount(80011), 1, reason: 'kept reference');
      expect(game.takeItemOutcome().views.single['action'], 'recipes');
    });
  });

  test('Strawberry Milk: provisional +50, and event 210 reacts to it', () {
    final milk = retry.items[80041]!;
    expect(milk.canUse, isTrue);
    expect(milk.effects.single['provisional'], isTrue);
    final game = fresh(retry)..state.addItem(80041);
    expect(game.useItem(80041), isTrue);
    expect(game.state.hp, 100);
    expect(game.state.itemCount(80041), 0);

    // Drinking it when Nina hands it over takes the poisoned branch.
    final drank = fresh(retry);
    final lines = play(
      drank,
      210,
      during: (run) {
        if (drank.state.itemCount(80041) > 0) {
          Game.useItemWith(drank.state, run.effects, 80041);
        }
      },
    );
    expect(lines, contains('You drank that...?'));
    final kept = play(fresh(retry), 210);
    expect(kept, contains('Gimme that.'));
  });

  group('Scouter', () {
    Game scouting({int sw = 1, int count = 0, int target = 10}) {
      final game = fresh(retry)..state.addItem(90021);
      game.state.setSwitch('SING_SW', sw);
      game.state.setSwitch('SING_COUNT', count);
      game.state.setSwitch('SING_TARGET', target);
      return game;
    }

    String check(Game game) {
      expect(game.useItem(90021), isTrue);
      expect(game.state.itemCount(90021), 1, reason: 'kept');
      return game.takeItemOutcome().reports.single;
    }

    test('forecasts the drawn sing-off with the sing-off rule', () {
      expect(retry.items[90021]!.canUse, isTrue);
      final losing = scouting(count: 3);
      expect(check(losing), contains('you will lose'));
      expect(
        MechanicRuntime(losing.state)
            .condition({'predicate': 'FUNC_SING_TARGET'}),
        isFalse,
      );
      final winning = scouting(count: 12);
      expect(check(winning), contains('you will win'));
      expect(
        MechanicRuntime(winning.state)
            .condition({'predicate': 'FUNC_SING_TARGET'}),
        isTrue,
      );
      // Champion match: the last target stands once SING_POINT >= 15.
      final champion = scouting(sw: 3, count: 20)
        ..state.setSwitch('SING_POINT', 15);
      expect(check(champion), contains('you will win'));
      // Character 67's sing-off is a guaranteed win.
      final king = scouting(sw: 0)..state.characterId = 67;
      expect(check(king), contains('you will win'));
    });

    test('reports no forecast before a target is drawn, and draws nothing', () {
      final early = scouting(sw: 0);
      final control = scouting(sw: 0);
      expect(check(early), contains('no sing-off opponent'));
      expect(
        early.state.random.nextInt(1 << 30),
        control.state.random.nextInt(1 << 30),
      );
      final redraw = scouting(sw: 3)..state.setSwitch('SING_POINT', 6);
      expect(check(redraw), contains('no sing-off opponent'));
      final done = scouting()..state.setSwitch('SING_WIN', 1);
      expect(check(done), contains('no sing-off left'));
    });
  });

  test('items with nothing to apply are refused, not used up', () {
    final game = fresh(original)..state.addItem(20236);
    expect(game.useItem(20236), isFalse);
    expect(game.state.itemCount(20236), 1);
    // A held passive such as the Key is not usable either.
    final key = fresh(retry)..state.addItem(90001);
    expect(key.useItem(90001), isFalse);
    expect(key.state.itemCount(90001), 1);
    // Ordinary consumables are unaffected.
    final coffee = fresh(original)..state.addItem(1);
    expect(coffee.useItem(1), isTrue);
  });
}
