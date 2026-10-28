/// What belongs to the player rather than to one run: Home's wallet, the
/// trait collection, puzzles, the daily quest and settings.
///
/// Home's balance pill shows cookies and refresh tokens (MM-01, 53 / 522 in
/// the capture). Cookies come from what the original rewards with them:
/// reaching an ending for the first time (its Endings List amount) and the
/// daily quest. Refresh tokens have no
/// recovered source yet.
///
/// A run spends from this wallet for every currency its rules mark
/// `shared` (GameState.attachWallet, TODO 84 M04): cookies by default.
/// The first shared run grants the old per-run `initial` once.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'account_catalog.dart';
import 'pack.dart';
import 'record_store.dart';
import 'state.dart' show SharedWallet;

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

/// The daily quest's reward (MM-08 shows 4).
const dailyQuestCookies = 4;

/// Trait packs a completed run pays out, once per run (RECONSTRUCTED).
/// The recording shows "Ending Reward Obtained! 2 Standard Trait Pack(s)"
/// with "X2 Reward Pack active"; the base of one is inferred from the
/// doubling, and this build has no purchase that could double it.
const endingRewardPackId = 'standard';
const endingRewardPacks = 1;

/// An ending reward waiting for the "Ending Reward Obtained!" dialog. The
/// packs are already in the inventory; [AccountStore] persists this until
/// the player confirms ([Account.acknowledgeEndingReward]).
class EndingReward {
  final String packId;
  final int count;
  const EndingReward(this.packId, this.count);

  Map<String, dynamic> toJson() => {'packId': packId, 'count': count};

  static EndingReward? fromJson(Object? j) => j is Map
      ? EndingReward(
          j['packId'] as String? ?? endingRewardPackId,
          (j['count'] as num?)?.toInt() ?? 0,
        )
      : null;
}

/// Mileage that guarantees an S-tier card (MM-14: 490/1000).
const mileageMax = 1000;

/// Change Username's price and length limits (F07: "2-16 characters",
/// Change with a cookie and 9).
const renameCookies = 9;
const usernameMinLength = 2;
const usernameMaxLength = 16;

/// Settings' Type of Music (F01/F02). Orchestral and Carol come with paid
/// entitlements in the original, which this build does not sell.
enum MusicType {
  regular('Regular'),
  orchestral('Orchestral'),
  carol('Carol');

  final String label;
  const MusicType(this.label);
}

class Account implements SharedWallet {
  @override
  int cookies;
  @override
  int refreshTokens;
  UniversitySet universities;

  /// Currencies whose one-time starting grant a run has already paid
  /// (GameState.attachWallet).
  @override
  final Set<String> walletGrants;

  /// The name under Home's scene and on the profile (F05/F07).
  String username;

  /// First rename is free; later changes cost nine cookies.
  int renameCount;
  int get renameCost => renameCount == 0 ? 0 : renameCookies;

  /// Settings toggles (F01). Stored for when audio and haptics exist;
  /// Rumble drives lib/ui/haptics.dart (F03); audio is not built yet (F02).
  bool bgm;
  bool sfx;
  bool rumble;
  MusicType music;

  /// Ending codes ever reached. Their cookies were paid when first reached.
  final Set<int> endings;

  /// Enrollments per university id, this account's own count.
  final Map<int, int> enrollments;

  /// Enrollments per department id: the "# Enrollments" of a major.
  final Map<int, int> departmentEnrollments;

  /// Runs whose ending reward was paid (record id + finish time), so
  /// replaying the completion can never pay twice.
  final Set<String> endingRewardsPaid;

  /// The reward awaiting its dialog, if any.
  EndingReward? pendingEndingReward;

