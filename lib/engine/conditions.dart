/// The condition evaluator.
///
/// KSS gates everything -- whether an event fires, which branch an `ifElse`
/// node takes, whether a change applies -- through one recursive shape:
///
///   { "operator": "and"|"or",
///     "left":  { ...conditionSet... } | { "conditions": [...] },
///     "right": { ...conditionSet... } | { "conditions": [...] },
///     "conditions": [ {type,target,targetType,compareType,value,args} ] }
///
/// A node with a `conditions` list ANDs them together. `left`/`right` combine
/// with `operator`. Empty sides are vacuously true, which is why the common
/// "one condition" case is written as an empty `left` and a populated `right`.
library;

import 'game_date.dart';
import 'pack_mechanics.dart';
import 'pack.dart';
import 'state.dart';

typedef FuncHandler = num Function(GameState state, List<dynamic> args);

class ConditionEvaluator {
  final Map<String, FuncHandler> funcs;

  ConditionEvaluator({Map<String, FuncHandler>? funcs})
    : funcs = {...defaultFuncs, ...?funcs};

  /// Targets the evaluator did not recognise. Surfaced in the dev panel so a
  /// pack using a verb the engine lacks is visible rather than silently false.
  final Set<String> unknownTargets = {};

  /// Resolve pack predicates before generic built-in functions.
  num? functionValue(String name, GameState state, List<dynamic> args) {
    if (state.pack.mechanics.section('predicates').containsKey(name)) {
      return MechanicRuntime(state, args).number({'predicate': name});
    }
    final handler = funcs[name];
    if (handler == null) {
      unknownTargets.add(name);
      return null;
    }
    return handler(state, args);
  }

  bool evaluate(Map<String, dynamic>? set, GameState state) {
    if (set == null) return true;
    if (set.isNotEmpty &&
        !set.keys.any({'conditions', 'operator', 'left', 'right'}.contains)) {
      try {
        return MechanicRuntime(state).condition(set);
      } on FormatException catch (error) {
        unknownTargets.add('expression: ${error.message}');
        return false;
      }
    }

    final conditions = set['conditions'];
    if (conditions is List) {
      for (final c in conditions) {
        if (c is Map<String, dynamic> && !_single(c, state)) return false;
      }
    }

    final left = set['left'];
    final right = set['right'];
    if (left == null && right == null) return true;

    final leftOk = left is Map<String, dynamic> ? evaluate(left, state) : true;
    final rightOk = right is Map<String, dynamic>
        ? evaluate(right, state)
        : true;

    final op = (set['operator'] as String?)?.toLowerCase() ?? 'and';
    if (op == 'or') {
      // An empty side must not make `or` trivially true: KSS writes the
      // single-condition case as an empty left with `and`, never `or`, but a
      // hand-edited pack might. Treat an empty side as "no opinion".
      final leftEmpty = _isEmpty(left);
      final rightEmpty = _isEmpty(right);
      if (leftEmpty && rightEmpty) return true;
      if (leftEmpty) return rightOk;
      if (rightEmpty) return leftOk;
      return leftOk || rightOk;
    }
    return leftOk && rightOk;
  }

  bool _isEmpty(dynamic side) {
    if (side is! Map) return true;
    final c = side['conditions'];
    final hasConditions = c is List && c.isNotEmpty;
    return !hasConditions && side['left'] == null && side['right'] == null;
  }

  bool _single(Map<String, dynamic> c, GameState state) {
    final actual = _actualValue(c, state);
    if (actual == null) return false;
    final expected = c['value'];
    final want = expected is num ? expected : 0;
    return compare(actual, c['compareType'] as String?, want);
  }

  static bool compare(num actual, String? compareType, num expected) {
    switch (compareType) {
      case 'equal':
      case null:
        return actual == expected;
      case 'notEqual':
        return actual != expected;
      case 'bigger':
      case 'greater':
        return actual > expected;
      case 'equalOrBigger':
      case 'greaterEqual':
        return actual >= expected;
      case 'smaller':
      case 'less':
        return actual < expected;
      case 'equalOrSmaller':
      case 'lessEqual':
        return actual <= expected;
      default:
        return false;
    }
  }

  num? _actualValue(Map<String, dynamic> c, GameState state) {
    final target = c['target'] as String?;
    if (target == null) return null;
    final args = (c['args'] as List?) ?? const [];

    switch (c['targetType'] as String?) {
      case 'event':
        // EVENT_159 -> how far event 159 has got: 0 never seen, 1 playing,
        // 2 finished. Not a fired-count -- story 16 compares against 2 in
        // eleven places (the Readers' Response beats and friends), which a
        // once-only event's count never reaches.
        final id = int.tryParse(target.replaceFirst('EVENT_', ''));
        return id == null ? null : (state.eventStates[id] ?? 0);

      case 'eventSwitch':
        return state.switchValue(target);

      case 'date':
        final want = GameDate.tryParse(target);
        if (want == null) return null;
        // A date condition matches the day; the tick in the code is the slot
        // the original scheduled it for, and is compared only when non-zero.
        if (want.tick != 0) {
          return (want.day == state.date.day && want.tick == state.date.tick)
              ? 1
              : 0;
        }
        return want.day == state.date.day ? 1 : 0;

      case 'location':
        // "Are you at this place right now?" -- not "is it unlocked".
        // Confirmed by the content: #314 "Eating Shrimp Crackers in Secret"
        // is LOCATION_1000 and opens with "this class is so boring"; #116
        // "Library Volunteering" is LOCATION_16003; #256 "Motherlode" is the
        // Gold Mine. 70 events are gated this way.
        final id = int.tryParse(target.replaceFirst('LOCATION_', ''));
        if (id == null) return null;
        return state.locationId == id ? 1 : 0;

      case 'func':
        return functionValue(target, state, args);

      default:
        unknownTargets.add(target);
        return null;
    }
  }

