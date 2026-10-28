import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';

class _FixedRoll implements Random {
  final double roll;
  _FixedRoll(this.roll);

  @override
  double nextDouble() => roll;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  late ContentPack pack;
  const published = {
    'AAA': {'S': 6, 'A': 94},
    'AAB': {'S': 4, 'A': 81, 'B': 15},
    'ABB': {'S': 2, 'A': 68, 'B': 30},
    'BBB': {'A': 55, 'B': 45},
    'BBC': {'A': 37, 'B': 53, 'C': 10},
    'BCC': {'A': 19, 'B': 61, 'C': 20},
    'CCC': {'A': 1, 'B': 69, 'C': 30},
  };

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  Account accountFor(String inputs) {
    final account = Account();
    for (var i = 0; i < inputs.length; i++) {
      final trait = pack.traits.values.firstWhere(
        (t) => t.setupEligible && t.storyId == null && t.rank == inputs[i],
      );
      account.traits.add(OwnedTrait(i + 1, trait.id));
    }
    account.nextTraitUid = inputs.length + 1;
    return account;
  }

  test(
    'all published rows and clarified mixes are independent of input order',
    () {
      expect(Account.combineRates, published);
      const expected = {
        ...published,
        'AAC': {'S': 2, 'A': 68, 'B': 30},
        'ABC': {'A': 55, 'B': 45},
        'ACC': {'A': 37, 'B': 53, 'C': 10},
        'SSS': {'S': 100},
      };
      for (final row in expected.entries) {
        final k = row.key;
        for (final order in {
          k,
          '${k[0]}${k[2]}${k[1]}',
          '${k[1]}${k[0]}${k[2]}',
          '${k[1]}${k[2]}${k[0]}',
          '${k[2]}${k[0]}${k[1]}',
          '${k[2]}${k[1]}${k[0]}',
        }) {
          expect(
            Account.combineRatesFor(order.split('')),
            row.value,
            reason: order,
          );
        }
      }
    },
  );

  for (final campaign in ['standard', 'winter', 'retry']) {
    test(
      'actual $campaign combines match every percentage and consume three copies',
      () {
        for (final inputs in [...published.keys, 'AAC', 'ABC', 'ACC', 'SSS']) {
          final counts = <String, int>{};
          for (var bucket = 0; bucket < 100; bucket++) {
            final account = accountFor(inputs);
            final picked = List.of(account.traits);
            final result = account.combine(
              picked,
              pack,
              campaign,
              _FixedRoll((bucket + .5) / 100),
            )!;
            counts.update(result.rank, (count) => count + 1, ifAbsent: () => 1);
            expect(account.traits, hasLength(1));
            expect(account.traits.single.uid, 4);
            expect(account.traits.single.traitId, result.id);
            expect(Account.poolFor(pack, campaign), contains(result));
          }
          expect(
            counts,
            Account.combineRatesFor(inputs.split('')),
            reason: inputs,
          );
        }
      },
    );
  }

  test('AAA and CCC use the correct probability boundaries', () {
    for (final (inputs, roll, rank) in [
      ('AAA', 0.0, 'S'),
      ('AAA', .059999, 'S'),
      ('AAA', .06, 'A'),
      ('CCC', .009999, 'A'),
      ('CCC', .01, 'B'),
      ('CCC', .699999, 'B'),
      ('CCC', .70, 'C'),
    ]) {
      final account = accountFor(inputs);
      expect(
        account
            .combine(
              List.of(account.traits),
              pack,
              'standard',
              _FixedRoll(roll),
            )!
            .rank,
        rank,
      );
    }
  });
}
