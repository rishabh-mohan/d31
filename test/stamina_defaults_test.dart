import 'dart:convert';

import 'dart:io';

import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Workshop fixture with its single location rebuilt from [actions], and
/// extra `rules.json` sections merged in.
Game gameWith(
  List<Map<String, dynamic>> actions, {
  Map<String, dynamic> rules = const {},
  String locationType = 'none',
  Map<String, String> extraFiles = const {},
}) {
  final files = <String, String>{};
  for (final name in ContentPack.allFiles) {
    final file = File('examples/packs/workshop/$name');
    if (file.existsSync()) files[name] = file.readAsStringSync();
  }
  files['locations.json'] = jsonEncode({
    'locations': [
      {'id': 801, 'name': 'Workshop', 'type': locationType, 'actions': actions},
    ],
  });
  files.addAll(extraFiles);
  files['rules.json'] = jsonEncode({
    ...jsonDecode(files['rules.json']!) as Map<String, dynamic>,
    ...rules,
  });
  return Game.newRun(ContentPack.fromFiles(files));
}

ActionPreview previewOf(Game game, String type) => game.preview(
  game.pack.locations[801]!.actions.firstWhere((a) => a.actionType == type),
);

Map<String, dynamic> action(String type, [num? hpWeight]) => {
  'locationActionType': type,
  'hpWeight': ?hpWeight,
};

void main() {
  const types = ['study', 'lesson', 'exercise', 'partTimeJob'];

  test('a pack that sets nothing gets the engine defaults', () {
    final game = gameWith([for (final t in types) action(t), action('sleep')]);
    expect(previewOf(game, 'study').hpCost, 16);
    expect(previewOf(game, 'lesson').hpCost, 9);
    expect(previewOf(game, 'exercise').hpCost, 24);
    expect(previewOf(game, 'partTimeJob').hpCost, 29);
    expect(previewOf(game, 'sleep').gain, 10);
  });

  test('sleep restores 3 more at a location of type sleep', () {
    final game = gameWith([action('sleep')], locationType: 'sleep');
    expect(previewOf(game, 'sleep').gain, 13);
  });

  test('a stamina weight adds perWeight on top of the type default', () {
    final game = gameWith([action('study', 1)]); // 16 + 6.25 = 22.25
    expect(previewOf(game, 'study').hpCost, 22);
  });

  test(
    'a pack that sets every staminaCost type uses its own numbers (kss16 style)',
    () {
      final game = gameWith(
        [
          action('study', 1),
          action('exercise', 2.5),
          action('partTimeJob', 3),
          action('lesson'),
        ],
        rules: {
          'staminaCost': {
            'study': 9.5,
            'exercise': 9.5,
            'partTimeJob': 9.5,
            'perWeight': 6.25,
            'lesson': 9,
          },
          'day': {'sleepRestoresHp': 10, 'sleepLocationBonusHp': 3},
        },
      );
      expect(previewOf(game, 'study').hpCost, 16); // 9.5 + 6.25
      expect(previewOf(game, 'exercise').hpCost, 25); // 9.5 + 15.625
      expect(previewOf(game, 'partTimeJob').hpCost, 28); // 9.5 + 18.75
      expect(previewOf(game, 'lesson').hpCost, 9);
    },
  );

  test('a per-type staminaCost key wins; other types keep their default', () {
    final game = gameWith(
      [action('study'), action('exercise')],
      rules: {
        'staminaCost': {'study': 12},
      },
    );
    expect(previewOf(game, 'study').hpCost, 12);
    expect(previewOf(game, 'exercise').hpCost, 24);
  });

  test('the default study case gives 15: an E-tier book (power 5) x studyWeight 3 at level 1', () {
    // kss16 baseline: tiers E..S are bookRank "1".."6" with power 5, 7, 10, 15, 22, 35.
    final book = {
      'id': 1,
      'name': 'Book E',
      'subject': 'craft',
      'power': 5,
      'doneCount': 8,
      'bookRank': '1',
    };
    final game = gameWith(
      [action('study')],
      extraFiles: {
        'books.json': jsonEncode({
          'books': [book],
        }),
      },
    );
    expect(
      game.pack.rules.studyWeight,
      3,
    ); // the engine default now matches kss16
    final preview = game.preview(
      game.pack.locations[801]!.actions.first,
      book: game.pack.books[1],
    );
    // No combo (first block), study level 1 (weight 1, +0), no traits, items or stationery.
    expect(preview.gain, 15);
  });

  test('the other defaults follow the kss16 baseline', () {
    // The Workshop fixture pins random events to 0; clear its events section to see the defaults.
    final rules = gameWith([action('study')], rules: {'events': {}}).pack.rules;
    expect(rules.partTimeBaseMoney, 500);
    expect(rules.randomEventChance, 0.06);
    expect(rules.maxEventsPerDay, 1);
    expect(rules.sleepRestoresHp, 10);
    expect(rules.sleepLocationBonusHp, 3);
  });
}
