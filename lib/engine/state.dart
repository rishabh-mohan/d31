/// Everything about a run in progress. Pure data plus small derived getters --
/// no Flutter, no IO -- so the loop can be exercised in tests and inspected
/// wholesale by the dev panel.
library;

import 'dart:convert';
import 'dart:math';

import 'game_date.dart';
import 'goals.dart';
import 'pack.dart';

class LogEntry {
  final GameDate at;
  final String text;
  final String kind; // action | event | effect | system
  LogEntry(this.at, this.text, this.kind);
}

class GameState {
  final ContentPack pack;
  final Random random;

  GameDate date;
  int locationId;
  bool isMale;
  String firstName;
  String lastName;
  String get fullName =>
      [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');

  final Map<String, num> stats;
  num hp;
  num money;

  num studyExp = 0;
  num exerciseExp = 0;
  num partTimeExp = 0;

  /// Event switches, seeded from the pack's declared defaults.
  final Map<String, int> switches;

  /// How many times each event has fired. `EVENT_<id>` conditions read this.
  final Map<int, int> eventCounts = {};

  final Set<int> unlockedLocations = {};
  final Map<int, int> inventory = {}; // itemId -> count
  final Map<int, int> itemUseCounts = {};
  final Set<int> traits = {};
  final Map<int, int> bookReadCounts = {};
  final Map<String, int> bookChoices = {};
  final Map<String, int> shopPurchases = {};
  final Map<int, int> stationeryInventory = {};
  final Map<String, int> equippedStationery = {};
  String? stationeryDrawDay;
  final List<int> pendingStationery = [];
  final Set<int> stationeryLocks = {};
  bool stationeryFreeRedrawUsed = false;

  List<Map<String, dynamic>> get activeStationerySets =>
      pack.stationerySets.where((set) {
        final ids = (set['equipmentItemIds'] as List? ?? const []).cast<int>();
        return ids.isNotEmpty && ids.every(equippedStationery.values.contains);
      }).toList();

  num stationeryBonus(String subject) {
    num total = 0;
    void addStats(dynamic rows) {
      for (final row in (rows as List? ?? const []).whereType<Map>()) {
        if (row['isAll'] == true || row['subjectType'] == subject) {
          total += (row['stat'] as num?) ?? 0;
        }
      }
    }

    for (final id in equippedStationery.values) {
      addStats(pack.stationery[id]?['studyStats']);
    }
    for (final set in activeStationerySets) {
      addStats(set['studyStats']);
    }
    return total;
  }

  /// Set by SET_RANDOM_SUBJECT / SET_DRAW_VALUE and read back by conditions.
  String? randomSubject;
  num drawValue = 0;

  /// Study combo: consecutive studies of the same subject.
  String? lastStudySubject;
  int studyCombo = 0;

  /// Action keys used today, for `blockDuplicated`.
  final Set<String> usedActionKeysToday = {};
  int eventsFiredToday = 0;

  /// Locations the run may not leave, set by LOCK_MOVE_LOCATION.
  bool movementLocked = false;
  bool exhaustionPending = false;

  /// The reroll counter beside the stamina bar.
  int rerolls = 0;

  /// The current weekly goal, renewed every Monday.
  WeeklyGoal? weeklyGoal;

  /// Study blocks clicked during the current goal week, counted whether or
  /// not the goal has already been met -- surplus effort still weights the
  /// next week'"'"'s goal rather than being wasted.
  int studyBlocksThisWeek = 0;

  /// Of those, the ones clicked after the goal was already met.
  int surplusStudyBlocks = 0;

  /// The soft currency in the top bar, separate from in-run money.
  int cookies = 0;

  final List<LogEntry> log = [];
  bool finished = false;
  String? endingLabel;
  int? endingCode;

  GameState({
    required this.pack,
    required this.date,
    required this.locationId,
    required this.stats,
    required this.hp,
    required this.money,
    required this.switches,
    this.isMale = true,
    String? firstName,
    String? lastName,
    Random? random,
  }) : firstName = firstName ?? pack.manifest.firstName,
       lastName = lastName ?? pack.manifest.lastName,
       random = random ?? Random();

  factory GameState.newRun(
    ContentPack pack, {
    Random? random,
    bool isMale = true,
  }) {
    final r = pack.rules;
    final initial =
        (r.section('stats')['initial'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final state = GameState(
      pack: pack,
      date: pack.manifest.startDate,
      locationId: pack.manifest.startLocationId,
      stats: {
        for (final s in pack.manifest.subjects) s: (initial[s] as num?) ?? 0,
      },
      hp: r.hpInitial,
      money: r.moneyInitial,
      switches: Map<String, int>.from(pack.switchDefaults),
      random: random,
      isMale: isMale,
    );
    for (final loc in pack.locations.values) {
      if (!loc.isDefaultLocked) state.unlockedLocations.add(loc.id);
    }
    state.rerolls = r.number('refresh', 'initial', 0).toInt();
    state.cookies = r.number('cookies', 'initial', 0).toInt();
    state.applyStartingTraitEffects();
    state.weeklyGoal = Goals.issue(state);
    state.note('Day 1. ${pack.manifest.name} begins.', 'system');
    return state;
  }

  // --- derived ------------------------------------------------------------

  int get ticksPerDay => pack.manifest.ticksPerDay;
  int get dayIndex => pack.manifest.startDate.daysUntil(date);
  int get dayNumber => dayIndex + 1;
  int get totalDays => pack.manifest.totalDays;
  int get daysRemaining => date.daysUntil(pack.manifest.endDate);
  bool get isLastDay => daysRemaining <= 0;
  GameLocation? get location => pack.locations[locationId];

  LevelTier get studyLevel => pack.studyLevels.tierFor(studyExp);
  LevelTier get exerciseLevel => pack.exerciseLevels.tierFor(exerciseExp);
  LevelTier get partTimeLevel => pack.partTimeLevels.tierFor(partTimeExp);

  num get totalStat => stats.values.fold<num>(0, (a, b) => a + b);

  num get hpMax {
    final base = pack.rules.hpMax;
    return base + exerciseLevel.level * pack.rules.exerciseHpPerLevel;
  }

  /// `section` on events maps the run onto six stretches. Events tagged
  /// "three" only fire in the third sixth of the calendar.
  static const sectionNames = ['one', 'two', 'three', 'four', 'five', 'six'];
  String get currentSection {
    final total = max(1, totalDays);
    final idx = ((dayIndex / total) * sectionNames.length).floor();
    return sectionNames[idx.clamp(0, sectionNames.length - 1)];
  }

  // --- mutation -----------------------------------------------------------

  void note(String text, [String kind = 'system']) {
    log.add(LogEntry(date, text, kind));
    if (log.length > 500) log.removeRange(0, log.length - 500);
  }

  void addStat(String subject, num amount) {
    if (subject == 'all') {
      for (final s in pack.manifest.subjects) {
        addStat(s, amount);
      }
      return;
    }
    if (subject == 'random') {
      addStat(randomOf(pack.manifest.subjects), amount);
      return;
    }
    if (subject == 'chosen') {
      addStat(randomSubject ?? randomOf(pack.manifest.subjects), amount);
      return;
    }
    if (subject == 'elective' ||
        subject == 'elective1' ||
        subject == 'elective2') {
      // Electives in KSS are the two inquiry subjects; in a five-subject pack
      // those are the last two listed.
      final subjects = pack.manifest.subjects;
      final idx = subject == 'elective2'
          ? subjects.length - 1
          : subjects.length - 2;
      if (idx >= 0) addStat(subjects[idx], amount);
      return;
    }
    if (subject == 'lesson') {
      for (final s in pack.manifest.subjects) {
        addStat(s, amount);
      }
      return;
    }
    if (!stats.containsKey(subject)) return;
    final maxStat = pack.rules.number('stats', 'max', 999999);
    stats[subject] = (stats[subject]! + amount).clamp(0, maxStat);
  }

  void addHp(num amount) {
    hp = (hp + amount).clamp(pack.rules.hpMin, hpMax);
  }

  void addMoney(num amount) {
    money = max(pack.rules.moneyMin, money + amount);
  }

  String randomOf(List<String> xs) => xs[random.nextInt(xs.length)];

  /// Switches the engine maintains rather than content: content reads the
  /// calendar through these names. Writing one is ignored.
  static const engineSwitches = {
    'DATE_PROGRESS',
    'TICK',
    'DATE_DAY',
    'DATE_MONTH',
    'DATE_WEEK',
    'DATE_INT',
    'WEEKCODE',
  };

  int switchValue(String name) {
    switch (name) {
      case 'DATE_PROGRESS':
      case 'TICK':
        return date.tick;
      case 'DATE_DAY':
        return date.day.day;
      case 'DATE_MONTH':
        return date.day.month;
      case 'DATE_WEEK':
      case 'WEEKCODE':
        // 1 = Monday .. 7 = Sunday, matching the run's Monday start.
        return date.day.weekday;
      case 'DATE_INT':
        return date.asInt;
    }
    return switches[name] ?? 0;
  }

  void setSwitch(String name, int value) {
    if (engineSwitches.contains(name)) return;
    switches[name] = value;
  }

  void addSwitch(String name, int delta) {
    if (engineSwitches.contains(name)) return;
    switches[name] = switchValue(name) + delta;
  }

  int itemCount(int id) => inventory[id] ?? 0;

  void addItem(int id, [int count = 1]) {
    final item = pack.items[id];
    final next = itemCount(id) + count;
    final cap = item?.maxCount;
    inventory[id] = cap == null ? next : min(next, cap);
  }

  bool removeItem(int id, [int count = 1]) {
    final have = itemCount(id);
    if (have < count) return false;
    if (have == count) {
      inventory.remove(id);
    } else {
      inventory[id] = have - count;
    }
    return true;
  }

  /// Whether trait effects are applied at all. Parked for now by request;
  /// the catalog still loads and traits can still be granted, they simply
  /// contribute nothing. Flip `rules.traits.enabled` to bring them back.
  bool get traitsEnabled => pack.rules.flag('traits', 'enabled', false);

  /// Traits are passive modifiers; `firstPlus*` ones only apply at run start.
  void applyStartingTraitEffects() {
    if (!traitsEnabled) return;
    for (final id in traits) {
      final trait = pack.traits[id];
      if (trait == null) continue;
      for (final e in trait.effects) {
        switch (e['type']) {
          case 'firstPlusStat':
            final subject = e['subjectType'] as String? ?? 'all';
            addStat(subject, (e['stat'] as num?) ?? 0);
          case 'firstPlusMoney':
            addMoney((e['money'] as num?) ?? 0);
          case 'firstExerciseLevel':
            exerciseExp = _expForLevel(pack.exerciseLevels, e['level']);
          case 'firstPlusPartTimeJobLevel':
            partTimeExp = _expForLevel(pack.partTimeLevels, e['level']);
        }
      }
    }
  }

  num _expForLevel(LevelTable table, dynamic level) {
    final want = (level as num?)?.toInt() ?? 0;
    for (final t in table.tiers) {
      if (t.level == want) return t.exp;
    }
    return 0;
  }

  /// Sum of a passive numeric modifier across held normal items and traits.
  /// `scopeOk` filters by the location scope attached to the effect.
  num passiveSum(String effectType, {String? subject, String? valueKey}) {
    num total = 0;
    final key = valueKey ?? 'value';
    for (final entry in inventory.entries) {
      final item = pack.items[entry.key];
      if (item == null || item.isConsumable) continue;
      for (final e in item.effects) {
        if (e['type'] != effectType) continue;
        if (!_scopeMatches(e['scope'])) continue;
        if (subject != null) {
          final s = e['subject'] as String?;
          if (s != null && s != 'all' && s != subject) continue;
        }
        final v = e[key];
        if (v is num) total += v;
      }
    }
    if (!traitsEnabled) return total;
    for (final id in traits) {
      for (final e
          in pack.traits[id]?.effects ?? const <Map<String, dynamic>>[]) {
        if (e['type'] != effectType) continue;
        final v = e[key] ?? e['extraStat'] ?? e['plusValue'];
        if (v is num) total += v;
      }
    }
    return total;
  }

  bool _scopeMatches(dynamic scope) {
    if (scope == null) return true;
    if (scope is! Map) return true;
    final wantId = scope['locationId'];
    if (wantId is num && wantId.toInt() != locationId) return false;
    final wantType = scope['locationType'];
    if (wantType is String && location?.type != wantType) return false;
    return true;
  }

  // --- serialisation (saves, and the dev panel's state dump) ---------------

  Map<String, dynamic> toJson() => {
    'packId': pack.manifest.id,
    'date': date.code,
    'locationId': locationId,
    'isMale': isMale,
    'stats': stats,
    'hp': hp,
    'money': money,
    'studyExp': studyExp,
    'exerciseExp': exerciseExp,
    'partTimeExp': partTimeExp,
    'switches': switches,
    'eventCounts': eventCounts.map((k, v) => MapEntry(k.toString(), v)),
    'unlockedLocations': unlockedLocations.toList(),
    'inventory': inventory.map((k, v) => MapEntry(k.toString(), v)),
    'itemUseCounts': itemUseCounts.map((k, v) => MapEntry(k.toString(), v)),
    'traits': traits.toList(),
    'bookReadCounts': bookReadCounts.map((k, v) => MapEntry(k.toString(), v)),
    'bookChoices': bookChoices,
    'shopPurchases': shopPurchases,
    'stationeryInventory': stationeryInventory.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'equippedStationery': equippedStationery,
    'firstName': firstName,
    'lastName': lastName,
    'stationeryDrawDay': stationeryDrawDay,
    'pendingStationery': pendingStationery,
    'stationeryLocks': stationeryLocks.toList(),
    'stationeryFreeRedrawUsed': stationeryFreeRedrawUsed,
    'randomSubject': randomSubject,
    'drawValue': drawValue,
    'lastStudySubject': lastStudySubject,
    'studyCombo': studyCombo,
    'eventsFiredToday': eventsFiredToday,
    'usedActionKeysToday': usedActionKeysToday.toList(),
    'movementLocked': movementLocked,
    'exhaustionPending': exhaustionPending,
    'rerolls': rerolls,
    'cookies': cookies,
    'weeklyGoal': weeklyGoal?.toJson(),
    'studyBlocksThisWeek': studyBlocksThisWeek,
    'surplusStudyBlocks': surplusStudyBlocks,
    'finished': finished,
    'endingLabel': endingLabel,
    'endingCode': endingCode,
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  static GameState fromJson(ContentPack pack, Map<String, dynamic> j) {
    final state = GameState(
      pack: pack,
      date: GameDate.tryParse(j['date'] as String?) ?? pack.manifest.startDate,
      locationId:
          (j['locationId'] as num?)?.toInt() ?? pack.manifest.startLocationId,
      stats: {
        for (final s in pack.manifest.subjects)
          s: ((j['stats'] as Map?)?[s] as num?) ?? 0,
      },
      hp: (j['hp'] as num?) ?? pack.rules.hpInitial,
      money: (j['money'] as num?) ?? pack.rules.moneyInitial,
      switches: {
        ...pack.switchDefaults,
        ...?(j['switches'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        ),
      },
      isMale: j['isMale'] as bool? ?? true,
      firstName: j['firstName'] as String?,
      lastName: j['lastName'] as String?,
    );
    state.studyExp = (j['studyExp'] as num?) ?? 0;
    state.exerciseExp = (j['exerciseExp'] as num?) ?? 0;
    state.partTimeExp = (j['partTimeExp'] as num?) ?? 0;
    void intMap(String key, Map<int, int> into) {
      ((j[key] as Map?) ?? const {}).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null) into[id] = (v as num?)?.toInt() ?? 0;
      });
    }

    intMap('eventCounts', state.eventCounts);
    intMap('inventory', state.inventory);
    intMap('itemUseCounts', state.itemUseCounts);
    intMap('bookReadCounts', state.bookReadCounts);
    intMap('stationeryInventory', state.stationeryInventory);
    state.stationeryDrawDay = j['stationeryDrawDay'] as String?;
    state.pendingStationery.addAll(
      (j['pendingStationery'] as List? ?? const []).cast<int>(),
    );
    state.stationeryLocks.addAll(
      (j['stationeryLocks'] as List? ?? const []).cast<int>(),
    );
    state.stationeryFreeRedrawUsed = j['stationeryFreeRedrawUsed'] == true;
    for (final entry in {
      'bookChoices': state.bookChoices,
      'shopPurchases': state.shopPurchases,
      'equippedStationery': state.equippedStationery,
    }.entries) {
      (j[entry.key] as Map? ?? const {}).forEach(
        (k, v) => entry.value[k.toString()] = (v as num).toInt(),
      );
    }
    state.unlockedLocations.addAll(
      ((j['unlockedLocations'] as List?) ?? const []).whereType<num>().map(
        (n) => n.toInt(),
      ),
    );
    state.traits.addAll(
      ((j['traits'] as List?) ?? const []).whereType<num>().map(
        (n) => n.toInt(),
      ),
    );
    state.randomSubject = j['randomSubject'] as String?;
    state.drawValue = (j['drawValue'] as num?) ?? 0;
    state.lastStudySubject = j['lastStudySubject'] as String?;
    state.studyCombo = (j['studyCombo'] as num?)?.toInt() ?? 0;
    state.eventsFiredToday = (j['eventsFiredToday'] as num?)?.toInt() ?? 0;
    state.usedActionKeysToday.addAll(
      ((j['usedActionKeysToday'] as List?) ?? const []).whereType<String>(),
    );
    state.movementLocked = j['movementLocked'] as bool? ?? false;
    state.exhaustionPending = j['exhaustionPending'] as bool? ?? false;
    state.rerolls = (j['rerolls'] as num?)?.toInt() ?? 0;
    state.cookies = (j['cookies'] as num?)?.toInt() ?? 0;
    state.weeklyGoal = WeeklyGoal.fromJson(
      (j['weeklyGoal'] as Map?)?.cast<String, dynamic>(),
    );
    state.studyBlocksThisWeek =
        (j['studyBlocksThisWeek'] as num?)?.toInt() ?? 0;
    state.surplusStudyBlocks = (j['surplusStudyBlocks'] as num?)?.toInt() ?? 0;
    state.finished = j['finished'] as bool? ?? false;
    state.endingLabel = j['endingLabel'] as String?;
    state.endingCode = (j['endingCode'] as num?)?.toInt();
    return state;
  }
}
