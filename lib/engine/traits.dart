/// The trait system: 244 traits whose `effectList` ships as data.
///
/// Traits are the one system KSS gives away — its formulas are compiled, but
/// a trait states what it does in JSON. This file is the reader for that
/// data: which traits are in force, whether an effect's conditions hold right
/// now, and what number it contributes.
///
/// Study efficiency is a flat stat bonus, one point per authored unit.
/// Prefer nonzero `storyStat` over the alternate scaled `extraStat` field.
/// Effects with no story value retain their explicit `extraStat` amount,
/// unless the description writes the `STAT_<n>` placeholder, which marks that
/// `extraStat` as the x3-scaled field (High Potential: `+STAT_5`, extraStat 15).
library;

import 'dart:developer' as developer;
import 'dart:math';

import 'game_date.dart';
import 'pack.dart';
import 'state.dart';

/// What one effect is being weighed against: the block being resolved.
class TraitContext {
  /// The subject a study block is paying into.
  final String? subject;

  /// `study`, `exercise`, `partTimeJob`, `sleep` — the block's own type.
  final String? actionType;

  /// The block's `changer.funcCode`, which three traits key off
  /// (`DO_EXPLORE`, `DO_GATHER`, `DO_KARAOKE`).
  final String? actionFuncCode;

  /// True for a Class block. `schoolStudyPlusStat` applies only here, and one
  /// `plusStat` carries `excludeSchoolStudy` to opt out of it.
  final bool schoolStudy;

  const TraitContext({
    this.subject,
    this.actionType,
    this.actionFuncCode,
    this.schoolStudy = false,
  });

  static const none = TraitContext();
}

class TraitEngine {
  final ContentPack pack;

  TraitEngine({required this.pack});

  /// Every condition target [conditionsHold] reads. The shipped trait,
  /// character and badge catalogs use only these (a test pins it); anything
  /// else fails closed, because an unread gate that passed would hand out a
  /// conditional bonus unconditionally.
  static const supportedConditionTargets = {
    'LOCATION_TYPE',
    'IS_HAVE_ITEM',
    'IS_HAVE_TRAIT',
    'IS_TODAY_IN_DATE_LIST',
    'TICK_RANDOM',
    'LOCATION_ID',
    'TICK',
    'WEEKCODE',
    'DATE_WEEK',
    'DATE_INT',
    'COMBO_STUDY',
    'PREV_STUDY_SUBJECT',
    'IS_BEFORE_SAT_EXAM',
    'EXERCISE_LEVEL',
    'PART_TIME_JOB_LEVEL',
    'STUDY_LEVEL',
  };

  /// Gates this engine met and could not read, as `target` or
  /// `target/compareType`. Each one held its effect back.
  final Set<String> unknownConditions = {};

  bool _unsupported(String what) {
    if (unknownConditions.add(what)) {
      assert(() {
        developer.log('Unsupported trait condition $what; effect withheld.');
        return true;
      }());
    }
    return false;
  }

  bool get enabled => pack.rules.flag('traits', 'enabled', true);

  /// The traits actually in force: held, in scope for where the player is,
  /// and not expired. A trait belonging to another story never counts — the
  /// catalog is global and carries traits for stories 3, 14, 18 and 20.
  Iterable<GameTrait> active(GameState state) sync* {
    if (!enabled) return;
    yield* state.setupModifiers;
    for (final id in state.traits) {
      final trait = pack.traits[id];
      if (trait == null) continue;
      if (!state.traitInForce(id)) continue;
      if (!_scopeHolds(trait, state)) continue;
      yield trait;
    }
  }

  /// `locationIdList` / `locationType` on the trait record scope the whole
  /// trait to a place. Most traits that use it also repeat it as a condition
  /// on the effect; honouring both costs nothing and matches either spelling.
  bool _scopeHolds(GameTrait trait, GameState state) {
    if (trait.locationIds.isNotEmpty &&
        !trait.locationIds.contains(state.locationId)) {
      return false;
    }
    final type = trait.locationType;
    if (type != null && type.isNotEmpty && state.location?.type != type) {
      return false;
    }
    return true;
  }

  // --- the six places a trait can pay out ----------------------------------

