import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/book_completion.dart';
import 'package:d30mode/engine/book_rewards.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/state.dart';

import 'support/book_fixture.dart';

void main() {
  test(
    'tier pools use eligible unowned traits, distinct items, and S stats only',
    () {
      final pack = rewardPack();
      final state = GameState.newRun(pack, random: Random(2))..isMale = true;
      state.inventory[104] = 1;
      state.grantTrait(200);
      for (var i = 0; i < 6; i++) {
        final pool = buildBookRewards(state, pack.books[i + 1]!);
        final items = pool
            .where((r) => r.type == 'item')
            .map((r) => r.id)
            .toList();
        final traits = pool
            .where((r) => r.type == 'trait')
            .map((r) => r.id)
            .toList();
        expect(items.toSet().length, items.length);
        expect(items, isNot(contains(103))); // female-only
        expect(items, isNot(contains(104))); // held at cap
        expect(traits, isNot(contains(200))); // owned
        expect(traits, isNot(contains(205))); // not eligible
        expect(pool.where((r) => r.type == 'stat').length, 5);
        expect(
          pool.where((r) => r.type == 'stat').map((r) => r.amount).toSet(),
          {
            [40, 105, 200, 375, 600, 800][i],
          },
        );
        if (i == 5) expect(pool.every((r) => r.type == 'stat'), isTrue);
      }
    },
  );

  test('first completion pauses the block; chosen roll and workbook survive reopening', () {
    final pack = rewardPack();
    var game = Game.newRun(pack, random: Random(4));
    game.state.bookReadCounts[1] = 1;
    final action = pack.locations[1]!.actions.first;
    final visibleHand = game.hand();
    final visibleBooks = [
      for (var i = 0; i < visibleHand.length; i++) game.bookForSlot(i)?.id,
    ];
    final outcome = game.act(
      action,
      book: pack.books[1],
      deferBookCompletion: true,
    );
    expect(outcome.acquiredItems, isEmpty); // saved prelude owns its receipt
    expect(game.state.date.tick, 0); // no day/events before receipt flow
    expect(game.hand(), same(visibleHand));
    expect([
      for (var i = 0; i < visibleHand.length; i++) game.bookForSlot(i)?.id,
    ], visibleBooks);
    expect(game.availableActions(), isNotEmpty);
    expect(game.state.pendingBookRewards.single.beforeItems, [101]);
    final original = jsonEncode(game.state.pendingBookRewards.single.toJson());
    game = Game(
      pack: pack,
      state: GameState.fromJson(
        pack,
        jsonDecode(jsonEncode(game.state.toJson())),
      ),
    );
    expect(jsonEncode(game.state.pendingBookRewards.single.toJson()), original);
    game.act(action, book: pack.books[1], deferBookCompletion: true);
    expect(game.readCount(pack.books[1]!), 2); // blocked during pending UI
    final pending = game.state.pendingBookRewards.single;
    pending.revealed = true;
    game.awardBookReward(pending);
    final awarded = jsonEncode(game.state.toJson());
    game.awardBookReward(pending);
    expect(jsonEncode(game.state.toJson()), awarded);
    game.state.pendingBookRewards.clear();
    game.finishBookCompletionAction();
    expect(game.state.date.tick, 1);
    game.finishBookCompletionAction();
    expect(game.state.date.tick, 1);
    game.act(action, book: pack.books[1], deferBookCompletion: true);
    expect(game.state.pendingBookRewards, isEmpty);
    expect(game.state.itemCount(101), 1); // no repeat workbook
  });

  test('trait reward runs acquisition hooks once and remains run-only', () {
    final game = Game.newRun(rewardPack());
    final pending = PendingBookReward(
      bookId: 1,
      candidates: [const BookReward('trait', id: 200)],
      selectedIndex: 0,
    );
    game.state.pendingBookRewards.add(pending);
    final before = game.state.money;
    game.awardBookReward(pending);
    expect(game.state.traits, contains(200));
    expect(game.state.initialTraitIds, isEmpty);
    expect(game.state.money, before + 7);
    final resumed = Game(
      pack: game.pack,
      state: GameState.fromJson(
        game.pack,
        jsonDecode(jsonEncode(game.state.toJson())),
      ),
    );
    resumed.awardBookReward(resumed.state.pendingBookRewards.single);
    expect(resumed.state.money, before + 7);
    expect(resumed.state.pendingBookRewards.single.stage, 'receipt');
  });

  test(
    'direct stat reward is exact and cannot be claimed twice after reload',
    () {
      final game = Game.newRun(rewardPack());
      final pending = PendingBookReward(
        bookId: 1,
        candidates: [const BookReward('stat', subject: 'logic', amount: 105)],
        selectedIndex: 0,
      );
      game.state.pendingBookRewards.add(pending);
      final before = game.state.stats['logic']!;
      game.awardBookReward(pending);
      expect(game.state.stats['logic'], before + 105);
      final resumed = Game(
        pack: game.pack,
        state: GameState.fromJson(
          game.pack,
          jsonDecode(jsonEncode(game.state.toJson())),
        ),
      );
      resumed.awardBookReward(resumed.state.pendingBookRewards.single);
      expect(resumed.state.stats['logic'], before + 105);
    },
  );

  test('exhausted item pools use configured fallback and deduplicate it', () {
    final pack = rewardPack(rewardChanges: {'items': []});
    final state = GameState.newRun(pack);
    for (final id in pack.items.keys) {
      state.inventory[id] = 1;
    }
    final pool = buildBookRewards(state, pack.books[1]!);
    expect(pool.where((r) => r.type == 'item').map((r) => r.id), [101]);
  });

  test('new items in the active pack automatically join the reward pool', () {
    final pack = rewardPack(rewardChanges: {'itemDraws': 1, 'items': []});
    final state = GameState.newRun(pack);
    for (final id in pack.items.keys.where((id) => id != 108)) {
      state.inventory[id] = 1;
    }
    final items = buildBookRewards(
      state,
      pack.books[1]!,
    ).where((r) => r.type == 'item');
    expect(items.single.id, 108);
  });

  test('reward items the pack does not have are dropped, not rejected', () {
    final pack = rewardPack(
      rewardChanges: {
        'items': [
          {'id': 999, 'bucket': 'low'},
          {'id': 101, 'bucket': 'low'},
        ],
      },
    );
    expect([for (final r in pack.bookRewards.items) r['id']], [101]);
  });

  test(
    'pack validation rejects negative weights and missing tiers',
    () {
      for (final changes in [
        {
          'tiers': {
            'E': {'stat': -1},
          },
        },
        {'tiers': {}},
        {
          'items': [
            {'id': 101, 'bucket': 'other'},
          ],
        },
      ]) {
        expect(() => rewardPack(rewardChanges: changes), throwsFormatException);
      }
    },
  );
}
