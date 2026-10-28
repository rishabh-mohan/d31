import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/commerce_screen.dart';
import 'package:d30mode/ui/day_menu.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/ui/stationery_card.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  test(
    'combination accepts two to four copies and rejects one or five atomically',
    () {
      for (final count in [0, 1, 2, 3, 4, 5]) {
        final game = Game.newRun(pack, random: Random(7));
        final id = pack.stationery.keys.first;
        game.state.stationeryInventory[id] = 10;
        game.equipStationery(id);
        final result = game.combineStationery(List.filled(count, id));
        if (count >= 2 && count <= 4) {
          expect(result, isNotNull);
          expect(
            game.state.stationeryInventory.values.fold(0, (int a, b) => a + b),
            11 - count,
          );
        } else {
          expect(result, isNull);
          expect(game.state.stationeryInventory, {id: 10});
        }
        expect(game.state.equippedStationery.values, contains(id));
      }
    },
  );

  for (final width in [320.0, 393.0]) {
    testWidgets('hub names, previews and four-tab navigation fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      for (final type in ['pencil', 'eraser', 'note', 'markingPen']) {
        final entries =
            pack.stationery.entries
                .where((e) => e.value['type'] == type)
                .toList()
              ..sort(
                (a, b) => (b.value['name'] as String).length.compareTo(
                  (a.value['name'] as String).length,
                ),
              );
        game.state.stationeryInventory[entries.first.key] = 1;
        game.equipStationery(entries.first.key);
      }
      final before = game.state.date;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayMenu(game: game, onStart: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // A fresh goal announces itself over the hub; acknowledge it first.
      await tester.tap(find.text("Let's do this!"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hub-traits-scroll')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('open-stationery'))).height,
        lessThan(
          tester.getSize(find.byKey(const ValueKey('open-store'))).height,
        ),
      );
      expect(find.byType(StationeryCard), findsNWidgets(4));
      for (final id in game.state.equippedStationery.values) {
        final name = find.text(pack.stationery[id]!['name'] as String);
        expect(name, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
          isFalse,
        );
      }
      final preview = tester.widget<Text>(
        find.byKey(const ValueKey('store-preview-8')),
      );
      expect(preview.data, pack.items[8]!.effectText);
      expect(preview.maxLines, 1);
      expect(preview.overflow, TextOverflow.ellipsis);
      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();
      expect(find.text('E'), findsOneWidget);
      expect(find.text('Korean +15'), findsOneWidget);
      for (final tab in ['items', 'shop', 'stationery', 'books']) {
        await tester.tap(find.byKey(ValueKey('menu-tab-$tab')));
        await tester.pumpAndSettle();
        expect(find.byType(CommerceScreen), findsOneWidget);
      }
      expect(game.state.date, before);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(DayMenu), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('two selected cards can be combined from the expanded menu', (
    tester,
  ) async {
    final game = Game.newRun(pack);
    final id = pack.stationery.keys.first;
    game.state.stationeryInventory[id] = 3;
    await tester.pumpWidget(
      MaterialApp(home: CommerceScreen(game: game, stationery: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Combine'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(ValueKey('stationery-$id')).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Combine'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    expect(
      game.state.stationeryInventory.values.fold(0, (int a, b) => a + b),
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'countdown weekday and gold sit centered inside their header cells',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(pack);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            game: game,
            packLocation: PackLocation('kss16', null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final row in [
        ('header-countdown', 'D-31'),
        ('header-weekday', 'Mon'),
        ('header-gold', '0 Gold'),
      ]) {
        final cell = tester.getCenter(find.byKey(ValueKey(row.$1)));
        final text = tester.getCenter(
          find.descendant(
            of: find.byKey(ValueKey(row.$1)),
            matching: find.text(row.$2),
          ),
        );
        expect((cell - text).distance, lessThan(.5));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