  /// Flat stat added to a study block's payout, in stat points.
  num studyBonus(GameState state, {String? subject, bool schoolStudy = false}) {
    final ctx = TraitContext(
      subject: subject,
      actionType: schoolStudy ? 'lesson' : 'study',
      schoolStudy: schoolStudy,
    );
    num total = 0;
    for (final trait in active(state)) {
      for (var i = 0; i < trait.effects.length; i++) {
        final e = trait.effects[i];
        final type = e['type'];
        if (type == 'schoolStudyPlusStat') {
          if (!schoolStudy) continue;
        } else if (type == 'plusStat') {
          if (schoolStudy && e['excludeSchoolStudy'] == true) continue;
          if (!_subjectMatches(e, state, subject)) continue;
        } else {
          continue;
        }
        if (!conditionsHold(e, state, ctx, rollKey: _key(trait, i))) continue;
        total += statValue(e, description: trait.description);
      }
    }
    return total;
  }

  /// Stamina-cost delta. Negative is a discount, which is what 20 of the 22
  /// `hpCost` effects are.
  num hpCostDelta(
    GameState state, {
    String? actionType,
    String? actionFuncCode,
  }) {
    final ctx = TraitContext(
      actionType: actionType,
      actionFuncCode: actionFuncCode,
    );
    num total = 0;
    for (final trait in active(state)) {
      for (var i = 0; i < trait.effects.length; i++) {
        final e = trait.effects[i];
        if (e['type'] != 'hpCost') continue;
        final wantAction = e['locationActionType'] as String?;
        if (wantAction != null) {
          // `schoolStudy` is the Class block, which this engine calls lesson.
          final want = wantAction == 'schoolStudy' ? 'lesson' : wantAction;
          if (want != actionType) continue;
        }
        final wantFunc = e['actionFuncCode'] as String?;
        if (wantFunc != null && wantFunc != actionFuncCode) continue;
        if (!conditionsHold(e, state, ctx, rollKey: _key(trait, i))) continue;
        total += (e['cost'] as num?) ?? 0;
      }
    }
    return total;
  }

  /// `(flat Gold, multiplier)` for a part-time shift's pay. "Workaholic:
  /// Part-Time earnings +20%" ships as `percentPlusMoney: 1.2`, so the
  /// percent fields are **factors, not percentages** — the descriptions are
  /// what settles it, here and for exercise exp and goal rewards.
  (num, num) partTimeMoney(GameState state) => _flatAndFactor(
    state,
    'partTimeJobMoney',
    'intPlusMoney',
    'percentPlusMoney',
    const TraitContext(actionType: 'partTimeJob'),
  );

  /// `(flat exp, multiplier)` for a workout. "Getting Fitter!: Workout EXP
  /// +20%" is `percentPlusExp: 1.2`; "Six Pack: Exercise Efficiency +5" is
  /// `intPlusExp: 5`.
  (num, num) exerciseExp(GameState state) => _flatAndFactor(
    state,
    'exerciseExp',
    'intPlusExp',
    'percentPlusExp',
    const TraitContext(actionType: 'exercise'),
  );

  (num, num) partTimeExp(GameState state) => _flatAndFactor(
    state,
    'partTimeJobExp',
    'intPlusExp',
    'percentPlusExp',
    const TraitContext(actionType: 'partTimeJob'),
  );

  /// Extra stamina a Sleep block restores.
  num sleepHp(GameState state) => _sum(
    state,
    'plusSleepHp',
    'plusValue',
    const TraitContext(actionType: 'sleep'),
  );

  /// Multiplier on a met Weekly Goal's reward — "MBTI J. Judger: Weekly
  /// Goals rewards +10%" is `percentPlusReward: 1.1`. Its description adds
  /// "effect begins the week after obtaining", which is not modelled.
  num goalRewardFactor(GameState state) =>
      _factor(state, 'goalReward', 'percentPlusReward', TraitContext.none);

  // --- compiled abilities -------------------------------------------------
  //
  // 71 traits ship no `effectList` (`notRefactor: true`): the original keeps
  // their rule in compiled code, so only the description says what they do.
  // These are the ones whose description states a usable rule. Where it
  // names no rate ("random chance", "high chance", "low chance", "cheaper"),
  // the default below is this project's, not a recovered number, and
  // `rules.traits.chances` overrides it by trait id.

