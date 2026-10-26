/// Acceptance modifiers act on each application's final chance (pack data:
/// traitAbilities acceptanceFactor/acceptancePoints, item acceptanceRate):
/// multiply first, then add percentage points, then clamp to 0..100.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';

void main() {
  for (final story in [16, 20]) {
    group('acceptance modifiers kss$story', () {
      late ContentPack pack;
      setUpAll(() async {
        pack = await ContentSource.loadFromDirectory(
          Directory('packs/kss$story'),
        );
      });

      Game run(num each, {List<int> traits = const [], List<int> items = const []}) {
        final game = Game(
          pack: pack,
          state: GameState.newRun(pack, random: Random(7)),
        );
        for (final s in pack.manifest.subjects) {
          game.state.stats[s] = each;
        }
        game.state.csatPending = true;
        for (final t in traits) {
          expect(game.state.grantTrait(t), isTrue, reason: 'trait $t');
        }
        for (final i in items) {
          game.state.addItem(i);
        }
        return game;
      }

      /// An eligible department whose unmodified chance is near [target].
      Department near(Game game, double target) {
        final list = game.eligibleDepartments();
        list.sort(
          (a, b) => (game.admissionChance(a) - target).abs().compareTo(
            (game.admissionChance(b) - target).abs(),
          ),
        );
        return list.first;
      }

      const mid = 15000;

      test('each modifier changes only the final chance', () {
        final plain = run(mid);
        final d = near(plain, .5);
        final c0 = plain.admissionChance(d);
        expect(c0, inInclusiveRange(.2, .9));
        final cases = <String, (List<int>, List<int>, double)>{
          'Master of 108 Bows x1.08': ([47], [], c0 * 1.08),
          'Blood Type A +3': ([74], [], c0 + .03),
          'Blood Type AB +1': ([89], [], c0 + .01),
          'MBTI S provisional +1': ([40], [], c0 + .01),
          'Totem +1': ([], [3004], c0 + .01),
          'Light +0.1': ([], [3007], c0 + .001),
          'Chocolate +2': ([], [3011], c0 + .02),
        };
        for (final e in cases.entries) {
          final g = run(mid, traits: e.value.$1, items: e.value.$2);
          expect(g.admissionChance(d), closeTo(e.value.$3, 1e-9), reason: e.key);
          // The score itself is no longer shifted (old standard-score path).
          expect(
            g.takeCsat().standardScore,
            closeTo(plain.takeCsat().standardScore, 1e-9),
            reason: e.key,
          );
        }
      });

      test('stacking multiplies first, then adds points', () {
        final plain = run(mid);
        final d = near(plain, .5);
        final c0 = plain.admissionChance(d);
        final g = run(mid, traits: [47, 74, 40], items: [3004, 3007, 3011]);
        final points = .03 + .01 + .01 + .001 + .02;
        expect(g.admissionChance(d), closeTo(c0 * 1.08 + points, 1e-9));
        expect(g.displayedRate(d), (g.admissionChance(d) * 100).round());
      });

      test('clamps to 0..100', () {
        final high = run(30000, traits: [47, 74], items: [3011]);
        for (final d in high.eligibleDepartments().take(20)) {
          expect(high.admissionChance(d), lessThanOrEqualTo(1.0));
          expect(high.displayedRate(d), lessThanOrEqualTo(100));
        }
        final topDept = near(run(30000), 1.0);
        expect(high.admissionChance(topDept), 1.0);
        // A hopeless application gains exactly the points, never a negative.
        final low = run(1000, traits: [74]);
        final hard = low.eligibleDepartments().first;
        expect(low.admissionChance(hard), closeTo(.03, .001));
        expect(run(1000).admissionChance(hard), lessThan(.001));
      });

      test('displayed rate, stored rate and roll agree', () {
        final g = run(mid, traits: [47, 74], items: [3011]);
        final plain = run(mid);
        final depts = <Department>[];
        final seen = <int>{};
        for (final d in g.eligibleDepartments()) {
          if (seen.add(d.universityId)) depts.add(d);
        }
        final chosen = depts.take(3).toList();
        final shown = [for (final d in chosen) g.displayedRate(d)];
        expect(
          [for (final d in chosen) plain.displayedRate(d)],
          isNot(shown),
          reason: 'modifiers must change the shown rates',
        );
        for (final d in chosen) {
          expect(g.draftProblem(d), isNull);
          g.addToDraft(d.id);
        }
        final results = g.submitDraft();
        expect([for (final r in results) r.rate], shown);
        expect(g.state.applicationRates, shown);
        // A displayed 100 always wins the roll; a 0 never does.
        for (final r in results) {
          if (r.rate == 100) expect(r.accepted, isTrue);
          if (r.rate == 0) expect(r.accepted, isFalse);
        }
      });
    });
  }
}
