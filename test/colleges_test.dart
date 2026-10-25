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

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  test('the catalog loads from colleges.json', () {
    expect(pack.sourceFiles.containsKey('colleges.json'), isTrue);
    expect(pack.admissions.universities[2]!.name, 'Korea Dream University');
    expect(pack.collegeSet, 'korean');
  });

  test('admissions.json still loads for packs built before colleges.json', () {
    final files = Map.of(pack.sourceFiles)
      ..['admissions.json'] = pack.sourceFiles['colleges.json']!
      ..remove('colleges.json');
    final old = ContentPack.fromFiles(files);
    expect(old.admissions.departments.length, pack.admissions.departments.length);
  });

  test('the US set renames universities and badges, nothing else', () {
    final us = pack.withColleges('us');
    expect(us.collegeSet, 'us');
    expect(us.admissions.universities[2]!.name, 'Purdue University');
    expect(us.badges[2]?.name ?? 'Purdue University', 'Purdue University');
    // Departments, cutoffs and ids are the same catalog.
    expect(us.admissions.departments.length, pack.admissions.departments.length);
    for (final d in pack.admissions.departments.values.take(50)) {
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

  test('a run keeps its university set through a save', () {
    final game = Game.newRun(pack.withColleges('us'));
    final json = jsonDecode(jsonEncode(game.state.toJson()));
    expect(json['collegeSet'], 'us');
    final loaded = GameState.fromJson(pack, json as Map<String, dynamic>);
    expect(loaded.pack.collegeSet, 'us');
    expect(loaded.pack.admissions.universities[2]!.name, 'Purdue University');
  });

  test('the female script keeps the set', () {
    final female = retry.withColleges('us').forPlayer(isMale: false);
    expect(female.collegeSet, 'us');
    expect(female.admissions.universities[2]?.name, 'Purdue University');
  });
}