  static const timeJumper = 69;
  static const stubborn = 41;
  static const willNotFalter = 51;
  static const solitaryGourmet = 21;
  static const limitedOffer = 34;
  static const developer = 43;
  static const walkingEnthusiast = 77;
  static const multitasker = 49;
  static const energizer = 84;
  static const streetPerformer = 210;

  static const _defaultChances = <int, num>{
    timeJumper: 0.10, // "10% chance of no stamina cost"
    stubborn: 0.30, // "Random chance" -- not stated
    willNotFalter: 0.70, // "High chance" -- not stated
    walkingEnthusiast: 0.50, // "50% chance of +20 Stamina"
    energizer: 0.05, // "Low chance ... for a day" -- not stated
  };

  /// Solitary Gourmet's "Food in the Store are cheaper": price factor on
  /// items tagged `food`. The amount is not stated.
  num get gourmetPriceFactor =>
      pack.rules.number('traits', 'gourmetPriceFactor', 0.8);

  /// Whether trait [id] is held, in force and in scope here -- the same test
  /// an `effectList` effect passes before it pays.
  bool holds(GameState state, int id) => active(state).any((t) => t.id == id);

  num chanceOf(int id) =>
      pack.rules.numberMap('traits', 'chances')['$id'] ??
      _defaultChances[id] ??
      0;

  /// A compiled ability's dice roll, seeded on the tick and the trait like
  /// `TICK_RANDOM`, so a card and the block it resolves see the same roll.
  bool rolls(GameState state, int id, {int salt = 0}) =>
      holds(state, id) &&
      Random(state.date.asInt * 31 + id * 101 + salt).nextDouble() <
          chanceOf(id);

  /// Time Jumper (one tick) or Energizer (the whole day) makes a block free.
  /// Energizer rolls once per day -- the seed drops the tick -- and the proc
  /// resets with the next day's roll.
  bool staminaFree(GameState state) {
    if (rolls(state, timeJumper)) return true;
    if (!holds(state, energizer)) return false;
    final day = GameDate(state.date.day, 0).asInt;
    return Random(day * 31 + energizer * 101).nextDouble() <
        chanceOf(energizer);
  }

  /// Stubborn and I will not falter! each roll their own chance to hold the
  /// player at 1 stamina instead of collapsing.
  bool survivesExhaustion(GameState state) =>
      rolls(state, stubborn) || rolls(state, willNotFalter);

  /// Store price factor: Limited Offer halves everything while its three-day
  /// clock runs; Solitary Gourmet discounts food. Both compound.
  num priceFactor(GameState state, GameItem? item) {
    num factor = 1;
    if (holds(state, limitedOffer)) factor *= 0.5;
    if (item != null &&
        item.detailTypes.contains('food') &&
        holds(state, solitaryGourmet)) {
      factor *= gourmetPriceFactor;
    }
    return factor;
  }

  /// Developer: "X2 Stamina increase with coffee". Coffee is the pack's
  /// `caffeine` tag (Coffee 1); Decaf Coffee is tagged `food` only.
  num itemHpFactor(GameState state, GameItem item) =>
      item.detailTypes.contains('caffeine') && holds(state, developer) ? 2 : 1;

  /// Multitasker: "+STAT_1 for a random subject when studying". The subject
  /// is drawn from the tick's seed, so it is fixed before the block resolves.
  String? multitaskSubject(GameState state) {
    if (!holds(state, multitasker)) return null;
    final subjects = pack.manifest.subjects;
    if (subjects.isEmpty) return null;
    final seed = state.date.asInt * 31 + multitasker * 101;
    return subjects[Random(seed).nextInt(subjects.length)];
  }

  num _sum(GameState state, String type, String key, TraitContext ctx) {
    num total = 0;
    for (final trait in active(state)) {
      for (var i = 0; i < trait.effects.length; i++) {
        final e = trait.effects[i];
        if (e['type'] != type) continue;
        if (!conditionsHold(e, state, ctx, rollKey: _key(trait, i))) continue;
        final v = e[key];
        if (v is num) total += v;
      }
    }
    return total;
  }

