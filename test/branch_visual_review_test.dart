import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/commerce_screen.dart';
import 'package:d30mode/ui/day_menu.dart';
import 'package:d30mode/ui/score_card.dart';
import 'package:d30mode/ui/stationery_draw.dart';

void main() {
  if (!const bool.fromEnvironment('RENDER_REVIEW')) return;
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    final font = FontLoader('Ahem')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
          ),
        ),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'C:/Users/stewc/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    await icons.load();
  });
  testWidgets('interrupted branch UI review at Nord width', (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = Game.newRun(pack);
    game.state.announcedGoalWeek = game.state.weeklyGoal?.weekIndex;
    for (final rank in ['S', 'A', 'B', 'C']) {
      for (final entry
          in pack.stationery.entries
              .where((e) => e.value['rank'] == rank)
              .take(4)) {
        game.state.stationeryInventory[entry.key] = 2;
      }
    }
    game.equipStationery(game.state.stationeryInventory.keys.first);
    final result = game.takeCsat();
    final screens = <String, Widget>{
      'stationery-grid': CommerceScreen(game: game, stationery: true),
      'day-menu': Scaffold(
        body: DayMenu(game: game, onStart: () {}),
      ),
      'score-card': Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ExamScoreCard(name: game.state.fullName, result: result),
          ),
        ),
      ),
    };
    for (final entry in screens.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Ahem'),
          home: RepaintBoundary(
            key: const ValueKey('review'),
            child: entry.value,
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull, reason: entry.key);
      await expectLater(
        find.byKey(const ValueKey('review')),
        matchesGoldenFile('../build/branch-review/${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    game.state.date = GameDate(DateTime(2023, 10, 19), 0);
    game.beginWeeklyStationeryDraw();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Ahem'),
        home: RepaintBoundary(
          key: const ValueKey('review'),
          child: StationeryDraw(game: game),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stop-all-stationery')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byKey(const ValueKey('review')),
      matchesGoldenFile('../build/branch-review/stationery-confetti.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
