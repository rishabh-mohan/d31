/// kss16's items and traits are general content: merged beneath every pack,
/// the pack's own ids always winning. Events are not part of the layer.
library;

import 'dart:io';

import 'package:d30mode/engine/base_content.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> layerFiles;
  late ContentPack kss16;
  late ContentPack workshopBare;
  late ContentPack kss20Bare;

  Future<ContentPack> load(String dir) =>
      ContentSource.loadFromDirectory(Directory(dir));

  setUpAll(() async {
    BaseContent.use({});
    kss16 = await load('packs/kss16');
    layerFiles = {
      for (final name in ['items.json', 'traits.json'])
        name: File('packs/kss16/$name').readAsStringSync(),
    };
    workshopBare = await load('examples/packs/workshop');
    kss20Bare = await load('packs/kss20');
  });

  setUp(() => BaseContent.use(layerFiles));
  tearDown(() => BaseContent.use({}));

  test('every campaign gains the items kss16 has that it lacks', () async {
    final workshop = await load('examples/packs/workshop');
    final missing = kss16.items.keys.where(
      (id) => !workshopBare.items.containsKey(id),
    );
    expect(missing, isNotEmpty);
    for (final id in missing) {
      expect(workshop.items[id]?.name, kss16.items[id]!.name);
    }
    expect(workshop.items.length, greaterThan(workshopBare.items.length));
  });

  test('a pack\'s own item and trait beat the layer on the same id', () async {
    final kss20 = await load('packs/kss20');
    for (final entry in kss20Bare.items.entries) {
      expect(kss20.items[entry.key]!.name, entry.value.name);
    }
    for (final entry in kss20Bare.traits.entries) {
      expect(kss20.traits[entry.key]!.name, entry.value.name);
    }
  });

  test('traits from the layer carry no story scope', () async {
    final workshop = await load('examples/packs/workshop');
    final scoped = kss16.traits.values.where((t) => t.storyId != null);
    expect(scoped, isNotEmpty);
    var checked = 0;
    for (final trait in scoped) {
      if (workshopBare.traits.containsKey(trait.id)) continue;
      expect(workshop.traits[trait.id]!.storyId, isNull, reason: trait.name);
      checked++;
    }
    expect(checked, greaterThan(0));
  });

  test('events, scenes, switches and sets are not merged', () async {
    for (final dir in ['examples/packs/workshop', 'packs/kss20']) {
      final bare = dir.contains('kss20') ? kss20Bare : workshopBare;
      final pack = await load(dir);
      expect(pack.events.keys.toSet(), bare.events.keys.toSet(), reason: dir);
      expect(pack.nodes.length, bare.nodes.length, reason: dir);
      expect(pack.switchDefaults.length, bare.switchDefaults.length);
      expect(pack.eventSets.length, bare.eventSets.length);
      expect(pack.speakers.length, bare.speakers.length);
    }
  });

  test('a pack without the layer loads exactly as its files say', () {
    BaseContent.use({});
    expect(
      workshopBare.traits.keys.toSet().difference(kss16.traits.keys.toSet()),
      isEmpty,
    );
  });
}
