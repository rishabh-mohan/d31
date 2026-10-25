import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/setup.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/csat_screen.dart';
import 'package:d30mode/ui/setup_screen.dart';
import 'package:d30mode/ui/event_screen.dart';

/// Retry Year's compiled mechanics, recovered from the Korean native, and the
/// exam day both campaigns now share. See docs/RETRY-YEAR.md.
void main() {
  late ContentPack retry;
  late ContentPack original;
  setUpAll(() async {
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    original = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  void finish(EventRun run, {int Function(EventBeat)? choose}) {
    for (var steps = 0; steps < 3000; steps++) {
      final beat = run.current;
      if (beat == null || beat.isEnd) return;
      beat.choices.isEmpty
          ? run.advance()
          : run.choose(beat.choices[choose?.call(beat) ?? 0]);
    }
    fail('event ${run.event.id} did not finish');
  }

  test('entry-tier books grant the same unbuffed +15 in both campaigns', () {
    for (final pack in [original, retry]) {
      final game = Game.newRun(pack, random: Random(82));
      game.state.openingComplete = true;
      game.state.date = GameDate(game.state.date.day, 7);
      game.state.locationId = 1000;
      expect(game.state.traits, isEmpty);
      expect(game.state.badgeIds, isEmpty);
      expect(game.state.equippedStationery, isEmpty);
      final study = pack.locations[1000]!.actions.firstWhere(
        (action) => action.actionType == 'study',
      );
      final book = pack
          .booksFor('korean')
          .firstWhere((book) => book.bookRank == '1');
      expect(book.power, 5);
      expect(game.preview(study, book: book).gain, 15);
      final before = game.state.stats['korean']!;
      game.act(study, book: book);
      expect(game.state.stats['korean']! - before, 15);
    }
  });

  test('Genius of the Century adds exactly three stats in both campaigns', () {
    for (final pack in [original, retry]) {
      for (final boosted in [false, true]) {
        final game = Game.newRun(pack, random: Random(82));
        game.state.openingComplete = true;
        game.state.date = GameDate(game.state.date.day, 7);
        game.state.locationId = 1000;
        if (boosted) game.state.grantTrait(73);
        final study = pack.locations[1000]!.actions.firstWhere(
          (action) => action.actionType == 'study',
        );
        final book = pack
            .booksFor('korean')
            .firstWhere((book) => book.bookRank == '1');
        expect(
          game.traits.studyBonus(
            game.state,
            subject: 'korean',
            schoolStudy: true,
          ),
          boosted ? 3 : 0,
        );
        final expected = boosted ? 18 : 15;
        expect(game.preview(study, book: book).gain, expected);
        final before = game.state.stats['korean']!;
        game.act(study, book: book);
        expect(game.state.stats['korean']! - before, expected);
      }
    }
  });

  /// A run already at [code], with the content that would have played by then
  /// out of the way: every event eligible now, apart from [keep], is marked
  /// finished, so the one under test is not queued behind the prologue.
  Game at(
    ContentPack pack,
    String code, {
    int seed = 1,
    Set<int> keep = const {},
  }) {
    final game = Game.newRun(pack, random: Random(seed));
    game.state.openingComplete = true;
    game.state.date = GameDate.parse(code);
    for (var round = 0; round < 20; round++) {
      final stale = game.events
          .eligible(game.state, includeFake: true)
          .where((e) => !keep.contains(e.id))
          .toList();
      if (stale.isEmpty) break;
      for (final e in stale) {
        game.state.eventStates[e.id] = 2;
      }
    }
    return game;
  }

  bool eligible(Game game, int id) =>
      game.events.eligible(game.state).any((e) => e.id == id);

  group('calendar', () {
    test('days survive a daylight-saving change', () {
      // 3 Nov 2024 is the US change; a Duration-based day lands on 23:00.
      var date = GameDate.parse('DATE_2024110100');
      for (var i = 0; i < 10; i++) {
        date = date.nextDay();
      }
      expect(date.code, 'DATE_2024111100');
      expect(date.day.hour, 0);
      expect(
        GameDate.parse('DATE_2024110200')
            .daysUntil(GameDate.parse('DATE_2024110500')),
        3,
      );
    });

    test('the promotion exam is eligible on the morning of 8 November', () {
      final game = at(retry, 'DATE_2024110700');
      game.state.date = game.state.date.nextDay();
      expect(eligible(game, 62), isTrue);
    });
  });

  group('friend trouble blocks', () {
    test('open from tick 1 of the rolling target day, with enough rapport', () {
      final game = at(retry, 'DATE_2024101800');
      final gate = Game.recoveredBlockGates['GO_PRO_CONDITION']!;
      game.state.setSwitch('GO_SEE', 2);
      expect(gate(game.state), isFalse, reason: 'tick 0 is not past it');
      game.state.date = GameDate.parse('DATE_2024101801');
      expect(gate(game.state), isTrue);
      game.state.setSwitch('GO_SEE', 1);
      expect(gate(game.state), isFalse, reason: 'rapport below 2');
    });

    test(
      'the block starts the arc and the arc moves the target three days',
      () {
        final game = at(retry, 'DATE_2024103001');
        game.state.setSwitch('BLOCK_TARGET_MONTH', 10);
        game.state.setSwitch('BLOCK_TARGET_DAY', 30);
        game.effects.applyChanger({'funcCode': 'DO_GO_PRO'}, game.state);
        expect(game.state.switchValue('GO_BLOCK'), 1);
        expect(eligible(game, 16), isTrue);
        finish(game.events.begin(retry.events[16]!, game.state));
        // 30 Oct + 3 rolls into November.
        expect(game.state.switchValue('BLOCK_TARGET_MONTH'), 11);
        expect(game.state.switchValue('BLOCK_TARGET_DAY'), 2);
      },
    );

    test('Presidential Assist counts toward the diagnosis beats', () {
      final game = at(retry, 'DATE_2024110201');
      final gate = Game.recoveredBlockGates['HELP_BANJANG_CONDITION']!;
      expect(gate(game.state), isFalse);
      game.state.setSwitch('NA_BLOCK', 1);
      game.state.setSwitch('BANJANG_STUDY_BLOCK_ON', 1);
      expect(gate(game.state), isTrue);
      for (var i = 0; i < 5; i++) {
        game.effects.applyChanger({'funcCode': 'DO_HELP_BANJANG'}, game.state);
      }
      expect(eligible(game, 41), isTrue);
    });
  });

  test('Gather raises GRASS_SW only for its own event check', () {
    final game = at(retry, 'DATE_2024110201');
    game.state.unlockedLocations.add(20001);
    game.state.locationId = 20001;
    final gather = retry.locations[20001]!.actions.firstWhere(
      (a) => a.funcCode == 'DO_GATHER',
    );
    final outcome = game.act(gather);
    expect(outcome.event?.event.id, 23, reason: 'Herb Collecting plays');
    expect(game.state.switchValue('GRASS_SW'), 0);
  });

  group('singing', () {
    test('practice decides the battle against the drawn target', () {
      final game = at(retry, 'DATE_2024110209');
      game.state.setSwitch('SING_POINT', 10);
      game.effects.applyChanger({'funcCode': 'SET_SING_TARGET'}, game.state);
      final target = game.state.switchValue('SING_TARGET');
      expect(target, inInclusiveRange(15, 17));
      expect(game.state.switchValue('SING_ENEMY'), inInclusiveRange(1, 6));
      final win = game.conditions.funcs['FUNC_SING_TARGET']!;
      expect(win(game.state, const []), 0);
      game.state.setSwitch('SING_COUNT', target);
      expect(win(game.state, const []), 1);
    });

    test('the microphone doubles practice', () {
      final game = at(retry, 'DATE_2024110209');
      game.effects.applyChanger({'funcCode': 'DO_KARAOKE'}, game.state);
      game.state.addItem(90008);
      game.effects.applyChanger({'funcCode': 'DO_KARAOKE'}, game.state);
      expect(game.state.switchValue('SING_COUNT'), 3);
    });

    test('the Sing-Off hands straight to its results', () {
      final game = at(retry, 'DATE_2024110209');
      game.state.eventStates[31] = 2;
      game.state.setSwitch('SING_SW', 1);
      game.state.setSwitch('SING_ENEMY', 1);
      finish(game.events.begin(retry.events[219]!, game.state));
      expect(game.state.switchValue('GOGO_SING'), 1);
      expect(eligible(game, 220), isTrue);
    });
  });

  group('exams', () {
    test('mock exam marks are the stat total against fixed bands', () {
      final game = at(retry, 'DATE_2024101803');
      final mark = game.conditions.funcs['FUNC_MOCK_EXAM_GOOD']!;
      void total(num value) {
        for (final s in retry.manifest.subjects) {
          game.state.stats[s] = value / retry.manifest.subjects.length;
        }
      }

      total(1400);
      expect(mark(game.state, [1]), 1);
      total(1600);
      expect(mark(game.state, [1]), 2);
      total(1800);
      expect(mark(game.state, [1]), 3);
      expect(mark(game.state, [3]), 1);
    });

    test("Taeyang's bet is his fixed mark in the drawn subject", () {
      final game = at(retry, 'DATE_2024110103');
      game.effects.applyChanger({
        'funcCode': 'SET_GOLD_SUN_VALUE',
        'args': [3],
      }, game.state);
      final subject =
          retry.manifest.subjects[game.state.switchValue('GOLD_SUN_SUBJECT')];
      final win = game.conditions.funcs['FUNC_IS_GOLD_WIN']!;
      game.state.stats[subject] = 2449;
      expect(win(game.state, const []), 0);
      game.state.stats[subject] = 2450;
      expect(win(game.state, const []), 1);
    });

    test('proficiency items raise EXAM_POINT and the kit reads it back', () {
      final game = at(retry, 'DATE_2024110500');
      for (final id in [80037, 80038, 80043, 80042]) {
        game.state.addItem(id);
      }
      for (final id in [80037, 80038, 80043]) {
        expect(game.useItem(id), isTrue);
      }
      expect(game.state.switchValue('EXAM_POINT'), 50);
      expect(game.useItem(80042), isTrue);
      expect(game.takeItemReports(), ['Promotion Exam Proficiency: 50%']);
      expect(game.state.itemCount(80042), 1, reason: 'the kit is kept');
    });
  });

  group('exam day', () {
    // Keep the Graduation Exams (74, story 16's 35) for the morning.
    Game examDay(ContentPack pack, {int seed = 1}) =>
        at(pack, pack.manifest.endDate.code, seed: seed, keep: {35, 74});

    test('Retry Year: no blocks, the Graduation Exam, then the CSAT', () {
      final game = examDay(retry);
      expect(game.availableActions(), isEmpty);
      final exam = game.beginDay();
      expect(exam?.event.id, 74);
      finish(exam!);
      expect(game.state.csatPending, isTrue);
      expect(game.state.finished, isFalse);
    });

    test('a failed year is the Second Retake ending', () {
      final game = examDay(retry);
      finish(game.beginDay()!);
      game.takeCsat();
      game.submitApplications(const []);
      game.enroll(null);
      final ending = game.nextEndingEvent();
      expect(ending?.event.id, 160);
      finish(ending!);
      expect(game.state.finished, isTrue);
      expect(game.state.endingLabel, 'Third Try Ending');
    });

    test('Medicine needs the Elite recommendation, and opens its ending', () {
      final game = examDay(retry);
      for (final s in retry.manifest.subjects) {
        game.state.stats[s] = 6000;
      }
      finish(game.beginDay()!);
      final medicine = retry.admissions.departments[54001]!;
      expect(game.canApply(medicine), isFalse);
      game.state.addItem(90019);
      expect(game.canApply(medicine), isTrue);
      expect(game.admissionChance(medicine), greaterThan(.99));
      expect(game.submitApplications([54001]), [54001]);
      game.enroll(54001);
      final ending = game.nextEndingEvent();
      expect(ending?.event.id, anyOf(163, 164));
    });

    test('story 16 sits the CSAT too, and its endings read the result', () {
      final game = examDay(original);
      for (final s in original.manifest.subjects) {
        game.state.stats[s] = 2000;
      }
      final exam = game.beginDay();
      expect(exam, isNotNull, reason: 'Graduation Exam opens exam day');
      finish(exam!);
      expect(game.state.csatPending, isTrue);
      final csat = game.takeCsat();
      expect(csat.standardScore, greaterThan(70));
      final best = game
          .departmentsByCutoff()
          .where((d) => game.canApply(d) && game.admissionChance(d) > .9)
          .first;
      game.submitApplications([best.id]);
      game.enroll(game.state.admittedDepartments.firstOrNull);
      for (
        var run = game.nextEndingEvent();
        run != null;
        run = game.nextEndingEvent()
      ) {
        finish(run);
      }
      expect(game.state.finished, isTrue);
      expect(game.state.endingLabel, isNotNull);
    });

    test('the sitting survives a save', () {
      final game = examDay(retry);
      finish(game.beginDay()!);
      game.takeCsat();
      game.submitApplications([
        for (final d in game.departmentsByCutoff())
          if (game.admissionChance(d) > .99 && game.canApply(d)) d.id,
      ]);
      final loaded = GameState.fromJson(retry, game.state.toJson());
      expect(loaded.csatPending, isTrue);
      expect(loaded.csat?.standardScore, game.state.csat!.standardScore);
      expect(loaded.applications, game.state.applications);
      expect(loaded.admittedDepartments, game.state.admittedDepartments);
    });
  });

  test('character blocks and abilities follow the chosen character', () {
    final medical = Game.recoveredBlockGates['MEDICAL_BLOCK_CONDITION']!;
    final mechanic = Game.recoveredBlockGates['MECHANIC_BLOCK_CONDITION']!;
    final game = Game.newRun(original);
    expect(medical(game.state) || mechanic(game.state), isFalse);
    game.state.characterId = 70;
    expect(medical(game.state), isTrue);
    game.state.setSwitch('MEDICAL_LEVEL', 4);
    expect(medical(game.state), isFalse, reason: 'crafted to the top');
    game.state.characterId = 74;
    expect(mechanic(game.state), isTrue);
    game.state.grantTrait(160020);
    expect(mechanic(game.state), isFalse, reason: 'Robotics Master held');

    final singer = at(retry, 'DATE_2024110209');
    final win = singer.conditions.funcs['FUNC_SING_TARGET']!;
    singer.state.setSwitch('SING_TARGET', 30);
    expect(win(singer.state, const []), 0);
    singer.state.characterId = 67;
    expect(win(singer.state, const []), 1, reason: "Alley King can't lose");
    final money = singer.state.money;
    singer.effects.applyChanger({'funcCode': 'DO_KARAOKE'}, singer.state);
    expect(singer.state.money, greaterThan(money));
  });

  test('trait lines only play for players with the trait (Jailbreaker)', () {
    for (final has in [false, true]) {
      final game = at(retry, 'DATE_2024101614');
      if (has) game.state.grantTrait(214);
      game.state.locationId = 20007;
      final before = game.state.totalStat;
      final run = game.events.begin(retry.events[4]!, game.state);
      final lines = <String>[];
      while (run.current != null && !run.current!.isEnd) {
        lines.add(run.current!.text);
        run.advance();
      }
      lines.add(run.current?.text ?? '');
      expect(lines.any((l) => l.contains('Jailbreak')), has);
      expect(
        game.state.totalStat - before,
        has ? 40.0 * retry.manifest.subjects.length : 0,
      );
    }
  });

  test('a female protagonist plays the female script, saves included', () {
    final draft = RunSetup(retry)..isMale = false;
    final game = draft.commit(retry);
    expect(game.state.isMale, isFalse);
    expect(identical(game.pack, retry), isFalse);
    // Jian Lee is actor 9 (a girl) in the male script and 27 (a boy) here.
    final swapped = retry.nodes.keys.where(
      (id) =>
          retry.nodes[id]!.standingId == 9 &&
          game.pack.nodes[id]?.standingId == 27,
    );
    expect(swapped, isNotEmpty);
    final loaded = GameState.fromJson(retry, game.state.toJson());
    expect(identical(loaded.pack, game.pack), isTrue);
    final male = (RunSetup(retry)..isMale = true).commit(retry);
    expect(identical(male.pack, retry), isTrue);
  });

  test('gender selection is a pack switch, and pairs follow the player', () {
    expect(retry.genderSelection, isTrue);
    expect(original.genderSelection, isFalse);
    // Two-form NPCs appear as the opposite gender of the protagonist.
    expect(retry.npcFor(9, playerIsMale: true), 9);
    expect(retry.npcFor(9, playerIsMale: false), 27);
    expect(retry.npcFor(27, playerIsMale: true), 9);
    expect(retry.npcFor(2, playerIsMale: false), 2);
    // A pack without the switch ignores a stray choice.
    final draft = RunSetup(original)..isMale = false;
    expect(draft.maleFor(original), draft.recommendedMale(original));
  });

  testWidgets('Select opens the gender page, and a card moves on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = RunSetup(retry)..difficulty = 'standard';
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(pack: retry, draft: draft, campaigns: [retry]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry Year'));
    await tester.pumpAndSettle();
    expect(find.text('Select Character (2 / 5)'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Select Gender'), findsOneWidget);
    expect(find.text('Select Character (2 / 5)'), findsOneWidget);
    final recommended = draft.recommendedMale(retry);
    expect(
      find.textContaining(recommended ? 'Male' : 'Female', findRichText: true),
      findsWidgets,
    );
    await tester.tap(
      find.byKey(ValueKey(recommended ? 'gender-Female' : 'gender-Male')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select Character (3 / 5)'), findsOneWidget);
    expect(draft.maleFor(retry), !recommended);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ending function holds its title on black for 3 seconds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = Game.newRun(retry);
    final run = game.events.begin(retry.events[1]!, game.state);
    await tester.pumpWidget(MaterialApp(home: EventScreen(run: run)));
    for (
      var i = 0;
      i < 40 && find.byKey(const ValueKey('ending-card')).evaluate().isEmpty;
      i++
    ) {
      if (run.current == null || run.current!.isEnd) break;
      if (find.byTooltip('Next').evaluate().isEmpty) break;
      await tester.tap(find.byTooltip('Next'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('ending-card')), findsOneWidget);
    expect(find.text('Retake Ending'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ending-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the CSAT screen goes from results to enrolment', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = Game.newRun(retry, random: Random(3));
    game.state.openingComplete = true;
    game.state.date = GameDate(retry.manifest.endDate.day, 0);
    for (final s in retry.manifest.subjects) {
      game.state.stats[s] = 3000;
    }
    game.state.csatPending = true;

    await tester.pumpWidget(MaterialApp(home: CsatScreen(game: game)));
    expect(find.text('CSAT Results'), findsOneWidget);
    await tester.tap(find.text('Choose universities'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Applications (0 / 3)'), findsOneWidget);
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(find.textContaining('Applications (1 / 3)'), findsOneWidget);
    await tester.tap(find.text('Submit applications'));
    await tester.pumpAndSettle();
    expect(find.text('Admission Results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
