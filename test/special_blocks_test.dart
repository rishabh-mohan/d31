/// Special blocks: the route-specific actions (Game Practice, Soccer
/// Practice, Drawing Practice) and what has to happen before they appear.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  /// Out of class, so the location is the player's to choose.
  Game afternoon() {
    final game = Game.newRun(pack);
    game.state.date = GameDate(game.state.date.day, 8);
    return game;
  }

  test('a block gate reads the switch the content writes', () {
    final game = afternoon();
    // The gate is a compiled predicate name; the switch is the plain one.
    expect(game.blockSwitchFor('PRO_GAME_BLOCK_CONDITION'), 'GAME_BLOCK');
    expect(game.blockSwitchFor('IDOL_BLOCK_CONDITION'), 'IDOL_BLOCK');
    // Other campaigns' routes declare no switch here, so they stay shut.
    expect(
      pack.switchDefaults.containsKey(
        game.blockSwitchFor('MEDICAL_BLOCK_CONDITION'),
      ),
      isFalse,
    );
  });

  test('Game Practice appears once the content turns GAME_BLOCK on', () {
    final game = afternoon();
    bool offered() =>
        game.availableActions().any((a) => a.text == 'Game Practice');

    expect(offered(), isFalse, reason: 'the switch starts off');
    game.state.setSwitch('GAME_BLOCK', 1);
    expect(offered(), isTrue);
    game.state.setSwitch('GAME_BLOCK', 0);
    expect(offered(), isFalse);
  });

  test('Soccer Practice needs its field, which an event unlocks', () {
    final game = afternoon();
    const field = 16007;
    expect(
      game.availableLocations().map((l) => l.id),
      isNot(contains(field)),
      reason: 'the field is locked until the soccer storyline opens it',
    );

    // What UNLOCK_LOCATION does when Watching Soccer reaches that node.
    game.effects.applyChanger(const {
      'changes': [],
      'funcCode': 'UNLOCK_LOCATION',
      'args': [field],
    }, game.state);

    expect(game.availableLocations().map((l) => l.id), contains(field));
    expect(game.move(field), isTrue);
    expect(
      game.availableActions().map((a) => a.text),
      contains('Soccer Practice'),
    );
  });
}
