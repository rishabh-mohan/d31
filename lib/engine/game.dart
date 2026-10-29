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

import 'pack_mechanics.dart';

import 'dart:math';

import 'admissions.dart';
import 'conditions.dart';
import 'dday.dart';
import 'effects.dart';
import 'event_engine.dart';
import 'game_date.dart';
import 'goals.dart';
import 'pack.dart';
import 'state.dart';
import 'traits.dart';
import 'book_rewards.dart';
import 'book_completion.dart';

export 'dday.dart';

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

  final List<StudyBonus> bonuses;
  String? get bonusSubject => bonuses.isEmpty ? null : bonuses.first.subject;
  int? get bonusGain => bonuses.isEmpty ? null : bonuses.first.value;

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
    this.bonuses = const [],
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

  /// The action met this week's goal and its reward was paid on the spot.
  final bool goalMet;

  /// Items a pack hook handed over while this resolved (Master of Notes'
  /// Weird Workbook on finishing a book), by ID and count. The host shows
  /// each in the acquisition popup before anything else (F21).
  final Map<int, int> acquiredItems;

  /// Short notices from pack abilities ("Bully: +200 Gold."), in order.
  final List<String> reports;

  ActionOutcome(
    this.summary, {
    this.event,
    this.beforeEvents = const [],
    this.dayEnded = false,
    this.runEnded = false,
    this.exhausted = false,
    this.goalMet = false,
    this.acquiredItems = const {},
    this.reports = const [],
  });

  ActionOutcome _withReceipts(Map<int, int> items, List<String> notes) =>
      items.isEmpty && notes.isEmpty
      ? this
      : ActionOutcome(
          summary,
          event: event,
          beforeEvents: beforeEvents,
          dayEnded: dayEnded,
          runEnded: runEnded,
          exhausted: exhausted,
          goalMet: goalMet,
          acquiredItems: {...acquiredItems, ...items},
          reports: [...reports, ...notes],
        );
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
      if (state.eventStates[id] == 2) continue;
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
  /// A pack that names no curve gets the calibrated default.
  List<List<num>> get examCurve => examCurveOf(pack);

  static List<List<num>> examCurveOf(ContentPack pack) {
    final exam = pack.rules.section('exam');
    final curve = [
      for (final p in exam['curve'] as List? ?? const [])
        if (p is List && p.length == 2 && p[0] is num && p[1] is num)
          [p[0] as num, p[1] as num],
    ];
    return curve.isNotEmpty ? curve : Admissions.defaultCurve;
  }

  /// The CSAT standard scores the current stats earn: per subject and the
  /// overall score. Pure arithmetic over [state] (no draws, no writes), so
  /// [takeCsat] and the Mock Exam Paper's forecast always agree.
  static ({Map<String, double> subjects, double standard}) csatScoresOf(
    GameState state,
  ) {
    final pack = state.pack;
    final subjects = pack.manifest.subjects;
    final curve = examCurveOf(pack);
    // Each subject is scored on its own stat and the CSAT is their average,
    // so a lopsided student does worse than a balanced one with the same
    // total.
    final scores = <String, double>{
      for (final s in subjects)
        s: Admissions.subjectScoreFor(state.stats[s] ?? 0, curve),
    };
    final standard = scores.isEmpty
        ? 0.0
        : scores.values.reduce((a, b) => a + b) / scores.length;
    return (subjects: scores, standard: standard);
  }

  /// What the CSAT would give if it were sat now: standard scores and grades
  /// from the current stats. Nothing is recorded; [takeCsat] is unaffected.
  static CsatResult forecastCsat(GameState state) {
    final scores = csatScoresOf(state);
    return CsatResult(
      standardScore: scores.standard,
      subjectScores: scores.subjects,
      grades: {
        for (final e in scores.subjects.entries)
          e.key: Admissions.gradeFor(e.value),
      },
    );
  }

  /// Sits the CSAT once; later calls return the same result.
  CsatResult takeCsat() {
    final existing = state.csat;
    if (existing != null) return existing;
    final subjects = pack.manifest.subjects;
    final computed = csatScoresOf(state);
    final scores = computed.subjects;
    final standard = computed.standard;
    // The Graduation Exam's announced Score and Top % (fitted; see
    // GraduationExam). Scores recorded at the exam cards are kept as taken.
    final examScores = <String, int>{
      for (final subject in subjects) subject: examScoreFor(subject),
    };
    final result = CsatResult(
      standardScore: standard,
      subjectScores: scores,
      grades: {
        for (final e in scores.entries) e.key: Admissions.gradeFor(e.value),
      },
      examScores: examScores,
      topPercents: {
        for (final e in examScores.entries)
          e.key: GraduationExam.topPercent(e.value, examTopTable),
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

  /// Whether an application to [department] may be sent at all (items it
  /// needs). Story availability is [isEligible]'s concern.
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

  /// The chance (0-1) this run's score gets into [department]. The model
  /// behind [displayedRate]; the roll uses the rounded displayed rate.
  double admissionChance(Department department) {
    final base = Admissions.acceptanceChance(
      takeCsat().standardScore,
      department.deviation,
      spread: pack.rules
          .number('exam', 'admissionSpread', Admissions.defaultSpread)
          .toDouble(),
    );
    return modifiedAcceptance(base);
  }

  /// Applies acceptance modifiers to the final chance (0-1): trait
  /// multipliers first, then trait and held-item percentage points, then a
  /// clamp to 0..1. Order is a prototype choice (no recovered arithmetic).
  double modifiedAcceptance(double base) {
    final factor = traits.acceptanceFactor(state);
    final points =
        traits.acceptancePoints(state) +
        state.passiveSum('acceptanceRate', valueKey: 'percent');
    return (base * factor + points / 100).clamp(0.0, 1.0).toDouble();
  }

  /// Sends the applications and decides each one. Returns the departments
  /// that accepted. Headless entry: it fills the draft with [departmentIds]
  /// (skipping the ineligible and second departments of one school) and
  /// commits it. An empty list commits nothing. See `submitDraft`.
  List<int> submitApplications(List<int> departmentIds) {
    if (state.applicationsCommitted) return state.admittedDepartments;
    for (final id in departmentIds) {
      addToDraft(id);
    }
    submitDraft();
    return state.admittedDepartments;
  }

  /// Enrolls in an accepted department, or (null) takes the retake academy,
  /// and turns the endings on. Idempotent: once the final decision is made a
  /// second call changes nothing and returns false. A department that did
  /// not accept the student is refused (false, nothing changes).
  bool enroll(int? departmentId) {
    if (state.finalDecided) return false;
    if (departmentId != null &&
        !state.admittedDepartments.contains(departmentId)) {
      return false;
    }
    if (departmentId != null) {
      state.enrolledDepartment = departmentId;
      final d = pack.admissions.departments[departmentId]!;
      final u = pack.admissions.universities[d.universityId];
      state.note('Enrolled: ${u?.name ?? ''}, ${d.name}.', 'system');
    } else {
      state.note('Retake the year.', 'system');
    }
    state.scoreAnnounced = true;
    state.resultsReviewed = true;
    state.finalDecided = true;
    state.csatPending = false;
    state.setSwitch('ENDING_CODE', 1);
    return true;
  }

  /// The next ending scene, once enrollment has turned the endings on.
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
    if (openingPending || state.dayEndPending) {
      return const [];
    }
    if (examEnabled && isExamDay) return const [];
    final here = state.location;
    if (here == null) return const [];
    final runtime = MechanicRuntime(state);
    final actions = [
      ...here.actions,
      for (final block in pack.mechanics.blocks)
        if (block['catalogOnly'] != true &&
            (block['locations'] as List).contains(state.locationId) &&
            runtime.blockEnabled(block))
          LocationAction.fromJson(
            (block['action'] as Map).cast<String, dynamic>(),
          ),
    ];
    return actions.where((a) {
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
      if (!conditions.evaluate(a.conditionSet, state)) return false;
      final gate = a.conditionFuncCode;
      if (gate != null && !blockGateOpen(gate)) return false;
      return true;
    }).toList();
  }

  /// A block gate is a pack predicate, or an explicitly declared switch.
  bool blockGateOpen(String gate) {
    if (pack.mechanics.section('predicates').containsKey(gate)) {
      return MechanicRuntime(state).condition({'predicate': gate});
    }
    if (pack.switchDefaults.containsKey(gate)) {
      return state.switchValue(gate) != 0;
    }
    conditions.unknownTargets.add('block gate: $gate');
    return false;
  }

  String blockSwitchFor(String gate) {
    final expression = pack.mechanics.section('predicates')[gate];
    if (expression is Map && expression['eq'] is List) {
      final first = (expression['eq'] as List).first;
      if (first is Map && first['switch'] is String) {
        return first['switch'] as String;
      }
    }
    return gate;
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
  int get schoolLocationId => pack.rules
      .number('school', 'locationId', pack.manifest.startLocationId)
      .toInt();

  /// True while the player is in class and cannot leave.
  bool get inClass {
    final suppression =
        pack.rules.section('school')['suppressedBySwitch'] as String?;
    if (suppression != null && state.switchValue(suppression) != 0) {
      return false;
    }
    if (!pack.rules.flag('school', 'lessonsEnabled', false)) return false;
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

  /// A reward notification locks interaction, not the cards behind the modal.
  /// Keep both the drawn blocks and their books until the entire action resumes.
  void invalidateHand() {
    if (bookCompletionPending && _handValid) return;
    _handValid = false;
    _handBooks.clear();
  }

  /// Runs the pack callback bound to engine moment [name] (see
  /// `EffectEngine.runHook`). Items it hands over are kept for the next
  /// outcome's receipts.
  void runHook(String name, [List<dynamic> args = const []]) {
    if (pack.mechanics.section('hooks')[name] is! String) return;
    final before = Map<int, int>.of(state.inventory);
    effects.runHook(state, name, args);
    for (final entry in state.inventory.entries) {
      final gained = entry.value - (before[entry.key] ?? 0);
      if (gained > 0) {
        _hookItems.update(entry.key, (n) => n + gained, ifAbsent: () => gained);
      }
    }
  }

  final Map<int, int> _hookItems = {};

  /// Attaches what hooks handed over and what abilities reported since the
  /// last outcome, then forgets them.
  ActionOutcome _receipts(ActionOutcome outcome) {
    final items = Map<int, int>.of(_hookItems);
    _hookItems.clear();
    final notes = List<String>.of(effects.reports);
    effects.reports.clear();
    return outcome._withReceipts(items, notes);
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
    return _handBooks.putIfAbsent(slot, () {
      final books = studiableBooks();
      if (books.isEmpty) return null;
      final pick = Random(state.date.asInt * 31 + slot + _handSalt);
      return books[pick.nextInt(books.length)];
    });
  }

  final Map<int, GameBook?> _handBooks = {};

  bool get bookCompletionPending =>
      state.pendingBookRewards.isNotEmpty ||
      state.bookCompletionContinuation != null;

  /// An idempotent award, saved before its acquisition receipt is presented.
  void awardBookReward(PendingBookReward pending) {
    if (pending.awarded || !state.pendingBookRewards.contains(pending)) return;
    final reward = pending.selected;
    switch (reward.type) {
      case 'item':
        state.addItem(reward.id!);
      case 'trait':
        pending.traitGranted = effects.acquireTrait(state, reward.id!);
      case 'stat':
        state.addStat(reward.subject!, reward.amount);
    }
    pending.awarded = true;
    pending.stage = 'receipt';
    invalidateHand();
  }

  /// Finish the interrupted block only after all saved reward stages close.
  ActionOutcome finishBookCompletionAction() {
    if (state.pendingBookRewards.isNotEmpty) {
      return ActionOutcome('Finish the book reward first.');
    }
    final saved = state.bookCompletionContinuation;
    if (saved == null) return ActionOutcome('');
    state.bookCompletionContinuation = null;
    effects.pulsedSwitches.addAll((saved['pulses'] as List).cast<String>());
    return _receipts(
      _finishAction(
        (saved['parts'] as List).cast<String>(),
        saved['exerciseBefore'] as int,
        saved['partTimeBefore'] as int,
        (saved['goalMet'] as bool) || settleWeeklyGoal(),
        saved['deferExhaustion'] as bool,
      ),
    );
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
  ///
  /// The chain runs over [menuBooks] -- this run's one variant per rank --
  /// not over every variant. Walking all of them made the engine wait on a
  /// rank-two sibling (1002) the menu never showed, while the menu showed
  /// rank three (2001) as open (A02). The Books menu reads this same list.
  List<GameBook> unlockedBooksFor(String subject) {
    final ordered = menuBooks(subject);
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
    if (openingPending || state.dayEndPending || bookCompletionPending) {
      return false;
    }
    if (state.exhaustionPending) return false;
    if (state.rerolls <= 0) return false;
    state.rerolls--;
    _handSalt++;
    invalidateHand();
    return true;
  }

  bool move(int locationId) {
    if (openingPending || state.dayEndPending || bookCompletionPending) {
      return false;
    }
    if (state.exhaustionPending) return false;
    if (inClass) return false;
    if (state.movementLocked) return false;
    if (!state.unlockedLocations.contains(locationId)) return false;
    final moved = locationId != state.locationId;
    state.locationId = locationId;
    if (moved) _walk();
    invalidateHand();
    return true;
  }

  void _walk() => traits.applyMovement(state);

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
          bonuses: traits.studyBonuses(state),
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

  /// Headless callers settle rewards synchronously; a UI host opts into
  /// the resumable presentation before the action advances.
  ActionOutcome act(
    LocationAction action, {
    GameBook? book,
    bool deferExhaustion = false,
    bool deferBookCompletion = false,
  }) {
    final outcome = _act(action, book: book, deferExhaustion: deferExhaustion);
    if (!deferBookCompletion && bookCompletionPending) {
      for (final pending in state.pendingBookRewards) {
        for (final id in pending.beforeItems) {
          _hookItems.update(id, (n) => n + 1, ifAbsent: () => 1);
        }
        awardBookReward(pending);
      }
      state.pendingBookRewards.clear();
      return finishBookCompletionAction();
    }
    return _receipts(outcome);
  }

  ActionOutcome _act(
    LocationAction action, {
    GameBook? book,
    bool deferExhaustion = false,
  }) {
    if (state.finished) return ActionOutcome('The run is over.');
    if (openingPending || state.dayEndPending || bookCompletionPending) {
      return ActionOutcome('Finish the current story first.');
    }
    if (state.exhaustionPending) {
      return ActionOutcome('Too tired to act.', exhausted: true);
    }

    effects.resetTransient();
    final parts = <String>[];
    final exerciseBefore = state.exerciseLevel.level;
    final partTimeBefore = state.partTimeLevel.level;

    // COMBO_STUDY counts study blocks in a row: any other block starts it over.
    if (action.actionType != 'study') state.studyCombo = 0;
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
    // Pack abilities that fire on any completed block (Bully).
    runHook('actionCompleted', [action.actionType]);
    final goalMet = settleWeeklyGoal();
    if (goalMet) parts.add('Weekly goal met!');
    if (action.blockDuplicated) state.usedActionKeysToday.add(_key(action));

    if (state.pendingBookRewards.isNotEmpty) {
      state.bookCompletionContinuation = {
        'parts': parts,
        'exerciseBefore': exerciseBefore,
        'partTimeBefore': partTimeBefore,
        'goalMet': goalMet,
        'deferExhaustion': deferExhaustion,
        'pulses': effects.pulsedSwitches.toList(),
      };
      invalidateHand();
      return ActionOutcome(parts.join(' '));
    }
    return _finishAction(
      parts,
      exerciseBefore,
      partTimeBefore,
      goalMet,
      deferExhaustion,
    );
  }

  ActionOutcome _finishAction(
    List<String> parts,
    int exerciseBefore,
    int partTimeBefore,
    bool goalMet,
    bool deferExhaustion,
  ) {
    final beforeEvents = <EventRun>[];
    if (state.exerciseLevel.level > exerciseBefore) {
      state.switches['EXERCISE_LEVEL_UP'] = 1;
      // Pack-owned progression effects run before the level-up dialogue.
      runHook('exerciseLevelUp');
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
    final wouldCollapse =
        state.hp <= pack.rules.hpMin && state.date.tick + 1 < actionTicksPerDay;
    if (wouldCollapse && _holdsOn()) {
      state.hp = pack.rules.hpMin + 1;
      parts.add('You hold on at 1 stamina.');
    } else if (wouldCollapse) {
      state.addStat('all', pack.rules.exhaustedPenaltyStat);
      parts.add('You collapse from exhaustion.');
      runHook('exhausted');
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
          goalMet: goalMet,
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
        goalMet: goalMet,
      );
    }

    return _tick(parts.join(' '), beforeEvents: beforeEvents, goalMet: goalMet);
  }

  /// Stubborn 41, I will not falter! 51 and a held Pet Rock 30207
  /// (`surviveExhaustion`) each roll their own chance to keep the player at
  /// 1 stamina instead of collapsing. Seeded on the tick, like the traits'.
  bool _holdsOn() {
    if (traits.survivesExhaustion(state)) return true;
    for (final id in state.inventory.keys) {
      for (final e in pack.items[id]?.effects ?? const <Map>[]) {
        if (e['type'] != 'surviveExhaustion') continue;
        final chance = (e['chance'] as num?) ?? 0;
        final roll = Random(state.date.asInt * 31 + id * 101).nextDouble();
        if (roll < chance) return true;
      }
    }
    return false;
  }

  /// Meets and pays this week's goal if its threshold has been reached --
  /// by an action, or by an event or item since. True when it just was.
  bool settleWeeklyGoal() => Goals.settleIfMet(state);

  // The formulas live in these four helpers so that `preview` and the
  // resolution below cannot disagree about what an action is worth.

  num _studyGain(LocationAction action, GameBook? book, String? subject) {
    final power = book?.power ?? 1;
    var gain = power * pack.rules.studyWeight * state.studyLevel.weight;
    gain += state.studyLevel.plusStat;
    gain += state.passiveSum('studyEfficiency', subject: subject);
    gain += traits.studyBonus(state, subject: subject);
    if (subject != null) gain += state.stationeryBonus(subject);
    // No built-in bonus for repeating a subject: that is a trait's job (Digging
    // Deep adds a flat +3, Hemorrhoids takes 2 away) through COMBO_STUDY and
    // PREV_STUDY_SUBJECT. The old stacking 5% was invented, not recovered.
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
    // Time Jumper / Energizer: seeded on the tick (the day, for Energizer),
    // so the card's 0 is the block's 0.
    if (traits.staminaFree(state)) return 0;

    final perWeight = pack.rules.number('staminaCost', 'perWeight', 6.25);
    // What an action with no stamina weight costs: the pack's
    // staminaCost.<type>, else the engine's default for the type. `base`
    // covers every other action type.
    num typeCost(String type, num fallback) =>
        pack.rules.number('staminaCost', type, fallback);

    num cost = switch (action.actionType) {
      'lesson' => typeCost('lesson', 9),
      'study' => typeCost('study', 16) + perWeight * action.hpWeight,
      'exercise' => typeCost('exercise', 24) + perWeight * action.hpWeight,
      'partTimeJob' =>
        typeCost('partTimeJob', 29) + perWeight * action.hpWeight,
      _ => typeCost('base', 9.5) + perWeight * action.hpWeight,
    };

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

  /// Student XP for one study block: an E-tier book gives `study.expPerStudy`,
  /// and each tier above adds `study.expPerTier` (a class block gives the E
  /// amount). No book counts as E.
  num _studyExpFor(GameBook? book) {
    final rank = int.tryParse(book?.bookRank ?? '') ?? 1;
    return pack.rules.studyExp +
        (rank - 1).clamp(0, 5) * pack.rules.studyExpPerTier;
  }

  String _study(LocationAction action, GameBook? book) {
    final subject =
        book?.subject ??
        state.randomSubject ??
        state.randomOf(pack.manifest.subjects);
    final gain = _studyGain(action, book, subject);

    // Study blocks in a row, of any subject (Hemorrhoids reads this counter).
    state.studyCombo++;
    state.lastStudySubject = subject;

    final amount = gain.round();
    state.addStat(subject, amount);
    final bonuses = traits.studyBonuses(state);
    for (final bonus in bonuses) {
      state.addStat(bonus.subject, bonus.value);
    }
    state.studyExp += _studyExpFor(book);
    Goals.recordStudyBlock(state);
    _spendHp(action);
    var finished = '';
    if (book != null) {
      final before = readCount(book);
      state.bookReadCounts[book.id] = before + 1;
      if (book.doneCount > 0 &&
          before < book.doneCount &&
          before + 1 >= book.doneCount &&
          state.processedBookRewards.add(book.id)) {
        finished = ' Finished ${book.name}.';
        final beforeItems = Map<int, int>.of(_hookItems);
        runHook('bookCompleted', [book.id]);
        if (pack.bookRewards.enabled &&
            pack.bookRewards.tier(book.tier) != null) {
          final receipts = <int>[];
          for (final entry in _hookItems.entries.toList()) {
            final delta = entry.value - (beforeItems[entry.key] ?? 0);
            for (var n = 0; n < delta; n++) {
              receipts.add(entry.key);
            }
          }
          _hookItems
            ..clear()
            ..addAll(beforeItems);
          final pool = buildBookRewards(state, book);
          if (pool.isNotEmpty) {
            final chain = menuBooks(book.subject);
            final index = chain.indexWhere((b) => b.id == book.id);
            state.pendingBookRewards.add(
              PendingBookReward(
                bookId: book.id,
                candidates: pool,
                selectedIndex: Random(state.bookRewardSeed + book.id)
                    .nextInt(pool.length),
                beforeItems: receipts,
                unlockedBookId:
                    index >= 0 &&
                        index + 1 < chain.length &&
                        !isBookComplete(chain[index + 1])
                    ? chain[index + 1].id
                    : null,
              ),
            );
          }
        }
      }
    }
    return 'Studied ${_pretty(subject)}: +$amount.'
        '${bonuses.map((b) => ' ${b.source}: ${_pretty(b.subject)} +${b.value}.').join()}'
        '$finished';
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
    runHook('sleep');
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
    bool goalMet = false,
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
        goalMet: goalMet,
      );
    }

    final event = _maybeEvent();
    _releasePulses();
    return ActionOutcome(
      summary,
      event: event,
      runEnded: state.finished,
      beforeEvents: beforeEvents,
      goalMet: goalMet,
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

    // An evening scene plays on its own evening: the date, stamina and trait
    // ages must not roll over underneath it (A11). Rolling at once also used
    // to begin the next morning's event and drop it unseen behind this one.
    // Retry Year defers every night, scene or not; story 16 only when the
    // evening has one, so its morning event still comes with the rollover.
    if (eveningEvent != null ||
        pack.rules.flag('events', 'deferEveningRollover', false)) {
      state.dayEndPending = true;
      return ActionOutcome('', dayEnded: true, event: eveningEvent);
    }
    return _rollToNextDay(eveningEvent);
  }

  ActionOutcome finishPendingDay() {
    if (!state.dayEndPending) return ActionOutcome('No day is pending.');
    state.dayEndPending = false;
    return _receipts(_rollToNextDay(null));
  }

  ActionOutcome _rollToNextDay(EventRun? eveningEvent) {
    state.date = state.date.nextDay();
    state.exhaustionPending = false;
    state.hp = state.hpMax;
    state.lastStudySubject = null;
    state.studyCombo = 0;
    final lockSwitch = pack.mechanics.section('bindings')['movementLockSwitch'];
    final confined = lockSwitch is String && state.switchValue(lockSwitch) == 1;
    state.movementLocked = confined;
    final toSchool = !confined && !state.date.isWeekend;
    if (toSchool) state.locationId = schoolLocationId;
    state.usedActionKeysToday.clear();
    state.eventsFiredToday = 0;
    // Temporary traits age overnight: Flu lasts 4 days, Fever Time 2.
    for (final gone in state.expireTraitsForNewDay()) {
      state.note('${gone.name} wore off.', 'effect');
    }
    invalidateHand();
    if (!isExamDay) {
      // Pack abilities keyed to the morning: day counters first, then the
      // walk in to school (Professional Latecomer).
      runHook('dayStarted');
      if (toSchool) runHook('arriveAtSchool');
    }

    if (isExamDay) {
      // The last, partial goal week ends here; there is no Monday after it.
      Goals.settle(state);
    }
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
      runHook('exerciseLevelUp');
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

  /// Eligible events on a skipped tick still play, without action rewards.
  /// A persisted guard prevents repeated random checks after save/resume.
  EventRun? beginExhaustedTickEvent() {
    if (!state.exhaustionPending ||
        state.finished ||
        state.date.tick >= actionTicksPerDay ||
        state.exhaustionCheckedAt == state.date.asInt) {
      return null;
    }
    state.exhaustionCheckedAt = state.date.asInt;
    return _maybeEvent();
  }

  /// Advance a lost action slot without granting action rewards.
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
    if (state.finished || state.csatPending) {
      state.exhaustionPending = false;
      return ActionOutcome('', runEnded: state.finished);
    }
    return _receipts(_endDay());
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

  /// What an offer costs today: the listed price after Limited Offer's 50%
  /// and Solitary Gourmet's food discount. The Store shows this number.
  int priceOf(int offerId) {
    final offer = pack.shop[offerId];
    if (offer == null) return 0;
    final listed = offer['price'] as num;
    final item = pack.items[(offer['itemId'] as num?)?.toInt()];
    final price = (listed * traits.priceFactor(state, item)).round();
    // Scrooge: a cheap enough item goes for a fixed price instead.
    final fixed = traits.priceOverride(state, listed);
    return fixed == null ? price : min(price, fixed.round());
  }

  /// Week boundaries follow Saturday, even for a pack starting another day.
  int get shopWeek =>
      (state.dayIndex + (pack.manifest.startDate.day.weekday + 1) % 7) ~/ 7;

  void _ensureShopOffers() {
    if (state.shopOfferWeek == shopWeek) return;
    state.shopOfferWeek = shopWeek;
    state.shopRerolls = 0;
    state.shopOfferIds
      ..clear()
      ..addAll(pack.shop.keys);
  }

  List<Map<String, dynamic>> get shopOffers {
    _ensureShopOffers();
    return [for (final id in state.shopOfferIds) ?pack.shop[id]];
  }

  bool get shopPurchasedThisWeek => state.shopPurchases.entries.any(
    (e) => e.key.startsWith('$shopWeek:') && e.value > 0,
  );

  String? get shopRefreshProblem {
    _ensureShopOffers();
    if (shopPurchasedThisWeek) {
      return 'Refresh is unavailable after a purchase until Saturday.';
    }
    if (state.cookies < 1) return 'Not enough cookies.';
    if (state.shopOfferIds.length < 2) return 'Not enough offers to refresh.';
    return null;
  }

  /// One cookie each time. Only the first reroll removes an offer.
  /// Selection still uses this prototype's configured offer pool.
  String? refreshShop() {
    final problem = shopRefreshProblem;
    if (problem != null) return problem;
    final count = state.shopOfferIds.length - (state.shopRerolls == 0 ? 1 : 0);
    final pool = pack.shop.keys.toList()..shuffle(state.random);
    final chosen = pool.take(count).toList();
    state.cookies--;
    state.shopOfferIds
      ..clear()
      ..addAll(chosen);
    state.shopRerolls++;
    return null;
  }

  String? purchase(int offerId) {
    _ensureShopOffers();
    if (!state.shopOfferIds.contains(offerId)) {
      return 'This offer is not in the current Store.';
    }
    final offer = pack.shop[offerId];
    if (offer == null) return 'This item is unavailable.';
    final week = shopWeek;
    final key = '$week:$offerId';
    final price = priceOf(offerId);
    final limit = (offer['stock'] as num?)?.toInt() ?? 1;
    if ((state.shopPurchases[key] ?? 0) >= limit) {
      return 'Sold out until Saturday.';
    }
    final itemId = (offer['itemId'] as num).toInt();
    if (!pack.items.containsKey(itemId)) return 'Item missing from pack.';
    // An item's maxCount caps ownership however it is obtained; refuse
    // before charging rather than let addItem clamp a paid-for copy away.
    if (shopItemAtCap(offerId)) return 'You already own as many as you can.';
    if (state.money < price) return 'Not enough Gold.';
    state.addMoney(-price);
    state.inventory[itemId] = state.itemCount(itemId) + 1;
    state.shopPurchases[key] = (state.shopPurchases[key] ?? 0) + 1;
    return null;
  }

  /// True when the offer's item is already held at its `maxCount`.
  bool shopItemAtCap(int offerId) {
    final itemId = (pack.shop[offerId]?['itemId'] as num?)?.toInt();
    final cap = pack.items[itemId]?.maxCount;
    return itemId != null && cap != null && state.itemCount(itemId) >= cap;
  }

  int shopStock(int offerId) {
    final offer = pack.shop[offerId];
    if (offer == null) return 0;
    _ensureShopOffers();
    if (!state.shopOfferIds.contains(offerId)) return 0;
    final key = '$shopWeek:$offerId';
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
    // Consumables with a supported effect, and kept checking tools; an item
    // with nothing to apply is refused rather than used up for nothing.
    if (!item.canUse) return false;
    final blocker = TraitEngine(pack: state.pack).itemUseBlockedBy(state, item);
    if (blocker != null) {
      effects.reports.add('$blocker: you cannot use ${item.name}.');
      return false;
    }
    // Developer doubles the stamina a coffee restores.
    final hpFactor = TraitEngine(pack: state.pack).itemHpFactor(state, item);
    if (hpFactor == 1) {
      effects.applyItem(item, state);
    } else {
      for (final e in item.effects) {
        if (e['trigger'] != null) continue;
        final v = e['value'];
        effects.applyItemEffect(
          e['type'] == 'hp' && v is num ? {...e, 'value': v * hpFactor} : e,
          state,
        );
      }
    }
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

  /// The last item use's reports and requested views, emptied on read.
  ItemUseOutcome takeItemOutcome() => ItemUseOutcome.drain(effects, state);

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

/// What using an item asked the UI to show: report lines (the Promotion Exam
/// Kit, the Scouter) and `ui` views (predicted grades, abilities, recipes).
class ItemUseOutcome {
  final List<String> reports;
  final List<Map<String, dynamic>> views;
  final GameState state;
  const ItemUseOutcome({
    required this.reports,
    required this.views,
    required this.state,
  });

  /// Takes both queues off [effects], leaving them empty.
  factory ItemUseOutcome.drain(EffectEngine effects, GameState state) {
    final out = ItemUseOutcome(
      reports: List.of(effects.reports),
      views: List.of(effects.views),
      state: state,
    );
    effects.reports.clear();
    effects.views.clear();
    return out;
  }

  bool get isEmpty => reports.isEmpty && views.isEmpty;
}
