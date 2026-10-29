/// Student XP: an E-tier book and a class block give `study.expPerStudy`, and
/// each book tier above adds `study.expPerTier`. 31-Day Mode shows the
/// catalog's level thresholds at 0.33 (the captures read 0/495 and .../4950).
library;

import 'dart:convert';
import 'dart:io';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stamina_defaults_test.dart' show action, gameWith;

Map<String, String> booksOfEveryTier() => {
  'books.json': jsonEncode({
    'books': [
      for (var rank = 1; rank <= 6; rank++)
        {
          'id': rank,
          'name': 'Book $rank',
          'subject': 'craft',
          'power': rank,
          'doneCount': 99,
          'bookRank': '$rank',
        },
    ],
  }),
};

/// XP one study block with book [id] adds.
num xpOf(Game game, int id) {
  game.state.hp = game.pack.rules.hpMax;
  final before = game.state.studyExp;
  game.act(game.pack.locations[801]!.actions.first, book: game.pack.books[id]);
  return game.state.studyExp - before;
}

void main() {
  test('the default is 100 for an E book and 100 more for each tier above', () {
    final game = gameWith([action('study')], extraFiles: booksOfEveryTier());
    expect(game.pack.rules.studyExp, 100);
    expect(game.pack.rules.studyExpPerTier, 100);
    expect([for (var id = 1; id <= 6; id++) xpOf(game, id)], [100, 200, 300, 400, 500, 600]);
  });

  test('a pack\'s own numbers rule, and a tier step of 0 makes every book equal', () {
    var game = gameWith(
      [action('study')],
      extraFiles: booksOfEveryTier(),
      rules: {
        'study': {'expPerStudy': 25, 'expPerTier': 10},
      },
    );
    expect([for (var id = 1; id <= 6; id++) xpOf(game, id)], [25, 35, 45, 55, 65, 75]);
    game = gameWith(
      [action('study')],
      extraFiles: booksOfEveryTier(),
      rules: {
        'study': {'expPerStudy': 40, 'expPerTier': 0},
      },
    );
    expect([for (var id = 1; id <= 6; id++) xpOf(game, id)], everyElement(40));
  });

  test('a block with no book counts as E', () {
    final game = gameWith([action('study')], extraFiles: booksOfEveryTier());
    game.state.hp = game.pack.rules.hpMax;
    final before = game.state.studyExp;
    game.act(game.pack.locations[801]!.actions.first);
    expect(game.state.studyExp - before, 100);
  });

  // Local pack data (never published): kss16 shows 31-Day Mode's scale.
  final hasPacks = Directory('packs/kss16').existsSync() && Directory('packs/kss20').existsSync();
  test('31-Day Mode thresholds are 0.33 of the catalog\'s; Retry Year keeps the catalog\'s', () async {
    final kss16 = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    final kss20 = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    final thirtyOne = [for (final t in kss16.studyLevels.tiers) t.exp];
    expect(thirtyOne, [0, 495, 4950, 13200, 23100, 33000, 49500, 66000, 99000, 165000]);
    expect(kss16.studyLevels.nextThresholdAfter(0), 495);
    expect(kss16.studyLevels.tierFor(700).level, 2); // the capture's LV2 at 700
    expect(kss16.studyLevels.nextThresholdAfter(700), 4950);
    expect([for (final t in kss20.studyLevels.tiers) t.exp].take(3), [0, 1500, 15000]);
    for (final pack in [kss16, kss20]) {
      expect(pack.rules.studyExp, 100);
      expect(pack.rules.studyExpPerTier, 100);
    }
  }, skip: !hasPacks);
}
