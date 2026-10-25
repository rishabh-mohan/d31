import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_text.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

/// Regressions for the original-game parity audit's engine defects
/// (TODO 81 / 86). Each test names the audit item it pins.
void main() {
  late ContentPack retry;
  late ContentPack original;
  setUpAll(() async {
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    original = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  group('A01 FUNC_IS_IN_CHARACTER_LIST', () {
    test('matches the playing character against the listed ids', () {
      final game = Game.newRun(retry, random: Random(1));
      final inList = game.conditions.funcs['FUNC_IS_IN_CHARACTER_LIST']!;
      game.state.characterId = 66;
      expect(inList(game.state, const [66]), 1);
      expect(inList(game.state, const [58]), 0);
      expect(inList(game.state, const [58, 66]), 1);
      game.state.characterId = null;
      expect(inList(game.state, const [66]), 0);
    });

    test("character 58's branch in #189 now follows the character", () {
      final game = Game.newRun(retry, random: Random(2));
      final node = retry.nodes[189002]!;
      game.state.characterId = 58;
      expect(game.conditions.evaluate(node.conditionSet, game.state), isTrue);
      game.state.characterId = 66;
      expect(game.conditions.evaluate(node.conditionSet, game.state), isFalse);
    });
  });

  group('A12 the Scouter', () {
    test("forecasts character 67's guaranteed sing-off win", () {
      final game = Game.newRun(retry, random: Random(3));
      game.state.addItem(90021);
      game.state.setSwitch('SING_TARGET', 15);
      game.state.setSwitch('SING_COUNT', 0);
      final win = game.conditions.funcs['FUNC_SING_TARGET']!;

      game.state.characterId = 1;
      expect(win(game.state, const []), 0);
      expect(expandEventText('{IS_SING_WIN}', game.state), contains('lose'));

      game.state.characterId = 67;
      expect(win(game.state, const []), 1);
      expect(expandEventText('{IS_SING_WIN}', game.state), contains('win'));
    });
  });
}
