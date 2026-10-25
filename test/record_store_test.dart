/// History records and the account file. Plain `test`s: real file I/O inside
/// `testWidgets` runs in a FakeAsync zone and never completes.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/record_store.dart';

void main() {
  late ContentPack pack;
  late Directory temp;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('d30-records');
    RecordStore.directoryOverride = temp;
    AccountStore.fileOverride = File('${temp.path}/account.json');
    AccountStore.current = Account();
  });

  tearDown(() async {
    RecordStore.directoryOverride = null;
    AccountStore.fileOverride = null;
    AccountStore.current = Account();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('a finished run is recorded with what History shows', () async {
    final game = Game.newRun(pack);
    game.state.firstName = 'Greg';
    game.state.lastName = 'Fiasco';
    game.state.stats['korean'] = 300;
    game.state.endingLabel = 'Realisation';
    game.concludeRun();

    final record = await RecordStore.add(game.state, ending: game.outcome);
    expect(record, isNotNull);

    final records = await RecordStore.list();
    expect(records, hasLength(1));
    final r = records.single;
    expect(r.name, 'Greg Fiasco');
    expect(r.ending, 'Realisation');
    expect(r.modeTitle, pack.manifest.name);
    expect(r.portrait, game.state.portrait);
    expect(r.stats['korean'], 300);
    expect(r.packId, 'kss16');
  });

  test('records list newest first and delete one at a time', () async {
    for (final name in ['First', 'Second']) {
      final game = Game.newRun(pack)..state.firstName = name;
      await RecordStore.add(game.state, ending: 'Done');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final records = await RecordStore.list();
    expect(records.map((r) => r.name.split(' ').first), ['Second', 'First']);

    await RecordStore.delete(records.first.id);
    expect((await RecordStore.list()).single.name, startsWith('First'));
  });

  test('a corrupt record is skipped', () async {
    await File('${temp.path}/record_0.json').writeAsString('{nope');
    await RecordStore.add(Game.newRun(pack).state, ending: 'Done');
    expect(await RecordStore.list(), hasLength(1));
  });

  test('the account round-trips its wallet and university setting', () async {
    expect((await AccountStore.load()).universities, UniversitySet.korean);
    AccountStore.current
      ..cookies = 53
      ..refreshTokens = 522
      ..universities = UniversitySet.us;
    expect(await AccountStore.save(), isTrue);

    AccountStore.current = Account();
    final loaded = await AccountStore.load();
    expect(loaded.cookies, 53);
    expect(loaded.refreshTokens, 522);
    expect(loaded.universities, UniversitySet.us);
  });
}
