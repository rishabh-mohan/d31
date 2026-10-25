import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

/// TODO 101: the Beggar's 500 gold check reads the MONEY switch, which used to
/// be an empty content switch, so he always called the player broke.
void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  /// Walks Beggar Begging (event 14), helping him, and returns what was said.
  List<String> helpTheBeggar(num money) {
    final game = Game.newRun(pack);
    game.state.money = money;
    final run = EventEngine(pack: pack).begin(pack.events[14]!, game.state);
    final said = <String>[];
    for (var i = 0; i < 100 && !run.current!.isEnd; i++) {
      said.add(run.current!.text);
      final choices = run.current!.choices;
      choices.isEmpty
          ? run.advance()
          : run.choose(
              choices.firstWhere((c) => c.text.contains('Help')),
            );
    }
    said.add(run.current!.text);
    return said;
  }

  test('with enough gold the Beggar is paid and thanks you', () {
    final game = Game.newRun(pack);
    expect(game.state.switchValue('MONEY'), game.state.money.floor());
    final said = helpTheBeggar(500);
    expect(said.join('|'), isNot(contains("You're broke too")));
    expect(said.last, contains('danced his way off'));
  });

  test('with too little gold the Beggar calls you broke', () {
    final said = helpTheBeggar(499);
    expect(said.join('|'), contains("You're broke too"));
  });
}
