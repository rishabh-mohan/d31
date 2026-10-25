/// The exam cards, the score announcement and the Submit route
/// (docs/DDAY-UI.md). Packs load in setUpAll: file I/O inside testWidgets
/// hangs.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:d30mode/engine/admissions.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/dday_results.dart';
import 'package:d30mode/ui/event_screen.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/ui/score_announcement.dart';
import 'package:d30mode/ui/submit_page.dart';
import 'package:d30mode/ui/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ContentPack kss16;
  late ContentPack kss20;

  setUpAll(() async {
    kss16 = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    kss20 = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  setUp(D30Toast.reset);

  Game examDay(ContentPack p, {num each = 3000}) {
    final game = Game(
      pack: p,
      state: GameState.newRun(p, random: Random(7)),
    );
    game.state.openingComplete = true;
    game.state.date = GameDate(p.manifest.endDate.day, 0);
    for (final s in p.manifest.subjects) {
      game.state.stats[s] = each;
    }
    game.state.csatPending = true;
    return game;
  }

  Game reload(Game game) {
    final json =
        jsonDecode(jsonEncode(game.state.toJson())) as Map<String, dynamic>;
    return Game(pack: game.pack, state: GameState.fromJson(game.pack, json));
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpGame(WidgetTester tester, Game game, String id) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          game: game,
          packLocation: PackLocation(id, null, false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Taps the card, reads its line, and closes the scene.
  Future<void> takeCard(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(ValueKey('exam-card-$label')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EventScreen), findsOneWidget);
    expect(
      find.textContaining(RegExp("not so sure|wasn't so bad")),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EventScreen), findsNothing);
  }

  for (final (name, pick, id) in [
    ('kss16', () => kss16, 'kss16'),
    ('kss20', () => kss20, 'kss20'),
  ]) {
    testWidgets('exam cards play in order, one tick each ($name)', (
      tester,
    ) async {
      phone(tester);
      final game = examDay(pick());
      await pumpGame(tester, game, id);
      final labels = [for (final c in game.examCards) c.label];
      expect(labels.last, 'Humanities');
      for (var i = 0; i < labels.length - 1; i++) {
        expect(find.byKey(const ValueKey('exam-hand')), findsOneWidget);
        expect(find.text(labels[i]), findsWidgets);
        expect(find.byKey(ValueKey('day-tick-$i-empty')), findsOneWidget);
        await takeCard(tester, labels[i]);
        expect(find.byKey(ValueKey('day-tick-$i-filled')), findsOneWidget);
        expect(game.state.date.tick, i + 1);
      }
      await tester.tap(find.byKey(ValueKey('exam-card-${labels.last}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(game.examCardsComplete, isTrue);
      expect(game.state.date.tick, labels.length);
      expect(find.text('Graduation Exam Score Announcement'), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-hand')), findsNothing);
    });
  }

  testWidgets('a save mid-sequence resumes at the next card, no repeats', (
    tester,
  ) async {
    phone(tester);
    final first = examDay(kss16);
    first.takeExamSubject();
    first.takeExamSubject();
    final resumed = reload(first);
    await pumpGame(tester, resumed, 'kss16');
    expect(find.byKey(const ValueKey('exam-card-English')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-card-Korean')), findsNothing);
    expect(find.byKey(const ValueKey('day-tick-1-filled')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-tick-2-empty')), findsOneWidget);
    await takeCard(tester, 'English');
    expect(resumed.state.examCardsDone.length, 3);
    expect(resumed.state.date.tick, 3);
  });

  group('score announcement', () {
    testWidgets('Confirm, staggered reveal, Next, Turn in Papers', (
      tester,
    ) async {
      phone(tester);
      final game = examDay(kss16)..completeExamCards();
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreAnnouncementPanel(game: game, onDone: () => done++),
          ),
        ),
      );
      expect(find.text('Graduation Exam Score Announcement'), findsOneWidget);
      expect(find.byKey(const ValueKey('score-table')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('score-confirm')));
      await tester.pump();
      double opacityOf(String subject) => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(ValueKey('score-$subject')),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      final subjects = kss16.manifest.subjects;
      expect(opacityOf(subjects[0]), 1);
      expect(opacityOf(subjects[2]), 0);
      await tester.pump(scoreRevealStep + const Duration(milliseconds: 20));
      expect(opacityOf(subjects[1]), 1);
      expect(opacityOf(subjects[3]), 0);
      expect(find.text('Next'), findsOneWidget);
      await tester.pump(scoreRevealStep * 4);
      expect(opacityOf(subjects.last), 1);
      expect(
        find.text('${game.scoreCard.examScores[subjects[0]]}'),
        findsWidgets,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Graduation Exam Score Card'), findsOneWidget);
      expect(find.text('Show off your Score Card!'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('share-Instagram')));
      await tester.tap(find.byKey(const ValueKey('share-Instagram')));
      await tester.pump();
      expect(find.text('Not available in this build.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(game.state.scoreAnnounced, isFalse);
      await tester.ensureVisible(find.text('Turn in Papers'));
      await tester.tap(find.text('Turn in Papers'));
      await tester.pump();
      expect(done, 1);
      expect(game.state.scoreAnnounced, isTrue);
    });

    testWidgets('reduced motion shows every score at once', (tester) async {
      phone(tester);
      final game = examDay(kss16)..completeExamCards();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(393, 873),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: ScoreAnnouncementPanel(game: game, onDone: () {}),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('score-confirm')));
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);
      final last = kss16.manifest.subjects.last;
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: find.byKey(ValueKey('score-$last')),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        1,
      );
    });
  });

  group('submit route', () {
    Game ready() {
      final game = examDay(kss16)..completeExamCards();
      game.confirmScoreAnnouncement();
      return game;
    }

    Future<void> pumpSubmit(WidgetTester tester, Game game) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(home: SubmitPage(game: game)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> apply(WidgetTester tester, Department d) async {
      final button = find.byKey(ValueKey('apply-${d.id}'));
      await tester.scrollUntilVisible(
        button,
        150,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.tap(button);
      await tester.pump();
    }

    Future<void> clearToasts(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 30));

    /// Departments the default 20-80 range lists for [game] with one school
    /// each.
    List<Department> listed(Game game) {
      final seen = <int>{};
      return [
        for (final d in game.recommendedDepartments(minRate: 20, maxRate: 80))
          if (seen.add(d.universityId)) d,
      ];
    }

    testWidgets('apply, remove and Auto Input keep slot 1', (tester) async {
      final game = ready();
      await pumpSubmit(tester, game);
      final rows = listed(game);
      expect(rows.length, greaterThanOrEqualTo(2));
      expect(find.text('Application\nCandidate'), findsNWidgets(3));
      await apply(tester, rows.first);
      expect(game.draftSlots.first, rows.first.id);
      expect(find.byKey(const ValueKey('slot-0-filled')), findsOneWidget);
      expect(find.textContaining('application available.'), findsOneWidget);
      await clearToasts(tester);

      await tester.tap(find.byKey(const ValueKey('auto-input')));
      await tester.pump();
      expect(game.draftSlots.first, rows.first.id);
      expect(game.draftSlots.every((s) => s != null), isTrue);
      await clearToasts(tester);

      await tester.tap(find.byKey(const ValueKey('slot-2-filled')));
      await tester.pump();
      expect(game.draftSlots[2], isNull);
      expect(game.draftSlots.first, rows.first.id);
      expect(
        find.textContaining('You started writing and then deleted your'),
        findsOneWidget,
      );
      await clearToasts(tester);
    });

    testWidgets('Turn In turns red when all three slots are filled', (
      tester,
    ) async {
      final game = ready();
      await pumpSubmit(tester, game);
      Color turnInColor() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.ancestor(
                          of: find.byKey(const ValueKey('turn-in-button')),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(turnInColor(), const Color(0xFFC95A24));
      await tester.tap(find.byKey(const ValueKey('auto-input')));
      await tester.pumpAndSettle();
      expect(turnInColor(), const Color(0xFFE5173F));
      await clearToasts(tester);
    });

    testWidgets('Hide Applied Universities hides a drafted school', (
      tester,
    ) async {
      // Find a school with two listed majors.
      final game = ready();
      await pumpSubmit(tester, game);
      final byUniversity = <int, List<Department>>{};
      for (final d in game.recommendedDepartments(minRate: 20, maxRate: 80)) {
        (byUniversity[d.universityId] ??= []).add(d);
      }
      final pair = byUniversity.values.firstWhere(
        (l) => l.length >= 2,
        orElse: () => const [],
      );
      expect(pair, isNotEmpty, reason: 'no school with two majors in range');
      await apply(tester, pair[0]);
      await clearToasts(tester);
      expect(
        find.byKey(ValueKey('major-card-${pair[1].id}'), skipOffstage: false),
        findsNothing,
      );
      Future<void> toggle() async {
        final sw = find.byKey(const ValueKey('hide-applied-switch'));
        await tester.scrollUntilVisible(
          sw,
          -200,
          scrollable: find.byType(Scrollable).at(1),
        );
        await tester.tap(sw);
        await tester.pump();
      }

      await toggle();
      expect(
        find.byKey(ValueKey('major-card-${pair[0].id}'), skipOffstage: false),
        findsOneWidget,
      );
      await toggle();
      expect(
        find.byKey(ValueKey('major-card-${pair[0].id}'), skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('Apply? cancel keeps the draft; Confirm commits once', (
      tester,
    ) async {
      final game = ready();
      await pumpSubmit(tester, game);
      await tester.tap(find.byKey(const ValueKey('turn-in-button')));
      await tester.pump();
      expect(find.text('Apply?'), findsNothing);
      expect(find.textContaining('at least one'), findsOneWidget);
      await clearToasts(tester);

      await tester.tap(find.byKey(const ValueKey('auto-input')));
      await tester.pump();
      await clearToasts(tester);
      final before = List.of(game.draftSlots);
      await tester.tap(find.byKey(const ValueKey('turn-in-button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Apply?'), findsOneWidget);
      final expected =
          'Chances of total rejection : '
          '${game.totalRejectionText(game.draftDepartments)}%';
      expect(find.text(expected), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('apply-close')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Apply?'), findsNothing);
      expect(game.draftSlots, before);
      expect(game.state.applicationsCommitted, isFalse);

      await tester.tap(find.byKey(const ValueKey('turn-in-button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byKey(const ValueKey('apply-confirm')));
      await tester.tap(find.byKey(const ValueKey('apply-confirm')));
      await tester.pump();
      expect(game.state.applicationsCommitted, isTrue);
      final applications = List.of(game.state.applications);
      expect(applications.length, before.whereType<int>().length);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DdayResultsFlow), findsOneWidget);
      expect(game.state.applications, applications);
    });

    testWidgets('Search Majors filters live and keeps the query', (
      tester,
    ) async {
      final game = ready();
      await pumpSubmit(tester, game);
      await tester.tap(find.byKey(const ValueKey('submit-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('Search for your major of choice'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('major-search')), 'com');
      await tester.pump();
      final matches = game.searchMajors('com');
      expect(matches, isNotEmpty);
      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => t.startsWith('Department of') || t.contains('Dep'));
      expect(shown, isNotEmpty);
      expect(
        find.byKey(ValueKey('major-card-${matches.first.id}')),
        findsOneWidget,
      );
      final other = game
          .searchMajors('')
          .firstWhere((d) => !d.name.toLowerCase().contains('com'));
      expect(
        find.byKey(ValueKey('major-card-${other.id}'), skipOffstage: false),
        findsNothing,
      );

      // Modal round trip and tab switches keep the query.
      await tester.tap(find.byKey(const ValueKey('collection-button')));
      await tester.pumpAndSettle();
      expect(find.text('University Collection'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('collection-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-tab-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('com'), findsOneWidget);
      expect(
        find.byKey(ValueKey('major-card-${matches.first.id}')),
        findsOneWidget,
      );
    });

    testWidgets('Search within Schools lists tiers and opens a school', (
      tester,
    ) async {
      final game = ready();
      await pumpSubmit(tester, game);
      await tester.tap(find.byKey(const ValueKey('submit-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('Korea'), findsOneWidget);
      final catalog = game.pack.admissions;
      final top = catalog.inCategory(UniversityCategory.korea).first;
      expect(find.byKey(ValueKey('school-${top.id}')), findsOneWidget);
      // A locked story-only school stays darkened.
      await tester.tap(find.byKey(const ValueKey('schools-special')));
      await tester.pump();
      final locked = catalog
          .inCategory(UniversityCategory.special)
          .where((u) => !u.available);
      if (locked.isNotEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('school-locked-${locked.first.id}')),
          200,
          scrollable: find.byType(Scrollable).at(1),
        );
        expect(find.textContaining('Available for admission in'), findsWidgets);
      }
      await tester.tap(find.byKey(const ValueKey('schools-korea')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('school-${top.id}')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('school-back')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('school-back')));
      await tester.pump();
      expect(find.byKey(ValueKey('school-${top.id}')), findsOneWidget);
    });
  });
}
