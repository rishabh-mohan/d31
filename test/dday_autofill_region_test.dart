// Auto Input must not collapse onto Taiwan/Global (TODO COLLEGE-AUTOFILL).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/admissions.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';

void main() {
  late ContentPack base;
  setUpAll(() async {
    base = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  Set<UniversityCategory> picked(String set, int each) {
    final p = base.withColleges(set);
    final game = Game(pack: p, state: GameState.newRun(p, random: Random(7)));
    for (final s in p.manifest.subjects) {
      game.state.stats[s] = each;
    }
    game.state.csatPending = true;
    game.completeExamCards();
    expect(game.autoFill(), [0, 1, 2]);
    return {
      for (final d in game.draftDepartments)
        p.admissions.universities[d.universityId]!.category,
    };
  }

  for (final set in ['korean', 'us']) {
    test('$set set: a hopeless run (all 0%) is not sent to the hardest '
        'Taiwan/Global majors', () {
      final cats = picked(set, 800);
      expect(cats, contains(UniversityCategory.korea));
      expect(cats, isNot(equals({UniversityCategory.taiwan,
          UniversityCategory.global})));
    });

    test('$set set: mid and strong runs draw from Korea and Taiwan', () {
      for (final each in [2500, 4000]) {
        expect(picked(set, each), contains(UniversityCategory.korea),
            reason: '$set @ $each');
      }
    });
  }
}
