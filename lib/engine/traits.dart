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

import 'dart:developer' as dev;
import 'dart:math';

import 'game_date.dart';
import 'pack_mechanics.dart';
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
        dev.log('Unsupported trait condition $what; effect withheld.');
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
    // Pack-owned surcharges for traits that ship no effectList (Sunstroke
    // "Stamina Cost +5"). Optional `actionType` narrows one to a block kind.
    for (final a in abilities(state, 'hpCost')) {
      final want = a.data['actionType'];
      if (want is String && want != actionType) continue;
      if (!_roll(state, a)) continue;
      total += a.data['value'] as num;
    }
    return total;
  }

  /// A fixed Store price that replaces the listed one when it is at most
  /// `maxPrice` ("Scrooge: items of 3000 Gold or below cost 100 Gold").
  /// Null when no held ability applies; the lowest applicable price wins.
  num? priceOverride(GameState state, num listed) {
    num? best;
    for (final a in abilities(state, 'priceOverride')) {
      if (listed > (a.data['maxPrice'] as num)) continue;
      if (!_roll(state, a)) continue;
      final price = a.data['price'] as num;
      if (best == null || price < best) best = price;
    }
    return best;
  }

  /// The name of a held ability that forbids using [item] (Lactose
  /// Intolerant: milk-tagged food), or null when it may be used.
  String? itemUseBlockedBy(GameState state, GameItem item) {
    for (final a in abilities(state, 'blockItemUse')) {
      if (item.detailTypes.contains(a.data['itemTag'])) return a.name;
    }
    return null;
  }

  /// The ability that turns away the next negative trait (Salt and Light),
  /// if one is held.
  PackAbility? negativeTraitGuard(GameState state) {
    for (final a in abilities(state, 'blockNegativeTrait')) {
      if (_roll(state, a)) return a;
    }
    return null;
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
  /// "effect begins the week after obtaining" (Korean: goals that appear
  /// from now on). That delay comes from `Goals.issue` reading this factor
  /// once, when a goal is posted: a trait gained mid-week cannot change the
  /// goal already on the board, and the next Monday's goal includes it.
  num goalRewardFactor(GameState state) =>
      _factor(state, 'goalReward', 'percentPlusReward', TraitContext.none);

  /// Behavior providers are pack-owned; catalog IDs never imply an ability.
  Iterable<PackAbility> abilities(GameState state, String type) sync* {
    if (!enabled) return;
    for (final trait in active(state)) {
      final list =
          pack.mechanics.section('traitAbilities')['${trait.id}'] as List? ??
          const [];
      for (var i = 0; i < list.length; i++) {
        final data = (list[i] as Map).cast<String, dynamic>();
        if (data['type'] == type &&
            MechanicRuntime(state).condition(data['when'])) {
          yield PackAbility(trait.id, i, trait.name, data);
        }
      }
    }
    final id = state.characterId;
    final list =
        pack.mechanics.section('characterAbilities')['$id'] as List? ??
        const [];
    if (id != null && pack.characters.containsKey(id)) {
      for (var i = 0; i < list.length; i++) {
        final data = (list[i] as Map).cast<String, dynamic>();
        if (data['type'] == type &&
            MechanicRuntime(state).condition(data['when'])) {
          yield PackAbility(-id, i, pack.characters[id]!.name, data);
        }
      }
    }
  }

  bool holds(GameState state, int id) => active(state).any((t) => t.id == id);
  bool _roll(GameState state, PackAbility a) {
    final chance =
        pack.rules.numberMap('traits', 'chances')['${a.source}'] ??
        (a.data['chance'] as num? ?? 1);
    final tick = a.data['period'] == 'day'
        ? GameDate(state.date.day, 0).asInt
        : state.date.asInt;
    return Random(tick * 31 + a.source * 101 + a.index * 7).nextDouble() <
        chance.clamp(0, 1);
  }

  bool abilityRoll(GameState state, PackAbility ability) =>
      _roll(state, ability);

  bool staminaFree(GameState state) =>
      abilities(state, 'staminaFree').any((a) => _roll(state, a));
  bool survivesExhaustion(GameState state) =>
      abilities(state, 'surviveExhaustion').any((a) => _roll(state, a));
  num _abilityFactor(GameState state, String type, GameItem? item) {
    num result = 1;
    for (final a in abilities(state, type)) {
      if (!_roll(state, a)) continue;
      final tag = a.data['itemTag'];
      if (tag != null && (item == null || !item.detailTypes.contains(tag))) {
        continue;
      }
      final fallback = a.data['factor'] as num? ?? 1;
      result *= a.data['factorRule'] is String
          ? pack.rules.number(
              'traits',
              a.data['factorRule'] as String,
              fallback,
            )
          : fallback;
    }
    return result;
  }

  num priceFactor(GameState state, GameItem? item) =>
      _abilityFactor(state, 'priceFactor', item);
  num itemHpFactor(GameState state, GameItem item) =>
      _abilityFactor(state, 'itemHpFactor', item);
  void applyMovement(GameState state) {
    final tick = state.date.asInt;
    final legacy = state.walkRolledAt == tick && state.abilityUses.isEmpty;
    for (final a in abilities(state, 'moveHp')) {
      final key = '${a.source}:${a.index}:moveHp';
      if (a.data['oncePerTick'] != false &&
          (legacy || state.abilityUses[key] == tick)) {
        continue;
      }
      state.abilityUses[key] = tick;
      if (_roll(state, a)) {
        state.addHp(a.data['value'] as num? ?? 0);
      }
    }
    state.walkRolledAt = tick; // Old saves retain their movement-proc guard.
  }

  List<StudyBonus> studyBonuses(GameState state) {
    final subjects = pack.manifest.subjects;
    if (subjects.isEmpty) return const [];
    return [
      for (final a in abilities(state, 'studyRandomStat'))
        if (_roll(state, a))
          StudyBonus(
            subjects[Random(
              state.date.asInt * 31 + a.source * 101 + a.index * 7,
            ).nextInt(subjects.length)],
            (a.data['value'] as num? ?? 0).round(),
            a.name,
          ),
    ];
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
        return subject == null ||
            pack.manifest.subjects.skip(3).take(2).contains(subject);
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

class PackAbility {
  final int source, index;
  final String name;
  final Map<String, dynamic> data;
  PackAbility(this.source, this.index, this.name, this.data);
}

class StudyBonus {
  final String subject, source;
  final int value;
  const StudyBonus(this.subject, this.value, this.source);
}
