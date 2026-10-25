/// The effect registry: everything that can change the run.
///
/// Two vocabularies meet here.
///
/// 1. `changer` blocks on nodes and location actions, as KSS authors them:
///      { "funcCode": "INCREASE_STAT", "args": [1, 150],
///        "changes": [ {"type":"set"|"add", "target":"SWITCH", "value":n} ] }
///    `changes` always runs (it is the switch bookkeeping); `funcCode` is the
///    gameplay verb.
///
/// 2. Item `effects`, which this project recovered from `effectText` because
///    the original keeps them compiled. Shapes are in docs/PACK-FORMAT.md.
///
/// Both are open registries: add a handler, and packs can use the verb.
library;

import 'dart:math';

import 'conditions.dart';
import 'pack.dart';
import 'state.dart';
import 'game_date.dart';

typedef ChangerHandler = void Function(
  GameState state,
  List<dynamic> args,
  EffectEngine engine,
);

class EffectEngine {
  final ConditionEvaluator conditions;
  final Map<String, ChangerHandler> handlers;

  /// funcCodes a pack used that this engine has no handler for. The dev panel
  /// lists these: an unimplemented verb silently doing nothing is exactly the
  /// bug that is hardest to notice.
  final Set<String> unknownFuncCodes = {};

  /// Set when an effect ends the run, so the caller can stop the loop.
  bool endRequested = false;
  String? endLabel;
  int? endCode;

  /// Set by MOVE_LOCATION so the loop can follow.
  int? moveToLocation;

  /// Switches a block raised only for this action's event check. The native
  /// writes 1, checks events, and writes 0 again (doGather, doMakeFood,
  /// doSingKing); Game clears these once the action's event has been picked.
  /// Deliberately not cleared by [resetTransient], which starting an event
  /// calls.
  final Set<String> pulsedSwitches = {};

  /// Messages an item asked to show the player, such as the Promotion Exam
  /// Kit's reading. The UI drains these after using an item.
  final List<String> reports = [];

  EffectEngine({
    ConditionEvaluator? conditions,
    Map<String, ChangerHandler>? extra,
  }) : conditions = conditions ?? ConditionEvaluator(),
       handlers = {...defaultHandlers, ...?extra};

  void resetTransient() {
    endRequested = false;
    endLabel = null;
    endCode = null;
    moveToLocation = null;
  }

