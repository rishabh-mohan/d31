/// The Calendar is the to-do list (TODO 66): the story's fixed dates plus
/// what events have told the player about, never every date-pinned event.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

void main() {
  late ContentPack pack;
  late ContentPack retry;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  test('a fresh run is only scheduled for the exam', () {
    final game = Game.newRun(pack);
    final schedule = game.schedule();
    expect(schedule, hasLength(1));
    expect(schedule.single.name, 'CSAT');
    expect(schedule.single.date.day, pack.manifest.endDate.day);
  });

  test('Retry Year lists its exams, not its pinned scenes', () {
    final names = Game.newRun(retry).schedule().map((e) => e.name).toList();
    expect(
      names,
      containsAll(['Hagwon Mock Exam #31', 'Promotion Exam', 'CSAT']),
    );
    expect(names, isNot(contains('Geum Taeyang')));
  });

  test('an event that tells the player adds to the calendar', () {
    final game = Game.newRun(pack);
    game.effects.applyChanger({
      'funcCode': 'ADD_TODO',
      'args': [20, 'National_Cooking_Contest', '2023.11.15.07'],
    }, game.state);
    game.effects.applyChanger({
      'funcCode': 'ADD_TODO_2',
      'args': [3, 'VisitArtGallery', 7],
    }, game.state);
    final names = game.schedule().map((e) => e.name).toList();
    expect(names, contains('National Cooking Contest'));
    expect(names, contains('Visit Art Gallery'));
    expect(names.last, 'CSAT', reason: 'sorted by date');
  });

  test('the calendar drops what is past', () {
    final game = Game.newRun(pack);
    game.effects.applyChanger({
      'funcCode': 'ADD_TODO_2',
      'args': [3, 'VisitArtGallery', 7],
    }, game.state);
    expect(game.schedule(), hasLength(2));
    game.state.date = pack.manifest.endDate;
    expect(game.schedule().map((e) => e.name), ['CSAT']);
  });
}
