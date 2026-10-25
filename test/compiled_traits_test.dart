/// The compiled trait abilities (TODO 82/83): traits that ship no
/// `effectList` and whose rule the engine carries in code. Every roll is
/// seeded, so these are deterministic.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/traits.dart';

late ContentPack pack;

/// A run parked out of class at the Gym, holding [ids].
Game withTraits(List<int> ids, {int tick = 7, int seed = 51}) {
  final game = Game.newRun(pack, random: Random(seed));
  game.state.date = GameDate(game.state.date.day, tick);
  game.state.locationId = 16005;
  for (final id in ids) {
    expect(game.state.grantTrait(id), isTrue, reason: 'trait $id refused');
  }
  game.invalidateHand();
  return game;
}

LocationAction actionOf(Game game, String type) =>
    game.state.location!.actions.firstWhere((a) => a.actionType == type);

/// Every action tick of the 30 days from the run's start.
Iterable<GameDate> ticks(Game game) sync* {
  for (var d = 0; d < 30; d++) {
    final day = GameDate.addDays(pack.manifest.startDate.day, d);
    for (var t = 0; t < 14; t++) {
      yield GameDate(day, t);
    }
  }
}

Future<void> main() async {
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  group('stamina-free blocks', () {
    test(
      'Time Jumper 69 frees about one tick in ten, card and block alike',
      () {
        final game = withTraits([TraitEngine.timeJumper]);
        final plain = withTraits(const []);
        final study = actionOf(game, 'study');
        var free = 0;
        var total = 0;
        for (final when in ticks(game)) {
          game.state.date = when;
          plain.state.date = when;
          total++;
          if (game.preview(study).hpCost == 0) free++;
          expect(plain.preview(study).hpCost, greaterThan(0));
        }
        // 420 seeded ticks; the stated rate is 10%.
        expect(free / total, inInclusiveRange(0.05, 0.16));

        // On a free tick the block really costs nothing.
        final freeTick = ticks(game).firstWhere((when) {
          game.state.date = when;
          return when.tick >= 6 && game.preview(study).hpCost == 0;
        });
        game.state.date = freeTick;
        game.state.hp = 50;
        game.act(study, book: game.bookForSlot(0));
        expect(game.state.hp, 50);
      },
    );

    test('Energizer 84 frees a whole day or none of it', () {
      final game = withTraits([TraitEngine.energizer]);
      final study = actionOf(game, 'study');
      var freeDays = 0;
      for (var d = 0; d < 400; d++) {
        final day = GameDate.addDays(pack.manifest.startDate.day, d);
        final costs = {
          for (var t = 0; t < 14; t++)
            (() {
              game.state.date = GameDate(day, t);
              return game.preview(study).hpCost == 0;
            })(),
        };
        expect(costs, hasLength(1), reason: 'day $day split');
        if (costs.single) freeDays++;
      }
      // "Low chance": 5% of days by default.
      expect(freeDays, inInclusiveRange(8, 40));
    });
  });

  group('holding on at 1 stamina', () {
    /// Share of action ticks on which [game] would hold on.
    double holdRate(Game game, bool Function(Game) holds) {
      var hits = 0;
      var total = 0;
      for (final when in ticks(game)) {
        game.state.date = when;
        total++;
        if (holds(game)) hits++;
      }
      return hits / total;
    }

    /// Spends the last stamina point on a block at [when].
    Game spendLast(Game game, GameDate when) {
      game.state.date = when;
      game.state.hp = 1;
      game.act(actionOf(game, 'study'), book: game.bookForSlot(0));
      return game;
    }

    test('Stubborn 41 and I will not falter! 51 roll distinct chances', () {
      final stubborn = withTraits([TraitEngine.stubborn]);
      final falter = withTraits([TraitEngine.willNotFalter]);
      final s = holdRate(stubborn, (g) => g.traits.survivesExhaustion(g.state));
      final f = holdRate(falter, (g) => g.traits.survivesExhaustion(g.state));
      expect(s, inInclusiveRange(0.22, 0.38)); // "random chance": 30%
      expect(f, inInclusiveRange(0.62, 0.78)); // "high chance": 70%
      expect(
        holdRate(
          withTraits(const []),
          (g) => g.traits.survivesExhaustion(g.state),
        ),
        0,
      );
    });

    test('a held-on block leaves 1 stamina; a failed roll collapses', () {
      final probe = withTraits([TraitEngine.stubborn]);
      final afternoon = ticks(probe).where((w) => w.tick >= 6 && w.tick < 12);
      final lucky = afternoon.firstWhere((w) {
        probe.state.date = w;
        return probe.traits.survivesExhaustion(probe.state);
      });
      final unlucky = afternoon.firstWhere((w) {
        probe.state.date = w;
        return !probe.traits.survivesExhaustion(probe.state);
      });

      final held = spendLast(withTraits([TraitEngine.stubborn]), lucky);
      expect(held.state.hp, 1);
      expect(held.state.date.day, lucky.day, reason: 'the day goes on');

      final fell = spendLast(withTraits([TraitEngine.stubborn]), unlucky);
      expect(fell.state.date.day, isNot(unlucky.day), reason: 'collapsed');
    });

    test('Pet Rock 30207 holds on at its parsed 50%', () {
      expect(pack.items[30207]!.effects.single, {
        'type': 'surviveExhaustion',
        'chance': 0.5,
      });
      final afternoon = <GameDate>[];
      final probe = withTraits(const []);
      for (final w in ticks(probe)) {
        if (w.tick >= 6 && w.tick < 12) afternoon.add(w);
      }
      var held = 0;
      for (final w in afternoon) {
        final game = withTraits(const []);
        game.state.addItem(30207);
        if (spendLast(game, w).state.date.day == w.day) held++;
      }
      expect(held / afternoon.length, inInclusiveRange(0.38, 0.62));

      // Without the rock, every one of those blocks collapses.
      for (final w in afternoon.take(20)) {
        expect(spendLast(withTraits(const []), w).state.date.day, isNot(w.day));
      }
    });
  });

  group('store discounts', () {
    test('Limited Offer 34 halves every Store price for its three days', () {
      final game = withTraits([TraitEngine.limitedOffer]);
      for (final id in pack.shop.keys) {
        final listed = pack.shop[id]!['price'] as num;
        expect(game.priceOf(id), (listed / 2).round());
      }
      // The checkout charges the shown price.
      game.state.money = 10000;
      expect(game.purchase(8), isNull);
      expect(game.state.money, 10000 - 750);

      // initialLifeTime 3: gone after the third rollover.
      for (var d = 0; d < 3; d++) {
        expect(game.priceOf(8), 750);
        game.state.expireTraitsForNewDay();
      }
      expect(game.priceOf(8), 1500);
    });

    test('Solitary Gourmet 21 discounts only food-tagged items', () {
      final game = withTraits([TraitEngine.solitaryGourmet]);
      final t = game.traits;
      expect(t.priceFactor(game.state, pack.items[1]), 0.8); // Coffee: food
      expect(t.priceFactor(game.state, pack.items[11]), 0.8); // Royal Meal
      expect(t.priceFactor(game.state, pack.items[18]), 1); // Coffee Machine
      expect(t.priceFactor(game.state, pack.items[8]), 1); // Weird Workbook
      // None of the five current offers is food, so the Store is unchanged.
      for (final id in pack.shop.keys) {
        expect(game.priceOf(id), pack.shop[id]!['price']);
      }

      game.state.grantTrait(TraitEngine.limitedOffer);
      expect(t.priceFactor(game.state, pack.items[1]), closeTo(0.4, 1e-9));
      expect(t.priceFactor(withTraits(const []).state, pack.items[1]), 1);
    });
  });
}
