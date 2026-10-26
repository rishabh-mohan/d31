/// The fitted CSAT curve's calibration, and one application per school.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

void main() {
  late ContentPack pack;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  Game withStats(num each) {
    final game = Game.newRun(pack);
    for (final s in pack.manifest.subjects) {
      game.state.stats[s] = each;
    }
    return game;
  }

  Department hardest() => pack.admissions.departments.values
      .where((d) => !pack.admissions.universities[d.universityId]!.storyOnly)
      .reduce((a, b) => a.deviation >= b.deviation ? a : b);

  test('the curve meets the calibration targets', () {
    final top = hardest();
    expect(top.deviation, closeTo(73.24, .01));
    expect(withStats(25000).admissionChance(top), greaterThan(.97));
    expect(withStats(15000).admissionChance(top), closeTo(.5, .05));
    expect(withStats(10000).admissionChance(top), inInclusiveRange(.08, .15));
    expect(withStats(3000).admissionChance(top), lessThan(.001));
    // 10k is a coin flip one tier down (cutoff ~69).
    final tierBelow = pack.admissions.departments.values
        .where((d) => (d.deviation - 68.9).abs() < .3)
        .first;
    expect(withStats(10000).admissionChance(tierBelow), closeTo(.5, .1));
    // 16k clears most regular departments.
    final regular = pack.admissions.departments.values.where(
      (d) => !pack.admissions.universities[d.universityId]!.storyOnly,
    );
    final likely = regular.where(
      (d) => withStats(16000).admissionChance(d) > .9,
    );
    expect(likely.length / regular.length, greaterThan(.85));
  });

  test('about 3k per subject reaches the easiest regular colleges', () {
    final easiest = pack.admissions.departments.values
        .where((d) => !pack.admissions.universities[d.universityId]!.storyOnly)
        .reduce((a, b) => a.deviation <= b.deviation ? a : b);
    final chance = withStats(3000).admissionChance(easiest);
    expect(chance, inInclusiveRange(.3, .7));
  });

  test('a lopsided student scores below a balanced one', () {
    final balanced = withStats(10000).takeCsat().standardScore;
    final lopsided = withStats(0);
    lopsided.state.stats[pack.manifest.subjects.first] = 50000;
    expect(lopsided.takeCsat().standardScore, lessThan(balanced));
  });

  test('one application per university', () {
    final game = withStats(25000);
    final dream = [
      for (final d in pack.admissions.departments.values)
        if (d.universityId == 2) d.id,
    ];
    final other = pack.admissions.departments.values.firstWhere(
      (d) => d.universityId == 3,
    );
    game.submitApplications([dream[0], dream[1], other.id]);
    expect(game.state.applications, [dream[0], other.id]);
    expect(
      game.sameSchoolChosen(pack.admissions.departments[dream[1]]!, [dream[0]]),
      isTrue,
    );
  });

  test('every pack sits the exam by default, borrowing colleges if needed', () {
    final files = Map.of(pack.sourceFiles)
      ..remove('colleges.json')
      ..remove('colleges_us.json');
    final rules = jsonDecode(files['rules.json']!) as Map<String, dynamic>;
    rules.remove('exam');
    files['rules.json'] = jsonEncode(rules);
    final bare = ContentPack.fromFiles(files);
    expect(bare.examEnabled, isFalse, reason: 'no colleges yet');
    final lent = bare.withCollegesFrom(pack);
    expect(lent.examEnabled, isTrue);
    expect(
      lent.admissions.departments.length,
      pack.admissions.departments.length,
    );
    // No curve in its rules: the calibrated default applies.
    final game = Game.newRun(lent);
    for (final s in lent.manifest.subjects) {
      game.state.stats[s] = 15000;
    }
    expect(game.takeCsat().standardScore, closeTo(73.24, .01));
    expect(identical(pack.withCollegesFrom(lent), pack), isTrue);
  });
}