  /// Finished runs per pack id.
  final Map<String, int> clears;

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
    Map<int, int>? departmentEnrollments,
    Set<String>? endingRewardsPaid,
    this.pendingEndingReward,
    Map<String, int>? clears,
    Map<String, int>? packs,
    this.mileage = 0,
    List<OwnedTrait>? traits,
    this.nextTraitUid = 1,
    Set<String>? boughtPuzzles,
    this.background = 'wallpaper0',
    this.quest,
    Set<String>? walletGrants,
    this.username = defaultUsername,
    this.renameCount = 0,
    this.bgm = true,
    this.sfx = true,
    this.rumble = true,
    this.music = MusicType.regular,
  }) : walletGrants = walletGrants ?? {},
       endings = endings ?? {},
       enrollments = enrollments ?? {},
       departmentEnrollments = departmentEnrollments ?? {},
       endingRewardsPaid = endingRewardsPaid ?? {},
       clears = clears ?? {},
       packs = packs ?? {},
       traits = traits ?? [],
       boughtPuzzles = boughtPuzzles ?? {};

  Map<String, dynamic> toJson() => {
    'cookies': cookies,
    'refreshTokens': refreshTokens,
    'universities': universities.name,
    'endings': endings.toList(),
    'enrollments': {for (final e in enrollments.entries) '${e.key}': e.value},
    'departmentEnrollments': {
      for (final e in departmentEnrollments.entries) '${e.key}': e.value,
    },
    'endingRewardsPaid': endingRewardsPaid.toList(),
    'pendingEndingReward': ?pendingEndingReward?.toJson(),
    'clears': clears,
    'packs': packs,
    'mileage': mileage,
    'traits': [for (final t in traits) t.toJson()],
    'nextTraitUid': nextTraitUid,
    'boughtPuzzles': boughtPuzzles.toList(),
    'background': background,
    'quest': ?quest?.toJson(),
    'walletGrants': walletGrants.toList(),
    'username': username,
    'renameCount': renameCount,
    'bgm': bgm,
    'sfx': sfx,
    'rumble': rumble,
    'music': music.name,
  };

  static const defaultUsername = 'Student';

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
    departmentEnrollments: {
      for (final e
          in ((j['departmentEnrollments'] as Map?) ?? const {}).entries)
        int.parse('${e.key}'): (e.value as num).toInt(),
    },
    endingRewardsPaid: {
      for (final v in j['endingRewardsPaid'] as List? ?? const []) '$v',
    },
    pendingEndingReward: EndingReward.fromJson(j['pendingEndingReward']),
    clears: {
      for (final e in ((j['clears'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
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
    walletGrants: {
      for (final v in j['walletGrants'] as List? ?? const []) '$v',
    },
    username: switch (j['username']) {
      final String name when validUsername(name) => name,
      _ => defaultUsername,
    },
    renameCount: (j['renameCount'] as num?)?.toInt() ?? 0,
    bgm: j['bgm'] as bool? ?? true,
    sfx: j['sfx'] as bool? ?? true,
    rumble: j['rumble'] as bool? ?? true,
    music: MusicType.values.firstWhere(
      (m) => m.name == j['music'],
      orElse: () => MusicType.regular,
    ),
  );

  // ---- Profile --------------------------------------------------------

  static bool validUsername(String name) {
    final n = name.trim().runes.length;
    return n >= usernameMinLength && n <= usernameMaxLength;
  }

  /// Why [name] cannot be taken, or null when Change may go ahead.
  String? renameProblem(String name) {
    if (!validUsername(name)) {
      return 'Use $usernameMinLength-$usernameMaxLength characters.';
    }
    if (name.trim() == username) return 'That is already your username.';
    if (cookies < renameCost) return 'Not enough cookies.';
    return null;
  }

  /// First valid rename is free; later changes cost [renameCookies].
  bool rename(String name) {
    if (renameProblem(name) != null) return false;
    cookies -= renameCost;
    renameCount++;
    username = name.trim();
    return true;
  }

  // ---- Runs -------------------------------------------------------------

  /// A finished run's account effects: its ending, enrollment and clears.
  /// Returns the cookies paid out.
  int recordRun(RunRecord record, AccountCatalog catalog) {
    var paid = 0;
    final code = record.endingCode;
    if (code != null && endings.add(code)) {
      paid += catalog.endings[code]?.cookies ?? 0;
    }
    if (record.enrolledUniversityId case final uni?) {
      if ((enrollments[uni] ?? 0) == 0) {
        paid += catalog.firstUniversityEnrollmentCookies;
      }
      enrollments[uni] = (enrollments[uni] ?? 0) + 1;
      if (record.enrolledDepartmentId case final dep?) {
        departmentEnrollments[dep] = (departmentEnrollments[dep] ?? 0) + 1;
      }
    }
    // One ending trait pack per completed run, once.
    final rewardKey = '${record.id}@${record.finishedAt.toIso8601String()}';
    if (endingRewardsPaid.add(rewardKey)) {
      packs[endingRewardPackId] =
          (packs[endingRewardPackId] ?? 0) + endingRewardPacks;
      pendingEndingReward = EndingReward(
        endingRewardPackId,
        (pendingEndingReward?.count ?? 0) + endingRewardPacks,
      );
    }
    clears[record.packId] = (clears[record.packId] ?? 0) + 1;
    cookies += paid;
    return paid;
  }

  /// The player confirmed the "Ending Reward Obtained!" dialog.
  void acknowledgeEndingReward() => pendingEndingReward = null;

  /// How many of this account's finished runs enrolled at [universityId]:
  /// the school browser's "enrollees : n". LOCAL; never a global count.
  int universityEnrollees(int universityId) => enrollments[universityId] ?? 0;

  /// The same for one major: "# Enrollments".
  int majorEnrollments(int departmentId) =>
      departmentEnrollments[departmentId] ?? 0;

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
    return drawn;
  }

  // ---- Combining ------------------------------------------------------

  /// Published rank percentages in the user-supplied Traits Combination
  /// Probability Information PDF (2026-10-25). Input order is irrelevant.
  static const combineRates = <String, Map<String, int>>{
    'AAA': {'S': 6, 'A': 94},
    'AAB': {'S': 4, 'A': 81, 'B': 15},
    'ABB': {'S': 2, 'A': 68, 'B': 30},
    'BBB': {'A': 55, 'B': 45},
    'BBC': {'A': 37, 'B': 53, 'C': 10},
    'BCC': {'A': 19, 'B': 61, 'C': 20},
    'CCC': {'A': 1, 'B': 69, 'C': 30},
  };

  /// User clarification for mixes omitted by the published PDF.
  static const combineRateAliases = {'AAC': 'ABB', 'ABC': 'BBB', 'ACC': 'BBC'};

  static Map<String, int>? combineRatesFor(Iterable<String> ranks) {
    final sorted = ranks.toList()..sort();
    if (sorted.length != 3) return null;
    final key = sorted.join();
    // Preserve the existing S-only result; the PDF covers A/B/C inputs.
    return key == 'SSS'
        ? const {'S': 100}
        : combineRates[combineRateAliases[key] ?? key];
  }

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
    if (combineRatesFor(
          picked.map((t) => pack.traits[t.traitId]?.rank ?? ''),
        ) ==
        null) {
      return 'No combination rates are available for these ranks.';
    }
    return null;
  }

  /// Consumes three copies and draws the result rank from the published
  /// combination table, then draws a card from that campaign's rank pool.
  GameTrait? combine(
    List<OwnedTrait> picked,
    ContentPack pack,
    String campaign, [
    Random? random,
  ]) {
    if (combineProblem(picked, pack) != null) return null;
    final rng = random ?? Random();
    final rates = combineRatesFor(
      picked.map((t) => pack.traits[t.traitId]!.rank),
    )!;
    var roll = rng.nextDouble() * 100;
    var rank = rates.keys.last;
    for (final entry in rates.entries) {
      roll -= entry.value;
      if (roll < 0) {
        rank = entry.key;
        break;
      }
    }
    final pool = [
      for (final t in poolFor(pack, campaign))
        if (t.rank == rank) t,
    ];
    if (pool.isEmpty) return null;
    final result = pool[rng.nextInt(pool.length)];
    final uids = picked.map((t) => t.uid).toSet();
    traits.removeWhere((t) => uids.contains(t.uid));
    traits.add(OwnedTrait(nextTraitUid++, result.id));
    return result;
  }

  // ---- Puzzles --------------------------------------------------------

  /// Which pieces are held. `gameCount` pieces need that many finished runs
  /// of the campaign (the first one run, the second two...): provisional,
  /// the original's counts were not recovered. Invites cannot be earned
  /// here. Event-package pieces (Cookie Parade levels, the Full Focus
  /// Package) count as held: there are no events or purchases to earn them
  /// from, and the user asked for the event-limited puzzles unlocked
  /// (TODO 102).
  List<bool> piecesOf(Puzzle puzzle) {
    if (boughtPuzzles.contains(puzzle.id)) {
      return List.filled(puzzle.pieces.length, true);
    }
    final runs = clears[puzzle.packId] ?? 0;
    var games = 0;
    return [
      for (final p in puzzle.pieces)
        switch (p.type) {
          'fixed' => true,
          'ending' => endings.contains(p.endingCode),
          'purchaseStory' => puzzle.packId != null,
          'gameCount' => runs >= ++games,
          'eventPackage' => true,
          _ => false,
        },
    ];
  }

  /// Share of the puzzle held, weighted by piece cookies where it has them
  /// (MM-13 is 2/4 yet 52%).
  double puzzleProgress(Puzzle puzzle) {
    final held = piecesOf(puzzle);
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
  int? completeNowPrice(Puzzle puzzle) {
    final held = piecesOf(puzzle);
    var price = 0;
    for (var i = 0; i < held.length; i++) {
      if (held[i]) continue;
      if (puzzle.pieces[i].cookies <= 0) return null;
      price += puzzle.pieces[i].cookies;
    }
    return price;
  }

  bool completeNow(Puzzle puzzle) {
    final price = completeNowPrice(puzzle);
    if (price == null || price == 0 || cookies < price) return false;
    cookies -= price;
    boughtPuzzles.add(puzzle.id);
    return true;
  }

  /// Makes a finished puzzle the Home background (MM-11's green check).
  /// An unfinished one is refused.
  bool useAsBackground(Puzzle puzzle) {
    if (!piecesOf(puzzle).every((h) => h)) return false;
    background = puzzle.id;
    return true;
  }

  /// The selected background, or null when its id is not in [catalog].
  Puzzle? backgroundIn(AccountCatalog catalog) {
    for (final p in catalog.allPuzzles) {
      if (p.id == background) return p;
    }
    return null;
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
