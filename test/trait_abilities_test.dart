/// Trait abilities owned by the KSS pack data (`content/kss/mechanics.json`
/// `traitAbilities` + `hooks`), for traits that ship no `effectList`, and
/// the traits whose behavior the imported event graphs already deliver.
/// Rates/amounts not stated by the catalog are provisional pack defaults;
/// docs/EFFECTS-REFERENCE.md says which. Every roll is seeded.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/goals.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';

import 'support/kss_ids.dart';

late ContentPack kss16;
late ContentPack kss20;

/// A run out of class at [location] on tick [tick], holding [ids].
Game withTraits(
  ContentPack pack,
  List<int> ids, {
  int tick = 7,
  int? location,
  int seed = 8,
}) {
  final game = Game.newRun(pack, random: Random(seed));
  game.state.openingComplete = true;
  game.state.date = GameDate(game.state.date.day, tick);
  game.state.locationId = location ?? 16005;
  game.state.unlockedLocations.add(game.state.locationId);
  for (final id in ids) {
    expect(game.state.grantTrait(id), isTrue, reason: 'trait $id refused');
  }
  game.invalidateHand();
  return game;
}

LocationAction actionOf(Game game, String type) =>
    game.state.location!.actions.firstWhere((a) => a.actionType == type);

/// Every action tick of [days] days from the run's start.
Iterable<GameDate> ticks(ContentPack pack, {int days = 30}) sync* {
  for (var d = 0; d < days; d++) {
    final day = GameDate.addDays(pack.manifest.startDate.day, d);
    for (var t = 6; t < 14; t++) {
      yield GameDate(day, t);
    }
  }
}

/// Acquires [id] the way event content does (Salt and Light can see it).
void acquire(Game game, int id) => game.effects.applyChanger({
  'funcCode': 'ACQUIRE_TRAIT',
  'args': [id],
}, game.state);

/// A global (story-free), permanent trait of [type] the guard tests can use.
int traitOf(ContentPack pack, String type, {Set<int> except = const {}}) => pack
    .traits
    .values
    .firstWhere(
      (t) =>
          t.type == type &&
          t.storyId == null &&
          t.lifeTimeDays == null &&
          !except.contains(t.id) &&
          (pack.mechanics.section('traitAbilities')['${t.id}'] == null),
    )
    .id;