  (num, num) _flatAndFactor(
    GameState state,
    String type,
    String flatKey,
    String factorKey,
    TraitContext ctx,
  ) {
    num flat = 0;
    num factor = 1;
    for (final trait in active(state)) {
      for (var i = 0; i < trait.effects.length; i++) {
        final e = trait.effects[i];
        if (e['type'] != type) continue;
        if (!conditionsHold(e, state, ctx, rollKey: _key(trait, i))) continue;
        final f = e[flatKey];
        if (f is num) flat += f;
        final p = e[factorKey];
        // Two such traits compound rather than adding: +20% and +30% is
        // x1.56, which is the only reading a bare factor supports.
        if (p is num && p != 0) factor *= p;
      }
    }
    return (flat, factor);
  }

  num _factor(GameState state, String type, String key, TraitContext ctx) {
    num factor = 1;
    for (final trait in active(state)) {
      for (var i = 0; i < trait.effects.length; i++) {
        final e = trait.effects[i];
        if (e['type'] != type) continue;
        if (!conditionsHold(e, state, ctx, rollKey: _key(trait, i))) continue;
        final v = e[key];
        if (v is num && v != 0) factor *= v;
      }
    }
    return factor;
  }

  // --- reading one effect ---------------------------------------------------

  /// Shared with setup labels so displayed efficiency matches the payout.
  num statValue(Map<String, dynamic> e, {String description = ''}) =>
      studyEfficiencyValue(e, description: description);

  bool _subjectMatches(
    Map<String, dynamic> e,
    GameState state,
    String? subject,
  ) {
    switch (e['plusStatType'] as String?) {
      case 'detail':
        final want = e['subjectType'] as String?;
        return want == null || subject == null || want == subject;
      case 'tamgoos':
        // The two elective slots, which story 16 fills with science and
        // society -- the enum order recovered in CLAUDE.md §1.
        return subject == null || subject == 'science' || subject == 'society';
      case 'lowSubject':
        return subject == null || subject == _lowestSubject(state);
      default: // 'all'
        return true;
    }
  }

  String? _lowestSubject(GameState state) {
    String? low;
    num best = 0;
    for (final s in pack.manifest.subjects) {
      final v = state.stats[s] ?? 0;
      if (low == null || v < best) {
        low = s;
        best = v;
      }
    }
    return low;
  }

  /// An effect's own `conditions`, which 51 of the 137 `plusStat` effects
  /// carry. All are AND-ed: the original has no operator field here.
  bool conditionsHold(
    Map<String, dynamic> e,
    GameState state,
    TraitContext ctx, {
    int rollKey = 0,
  }) {
    for (final raw in (e['conditions'] as List? ?? const [])) {
      if (raw is! Map) continue;
      if (!_conditionHolds(raw.cast<String, dynamic>(), state, ctx, rollKey)) {
        return false;
      }
    }
    return true;
  }

  /// A trait's dice roll must land the same way for the action card and for
  /// resolving the block, or "Monty Hall Problem: 2/3 chance of an extra
  /// +STAT_7" would make the card lie. So `TICK_RANDOM` is a *seeded* roll
  /// on the tick and the effect, not a draw from the run's RNG -- the same
  /// trick `bookForSlot` uses, and the name says per-tick anyway.
  int _key(GameTrait trait, int effectIndex) =>
      trait.id * 101 + effectIndex * 7;

  bool _conditionHolds(
    Map<String, dynamic> c,
    GameState state,
    TraitContext ctx,
    int rollKey,
  ) {
    final target = c['target'] as String?;
    if (target == null) return true;

    // The string-valued and list-valued ones do not go through the numeric
    // comparator at all.
    switch (target) {
      case 'LOCATION_TYPE':
        final want = c['strValue'] as String?;
        return _compareBool(c, state.location?.type == want);
      case 'IS_HAVE_ITEM':
        final id = _firstArgInt(c);
        return _compareBool(c, id != null && state.itemCount(id) > 0);
      case 'IS_HAVE_TRAIT':
        final id = _firstArgInt(c);
        return _compareBool(c, id != null && state.traits.contains(id));
      case 'IS_TODAY_IN_DATE_LIST':
        final codes = (c['args'] as List? ?? const []).whereType<String>();
        final today = state.date.day;
        final hit = codes.any((code) {
          final d = GameDateCodes.dayOf(code);
          return d != null && d.month == today.month && d.day == today.day;
        });
        return _compareBool(c, hit);
      case 'TICK_RANDOM':
        // A dice roll, not a reading: "2/3 chance of an extra +STAT_7".
        final percent = (c['percent'] as num?) ?? 0;
        final roll = Random(state.date.asInt * 31 + rollKey).nextDouble();
        return roll < percent;
    }

    final actual = _numericTarget(target, state, ctx);
    if (actual == null) return _unsupported(target);
    final want = (c['intValue'] as num?) ?? 0;
    final compareType = c['compareType'] as String?;
    switch (compareType) {
      case 'equal':
        return actual == want;
      case 'notEqual':
        return actual != want;
      case 'greater':
        return actual > want;
      case 'greaterEqual':
        return actual >= want;
      case 'less':
        return actual < want;
      case 'lessEqual':
        return actual <= want;
      default:
        return _unsupported('$target/$compareType');
    }
  }