  // -------------------------------------------------------------------------
  // The FUNC_ registry. Every target that story 16 actually uses is here;
  // add to this map (or pass `funcs:`) to extend the vocabulary.
  // -------------------------------------------------------------------------

  static int _b(bool v) => v ? 1 : 0;

  static final Map<String, FuncHandler> defaultFuncs = {
    'FUNC_ITEM_HAVE': (s, a) {
      final id = _intArg(a, 0);
      return _b(id != null && s.itemCount(id) > 0);
    },
    'FUNC_ITEM_COUNT': (s, a) {
      final id = _intArg(a, 0);
      return id == null ? 0 : s.itemCount(id);
    },
    'FUNC_ITEM_HAVE_LIST': (s, a) =>
        _b(a.whereType<num>().any((n) => s.itemCount(n.toInt()) > 0)),
    'FUNC_EXIST_ITEM_LIST': (s, a) =>
        _b(a.whereType<num>().any((n) => s.itemCount(n.toInt()) > 0)),
    'FUNC_ITEM_USE_COUNT': (s, a) {
      final id = _intArg(a, 0);
      return id == null ? 0 : (s.itemUseCounts[id] ?? 0);
    },
    'FUNC_IS_NO_ITEM_IN_POCKET': (s, a) => _b(s.inventory.isEmpty),

    'FUNC_TRAIT_HAVE': (s, a) {
      final id = _intArg(a, 0);
      return _b(id != null && s.traits.contains(id));
    },
    'FUNC_IS_TRAIT_LIST': (s, a) =>
        _b(a.whereType<num>().any((n) => s.traits.contains(n.toInt()))),
    'FUNC_TRAIT_HAVE_LIST': (s, a) =>
        _b(a.whereType<num>().any((n) => s.traits.contains(n.toInt()))),
    // Is the current place of this kind ("partTimeJob", "sleep", ...)?
    'FUNC_IS_LOCATION_TYPE': (s, a) =>
        _b(a.isNotEmpty && s.location?.type == '${a[0]}'),

    'FUNC_RANDOM_TRUE': (s, a) {
      // args is a percentage when given, otherwise a coin flip.
      final pct = _numArg(a, 0) ?? 50;
      return _b(s.random.nextDouble() * 100 < pct);
    },
    'FUNC_RANDOM_VALUE': (s, a) {
      final lo = (_numArg(a, 0) ?? 0).toInt();
      final hi = (_numArg(a, 1) ?? 100).toInt();
      return hi <= lo ? lo : lo + s.random.nextInt(hi - lo + 1);
    },

    'FUNC_IS_MALE': (s, a) => _b(s.isMale),
    'FUNC_IS_FEMALE': (s, a) => _b(!s.isMale),
    'FUNC_IS_WEEKEND': (s, a) => _b(s.date.isWeekend),

    'FUNC_GET_EXERCISE_LEVEL': (s, a) => s.exerciseLevel.level,
    'FUNC_GET_PART_TIME_JOB_LEVEL': (s, a) => s.partTimeLevel.level,
    'FUNC_GET_STUDY_LEVEL': (s, a) => s.studyLevel.level,
    'FUNC_GET_PLUS_STAT': (s, a) => s.studyLevel.plusStat,

    'FUNC_GET_LOW_STAT': (s, a) => _subjectIndexOf(s, lowest: true),
    'FUNC_GET_HIGH_STAT': (s, a) => _subjectIndexOf(s, lowest: false),

    'FUNC_IS_LOCATION_LIST': (s, a) =>
        _b(a.whereType<num>().any((n) => n.toInt() == s.locationId)),
    'FUNC_BEFORE_MOVE_LOCATION': (s, a) => s.locationId,
    'FUNC_AFTER_MOVE_LOCATION': (s, a) => s.locationId,
    'FUNC_MOVE_LOCATION_EXCEPT': (s, a) =>
        _b(!a.whereType<num>().any((n) => n.toInt() == s.locationId)),
    'FUNC_START_LOCATION_COUNT': (s, a) => s.locationId,

    'FUNC_TODO_HAVE': (s, a) => _b(s.taskDeadlines.containsKey(_intArg(a, 0))),
    'FUNC_TODO_DAY': (s, a) => s.pack.rules.flag('tasks', 'enabled', false)
        ? _taskDays(s, a)
        : s.daysRemaining,
    'FUNC_ROUGH_TODO_DAY': (s, a) =>
        s.pack.rules.flag('tasks', 'enabled', false)
        ? _b(s.taskDeadlines[_intArg(a, 0)]?.day == s.date.day)
        : (s.daysRemaining / 7).floor(),
    'FUNC_AFTER_DAY_V2': (s, a) => s.dayIndex,
    'FUNC_GET_GAME_COUNT': (s, a) => 1,
    'FUNC_STUDY_COUNT': (s, a) =>
        s.bookReadCounts.values.fold<int>(0, (x, y) => x + y),
    // How many departments accepted the CSAT. Retry Year's "Second Retake"
    // (160) and story 16's "Second Try" both fire on 0, the failed year.
    'FUNC_GET_SUCCESS_LENGTH': (s, a) => s.admittedDepartments.length,
    'FUNC_GOOD_DRAW_VALUE': (s, a) => s.drawValue,

    // --- Retry Year predicates, from the Korean native's FUNC table --------

    // vtl: has today passed the given 'yyyy.MM.dd'?
    'FUNC_AFTER_DAY': (s, a) {
      final parts = (a.isNotEmpty ? '${a[0]}' : '').split('.');
      if (parts.length < 3) return 0;
      final day = DateTime(
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 1,
        int.tryParse(parts[2]) ?? 1,
      );
      return _b(s.date.day.isAfter(day));
    },
    'FUNC_COMPARE_SWITCH': (s, a) {
      final name = a.isNotEmpty ? a[0]?.toString() : null;
      return name == null ? 0 : s.switchValue(name);
    },

    // After the CSAT: the grade per subject (1 best .. 9, 0 before the exam)
    // and where the student enrolled.
    'FUNC_GET_CURRENT_EXAM_GRADE': (s, a) {
      final subjects = s.pack.manifest.subjects;
      final i = _intArg(a, 0) ?? 0;
      if (s.csat == null || i < 0 || i >= subjects.length) return 0;
      return s.csat!.grades[subjects[i]] ?? 0;
    },
    'FUNC_IS_ENTER_UNIV': (s, a) =>
        _b(_enrolled(s)?.universityId == _intArg(a, 0)),
    'FUNC_IS_ENTER_UNIV_WITH_DEPART': (s, a) => _b(
      _enrolled(s)?.universityId == _intArg(a, 0) &&
          s.enrolledDepartment == _intArg(a, 1),
    ),
    'FUNC_IS_ENTER_DEPART_LIST': (s, a) =>
        _b(a.whereType<num>().any((n) => n.toInt() == s.enrolledDepartment)),
    // Enrolled somewhere whose cutoff is at or above this percentile.
    'FUNC_IS_ENTER_UNIV_THAT_RATE': (s, a) {
      final department = _enrolled(s);
      final rate = _numArg(a, 0) ?? 100;
      return _b(department != null && department.percentile >= rate);
    },
    'FUNC_IS_ENTER_UNIV_WITH_DEPART_TYPE': (s, a) => 0,
    // Is the player one of these characters? Retry Year asks it of a single
    // id (58's branches in #189/#210, 66's Weird Cookie), but the name and
    // the sibling *_LIST predicates take any number.
    'FUNC_IS_IN_CHARACTER_LIST': (s, a) => _b(
      s.characterId != null && a.any((id) => _intArg([id], 0) == s.characterId),
    ),

    // Store / regional predicates with no meaning in a local build. They
    // report "no premium, not the JP build" so the content that branches on
    // them takes the ordinary path.
    'FUNC_GET_PREMIUM_LEVEL': (s, a) => 0,
    'FUNC_IS_PLAYED_JP': (s, a) => 0,
  };

