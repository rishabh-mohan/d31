import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';

/// TODO 36: one career storyline per run, as the original's single selected
/// rank-A event set; side stories and required events are unaffected.
void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  test('each run plays one career, and which one varies', () {
    final picked = <int>{};
    for (var seed = 0; seed < 40; seed++) {
      final game = Game.newRun(pack, random: Random(seed));
      expect(game.state.careerSets, hasLength(1));
      picked.addAll(game.state.careerSets!);
    }
    expect(picked.length, greaterThan(3));
  });

  test('Watching Soccer plays only in a soccer run', () {
    for (final soccer in [true, false]) {
      final game = Game.newRun(pack, random: Random(1));
      game.state.careerSets = {soccer ? 18 : 19};
      game.state.date = GameDate.parse('DATE_2023102100');
      final eligible = game.events.eligible(game.state).map((e) => e.id);
      expect(eligible.contains(173), soccer);
    }
  });

  test('the choice survives a save, and side stories stay open', () {
    final game = Game.newRun(pack, random: Random(2));
    final restored = GameState.fromJson(pack, game.state.toJson());
    expect(restored.careerSets, game.state.careerSets);
    expect(game.state.eventSetActive(13), isTrue, reason: 'rank-B gym set');
    expect(game.state.eventSetActive(12), isTrue, reason: 'required set');
  });
}