  num? _numericTarget(String target, GameState state, TraitContext ctx) {
    switch (target) {
      case 'LOCATION_ID':
        return state.locationId;
      case 'TICK':
        return state.date.tick;
      case 'WEEKCODE':
      case 'DATE_WEEK':
        return state.date.day.weekday;
      case 'DATE_INT':
        // Traits spell this month*100+day -- "Birthday Effect" is 823, and
        // its description reads "(Aug 23 only)". Nothing else in the pack
        // reads DATE_INT, so the engine switch's yyyymmddtt form never
        // collides with this.
        return state.date.day.month * 100 + state.date.day.day;
      case 'COMBO_STUDY':
        return state.studyCombo;
      case 'PREV_STUDY_SUBJECT':
        // Addressed by position, like every other subject reference.
        final prev = state.lastStudySubject;
        if (prev == null) return -1;
        return pack.manifest.subjects.indexOf(prev);
      case 'IS_BEFORE_SAT_EXAM':
        return state.isDayBeforeExam ? 1 : 0;
      case 'EXERCISE_LEVEL':
        return state.exerciseLevel.level;
      case 'PART_TIME_JOB_LEVEL':
        return state.partTimeLevel.level;
      case 'STUDY_LEVEL':
        return state.studyLevel.level;
      default:
        return null;
    }
  }

  /// `equal 1` means "yes", `equal 0` means "no"; the predicates are written
  /// both ways (Overdresser wants the item, Superiority wants the trait
  /// *absent*).
  bool _compareBool(Map<String, dynamic> c, bool actual) {
    final want = ((c['intValue'] as num?) ?? 1) != 0;
    final negated = (c['compareType'] as String?) == 'notEqual';
    return negated ? actual != want : actual == want;
  }

  int? _firstArgInt(Map<String, dynamic> c) {
    final args = c['args'] as List? ?? const [];
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is num) return first.toInt();
    return int.tryParse(first.toString());
  }
}

/// `DATE_2024101700` -> that day. The trait date lists are written in the
/// same code the calendar uses, but for a different year than the run.
class GameDateCodes {
  static DateTime? dayOf(String code) {
    final digits = code.replaceFirst('DATE_', '');
    if (digits.length < 8) return null;
    final year = int.tryParse(digits.substring(0, 4));
    final month = int.tryParse(digits.substring(4, 6));
    final day = int.tryParse(digits.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}

/// One stat per efficiency unit; never add the two alternative data fields.
///
/// [description] is the owning trait's. Two traits ship storyStat 0 with a
/// scaled extraStat, and only their descriptions tell them apart from the
/// literal ones: High Potential "+STAT_5" is extraStat 15 and Entrepreneur
/// "+STAT_2" is extraStat 6, while Worth the Wait "+3" is extraStat 3. The
/// placeholder is the description's unit, so the scaled field is divided back.
num studyEfficiencyValue(
  Map<String, dynamic> effect, {
  String description = '',
}) {
  final story = (effect['storyStat'] as num?) ?? 0;
  if (story != 0) return story;
  final extra = (effect['extraStat'] as num?) ?? 0;
  if (_statPlaceholder.hasMatch(description)) {
    return extra % 3 == 0 ? extra ~/ 3 : extra / 3;
  }
  return extra;
}

final _statPlaceholder = RegExp(r'STAT_\d');
