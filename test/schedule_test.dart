/// The Calendar is content, not code: it comes from the campaign's
/// date-pinned events (docs/D30-MODE-SPEC.md 6.6), so a storyline can add to
/// it without the UI knowing anything about cooking contests.
library;

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

  test('a fresh run is only scheduled for the exam', () {
    final game = Game.newRun(pack);
    final schedule = game.schedule();
    expect(schedule, hasLength(1));
    expect(schedule.single.name, 'Graduation Exam');
    expect(schedule.single.date.day, pack.manifest.endDate.day);
  });

  test('meeting a storyline puts its pinned events on the calendar', () {
    final game = Game.newRun(pack);
    final opener = pack.events.values.firstWhere(
      (e) => e.name == 'Great News',
    );
    expect(
      opener.eventSetId,
      isNotNull,
      reason: 'the cooking opener should belong to a storyline set',
    );

    game.state.eventStates[opener.id] = 1;
    final names = game.schedule().map((e) => e.name).toList();
    expect(names, contains('National Cooking Contest'));
    expect(names, contains('First Training Session'));
    expect(names.last, 'Graduation Exam', reason: 'sorted by date');
  });

  test('the calendar drops what is finished or already past', () {
    final game = Game.newRun(pack);
    final opener = pack.events.values.firstWhere(
      (e) => e.name == 'Great News',
    );
    game.state.eventStates[opener.id] = 1;
    final before = game.schedule().length;

    final contest = pack.events.values.firstWhere(
      (e) => e.name == 'National Cooking Contest',
    );
    game.state.eventStates[contest.id] = 2;
    expect(
      game.schedule().map((e) => e.name),
      isNot(contains('National Cooking Contest')),
    );
    expect(game.schedule().length, before - 1);

    // Walk the clock past the first training session.
    game.state.date = pack.manifest.endDate;
    expect(game.schedule().map((e) => e.name), ['Graduation Exam']);
  });
}
