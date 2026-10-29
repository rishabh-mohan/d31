/// The recovered E–A item/trait/stat candidate algorithm. S is stats only.
library;

import 'dart:math';

import 'book_rewards.dart';
import 'pack.dart';
import 'state.dart';

List<BookReward> buildBookRewards(GameState state, GameBook book) {
  final rules = state.pack.bookRewards;
  final tier = rules.tier(book.tier)!;
  final seed = state.bookRewardSeed + book.id;
  final pool = <BookReward>[];
  // Explicit rules override the active pack's catalog. New authored items
  // enter the low bucket by default; imported non-reward/quest items can opt out.
  final itemRules = {for (final row in rules.items) row['id'] as int: row};
  for (final item in state.pack.items.values) {
    if (!item.bookRewardExcluded) {
      itemRules.putIfAbsent(
        item.id,
        () => {'id': item.id, 'bucket': item.bookRewardBucket, 'gender': 'any'},
      );
    }
  }
  if (book.tier != 'S') {
    final weights = (tier['items'] as Map? ?? const {});
    final selected = <int>{};
    final buckets = ['low', 'middle', 'high'];
    final sum = buckets.fold<num>(0, (v, b) => v + ((weights[b] as num?) ?? 0));
    if (sum > 0) {
      for (var slot = 0; slot < rules.itemDraws; slot++) {
        var found = false;
        for (var attempt = 0; attempt <= 10000; attempt++) {
          var roll = state.random.nextDouble() * sum;
          var bucket = buckets.last;
          for (final b in buckets) {
            roll -= (weights[b] as num?) ?? 0;
            if (roll < 0) {
              bucket = b;
              break;
            }
          }
          final eligible = itemRules.values.where((row) {
            final id = row['id'] as int;
            final item = state.pack.items[id]!;
            final gender = row['gender'] ?? 'any';
            return row['bucket'] == bucket &&
                row['enabled'] != false &&
                (gender == 'any' || (gender == 'male') == state.isMale) &&
                !selected.contains(id) &&
                (item.maxCount == null || state.itemCount(id) < item.maxCount!);
          }).toList();
          if (eligible.isEmpty) continue;
          selected.add(
            eligible[state.random.nextInt(eligible.length)]['id'] as int,
          );
          found = true;
          break;
        }
        if (!found && rules.fallbackItemId != null) {
          selected.add(rules.fallbackItemId!);
        }
      }
    }
    pool.addAll(selected.map((id) => BookReward('item', id: id)));
    final counts = tier['traits'] as Map? ?? const {};
    for (final grade in ['C', 'B', 'A']) {
      final eligible = state.pack.traits.values
          .where(
            (t) =>
                t.bookRewardEligible &&
                t.rank == grade &&
                !state.traits.contains(t.id) &&
                (t.storyId == null || t.storyId == state.pack.manifest.storyId),
          )
          .toList();
      eligible.shuffle(Random(seed));
      pool.addAll(
        eligible
            .take((counts[grade] as num?)?.toInt() ?? 0)
            .map((t) => BookReward('trait', id: t.id)),
      );
    }
  }
  for (final subject in state.pack.manifest.subjects) {
    pool.add(
      BookReward(
        'stat',
        subject: subject,
        amount: (tier['stat'] as num?)?.toInt() ?? 0,
      ),
    );
  }
  pool.shuffle(Random(seed));
  return pool;
}
