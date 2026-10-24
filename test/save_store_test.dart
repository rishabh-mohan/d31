/// Save slots. These are plain `test`s on purpose: real file I/O inside
/// `testWidgets` runs in a FakeAsync zone and never completes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/save_store.dart';

void main() {
  late ContentPack pack;
  late ContentPack retry;
  late Directory temp;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('d30-saves');
    SaveStore.directoryOverride = temp;
  });

  tearDown(() async {
    SaveStore.directoryOverride = null;
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('a slot round-trips a run and lists without a pack', () async {
    final game = Game.newRun(pack);
    game.state.firstName = 'Greg';
    game.state.lastName = 'Fiasco';
    game.state.money = 1170;
    game.state.stats['korean'] = 527;
    game.state.date = GameDate(game.state.date.day, 6);
    game.state.saveSlot = 1;

    expect(await SaveStore.write(1, game.state), isTrue);

    final summaries = await SaveStore.list();
    expect(summaries.length, SaveStore.slots);
    expect(summaries[0], isNull);
    expect(summaries[2], isNull);
    expect(summaries[1]!.name, 'Greg Fiasco');
    expect(summaries[1]!.daysRemaining, game.state.daysRemaining);
    expect(summaries[1]!.stats['korean'], 527);

    final loaded = await SaveStore.read(1, pack);
    expect(loaded, isNotNull);
    expect(loaded!.fullName, 'Greg Fiasco');
    expect(loaded.money, 1170);
    expect(loaded.date.tick, 6);
    expect(loaded.saveSlot, 1);
    expect(loaded.stats['korean'], 527);
  });

  test('slots are independent and deletable', () async {
    final a = Game.newRun(pack)..state.firstName = 'A';
    final b = Game.newRun(pack)..state.firstName = 'B';
    await SaveStore.write(0, a.state);
    await SaveStore.write(2, b.state);

    expect((await SaveStore.list()).map((s) => s?.name), [
      'A ${a.state.lastName}'.trim(),
      null,
      'B ${b.state.lastName}'.trim(),
    ]);

    await SaveStore.delete(0);
    expect(await SaveStore.summary(0), isNull);
    expect(await SaveStore.read(0, pack), isNull);
    expect((await SaveStore.summary(2))!.name.startsWith('B'), isTrue);
  });

  test(
    'campaign identity selects Retry Year and prevents loading the wrong pack',
    () async {
      final game = Game.newRun(retry);
      expect(await SaveStore.write(0, game.state), isTrue);
      expect((await SaveStore.summary(0))!.packId, 'kss20');
      expect(await SaveStore.read(0, pack), isNull);
      final restored = await SaveStore.read(0, retry);
      expect(restored!.pack.manifest.storyId, 20);
      expect(restored.date, retry.manifest.startDate);
      expect(restored.switches, game.state.switches);
      await SaveStore.write(1, Game.newRun(pack).state);
      final file = File('${temp.path}/slot_1.json');
      final legacy =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      (legacy['summary'] as Map).remove('packId');
      await file.writeAsString(jsonEncode(legacy));
      expect((await SaveStore.summary(1))!.packId, 'kss16');
      expect(await SaveStore.read(1, pack), isNotNull);
    },
  );

  test('a corrupt slot reads as empty instead of throwing', () async {
    await File('${temp.path}/slot_0.json').writeAsString('{not json');
    expect(await SaveStore.summary(0), isNull);
    expect(await SaveStore.read(0, pack), isNull);
    expect((await SaveStore.list())[0], isNull);
  });

  test('a half-written slot cannot destroy the previous save', () async {
    final game = Game.newRun(pack)..state.firstName = 'Keep';
    await SaveStore.write(0, game.state);
    // What a kill mid-write leaves behind: the temp neighbour, never renamed.
    await File('${temp.path}/slot_0.json.tmp').writeAsString('{half');
    expect((await SaveStore.summary(0))!.name.startsWith('Keep'), isTrue);
  });

  test('an overwrite replaces the slot rather than appending', () async {
    final first = Game.newRun(pack)..state.firstName = 'First';
    await SaveStore.write(0, first.state);
    final second = Game.newRun(pack)..state.firstName = 'Second';
    await SaveStore.write(0, second.state);

    expect((await SaveStore.summary(0))!.name.startsWith('Second'), isTrue);
    final raw = jsonDecode(
      await File('${temp.path}/slot_0.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(raw['version'], 1);
    expect(raw['state'], isA<Map<String, dynamic>>());
  });

  test('saving is simply unavailable when there is no directory', () async {
    SaveStore.directoryOverride = null;
    // No documents directory is bound in a plain test host, so the store has
    // nowhere to write; it must report that rather than throw.
    final game = Game.newRun(pack);
    expect(await SaveStore.write(0, game.state), isFalse);
    expect(await SaveStore.list(), everyElement(isNull));
  });
}
