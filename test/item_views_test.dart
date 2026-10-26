import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/inventory_screen.dart';
import 'package:d30mode/ui/item_views.dart';

/// The checking items' views (project design) render at phone size without
/// overflow, and the bag offers Use/Check only where something happens.
void main() {
  late ContentPack original;
  late ContentPack retry;
  setUpAll(() async {
    original = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  Future<void> phone(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Game game(ContentPack pack) {
    final g = Game.newRun(pack, random: Random(9));
    g.state.openingComplete = true;
    return g;
  }

  Widget dialog(Widget child) => Scaffold(
    body: Center(child: ItemViewDialog(child: child)),
  );

  testWidgets('predicted grades fit a phone', (tester) async {
    final g = game(original);
    g.state.stats.updateAll((k, v) => 123456);
    await phone(tester, dialog(PredictedGradesView(state: g.state)));
    expect(find.text('Predicted Grades'), findsOneWidget);
    expect(find.text('Humnts.'), findsOneWidget);
    expect(find.textContaining('Standard score'), findsOneWidget);
    expect(find.textContaining('Overall grade'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abilities fit a phone, with comic progress once targeted', (
    tester,
  ) async {
    final g = game(original);
    final view = original.items[20018]!.effects.single;
    await phone(tester, dialog(AbilitiesView(state: g.state, view: view)));
    expect(find.text('Abilities'), findsOneWidget);
    expect(find.text('Comic'), findsNothing);
    expect(tester.takeException(), isNull);

    g.state.setSwitch('TARGET_DRAW_COUNT', 5);
    g.state.setSwitch('DRAW_COUNT', 2);
    g.state.setSwitch('TARGET_DRAW_KOREAN', 3);
    await phone(tester, dialog(AbilitiesView(state: g.state, view: view)));
    expect(find.text('Comic'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the recipe fits a phone and ticks held ingredients', (
    tester,
  ) async {
    final g = game(retry);
    g.state.addItem(80003);
    g.state.addItem(80004);
    g.state.addItem(80007);
    final view = retry.items[80011]!.effects.single;
    await phone(tester, dialog(RecipeView(state: g.state, view: view)));
    for (final id in [80012, 80013, 80014]) {
      expect(find.byKey(ValueKey('recipe-$id')), findsOneWidget);
    }
    expect(find.text('Red Potion'), findsOneWidget);
    // Only the Red Potion has all three ingredients.
    expect(find.text('Ready'), findsOneWidget);
    expect(find.textContaining('1000 Gold'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bag: Check the Scouter, open the Recipe, no Use for none', (
    tester,
  ) async {
    final g = game(retry);
    g.state.addItem(90021);
    g.state.addItem(80011);
    g.state.addItem(90001);
    g.state.setSwitch('SING_SW', 1);
    g.state.setSwitch('SING_TARGET', 4);
    await phone(tester, InventoryScreen(game: g));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('use-item-80011')));
    await settle(tester);
    expect(find.byKey(const ValueKey('recipes')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(g.state.itemCount(80011), 1);

    await tester.tap(find.text('Other Items'));
    await settle(tester);
    expect(find.byKey(const ValueKey('use-item-90001')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('use-item-90021')));
    await settle(tester);
    expect(find.textContaining('you will lose the next sing-off'), findsOne);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(g.state.itemCount(90021), 1);
  });

  testWidgets('the bag uses the Mock Exam Paper into its forecast', (
    tester,
  ) async {
    final g = game(original);
    g.state.addItem(30);
    g.state.addItem(20236);
    await phone(tester, InventoryScreen(game: g));
    await settle(tester);
    expect(find.byKey(const ValueKey('use-item-20236')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('use-item-30')));
    await settle(tester);
    expect(find.byKey(const ValueKey('predicted-grades')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(g.state.itemCount(30), 0);
  });
}
