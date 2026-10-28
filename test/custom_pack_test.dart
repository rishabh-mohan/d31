import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/engine/event_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentPack pack;
  setUp(() async {
    pack = await ContentSource.loadFromDirectory(
      Directory('examples/packs/workshop'),
    );
  });

  test('independent pack owns blocks, traits, characters and callbacks', () {
    final game = Game.newRun(pack);
    game.state.characterId = 70;
    game.state.grantTrait(69);
    expect(game.traits.staminaFree(game.state), isTrue);
    expect(game.availableActions().any((a) => a.funcCode == 'CRAFT'), isFalse);
    game.effects.applyChanger({
      'funcCode': 'ENABLE_BLOCK',
      'args': ['bench'],
    }, game.state);
    expect(game.availableActions().any((a) => a.funcCode == 'CRAFT'), isTrue);
    game.effects.applyChanger({'funcCode': 'CRAFT'}, game.state);
    expect(game.state.stats['craft'], 5);
    expect(game.state.money, 10);
    expect(game.state.switchValue('CRAFT_COUNT'), 1);
    final resumed = GameState.fromJson(
      pack,
      jsonDecode(jsonEncode(game.state.toJson())),
    );
    final next = Game(pack: pack, state: resumed);
    expect(next.availableActions().any((a) => a.funcCode == 'CRAFT'), isTrue);
    next.effects.applyChanger({
      'funcCode': 'DISABLE_BLOCK',
      'args': ['crafting'],
    }, resumed);
    expect(next.availableActions().any((a) => a.funcCode == 'CRAFT'), isFalse);
    expect(game.effects.unknownFuncCodes, isEmpty);
  });

  test('catalog IDs alone never imply campaign behavior', () {
    final files = {...pack.sourceFiles}..remove('mechanics.json');
    final plain = ContentPack.fromFiles(files);
    final game = Game.newRun(plain);
    game.state.characterId = 70;
    game.state.grantTrait(69);
    expect(game.traits.staminaFree(game.state), isFalse);
    expect(game.blockGateOpen('MEDICAL_BLOCK_CONDITION'), isFalse);
    expect(
      game.availableActions().map((a) => a.text),
      isNot(contains('Make a keepsake')),
    );
  });

  test(
    'custom action resolves through the normal turn and expands its macro',
    () {
      final game = Game.newRun(pack);
      game.state.characterId = 70;
      game.state.grantTrait(69);
      game.effects.applyChanger({
        'funcCode': 'ENABLE_BLOCK',
        'args': ['crafting'],
      }, game.state);
      final action = game.availableActions().singleWhere(
        (a) => a.funcCode == 'CRAFT',
      );
      final tick = game.state.date.tick;
      game.act(action);
      expect(game.state.date.tick, tick + 1);
      expect(game.state.stats['craft'], 5);
      expect(game.state.money, 10);
      expect(expandEventText('{CRAFT_COUNT}', game.state), '1');
    },
  );

  test(
    'custom study bonus previews are stable and match the resolved payout',
    () {
      final mechanics = jsonDecode(pack.sourceFiles['mechanics.json']!);
      (mechanics['traitAbilities']['69'] as List).add({
        'type': 'studyRandomStat',
        'chance': 1,
        'value': 4,
      });
      final custom = ContentPack.fromFiles({
        ...pack.sourceFiles,
        'mechanics.json': jsonEncode(mechanics),
      });
      final game = Game.newRun(custom);
      game.state.grantTrait(69);
      game.state.randomSubject = 'craft';
      final action = game.availableActions().firstWhere(
        (a) => a.actionType == 'study',
      );
      final preview = game.preview(action);
      for (var i = 0; i < 5; i++) {
        expect(game.preview(action).bonusSubject, preview.bonusSubject);
        expect(game.preview(action).bonusGain, 4);
      }
      final before = game.state.totalStat;
      game.act(action);
      expect(game.state.totalStat - before, preview.gain! + 4);
    },
  );

  test('callback ability chance zero withholds only its own reward', () {
    final mechanics = jsonDecode(pack.sourceFiles['mechanics.json']!);
    mechanics['traitAbilities']['69'][1]['chance'] = 0;
    final custom = ContentPack.fromFiles({
      ...pack.sourceFiles,
      'mechanics.json': jsonEncode(mechanics),
    });
    final game = Game.newRun(custom);
    game.state.characterId = 70;
    game.state.grantTrait(69);
    game.effects.applyChanger({'funcCode': 'CRAFT'}, game.state);
    expect(game.state.money, 7);
    expect(game.state.stats['craft'], 5);
  });

  test('custom block character gate remains pack scoped', () {
    final game = Game.newRun(pack);
    game.effects.applyChanger({
      'funcCode': 'ENABLE_BLOCK',
      'args': ['crafting'],
    }, game.state);
    expect(game.availableActions().any((a) => a.funcCode == 'CRAFT'), isFalse);
    game.state.characterId = 70;
    expect(game.availableActions().any((a) => a.funcCode == 'CRAFT'), isTrue);
  });

  test('direct expression conditions gate actions and unknown expressions fail closed', () {
    final game = Game.newRun(pack);
    final condition = <String, dynamic>{
      'eq': [
        {'field': 'characterId'},
        70,
      ],
    };
    expect(game.conditions.evaluate(condition, game.state), isFalse);
    game.state.characterId = 70;
    expect(game.conditions.evaluate(condition, game.state), isTrue);
    expect(game.conditions.evaluate({'unknown': 1}, game.state), isFalse);
    expect(game.conditions.unknownTargets, isNotEmpty);
  });

  test(
    'absolute editable custom packs are discovered and loaded without a bundle',
    () async {
      ContentSource.rootsOverride = [Directory('examples/packs').absolute];
      addTearDown(() => ContentSource.rootsOverride = null);
      expect(await ContentSource.availablePackIds(), contains('workshop'));
      final (loaded, location) = await ContentSource.load(packId: 'workshop');
      expect(loaded.manifest.id, 'workshop');
      expect(location.directory!.isAbsolute, isTrue);
    },
  );

  test(
    'malformed mechanics fail when loading with useful file attribution',
    () {
      for (final data in [
        {'version': 2},
        {
          'version': 1,
          'callbacks': {
            'BAD': [
              {'op': 'nativeCode'},
            ],
          },
        },
        {
          'version': 1,
          'callbacks': {
            'BAD': [
              {'op': 'addStat', 'value': 4},
            ],
          },
        },
        {
          'version': 1,
          'predicates': {
            'BAD': {'unknownExpression': 1},
          },
        },
        {
          'version': 1,
          'predicates': {
            'BAD': {'predicate': 'BAD'},
          },
        },
        {
          'version': 1,
          'predicates': {
            'BAD': {
              'randomInt': [0, 1],
            },
          },
        },
        {
          'version': 1,
          'blocks': [
            {'id': 'incomplete'},
          ],
        },
      ]) {
        expect(
          () => ContentPack.fromFiles({
            ...pack.sourceFiles,
            'mechanics.json': jsonEncode(data),
          }),
          throwsA(
            isA<PackFormatException>().having(
              (e) => e.file,
              'file',
              'mechanics.json',
            ),
          ),
        );
      }
    },
  );
}