  /// Applies one `changer` block.
  void applyChanger(Map<String, dynamic>? changer, GameState state) {
    if (changer == null) return;

    for (final raw in (changer['changes'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final gate = (raw['conditionSet'] as Map?)?.cast<String, dynamic>();
      if (!conditions.evaluate(gate, state)) continue;
      final target = raw['target'] as String?;
      if (target == null) continue;
      final value = (raw['value'] as num?)?.toInt() ?? 0;
      if (raw['type'] == 'add') {
        state.addSwitch(target, value);
      } else {
        state.setSwitch(target, value);
      }
    }

    final code = changer['funcCode'] as String?;
    if (code == null) return;
    final handler = handlers[code];
    if (handler == null) {
      unknownFuncCodes.add(code);
      return;
    }
    final exerciseBefore = state.exerciseLevel.level;
    final workBefore = state.partTimeLevel.level;
    handler(state, (changer['args'] as List?) ?? const [], this);
    _recordLevelChanges(state, exerciseBefore, workBefore);
  }

  /// Applies one item's `effects` list. Consumables apply on use; normal
  /// items are passive and read through `GameState.passiveSum` instead, so
  /// only `trigger`-less consumable effects run here.
  void applyItem(GameItem item, GameState state) {
    for (final e in item.effects) {
      if (e['trigger'] != null) continue;
      applyItemEffect(e, state);
    }
  }

  void applyItemEffect(Map<String, dynamic> e, GameState state) {
    final conds = e['conditions'];
    if (conds is List && conds.isNotEmpty) {
      for (final c in conds.whereType<Map>()) {
        if (!_simpleCondition(c.cast<String, dynamic>(), state)) return;
      }
    }

    num amount(String key) {
      final range = e['range'];
      if (range is List && range.length == 2) {
        final lo = (range[0] as num?) ?? 0;
        final hi = (range[1] as num?) ?? lo;
        if (hi <= lo) return lo;
        return lo + state.random.nextInt((hi - lo).toInt() + 1);
      }
      final v = e[key];
      return v is num ? v : 0;
    }

    final exerciseBefore = state.exerciseLevel.level;
    final workBefore = state.partTimeLevel.level;
    switch (e['type'] as String?) {
      case 'stat':
        state.addStat(e['subject'] as String? ?? 'all', amount('value'));
      case 'hp':
        state.addHp(amount('value'));
      case 'hpMultiply':
        state.hp = min(state.hpMax, state.hp * ((e['factor'] as num?) ?? 1));
      case 'hpSet':
        state.hp = amount('value').clamp(state.pack.rules.hpMin, state.hpMax);
      case 'money':
        state.addMoney(amount('value'));
      case 'exerciseExp':
        state.exerciseExp += amount('value');
      case 'partTimeExp':
        state.partTimeExp += amount('value');
      case 'readCount':
        final subject = e['subject'] as String?;
        for (final b in state.pack.books.values) {
          if (subject == null || subject == 'all' || b.subject == subject) {
            state.bookReadCounts[b.id] =
                (state.bookReadCounts[b.id] ?? 0) + amount('value').toInt();
          }
        }
      case 'acquireItem':
        final id = (e['itemId'] as num?)?.toInt();
        if (id != null) state.addItem(id, ((e['count'] as num?) ?? 1).toInt());
      case 'acquireItemRandom':
        final pool = state.pack.items.values
            .where((i) => i.isConsumable)
            .toList();
        if (pool.isNotEmpty) {
          for (var n = 0; n < ((e['count'] as num?) ?? 1).toInt(); n++) {
            state.addItem(pool[state.random.nextInt(pool.length)].id);
          }
        }
      case 'unlockLocation':
        final id = (e['locationId'] as num?)?.toInt();
        if (id != null) state.unlockedLocations.add(id);
      case 'switchAdd':
        final name = e['switch'] as String?;
        if (name != null) state.addSwitch(name, amount('value').toInt());
      case 'report':
        final name = e['switch'] as String?;
        if (name != null) {
          reports.add(
            '${e['label'] ?? name}: ${state.switchValue(name)}'
            '${e['suffix'] ?? ''}',
          );
        }
      case 'removeTraits':
        final kind = e['traitType'] as String? ?? 'bad';
        for (final id in state.traits.toList()) {
          if (state.pack.traits[id]?.type == kind) state.removeTrait(id);
        }
      case 'cureTrait':
        final label = (e['trait'] as String? ?? '').toLowerCase();
        for (final id in state.traits.toList()) {
          if ((state.pack.traits[id]?.name ?? '').toLowerCase() == label) {
            state.removeTrait(id);
          }
        }
      // Passive modifiers: read via passiveSum while the item is held.
      case 'studyEfficiency':
      case 'exerciseEfficiency':
      case 'partTimeEarnings':
      case 'sleepEfficiency':
      case 'hpCost':
      case 'goalReward':
      case 'acceptanceRate':
      case 'surviveExhaustion':
      case 'preventEvent':
      case 'ui':
        break;
      default:
        break;
    }
    _recordLevelChanges(state, exerciseBefore, workBefore);
  }

  void _recordLevelChanges(
    GameState state,
    int exerciseBefore,
    int workBefore,
  ) {
    if (state.exerciseLevel.level > exerciseBefore) {
      state.setSwitch('EXERCISE_LEVEL_UP', 1);
    }
    if (state.partTimeLevel.level > workBefore) {
      state.setSwitch('PART_TIME_JOB_LEVEL_UP', 1);
    }
  }

  bool _simpleCondition(Map<String, dynamic> c, GameState state) {
    final target = c['target'] as String?;
    if (target == null) return true;
    num? actual;
    switch (target) {
      case 'EXERCISE_LEVEL':
        actual = state.exerciseLevel.level;
      case 'PART_TIME_JOB_LEVEL':
        actual = state.partTimeLevel.level;
      case 'STUDY_LEVEL':
        actual = state.studyLevel.level;
      case 'LOCATION_ID':
        actual = state.locationId;
      case 'TICK':
        actual = state.date.tick;
      case 'DATE_INT':
        actual = state.date.asInt;
      default:
        return true; // unknown gate: do not block the effect
    }
    final want = (c['intValue'] as num?) ?? (c['value'] as num?) ?? 0;
    return ConditionEvaluator.compare(
      actual,
      c['compareType'] as String?,
      want,
    );
  }

  // -------------------------------------------------------------------------
  // funcCode handlers -- every verb story 16 uses.
  // -------------------------------------------------------------------------

  static int? _int(List a, int i) {
    if (i >= a.length) return null;
    final v = a[i];
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static num _num(List a, int i, [num fallback = 0]) {
    if (i >= a.length) return fallback;
    final v = a[i];
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? fallback;
  }

  static String? _str(List a, int i) => i < a.length ? a[i]?.toString() : null;

  /// KSS addresses subjects by index. Resolve against the pack's own list so
  /// a pack with different subjects still works.
  static String _subjectAt(GameState s, int index) {
    final subs = s.pack.manifest.subjects;
    if (subs.isEmpty) return 'korean';
    return subs[index.clamp(0, subs.length - 1)];
  }

  /// Advances one of the special side tracks: [counter] is the switch its
  /// storyline reads. The step comes from `rules.specialTracks.stepPerSession`
  /// (1, as the native) so it can be retuned.
  static void _advanceTrack(GameState s, String counter) {
    final step = s.pack.rules
        .number('specialTracks', 'stepPerSession', 1)
        .toInt();
    s.addSwitch(counter, step);
  }

  static void _pulse(GameState s, EffectEngine e, String name) {
    s.setSwitch(name, 1);
    e.pulsedSwitches.add(name);
  }

  static final Map<String, ChangerHandler> defaultHandlers = {
    // The host owns the loss-of-day sequence, after this global dialogue.
    // Do not charge the stat penalty or roll the date a second time here.
    'DEFAULT_FAIL_EVENT': (s, a, e) {},
    // Exercising cures Out of Shape. Trait *effects* stay parked by
    // rules.traits.enabled, but the trait and the switch its global event
    // (10010003, gated on TRAIT_EVENT_7 == 1) waits on are cleared here, so
    // the event cannot fire again off a stale switch.
    'REMOVE_TRAIT_FROM_EXERCISE': (s, a, e) {
      s.switches[GameState.outOfShapeSwitch] = 0;
      s.removeTrait(GameState.outOfShapeTraitId);
    },
    // --- stats ---
    'INCREASE_STAT': (s, a, e) =>
        s.addStat(_subjectAt(s, _int(a, 0) ?? 0), _num(a, 1)),
    'DECREASE_STAT': (s, a, e) =>
        s.addStat(_subjectAt(s, _int(a, 0) ?? 0), -_num(a, 1)),
    'INCREASE_STAT_ALL': (s, a, e) => s.addStat('all', _num(a, 0)),
    'DECREASE_STAT_ALL': (s, a, e) => s.addStat('all', -_num(a, 0)),
    'INCREASE_RANDOM_STAT': (s, a, e) => s.addStat('random', _num(a, 0)),
    'INCREASE_LOW_STAT': (s, a, e) {
      final i = ConditionEvaluator.defaultFuncs['FUNC_GET_LOW_STAT']!(
        s,
        const [],
      );
      s.addStat(_subjectAt(s, i.toInt()), _num(a, 0));
    },
    'DECREASE_TAMGOO_STAT': (s, a, e) => s.addStat('all', -_num(a, 0)),
    'INCREASE_TAMGOO_STAT': (s, a, e) => s.addStat('all', _num(a, 0)),
    'DECREASE_TAMGOO_HIGH_STAT': (s, a, e) {
      final i = ConditionEvaluator.defaultFuncs['FUNC_GET_HIGH_STAT']!(
        s,
        const [],
      );
      s.addStat(_subjectAt(s, i.toInt()), -_num(a, 0));
    },
    'SET_RANDOM_SUBJECT': (s, a, e) =>
        s.randomSubject = s.randomOf(s.pack.manifest.subjects),

    // --- hp / money ---
    'INCREASE_HP': (s, a, e) => s.addHp(_num(a, 0)),
    'DECREASE_HP': (s, a, e) => s.addHp(-_num(a, 0)),
    'INCREASE_MONEY': (s, a, e) => s.addMoney(_num(a, 0)),
    'DECREASE_MONEY': (s, a, e) => s.addMoney(-_num(a, 0)),

    // --- exp ---
    'INCREASE_EXERCISE_EXP': (s, a, e) => s.exerciseExp += _num(a, 0),
    'INCREASE_PART_TIME_JOB_EXP': (s, a, e) => s.partTimeExp += _num(a, 0),

    // --- items ---
    'ACQUIRE_ITEM': (s, a, e) {
      final id = _int(a, 0);
      // KSS also passes symbolic ids ("STOLEN_ITEM") that resolve against a
      // story table the pack does not carry; those are skipped, and the
      // engine records it rather than inventing an item.
      if (id == null) {
        e.unknownFuncCodes.add('ACQUIRE_ITEM(${_str(a, 0)})');
        return;
      }
      s.addItem(id, _int(a, 1) ?? 1);
    },
    'ACQUIRE_ITEM_RANDOM': (s, a, e) {
      final pool = a.whereType<num>().map((n) => n.toInt()).toList();
      if (pool.isEmpty) return;
      s.addItem(pool[s.random.nextInt(pool.length)]);
    },
    'REMOVE_ITEM': (s, a, e) {
      final id = _int(a, 0);
      if (id != null) s.removeItem(id, _int(a, 1) ?? 1);
    },
    'REMOVE_ITEM_LIST': (s, a, e) {
      for (final n in a.whereType<num>()) {
        s.removeItem(n.toInt());
      }
    },
    'REMOVE_ITEM_RANDOM': (s, a, e) {
      if (s.inventory.isEmpty) return;
      final ids = s.inventory.keys.toList();
      s.removeItem(ids[s.random.nextInt(ids.length)]);
    },

    // --- traits ---
    'ACQUIRE_TRAIT': (s, a, e) {
      final id = _int(a, 0);
      // grantTrait starts a temporary trait's clock and refuses traits
      // belonging to another story.
      if (id != null && s.grantTrait(id)) {
        final trait = s.pack.traits[id];
        if (trait != null) s.note('Gained trait: ${trait.name}.', 'effect');
      }
    },
    // One trait from the list that the player does not hold yet (Hyunho's
    // robots, the Gifted draws).
    'ACQUIRE_TRAIT_RANDOM': (s, a, e) {
      final pool = a
          .whereType<num>()
          .map((n) => n.toInt())
          .where((id) => !s.traits.contains(id) && s.pack.traits[id] != null)
          .toList();
      if (pool.isEmpty) return;
      final id = pool[s.random.nextInt(pool.length)];
      if (s.grantTrait(id)) {
        s.note('Gained trait: ${s.pack.traits[id]!.name}.', 'effect');
      }
    },
    'REMOVE_TRAIT': (s, a, e) {
      final id = _int(a, 0);
      if (id != null) s.removeTrait(id);
    },
    'REMOVE_BAD_TRAIT_RANDOM': (s, a, e) {
      final bad = s.traits
          .where((id) => s.pack.traits[id]?.type == 'bad')
          .toList();
      if (bad.isNotEmpty) s.removeTrait(bad[s.random.nextInt(bad.length)]);
    },

    // --- locations ---
    'UNLOCK_LOCATION': (s, a, e) {
      final id = _int(a, 0);
      if (id != null) s.unlockedLocations.add(id);
    },
    'UNLOCK_LOCATION_ALL': (s, a, e) =>
        s.unlockedLocations.addAll(s.pack.locations.keys),
    'LOCK_LOCATION': (s, a, e) {
      final id = _int(a, 0);
      if (id != null) s.unlockedLocations.remove(id);
    },
    'LOCK_LOCATION_EXCEPT': (s, a, e) {
      final keep = a.whereType<num>().map((n) => n.toInt()).toSet();
      s.unlockedLocations.removeWhere((id) => !keep.contains(id));
    },
    'MOVE_LOCATION': (s, a, e) {
      final id = _int(a, 0);
      if (id != null) {
        s.locationId = id;
        s.unlockedLocations.add(id);
        e.moveToLocation = id;
      }
    },
    'LOCK_MOVE_LOCATION': (s, a, e) => s.movementLocked = true,
    'UNLOCK_MOVE_LOCATION': (s, a, e) => s.movementLocked = false,
    'START_LOCATION_COUNT': (s, a, e) {},

    // --- switches ---
    'SET_RANDOM_SWITCH': (s, a, e) {
      final name = _str(a, 0);
      if (name == null) return;
      final lo = _num(a, 1).toInt();
      final hi = _num(a, 2, lo.toDouble()).toInt();
      s.setSwitch(name, hi <= lo ? lo : lo + s.random.nextInt(hi - lo + 1));
    },
    'SET_RANDOM_SWITCH_3': (s, a, e) {
      final name = _str(a, 0);
      if (name == null) return;
      final lo = _num(a, 1).toInt();
      final hi = _num(a, 2, lo.toDouble()).toInt();
      s.setSwitch(name, hi <= lo ? lo : lo + s.random.nextInt(hi - lo + 1));
    },
    'SET_VALUE_TARGET': (s, a, e) {
      // ["BANBAN2", "+=", "TAMGOO2_STAT"] -- switch, operator, source switch.
      final dest = _str(a, 0);
      final op = _str(a, 1) ?? '=';
      final srcName = _str(a, 2);
      if (dest == null || srcName == null) return;
      final src = s.switchValue(srcName);
      switch (op) {
        case '+=':
          s.addSwitch(dest, src);
        case '-=':
          s.addSwitch(dest, -src);
        case '=':
          s.setSwitch(dest, src);
      }
    },
    'SET_DRAW_VALUE': (s, a, e) => s.drawValue = s.random.nextInt(100),
    'ADD_CHALLENGE_VALUE': (s, a, e) {
      final name = _str(a, 0);
      if (name != null) s.addSwitch(name, _num(a, 1).toInt());
    },
    'ADD_BLOCK': (s, a, e) {},

    // --- authored task deadlines ---
    'ADD_TODO': (s, a, e) {
      if (!s.pack.rules.flag('tasks', 'enabled', false)) return;
      final id = _int(a, 0);
      final raw = _str(a, 2);
      if (id == null || raw == null) return;
      final parts = raw.split('.');
      final due =
          GameDate.tryParse(raw) ??
          (parts.length == 4
              ? GameDate.tryParse(
                  'DATE_${parts[0]}${parts[1].padLeft(2, '0')}${parts[2].padLeft(2, '0')}${parts[3].padLeft(2, '0')}',
                )
              : null);
      if (due == null) {
        e.unknownFuncCodes.add('ADD_TODO(invalid date)');
        return;
      }
      s.taskDeadlines[id] = due;
      s.taskTitles[id] = (_str(a, 1) ?? '').replaceAll('_', ' ');
    },
    'ADD_TODO_2': (s, a, e) {
      if (!s.pack.rules.flag('tasks', 'enabled', false)) return;
      final id = _int(a, 0);
      final days = _int(a, 2);
      // Story 16 often names only the day ([7, "Date_with_Customer", 7]).
      final tick = _int(a, 3) ?? 0;
      if (id == null || days == null) return;
      s.taskDeadlines[id] = GameDate(
        GameDate.addDays(s.date.day, days),
        tick,
      );
      s.taskTitles[id] = (_str(a, 1) ?? '').replaceAll('_', ' ');
    },
    'REMOVE_TODO': (s, a, e) {
      final id = _int(a, 0);
      s.taskDeadlines.remove(id);
      s.taskTitles.remove(id);
    },

    // --- run control ---
    'END_GAME': (s, a, e) {
      e.endRequested = true;
      e.endCode = _int(a, 0);
      e.endLabel = _str(a, 1);
    },
    // The Graduation Exam's last line. The host sits the CSAT and takes the
    // applications once the scene closes; see Game.takeCsat.
    'START_SAT': (s, a, e) {
      if (s.pack.rules.flag('exam', 'enabled', false) && s.csat == null) {
        s.csatPending = true;
      }
    },
    'SHOW_ENDING': (s, a, e) {
      // Native sub_be91d0 presents an ending, then raises its second argument
      // as a continuation switch. The opening's START does not end the run.
      final continuation = _str(a, 1);
      if (continuation == null || continuation.isEmpty) {
        e.unknownFuncCodes.add('SHOW_ENDING(without continuation)');
        return;
      }
      s.setSwitch(continuation, 1);
      s.note('Ending: ${_str(a, 0) ?? ''}', 'event');
    },
    'SET_DOK_BANG': (s, a, e) {
      final rules = s.pack.rules.section('reflectionRoom');
      final room = (rules['locationId'] as num?)?.toInt();
      if (room == null) {
        e.unknownFuncCodes.add('SET_DOK_BANG(missing rules)');
        return;
      }
      final ordinary = (rules['ordinaryLocationIds'] as List? ?? const [])
          .whereType<num>()
          .map((id) => id.toInt());
      final confined = _int(a, 0) == 1;
      s.setSwitch('DOK_BANG_ON', confined ? 1 : 0);
      if (confined) {
        s.unlockedLocations.removeAll(ordinary);
        s.unlockedLocations.add(room);
        s.locationId = room;
        e.moveToLocation = room;
      } else {
        s.unlockedLocations.remove(room);
        s.unlockedLocations.addAll(ordinary);
        s.locationId =
            (rules['exitLocationId'] as num?)?.toInt() ??
            s.pack.manifest.startLocationId;
        e.moveToLocation = s.locationId;
      }
      s.movementLocked = confined;
    },

    // --- the special location tracks -------------------------------------
    //
    // Each practice block adds one to the counter its storyline reads: the
    // native handlers (idolAction, proGameAction, soccerAction,
    // medicalAction, mechanicAction, practicePsychic) are a single `+ 1`.
    // Story 16's idol beats fire at IDOL 10/25/50, soccer at SOCCER
    // 10/30/50, the pro-gaming results branch on GAME 10/50/100; Ihyeon's
    // potion levels need MEDICAL_COUNT 10, Hyunho's robots ROBOT_COUNT 10.
    // The step stays tunable under `rules.specialTracks`.
    'IDOL_ACTION': (s, a, e) => _advanceTrack(s, 'IDOL'),
    'PRO_GAME_ACTION': (s, a, e) => _advanceTrack(s, 'GAME'),
    'SOCCER_ACTION': (s, a, e) => _advanceTrack(s, 'SOCCER'),
    'MEDICAL_ACTION': (s, a, e) => _advanceTrack(s, 'MEDICAL_COUNT'),
    'MECHANIC_ACTION': (s, a, e) => _advanceTrack(s, 'ROBOT_COUNT'),
    'PRACTICE_PSYCHIC': (s, a, e) =>
        _advanceTrack(s, 'PSYCHIC_PRACTICE_COUNT'),

    // --- Retry Year's compiled callbacks ----------------------------------
    //
    // Each is the disassembled body from the Korean native, not a guess.
    // Addresses are recorded in docs/RETRY-YEAR.md.

    // sub_bdc1b0 / sub_bdc264 / sub_bdc318: a friend's trouble block raises
    // the switch their story waits on.
    'DO_GO_BANJANG': (s, a, e) => s.setSwitch('NA_BLOCK', 1),
    'DO_GO_LEE': (s, a, e) => s.setSwitch('LEE_BLOCK', 1),
    'DO_GO_PRO': (s, a, e) => s.setSwitch('GO_BLOCK', 1),
    // sub_bdb8dc: each assist counts toward Banjang's three diagnosis beats.
    'DO_HELP_BANJANG': (s, a, e) => s.addSwitch('BANJANG_COUNT', 1),
    // sub_bdc0d0 / sub_bdb9d8 / sub_bdbab8: raise, check events, lower.
    'DO_GATHER': (s, a, e) => _pulse(s, e, 'GRASS_SW'),
    'DO_MAKE_FOOD': (s, a, e) => _pulse(s, e, 'MAKE_FOOD_BLOCK'),
    'DO_SINGKING': (s, a, e) => _pulse(s, e, 'SING_KING_BLOCK'),
    // sub_bdbb98: practice is worth 2 with item 90008 in the bag, else 1.
    // A character whose ability is SING_MONEY (67) is also paid each time;
    // the amount is a remote-config value not in the binary, so
    // rules.karaoke.money stands in for it.
    'DO_KARAOKE': (s, a, e) {
      s.addSwitch('SING_COUNT', s.itemCount(90008) > 0 ? 2 : 1);
      if (s.pack.characters[s.characterId]?.specialFuncCode == 'SING_MONEY') {
        s.addMoney(s.pack.rules.number('karaoke', 'money', 1000));
      }
    },
    // sub_be9578: the next trouble block opens three days after the last
    // target, rolling the month over.
    'SET_NEXT_TARGET_BLOCK_CONDITION': (s, a, e) {
      final month = s.switchValue('BLOCK_TARGET_MONTH');
      final day = s.switchValue('BLOCK_TARGET_DAY');
      if (month <= 0 || day <= 0) return;
      final next = DateTime(s.date.day.year, month, day + 3);
      s.setSwitch('BLOCK_TARGET_MONTH', next.month);
      s.setSwitch('BLOCK_TARGET_DAY', next.day);
    },
    // sub_bea5f8 (0xff1048): the opponent and the practice they demand.
    'SET_SING_TARGET': (s, a, e) {
      final point = s.switchValue('SING_POINT');
      s.setSwitch(
        'SING_TARGET',
        (point * 1.5 + s.random.nextInt(3)).round(),
      );
      s.setSwitch('SING_ENEMY', s.random.nextInt(6) + 1);
    },
    // sub_be9f38: Taeyang's bet. The argument names the mock exam (1-3) and
    // the subject is drawn at random; FUNC_IS_GOLD_WIN settles it.
    'SET_GOLD_SUN_VALUE': (s, a, e) {
      final subjects = s.pack.manifest.subjects;
      if (subjects.isEmpty) return;
      s.setSwitch('GOLD_ORDER', _int(a, 0) ?? 1);
      s.setSwitch('GOLD_SUN_SUBJECT', s.random.nextInt(subjects.length));
    },
    // sub_be973c: moving up to the Higher class closes the Lower class's
    // haunts and sends you to the classroom.
    'SET_HIGH_GOGO': (s, a, e) {
      s.setSwitch('HIGH_GOGO', 1);
      s.unlockedLocations.removeAll(const [2000, 20001, 20002, 20003, 20004]);
      s.locationId = 1000;
      s.unlockedLocations.add(1000);
      e.moveToLocation = 1000;
    },
    // Takes one copy of the first listed item the player holds.
    'REMOVE_ITEM_ONCE': (s, a, e) {
      for (final n in a.whereType<num>()) {
        if (s.itemCount(n.toInt()) > 0) {
          s.removeItem(n.toInt());
          return;
        }
      }
    },

    // A draw/gacha beat: SET_DRAW_VALUE rolls, DO_DRAW commits the roll so
    // FUNC_GOOD_DRAW_VALUE can be compared against it.
    'DO_DRAW': (s, a, e) {
      if (s.drawValue == 0) s.drawValue = s.random.nextInt(100);
    },

    // --- flavour / platform verbs with no simulation meaning ---
    'SIREN': (s, a, e) {},
    'GO_WEB_BROWSER': (s, a, e) {},
    'HACKING_LESSON': (s, a, e) {},
    'ALIVE_ART': (s, a, e) {},
    'SLEEP': (s, a, e) {},
    'PART_TIME_JOB': (s, a, e) {},
    'EXERCISE': (s, a, e) {},
    'STUDY': (s, a, e) {},
  };
}
