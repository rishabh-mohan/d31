/// The day loop: the thing that is actually "D-31 mode".
///
/// A run is `totalDays` days of `ticksPerDay` action slots. Each slot the
/// player picks an action at their current location, or moves. Resolving an
/// action spends stamina, pays out, advances the clock, and may hand control
/// to an event.
///
/// All of the arithmetic reads from rules.json. None of it is in KSS's JSON
/// (its formulas are compiled), so these are this project's model, fitted to
/// the data that is observable -- action weights, hpWeight, book power,
/// level-table weights. Change rules.json to change the game.
library;

import 'dart:math';

import 'admissions.dart';
import 'conditions.dart';
import 'effects.dart';
import 'event_engine.dart';
import 'game_date.dart';
import 'goals.dart';
import 'pack.dart';
import 'state.dart';
import 'traits.dart';

/// Which card shape an action gets drawn as.
enum ActionKind { study, lesson, partTimeJob, exercise, sleep, special }

/// A class block'"'"'s subject and the book its payout is scaled from.
class Lesson {
  final String subject;
  final GameBook book;
  Lesson({required this.subject, required this.book});
}

/// What an action card shows before it is tapped.
class ActionPreview {
  final ActionKind kind;
  final String title;

  /// Subject tag, when the action is subject-shaped.
  final String? subject;

  /// Book rank tag ("E", "1"...), when the action studies a book.
  final String? rank;

  /// Stat points gained, or stamina restored for sleep. When [gainMax] is
  /// set this is the lower bound of a band.
  final int? gain;

  /// Upper bound, for actions whose payout is rolled on resolution.
  final int? gainMax;

  /// Money paid, for a part-time shift.
  final int? money;

  final num hpCost;

  /// 0..1 bar under the title: book completion, or progress to the next level.
  final double progress;

  /// Whether the bar ends in a coin, as the book cards do.
  final bool showCoin;

  /// Set when a study block'"'"'s book has been read through. The card then
  /// shows "Reading Complete" in place of the progress bar.
  final bool bookComplete;

  ActionPreview({
    required this.kind,
    required this.title,
    required this.hpCost,
    this.subject,
    this.rank,
    this.gain,
    this.gainMax,
    this.money,
    this.progress = 0,
    this.showCoin = false,
    this.bookComplete = false,
  });
}

/// What happened when an action resolved.
class ActionOutcome {
  final String summary;
  final EventRun? event;
  final List<EventRun> beforeEvents;
  final bool dayEnded;
  final bool runEnded;
  final bool exhausted;
  ActionOutcome(
    this.summary, {
    this.event,
    this.beforeEvents = const [],
    this.dayEnded = false,
    this.runEnded = false,
    this.exhausted = false,
  });
}

class Game {
  final ContentPack pack;
  final GameState state;
  final ConditionEvaluator conditions;
  late final EffectEngine effects;
  late final EventEngine events;

  /// Reads the trait catalog's own `effectList`. See `traits.dart` for which
  /// of the two stat fields is the real one.
  final TraitEngine traits;

  Game({required this.pack, required this.state})
    : conditions = ConditionEvaluator(),
      traits = TraitEngine(pack: pack) {
    effects = EffectEngine(conditions: conditions);
    events = EventEngine(pack: pack, conditions: conditions, effects: effects);
    // One evaluator and one effect engine across the whole run, so the
    // "unknown verb" sets accumulate somewhere the dev panel can read.
    effects.conditions.unknownTargets.addAll(conditions.unknownTargets);
  }

  factory Game.newRun(ContentPack pack, {Random? random}) {
    final state = GameState.newRun(pack, random: random);
    return Game(pack: pack, state: state);
  }

  List<int> get openingEventIds =>
      (pack.rules.section('events')['openingEventIds'] as List? ?? const [])
          .whereType<num>()
          .map((id) => id.toInt())
          .toList();

  bool get openingPending =>
      !state.openingComplete && openingEventIds.isNotEmpty;

  /// Host-driven prologue beats do not spend time or consume random-event caps.
  /// Resume at the first unfinished beat rather than granting rewards twice.
  EventRun? beginOpeningEvent() {
    if (!openingPending) return null;
    for (final id in openingEventIds) {
      if (state.eventStates[id] == 2) {
        // Old prototype saves completed event 1 while SHOW_ENDING was a no-op.
        // Reconcile its continuation without replaying the ending/rewards.
        final continuations =
            pack.rules.section('events')['openingContinuationSwitches'] as Map?;
        final name = continuations?['$id'];
        if (name is String && state.switchValue(name) == 0) {
          state.setSwitch(name, 1);
        }
        continue;
      }
      final event = pack.events[id];
      if (event == null) throw StateError('Opening event $id is missing');
      final dailyCount = state.eventsFiredToday;
      effects.resetTransient();
      final run = events.begin(event, state);
      state.eventsFiredToday = dailyCount;
      state.note('Prologue: ${event.name}', 'event');
      invalidateHand();
      return run;
    }
    state.openingComplete = true;
    invalidateHand();
    return null;
  }

  /// Tick-zero scheduled dialogue runs before the first action of a day.
  EventRun? beginDay() {
    if (isExamDay && examEnabled) return _beginExamDay();
    return pack.rules.flag('events', 'checkAtDayStart', false)
        ? nextScheduledEvent()
        : null;
  }

  // --- exam day -----------------------------------------------------------

  bool get examEnabled => pack.examEnabled;

  bool get isExamDay => state.date.compareTo(pack.manifest.endDate) >= 0;

  /// The Graduation Exam scene opens exam day and ends on START_SAT. A pack
  /// without one still sits the exam.
  EventRun? _beginExamDay() {
    if (state.csat != null || state.finished) return null;
    final event = _nextPinnedEvent();
    if (event != null) {
      effects.resetTransient();
      state.note('Event: ${event.name}', 'event');
      return events.begin(event, state);
    }
    state.csatPending = true;
    return null;
  }

