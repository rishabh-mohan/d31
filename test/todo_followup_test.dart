import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/setup.dart';
import 'package:d30mode/ui/day_menu.dart';
import 'package:d30mode/ui/event_screen.dart';
import 'package:d30mode/ui/my_info.dart';
import 'package:d30mode/ui/portrait.dart';
import 'package:d30mode/ui/setup_screen.dart';
import 'package:d30mode/ui/university_badge.dart';

void main() {
  late ContentPack pack;
  late ContentPack scene;
  setUpAll(() async {
    if (const bool.fromEnvironment('RENDER_REVIEW')) {
      final font = FontLoader('ReviewFont')
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
    }
    final files = <String, String>{};
    for (final name in ContentPack.allFiles) {
      final file = File('packs/kss16/$name');
      if (file.existsSync()) files[name] = file.readAsStringSync();
    }
    final rules = jsonDecode(files['rules.json']!) as Map<String, dynamic>;
    (rules['events'] as Map)['maxEventsPerDay'] = 0;
    files['rules.json'] = jsonEncode(rules);
    pack = ContentPack.fromFiles(files);
    files['events/events.json'] = jsonEncode({
      'events': [
        {'id': 1, 'name': 'Quizmaster', 'rootNodeId': 1},
      ],
      'nodes': [
        {
          'id': 1,
          'type': 'standing',
          'standingId': 2,
          'standingExpression': 'defaults',
          'nextNodeId': 2,
        },
        {
          'id': 2,
          'type': 'text',
          'speakerId': 2,
          'text': 'Here is a question.',
          'nextNodeId': 3,
        },
        {
          'id': 3,
          'type': 'option',
          'speakerId': 0,
          'text': 'What is two plus two?',
          'optionText': 'Choose your answer',
          'options': [
            {'text': 'Four', 'nextNodeId': 4},
          ],
        },
        {
          'id': 4,
          'type': 'text',
          'speakerId': 2,
          'standingExpression': '밝음',
          'text': 'Correct!',
          'nextNodeId': 5,
        },
        {'id': 5, 'type': 'standing', 'standingOff': true, 'nextNodeId': 6},
        {
          'id': 6,
          'type': 'text',
          'speakerId': 0,
          'text': 'He left.',
          'nextNodeId': 7,
        },
        {'id': 7, 'type': 'last'},
      ],
    });
    scene = ContentPack.fromFiles(files);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (const bool.fromEnvironment('RENDER_REVIEW')) {
      // Allow image codec tasks outside the fake clock to finish for review.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('review-frame')),
        matchesGoldenFile('../build/ui-review/$name.png'),
      );
    }
  }

  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(
      fontFamily: const bool.fromEnvironment('RENDER_REVIEW')
          ? 'ReviewFont'
          : null,
    ),
    home: RepaintBoundary(key: const ValueKey('review-frame'), child: child),
  );

  test('last action exhaustion has no popup, lost slots or penalty', () {
    for (final defer in [false, true]) {
      final game = Game.newRun(pack);
      game.state.date = GameDate(game.state.date.day, 13);
      game.state.hp = 1;
      final stats = Map.of(game.state.stats);
      final work = pack.locations[1000]!.actions.firstWhere(
        (a) => a.actionType == 'partTimeJob',
      );
      final outcome = game.act(work, deferExhaustion: defer);
      expect(outcome.exhausted, isFalse);
      expect(outcome.dayEnded, isTrue);
      expect(outcome.event, isNull);
      expect(game.state.exhaustionPending, isFalse);
      expect(game.state.date.tick, 0);
      expect(game.state.stats, stats);
      expect(game.state.hp, game.state.hpMax);
    }
  });

  test('penultimate action still exhausts and NPC standing persists for player speech', () {
    final game = Game.newRun(pack);
    game.state.date = GameDate(game.state.date.day, 12);
    game.state.hp = 1;
    final work = pack.locations[1000]!.actions.firstWhere(
      (a) => a.actionType == 'partTimeJob',
    );
    expect(game.act(work, deferExhaustion: true).exhausted, isTrue);
    final actorGame = Game.newRun(scene);
    final run = actorGame.events.begin(scene.events[1]!, actorGame.state);
    expect(run.portraitId, 2);
    run.advance();
    expect(run.current!.speakerName, 'Me');
    expect(run.portraitId, 2);
    run.choose(run.current!.choices.single);
    expect(run.portraitExpression, '밝음');
    run.advance();
    expect(run.portraitId, isNull);
  });

  test('all location cards and active crests resolve bundled art', () {
    for (final location in pack.locations.values) {
      expect(location.image, isNotNull, reason: location.name);
      expect(
        File('assets/images/${location.image}').existsSync(),
        isTrue,
        reason: location.name,
      );
    }
    final badges = pack.presentation['badges'] as Map;
    for (final id in pack.badges.keys) {
      if (id == 2) continue; // Original SVG is drawn by UniversityBadgeView.
      expect(badges['$id'], isNotNull, reason: 'crest $id');
    }
  });

  for (final width in [320.0, 393.0]) {
    testWidgets('question and authored heading remain visible at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = Game.newRun(scene);
      final run = game.events.begin(scene.events[1]!, game.state)..advance();
      await tester.pumpWidget(host(EventScreen(run: run)));
      await tester.pumpAndSettle();
      expect(find.text('Choose your answer'), findsOneWidget);
      expect(find.byKey(const ValueKey('choice-question')), findsOneWidget);
      expect(find.text('Four'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('choice-question'))).bottom,
        lessThan(tester.getRect(find.text('Four')).top),
      );
      expect(find.byType(Portrait), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'question-$width');
    });

    testWidgets(
      'seven long badge names fit setup and fixed My Info at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final badges = pack.badges.values.toList()
          ..sort((a, b) => b.name.length.compareTo(a.name.length));
        final draft = RunSetup(pack)
          ..badges.addAll(badges.take(7).map((b) => b.universityId));
        await tester.pumpWidget(host(SetupScreen(pack: pack, draft: draft)));
        await tester.pumpAndSettle();
        await capture(tester, 'mode-$width');
        // The difficulty step has no footer button: its two mode cards are
        // the forward choice, as the reference shows.
        await tester.tap(find.text('Standard Mode'));
        await tester.pumpAndSettle();
        await capture(tester, 'character-$width');
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(find.byType(UniversityBadgeSlots), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'badges-$width');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'traits-$width');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await capture(tester, 'name-$width');
        final game = draft.commit(pack);
        for (final trait
            in pack.traits.values
                .where((t) => RunSetup.eligible(t, pack))
                .take(18)) {
          game.state.grantTrait(trait.id);
        }
        await tester.pumpWidget(host(Scaffold(body: MyInfoPanel(game: game))));
        await tester.pumpAndSettle();
        expect(find.byType(Scrollable), findsNothing);
        expect(find.byType(UniversityBadgeView), findsNWidgets(7));
        expect(tester.takeException(), isNull);
        await capture(tester, 'my-info-$width');
        await tester.pumpWidget(
          host(
            Scaffold(
              body: DayMenu(game: game, onStart: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // A fresh goal announces itself over the hub; acknowledge it first.
        await tester.tap(find.text("Let's do this!"));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('hub-traits-scroll')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'hub-$width');
      },
    );
  }
}