Future<void> main() async {
  setUpAll(() async {
    kss16 = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    kss20 = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  group('Master of Notes 8 (T01)', () {
    /// A study block on a book one read short of finished.
    (Game, GameBook, LocationAction) nearlyRead(List<int> traits) {
      final game = withTraits(kss16, traits);
      final book = game.studiableBooks().firstWhere((b) => b.doneCount > 1);
      game.state.bookReadCounts[book.id] = book.doneCount - 1;
      return (game, book, actionOf(game, 'study'));
    }

    test('finishing a book hands over one Weird Workbook with a receipt', () {
      final (game, book, study) = nearlyRead([KssIds.masterOfNotes]);
      expect(game.state.itemCount(KssIds.weirdWorkbook), 0);
      final outcome = game.act(study, book: book);
      expect(game.isBookComplete(book), isTrue);
      expect(game.state.itemCount(KssIds.weirdWorkbook), 1);
      // The host shows it in the acquisition popup (Use / Confirm, F21).
      expect(outcome.acquiredItems, {KssIds.weirdWorkbook: 1});
      expect(outcome.summary, contains('Finished ${book.name}.'));

      // Re-reading the finished book is not finishing it again.
      game.state.date = GameDate(game.state.date.day, 7);
      game.state.hp = game.state.hpMax;
      final again = game.act(study, book: book);
      expect(game.state.itemCount(KssIds.weirdWorkbook), 1);
      expect(again.acquiredItems, isEmpty);
    });

    test('the workbook is the ordinary +90 consumable, usable at once', () {
      final (game, book, study) = nearlyRead([KssIds.masterOfNotes]);
      game.act(study, book: book);
      final before = game.state.totalStat;
      expect(game.useItem(KssIds.weirdWorkbook), isTrue);
      expect(game.state.totalStat - before, 90);
      expect(game.state.itemCount(KssIds.weirdWorkbook), 0);
    });

    test('without the trait a finished book gives nothing', () {
      final (game, book, study) = nearlyRead(const []);
      final outcome = game.act(study, book: book);
      expect(game.isBookComplete(book), isTrue);
      expect(game.state.itemCount(KssIds.weirdWorkbook), 0);
      expect(outcome.acquiredItems, isEmpty);
    });

    test('no completion gacha is implemented beside it (TODO 39)', () {
      final (game, book, study) = nearlyRead([KssIds.masterOfNotes]);
      final before = Map<int, int>.of(game.state.inventory);
      game.act(study, book: book);
      final gained = {
        for (final e in game.state.inventory.entries)
          if (e.value > (before[e.key] ?? 0)) e.key: e.value,
      };
      expect(gained.keys, [KssIds.weirdWorkbook]);
    });
  });

  group('Bully 44 (T12)', () {
    test('pays 200 Gold on about one completed block in ten', () {
      final game = withTraits(kss16, [KssIds.bully]);
      var paid = 0, total = 0;
      for (final when in ticks(kss16)) {
        game.state.date = when;
        final before = game.state.money;
        game.runHook('actionCompleted', ['study']);
        final gain = game.state.money - before;
        expect(gain, anyOf(0, 200));
        if (gain == 200) paid++;
        total++;
      }
      // Provisional configurable default: 10% (rules.traits.chances.44).
      expect(paid / total, inInclusiveRange(0.05, 0.16));
    });

    test('a lucky block pays during act and says so; preview never rolls', () {
      final probe = withTraits(kss16, [KssIds.bully]);
      final lucky = ticks(kss16).firstWhere((when) {
        probe.state.date = when;
        final before = probe.state.money;
        probe.runHook('actionCompleted', ['study']);
        return probe.state.money > before;
      });
      final game = withTraits(kss16, [KssIds.bully]);
      game.state.date = lucky;
      final study = actionOf(game, 'study');
      final money = game.state.money;
      game.preview(study);
      expect(game.state.money, money, reason: 'preview is read-only');
      final outcome = game.act(study, book: game.bookForSlot(0));
      expect(outcome.reports, contains('Bully: +200 Gold.'));
      expect(game.state.money, greaterThanOrEqualTo(money + 200));
    });

    test('the roll is seeded: the same tick lands the same way twice', () {
      for (final when in ticks(kss16).take(60)) {
        final results = [
          for (var i = 0; i < 2; i++)
            (() {
              final g = withTraits(kss16, [KssIds.bully], seed: i);
              g.state.date = when;
              g.runHook('actionCompleted', ['study']);
              return g.state.money;
            })(),
        ];
        expect(results.toSet(), hasLength(1));
      }
    });

    test('no trait, no Gold', () {
      final game = withTraits(kss16, const []);
      for (final when in ticks(kss16).take(100)) {
        game.state.date = when;
        game.runHook('actionCompleted', ['study']);
      }
      expect(game.state.money, 0);
    });
  });

  group('Talented Singer 201 and Brilliant Microphone 90008 (T14)', () {
    int singingCount(List<int> traits, {bool microphone = false}) {
      final game = withTraits(kss20, traits, location: 20002);
      if (microphone) game.state.addItem(KssIds.brilliantMicrophone);
      final practice = game.state.location!.actions.firstWhere(
        (a) => a.funcCode == 'DO_KARAOKE',
      );
      final before = game.state.switchValue('SING_COUNT');
      game.act(practice);
      return game.state.switchValue('SING_COUNT') - before;
    }

    test('Singing Practice: 1, x2 with the microphone, +1 for the trait', () {
      expect(singingCount(const []), 1);
      expect(singingCount(const [], microphone: true), 2);
      expect(singingCount([KssIds.talentedSinger]), 2);
      expect(singingCount([KssIds.talentedSinger], microphone: true), 3);
    });

    test('the trait is scoped to the Karaoke (20002)', () {
      final game = withTraits(kss20, [KssIds.talentedSinger], location: 1000);
      final before = game.state.switchValue('SING_COUNT');
      game.effects.applyChanger({'funcCode': 'DO_KARAOKE'}, game.state);
      expect(game.state.switchValue('SING_COUNT') - before, 1);
    });
  });

  group('Exam Dreams 206 (T15)', () {
    test('each Sleep adds +45 to one random subject and says which', () {
      final game = withTraits(kss20, [KssIds.examDreams], location: 1000);
      final hit = <String>{};
      for (var n = 0; n < 40; n++) {
        final before = Map<String, num>.of(game.state.stats);
        game.runHook('sleep');
        final changed = [
          for (final s in kss20.manifest.subjects)
            if (game.state.stats[s] != before[s]) s,
        ];
        expect(changed, hasLength(1));
        expect(game.state.stats[changed.single]! - before[changed.single]!, 45);
        hit.add(changed.single);
      }
      expect(hit.length, greaterThan(2), reason: 'the subject is random');
    });

    test('the Sleep block pays it on act and reports it', () {
      final game = withTraits(kss20, [KssIds.examDreams], location: 1000);
      final sleep = actionOf(game, 'sleep');
      final stats = game.state.totalStat;
      expect(game.preview(sleep).gain, greaterThan(0));
      expect(game.state.totalStat, stats, reason: 'preview is read-only');
      final outcome = game.act(sleep);
      expect(outcome.reports.where((r) => r.startsWith('Exam Dreams: ')), [
        isA<String>(),
      ]);
      expect(game.state.totalStat - stats, greaterThanOrEqualTo(45));
    });

    test('without the trait Sleep pays no stats', () {
      final game = withTraits(kss20, const [], location: 1000);
      final stats = game.state.totalStat;
      game.runHook('sleep');
      expect(game.state.totalStat, stats);
    });
  });

  group('Professional Latecomer 9', () {
    test('loses 10 stamina on about 30% of school arrivals', () {
      final game = withTraits(kss16, [KssIds.professionalLatecomer]);
      var lost = 0, total = 0;
      for (var d = 0; d < 300; d++) {
        game.state.date = GameDate(
          GameDate.addDays(kss16.manifest.startDate.day, d),
          0,
        );
        game.state.hp = 100;
        game.runHook('arriveAtSchool');
        expect(game.state.hp, anyOf(100, 90));
        if (game.state.hp == 90) lost++;
        total++;
      }
      expect(lost / total, inInclusiveRange(0.22, 0.38));
    });

    test('the morning walk to school applies it on a weekday rollover', () {
      // Find a weekday whose arrival roll loses stamina, then roll into it.
      final probe = withTraits(kss16, [KssIds.professionalLatecomer]);
      final start = kss16.manifest.startDate.day;
      final day = List.generate(20, (d) => GameDate.addDays(start, d + 1))
          .firstWhere((day) {
            if (day.weekday > DateTime.friday) return false;
            probe.state.date = GameDate(day, 0);
            probe.state.hp = 100;
            probe.runHook('arriveAtSchool');
            return probe.state.hp < 100;
          });
      final game = withTraits(kss16, [KssIds.professionalLatecomer]);
      game.state.date = GameDate(GameDate.addDays(day, -1), 13);
      game.state.dayEndPending = true;
      final outcome = game.finishPendingDay();
      expect(game.state.date.day, day);
      expect(game.state.locationId, 1000);
      expect(game.state.hp, game.state.hpMax - 10);
      expect(outcome.reports, contains('Professional Latecomer: -10 stamina.'));
    });

    test('disappears after five days without fainting; fainting resets', () {
      final game = withTraits(kss16, [KssIds.professionalLatecomer]);
      void morning() {
        game.state.date = game.state.date.nextDay();
        game.runHook('dayStarted');
      }

      for (var d = 0; d < 4; d++) {
        morning();
      }
      expect(game.state.traits, contains(KssIds.professionalLatecomer));
      game.runHook('exhausted'); // fainted on day four
      for (var d = 0; d < 4; d++) {
        morning();
      }
      expect(game.state.traits, contains(KssIds.professionalLatecomer));
      morning();
      expect(game.state.traits, isNot(contains(KssIds.professionalLatecomer)));
      expect(game.state.switchValue('LATECOMER_CLEAN_DAYS'), 0);
    });

    test('a real collapse resets the count', () {
      final game = withTraits(kss16, [KssIds.professionalLatecomer]);
      game.state.setSwitch('LATECOMER_CLEAN_DAYS', 3);
      game.state.hp = 1;
      game.act(actionOf(game, 'study'), book: game.bookForSlot(0));
      expect(game.state.switchValue('LATECOMER_CLEAN_DAYS'), lessThan(3));
    });
  });

  group('Salt and Light 48', () {
    test('turns away the next negative trait, once, and is used up', () {
      final bad = traitOf(kss16, 'bad');
      final bad2 = traitOf(kss16, 'bad', except: {bad});
      final good = traitOf(kss16, 'good');
      final game = withTraits(kss16, [KssIds.saltAndLight]);
      acquire(game, good);
      expect(game.state.traits, contains(good));
      expect(game.state.traits, contains(KssIds.saltAndLight));
      acquire(game, bad);
      expect(game.state.traits, isNot(contains(bad)));
      expect(game.state.traits, isNot(contains(KssIds.saltAndLight)));
      expect(game.takeItemReports().single, contains('blocked'));
      acquire(game, bad2);
      expect(game.state.traits, contains(bad2));
    });

    test('setup/dev grants are not "obtained" and pass straight through', () {
      final bad = traitOf(kss16, 'bad');
      final game = withTraits(kss16, [KssIds.saltAndLight]);
      expect(game.state.grantTrait(bad), isTrue);
      expect(game.state.traits, contains(KssIds.saltAndLight));
    });
  });

  group('Stocks Manager 54', () {
    test('a positive next trait pays, a negative one costs; then it ends', () {
      final good = traitOf(kss16, 'good');
      final bad = traitOf(kss16, 'bad');
      final up = withTraits(kss16, [KssIds.stocksManager]);
      up.state.money = 5000;
      acquire(up, good);
      expect(up.state.money, 6000);
      expect(up.state.traits, isNot(contains(KssIds.stocksManager)));
      acquire(up, bad);
      expect(up.state.money, 6000, reason: 'only the next trait counts');

      final down = withTraits(kss16, [KssIds.stocksManager]);
      down.state.money = 5000;
      acquire(down, bad);
      expect(down.state.money, 4000);
      expect(down.state.traits, isNot(contains(KssIds.stocksManager)));
    });

    test('a trait that is not actually obtained settles nothing', () {
      // Exam Dreams belongs to story 20, so story 16 refuses it; a trait
      // already held is not obtained again either.
      final game = withTraits(kss16, [KssIds.stocksManager, KssIds.bully]);
      game.state.money = 5000;
      acquire(game, KssIds.examDreams);
      acquire(game, KssIds.bully);
      expect(game.state.money, 5000);
      expect(game.state.traits, contains(KssIds.stocksManager));
    });

    test('Salt and Light blocks first, so a blocked trait is no trade', () {
      final bad = traitOf(kss16, 'bad');
      final game = withTraits(kss16, [
        KssIds.saltAndLight,
        KssIds.stocksManager,
      ]);
      game.state.money = 5000;
      acquire(game, bad);
      expect(game.state.money, 5000);
      expect(game.state.traits, contains(KssIds.stocksManager));
    });
  });

  test('Scrooge 53: Store items of 3000 Gold or less cost 100', () {
    final game = withTraits(kss16, [KssIds.scrooge]);
    final plain = withTraits(kss16, const []);
    for (final id in kss16.shop.keys) {
      final listed = kss16.shop[id]!['price'] as num;
      expect(game.priceOf(id), listed <= 3000 ? 100 : plain.priceOf(id));
    }
    game.state.money = 1000;
    expect(game.purchase(8), isNull); // Weird Workbook, listed 1500
    expect(game.state.money, 900);
  });

  group('Lactose Intolerant 70', () {
    test('milk-tagged food cannot be used; other items can', () {
      final game = withTraits(kss16, [KssIds.lactoseIntolerant]);
      game.state.hp = 10;
      game.state.addItem(9); // White Milk
      expect(game.useItem(9), isFalse);
      expect(game.state.itemCount(9), 1);
      expect(game.state.hp, 10);
      expect(game.takeItemReports().single, contains('White Milk'));
      game.state.addItem(1); // Coffee
      expect(game.useItem(1), isTrue);
    });

    test('Lactase Pills 31 cure it, and milk is usable again', () {
      expect(kss16.items[31]!.effects.single, {
        'type': 'cureTrait',
        'trait': 'Lactose Intolerant',
      });
      final game = withTraits(kss16, [KssIds.lactoseIntolerant]);
      game.state.addItem(31);
      expect(game.useItem(31), isTrue);
      expect(game.state.traits, isNot(contains(KssIds.lactoseIntolerant)));
      game.state.addItem(9);
      expect(game.useItem(9), isTrue);
    });
  });

  test('Sunstroke 100 (+5) and Heat Stroke 102 (+100) for their days', () {
    final plain = withTraits(kss16, const []);
    final base = plain.preview(actionOf(plain, 'study')).hpCost;
    for (final (id, extra, days) in [
      (KssIds.sunstroke, 5, 5),
      (KssIds.heatStroke, 100, 3),
    ]) {
      final game = withTraits(kss16, [id]);
      final study = actionOf(game, 'study');
      for (var d = 0; d < days; d++) {
        expect(game.preview(study).hpCost, base + extra, reason: 'day $d');
        game.state.expireTraitsForNewDay();
      }
      expect(game.preview(study).hpCost, base, reason: 'cured');
    }
    // The card's number is the block's number.
    final game = withTraits(kss16, [KssIds.sunstroke]);
    game.act(actionOf(game, 'study'), book: game.bookForSlot(0));
    expect(game.state.hp, game.state.hpMax - (base + 5));
  });

  test("Customer's Lover/Curse 160004/160005 open the date and curse", () {
    for (final (id, gate) in [
      (KssIds.customersLover, 'SON_NIM_LOVE'),
      (KssIds.customersCurse, 'SON_NIM_COURSE'),
    ]) {
      final game = withTraits(kss16, const []);
      expect(game.state.switchValue(gate), 0);
      acquire(game, id);
      expect(game.state.switchValue(gate), 1);
      // Kept on while the trait is held.
      game.state.setSwitch(gate, 0);
      game.runHook('dayStarted');
      expect(game.state.switchValue(gate), 1);
      // The only readers are the Customer Date (90) / Curse (96) gates.
      final readers = kss16.events.values.where(
        (e) => jsonEncode(e.conditionSet).contains('"$gate"'),
      );
      expect(readers.map((e) => e.id), [id == 160004 ? 90 : 96]);
    }
  });

  group('MBTI J. Judger 38', () {
    test('a mid-week grant leaves the posted goal; next week gets +10%', () {
      final game = withTraits(kss16, const []);
      final posted = game.state.weeklyGoal!;
      final plainNext = Goals.issue(game.state).rewardValue;
      expect(game.state.grantTrait(KssIds.judger), isTrue);
      expect(Goals.rewardAmount(posted, game.state), posted.rewardValue);
      final next = Goals.issue(game.state).rewardValue;
      expect(next, closeTo(plainNext * 1.1, 1));
    });

    test('the factor survives a save as part of the posted goal', () {
      final game = withTraits(kss16, [KssIds.judger]);
      game.state.weeklyGoal = Goals.issue(game.state);
      final reward = game.state.weeklyGoal!.rewardValue;
      final loaded = GameState.fromJson(kss16, game.state.toJson());
      loaded.removeTrait(KssIds.judger);
      expect(Goals.rewardAmount(loaded.weeklyGoal!, loaded), reward);
    });
  });

  group('delivered by the event graphs (no ability added)', () {
    /// Nodes gated on holding [trait], with what each one pays.
    List<List<dynamic>> gated(ContentPack pack, int trait) => [
      for (final n in pack.nodes.values)
        if (jsonEncode(n.conditionSet).contains('"FUNC_TRAIT_HAVE"') &&
            jsonEncode(n.conditionSet).contains('[$trait]'))
          [n.changer?['funcCode'], n.changer?['args']],
    ];

    for (final (id, name, amount, count) in [
      (KssIds.jailbreaker, 'Jailbreaker', 40, 2),
      (KssIds.delinquent, 'Delinquent', 20, 1),
      (KssIds.cookingMaster, 'Cooking Master', 50, 4),
    ]) {
      test('$name $id: All stats +$amount in both scripts', () {
        for (final pack in [
          kss20.forPlayer(isMale: true),
          kss20.forPlayer(isMale: false),
        ]) {
          expect(gated(pack, id), [
            for (var i = 0; i < count; i++)
              [
                'INCREASE_STAT_ALL',
                [amount],
              ],
          ]);
          expect(kss16.mechanics.section('traitAbilities')['$id'], isNull);
        }
      });
    }

    test('Favourite Student 160012 is granted with the training switch', () {
      for (final grant in [181023, 181069]) {
        final node = kss16.nodes[grant]!;
        expect(node.changer?['funcCode'], 'ACQUIRE_TRAIT');
        expect(node.changer?['args'], [KssIds.favouriteStudent]);
        final next = kss16.nodes[node.nextNodeId]!;
        expect(jsonEncode(next.changer), contains('"COOK_ON"'));
      }
      expect(jsonEncode(kss16.events[182]!.conditionSet), contains('COOK_ON'));
    });

    test('Lower Student 200010 is a marker no condition reads', () {
      final readers = kss20.nodes.values.where(
        (n) => jsonEncode(n.conditionSet).contains('${KssIds.lowerStudent}'),
      );
      expect(readers, isEmpty);
      expect(
        kss20.nodes.values.where(
          (n) =>
              n.changer?['funcCode'] == 'REMOVE_TRAIT' &&
              (n.changer?['args'] as List?)?.first == KssIds.lowerStudent,
        ),
        isNotEmpty,
      );
    });
  });
}
