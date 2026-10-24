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
  EventRun? beginDay() => pack.rules.flag('events', 'checkAtDayStart', false)
      ? nextScheduledEvent()
      : null;

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
      final expired = state.taskDeadlines.entries
          .where((task) => task.value.compareTo(state.date) <= 0)
          .map((task) => task.key)
          .toList();
      for (final id in expired) {
        state.taskDeadlines.remove(id);
        state.taskTitles.remove(id);
      }
    }
    if (!pack.rules.flag('events', 'executeFakeEvents', false)) return;
    final processed = <int>{};
    for (var steps = 0; steps < 100; steps++) {
      final event = events
          .eligible(state, includeFake: true)
          .where((event) => event.isFake && !processed.contains(event.id))
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
      if (gate != null && state.switchValue(blockSwitchFor(gate)) == 0) {
        return false;
      }
      return true;
    }).toList();
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
      return ActionOutcome(
        summary,
        dayEnded: true,
        runEnded: end.runEnded,
        event: end.event,
        beforeEvents: beforeEvents,
      );
    }

    final event = _maybeEvent();
    return ActionOutcome(
      summary,
      event: event,
      runEnded: state.finished,
      beforeEvents: beforeEvents,
    );
  }

  int get actionTicksPerDay {
    final configured = pack.rules
        .number('day', 'actionTicksPerDay', 14)
        .toInt();
    return configured.clamp(1, pack.manifest.ticksPerDay);
  }

  /// What the Calendar shows: every date-pinned event still ahead of the run.
  ///
  /// The spine is content, not code — 23 of the English campaign's events
  /// carry a `date` condition (docs/D30-MODE-SPEC.md §6.6), the Graduation
  /// Exam among them — so nothing here is hardcoded and a storyline that adds
  /// a National Cooking Contest shows up on its own.
  ///
  /// Which of them to list is our rule, not a recovered one: an event that
  /// belongs to a storyline set only appears once the run has actually met
  /// that storyline, otherwise day one would advertise every career at once.
  List<ScheduledEntry> schedule() {
    final seenSets = <int>{
      for (final entry in state.eventStates.entries)
        if (entry.value > 0)
          if (pack.events[entry.key]?.eventSetId case final int set) set,
    };

    final entries = <ScheduledEntry>[];
    for (final event in pack.events.values) {
      if (event.isFake || event.isRandomDate) continue;
      if ((state.eventStates[event.id] ?? 0) >= 2) continue;
      final set = event.eventSetId;
      if (set != null && !seenSets.contains(set)) continue;
      final date = _pinnedDate(event.conditionSet);
      if (date == null || date.day.isBefore(state.date.day)) continue;
      entries.add(ScheduledEntry(date: date, name: event.name, event: event));
    }

    // The exam is in the spine, but a pack that drops it should still show the
    // day the run ends on.
    if (!entries.any((e) => e.date.day == pack.manifest.endDate.day)) {
      entries.add(
        ScheduledEntry(date: pack.manifest.endDate, name: 'Graduation Exam'),
      );
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  /// The first `date` condition anywhere in a condition tree.
  GameDate? _pinnedDate(Map<String, dynamic>? set) {
    if (set == null) return null;
    final conditions = set['conditions'];
    if (conditions is List) {
      for (final c in conditions) {
        if (c is Map<String, dynamic> && c['targetType'] == 'date') {
          final date = GameDate.tryParse(c['target'] as String?);
          if (date != null) return date;
        }
      }
    }
    for (final side in ['left', 'right']) {
      final branch = set[side];
      if (branch is Map<String, dynamic>) {
        final found = _pinnedDate(branch);
        if (found != null) return found;
      }
    }
    return null;
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

    if (state.date.compareTo(pack.manifest.endDate) >= 0) {
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
    final event = events.pick(state);
    if (event == null) return null;
    final run = events.begin(event, state);
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
    final item = pack.items[itemId];
    if (item == null || state.itemCount(itemId) <= 0) return false;
    if (!item.isConsumable) return false;
    effects.applyItem(item, state);
    state.itemUseCounts[itemId] = (state.itemUseCounts[itemId] ?? 0) + 1;
    state.removeItem(itemId);
    state.note('Used ${item.name}.', 'effect');
    return true;
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
