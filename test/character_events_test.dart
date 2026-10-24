import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

/// TODO 48 / 34: character abilities are the global character events, and
/// the practice blocks feed the counters their storylines read.
void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  void finish(EventRun run) {
    for (var i = 0; i < 2000 && !run.current!.isEnd; i++) {
      run.current!.choices.isEmpty
          ? run.advance()
          : run.choose(run.current!.choices.first);
    }
  }

  /// Plays [days] days of mixed blocks and returns how often each event ran.
  Map<int, int> play(int character, {int days = 10, int seed = 3}) {
    final game = Game.newRun(pack, random: Random(seed));
    game.state.characterId = character;
    final seen = <int, int>{};
    final stop = game.state.dayNumber + days;
    var guard = 0;
    while (game.state.dayNumber < stop && guard++ < 2000) {
      final hand = game.hand();
      if (hand.isEmpty) break;
      final slot = game.state.hp < 35
          ? max(0, hand.indexWhere((a) => a.actionType == 'sleep'))
          : game.state.random.nextInt(hand.length);
      final outcome = game.act(hand[slot], book: game.bookForSlot(slot));
      for (final run in [...outcome.beforeEvents, ?outcome.event]) {
        seen.update(run.event.id, (n) => n + 1, ifAbsent: () => 1);
        finish(run);
      }
    }
    return seen;
  }

  test('the Beggar begs again on later days, other characters never do', () {
    final beggar = play(3);
    expect(beggar[10020001] ?? 0, greaterThan(1));
    final ordinary = play(1);
    expect(
      ordinary.keys.where((id) => pack.events[id]?.isCharacterEvent ?? false),
      isEmpty,
    );
  });

  test("Ihyeon's medicine block levels up her potions", () {
    final game = Game.newRun(pack);
    game.state.characterId = 70;
    final block = pack.locations.values
        .expand((l) => l.actions)
        .firstWhere((a) => a.funcCode == 'MEDICAL_ACTION');
    expect(game.blockGateOpen(block.conditionFuncCode!), isTrue);
    for (var i = 0; i < 10; i++) {
      game.effects.applyChanger(block.changer, game.state);
    }
    expect(game.state.switchValue('MEDICAL_COUNT'), 10);
    expect(
      game.events.eligible(game.state).map((e) => e.id),
      contains(10020100),
    );
  });

  test('practice blocks feed the counters their storylines read', () {
    final game = Game.newRun(pack);
    for (final (code, counter) in [
      ('IDOL_ACTION', 'IDOL'),
      ('PRO_GAME_ACTION', 'GAME'),
      ('SOCCER_ACTION', 'SOCCER'),
      ('MECHANIC_ACTION', 'ROBOT_COUNT'),
    ]) {
      game.effects.applyChanger({'funcCode': code}, game.state);
      expect(game.state.switchValue(counter), 1, reason: code);
    }
  });
}