  static int _taskDays(GameState state, List<dynamic> args) {
    // Whole-day view of the authored task deadline. Native partial-day
    // rounding is unresolved; the normal confinement exit uses TODO_HAVE.
    final due = state.taskDeadlines[_intArg(args, 0)];
    return due == null ? 0 : state.date.daysUntil(due);
  }

  static Department? _enrolled(GameState s) => s.enrolledDepartment == null
      ? null
      : s.pack.admissions.departments[s.enrolledDepartment];

  static int? _intArg(List<dynamic> a, int i) {
    if (i >= a.length) return null;
    final v = a[i];
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static num? _numArg(List<dynamic> a, int i) {
    if (i >= a.length) return null;
    final v = a[i];
    return v is num ? v : num.tryParse(v.toString());
  }

  /// KSS addresses subjects positionally (INCREASE_STAT [1, 150] = subject 1).
  /// These return that same index so the two sides agree.
  static int _subjectIndexOf(GameState s, {required bool lowest}) {
    final subjects = s.pack.manifest.subjects;
    if (subjects.isEmpty) return 0;
    var best = 0;
    for (var i = 1; i < subjects.length; i++) {
      final v = s.stats[subjects[i]] ?? 0;
      final b = s.stats[subjects[best]] ?? 0;
      if (lowest ? v < b : v > b) best = i;
    }
    return best;
  }
}
