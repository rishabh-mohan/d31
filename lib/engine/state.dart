/// Everything about a run in progress. Pure data plus small derived getters --
/// no Flutter, no IO -- so the loop can be exercised in tests and inspected
/// wholesale by the dev panel.
library;

import 'dart:convert';
import 'dart:math';

import 'admissions.dart';
import 'game_date.dart';
import 'goals.dart';
import 'quiz.dart';
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
  String difficulty = 'standard';
  int? characterId;
  final List<int> badgeIds = [];
  final List<int> initialTraitIds = [];

  String get portrait =>
      pack.characters[characterId]?.portrait ?? 'character/portrait.png';

  Iterable<GameTrait> get setupModifiers sync* {
    final character = pack.characters[characterId];
    if (character != null) {
      yield GameTrait.fromJson({
        'id': -character.id,
        'effectList': character.effects,
      });
    }
    for (final id in badgeIds) {
      final badge = pack.badges[id];
      if (badge != null) {
        yield GameTrait.fromJson({
          'id': -100000 - id,
          'effectList': badge.effects,
        });
      }
    }
  }

  String firstName;
  String lastName;
  String get fullName =>
      [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');

  final Map<String, num> stats;
  num _hp;
  num get hp => _hp;
  set hp(num value) => _hp = value.clamp(pack.rules.hpMin, hpMax);
  num money;

  num studyExp = 0;
  num exerciseExp = 0;
  num partTimeExp = 0;

  /// Event switches, seeded from the pack's declared defaults.
  final Map<String, int> switches;

  /// How many times each event has fired. Drives the dev panel and the
  /// run summary; conditions read [eventStates] instead.
  final Map<int, int> eventCounts = {};

  /// Where each event stands, in KSS's own three values: **0** never seen,
  /// **1** playing right now, **2** finished.
  ///
  /// Recovered from the content: across story 16 every `EVENT_<id>`
  /// condition compares against 0 or 2 and nothing else (148 and 11 of them).
  /// A fired-count can never reach 2 for a once-only event, so the eleven
  /// `equal 2` conditions -- the four Readers' Response beats, the mining
  /// restoration, Provoked -- were dead while counts backed them.
  final Map<int, int> eventStates = {};
  bool openingComplete = false;
  bool dayEndPending = false;
  final Map<int, GameDate> taskDeadlines = {};
  final Map<int, String> taskTitles = {};

  /// The switch the global Out of Shape trait event (10010003) is gated on.
  /// KSS names a trait event's switch `TRAIT_EVENT_<traitId>`, and trait 7
  /// is Out of Shape ("Stamina Cost +3 / Regular exercise might help").
  static const outOfShapeSwitch = 'TRAIT_EVENT_7';
  static const outOfShapeTraitId = 7;

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

  /// The save slot this run belongs to, so the in-game Save writes back where
  /// it was loaded from. `null` for a run that has never been saved.
  int? saveSlot;

  /// Which goal week has already had its announcement dialog shown, so the
  /// reference's "Check your Weekly Goals" popup opens once per goal and not
  /// again on every preparation screen. `null` means none yet.
  int? announcedGoalWeek;

  /// Study blocks clicked during the current goal week, counted whether or
  /// not the goal has already been met -- surplus effort still weights the
  /// next week'"'"'s goal rather than being wasted.
  int studyBlocksThisWeek = 0;

  /// Of those, the ones clicked after the goal was already met.
  int surplusStudyBlocks = 0;

  /// The soft currency in the top bar, separate from in-run money.
  int cookies = 0;

  /// The career storylines (rank-A event sets) this run plays. The original
  /// keeps one selected A set per story (`eventset_selected_a_<story>`);
  /// the others' events never fire. Null means every set (old saves, packs
  /// without career sets).
  Set<int>? careerSets;

  /// Picks this run's careers by the sets' own weights:
  /// `rules.events.careersPerRun` of them (1, as the original's single
  /// selection; 0 turns the limit off).
  void chooseCareerSets() {
    final count = pack.rules.number('events', 'careersPerRun', 1).toInt();
    final careers = pack.eventSets
        .where((s) => s['rank'] == 'A' && s['id'] is num)
        .toList();
    if (count <= 0 || careers.length <= count) {
      careerSets = null;
      return;
    }
    final pool = List.of(careers);
    final chosen = <int>{};
    while (chosen.length < count && pool.isNotEmpty) {
      final total = pool.fold<num>(
        0,
        (a, s) => a + ((s['weight'] as num?) ?? 1),
      );
      var roll = random.nextDouble() * total;
      var pick = pool.last;
      for (final s in pool) {
        roll -= (s['weight'] as num?) ?? 1;
        if (roll <= 0) {
          pick = s;
          break;
        }
      }
      chosen.add((pick['id'] as num).toInt());
      pool.remove(pick);
    }
    careerSets = chosen;
  }

  /// Whether an event's storyline is in play this run.
  bool eventSetActive(int? setId) {
    final careers = careerSets;
    if (careers == null || setId == null) return true;
    final isCareer = pack.eventSets.any(
      (s) => (s['id'] as num?)?.toInt() == setId && s['rank'] == 'A',
    );
    return !isCareer || careers.contains(setId);
  }

  /// The quiz question on screen, if a choice asked one. Not saved: a quiz
  /// lives only as long as its choice.
  QuizDraw? quiz;

  /// Raised by START_SAT: the CSAT is sat as soon as the scene closes.
  bool csatPending = false;
  CsatResult? csat;

  /// Departments applied to, the ones that accepted, and where the student
  /// enrolled. Enrolling is what turns the endings on (`ENDING_CODE`).
  final List<int> applications = [];
  final List<int> admittedDepartments = [];
  int? enrolledDepartment;

  final List<LogEntry> log = [];
  bool finished = false;
  String? endingLabel;
  int? endingCode;

  GameState({
    required this.pack,
    required this.date,
    required this.locationId,
    required this.stats,
    required num hp,
    required this.money,
    required this.switches,
    this.isMale = true,
    String? firstName,
    String? lastName,
    Random? random,
  }) : _hp = hp.clamp(pack.rules.hpMin, pack.rules.hpMax),
       firstName = firstName ?? pack.manifest.firstName,
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
    state.unlockedLocations.add(state.locationId);
    state._seedInitialTasks();
    state.chooseCareerSets();
    state.rerolls = r.number('refresh', 'initial', 0).toInt();
    state.cookies = r.number('cookies', 'initial', 0).toInt();
    state.applyStartingTraitEffects();
    state.weeklyGoal = Goals.issue(state);
    state.note('Day 1. ${pack.manifest.name} begins.', 'system');
    return state;
  }

  void _seedInitialTasks() {
    for (final task
        in (pack.rules.section('tasks')['initial'] as List? ?? const [])
            .whereType<Map>()) {
      final due = GameDate.tryParse(
        (task['date'] as Map?)?['dateCode'] as String?,
      );
      if (task['id'] is num && due != null && due.compareTo(date) > 0) {
        final id = (task['id'] as num).toInt();
        taskDeadlines[id] = due;
        taskTitles[id] = task['title'] as String? ?? '';
      }
    }
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

  /// True once the exercise level sits on the top tier of the level table
  /// (level 10, "Big 3 of 1000"). At the top there is no exp left to earn,
  /// so workout blocks stop being dealt and Out of Shape cannot be applied.
  bool get exerciseMaxed => exerciseLevel.level >= pack.exerciseLevels.maxLevel;

  num get totalStat => stats.values.fold<num>(0, (a, b) => a + b);

  num get hpMax => pack.rules.hpMax;

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
    if (name.startsWith('EVENT_')) {
      final id = int.tryParse(name.substring(6));
      if (id != null) return eventStates[id] ?? 0;
    }
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
    if (name.startsWith('EVENT_')) {
      final id = int.tryParse(name.substring(6));
      if (id != null) {
        eventStates[id] = value;
        return;
      }
    }
    if (name == outOfShapeSwitch && exerciseMaxed) {
      // A maxed-out exercise level cannot be out of shape. Holding the
      // switch at 0 is what keeps the Out of Shape trait event from firing,
      // because that event's only condition is TRAIT_EVENT_7 == 1.
      switches[name] = 0;
      return;
    }
    switches[name] = value;
  }

  void addSwitch(String name, int delta) {
    if (engineSwitches.contains(name)) return;
    setSwitch(name, switchValue(name) + delta);
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

  /// Whether trait effects are applied at all. `TraitEngine` reads the same
  /// flag; this is here for the UI, which greys the panel when it is off.
  bool get traitsEnabled => pack.rules.flag('traits', 'enabled', true);

  /// Days left on a temporary trait. Nine traits ship `initialLifeTime`
  /// (Flu 4, Fever Time 2, Hemorrhoids 5); a permanent trait has no entry.
  final Map<int, int> traitDaysLeft = {};

  /// Grants a trait, honouring the two things that can refuse it: a trait
  /// scoped to another story, and one already held. Returns what happened,
  /// so an event can say so.
  bool grantTrait(int id) {
    final trait = pack.traits[id];
    if (trait == null) return false;
    final story = pack.manifest.storyId;
    if (trait.storyId != null && story != null && trait.storyId != story) {
      note(
        'Trait ${trait.name} (#$id) belongs to story ${trait.storyId}, '
            'not $story; not granted.',
        'system',
      );
      return false;
    }
    if (!traits.add(id)) return false;
    if (trait.lifeTimeDays != null) traitDaysLeft[id] = trait.lifeTimeDays!;
    return true;
  }

  bool removeTrait(int id) {
    traitDaysLeft.remove(id);
    return traits.remove(id);
  }

  /// A held trait is in force unless its clock has run out.
  bool traitInForce(int id) {
    if (!traits.contains(id)) return false;
    final left = traitDaysLeft[id];
    return left == null || left > 0;
  }

  /// Ages the temporary traits one day and drops the expired ones. Called
  /// from the day rollover. Returns what it removed, for the day summary.
  List<GameTrait> expireTraitsForNewDay() {
    final gone = <GameTrait>[];
    for (final id in traitDaysLeft.keys.toList()) {
      final left = (traitDaysLeft[id] ?? 0) - 1;
      if (left > 0) {
        traitDaysLeft[id] = left;
        continue;
      }
      traitDaysLeft.remove(id);
      traits.remove(id);
      final trait = pack.traits[id];
      if (trait != null) gone.add(trait);
    }
    return gone;
  }

  /// True on the eve of an exam day, which four traits key off
  /// (`IS_BEFORE_SAT_EXAM`) -- Procrastinator's +45 lands here. The exam
  /// days are the pack's own `specialDays`; story 16 has one, the CSAT.
  bool get isDayBeforeExam {
    final tomorrow = GameDate.addDays(date.day, 1);
    for (final day in pack.manifest.specialDays) {
      final code =
          ((day['gameDate'] as Map?)?['dateCode'] ?? day['dateCode'])
              as String?;
      final when = GameDate.tryParse(code);
      if (when == null) continue;
      if (when.day.year == tomorrow.year &&
          when.day.month == tomorrow.month &&
          when.day.day == tomorrow.day) {
        return true;
      }
    }
    return false;
  }

  /// Traits are passive modifiers; `firstPlus*` ones only apply at run start.
  void applyStartingTraitEffects() {
    if (!traitsEnabled) return;
    for (final trait in [
      ...traits.map((id) => pack.traits[id]).whereType<GameTrait>(),
      ...setupModifiers,
    ]) {
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
    // Traits are NOT summed here. They speak a different effect vocabulary
    // (`plusStat`, not `studyEfficiency`) and carry conditions, scope and a
    // lifetime, so they go through `TraitEngine` instead.
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
    'difficulty': difficulty,
    'characterId': characterId,
    'badgeIds': badgeIds,
    'initialTraitIds': initialTraitIds,
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
    'eventStates': eventStates.map((k, v) => MapEntry(k.toString(), v)),
    'openingComplete': openingComplete,
    'dayEndPending': dayEndPending,
    'taskDeadlines': taskDeadlines.map((k, v) => MapEntry('$k', v.code)),
    'taskTitles': taskTitles.map((k, v) => MapEntry('$k', v)),
    'unlockedLocations': unlockedLocations.toList(),
    'inventory': inventory.map((k, v) => MapEntry(k.toString(), v)),
    'itemUseCounts': itemUseCounts.map((k, v) => MapEntry(k.toString(), v)),
    'traits': traits.toList(),
    'traitDaysLeft': traitDaysLeft.map((k, v) => MapEntry(k.toString(), v)),
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
    'announcedGoalWeek': announcedGoalWeek,
    'saveSlot': saveSlot,
    'studyBlocksThisWeek': studyBlocksThisWeek,
    'surplusStudyBlocks': surplusStudyBlocks,
    'finished': finished,
    'endingLabel': endingLabel,
    'endingCode': endingCode,
    'csatPending': csatPending,
    if (careerSets != null) 'careerSets': careerSets!.toList(),
    'csat': csat?.toJson(),
    'applications': applications,
    'admittedDepartments': admittedDepartments,
    'enrolledDepartment': enrolledDepartment,
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  static GameState fromJson(ContentPack base, Map<String, dynamic> j) {
    // A female protagonist's run continues in the female script.
    final pack = base.forPlayer(isMale: j['isMale'] as bool? ?? true);
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
    state.difficulty = j['difficulty'] as String? ?? 'standard';
    state.characterId = (j['characterId'] as num?)?.toInt();
    state.badgeIds.addAll(
      (j['badgeIds'] as List? ?? [])
          .whereType<int>()
          .where(pack.badges.containsKey)
          .toSet()
          .take(7),
    );
    state.initialTraitIds.addAll(
      (j['initialTraitIds'] as List? ?? []).whereType<int>().toSet().take(5),
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
    intMap('eventStates', state.eventStates);
    state.openingComplete =
        j['openingComplete'] as bool? ??
        (state.dayIndex > 0 || state.eventStates[3] == 2);
    state.dayEndPending = j['dayEndPending'] == true;
    (j['taskDeadlines'] as Map? ?? const {}).forEach((key, value) {
      final id = int.tryParse('$key');
      final due = GameDate.tryParse(value as String?);
      if (id != null && due != null) state.taskDeadlines[id] = due;
    });
    (j['taskTitles'] as Map? ?? const {}).forEach((key, value) {
      final id = int.tryParse('$key');
      if (id != null) state.taskTitles[id] = '$value';
    });
    if (!j.containsKey('taskDeadlines')) state._seedInitialTasks();
    intMap('traitDaysLeft', state.traitDaysLeft);
    if (state.eventStates.isEmpty) {
      // A save written before event progress was tracked: anything that had
      // fired is treated as finished, which is what its count meant.
      state.eventCounts.forEach((id, count) {
        if (count > 0) state.eventStates[id] = 2;
      });
    }
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
    state.announcedGoalWeek = (j['announcedGoalWeek'] as num?)?.toInt();
    state.saveSlot = (j['saveSlot'] as num?)?.toInt();
    state.studyBlocksThisWeek =
        (j['studyBlocksThisWeek'] as num?)?.toInt() ?? 0;
    state.surplusStudyBlocks = (j['surplusStudyBlocks'] as num?)?.toInt() ?? 0;
    state.finished = j['finished'] as bool? ?? false;
    state.endingLabel = j['endingLabel'] as String?;
    state.endingCode = (j['endingCode'] as num?)?.toInt();
    state.csatPending = j['csatPending'] == true;
    if (j['careerSets'] is List) {
      state.careerSets = {
        for (final n in (j['careerSets'] as List).whereType<num>()) n.toInt(),
      };
    }
    state.csat = CsatResult.fromJson(
      (j['csat'] as Map?)?.cast<String, dynamic>(),
    );
    for (final key in ['applications', 'admittedDepartments']) {
      final list = key == 'applications'
          ? state.applications
          : state.admittedDepartments;
      list.addAll(
        (j[key] as List? ?? const []).whereType<num>().map((n) => n.toInt()),
      );
    }
    state.enrolledDepartment = (j['enrolledDepartment'] as num?)?.toInt();
    return state;
  }
}
