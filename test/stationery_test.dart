import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/commerce_screen.dart';
import 'package:d30mode/ui/stationery_card.dart';
import 'package:d30mode/ui/stationery_draw.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  test('Thursday batch survives reload, locks redraws, claims only once', () {
    final game = Game.newRun(pack, random: Random(1));
    game.state.cookies = 0;
    for (final day in [16, 17, 18, 20, 21, 22]) {
      game.state.date = GameDate(DateTime(2023, 10, day), 0);
      expect(game.beginWeeklyStationeryDraw(), isFalse);
    }
    game.state.date = GameDate(DateTime(2023, 10, 19), 0);
    expect(game.beginWeeklyStationeryDraw(), isTrue);
    final cards = List.of(game.state.pendingStationery);
    final saved = GameState.fromJson(pack, game.state.toJson());
    expect(saved.pendingStationery, cards);
    expect(saved.stationeryDrawDay, game.state.date.dayCode);
    final resumed = Game(pack: pack, state: saved);
    expect(resumed.beginWeeklyStationeryDraw(), isTrue);
    expect(resumed.state.pendingStationery, cards);
    game.state.stationeryLocks.add(0);
    expect(game.redrawStationery(), isTrue);
    expect(game.state.pendingStationery[0], cards[0]);
    for (final id in game.state.pendingStationery.skip(1)) {
      expect(pack.stationery[id]!['rank'], isNot('C'));
    }
    expect(game.state.cookies, 0);
    expect(game.redrawStationery(), isFalse);
    game.state.cookies = 1;
    expect(game.redrawStationery(), isTrue);
    expect(game.state.cookies, 0);
    game.claimStationeryDraw();
    game.claimStationeryDraw();
    expect(
      game.state.stationeryInventory.values.fold(0, (int n, v) => n + v),
      5,
    );
    expect(game.beginWeeklyStationeryDraw(), isFalse);
    game.state.date = GameDate(DateTime(2023, 10, 26), 0);
    expect(game.beginWeeklyStationeryDraw(), isTrue);
  });

  test('rank-weighted draws make S rare independently of catalog counts', () {
    final game = Game.newRun(pack, random: Random(71));
    final counts = <String, int>{};
    for (var week = 0; week < 2000; week++) {
      game.state.date = GameDate(DateTime(2023, 10, 19 + 7 * week), 0);
      expect(game.beginWeeklyStationeryDraw(), isTrue);
      for (final id in game.state.pendingStationery) {
        final rank = pack.stationery[id]!['rank'] as String;
        counts[rank] = (counts[rank] ?? 0) + 1;
      }
      game.claimStationeryDraw();
    }
    expect(counts['S'], inInclusiveRange(60, 140));
    expect(counts['C'], greaterThan(counts['B']!));
    expect(counts['B'], greaterThan(counts['A']!));
    expect(counts['A'], greaterThan(counts['S']!));
  });

  test('combination consumes duplicate copies and reserves equipped copy', () {
    final game = Game.newRun(pack, random: Random(2));
    final id = pack.stationery.keys.first;
    game.state.stationeryInventory[id] = 4;
    game.equipStationery(id);
    final before = Map.of(game.state.stationeryInventory);
    expect(game.combineStationery([id, id, id, id]), isNull);
    expect(game.state.stationeryInventory, before);
    game.state.stationeryInventory[id] = 5;
    final result = game.combineStationery([id, id, id, id]);
    expect(result, isNotNull);
    expect(
      game.state.stationeryInventory.values.fold(0, (int n, v) => n + v),
      2,
    );
    expect(game.state.stationeryInventory[id], greaterThanOrEqualTo(1));
    expect(game.state.equippedStationery.values, contains(id));
    final after = Map.of(game.state.stationeryInventory);
    expect(game.combineStationery([999999, id, id, id]), isNull);
    expect(game.state.stationeryInventory, after);
  });

  test(
    'combine uses editable distributions rather than guaranteed upgrade',
    () {
      final game = Game.newRun(pack, random: Random(99));
      final id = pack.stationery.entries
          .firstWhere((e) => e.value['rank'] == 'C')
          .key;
      game.state.stationeryInventory[id] = 4000;
      final counts = <String, int>{};
      for (var i = 0; i < 1000; i++) {
        final result = game.combineStationery([id, id, id, id])!;
        final rank = pack.stationery[result]!['rank'] as String;
        counts[rank] = (counts[rank] ?? 0) + 1;
      }
      expect(counts['B'], inInclusiveRange(150, 250));
      expect(counts.keys, unorderedEquals(['B', 'C']));
    },
  );

  test('four-piece set bonus is applied once and removed with a piece', () {
    final game = Game.newRun(pack);
    final set = pack.stationerySets.first;
    final ids = (set['equipmentItemIds'] as List).cast<int>();
    for (final id in ids) {
      game.state.stationeryInventory[id] = 1;
      game.equipStationery(id);
    }
    expect(game.state.activeStationerySets, [set]);
    for (final subject in pack.manifest.subjects) {
      num expected = 0;
      for (final row in [
        for (final id in ids) ...(pack.stationery[id]!['studyStats'] as List),
        ...(set['studyStats'] as List),
      ].cast<Map>()) {
        if (row['isAll'] == true || row['subjectType'] == subject) {
          expected += row['stat'] as num;
        }
      }
      expect(game.state.stationeryBonus(subject), expected);
    }
    game.state.equippedStationery.remove(pack.stationery[ids.last]!['type']);
    expect(game.state.activeStationerySets, isEmpty);
  });

  testWidgets(
    'compact menu sorts tiers and renders four removable combine slots',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      for (final rank in ['C', 'B', 'A', 'S']) {
        final id = pack.stationery.entries
            .firstWhere((e) => e.value['rank'] == rank)
            .key;
        game.state.stationeryInventory[id] = 4;
      }
      await tester.pumpWidget(
        MaterialApp(home: CommerceScreen(game: game, stationery: true)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<StationeryCard>(find.byType(StationeryCard))
            .map((w) => w.item['rank']),
        ['S', 'A', 'B', 'C'],
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Combine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StationeryCard).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('combine-slot-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('remove-material-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('combine-slot-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Thursday draw fits narrow screen and lock overlays remain visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      game.state.date = GameDate(DateTime(2023, 10, 19), 0);
      game.beginWeeklyStationeryDraw();
      await tester.pumpWidget(MaterialApp(home: StationeryDraw(game: game)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('draw-card-0')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
