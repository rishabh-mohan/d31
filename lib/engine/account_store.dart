/// What belongs to the player rather than to one run: Home's wallet, the
/// trait collection, puzzles, achievements, the daily quest and settings.
///
/// Home's balance pill shows cookies and refresh tokens (MM-01, 53 / 522 in
/// the capture). Cookies come from what the original rewards with them:
/// reaching an ending for the first time (its Endings List amount), the
/// achievements that list one, and the daily quest. Refresh tokens have no
/// recovered source yet and stay at zero.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'account_catalog.dart';
import 'pack.dart';
import 'record_store.dart';

/// Which admissions catalog a run applies to (TODO 41).
enum UniversitySet {
  korean('Korean universities'),
  us('US universities');

  final String label;
  const UniversitySet(this.label);
}

/// One owned copy of a trait. Copies are separate (MM-19 shows two Master
/// of 108 Bows), and combine-locking belongs to the copy (MM-27).
class OwnedTrait {
  final int uid;
  final int traitId;
  bool locked;

  OwnedTrait(this.uid, this.traitId, {this.locked = false});

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'traitId': traitId,
    if (locked) 'locked': true,
  };

  static OwnedTrait fromJson(Map j) => OwnedTrait(
    (j['uid'] as num).toInt(),
    (j['traitId'] as num).toInt(),
    locked: j['locked'] == true,
  );
}

class DailyQuest {
  /// Local date it was issued for, yyyy-mm-dd.
  final String date;
  final int universityId;
  final int departmentId;
  bool claimed;

  DailyQuest(
    this.date,
    this.universityId,
    this.departmentId, {
    this.claimed = false,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'universityId': universityId,
    'departmentId': departmentId,
    'claimed': claimed,
  };

  static DailyQuest fromJson(Map j) => DailyQuest(
    j['date'] as String,
    (j['universityId'] as num).toInt(),
    (j['departmentId'] as num).toInt(),
    claimed: j['claimed'] == true,
  );
}

/// An "Other" achievement (MM-07).
class AchievementInfo {
  final String id;
  final String title;
  final String condition;
  final int target;

  /// Cookies on completion. Only Story Addict's 5 is captured; the others
  /// were already complete in the capture, so theirs are unknown and none is
  /// granted.
  final int cookies;

  const AchievementInfo(
    this.id,
    this.title,
    this.condition,
    this.target, {
    this.cookies = 0,
  });

  static const all = [
    AchievementInfo(
      'story_addict',
      'Story Addict',
      'Reach Campaign Ending',
      5,
      cookies: 5,
    ),
    AchievementInfo('enjoyer', 'Enjoyer', 'Clear 31-Day Mode', 5),
    AchievementInfo('gym_rat', 'Gym Rat', 'Reach Exercise Level 10', 1),
    AchievementInfo(
      'work_addict',
      'Work Addict',
      'Reach Part-Time Stage 10',
      1,
    ),
    AchievementInfo(
      'renaissance',
      'Renaissance Man',
      'Obtain 20 or more Traits',
      1,
    ),
  ];
}

/// The daily quest's reward (MM-08 shows 4).
const dailyQuestCookies = 4;

/// Mileage that guarantees an S-tier card (MM-14: 490/1000).
const mileageMax = 1000;

class Account {
  int cookies;
  int refreshTokens;
  UniversitySet universities;

  /// Ending codes ever reached. Their cookies were paid when first reached.
  final Set<int> endings;

  /// Enrolments per university id, this account's own count.
  final Map<int, int> enrollments;

  /// Finished runs per pack id.
  final Map<String, int> clears;
  int bestExerciseLevel;
  int bestPartTimeLevel;

  /// Achievements already paid out.
  final Set<String> achievementsPaid;

  final Map<String, int> packs;
  int mileage;
  final List<OwnedTrait> traits;
  int nextTraitUid;

  /// Puzzles finished with Complete Now (MM-12/13).
  final Set<String> boughtPuzzles;

  /// The Home background: a puzzle id.
  String background;
  DailyQuest? quest;

  Account({
    this.cookies = 0,
    this.refreshTokens = 0,
    this.universities = UniversitySet.korean,
    Set<int>? endings,
    Map<int, int>? enrollments,
    Map<String, int>? clears,
    this.bestExerciseLevel = 0,
    this.bestPartTimeLevel = 0,
    Set<String>? achievementsPaid,
    Map<String, int>? packs,
    this.mileage = 0,
    List<OwnedTrait>? traits,
    this.nextTraitUid = 1,
    Set<String>? boughtPuzzles,
    this.background = 'wallpaper0',
    this.quest,
  }) : endings = endings ?? {},
       enrollments = enrollments ?? {},
       clears = clears ?? {},
       achievementsPaid = achievementsPaid ?? {},
       packs = packs ?? {},
       traits = traits ?? [],
       boughtPuzzles = boughtPuzzles ?? {};

