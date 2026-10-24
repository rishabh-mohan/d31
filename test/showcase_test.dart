import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/showcase.dart';
import 'package:d30mode/ui/event_screen.dart';

void main() {
  for (final packId in ['kss16', 'kss20']) {
    testWidgets('$packId: every NPC with art speaks, and nothing is saved', (
      tester,
    ) async {
      final pack = await tester.runAsync(
        () => ContentSource.loadFromDirectory(Directory('packs/$packId')),
      );
      final game = Game.newRun(pack!);
      final before = game.state.toJson();
      final cast = CharacterShowcase.lines(pack);
      final npcs = (pack.presentation['npcs'] as Map).keys.length;
      expect(cast.map((l) => l.$1).toSet().length, npcs);

      final run = CharacterShowcase.begin(game);
      final seen = <int>{};
      for (var i = 0; i < cast.length; i++) {
        expect(run.portraitId, cast[i].$1);
        expect(run.portraitExpression, cast[i].$2);
        expect(run.current!.speakerName, isNot('???'));
        seen.add(run.portraitId!);
        run.advance();
      }
      expect(run.current?.isEnd ?? true, isTrue);
      expect(seen.length, npcs);
      CharacterShowcase.cleanUp(game.state);
      expect(game.state.toJson()['eventStates'], before['eventStates']);
      expect(game.state.toJson()['eventCounts'], before['eventCounts']);

      // And it renders: the first speaker on the event screen.
      final again = CharacterShowcase.begin(game);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: EventScreen(run: again)));
      await tester.pump();
      expect(find.textContaining(cast.first.$3), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
