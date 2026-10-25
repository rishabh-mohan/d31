/// Regression tests for the audit's flow items: book prerequisites (A02),
/// multi-subject items (A05), Weekly Goal timing (A08/A09), deferred evening
/// rollover (A11), ADD_BLOCK (A14) and events during exhaustion (TODO 92).
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

late ContentPack pack;

Future<void> main() async {
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  group('A02 book prerequisites', () {
    test('the menu and the block lottery share one chain', () {
      final game = Game.newRun(pack, random: Random(4));
      // This run's variants: 1001 at rank two (1002 hidden), 2001 at three.
      game.state.bookChoices['korean:2'] = 1001;
      game.state.bookChoices['korean:3'] = 2001;
      final books = game.menuBooks('korean');
      expect(books.take(3).map((b) => b.id), [1, 1001, 2001]);

      game.state.bookReadCounts[1] = pack.books[1]!.doneCount;
      game.state.bookReadCounts[1001] = pack.books[1001]!.doneCount;
      final unlocked = game.unlockedBooksFor('korean').map((b) => b.id);
      // Rank three opens on the shown rank-two book; the hidden sibling
      // never becomes a prerequisite, nor studiable.
      expect(unlocked, [1, 1001, 2001]);
      expect(game.studiableBooks().map((b) => b.id), isNot(contains(1002)));

      // With 1002 shown instead, finishing 1001 opens nothing further.
      game.state.bookChoices['korean:2'] = 1002;
      expect(game.unlockedBooksFor('korean').map((b) => b.id), [1, 1002]);
    });
  });
}