  /// The highest-priority date-pinned event eligible now, ignoring the daily
  /// cap. Exam day and the endings are scheduled content and must play.
  GameEvent? _nextPinnedEvent() {
    final order =
        (pack.rules.section('events')['priorityOrder'] as List?)
            ?.whereType<String>()
            .toList() ??
        const ['veryHigh', 'high', 'middle', 'low'];
    int rank(GameEvent e) {
      final i = order.indexOf(e.priority);
      return i < 0 ? order.length : i;
    }

    final pinned = events.eligible(state).where((e) => !e.isRandomDate).toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.id.compareTo(b.id);
      });
    return pinned.firstOrNull;
  }

  /// `rules.exam.curve`: `[stat, score]` points for one subject's score.
  /// A pack that names neither a curve nor the older meanTotal/sdTotal gets
  /// the calibrated default.
  List<List<num>> get examCurve {
    final exam = pack.rules.section('exam');
    final curve = [
      for (final p in exam['curve'] as List? ?? const [])
        if (p is List && p.length == 2 && p[0] is num && p[1] is num)
          [p[0] as num, p[1] as num],
    ];
    if (curve.isNotEmpty) return curve;
    return exam.containsKey('meanTotal') ? const [] : Admissions.defaultCurve;
  }

  /// Sits the CSAT once; later calls return the same result.
  CsatResult takeCsat() {
    final existing = state.csat;
    if (existing != null) return existing;
    final subjects = pack.manifest.subjects;
    final curve = examCurve;
    final mean = pack.rules.number('exam', 'meanTotal', 2600);
    final sd = pack.rules.number('exam', 'sdTotal', 1300);
    // Each subject is scored on its own stat and the CSAT is their average,
    // so a lopsided student does worse than a balanced one with the same
    // total. (Older packs: one linear curve over the total.)
    double scoreOf(num stat) => curve.isNotEmpty
        ? Admissions.subjectScoreFor(stat, curve)
        : Admissions.standardScoreFor(
            stat * subjects.length,
            mean: mean,
            sd: sd,
          );
    final scores = <String, double>{
      for (final s in subjects) s: scoreOf(state.stats[s] ?? 0),
    };
    var standard = curve.isNotEmpty && scores.isNotEmpty
        ? scores.values.reduce((a, b) => a + b) / scores.length
        : Admissions.standardScoreFor(state.totalStat, mean: mean, sd: sd);
    // "University acceptance rate +1%" items move the score by the points
    // that are worth around the middle of the curve.
    standard += state.passiveSum('acceptanceRate', valueKey: 'percent') * 0.25;
    final result = CsatResult(
      standardScore: standard,
      subjectScores: scores,
      grades: {
        for (final e in scores.entries) e.key: Admissions.gradeFor(e.value),
      },
    );
    state.csat = result;
    state.note(
      'CSAT: standard score ${standard.toStringAsFixed(1)} '
          '(top ${(100 - result.percentile).toStringAsFixed(1)}%).',
      'system',
    );
    return result;
  }

  int get applicationLimit =>
      pack.rules.number('exam', 'applications', 3).toInt();

  /// Every department, hardest first.
  List<Department> departmentsByCutoff() =>
      pack.admissions.departments.values.toList()..sort((a, b) {
        final c = b.deviation.compareTo(a.deviation);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

  /// Whether an application to [department] may be sent at all.
  bool canApply(Department department) =>
      department.requiredItems.every((id) => state.itemCount(id) > 0);

  /// One application per university: a second department of a school
  /// already chosen in [chosen] is refused.
  bool sameSchoolChosen(Department department, Iterable<int> chosen) =>
      chosen.any(
        (id) =>
            id != department.id &&
            pack.admissions.departments[id]?.universityId ==
                department.universityId,
      );

  double admissionChance(Department department) => Admissions.acceptanceChance(
    takeCsat().standardScore,
    department.deviation,
    spread: pack.rules
        .number('exam', 'admissionSpread', Admissions.defaultSpread)
        .toDouble(),
  );

  /// Sends the applications and decides each one. Returns the departments
  /// that accepted.
  List<int> submitApplications(List<int> departmentIds) {
    if (state.applications.isNotEmpty) return state.admittedDepartments;
    for (final id in departmentIds) {
      if (state.applications.length >= applicationLimit) break;
      final department = pack.admissions.departments[id];
      if (department == null ||
          !canApply(department) ||
          sameSchoolChosen(department, state.applications)) {
        continue;
      }
      state.applications.add(id);
      if (state.random.nextDouble() < admissionChance(department)) {
        state.admittedDepartments.add(id);
      }
    }
    return state.admittedDepartments;
  }

  /// Enrols (or, with null, retakes the year) and turns the endings on.
  void enroll(int? departmentId) {
    if (departmentId != null &&
        state.admittedDepartments.contains(departmentId)) {
      state.enrolledDepartment = departmentId;
      final d = pack.admissions.departments[departmentId]!;
      final u = pack.admissions.universities[d.universityId];
      state.note('Enrolled: ${u?.name ?? ''}, ${d.name}.', 'system');
    }
    state.csatPending = false;
    state.setSwitch('ENDING_CODE', 1);
  }

  /// The next ending scene, once enrolment has turned the endings on.
  EventRun? nextEndingEvent() {
    if (state.finished || state.switchValue('ENDING_CODE') != 1) return null;
    _processAutomaticEvents();
    final event = _nextPinnedEvent();
    if (event == null) return null;
    effects.resetTransient();
    state.note('Event: ${event.name}', 'event');
    return events.begin(event, state);
  }

  /// No ending scene claimed the run: close it on the admission itself.
  void concludeRun() {
    if (state.finished) return;
    state.finished = true;
    final department = state.enrolledDepartment == null
        ? null
        : pack.admissions.departments[state.enrolledDepartment];
    state.endingLabel ??= department == null
        ? 'Retake the year'
        : '${pack.admissions.universities[department.universityId]?.name ?? ''}'
              ' — ${department.name}';
  }

  EventRun? nextScheduledEvent() {
    if (openingPending ||
        !pack.rules.flag('events', 'chainScheduledEvents', false)) {
      return null;
    }
    _processAutomaticEvents();
    final event = events.pick(state, scheduledOnly: true);
    if (event == null) return null;
    effects.resetTransient();
    return events.begin(event, state);
  }

  void _processAutomaticEvents() {
    if (pack.rules.flag('tasks', 'enabled', false)) {
      // A task with a tick (Retry Year's tick-14 escape) ends at that tick; a
      // day-only one lasts through its day, so "is it due today?" can see it.
      final expired = state.taskDeadlines.entries
          .where(
            (task) => task.value.tick > 0
                ? task.value.compareTo(state.date) <= 0
                : task.value.day.isBefore(state.date.day),
          )
          .map((task) => task.key)
          .toList();
      for (final id in expired) {
        state.taskDeadlines.remove(id);
        state.taskTitles.remove(id);
      }
    }
    // A campaign opts in to its own hidden events; the character abilities'
    // nightly resets always run, or each ability would fire once per run.
    final allFakes = pack.rules.flag('events', 'executeFakeEvents', false);
    final processed = <int>{};
    for (var steps = 0; steps < 100; steps++) {
      final event = events
          .eligible(state, includeFake: true)
          .where(
            (event) =>
                event.isFake &&
                (allFakes || event.isCharacterEvent) &&
                !processed.contains(event.id),
          )
          .firstOrNull;
      if (event == null) return;
      processed.add(event.id);
      final dailyCount = state.eventsFiredToday;
      final run = events.begin(event, state);
      state.eventsFiredToday = dailyCount;
      while (run.current != null && !run.current!.isEnd) {
        if (run.current!.choices.isNotEmpty) {
          state.note(
            'Automatic event ${event.id} unexpectedly needs a choice.',
            'system',
          );
          return;
        }
        run.advance();
      }
    }
  }

  // --- what the player may do right now -----------------------------------

  List<GameLocation> availableLocations() {
    if (openingPending) {
      final here = state.location;
      return here == null ? [] : [here];
    }
    if (inClass) {
      final school = pack.locations[schoolLocationId];
      return school == null ? const [] : [school];
    }
    if (state.movementLocked) {
      final here = state.location;
      return here == null ? const [] : [here];
    }
    final list =
        pack.locations.values
            .where((l) => state.unlockedLocations.contains(l.id))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  /// Every action at the current location that is not blocked right now.
  /// This is the pool the hand is drawn from, not what the player sees.
  List<LocationAction> availableActions() {
    if (openingPending || state.dayEndPending) return const [];
    if (examEnabled && isExamDay) return const [];
    final here = state.location;
    if (here == null) return const [];
    return here.actions.where((a) {
      if (a.blockDuplicated && state.usedActionKeysToday.contains(_key(a))) {
        return false;
      }
      // A maxed-out exercise level retires the workout block: there is no
      // level left to earn, so it stops being dealt into the hand. Every
      // location keeps at least two other actions, so no pool empties --
      // the Gym, the thinnest at three, still deals sleep and study.
      if (a.actionType == 'exercise' && state.exerciseMaxed) return false;
      // `conditionFuncCode` gates the special actions (idol practice, game
      // practice, ...). Without the switch set, hide them.
      final gate = a.conditionFuncCode;
      if (gate != null && !blockGateOpen(gate)) return false;
      return true;
    }).toList();
  }

  /// Whether a special block's compiled gate is open.
  bool blockGateOpen(String gate) {
    final recovered = recoveredBlockGates[gate];
    if (recovered != null) return recovered(state);
    return state.switchValue(blockSwitchFor(gate)) != 0;
  }

  /// Gates read from the Korean native's block-condition table (the
  /// `Map<String, bool Function()>` built at 0x6cb798). Each body is the
  /// disassembled closure, not a guess; see docs/RETRY-YEAR.md.
  static final Map<String, bool Function(GameState)> recoveredBlockGates = {
    // RJl / SJl / TJl: a friend's trouble block, once their rapport switch is
    // high enough and the rolling BLOCK_TARGET date has passed.
    'GO_PRO_CONDITION': (s) =>
        s.switchValue('GO_BLOCK') == 0 &&
        s.switchValue('GO_SEE') >= 2 &&
        _pastBlockTarget(s) &&
        s.switchValue('EXAM_SW') != 1,
    'GO_LEE_CONDITION': (s) =>
        s.switchValue('LEE_BLOCK') == 0 &&
        s.switchValue('LEE_SEE') >= 3 &&
        _pastBlockTarget(s) &&
        s.switchValue('EXAM_SW') != 1,
    'GO_BANJANG_CONDITION': (s) =>
        s.switchValue('NA_BLOCK') == 0 &&
        s.switchValue('BANJANG_HEALTH') >= 2 &&
        _pastBlockTarget(s) &&
        s.switchValue('EXAM_SW') != 1,
    // UJl
    'HELP_BANJANG_CONDITION': (s) =>
        s.switchValue('BANJANG_STUDY_BLOCK_ON') == 1 &&
        s.switchValue('BANJANG_CLEAR') == 0 &&
        s.switchValue('NA_BLOCK') == 1 &&
        s.switchValue('EXAM_SW') != 1,
    // VJl / WJl
    'SINGKING_CONDITION': (s) =>
        s.switchValue('SING_POINT') >= 15 && s.switchValue('SING_WIN') != 1,
    'KARAOKE_CONDITION': (s) => s.switchValue('SING_WIN') != 1,
    // Story 16. LJl / MJl: the career blocks once their route opens.
    'IDOL_BLOCK_CONDITION': (s) => s.switchValue('IDOL_BLOCK') == 1,
    'PRO_GAME_BLOCK_CONDITION': (s) => s.switchValue('GAME_BLOCK') == 1,
    // NJl / OJl / ZJl: blocks a character brings. Med Student Ihyeon (70)
    // crafts medicine up to MEDICAL_LEVEL 3; Hyunho Park (74) collects parts
    // until he holds Robotics Master (160020); psychic practice belongs to a
    // character (10044) the catalog does not ship, so it stays shut.
    'MEDICAL_BLOCK_CONDITION': (s) =>
        s.characterId == 70 && s.switchValue('MEDICAL_LEVEL') <= 3,
    'MECHANIC_BLOCK_CONDITION': (s) =>
        s.characterId == 74 && !s.traits.contains(160020),
    'PRACTICE_PSYCHIC_CONDITION': (s) =>
        s.characterId == 10044 &&
        ![
          'skill1',
          'skill2',
          'skill3',
          'skill4',
          'skill5',
        ].every((k) => s.switchValue(k) >= 5),
  };

  /// The native builds `DATE_2024<MM><DD>00` from BLOCK_TARGET_MONTH/DAY and
  /// asks whether now is strictly later, so the block opens from tick 1 of
  /// the target day.
  static bool _pastBlockTarget(GameState s) {
    final month = s.switchValue('BLOCK_TARGET_MONTH');
    final day = s.switchValue('BLOCK_TARGET_DAY');
    if (month <= 0 || day <= 0) return false;
    final target = GameDate(DateTime(s.date.day.year, month, day), 0);
    return s.date.compareTo(target) > 0;
  }

  /// The switch a special block's gate actually reads.
  ///
  /// The gate name is a **compiled predicate** in the original —
  /// `IDOL_BLOCK_CONDITION` — while the content writes a plainer switch,
  /// `IDOL_BLOCK`. Reading the gate name as a switch meant every special
  /// block stayed hidden for ever, because no such switch exists.
  ///
  /// Story 16 writes `GAME_BLOCK` and the matching gate is
  /// `PRO_GAME_BLOCK_CONDITION`, so the `PRO_` prefix is dropped too. Gates
  /// with no declared switch — mechanic, medical, psychic — belong to other
  /// campaigns' routes and stay shut here, which is correct: story 16's
  /// careers are Entrepreneur, Soccer, Cooking and Webtoon.
  String blockSwitchFor(String gate) {
    if (pack.switchDefaults.containsKey(gate)) return gate;
    var name = gate.endsWith('_CONDITION')
        ? gate.substring(0, gate.length - '_CONDITION'.length)
        : gate;
    if (pack.switchDefaults.containsKey(name)) return name;
    if (name.startsWith('PRO_')) {
      final shorter = name.substring(4);
      if (pack.switchDefaults.containsKey(shorter)) return shorter;
    }
    return name;
  }

  String _key(LocationAction a) =>
      a.duplicatedKey ?? '${a.actionType}:${a.text}';

  // --- the block hand -----------------------------------------------------
  //
  // Each tick the player is dealt a hand of action blocks drawn from the
  // location's list *without replacement, weighted by `weight`* -- so
  // `weight` is an appearance probability, not a payout multiplier. That is
  // why the Reading Room carries study 12 / sleep 0.3: you go there to be
  // offered study and almost nothing else.
  //
  // How many blocks are dealt is compiled in the original; it is
  // `rules.day.blocksPerTick` here.

  List<LocationAction> _hand = const [];
  bool _handValid = false;

  // --- lessons ------------------------------------------------------------
  //
  // On weekdays the student is in class for the first few ticks. During those
  // ticks School is where they are, they cannot leave, and the first block of
  // the hand is always a Lesson -- it is not drawn, so a Refresh Ticket
  // cannot reroll it away. Which subject the lesson teaches and how much it
  // is worth vary; the amount comes from a real book of that subject, so
  // lessons track the same power curve as studying does.

  int get classTicks => pack.rules.number('school', 'classTicks', 6).toInt();
  int get schoolLocationId =>
      pack.rules.number('school', 'locationId', 1000).toInt();

  /// True while the player is in class and cannot leave.
  bool get inClass {
    final suppression =
        pack.rules.section('school')['suppressedBySwitch'] as String?;
    if (suppression != null && state.switchValue(suppression) != 0) {
      return false;
    }
    if (!pack.rules.flag('school', 'lessonsEnabled', true)) return false;
    if (state.date.isWeekend) return false;
    if (state.date.tick >= classTicks) return false;
    return state.dayIndex > 0 ||
        pack.rules.flag('school', 'lessonsOnFirstDay', true);
  }

  static final LocationAction _lessonAction = LocationAction.fromJson(const {
    'locationActionType': 'lesson',
    'text': 'Lesson',
    'weight': 0,
    'hpWeight': 1,
    'blockDuplicated': false,
  });

  /// The lesson on offer at a given moment. Derived from the date, not from
  /// `state.random`, so it is stable across rebuilds and refreshes within the
  /// same tick.
  Lesson? lessonFor(GameDate when) {
    final subjects = pack.manifest.subjects;
    if (subjects.isEmpty) return null;

    final seed = when.asInt;
    final pick = Random(seed);
    final subject = subjects[pick.nextInt(subjects.length)];

    // Lessons draw from the lower book ranks early and open up as the run
    // goes on, so class keeps pace without ever beating deliberate study.
    final books = pack.booksFor(subject);
    if (books.isEmpty) return null;
    final cap = pack.rules.number('school', 'lessonRankCap', 3).toInt();
    final reach = pack.rules.number('school', 'lessonRankPerWeek', 1).toInt();
    final limit = (cap + (state.dayIndex ~/ 7) * reach)
        .clamp(1, books.length)
        .toInt();
    final book = books[pick.nextInt(limit)];

    return Lesson(subject: subject, book: book);
  }

  /// A lesson pays somewhere inside a band around its book'"'"'s power.
  (int, int) _lessonRange(Lesson lesson) {
    final mid = _lessonGain(lesson);
    final spread = pack.rules.number('school', 'lessonSpread', 0.45);
    return ((mid * (1 - spread)).round(), (mid * (1 + spread)).round());
  }

  num _lessonGain(Lesson lesson) {
    var gain =
        lesson.book.power *
        pack.rules.studyWeight *
        state.studyLevel.weight *
        pack.rules.number('school', 'lessonFactor', 1);
    gain += state.studyLevel.plusStat;
    // "Study Efficiency for Lessons" items carry subject `lesson`.
    gain += state.passiveSum('studyEfficiency', subject: 'lesson');
    gain += traits.studyBonus(
      state,
      subject: lesson.subject,
      schoolStudy: true,
    );
    gain += state.stationeryBonus(lesson.subject);
    return gain;
  }

  /// The blocks currently on offer. Dealt lazily so a fresh hand appears
  /// after every tick, move, or unlock.
  ///
  /// During class the Lesson block occupies the first slot and the rest of
  /// the hand is drawn around it, so a refresh rerolls the other blocks but
  /// never the lesson.
  List<LocationAction> hand() {
    if (state.exhaustionPending) return const [];
    if (!_handValid) {
      if (inClass) {
        final rest = _draw(limit: blocksPerTick - 1);
        _hand = [_lessonAction, ...rest];
      } else {
        _hand = _draw();
      }
      _handValid = true;
    }
    return _hand;
  }

  void invalidateHand() => _handValid = false;

  /// Drops the Out of Shape trait and the switch its global event waits on.
  /// Exercising is the cure in the original: the level-up dialogue's closing
  /// node carries `REMOVE_TRAIT_FROM_EXERCISE`.
  void clearOutOfShape() {
    state.switches[GameState.outOfShapeSwitch] = 0;
    state.removeTrait(GameState.outOfShapeTraitId);
  }

  int get blocksPerTick => pack.rules.number('day', 'blocksPerTick', 4).toInt();

  /// Draws a hand **with replacement**, so the same block can appear twice.
  ///
  /// This matters more than it looks. Without replacement, a location with
  /// exactly `blocksPerTick` ungated actions -- School has 4, and
  /// blocksPerTick is 4 -- always deals its entire pool, so the hand never
  /// changes and a Refresh Ticket does nothing. The reference hands settle
  /// it: they show two "Science Textbook" cards side by side, and two
  /// workout cards in another, which a without-replacement draw cannot
  /// produce.
  List<LocationAction> _draw({int? limit}) {
    final pool = availableActions();
    final count = limit ?? blocksPerTick;
    if (count <= 0 || pool.isEmpty) return const [];

    final weights = [
      for (final a in pool) a.weight <= 0 ? 0.0001 : a.weight.toDouble(),
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);

    final drawn = <LocationAction>[];
    for (var n = 0; n < count; n++) {
      var roll = state.random.nextDouble() * total;
      var picked = pool.length - 1;
      for (var i = 0; i < pool.length; i++) {
        roll -= weights[i];
        if (roll <= 0) {
          picked = i;
          break;
        }
      }
      drawn.add(pool[picked]);
    }
    return drawn;
  }

  /// Which book a study block in slot [slot] is studying.
  ///
  /// Derived from the date and the slot rather than `state.random`, so the
  /// card shows the same book that tapping it will study, and so it survives
  /// a rebuild within the same tick. A Refresh Ticket changes the hand, not
  /// this -- the slot is what moves.
  GameBook? bookForSlot(int slot) {
    final books = studiableBooks();
    if (books.isEmpty) return null;
    final pick = Random(state.date.asInt * 31 + slot + _handSalt);
    return books[pick.nextInt(books.length)];
  }

  /// How many times this book has been read.
  int readCount(GameBook book) => state.bookReadCounts[book.id] ?? 0;

  /// True once the book has been read through. A finished book is still
  /// studiable — the reference shows a completed Korean Textbook still paying
  /// out — it simply shows "Reading Complete" where the progress bar was.
  bool isBookComplete(GameBook book) =>
      book.doneCount > 0 && readCount(book) >= book.doneCount;

  /// The books of one subject that are available to study, weakest first.
  ///
  /// Tiers unlock in order: a book is reachable only once the one below it has
  /// been read through, which is the same rule the Books menu states as
  /// `Unlocked when you complete reading <previous book>`. The lowest tier is
  /// always open.
  List<GameBook> unlockedBooksFor(String subject) {
    final ordered = pack.booksFor(subject);
    final out = <GameBook>[];
    for (final book in ordered) {
      out.add(book);
      if (!isBookComplete(book)) break;
    }
    return out;
  }

  /// Every unlocked book across every subject — the pool the block lottery
  /// draws a study block's book from. A locked tier must never be offered.
  List<GameBook> studiableBooks() => [
    for (final subject in pack.manifest.subjects) ...unlockedBooksFor(subject),
  ];

  /// Bumped on every refresh so a redeal also reshuffles the books.
  int _handSalt = 0;

  /// Spend a Refresh Ticket to redeal the hand. Returns false when there is
  /// no ticket, which the original surfaces as "Refresh unavailable!".
  bool refreshHand() {
    if (openingPending || state.dayEndPending) return false;
    if (state.exhaustionPending) return false;
    if (state.rerolls <= 0) return false;
    state.rerolls--;
    _handSalt++;
    invalidateHand();
    return true;
  }

  bool move(int locationId) {
    if (openingPending || state.dayEndPending) return false;
    if (state.exhaustionPending) return false;
    if (inClass) return false;
    if (state.movementLocked) return false;
    if (!state.unlockedLocations.contains(locationId)) return false;
    state.locationId = locationId;
    invalidateHand();
    return true;
  }

  // --- previewing an action -----------------------------------------------

  /// What an action card shows before you tap it: what it pays, what it
  /// costs, and the tags that go on the card. Computed with the same
  /// formulas `act` uses, so the card cannot drift from the outcome.
  ActionPreview preview(LocationAction action, {GameBook? book}) {
    final hpCost = _hpCostOf(action);

    switch (action.actionType) {
      case 'study':
        final subject = book?.subject ?? state.randomSubject;
        final gain = _studyGain(action, book, subject);
        return ActionPreview(
          kind: ActionKind.study,
          title: book?.name ?? 'Study',
          subject: subject,
          rank: book?.tier,
          gain: gain.round(),
          hpCost: hpCost,
          progress: _bookProgress(book),
          bookComplete: book != null && isBookComplete(book),
          showCoin: true,
        );

      case 'partTimeJob':
        return ActionPreview(
          kind: ActionKind.partTimeJob,
          title: _jobLabel(action),
          money: _partTimePay().round(),
          hpCost: hpCost,
          progress: _levelProgress(pack.partTimeLevels, state.partTimeExp),
        );

      case 'exercise':
        return ActionPreview(
          kind: ActionKind.exercise,
          title: 'Level ${state.exerciseLevel.level}',
          gain: _exerciseGain().round(),
          hpCost: hpCost,
          progress: _levelProgress(pack.exerciseLevels, state.exerciseExp),
        );

      case 'lesson':
        final lesson = lessonFor(state.date);
        final span = lesson == null ? null : _lessonRange(lesson);
        return ActionPreview(
          kind: ActionKind.lesson,
          title: 'Period ${state.date.tick + 1}',
          subject: lesson?.subject,
          gain: span?.$1,
          gainMax: span?.$2,
          hpCost: hpCost,
        );

      case 'sleep':
        return ActionPreview(
          kind: ActionKind.sleep,
          title: action.label(),
          gain: _sleepRecovery().round(),
          hpCost: 0,
        );

      default:
        return ActionPreview(
          kind: ActionKind.special,
          title: action.label(),
          hpCost: hpCost,
        );
    }
  }

  /// Part-time work is themed per location in the pack's
  /// `levels.partTimeJob.textByLocation`, indexed by the current level.
  String _jobLabel(LocationAction action) {
    final raw = pack.rawLevels['partTimeJob'];
    final list = raw is Map ? raw['textByLocation'] : null;
    if (list is List) {
      for (final entry in list.whereType<Map>()) {
        if ((entry['locationId'] as num?)?.toInt() != state.locationId) {
          continue;
        }
        final texts = (entry['textList'] as List?)
            ?.whereType<String>()
            .toList();
        if (texts == null || texts.isEmpty) break;
        final idx = (state.partTimeLevel.level - 1).clamp(0, texts.length - 1);
        return texts[idx];
      }
    }
    return action.label();
  }

  double _bookProgress(GameBook? book) {
    if (book == null || book.doneCount <= 0) return 0;
    return (readCount(book) / book.doneCount).clamp(0, 1).toDouble();
  }

  double _levelProgress(LevelTable table, num exp) {
    final tier = table.tierFor(exp);
    final next = table.nextThresholdAfter(exp);
    if (next == null || next <= tier.exp) return 1;
    return ((exp - tier.exp) / (next - tier.exp)).clamp(0, 1).toDouble();
  }

  // --- resolving an action ------------------------------------------------

  ActionOutcome act(
    LocationAction action, {
    GameBook? book,
    bool deferExhaustion = false,
  }) {
    if (state.finished) return ActionOutcome('The run is over.');
    if (openingPending || state.dayEndPending) {
      return ActionOutcome('Finish the current story first.');
    }
    if (state.exhaustionPending) {
      return ActionOutcome('Too tired to act.', exhausted: true);
    }

    effects.resetTransient();
    final parts = <String>[];
    final exerciseBefore = state.exerciseLevel.level;
    final partTimeBefore = state.partTimeLevel.level;

    switch (action.actionType) {
      case 'study':
        parts.add(_study(action, book));
      case 'partTimeJob':
        parts.add(_partTimeJob(action));
      case 'exercise':
        parts.add(_exercise(action));
      case 'lesson':
        parts.add(_lesson(action));
      case 'sleep':
        parts.add(_sleep(action));
      default:
        parts.add(_special(action));
    }

    // The action's own changer runs after the built-in payout, so content can
    // adjust it.
    effects.applyChanger(action.changer, state);
    if (Goals.checkMet(state)) {
      parts.add('Weekly goal met!');
    }
    if (action.blockDuplicated) state.usedActionKeysToday.add(_key(action));

    final beforeEvents = <EventRun>[];
    if (state.exerciseLevel.level > exerciseBefore) {
      state.switches['EXERCISE_LEVEL_UP'] = 1;
      // Levelling up is what shakes Out of Shape off, which is why the
      // global level-up event ends on REMOVE_TRAIT_FROM_EXERCISE. At the
      // top of the table it also latches: `setSwitch` refuses to raise
      // TRAIT_EVENT_7 again while the level is maxed.
      clearOutOfShape();
      final levelUp = beginSystemEvent('exerciseLevelUp');
      if (levelUp != null) beforeEvents.add(levelUp);
    }

    if (state.partTimeLevel.level > partTimeBefore) {
      state.switches['PART_TIME_JOB_LEVEL_UP'] = 1;
      final levelUp = beginSystemEvent('partTimeLevelUp');
      if (levelUp != null) beforeEvents.add(levelUp);
    }

    // The final action uses the last slot: there is no remaining day to lose.
    // Follow normal evening/rollover, without the collapse popup or penalty.
    if (state.hp <= pack.rules.hpMin &&
        state.date.tick + 1 < actionTicksPerDay) {
      state.addStat('all', pack.rules.exhaustedPenaltyStat);
      parts.add('You collapse from exhaustion.');
      _releasePulses();
      if (deferExhaustion) {
        state.exhaustionPending = true;
        // The chosen action consumed a slot; the rest are lost to exhaustion.
        advanceExhaustedTick();
        invalidateHand();
        return ActionOutcome(
          parts.join(' '),
          exhausted: true,
          beforeEvents: beforeEvents,
          event: beginExhaustionEvent(),
        );
      }
      final outcome = _endDay();
      return ActionOutcome(
        parts.join(' '),
        dayEnded: true,
        exhausted: true,
        beforeEvents: beforeEvents,
        runEnded: outcome.runEnded,
        event: outcome.event,
      );
    }

    return _tick(parts.join(' '), beforeEvents: beforeEvents);
  }

  // The formulas live in these four helpers so that `preview` and the
  // resolution below cannot disagree about what an action is worth.

  num _studyGain(LocationAction action, GameBook? book, String? subject) {
    final power = book?.power ?? 1;
    var gain = power * pack.rules.studyWeight * state.studyLevel.weight;
    gain += state.studyLevel.plusStat;
    gain += state.passiveSum('studyEfficiency', subject: subject);
    gain += traits.studyBonus(state, subject: subject);
    if (subject != null) gain += state.stationeryBonus(subject);
    if (subject != null && state.lastStudySubject == subject) {
      final stacks = min(state.studyCombo, pack.rules.comboMaxStacks);
      gain *= 1 + stacks * pack.rules.comboBonusPercent;
    }
    return gain;
  }

  num _partTimePay() {
    var pay = pack.rules.partTimeBaseMoney * state.partTimeLevel.weight;
    pay *= pack.partTimeLevels.efficiencyAt(state.locationId);
    pay += state.passiveSum('partTimeEarnings');
    final (traitFlat, traitFactor) = traits.partTimeMoney(state);
    pay += traitFlat;
    final percent = state.passiveSum('partTimeEarnings', valueKey: 'percent');
    if (percent != 0) pay *= 1 + percent / 100;
    return pay * traitFactor;
  }

  num _exerciseGain() {
    var exp = pack.rules.exerciseExp.toDouble();
    exp += state.passiveSum('exerciseEfficiency');
    final (traitFlat, traitFactor) = traits.exerciseExp(state);
    exp += traitFlat;
    final percent = state.passiveSum('exerciseEfficiency', valueKey: 'percent');
    if (percent != 0) exp *= 1 + percent / 100;
    return exp *
        traitFactor *
        pack.exerciseLevels.efficiencyAt(state.locationId);
  }

  num _sleepRecovery() {
    var recovery = pack.rules.sleepRestoresHp;
    final here = state.location;
    if (here != null && here.type == 'sleep') {
      recovery += pack.rules.sleepLocationBonusHp;
    }
    return recovery +
        state.passiveSum('sleepEfficiency') +
        traits.sleepHp(state);
  }

  /// Stamina is the only real resource, so this is the most load-bearing
  /// number in the game. See `rules.staminaCost` for where the shape comes
  /// from. Sleep never costs; it restores.
  num _hpCostOf(LocationAction action) {
    if (action.actionType == 'sleep') return 0;

    final base = pack.rules.number('staminaCost', 'base', 9.5);
    final perWeight = pack.rules.number('staminaCost', 'perWeight', 6.25);

    num cost;
    if (action.actionType == 'lesson') {
      cost = pack.rules.number('staminaCost', 'lesson', base);
    } else {
      cost = base + perWeight * action.hpWeight;
    }

    // hpCost effects are discounts (negative), and may be gated on the tick
    // -- Night Owl is -3 from tick 10, Indestructible a flat -3.
    cost += state.passiveSum('hpCost');
    cost += traits.hpCostDelta(
      state,
      actionType: action.actionType,
      actionFuncCode: action.funcCode,
    );
    if (cost < 0) return 0;
    // Whole points, as the reference shows them, so the card and the bar
    // never disagree by a rounding step.
    return max(0, cost.round() - state.exerciseLevel.level);
  }

  String _study(LocationAction action, GameBook? book) {
    final subject =
        book?.subject ??
        state.randomSubject ??
        state.randomOf(pack.manifest.subjects);
    final gain = _studyGain(action, book, subject);

    if (state.lastStudySubject == subject) {
      state.studyCombo++;
    } else {
      state.studyCombo = 1;
    }
    state.lastStudySubject = subject;

    final amount = gain.round();
    state.addStat(subject, amount);
    state.studyExp += pack.rules.studyExp;
    Goals.recordStudyBlock(state);
    _spendHp(action);
    if (book != null) {
      state.bookReadCounts[book.id] = (state.bookReadCounts[book.id] ?? 0) + 1;
    }
    return 'Studied ${_pretty(subject)}: +$amount.';
  }

  String _partTimeJob(LocationAction action) {
    final amount = _partTimePay().round();
    state.addMoney(amount);
    final (flatExp, expFactor) = traits.partTimeExp(state);
    state.partTimeExp += (pack.rules.partTimeExp + flatExp) * expFactor;
    _spendHp(action);
    return 'Worked a shift: +$amount.';
  }

  String _exercise(LocationAction action) {
    final exp = _exerciseGain();
    final before = state.exerciseLevel.level;
    _spendHp(action);
    state.exerciseExp += exp.round();
    final after = state.exerciseLevel.level;
    final levelled = after > before
        ? ' Exercise level up: ${state.exerciseLevel.name}.'
        : '';
    return 'Exercised: +${exp.round()} EXP.$levelled';
  }

  String _special(LocationAction action) {
    _spendHp(action);
    return action.label();
  }

  void _spendHp(LocationAction action) {
    state.addHp(-_hpCostOf(action));
  }

  /// Sleeping restores stamina and costs a tick like any other block. It does
  /// **not** end the day -- the day ends when the action ticks run out.
  String _sleep(LocationAction action) {
    final recovery = _sleepRecovery();
    state.addHp(recovery);

    // Items with an onSleep trigger fire here.
    for (final entry in state.inventory.entries) {
      final item = pack.items[entry.key];
      if (item == null) continue;
      for (final e in item.effects) {
        if (e['trigger'] == 'onSleep') effects.applyItemEffect(e, state);
      }
    }
    return 'Slept. +${recovery.round()} stamina.';
  }

  /// A class block. Teaches whichever subject the lesson is on, at a rate set
  /// by a real book of that subject, and counts toward the weekly goal just
  /// as deliberate study does.
  String _lesson(LocationAction action) {
    final lesson = lessonFor(state.date);
    if (lesson == null) {
      _spendHp(action);
      return 'Class.';
    }
    final (lo, hi) = _lessonRange(lesson);
    final amount = hi <= lo ? lo : lo + state.random.nextInt(hi - lo + 1);
    state.addStat(lesson.subject, amount);
    state.studyExp += pack.rules.studyExp;
    Goals.recordStudyBlock(state);
    _spendHp(action);
    return 'Lesson — ${_pretty(lesson.subject)}: +$amount.';
  }

  /// Spend one tick.
  ///
  /// A day is `ticksPerDay` (15) slots, but only the first
  /// `actionTicksPerDay` (14) are the player's. The last one is the evening
  /// slot: it takes no action, it is where the day's `DATE_..14` content
  /// fires ("9 o'clock News", "The Day Before the CSAT", "Make a wish"), and
  /// then the day rolls over.
  ActionOutcome _tick(
    String summary, {
    List<EventRun> beforeEvents = const [],
  }) {
    state.date = state.date.advance(1, pack.manifest.ticksPerDay);
    invalidateHand();

    if (state.date.tick >= actionTicksPerDay) {
      final end = _endDay();
      _releasePulses();
      return ActionOutcome(
        summary,
        dayEnded: true,
        runEnded: end.runEnded,
        event: end.event,
        beforeEvents: beforeEvents,
      );
    }

    final event = _maybeEvent();
    _releasePulses();
    return ActionOutcome(
      summary,
      event: event,
      runEnded: state.finished,
      beforeEvents: beforeEvents,
    );
  }

  /// Lowers the switches a block raised only for this action's event check.
  void _releasePulses() {
    for (final name in effects.pulsedSwitches) {
      state.setSwitch(name, 0);
    }
    effects.pulsedSwitches.clear();
  }

  int get actionTicksPerDay {
    final configured = pack.rules
        .number('day', 'actionTicksPerDay', 14)
        .toInt();
    return configured.clamp(1, pack.manifest.ticksPerDay);
  }

  /// What the Calendar shows: the to-do list, as the original's is. That is
  /// the story's fixed dates (the CSAT, Retry Year's mock and promotion
  /// exams, from todos.json) plus whatever events have told the player about
  /// through ADD_TODO -- Taeyang's challenge, the National Cooking Contest,
  /// a match with the pros. Events the player has not heard of stay off it
  /// (TODO 66). Finished and past entries drop off.
  List<ScheduledEntry> schedule() {
    final entries = <ScheduledEntry>[
      for (final task in state.taskDeadlines.entries)
        if (!task.value.day.isBefore(state.date.day))
          ScheduledEntry(
            date: task.value,
            name: taskLabel(state.taskTitles[task.key] ?? ''),
          ),
    ];
    // A pack without a to-do for its exam still shows the day the run ends.
    if (!entries.any((e) => e.date.day == pack.manifest.endDate.day)) {
      entries.add(
        ScheduledEntry(date: pack.manifest.endDate, name: 'Graduation Exam'),
      );
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  /// To-do titles are authored as identifiers ("Date_with_Customer",
  /// "VisitArtGallery"); a few are placeholders the native fills in
  /// ("FUNC_1"), which read as a plain appointment.
  static String taskLabel(String raw) {
    if (raw.isEmpty || raw.startsWith('FUNC_')) return 'Appointment';
    return raw
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
        .trim();
  }

  /// Runs the evening slot, then advances to the next day.
  ActionOutcome _endDay() {
    // Park the clock on the evening tick so the tick-14 content is eligible.
    state.date = GameDate(state.date.day, pack.manifest.ticksPerDay - 1);
    final eveningEvent = _maybeEvent();

    if (pack.rules.flag('events', 'deferEveningRollover', false)) {
      state.dayEndPending = true;
      return ActionOutcome('', dayEnded: true, event: eveningEvent);
    }
    return _rollToNextDay(eveningEvent);
  }

  ActionOutcome finishPendingDay() {
    if (!state.dayEndPending) return ActionOutcome('No day is pending.');
    state.dayEndPending = false;
    return _rollToNextDay(null);
  }

  ActionOutcome _rollToNextDay(EventRun? eveningEvent) {
    state.date = state.date.nextDay();
    state.exhaustionPending = false;
    state.hp = state.hpMax;
    state.lastStudySubject = null;
    state.studyCombo = 0;
    final confined = state.switchValue('DOK_BANG_ON') == 1;
    state.movementLocked = confined;
    if (!confined && !state.date.isWeekend) state.locationId = schoolLocationId;
    state.usedActionKeysToday.clear();
    state.eventsFiredToday = 0;
    // Temporary traits age overnight: Flu lasts 4 days, Fever Time 2.
    for (final gone in state.expireTraitsForNewDay()) {
      state.note('${gone.name} wore off.', 'effect');
    }
    invalidateHand();

    if (isExamDay && examEnabled) {
      // Exam day is played: the Graduation Exam scene, the CSAT, the
      // applications, then whichever ending the result opens. No blocks.
      state.note('Day ${state.totalDays}. The exam has arrived.', 'system');
      return ActionOutcome('', dayEnded: true, event: eveningEvent);
    }
    if (isExamDay) {
      state.finished = true;
      state.endingLabel ??= 'Exam day';
      state.note('Day ${state.totalDays}. The exam has arrived.', 'system');
      return ActionOutcome(
        '',
        dayEnded: true,
        runEnded: true,
        event: eveningEvent,
      );
    }

    // Weekly Goals renew every Monday, and the run starts on one.
    if (state.date.day.weekday == DateTime.monday) {
      Goals.rollOver(state);
    }

    state.note('Day ${state.dayNumber}.', 'system');
    // Tick-0 housekeeping (the hidden resets) belongs to the new morning.
    _processAutomaticEvents();
    final morningEvent = pack.rules.flag('events', 'checkAtDayStart', false)
        ? null
        : _maybeEvent();
    return ActionOutcome(
      '',
      dayEnded: true,
      event: eveningEvent ?? morningEvent,
    );
  }

  EventRun? _maybeEvent() {
    _processAutomaticEvents();
    final personal = _nextCharacterEvent();
    if (personal != null) return personal;
    final event = events.pick(state);
    if (event == null) return null;
    final run = events.begin(event, state);
    state.note('Event: ${event.name}', 'event');
    return run;
  }

  /// The chosen character's own ability scene, if one is ready. These carry
  /// their own odds (the Beggar is a 30% check each block) and reset nightly
  /// through hidden events, so they neither wait for nor spend the day's
  /// story-event budget.
  EventRun? _nextCharacterEvent() {
    final event =
        (events.eligible(state).where((e) => e.isCharacterEvent).toList()
              ..sort((a, b) => a.id.compareTo(b.id)))
            .firstOrNull;
    if (event == null) return null;
    final fired = state.eventsFiredToday;
    final run = events.begin(event, state);
    state.eventsFiredToday = fired;
    state.note('Event: ${event.name}', 'event');
    return run;
  }

  // --- items --------------------------------------------------------------

  /// Global failure dialogue bypasses the random-event cap and repeat gates.
  EventRun? beginExhaustionEvent() => beginSystemEvent('exhaustion');

  /// Event/item XP can level up outside an action. Present the existing global
  /// graph after that scene; its final node clears the pending switch.
  EventRun? beginPendingLevelUpEvent() {
    if (state.switchValue('EXERCISE_LEVEL_UP') == 1) {
      clearOutOfShape();
      return beginSystemEvent('exerciseLevelUp');
    }
    if (state.switchValue('PART_TIME_JOB_LEVEL_UP') == 1) {
      return beginSystemEvent('partTimeLevelUp');
    }
    return null;
  }

  EventRun? beginSystemEvent(String binding) {
    final event = pack.systemEvents[pack.systemEventBindings[binding]];
    if (event == null) return null;
    final dailyCount = state.eventsFiredToday;
    final run = events.begin(event, state);
    state.eventsFiredToday = dailyCount;
    return run;
  }

  /// Presentation-only lost slots: no payouts, stamina recovery or events.
  bool advanceExhaustedTick() {
    if (!state.exhaustionPending || state.date.tick >= actionTicksPerDay) {
      return false;
    }
    state.date = GameDate(state.date.day, state.date.tick + 1);
    return true;
  }

  ActionOutcome finishExhaustedDay() {
    if (!state.exhaustionPending) {
      return ActionOutcome('No exhausted day to finish.');
    }
    return _endDay();
  }

  /// One representative per subject/rank for this run, retained across saves.
  List<GameBook> menuBooks(String subject) {
    final grouped = <String, List<GameBook>>{};
    for (final book in pack.booksFor(subject)) {
      grouped.putIfAbsent(book.bookRank, () => []).add(book);
    }
    return [
      for (final entry in grouped.entries)
        (() {
          final key = '$subject:${entry.key}';
          var id = state.bookChoices[key];
          if (!entry.value.any((b) => b.id == id)) {
            id = entry.value[state.random.nextInt(entry.value.length)].id;
            state.bookChoices[key] = id;
          }
          return pack.books[id]!;
        })(),
    ];
  }

  String? purchase(int offerId) {
    final offer = pack.shop[offerId];
    if (offer == null) return 'This item is unavailable.';
    final week =
        (state.dayIndex + 2) ~/ 7; // run begins Monday; restock Saturday.
    final key = '$week:$offerId';
    final price = (offer['price'] as num).toInt();
    final limit = (offer['stock'] as num?)?.toInt() ?? 1;
    if ((state.shopPurchases[key] ?? 0) >= limit) {
      return 'Sold out until Saturday.';
    }
    if (state.money < price) return 'Not enough Gold.';
    final itemId = (offer['itemId'] as num).toInt();
    if (!pack.items.containsKey(itemId)) return 'Item missing from pack.';
    state.addMoney(-price);
    state.inventory[itemId] = state.itemCount(itemId) + 1;
    state.shopPurchases[key] = (state.shopPurchases[key] ?? 0) + 1;
    return null;
  }

  int shopStock(int offerId) {
    final offer = pack.shop[offerId];
    if (offer == null) return 0;
    final key = '${(state.dayIndex + 2) ~/ 7}:$offerId';
    return max(
      0,
      ((offer['stock'] as num?)?.toInt() ?? 1) -
          (state.shopPurchases[key] ?? 0),
    );
  }

  bool equipStationery(int id) {
    final item = pack.stationery[id];
    if (item == null || (state.stationeryInventory[id] ?? 0) < 1) return false;
    state.equippedStationery[item['type'] as String] = id;
    return true;
  }

  static const stationeryRanks = ['S', 'A', 'B', 'C'];

  /// Rank first, then item: catalog size must never determine rarity.
  int? _rollStationery(Map<String, num> weights) {
    final pools = <String, List<int>>{
      for (final rank in stationeryRanks)
        rank: pack.stationery.entries
            .where((e) => e.value['rank'] == rank)
            .map((e) => e.key)
            .toList(),
    };
    final available = weights.entries
        .where((e) => e.value > 0 && (pools[e.key]?.isNotEmpty ?? false))
        .toList();
    final total = available.fold<num>(0, (sum, e) => sum + e.value);
    if (total <= 0) return null;
    var roll = state.random.nextDouble() * total;
    for (final entry in available) {
      roll -= entry.value;
      if (roll < 0) {
        final pool = pools[entry.key]!;
        return pool[state.random.nextInt(pool.length)];
      }
    }
    return pools[available.last.key]!.last;
  }

  Map<String, num> get stationeryDrawWeights => {
    for (final rank in stationeryRanks)
      rank:
          ((pack.rules.raw['stationery']?['drawWeights'] as Map?)?[rank]
              as num?) ??
          const {'S': 1, 'A': 9, 'B': 30, 'C': 60}[rank]!,
  };

  /// Called after Wednesday's summary, before Thursday's preparation menu.
  /// The date and pending batch are saved, so reopening cannot grant it twice.
  bool beginWeeklyStationeryDraw() {
    if (state.pendingStationery.isNotEmpty) return true;
    if (state.finished ||
        state.date.day.weekday != DateTime.thursday ||
        state.date.tick != 0 ||
        state.stationeryDrawDay == state.date.dayCode) {
      return false;
    }
    final cards = List.generate(
      5,
      (_) => _rollStationery(stationeryDrawWeights),
    );
    if (cards.any((id) => id == null)) return false;
    state.stationeryDrawDay = state.date.dayCode;
    state.stationeryFreeRedrawUsed = false;
    state.stationeryLocks.clear();
    state.pendingStationery.addAll(cards.cast<int>());
    return true;
  }

  bool redrawStationery() {
    if (state.pendingStationery.isEmpty ||
        state.stationeryLocks.length == state.pendingStationery.length) {
      return false;
    }
    final cost = state.stationeryFreeRedrawUsed
        ? pack.rules.number('stationery', 'redrawCookies', 1).toInt()
        : 0;
    if (state.cookies < cost) return false;
    final weights = {...stationeryDrawWeights, 'C': 0};
    final replacements = <int, int>{};
    for (var i = 0; i < state.pendingStationery.length; i++) {
      if (state.stationeryLocks.contains(i)) continue;
      final id = _rollStationery(weights);
      if (id == null) return false;
      replacements[i] = id;
    }
    state.cookies -= cost;
    state.stationeryFreeRedrawUsed = true;
    replacements.forEach((index, id) => state.pendingStationery[index] = id);
    return true;
  }

  void claimStationeryDraw() {
    for (final id in state.pendingStationery) {
      state.stationeryInventory[id] = (state.stationeryInventory[id] ?? 0) + 1;
    }
    state.pendingStationery.clear();
    state.stationeryLocks.clear();
  }

  int availableStationeryCopies(int id) => max(
    0,
    (state.stationeryInventory[id] ?? 0) -
        (state.equippedStationery.values.contains(id) ? 1 : 0),
  );

  /// Preserve the best ingredient tier, per the user's A+C -> A rule.
  /// Original odds remain unresolved; the upgrade chance is editable.
  Map<String, num> stationeryCombinationWeights(List<int> materials) {
    var best = stationeryRanks.length;
    for (final id in materials) {
      final rank = pack.stationery[id]?['rank'] as String?;
      if (rank == null) continue;
      final index = stationeryRanks.indexOf(rank);
      if (index < 0) continue;
      best = min(best, index);
    }
    if (best == stationeryRanks.length) return {};
    if (best == 0) return {'S': 100};
    final upgrade = pack.rules
        .number('stationery', 'combineUpgradeChance', 0.05)
        .clamp(0, 1);
    return {
      stationeryRanks[best]: 1 - upgrade,
      stationeryRanks[best - 1]: upgrade,
    };
  }

  int? combineStationery(List<int> materials) {
    if (materials.length < 2 || materials.length > 4) return null;
    final counts = <int, int>{};
    for (final id in materials) {
      if (!pack.stationery.containsKey(id)) return null;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.entries.any((e) => availableStationeryCopies(e.key) < e.value)) {
      return null;
    }
    final result = _rollStationery(stationeryCombinationWeights(materials));
    if (result == null) return null;
    for (final entry in counts.entries) {
      state.stationeryInventory[entry.key] =
          state.stationeryInventory[entry.key]! - entry.value;
    }
    state.stationeryInventory[result] =
        (state.stationeryInventory[result] ?? 0) + 1;
    return result;
  }

  bool useItem(int itemId) {
    if (state.exhaustionPending) return false;
    return useItemWith(state, effects, itemId);
  }

  /// Uses a consumable against any state/effect engine -- the event screen
  /// offers Use on an item an event just handed over, without a Game.
  static bool useItemWith(GameState state, EffectEngine effects, int itemId) {
    final item = state.pack.items[itemId];
    if (item == null || state.itemCount(itemId) <= 0) return false;
    if (!item.isConsumable) return false;
    effects.applyItem(item, state);
    state.itemUseCounts[itemId] = (state.itemUseCounts[itemId] ?? 0) + 1;
    // A checking tool (the Promotion Exam Kit) is read, not used up.
    if (!item.effects.any((e) => e['keepItem'] == true)) {
      state.removeItem(itemId);
    }
    state.note('Used ${item.name}.', 'effect');
    return true;
  }

  /// What the last item used asked to tell the player, emptied on read.
  List<String> takeItemReports() {
    final out = List<String>.of(effects.reports);
    effects.reports.clear();
    return out;
  }

  // --- outcome ------------------------------------------------------------

  String get outcome {
    if (state.endingLabel != null && state.endingLabel!.isNotEmpty) {
      return state.endingLabel!;
    }
    return 'Total stats: ${state.totalStat.round()}';
  }

  String _pretty(String subject) => subject.isEmpty
      ? subject
      : subject[0].toUpperCase() + subject.substring(1);

  /// Verbs and targets the pack used that the engine has no handler for.
  /// Shown in the dev panel; an unimplemented verb that silently does nothing
  /// is the hardest kind of content bug to spot.
  Map<String, Set<String>> get gaps => {
    'funcCodes': effects.unknownFuncCodes,
    'conditionTargets': {
      ...conditions.unknownTargets,
      ...effects.conditions.unknownTargets,
    },
  };
}

/// One row of the Calendar: a day something is pinned to, and its name.
class ScheduledEntry {
  final GameDate date;
  final String name;

  /// The event it came from, or null for the fallback exam row.
  final GameEvent? event;

  const ScheduledEntry({required this.date, required this.name, this.event});
}
