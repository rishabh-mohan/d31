import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/setup.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/ui/event_screen.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/ui/setup_screen.dart';
import 'package:d30mode/ui/pack_menus.dart';
import 'package:d30mode/ui/portrait.dart';

void main() {
  late ContentPack original;
  late ContentPack retry;
  setUpAll(() async {
    original = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  List<String> finish(EventRun run) {
    final lines = <String>[];
    for (var steps = 0; steps < 2500; steps++) {
      final beat = run.current;
      if (beat == null) break;
      lines.add(beat.text);
      if (beat.isEnd) return lines;
      if (beat.choices.isEmpty) {
        run.advance();
      } else {
        run.choose(beat.choices.first);
      }
    }
    fail('Event ${run.event.id} did not finish');
  }

  void open(Game game) {
    while (true) {
      final run = game.beginOpeningEvent();
      if (run == null) return;
      finish(run);
    }
  }

  test('old first-day saves recover the missing START continuation and initial tasks', () {
    final initial = Game.newRun(retry);
    finish(initial.beginOpeningEvent()!);
    final legacy = initial.state.toJson()
      ..remove('openingComplete')
      ..remove('taskDeadlines')
      ..remove('taskTitles');
    (legacy['switches'] as Map).remove('START');
    final game = Game(pack: retry, state: GameState.fromJson(retry, legacy));
    expect(game.state.taskDeadlines.containsKey(10000), isTrue);
    expect(game.beginOpeningEvent()!.event.id, 169);
    expect(game.state.switchValue('START'), 1);
    expect(game.state.eventCounts[1], 1);
  });

  test('opening plays rejection, mother, placement test and reflection before any tick', () {
    final game = RunSetup(retry).commit(retry);
    final date = game.state.date;
    final tickets = game.state.rerolls;
    expect(game.state.locationId, 20007);
    expect(game.openingPending, isTrue);
    expect(game.availableActions(), isEmpty);
    expect(game.refreshHand(), isFalse);
    expect(game.move(1000), isFalse);
    final ids = <int>[];
    final lines = <String>[];
    while (true) {
      final run = game.beginOpeningEvent();
      if (run == null) break;
      ids.add(run.event.id);
      lines.addAll(finish(run));
    }
    expect(ids, [1, 169, 2, 3]);
    expect(lines, contains('She was crying...'));
    expect(lines, contains('You will now take a quick test.'));
    expect(lines, contains('The test started straight away like that...'));
    expect(game.state.switchValue('START'), 1);
    expect(game.state.date, date);
    expect(game.state.rerolls, tickets);
    expect(game.state.finished, isFalse);
    expect(game.state.eventsFiredToday, 0);
    expect(game.effects.unknownFuncCodes, isEmpty);
    expect(game.state.locationId, 20007);
    expect(game.state.switchValue('DOK_BANG_ON'), 1);
    expect(game.state.movementLocked, isTrue);
    expect(game.state.taskDeadlines[5], GameDate.parse('DATE_2024101414'));
    expect(game.availableLocations().map((location) => location.id), [20007]);
    expect(game.inClass, isFalse);
    expect(game.hand().any((action) => action.actionType == 'lesson'), isFalse);
  });

  test(
    'a saved opening resumes at the next beat without repeating the ending',
    () {
      var game = Game.newRun(retry);
      finish(game.beginOpeningEvent()!);
      game = Game(
        pack: retry,
        state: GameState.fromJson(retry, game.state.toJson()),
      );
      expect(game.openingPending, isTrue);
      final next = game.beginOpeningEvent()!;
      expect(next.event.id, 169);
      finish(next);
      open(game);
      expect(game.state.eventCounts[1], 1);
      expect(game.state.eventCounts[169], 1);
      expect(game.state.taskDeadlines.containsKey(5), isTrue);
      final restored = Game(
        pack: retry,
        state: GameState.fromJson(retry, game.state.toJson()),
      );
      expect(restored.openingPending, isFalse);
      expect(restored.beginOpeningEvent(), isNull);
      expect(restored.state.taskDeadlines, game.state.taskDeadlines);
    },
  );

  test('first-day confinement releases in the evening, then the next morning introduces the class', () {
    final game = Game.newRun(retry, random: Random(1));
    open(game);
    game.state.eventsFiredToday = 99; // Scheduled story beats bypass the cap.
    final sleep = retry.locations[20007]!.actions.firstWhere(
      (a) => a.actionType == 'sleep',
    );
    for (var tick = 1; tick < 14; tick++) {
      final result = game.act(sleep);
      expect(result.event, isNull);
      expect(game.state.date.tick, tick);
      expect(game.state.locationId, 20007);
      expect(game.inClass, isFalse);
    }
    final evening = game.act(sleep);
    expect(evening.event!.event.id, 4);
    expect(game.state.date, GameDate.parse('DATE_2024101414'));
    expect(game.state.dayEndPending, isTrue);
    expect(game.state.taskDeadlines.containsKey(5), isFalse);
    finish(evening.event!);
    expect(game.state.switchValue('DOK_BANG_ON'), 0);
    expect(game.state.movementLocked, isFalse);
    expect(game.nextScheduledEvent(), isNull);
    final checkpoint = GameState.fromJson(retry, game.state.toJson());
    expect(checkpoint.dayEndPending, isTrue);
    game.finishPendingDay();
    expect(game.state.date, GameDate.parse('DATE_2024101500'));
    expect(game.state.locationId, 1000);
    final morning = game.beginDay()!;
    expect(morning.event.id, 211);
    finish(morning);
    final followup = game.nextScheduledEvent()!;
    expect(followup.event.id, 6);
    finish(followup);
    final introduction = game.nextScheduledEvent()!;
    expect(introduction.event.id, 7);
    finish(introduction);
    expect(game.state.date, GameDate.parse('DATE_2024101500'));
  });

  test('Nice to Meet You grants the kit once and preserves it in saves', () {
    final game = Game.newRun(retry);
    game.state.addItem(80042, 2);
    final run = game.events.begin(retry.events[211]!, game.state);
    while (run.current!.node.id != 211010 && !run.current!.isEnd) {
      run.advance();
    }
    expect(run.current!.node.id, 211010);
    expect(game.state.itemCount(80042), 3);
    expect(run.acquiredItems, {80042: 1});
    finish(run);
    expect(game.state.itemCount(80042), 3);
    expect(run.acquiredItems, {80042: 1});
    final restored = GameState.fromJson(retry, game.state.toJson());
    expect(restored.itemCount(80042), 3);
  });

  test('Banjang Na has his body, outfit and every authored expression', () {
    final actor = (retry.presentation['npcs'] as Map)['7'] as Map;
    final paths = [
      actor['skeleton'],
      ...(actor['expressions'] as Map).values,
      ...(actor['clothes'] as Map).values,
    ];
    expect(paths.length, 6);
    for (final path in paths) {
      expect(path, isNotNull);
      expect(File('assets/images/$path').existsSync(), isTrue);
    }
  });

  testWidgets('event receipt and bag both show the Promotion Exam Kit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = Game.newRun(retry);
    final run = game.events.begin(retry.events[211]!, game.state);
    while (run.current!.node.id != 211010 && !run.current!.isEnd) {
      run.advance();
    }
    await tester.pumpWidget(MaterialApp(home: EventScreen(run: run)));
    await tester.pumpAndSettle();
    expect(find.text('Received: Promotion Exam Kit x1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    finish(run);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BagsMenu(game: game)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Promotion Exam Kit ×1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only Mom and Ji Suin receive the event portrait lift', (
    tester,
  ) async {
    final game = Game.newRun(retry);
    for (final (event, npc, lift) in [
      (169, 1, -24.0),
      (3, 3, -24.0),
      (2, 2, 0.0),
    ]) {
      final run = game.events.begin(retry.events[event]!, game.state);
      while (run.portraitId != npc && !run.current!.isEnd) {
        run.advance();
      }
      expect(run.portraitId, npc);
      await tester.pumpWidget(
        MaterialApp(
          home: EventScreen(key: ValueKey(event), run: run),
        ),
      );
      await tester.pumpAndSettle();
      final transform = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byType(Portrait),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.getTranslation().y, lift);
      expect(tester.takeException(), isNull);
    }
  });

  test('hidden reset events update real EVENT state without consuming a visible-event slot', () {
    final game = Game.newRun(retry, random: Random(1));
    open(game);
    game.state.date = GameDate.parse('DATE_2024101505');
    game.state.setSwitch('DOK_BANG_ON', 0);
    game.state.setSwitch('EVENT_4', 2);
    game.state.eventsFiredToday = 99;
    final scheduled = game.nextScheduledEvent();
    expect(scheduled?.event.id, 211);
    expect(game.state.eventStates[4], 0);
    expect(game.state.eventStates[5], 2);
    expect(game.state.eventsFiredToday, 100); // Only the visible event counted.
  });

  testWidgets('new Retry Year opens its prologue without pressing an action', (
    tester,
  ) async {
    final game = RunSetup(retry).commit(retry);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          game: game,
          packLocation: PackLocation('kss20', null, false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventScreen), findsOneWidget);
    expect(
      tester.widget<EventScreen>(find.byType(EventScreen)).run.event.id,
      1,
    );
    expect(find.text('No...'), findsOneWidget);
    expect(game.state.date.tick, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('story 20 imports its calendar, locations, characters and complete event catalog', () {
    expect(retry.manifest.id, 'kss20');
    expect(retry.manifest.storyId, 20);
    expect(retry.manifest.startDate.day, DateTime(2024, 10, 14));
    expect(retry.manifest.endDate.day, DateTime(2024, 11, 14));
    expect(retry.events.length, 218);
    expect(retry.locations.length, 8);
    expect(retry.characters.length, 20);
    expect(retry.locations[1000]!.name, 'Lower Classroom');
    expect(retry.partTimeLevels.tiers.first.name, 'Beginner');
    expect(retry.partTimeLevels.tiers[1].name, 'Apprentice');
    for (final location in retry.locations.values) {
      expect(File('assets/images/${location.image}').existsSync(), isTrue);
    }
    final npcs = retry.presentation['npcs'] as Map;
    for (final id in [1, 2, 3, 4, 5, 6]) {
      final actor = npcs['$id'] as Map;
      for (final path in [
        actor['skeleton'],
        (actor['expressions'] as Map)['defaults'],
        (actor['clothes'] as Map)['defaults'],
      ]) {
        expect(path, isNotNull, reason: 'missing opening actor $id');
        expect(File('assets/images/$path').existsSync(), isTrue);
      }
    }
    for (final event in retry.events.values) {
      expect(
        retry.nodes.containsKey(event.rootNodeId),
        isTrue,
        reason: 'missing root ${event.id}',
      );
    }
    // Korean name/quiz macros are runtime tokens, not untranslated dialogue.
    final korean = RegExp(r'[\uac00-\ud7a3]');
    final macros = RegExp(r'\{[^{}]*\}|<[^<>]*>');
    for (final node in retry.nodes.values) {
      for (final text in [
        node.text,
        node.elseText,
        node.optionText,
        ...node.options.map((option) => option.text),
      ]) {
        expect(
          korean.hasMatch((text ?? '').replaceAll(macros, '')),
          isFalse,
          reason: 'untranslated prose at node ${node.id}',
        );
      }
    }
    final setup = RunSetup(retry);
    expect(setup.characterId, isNotNull);
    final game = setup.commit(retry);
    expect(game.pack, same(retry));
    final own = retry.traits.values.where((t) => t.storyId == 20).first;
    expect(game.state.grantTrait(own.id), isTrue);
    final other = retry.traits.values.where((t) => t.storyId == 16).first;
    expect(game.state.grantTrait(other.id), isFalse);
    expect(
      GameState.fromJson(retry, game.state.toJson()).traits,
      contains(own.id),
    );
  });

  test('Retry Year can advance a complete prototype run without hanging', () {
    final game = Game.newRun(retry, random: Random(20));
    open(game);
    var actions = 0;
    while (!game.state.finished && actions++ < 600) {
      final action = game.availableActions().firstWhere(
        (a) => a.actionType == 'study',
      );
      final outcome = game.act(action);
      for (final run in [
        ...outcome.beforeEvents,
        if (outcome.event != null) outcome.event!,
      ]) {
        var steps = 0;
        while (run.current != null && !run.current!.isEnd && steps++ < 2500) {
          if (run.current!.choices.isEmpty) {
            run.advance();
          } else {
            run.choose(run.current!.choices.first);
          }
        }
        expect(run.exhausted, isFalse, reason: 'event ${run.event.id} looped');
      }
      for (var beats = 0; beats < 250; beats++) {
        final scheduled = game.nextScheduledEvent();
        if (scheduled == null) break;
        finish(scheduled);
      }
      if (game.state.dayEndPending) {
        game.finishPendingDay();
        final morning = game.beginDay();
        if (morning != null) finish(morning);
      }
    }
    expect(game.state.finished, isTrue);
    expect(actions, lessThan(600));
  });

  testWidgets(
    'selecting Retry Year uses its own setup and keeps the header visible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            pack: original,
            draft: RunSetup(original),
            campaigns: [original, retry],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elite Mode'), findsNothing);
      expect(find.textContaining('Elite Support Pack'), findsNothing);
      expect(find.text('Select Character (1 / 5)'), findsOneWidget);
      await tester.tap(find.text('Retry Year'));
      await tester.pumpAndSettle();
      expect(find.text('Select Character (2 / 5)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Retry Year'), findsOneWidget);
    },
  );
}
