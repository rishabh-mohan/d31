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
import 'pack_mechanics.dart';
import 'traits.dart';
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
  int _callbackCalls = 0;

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

  /// Item interfaces a used item asked to open (`ui` effects: predicted
  /// grades, abilities, recipes). The UI drains these with [reports].
  final List<Map<String, dynamic>> views = [];

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
    final exerciseBefore = state.exerciseLevel.level;
    final workBefore = state.partTimeLevel.level;
    _callbackCalls = 0;
    try {
      _dispatch(code, (changer['args'] as List?) ?? const [], state, 0);
    } on FormatException catch (error) {
      unknownFuncCodes.add('$code: ${error.message}');
    }
    _recordLevelChanges(state, exerciseBefore, workBefore);
  }

  void _dispatch(String code, List<dynamic> args, GameState state, int depth) {
    if (depth > 16 || ++_callbackCalls > 1000) {
      throw const FormatException('Callback recursion/operation limit');
    }
    final steps = state.pack.mechanics.section('callbacks')[code];
    void call(String name, List<dynamic> values) =>
        _dispatch(name, values, state, depth + 1);
    if (steps is List) {
      MechanicRuntime(
        state,
        args,
      ).execute(steps, call: call, pulse: pulsedSwitches.add);
    } else {
      final handler = handlers[code];
      if (handler == null) {
        unknownFuncCodes.add(code);
        return;
      }
      handler(state, args, this);
    }
    final traits = TraitEngine(pack: state.pack);
    for (final ability in traits.abilities(state, 'callback')) {
      if (ability.data['callback'] == code &&
          traits.abilityRoll(state, ability)) {
        MechanicRuntime(state, args).execute(
          ability.data['steps'] as List? ?? const [],
          call: call,
          pulse: pulsedSwitches.add,
        );
      }
    }
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
    if (!state.itemConditionsHold(e)) return;

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
        // A pack-authored, read-only expression (the Scouter's forecast).
        // It must not draw: previews and checks never consume rolls.
        if (e['text'] != null) {
          final text = '${MechanicRuntime(state).value(e['text']) ?? ''}';
          if (text.isNotEmpty) reports.add(text);
        } else if (name != null) {
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
      case 'ui':
        views.add(e);
      // Passive modifiers: read via passiveSum while the item is held.
      // `preventEvent` items are read by the imported event graphs, which
      // branch on FUNC_ITEM_COUNT for the item (the effect's `events` list
      // names them); there is nothing to apply here.
      case 'studyEfficiency':
      case 'exerciseEfficiency':
      case 'partTimeEarnings':
      case 'sleepEfficiency':
      case 'hpCost':
      case 'goalReward':
      case 'acceptanceRate':
      case 'surviveExhaustion':
      case 'preventEvent':
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

  /// The elective (tamgoo) subjects: positions 3 and 4 of the pack's list.
  static Iterable<String> _tamgoos(GameState s) =>
      s.pack.manifest.subjects.skip(3).take(2);

  static final Map<String, ChangerHandler> defaultHandlers = {
    // The host owns the loss-of-day sequence, after this global dialogue.
    // Do not charge the stat penalty or roll the date a second time here.
    'DEFAULT_FAIL_EVENT': (s, a, e) {},
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
    // Tamgoo is the two elective slots, positions 3 and 4 (CLAUDE.md §1),
    // which story 16 fills with science and society -- never the core three.
    'DECREASE_TAMGOO_STAT': (s, a, e) {
      for (final subject in _tamgoos(s)) {
        s.addStat(subject, -_num(a, 0));
      }
    },
    'INCREASE_TAMGOO_STAT': (s, a, e) {
      for (final subject in _tamgoos(s)) {
        s.addStat(subject, _num(a, 0));
      }
    },
    // The higher of the two electives; the first on a tie.
    'DECREASE_TAMGOO_HIGH_STAT': (s, a, e) {
      String? high;
      for (final subject in _tamgoos(s)) {
        if (high == null || (s.stats[subject] ?? 0) > (s.stats[high] ?? 0)) {
          high = subject;
        }
      }
      if (high != null) s.addStat(high, -_num(a, 0));
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
    'ENABLE_BLOCK': (s, a, e) =>
        MechanicRuntime(s).setBlock(a.isEmpty ? '' : a[0], true),
    'DISABLE_BLOCK': (s, a, e) =>
        MechanicRuntime(s).setBlock(a.isEmpty ? '' : a[0], false),

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
      s.taskDeadlines[id] = GameDate(GameDate.addDays(s.date.day, days), tick);
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
      if (s.pack.examEnabled && s.csat == null) {
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
