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

  Puzzle retryPuzzle(String id) =>
      catalog.allPuzzles.firstWhere((p) => p.id == id);

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    final retry = await ContentSource.loadFromDirectory(
      Directory('packs/kss20'),
    );
    catalog = AccountCatalog.parse(
      await File('assets/account/catalog.json').readAsString(),
    ).withShelves([retry.puzzleShelf(Directory('packs/kss20').absolute.path)!]);
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
    expect(retryPuzzle('wallpaper201').totalCookies, 69);
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

  test('first-time endings pay their Endings List cookies', () {
    final a = Account();
    for (final code in [200001, 200002, 200003, 200005, 200006]) {
      a.recordRun(record(ending: code), catalog);
    }
    expect(a.cookies, 1 + 2 + 2 + 1 + 1);
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
    final a = Account(endings: {200009});
    final suin = retryPuzzle('wallpaper201');
    expect(a.piecesOf(suin), [true, false, false, false]);
    expect(a.puzzleProgress(suin), closeTo(30 / 69, 1e-9));
    // Game-count pieces carry no price, so the rest cannot be bought.
    expect(a.completeNowPrice(suin), isNull);
    // A finished run of the owning pack fills them one by one.
    a.clears['kss20'] = 1;
    expect(a.piecesOf(suin), [true, false, true, false]);
    a.clears['kss20'] = 2;
    a.endings.add(200010);
    expect(a.piecesOf(suin).every((h) => h), isTrue);

    // Complete Now charges the missing pieces' cookies.
    const priced = Puzzle(
      id: 'p',
      name: '',
      description: '',
      storyId: 0,
      pieces: [
        PuzzlePiece('ending', endingCode: 1, cookies: 40),
        PuzzlePiece('ending', endingCode: 2, cookies: 60),
      ],
    );
    final b = Account(endings: {2}, cookies: 200);
    expect(b.completeNowPrice(priced), 40);
    expect(b.completeNow(priced), isTrue);
    expect(b.cookies, 160);
    expect(b.piecesOf(priced).every((h) => h), isTrue);
    // Event-limited puzzles are unlocked: nothing here can earn their
    // Cookie Parade or package pieces (TODO 102).
    for (final event in catalog.puzzles) {
      expect(b.piecesOf(event).every((h) => h), isTrue);
      expect(b.completeNowPrice(event), 0, reason: event.id);
    }
  });

  test('only a finished puzzle can become the background', () {
    final a = Account();
    // The built-in desk is no puzzle.
    expect(a.background, 'wallpaper0');
    expect(a.backgroundIn(catalog), isNull);
    final suin = retryPuzzle('wallpaper201');
    expect(a.useAsBackground(suin), isFalse);
    expect(a.background, 'wallpaper0');
    final event = catalog.puzzles.firstWhere((p) => p.id == 'wallpaper1011');
    expect(a.useAsBackground(event), isTrue);
    expect(
      a.backgroundIn(catalog)!.wallpaper,
      'kss/images/wallpaper_image/wallpaper1011.png',
    );
    // A pack's puzzle draws its own full-screen art.
    final academy = retryPuzzle('wallpaper200');
    expect(a.useAsBackground(academy), isTrue);
    expect(
      a.backgroundIn(catalog)!.wallpaper,
      endsWith('puzzles/wallpaper200.png'),
    );
    expect(File(academy.wallpaper).existsSync(), isTrue);
    expect(Account.fromJson(a.toJson()).background, 'wallpaper200');
    // An id no pack or catalog has falls back to the desk.
    a.background = 'wallpaper9999';
    expect(a.backgroundIn(catalog), isNull);
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
