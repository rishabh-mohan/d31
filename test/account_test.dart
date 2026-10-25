/// The account rules behind Home's pages: ending rewards, achievements,
/// trait packs and mileage, combining, puzzles and the daily quest.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_catalog.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/record_store.dart';

void main() {
  late ContentPack pack;
  late AccountCatalog catalog;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    catalog = AccountCatalog.parse(
      await File('assets/account/catalog.json').readAsString(),
    );
  });

  RunRecord record({
    int? ending,
    int? department,
    int? university,
    String packId = 'kss16',
    int exercise = 0,
    DateTime? at,
  }) => RunRecord(
    id: 0,
    name: 'Greg',
    portrait: '',
    packId: packId,
    modeTitle: '31-Day Mode',
    ending: 'x',
    finishedAt: at ?? DateTime.now(),
    stats: const {},
    endingCode: ending,
    enrolledDepartmentId: department,
    enrolledUniversityId: university,
    exerciseLevel: exercise,
  );

  test('the catalog has every campaign\'s endings and puzzles', () {
    expect(catalog.endings[30003]!.cookies, 3);
    expect(catalog.endings[30003]!.storyId, 3);
    expect(catalog.endingsOf(20), hasLength(13));
    final ihyeon = catalog.puzzles.firstWhere((p) => p.id == 'wallpaper1');
    expect(ihyeon.totalCookies, 99);
    expect(catalog.universities.where((u) => u.region == 'taiwan'), isNotEmpty);
    expect(catalog.universities.firstWhere((u) => u.id == 2).stars, 5);
    expect(catalog.universities.firstWhere((u) => u.id == 1).stars, 4.5);
  });

  test('an ending pays its cookies once', () {
    final a = Account();
    expect(a.recordRun(record(ending: 200004), catalog), 3);
    expect(a.cookies, 3);
    a.recordRun(record(ending: 200004), catalog);
    expect(a.cookies, 3);
    expect(a.endings, {200004});
  });

  test('achievements complete and Story Addict pays its 5', () {
    final a = Account();
    for (final code in [200001, 200002, 200003, 200005, 200006]) {
      a.recordRun(record(ending: code), catalog);
    }
    final addict = AchievementInfo.all.first;
    expect(a.achievementDone(addict), isTrue);
    // 1 + 2 + 2 + 1 + 1 for the endings, 5 for the achievement.
    expect(a.cookies, 7 + 5);
    a.payAchievements();
    expect(a.cookies, 12);
    a.recordRun(record(exercise: 10), catalog);
    expect(
      a.achievementDone(
        AchievementInfo.all.firstWhere((x) => x.id == 'gym_rat'),
      ),
      isTrue,
    );
  });

  test('packs cost cookies and open into owned copies', () {
    final a = Account(cookies: 20);
    final standard = TraitPackKind.byId('standard')!;
    expect(a.buyPack(standard), isTrue);
    expect(a.buyPack(standard), isFalse);
    expect(a.cookies, 5);
    final drawn = a.openPack(standard, pack, Random(1))!;
    expect(drawn, hasLength(3));
    expect(a.traits, hasLength(3));
    expect(a.packs['standard'], 0);
    expect(a.openPack(standard, pack), isNull);
    for (final t in drawn) {
      expect(t.setupEligible, isTrue);
      expect(t.storyId, isNull);
    }
  });

  test('full mileage guarantees an S card and empties', () {
    final a = Account(mileage: mileageMax, packs: {'standard': 1});
    final drawn = a.openPack(TraitPackKind.byId('standard')!, pack, Random(3))!;
    expect(drawn.first.rank, 'S');
    expect(a.mileage, 0);
  });

  test('rolled odds follow the recovered rates', () {
    final a = Account(packs: {'jumbo': 2000});
    final rng = Random(7);
    final ranks = <String, int>{};
    for (var i = 0; i < 2000; i++) {
      a.mileage = 0;
      for (final t in a.openPack(TraitPackKind.byId('jumbo')!, pack, rng)!) {
        ranks[t.rank] = (ranks[t.rank] ?? 0) + 1;
      }
    }
    final c = ranks['C']! / 10000;
    expect(c, closeTo(.80, .02));
    expect((ranks['B'] ?? 0) / 10000, closeTo(.15, .02));
  });

  test('combining takes three unlocked cards, S only with S', () {
    final a = Account();
    int idOf(String rank) => pack.traits.values
        .firstWhere(
          (t) => t.setupEligible && t.rank == rank && t.storyId == null,
        )
        .id;
    final s = OwnedTrait(1, idOf('S'));
    final b1 = OwnedTrait(2, idOf('B'));
    final b2 = OwnedTrait(3, idOf('B'));
    final b3 = OwnedTrait(4, idOf('B'), locked: true);
    a.traits.addAll([s, b1, b2, b3]);
    a.nextTraitUid = 5;
    expect(a.combineProblem([s, b1, b2], pack), contains('S-Ranks'));
    expect(a.combineProblem([b1, b2, b3], pack), contains('locked'));
    expect(a.combineProblem([b1, b2], pack), isNotNull);
    b3.locked = false;
    final result = a.combine([b1, b2, b3], pack, 'standard', Random(2))!;
    expect(['B', 'A'], contains(result.rank));
    expect(a.traits.map((t) => t.uid), [1, 5]);
  });

  test('puzzle progress is weighted by piece cookies', () {
    final a = Account(endings: {30009, 30010});
    final seoA = catalog.puzzles.firstWhere((p) => p.id == 'wallpaper3');
    expect(a.piecesOf(seoA, const {}), [false, false, true, true]);
    final weight = seoA.pieces[0].cookies + seoA.pieces[1].cookies;
    expect(a.completeNowPrice(seoA, const {}), weight);
    expect(
      a.puzzleProgress(seoA, const {}),
      closeTo(1 - weight / seoA.totalCookies, 1e-9),
    );
    a.cookies = 200;
    expect(a.completeNow(seoA, const {}), isTrue);
    expect(a.piecesOf(seoA, const {}).every((h) => h), isTrue);
    expect(a.cookies, 200 - weight);
    // An event-only puzzle cannot be bought.
    final event = catalog.puzzles.firstWhere((p) => p.id == 'wallpaper1010');
    expect(a.completeNowPrice(event, const {}), isNull);
  });

  test('the daily quest is stable for the day and pays once', () {
    final a = Account();
    final day = DateTime(2026, 10, 24, 9);
    final q = a.questFor(day, pack.admissions)!;
    expect(a.questFor(DateTime(2026, 10, 24, 23), pack.admissions), same(q));
    expect(pack.admissions.universities[q.universityId]!.storyOnly, isFalse);
    final done = record(
      department: q.departmentId,
      university: q.universityId,
      at: DateTime(2026, 10, 24, 12),
    );
    expect(a.claimQuest([record(at: DateTime(2026, 10, 24, 12))]), isFalse);
    expect(a.claimQuest([done]), isTrue);
    expect(a.cookies, dailyQuestCookies);
    expect(a.claimQuest([done]), isFalse);
    expect(
      a.questFor(DateTime(2026, 10, 25), pack.admissions)!.date,
      '2026-10-25',
    );
  });

  test('the account round-trips', () {
    final a = Account(cookies: 9, mileage: 40)
      ..endings.add(30003)
      ..enrollments[2] = 3
      ..traits.add(OwnedTrait(7, 160001, locked: true))
      ..packs['jumbo'] = 2
      ..boughtPuzzles.add('wallpaper1');
    final b = Account.fromJson(a.toJson());
    expect(b.cookies, 9);
    expect(b.mileage, 40);
    expect(b.endings, {30003});
    expect(b.enrollments[2], 3);
    expect(b.traits.single.locked, isTrue);
    expect(b.packs['jumbo'], 2);
    expect(b.boughtPuzzles, {'wallpaper1'});
  });
}
