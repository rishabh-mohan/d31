/// The D-Day engine API (docs/DDAY-FLOW.md): exam cards, fitted exam scores,
/// the draft, the commit, the final decision, local counts and the ending
/// reward. Plain `test`s only: file I/O inside testWidgets hangs.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/admissions.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/record_store.dart';
import 'package:d30mode/engine/state.dart';

void main() {
  late ContentPack pack;
  late ContentPack retry;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });

  /// A run on exam day with the Graduation Exam scene over (START_SAT).
  Game examDay(ContentPack p, {num each = 3000, int seed = 7}) {
    final game = Game(
      pack: p,
      state: GameState.newRun(p, random: _Seeded(seed)),
    );
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

  /// Departments in [game] whose displayed rate is [rate], one per school.
  List<Department> withRate(Game game, int rate, {int take = 3}) {
    final seen = <int>{};
    final out = <Department>[];
    for (final d in game.eligibleDepartments()) {
      if (game.displayedRate(d) == rate && seen.add(d.universityId)) {
        out.add(d);
        if (out.length == take) break;
      }
    }
    return out;
  }

  group('arithmetic', () {
    test('total rejection matches both recorded Apply? modals', () {
      expect(
        Admissions.totalRejectionPercent([23, 20, 35]),
        closeTo(40.04, 1e-9),
      );
      expect(
        Admissions.totalRejectionPercent([23, 9, 10]),
        closeTo(63.063, 1e-9),
      );
      expect(
        Admissions.formatPercent(
          Admissions.totalRejectionPercent([23, 20, 35]),
        ),
        '40.04',
      );
      expect(
        Admissions.formatPercent(Admissions.totalRejectionPercent([23, 9, 10])),
        '63.063',
      );
      expect(Admissions.formatPercent(100), '100');
      expect(Admissions.formatPercent(7.5), '7.5');
      expect(Admissions.totalRejectionPercent([100]), 0);
      expect(Admissions.totalRejectionPercent(const []), 100);
    });

    test('Game.totalRejectionChance uses the displayed rates', () {
      final game = examDay(pack, each: 3000);
      final picks = <Department>[
        for (final r in [23, 20, 35, 9, 10, 40, 5])
          ...withRate(game, r, take: 1),
      ];
      // Whatever rates the fitted model offers, the product must be of the
      // displayed (rounded) values.
      final trio = picks.take(3).toList();
      final expected = trio.fold<double>(
        100,
        (a, d) => a * (1 - game.displayedRate(d) / 100),
      );
      expect(game.totalRejectionChance(trio), closeTo(expected, 1e-6));
      expect(
        game.totalRejectionText(trio),
        Admissions.formatPercent(game.totalRejectionChance(trio)),
      );
    });
  });

  group('graduation exam scores', () {
    const stats = [2205, 2158, 1253, 1630, 3476];
    const scores = [58, 59, 50, 53, 66];
    const tops = [47.7, 46.1, 58.6, 55.0, 35.8];

    test('the fitted curve reproduces the recorded fixture closely', () {
      for (var i = 0; i < 5; i++) {
        // Base (no variation) is within a point; with the seeded variation,
        // any seed stays within two of the recording.
        expect(
          (GraduationExam.baseScore(stats[i]) - scores[i]).abs(),
          lessThan(1.5),
        );
        for (var seed = 0; seed < 200; seed++) {
          final s = GraduationExam.score(stats[i], seed);
          expect(
            (s - scores[i]).abs(),
            lessThanOrEqualTo(2),
            reason: '$i/$seed',
          );
        }
      }
    });

    test('Top % passes exactly through the recorded pairs and is monotone', () {
      for (var i = 0; i < 5; i++) {
        expect(GraduationExam.topPercent(scores[i]), tops[i]);
      }
      var last = 101.0;
      for (var s = 0; s <= 100; s++) {
        final t = GraduationExam.topPercent(s);
        expect(t, lessThanOrEqualTo(last));
        last = t;
      }
    });

    test('scores are integers 0-100 and Top % has one decimal', () {
      final game = examDay(pack, each: 2000);
      game.completeExamCards();
      final card = game.scoreCard;
      expect(card.examScores.keys, pack.manifest.subjects);
      for (final s in pack.manifest.subjects) {
        expect(card.examScores[s], inInclusiveRange(0, 100));
        final top = card.topPercents[s]!;
        expect((top * 10).roundToDouble(), closeTo(top * 10, 1e-9));
      }
    });

    test('stored once: reopening or reloading never rerolls', () {
      final game = examDay(pack, each: 2400);
      game.completeExamCards();
      final first = game.scoreCard.examScores;
      final loaded = reload(game);
      expect(loaded.scoreCard.examScores, first);
      // Even if the stats moved afterwards, the recorded card stands.
      loaded.state.stats['korean'] = 9999;
      expect(loaded.scoreCard.examScores, first);
      // A fresh Game over the same state derives the same numbers.
      final again = examDay(pack, each: 2400);
      again.state.firstName = game.state.firstName;
      again.state.lastName = game.state.lastName;
      expect(again.examScoreFor('math'), game.state.examCardScores['math']);
    });
  });

  group('exam cards', () {
    test(
      'five cards in the pack order with display labels, both campaigns',
      () {
        for (final p in [pack, retry]) {
          final game = examDay(p);
          expect(game.examCardsPending, isTrue);
          expect(game.ddayStage, DDayStage.examCards);
          expect([
            for (final c in game.examCards) c.subject,
          ], p.manifest.subjects);
          expect(
            [for (final c in game.examCards) c.label],
            ['Korean', 'Maths', 'English', 'Science', 'Humanities'],
          );
        }
      },
    );

    test('each card advances one tick and is taken once, in order', () {
      final game = examDay(pack, each: 2200);
      final start = game.state.date.tick;
      final order = <String>[];
      for (var i = 0; i < 5; i++) {
        final turn = game.takeExamSubject()!;
        order.add(turn.subject);
        expect(game.state.date.tick, start + i + 1);
        expect(
          turn.response,
          anyOf("I'm not so sure about this...", "That wasn't so bad..."),
        );
      }
      expect(order, pack.manifest.subjects);
      expect(game.takeExamSubject(), isNull);
      expect(game.examCardsComplete, isTrue);
      expect(game.state.date.tick, start + 5);
      expect(game.ddayStage, DDayStage.scoreAnnouncement);
    });

    test('the response follows the subject score threshold', () {
      final strong = examDay(pack, each: 6000);
      expect(strong.takeExamSubject()!.response, "That wasn't so bad...");
      final weak = examDay(pack, each: 1000);
      expect(weak.takeExamSubject()!.response, "I'm not so sure about this...");
    });

    test('resumable from a save without repeating a step', () {
      final game = examDay(pack, each: 2200);
      game.takeExamSubject();
      game.takeExamSubject();
      final loaded = reload(game);
      expect(loaded.state.examCardsDone, ['korean', 'math']);
      expect(loaded.currentExamCard!.subject, 'english');
      final tick = loaded.state.date.tick;
      loaded.takeExamSubject();
      expect(loaded.state.date.tick, tick + 1);
      loaded.completeExamCards();
      expect(loaded.state.examCardsDone, pack.manifest.subjects);
      expect(loaded.state.date.tick, 5);
    });

    test('nothing to take off exam day', () {
      final game = Game.newRun(pack);
      expect(game.examCardsPending, isFalse);
      expect(game.takeExamSubject(), isNull);
      expect(game.ddayStage, DDayStage.none);
    });
  });

  group('draft', () {
    test('add, remove, hide-applied and one school per draft', () {
      final game = examDay(pack, each: 4000)..completeExamCards();
      final pool = game.recommendedDepartments(hideApplied: false);
      final a = pool.first;
      expect(game.addToDraft(a.id), 0);
      expect(game.isUniversityDrafted(a.universityId), isTrue);
      expect(
        game.recommendedDepartments().any(
          (d) => d.universityId == a.universityId,
        ),
        isFalse,
      );
      expect(
        game
            .recommendedDepartments(hideApplied: false)
            .any((d) => d.id == a.id),
        isTrue,
      );
      // A second major of the same school is refused.
      final sibling = pack.admissions
          .departmentsOf(a.universityId)
          .firstWhere((d) => d.id != a.id);
      expect(game.addToDraft(sibling.id), isNull);
      expect(game.draftProblem(sibling), isNotNull);
      expect(game.removeFromDraft(0), isTrue);
      expect(game.removeFromDraft(0), isFalse);
      expect(game.isHiddenByApplied(a), isFalse);
    });

    test('Auto Input fills only empty slots and keeps slot 1', () {
      final game = examDay(pack, each: 4000)..completeExamCards();
      final first = game.recommendedDepartments().first;
      game.addToDraft(first.id);
      final filled = game.autoFill();
      expect(filled, [1, 2]);
      final slots = game.draftSlots;
      expect(slots[0], first.id);
      expect(slots.whereType<int>().length, 3);
      final schools = game.draftDepartments.map((d) => d.universityId).toSet();
      expect(schools.length, 3);
      // Full tray: nothing changes.
      final before = List.of(game.draftSlots);
      expect(game.autoFill(), isEmpty);
      expect(game.draftSlots, before);
      // A middle gap fills just that slot.
      game.removeFromDraft(1);
      expect(game.autoFill(), [1]);
      expect(game.draftSlots[0], first.id);
      expect(game.draftSlots[2], before[2]);
    });

    test('the draft survives save and load, uncommitted', () {
      final game = examDay(pack, each: 4000)..completeExamCards();
      game.addToDraft(game.recommendedDepartments().first.id);
      game.autoFill();
      final loaded = reload(game);
      expect(loaded.draftSlots, game.draftSlots);
      expect(loaded.state.applications, isEmpty);
      expect(loaded.state.applicationsCommitted, isFalse);
    });
  });

  group('commit and final decision', () {
    test('submitDraft rolls once, in order, and never rerolls', () {
      final game = examDay(pack, each: 5000)..completeExamCards();
      game.confirmScoreAnnouncement();
      game.addToDraft(
        game.recommendedDepartments(minRate: 30, maxRate: 70).first.id,
      );
      game.autoFill();
      expect(game.state.draft.whereType<int>().length, 3);
      final results = game.submitDraft();
      expect(results.length, 3);
      expect([for (final r in results) r.department.id], game.state.draft);
      for (final r in results) {
        expect(r.rate, game.displayedRate(r.department));
      }
      final snapshot = [
        for (final r in results) (r.department.id, r.rate, r.accepted),
      ];
      // Idempotent.
      expect([
        for (final r in game.submitDraft())
          (r.department.id, r.rate, r.accepted),
      ], snapshot);
      // Not rerolled after a save/load either, even with a different RNG.
      final loaded = reload(game);
      expect(loaded.state.applicationsCommitted, isTrue);
      expect([
        for (final r in loaded.submitDraft())
          (r.department.id, r.rate, r.accepted),
      ], snapshot);
      expect(loaded.state.applications, game.state.applications);
      // The draft can no longer be edited.
      expect(loaded.addToDraft(1), isNull);
      expect(loaded.removeFromDraft(0), isFalse);
    });

    test('1 to 3 candidates may be submitted; none commits nothing', () {
      final game = examDay(pack, each: 5000)..completeExamCards();
      expect(game.submitDraft(), isEmpty);
      expect(game.state.applicationsCommitted, isFalse);
      game.addToDraft(game.recommendedDepartments().first.id);
      expect(game.submitDraft(), hasLength(1));
    });

    test('rate 100 always accepts and rate 0 never does', () {
      final game = examDay(pack, each: 50000)..completeExamCards();
      final sure = withRate(game, 100, take: 2);
      expect(sure.length, 2);
      for (final d in sure) {
        game.addToDraft(d.id);
      }
      final results = game.submitDraft();
      expect(results.every((r) => r.accepted), isTrue);
      expect(game.acceptedPrograms, hasLength(2));

      final weak = examDay(pack, each: 0)..completeExamCards();
      final hopeless = withRate(weak, 0, take: 3);
      for (final d in hopeless) {
        weak.addToDraft(d.id);
      }
      expect(weak.submitDraft().any((r) => r.accepted), isFalse);
    });

    test('choose among acceptances; enrollment is idempotent', () {
      final game = examDay(pack, each: 50000)..completeExamCards();
      for (final d in withRate(game, 100, take: 3)) {
        game.addToDraft(d.id);
      }
      game.submitDraft();
      expect(game.acceptedPrograms, hasLength(3));
      expect(game.finalDecisionOptions.every((o) => !o.isRetake), isTrue);
      expect(game.enrollRetake(), isFalse, reason: 'something accepted you');
      final other = game.acceptedPrograms[1].department.id;
      expect(game.enroll(999999), isFalse);
      expect(game.state.finalDecided, isFalse);
      expect(game.enroll(other), isTrue);
      expect(game.state.enrolledDepartment, other);
      expect(game.state.switchValue('ENDING_CODE'), 1);
      expect(game.state.csatPending, isFalse);
      // Second call changes nothing.
      expect(game.enroll(game.acceptedPrograms[0].department.id), isFalse);
      expect(game.state.enrolledDepartment, other);
      expect(
        game.applicationResults.where((r) => r.enrolled).single.department.id,
        other,
      );
      expect(reload(game).state.finalDecided, isTrue);
    });

    test('all rejected offers the retake academy, in both campaigns', () {
      for (final p in [pack, retry]) {
        final game = examDay(p, each: 0)..completeExamCards();
        for (final d in withRate(game, 0, take: 3)) {
          game.addToDraft(d.id);
        }
        game.submitDraft();
        expect(game.acceptedPrograms, isEmpty);
        final options = game.finalDecisionOptions;
        expect(options, hasLength(1));
        expect(options.single.isRetake, isTrue);
        expect(options.single.university!.name, 'Korea Retry Academy');
        expect(options.single.department.name, 'Comprehensive Retake Course');
        expect(game.enrollRetake(), isTrue);
        expect(game.enrollRetake(), isFalse);
        expect(game.state.enrolledDepartment, isNull);
        expect(game.state.switchValue('ENDING_CODE'), 1);
        game.concludeRun();
        expect(game.state.finished, isTrue);
        expect(game.outcome, isNotEmpty);
      }
    });

    test('stages advance from announcement to ending and survive a save', () {
      final game = examDay(pack, each: 50000);
      expect(game.ddayStage, DDayStage.examCards);
      game.completeExamCards();
      expect(game.ddayStage, DDayStage.scoreAnnouncement);
      game.confirmScoreAnnouncement();
      expect(reload(game).ddayStage, DDayStage.drafting);
      game.addToDraft(withRate(game, 100, take: 1).single.id);
      game.submitDraft();
      expect(reload(game).ddayStage, DDayStage.results);
      game.confirmResults();
      expect(reload(game).ddayStage, DDayStage.finalDecision);
      game.enroll(game.acceptedPrograms.first.department.id);
      expect(game.ddayStage, DDayStage.ending);
    });
  });

  group('catalog', () {
    test('both campaigns carry all 137 universities in four tabs', () {
      for (final p in [pack, retry]) {
        final a = p.admissions;
        expect(a.universities.length, 137);
        expect(a.inCategory(UniversityCategory.korea).length, 51);
        expect(a.inCategory(UniversityCategory.global).length, 10);
        expect(a.inCategory(UniversityCategory.taiwan).length, 70);
        expect(a.inCategory(UniversityCategory.special).length, 5);
        expect(a.inCategory(UniversityCategory.retake).length, 1);
        expect(a.departments.length, greaterThan(3300));
        // Stars come from the rank ladder; the Korea tab leads with Dream U.
        expect(a.universities[2]!.stars, 5);
        expect(a.inCategory(UniversityCategory.korea).first.stars, 5);
        expect(a.universities[1]!.stars, 4.5);
        // Global/Taiwan labels come from the shared overlay.
        expect(a.universities[203]!.category, UniversityCategory.global);
        expect(a.universities[203]!.name, isNot(contains('sf')));
        expect(
          a.inCategory(UniversityCategory.global).map((u) => u.name),
          contains(contains('Stanford')),
        );
        expect(a.universities[0]!.category, UniversityCategory.retake);
        expect(a.universities[0]!.crestPath, endsWith('0.svg'));
      }
    });

    test('department ids and cutoffs match the original catalog', () {
      final d = pack.admissions.departments[4010]!;
      expect(d.universityId, 4);
      expect(d.deviation, 68.2);
      expect(retry.admissions.departments[4010]!.deviation, 68.2);
    });

    test('story-only schools keep their availability', () {
      final basakan = pack.admissions.universities[56]!;
      expect(basakan.available, isTrue);
      expect(retry.admissions.universities[56]!.available, isFalse);
      // The Retry Universities belong to story 20.
      for (final id in [54, 55]) {
        expect(pack.admissions.universities[id]!.available, isFalse);
        expect(pack.admissions.universities[id]!.availableStories, [20]);
        expect(pack.admissions.departmentsOf(id), isEmpty);
        expect(retry.admissions.universities[id]!.available, isTrue);
        expect(retry.admissions.departmentsOf(id), isNotEmpty);
      }
      final g16 = examDay(pack);
      final g20 = examDay(retry);
      expect(
        g16.eligibleDepartments().any((d) => d.universityId == 55),
        isFalse,
      );
      expect(
        g20.eligibleDepartments().any((d) => d.universityId == 55),
        isTrue,
      );
      // The Retry Academy is never a candidate.
      expect(
        g16.eligibleDepartments().any((d) => d.universityId == 0),
        isFalse,
      );
      expect(g16.addToDraft(0), isNull);
    });

    test('the US set renames only the regular Korean universities', () {
      for (final base in [pack, retry]) {
        final us = base.withColleges('us');
        for (final u in base.admissions.universities.values) {
          final other = us.admissions.universities[u.id]!;
          if (u.category == UniversityCategory.korea) {
            expect(other.name, isNot(u.name), reason: '${u.id}');
          } else {
            expect(other.name, u.name, reason: '${u.id}');
          }
          expect(other.category, u.category);
          expect(other.stars, u.stars);
        }
      }
    });

    test('search majors matches substrings in department names', () {
      final game = examDay(pack);
      final hits = game.searchMajors('com');
      expect(hits, isNotEmpty);
      expect(hits.every((d) => d.name.toLowerCase().contains('com')), isTrue);
      expect(game.searchMajors('').length, game.eligibleDepartments().length);
    });
  });

  group('local counts and the ending reward', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('dday_flow_test');
      RecordStore.directoryOverride = Directory('${temp.path}/records');
      AccountStore.fileOverride = File('${temp.path}/account.json');
      AccountStore.current = Account();
    });

    tearDown(() async {
      RecordStore.directoryOverride = null;
      AccountStore.fileOverride = null;
      AccountStore.current = Account();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    Future<RunRecord> finish(Game game) async {
      game.concludeRun();
      final record = await RecordStore.add(game.state, ending: game.outcome);
      return record!;
    }

    test(
      'enrollees and # Enrollments count this account\'s own runs',
      () async {
        final account = Account();
        var department = 0;
        for (var run = 0; run < 3; run++) {
          final game = examDay(pack, each: 50000, seed: run)
            ..completeExamCards();
          final pick = withRate(game, 100, take: 1).single;
          department = pick.id;
          game.addToDraft(pick.id);
          game.submitDraft();
          game.enroll(pick.id);
          account.recordRun(await finish(game), AccountStore.catalog);
        }
        final uni = pack.admissions.departments[department]!.universityId;
        expect(account.universityEnrollees(uni), 3);
        expect(account.majorEnrollments(department), 3);
        expect(account.majorEnrollments(999999), 0);
        // Round-trips with the account.
        final back = Account.fromJson(
          jsonDecode(jsonEncode(account.toJson())) as Map<String, dynamic>,
        );
        expect(back.majorEnrollments(department), 3);
      },
    );

    test('a retake counts as no enrollment', () async {
      final account = Account();
      final game = examDay(pack, each: 0)..completeExamCards();
      game.enrollRetake();
      account.recordRun(await finish(game), AccountStore.catalog);
      expect(account.enrollments, isEmpty);
      expect(account.departmentEnrollments, isEmpty);
    });

    test('one Standard Trait Pack per completed run, granted once', () async {
      final account = Account();
      final game = examDay(pack, each: 0)..completeExamCards();
      game.enrollRetake();
      final record = await finish(game);
      account.recordRun(record, AccountStore.catalog);
      expect(account.packs['standard'], 1);
      expect(account.pendingEndingReward!.count, 1);
      expect(account.pendingEndingReward!.packId, 'standard');
      // Recording the same run again pays nothing more.
      account.recordRun(record, AccountStore.catalog);
      expect(account.packs['standard'], 1);
      expect(account.pendingEndingReward!.count, 1);
      // The pending dialog survives a restart until confirmed.
      final back = Account.fromJson(
        jsonDecode(jsonEncode(account.toJson())) as Map<String, dynamic>,
      );
      expect(back.pendingEndingReward!.count, 1);
      back.acknowledgeEndingReward();
      expect(back.pendingEndingReward, isNull);
      expect(back.packs['standard'], 1);
    });
  });
}

/// A Random whose stream is fixed by [seed] (the engine only needs
/// determinism in tests).
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
