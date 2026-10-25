/// The application-results flow, Final Decision, Confirm Enrollment, the
/// share scene, the completion summary and the ending reward modal.
///
/// The pack loads in setUpAll (file I/O inside testWidgets hangs, CLAUDE.md
/// 5a). Animations driven by an AnimationController lose their first frame
/// in tests, so waits here pump a short frame and then the duration.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/record_store.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/dday_results.dart';
import 'package:d30mode/ui/end_screen.dart';
import 'package:d30mode/ui/student_photo.dart';

class _Seeded implements Random {
  final Random _inner;
  _Seeded(int seed) : _inner = Random(seed);
  @override
  bool nextBool() => _inner.nextBool();
  @override
  double nextDouble() => _inner.nextDouble();
  @override
  int nextInt(int max) => _inner.nextInt(max);
}

void main() {
  late ContentPack pack;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  /// A run with three committed applications whose verdicts are [accept]
  /// (stored directly, as the engine would have rolled them).
  Game committed(List<bool> accept, {bool reviewed = false}) {
    final game = Game(
      pack: pack,
      state: GameState.newRun(pack, random: _Seeded(7)),
    );
    for (final s in pack.manifest.subjects) {
      game.state.stats[s] = 3000;
    }
    game.state.csatPending = true;
    game.completeExamCards();
    game.confirmScoreAnnouncement();
    game.autoFill();
    game.submitDraft();
    final ids = [...game.state.applications];
    expect(ids.length, accept.length);
    game.state.admittedDepartments
      ..clear()
      ..addAll([
        for (var i = 0; i < ids.length; i++)
          if (accept[i]) ids[i],
      ]);
    if (reviewed) game.confirmResults();
    return game;
  }

  Future<void> host(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: app!,
        ),
        home: child,
      ),
    );
  }

  /// Lets a controller-driven animation of [ms] finish.
  Future<void> wait(WidgetTester tester, [int ms = 3300]) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(Duration(milliseconds: ms));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> skipTitle(WidgetTester tester) async {
    await tester.tap(key('results-title'));
    await wait(tester, 500);
  }

  Future<void> browseAndConfirm(WidgetTester tester) async {
    await tester.tap(key('browse-results'));
    await wait(tester);
    await tester.tap(key('result-confirm'));
    await wait(tester, 700);
  }

  group('engine additions', () {
    test('resultsRevealed counts confirms, saves and clamps', () {
      final game = committed([false, false, false]);
      expect(game.resultsRevealed, 0);
      expect(game.confirmNextResult(), 1);
      expect(game.confirmNextResult(), 2);
      final json =
          jsonDecode(jsonEncode(game.state.toJson())) as Map<String, dynamic>;
      final back = Game(pack: pack, state: GameState.fromJson(pack, json));
      expect(back.resultsRevealed, 2);
      expect(back.confirmNextResult(), 3);
      expect(back.confirmNextResult(), 3, reason: 'never past the last');
      expect(
        back.state.resultsReviewed,
        isFalse,
        reason: 'aggregate is separate',
      );
      back.confirmResults();
      expect(back.resultsRevealed, 3);
      expect(back.confirmNextResult(), 3);
    });

    test('the Student ID photo path saves with the run and its record', () {
      final game = committed([false, false, false]);
      game.state.studentPhotoPath = '/data/student_photos/photo_1.jpg';
      final json =
          jsonDecode(jsonEncode(game.state.toJson())) as Map<String, dynamic>;
      expect(
        GameState.fromJson(pack, json).studentPhotoPath,
        '/data/student_photos/photo_1.jpg',
      );
      final record = RunRecord.of(3, game.state, ending: 'Retake Ending');
      final copy = RunRecord.fromJson(3, record.toJson());
      expect(copy.studentPhoto, '/data/student_photos/photo_1.jpg');
      expect(
        RunRecord.of(
          4,
          committed([false, false, false]).state,
          ending: 'x',
        ).toJson().containsKey('studentPhoto'),
        isFalse,
      );
    });
  });

  group('envelopes', () {
    testWidgets('title fades, a tap skips it, and the stack opens', (
      tester,
    ) async {
      final game = committed([false, false, false]);
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      expect(find.text('Application Results\nAnnouncement'), findsOneWidget);
      await tester.tap(key('results-title'));
      await wait(tester, 500);
      expect(key('results-envelopes'), findsOneWidget);
      expect(key('acceptance-rate'), findsOneWidget);
    });

    testWidgets('results follow submission order and never reroll', (
      tester,
    ) async {
      final game = committed([false, true, false]);
      final results = game.applicationResults;
      final snapshot = [
        for (final r in results) (r.department.id, r.rate, r.accepted),
      ];
      final rolls = [...game.state.admittedDepartments];
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await skipTitle(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          find.text('${results[i].rate}% Acceptance Rate'),
          findsOneWidget,
          reason: 'envelope $i is the active one, in submission order',
        );
        await tester.tap(key('browse-results'));
        await wait(tester);
        final card = find.byKey(ValueKey('result-card-$i'));
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(results[i].accepted ? 'Accepted' : 'Rejected'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(results[i].university!.name),
          ),
          findsOneWidget,
        );
        // Rebuilding the whole flow mid-card does not reroll: the new flow
        // resumes at this same (unconfirmed) envelope.
        await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
        if (game.resultsRevealed == 0) await skipTitle(tester);
        expect(
          find.text('${results[i].rate}% Acceptance Rate'),
          findsOneWidget,
        );
        await tester.tap(key('browse-results'));
        await wait(tester);
        await tester.tap(key('result-confirm'));
        await wait(tester, 700);
        if (i < 2) {
          expect(game.resultsRevealed, i + 1);
        }
      }
      expect([
        for (final r in game.applicationResults)
          (r.department.id, r.rate, r.accepted),
      ], snapshot);
      expect(game.state.admittedDepartments, rolls);
    });

    testWidgets('each Confirm advances exactly once; aggregate is separate', (
      tester,
    ) async {
      final game = committed([false, false, false]);
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await skipTitle(tester);
      await tester.tap(key('browse-results'));
      await wait(tester);
      // A double tap in the same frame still counts one Confirm.
      await tester.tap(key('result-confirm'));
      await tester.tap(key('result-confirm'), warnIfMissed: false);
      await wait(tester, 700);
      expect(game.resultsRevealed, 1);
      await browseAndConfirm(tester);
      expect(game.resultsRevealed, 2);
      expect(key('results-cards'), findsNothing);
      await browseAndConfirm(tester);
      expect(game.resultsRevealed, 3);
      // The combined page is its own step with its own Confirm.
      expect(key('results-cards'), findsOneWidget);
      expect(game.state.resultsReviewed, isFalse);
      expect(key('final-decision-title'), findsOneWidget);
      await tester.tap(key('results-confirm-all'));
      await wait(tester, 800);
      expect(game.state.resultsReviewed, isTrue);
      expect(game.state.finalDecided, isFalse);
    });

    testWidgets('combined page lists the cards in submission order', (
      tester,
    ) async {
      final game = committed([false, false, false]);
      for (var i = 0; i < 3; i++) {
        game.confirmNextResult();
      }
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await wait(tester, 500);
      final tops = [
        for (var i = 0; i < 3; i++)
          tester.getTopLeft(key('combined-card-$i')).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet().length, 3);
    });

    testWidgets('a restart resumes at the next unconfirmed envelope', (
      tester,
    ) async {
      final game = committed([false, false, false]);
      game.confirmNextResult();
      final second = game.applicationResults[1];
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await wait(tester, 500);
      expect(key('results-title'), findsNothing);
      expect(key('envelope-0'), findsNothing, reason: 'already revealed');
      expect(key('envelope-1'), findsOneWidget);
      expect(find.text('${second.rate}% Acceptance Rate'), findsOneWidget);
    });

    testWidgets('fast-forward jumps to the revealed card, Confirm remains', (
      tester,
    ) async {
      final game = committed([true, false, false]);
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await skipTitle(tester);
      await tester.tap(key('results-fast-forward'));
      await wait(tester, 100);
      expect(key('result-card-0'), findsOneWidget);
      expect(key('result-confirm'), findsOneWidget);
      expect(game.resultsRevealed, 0);
    });

    testWidgets('reduced motion shows the card without the staged opening', (
      tester,
    ) async {
      final game = committed([false, false, false]);
      await host(
        tester,
        DdayResultsFlow(game: game, onFinished: () {}),
        reduceMotion: true,
      );
      await tester.pump();
      await tester.pump();
      expect(key('results-envelopes'), findsOneWidget, reason: 'no title fade');
      await tester.tap(key('browse-results'));
      await tester.pump();
      expect(key('result-confirm'), findsOneWidget);
      await tester.tap(key('result-confirm'));
      await tester.pump();
      expect(game.resultsRevealed, 1);
      expect(
        find.text('${game.applicationResults[1].rate}% Acceptance Rate'),
        findsOneWidget,
      );
    });
  });

  group('final decision', () {
    testWidgets('all rejected: only the academy, and Confirm Enrollment', (
      tester,
    ) async {
      final game = committed([false, false, false], reviewed: true);
      var finished = 0;
      await host(
        tester,
        DdayResultsFlow(game: game, onFinished: () => finished++),
      );
      await wait(tester, 900);
      expect(key('final-decision-title'), findsOneWidget);
      expect(key('final-decision-button'), findsNothing);
      for (var i = 0; i < 3; i++) {
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .descendant(
                      of: key('card-slot-$i'),
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
          reason: 'rejected cards cannot be chosen',
        );
      }
      expect(find.text('Korea Retry Academy'), findsOneWidget);
      expect(find.text('Comprehensive Retake Course'), findsOneWidget);

      // Choosing the card only opens the modal.
      await tester.tap(key('final-retake-card'));
      await wait(tester, 400);
      expect(key('confirm-enrollment'), findsOneWidget);
      expect(game.state.finalDecided, isFalse);
      // X dismisses without enrolling.
      await tester.tap(key('enrollment-close'));
      await wait(tester, 400);
      expect(key('confirm-enrollment'), findsNothing);
      expect(game.state.finalDecided, isFalse);

      await tester.tap(key('final-retake-card'));
      await wait(tester, 400);
      await tester.tap(key('enrollment-confirm'));
      await tester.tap(key('enrollment-confirm'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(key('enrollment-loading'), findsOneWidget);
      expect(game.state.finalDecided, isFalse, reason: 'still loading');
      await tester.pump(const Duration(milliseconds: 900));
      await wait(tester, 800);
      expect(game.state.finalDecided, isTrue);
      expect(game.state.enrolledDepartment, isNull);
      expect(game.state.switchValue('ENDING_CODE'), 1);
      expect(key('results-scene'), findsOneWidget);
      expect(finished, 0);
    });

    testWidgets('mixed: rejected fade away, accepted centre, choose one', (
      tester,
    ) async {
      final game = committed([true, false, true], reviewed: true);
      final accepted = game.acceptedPrograms;
      expect(accepted, hasLength(2));
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await wait(tester, 900);
      expect(key('final-decision-button'), findsOneWidget);
      // Cards are stacked at the top before the button is pressed.
      expect(tester.getTopLeft(key('combined-card-0')).dy, lessThan(300));
      await tester.tap(key('final-decision-button'));
      await wait(tester, 900);
      double opacity(int i) => tester
          .widget<AnimatedOpacity>(
            find
                .descendant(
                  of: key('card-slot-$i'),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(1), 0, reason: 'the rejected card fades out');
      expect(opacity(0), 1);
      expect(opacity(2), 1);
      final centre = [
        for (final i in [0, 2]) tester.getCenter(key('combined-card-$i')).dy,
      ];
      expect((centre[0] + centre[1]) / 2, closeTo(873 * .56, 12));
      expect(key('final-decision-button'), findsNothing);
      expect(game.state.finalDecided, isFalse);

      // Choosing a card opens the modal for THAT school; confirm enrolls once.
      await tester.tap(key('final-card-2'));
      await wait(tester, 400);
      expect(key('confirm-enrollment'), findsOneWidget);
      await tester.tap(key('enrollment-confirm'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 900));
      await wait(tester, 800);
      expect(game.state.finalDecided, isTrue);
      expect(game.state.enrolledDepartment, accepted[1].department.id);
      expect(game.enroll(accepted[0].department.id), isFalse);
      expect(game.state.enrolledDepartment, accepted[1].department.id);
    });

    testWidgets('a resumed Final Decision page needs no re-confirmation', (
      tester,
    ) async {
      final game = committed([true, false, false], reviewed: true);
      expect(game.ddayStage, DDayStage.finalDecision);
      await host(tester, DdayResultsFlow(game: game, onFinished: () {}));
      await wait(tester, 900);
      expect(key('results-title'), findsNothing);
      expect(key('results-confirm-all'), findsNothing);
      expect(key('final-decision-button'), findsOneWidget);
    });
  });

  group('enrollment scene', () {
    Future<Game> enrolled(WidgetTester tester, {void Function()? done}) async {
      final game = committed([false, false, false], reviewed: true);
      game.enrollRetake();
      await host(
        tester,
        DdayResultsFlow(game: game, onFinished: done ?? () {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return game;
    }

    testWidgets('card, upload, panel, Confirm; no rank lines; finishes once', (
      tester,
    ) async {
      var finished = 0;
      final game = await enrolled(tester, done: () => finished++);
      expect(key('results-scene'), findsOneWidget);
      expect(key('student-id-card'), findsOneWidget);
      expect(find.textContaining('Ranked'), findsNothing);
      expect(find.text('Korean Student Simulator'), findsOneWidget);
      expect(
        find.text('Upload your photo to your student ID!'),
        findsOneWidget,
      );
      await tester.tap(key('share-instagram'));
      await tester.pump();
      expect(find.text('Not available in this build.'), findsOneWidget);
      await tester.tap(key('share-x'));
      await tester.pump();
      expect(find.text('Not available in this build.'), findsOneWidget);
      await tester.tap(key('scene-confirm'));
      await tester.tap(key('scene-confirm'), warnIfMissed: false);
      expect(finished, 1);
      expect(game.state.finalDecided, isTrue);
    });

    testWidgets('upload stores the chosen photo on the run', (tester) async {
      final dir = Directory.systemTemp.createTempSync('d30photo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final photo = File('${dir.path}/me.jpg')..writeAsBytesSync([0, 1, 2]);
      StudentPhotos.pickOverride = () async => photo.path;
      addTearDown(() => StudentPhotos.pickOverride = null);
      final game = await enrolled(tester);
      expect(game.state.studentPhotoPath, isNull);
      await tester.tap(key('upload-photo'));
      await tester.pump();
      await tester.pump();
      expect(game.state.studentPhotoPath, photo.path);
      expect(
        RunRecord.of(1, game.state, ending: 'Retake Ending').studentPhoto,
        photo.path,
      );
    });
  });

  group('completion summary and reward', () {
    Game finishedRun() {
      final game = committed([false, false, false], reviewed: true);
      game.enrollRetake();
      game.concludeRun();
      game.state.endingLabel = 'Retake Ending';
      return game;
    }

    testWidgets('shows the stored run: ID, title, five chips, score card', (
      tester,
    ) async {
      final game = finishedRun();
      await host(tester, EndScreen(outcome: game.outcome, state: game.state));
      expect(key('student-id-card'), findsOneWidget);
      expect(find.text('Retake Ending'), findsOneWidget);
      expect(find.text('Graduation Exam Score Card'), findsOneWidget);
      expect(find.text('Back to Main Menu'), findsOneWidget);
      for (final s in pack.manifest.subjects) {
        expect(
          tester.widget<Text>(key('stat-$s')).data,
          '${game.state.stats[s]!.round()}',
        );
      }
      final csat = game.state.csat!;
      for (final s in pack.manifest.subjects) {
        expect(find.text('${csat.examScores[s]}'), findsWidgets);
      }
    });

    testWidgets('the reward modal claims once, then Home', (tester) async {
      final game = finishedRun();
      final account = AccountStore.current;
      account.pendingEndingReward = const EndingReward('standard', 1);
      addTearDown(() => account.pendingEndingReward = null);
      await host(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('HOME')),
          ),
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('HOME')),
            ),
            MaterialPageRoute<void>(
              builder: (_) =>
                  EndScreen(outcome: game.outcome, state: game.state),
            ),
          ],
        ),
      );
      await tester.tap(key('back-to-main-menu'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('return-spinner'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Ending Reward Obtained!'), findsOneWidget);
      expect(find.text('1 Standard Trait Pack(s)'), findsOneWidget);
      await tester.tap(key('ending-reward-confirm'));
      await tester.tap(key('ending-reward-confirm'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(account.pendingEndingReward, isNull);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Ending Reward Obtained!'), findsNothing);

      // A second visit has nothing left to claim and goes straight home.
      await host(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('HOME')),
          ),
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('HOME')),
            ),
            MaterialPageRoute<void>(
              builder: (_) =>
                  EndScreen(outcome: game.outcome, state: game.state),
            ),
          ],
        ),
      );
      await tester.tap(key('back-to-main-menu'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Ending Reward Obtained!'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
