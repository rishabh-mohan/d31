/// The university sets (TODO 41): colleges.json, the US overlay, and a run
/// keeping the set it started with.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';

void main() {
  late ContentPack pack;
  late ContentPack retry;

  // Where tools/us_colleges.csv puts Purdue; the mapping is the user's to edit.
  int purdueIn(ContentPack p) => p.admissions.universities.values
      .firstWhere((u) => u.name == 'Purdue University')
      .id;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  test('the catalog loads from colleges.json', () {
    expect(pack.sourceFiles.containsKey('colleges.json'), isTrue);
    expect(pack.admissions.universities[2]!.name, 'Korea Dream University');
    expect(pack.collegeSet, 'korean');
  });

  test('the US set preserves existing majors while adding its own', () {
    final us = pack.withColleges('us');
    expect(us.collegeSet, 'us');
    expect(us.admissions.universities[2]!.name, 'Harvard University');
    // Purdue is a top-level college.
    final purdue = purdueIn(us);
    expect([
      'eight',
      'nine',
      'ten',
    ], contains(us.admissions.universities[purdue]!.rank));
    expect(us.badges[purdue]?.name ?? 'Purdue University', 'Purdue University');
    // Existing departments, cutoffs and ids are preserved.
    expect(
      us.admissions.departments.length,
      pack.admissions.departments.length + 1,
    );
    for (final d in pack.admissions.departments.values) {
      final other = us.admissions.departments[d.id]!;
      expect(other.deviation, d.deviation);
      expect(other.universityId, d.universityId);
    }
    // Basakan, story-only, is left alone.
    expect(us.admissions.universities[56]!.name, 'Basakan University');
    // Every regular university was renamed, and no two share a name.
    final names = us.admissions.universities.values
        .where((u) => !u.storyOnly)
        .map((u) => u.name)
        .toList();
    expect(names.where((n) => n.startsWith('Korea ')), isEmpty);
    expect(names.toSet().length, names.length);
    expect(names.any((n) => n.contains('Stanford')), isFalse);
    // Built once; and back again.
    expect(identical(pack.withColleges('us'), us), isTrue);
    expect(identical(us.withColleges('korean'), pack), isTrue);
    expect(identical(pack.withColleges('mars'), pack), isTrue);
  });

  test(
    'Ball State offers Teaching Physics only in the US set in both stories',
    () {
      for (final base in [pack, retry]) {
        final us = base.withColleges('us');
        final ballState = us.admissions.universities.values.singleWhere(
          (u) => u.name == 'Ball State University',
        );
        final major = us.admissions.departments.values.singleWhere(
          (d) => d.universityId == ballState.id && d.name == 'Teaching Physics',
        );
        expect(major.id, 118022);
        expect(major.deviation, 52.5);
        expect(major.requiredItems, isEmpty);
        expect(base.admissions.departments.containsKey(major.id), isFalse);
        expect(
          us
              .withColleges('korean')
              .admissions
              .departments
              .containsKey(major.id),
          isFalse,
        );
        expect(
          us.admissions.departments.length,
          base.admissions.departments.length + 1,
        );
      }
    },
  );

  test('the US set carries each school’s own crest', () {
    final us = pack.withColleges('us');
    final purdue = purdueIn(us);
    expect(
      us.admissions.universities[purdue]!.crestPath,
      'colleges/us/$purdue.png',
    );
    expect(us.badges[purdue]?.crest, anyOf(isNull, 'colleges/us/$purdue.png'));
    // The Korean set keeps the original crests.
    expect(pack.admissions.universities[purdue]!.crest, isNull);
    expect(
      pack.admissions.universities[purdue]!.crestPath,
      'kss/images/university/$purdue.png',
    );
    // Story-only universities keep theirs in both.
    expect(us.admissions.universities[56]!.crest, isNull);
  });

  test('a run keeps its university set through a save', () {
    final game = Game.newRun(pack.withColleges('us'));
    final json = jsonDecode(jsonEncode(game.state.toJson()));
    expect(json['collegeSet'], 'us');
    final loaded = GameState.fromJson(pack, json as Map<String, dynamic>);
    expect(loaded.pack.collegeSet, 'us');
    expect(purdueIn(loaded.pack), purdueIn(pack.withColleges('us')));
  });

  test('the female script keeps the set', () {
    final female = retry.withColleges('us').forPlayer(isMale: false);
    expect(female.collegeSet, 'us');
    expect(purdueIn(female), purdueIn(retry.withColleges('us')));
  });
}