  Map<String, dynamic> toJson() => {
    'cookies': cookies,
    'refreshTokens': refreshTokens,
    'universities': universities.name,
    'endings': endings.toList(),
    'enrollments': {for (final e in enrollments.entries) '${e.key}': e.value},
    'clears': clears,
    'bestExerciseLevel': bestExerciseLevel,
    'bestPartTimeLevel': bestPartTimeLevel,
    'achievementsPaid': achievementsPaid.toList(),
    'packs': packs,
    'mileage': mileage,
    'traits': [for (final t in traits) t.toJson()],
    'nextTraitUid': nextTraitUid,
    'boughtPuzzles': boughtPuzzles.toList(),
    'background': background,
    'quest': ?quest?.toJson(),
  };

  static Account fromJson(Map<String, dynamic> j) => Account(
    cookies: (j['cookies'] as num?)?.toInt() ?? 0,
    refreshTokens: (j['refreshTokens'] as num?)?.toInt() ?? 0,
    universities: UniversitySet.values.firstWhere(
      (u) => u.name == j['universities'],
      orElse: () => UniversitySet.korean,
    ),
    endings: {
      for (final v in j['endings'] as List? ?? const [])
        if (v is num) v.toInt(),
    },
    enrollments: {
      for (final e in ((j['enrollments'] as Map?) ?? const {}).entries)
        int.parse('${e.key}'): (e.value as num).toInt(),
    },
    clears: {
      for (final e in ((j['clears'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
    bestExerciseLevel: (j['bestExerciseLevel'] as num?)?.toInt() ?? 0,
    bestPartTimeLevel: (j['bestPartTimeLevel'] as num?)?.toInt() ?? 0,
    achievementsPaid: {
      for (final v in j['achievementsPaid'] as List? ?? const []) '$v',
    },
    packs: {
      for (final e in ((j['packs'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
    mileage: (j['mileage'] as num?)?.toInt() ?? 0,
    traits: [
      for (final t in j['traits'] as List? ?? const [])
        if (t is Map) OwnedTrait.fromJson(t),
    ],
    nextTraitUid: (j['nextTraitUid'] as num?)?.toInt() ?? 1,
    boughtPuzzles: {
      for (final v in j['boughtPuzzles'] as List? ?? const []) '$v',
    },
    background: j['background'] as String? ?? 'wallpaper0',
    quest: j['quest'] is Map ? DailyQuest.fromJson(j['quest'] as Map) : null,
  );

  // ---- Runs -------------------------------------------------------------

  /// A finished run's account effects: its ending, enrolment, clears and
  /// best levels, then any achievement it completed. Returns the cookies
  /// paid out.
  int recordRun(RunRecord record, AccountCatalog catalog) {
    var paid = 0;
    final code = record.endingCode;
    if (code != null && endings.add(code)) {
      paid += catalog.endings[code]?.cookies ?? 0;
    }
    if (record.enrolledUniversityId case final uni?) {
      enrollments[uni] = (enrollments[uni] ?? 0) + 1;
    }
    clears[record.packId] = (clears[record.packId] ?? 0) + 1;
    bestExerciseLevel = max(bestExerciseLevel, record.exerciseLevel);
    bestPartTimeLevel = max(bestPartTimeLevel, record.partTimeLevel);
    cookies += paid;
    return paid + payAchievements();
  }

  int achievementProgress(AchievementInfo a) => switch (a.id) {
    'story_addict' => endings.length,
    'enjoyer' => clears['kss16'] ?? 0,
    'gym_rat' => bestExerciseLevel >= 10 ? 1 : 0,
    'work_addict' => bestPartTimeLevel >= 10 ? 1 : 0,
    'renaissance' => traits.length >= 20 ? 1 : 0,
    _ => 0,
  };

  bool achievementDone(AchievementInfo a) => achievementProgress(a) >= a.target;

  /// Pays every newly completed achievement once.
  int payAchievements() {
    var paid = 0;
    for (final a in AchievementInfo.all) {
      if (achievementDone(a) && achievementsPaid.add(a.id)) {
        paid += a.cookies;
      }
    }
    cookies += paid;
    return paid;
  }

  // ---- Trait packs ----------------------------------------------------

  /// Buys one pack. False when the cookies are short.
  bool buyPack(TraitPackKind kind) {
    if (cookies < kind.price) return false;
    cookies -= kind.price;
    packs[kind.id] = (packs[kind.id] ?? 0) + 1;
    return true;
  }

  /// The traits a campaign's packs and combines draw from: every gachable
  /// ranked trait without a story, plus that campaign's own.
  static List<GameTrait> poolFor(ContentPack pack, String campaign) {
    final story = TraitPackKind.storyOf(campaign);
    return [
      for (final t in pack.traits.values)
        if (t.setupEligible &&
            const {'S', 'A', 'B', 'C'}.contains(t.rank) &&
            (t.storyId == null || t.storyId == story))
          t,
    ];
  }

  /// Opens one owned pack and adds its cards. Mileage: a full bar
  /// guarantees one S card and empties; otherwise any S empties it, and a
  /// pack without one adds its mileage (MM-14's guarantee text).
  List<GameTrait>? openPack(
    TraitPackKind kind,
    ContentPack pack, [
    Random? random,
  ]) {
    if ((packs[kind.id] ?? 0) <= 0) return null;
    final rng = random ?? Random();
    final pool = poolFor(pack, kind.campaign);
    final story = TraitPackKind.storyOf(kind.campaign);
    List<GameTrait> ofRank(String rank) => [
      for (final t in pool)
        if (t.rank == rank &&
            !(rank == 'S' && kind.storySOnly && t.storyId != story))
          t,
    ];
    final guaranteed = mileage >= mileageMax;
    final drawn = <GameTrait>[];
    for (var i = 0; i < kind.cards; i++) {
      var rank = 'S';
      if (!(guaranteed && i == 0)) {
        var roll = rng.nextDouble() * 100;
        for (final e in kind.odds.entries) {
          rank = e.key;
          roll -= e.value;
          if (roll < 0) break;
        }
      }
      final choices = ofRank(rank).isEmpty ? pool : ofRank(rank);
      if (choices.isEmpty) continue;
      drawn.add(choices[rng.nextInt(choices.length)]);
    }
    packs[kind.id] = packs[kind.id]! - 1;
    if (guaranteed || drawn.any((t) => t.rank == 'S')) {
      mileage = 0;
    } else {
      mileage = min(mileageMax, mileage + kind.mileage);
    }
    for (final t in drawn) {
      traits.add(OwnedTrait(nextTraitUid++, t.id));
    }
    payAchievements();
    return drawn;
  }

  // ---- Combining ------------------------------------------------------

  static const _rankOrder = ['C', 'B', 'A', 'S'];

  /// Why three copies cannot combine, or null when they can. Recovered
  /// rules: exactly three, none combine-locked, and "S-Ranks can only be
  /// combined with other S-Ranks."
  String? combineProblem(List<OwnedTrait> picked, ContentPack pack) {
    if (picked.length != 3) return 'Select three traits.';
    if (picked.any((t) => t.locked)) {
      return 'Combine-locked cards cannot be selected.';
    }
    final ranks = picked.map((t) => pack.traits[t.traitId]?.rank).toSet();
    if (ranks.contains('S') && ranks.length > 1) {
      return 'S-Ranks can only be combined with other S-Ranks.';
    }
    return null;
  }

  /// Chance the result steps up one rank. The original's rates were a web
  /// page ("Combine Rates") that was not recovered; this is provisional.
  static const combineUpgradeChance = .25;

  /// Consumes three copies and adds one trait: the highest input rank, or
  /// one above it at [combineUpgradeChance]. Provisional rule.
  GameTrait? combine(
    List<OwnedTrait> picked,
    ContentPack pack,
    String campaign, [
    Random? random,
  ]) {
    if (combineProblem(picked, pack) != null) return null;
    final rng = random ?? Random();
    var top = 0;
    for (final t in picked) {
      top = max(top, _rankOrder.indexOf(pack.traits[t.traitId]?.rank ?? 'C'));
    }
    if (top < 3 && rng.nextDouble() < combineUpgradeChance) top++;
    final pool = [
      for (final t in poolFor(pack, campaign))
        if (t.rank == _rankOrder[top]) t,
    ];
    if (pool.isEmpty) return null;
    final result = pool[rng.nextInt(pool.length)];
    final uids = picked.map((t) => t.uid).toSet();
    traits.removeWhere((t) => uids.contains(t.uid));
    traits.add(OwnedTrait(nextTraitUid++, result.id));
    payAchievements();
    return result;
  }

  // ---- Puzzles --------------------------------------------------------

  /// Which pieces are held. `gameCount` pieces need that many finished runs
  /// of the campaign (the first one run, the second two...): provisional,
  /// the original's counts were not recovered. Invites and event packages
  /// cannot be earned here.
  List<bool> piecesOf(Puzzle puzzle, Set<int> installedStories) {
    if (boughtPuzzles.contains(puzzle.id)) {
      return List.filled(puzzle.pieces.length, true);
    }
    final runs = clearsOfStory(puzzle.storyId);
    var games = 0;
    return [
      for (final p in puzzle.pieces)
        switch (p.type) {
          'fixed' => true,
          'ending' => endings.contains(p.endingCode),
          'purchaseStory' => installedStories.contains(puzzle.storyId),
          'gameCount' => runs >= ++games,
          _ => false,
        },
    ];
  }

  /// Finished runs of a story, read from the pack ids that carry it.
  int clearsOfStory(int storyId) => clears['kss$storyId'] ?? 0;

  /// Share of the puzzle held, weighted by piece cookies where it has them
  /// (MM-13 is 2/4 yet 52%).
  double puzzleProgress(Puzzle puzzle, Set<int> installedStories) {
    final held = piecesOf(puzzle, installedStories);
    final total = puzzle.totalCookies;
    if (total == 0) {
      return held.where((h) => h).length / max(1, held.length);
    }
    var have = 0;
    for (var i = 0; i < held.length; i++) {
      if (held[i]) have += puzzle.pieces[i].cookies;
    }
    return have / total;
  }

  /// Complete Now's price: the missing pieces' cookies. Null when a missing
  /// piece has no price (event-only pieces cannot be bought).
  int? completeNowPrice(Puzzle puzzle, Set<int> installedStories) {
    final held = piecesOf(puzzle, installedStories);
    var price = 0;
    for (var i = 0; i < held.length; i++) {
      if (held[i]) continue;
      if (puzzle.pieces[i].cookies <= 0) return null;
      price += puzzle.pieces[i].cookies;
    }
    return price;
  }

  bool completeNow(Puzzle puzzle, Set<int> installedStories) {
    final price = completeNowPrice(puzzle, installedStories);
    if (price == null || price == 0 || cookies < price) return false;
    cookies -= price;
    boughtPuzzles.add(puzzle.id);
    return true;
  }

  // ---- Daily quest ----------------------------------------------------

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Today's quest, issued on first look: one department of a regular
  /// university, picked from the date so it is stable through the day.
  DailyQuest? questFor(DateTime now, AdmissionsCatalog catalog) {
    final key = dayKey(now);
    if (quest?.date == key) return quest;
    final departments = [
      for (final d in catalog.departments.values)
        if (catalog.universities[d.universityId] case final u?)
          if (!u.storyOnly && d.requiredItems.isEmpty) d,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (departments.isEmpty) return null;
    final pick = departments[Random(key.hashCode).nextInt(departments.length)];
    return quest = DailyQuest(key, pick.universityId, pick.id);
  }

  /// Whether a run finished today enrolled in the quest's department.
  static bool questComplete(DailyQuest quest, List<RunRecord> records) =>
      records.any(
        (r) =>
            r.enrolledDepartmentId == quest.departmentId &&
            dayKey(r.finishedAt.toLocal()) == quest.date,
      );

  bool claimQuest(List<RunRecord> records) {
    final q = quest;
    if (q == null || q.claimed || !questComplete(q, records)) return false;
    q.claimed = true;
    cookies += dailyQuestCookies;
    return true;
  }
}

class AccountStore {
  AccountStore._();

  /// The loaded account. Defaults until [load] has run, and stays at the
  /// defaults on a host with no documents directory.
  static Account current = Account();

  /// The account pages' catalog, loaded with the account.
  static AccountCatalog catalog = AccountCatalog.empty;

  @visibleForTesting
  static File? fileOverride;

  static Future<File?> _file() async {
    final override = fileOverride;
    if (override != null) return override;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return File('${docs.path}/account.json');
    } catch (_) {
      return null;
    }
  }

  static Future<Account> load() async {
    final file = await _file();
    try {
      if (file != null && await file.exists()) {
        current = Account.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // An unreadable account file keeps the defaults.
    }
    return current;
  }

  static Future<bool> save() async {
    final file = await _file();
    if (file == null) return false;
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(current.toJson()));
      await temp.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
