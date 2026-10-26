/// Bounded, declarative pack behavior. No campaign identifiers belong here.
library;

import 'dart:math';

import 'game_date.dart';
import 'state.dart';

class PackMechanics {
  final Map<String, dynamic> raw;
  const PackMechanics([this.raw = const {}]);
  Map<String, dynamic> section(String name) =>
      (raw[name] as Map? ?? const {}).cast<String, dynamic>();
  List<Map<String, dynamic>> get blocks => (raw['blocks'] as List? ?? const [])
      .cast<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
  static const abilityTypes = {
    'staminaFree',
    'surviveExhaustion',
    'priceFactor',
    'itemHpFactor',
    'moveHp',
    'studyRandomStat',
    'acceptanceFactor',
    'acceptancePoints',
    'callback',
    'hpCost',
    'priceOverride',
    'blockItemUse',
    'blockNegativeTrait',
  };
  static const operations = {
    'setSwitch',
    'addSwitch',
    'addMoney',
    'addHp',
    'addStat',
    'grantItem',
    'removeTrait',
    'grantTrait',
    'pulse',
    'drawItem',
    'if',
    'call',
    'enableBlock',
    'disableBlock',
    'shiftCalendar',
    'setField',
    'note',
  };
  factory PackMechanics.parse(Map<String, dynamic> raw) {
    if (raw.isNotEmpty && raw['version'] != 1) {
      throw const FormatException('mechanics.version must be 1');
    }
    var nodes = 0;
    void walk(dynamic v, [int depth = 0]) {
      if (depth > 32 || ++nodes > 20000) {
        throw const FormatException('Mechanics exceeds nesting/size limit');
      }
      if (v is Map) {
        if (v.containsKey('op') && !operations.contains(v['op'])) {
          throw FormatException('Unknown mechanics operation ${v['op']}');
        }
        for (final x in v.values) {
          walk(x, depth + 1);
        }
      } else if (v is List) {
        for (final x in v) {
          walk(x, depth + 1);
        }
      }
    }

    walk(raw);
    for (final key in [
      'predicates',
      'callbacks',
      'traitAbilities',
      'characterAbilities',
      'hooks',
      'switchGuards',
      'textMacros',
      'bindings',
    ]) {
      if (raw[key] != null && raw[key] is! Map) {
        throw FormatException('$key must be an object');
      }
    }
    if (raw['blocks'] != null && raw['blocks'] is! List) {
      throw const FormatException('blocks must be a list');
    }
    final parsed = PackMechanics(raw);
    void expression(dynamic e, {bool mutable = false}) {
      if (e is! Map) return;
      const names = {
        'literal',
        'arg',
        'args',
        'switch',
        'itemCount',
        'trait',
        'characterCode',
        'field',
        'rule',
        'predicate',
        'all',
        'any',
        'not',
        'if',
        'eq',
        'ne',
        'gt',
        'gte',
        'lt',
        'lte',
        'add',
        'sub',
        'mul',
        'div',
        'round',
        'lookup',
        'grade',
        'subjectStat',
        'subjectName',
        'randomInt',
        'roll',
        'dateAfter',
        'concat',
      };
      if (e.length != 1 || !names.contains(e.keys.single)) {
        throw FormatException('Unknown or ambiguous expression: ${e.keys}');
      }
      final key = e.keys.single;
      final v = e[key];
      if (key == 'literal') return;
      if (key == 'randomInt' && !mutable) {
        throw const FormatException('randomInt is only allowed in callbacks');
      }
      if (key == 'field' &&
          !{
            'storyId',
            'characterId',
            'locationId',
            'tick',
            'dateInt',
            'totalStat',
            'subjectCount',
            'exerciseLevel',
            'exerciseMaxed',
            'studyLevel',
            'money',
          }.contains(v)) {
        throw FormatException('Unknown field $v');
      }
      if (key == 'arg' && (v is! int || v < 0)) {
        throw const FormatException('arg requires a nonnegative integer');
      }
      if (key == 'predicate' &&
          (v is! String || !parsed.section('predicates').containsKey(v))) {
        throw FormatException('Unknown predicate $v');
      }
      const pairs = {
        'eq',
        'ne',
        'gt',
        'gte',
        'lt',
        'lte',
        'add',
        'sub',
        'mul',
        'div',
        'grade',
        'randomInt',
      };
      if ((pairs.contains(key) && (v is! List || v.length != 2)) ||
          (key == 'if' && (v is! List || v.length != 3)) ||
          ({'lookup', 'rule'}.contains(key) &&
              (v is! List || v.length < 2 || v.length > 3)) ||
          ({'all', 'any', 'concat'}.contains(key) && v is! List)) {
        throw FormatException('Invalid operands for $key');
      }
      if (key == 'roll' || key == 'dateAfter') {
        if (v is! Map ||
            (key == 'roll' && !v.containsKey('chance')) ||
            (key == 'dateAfter' &&
                (!v.containsKey('month') || !v.containsKey('day')))) {
          throw FormatException('Invalid $key expression');
        }
        for (final child in v.values) {
          expression(child, mutable: mutable);
        }
      } else if (v is List) {
        for (final child in v) {
          expression(child, mutable: mutable);
        }
      } else {
        expression(v, mutable: mutable);
      }
    }

    void steps(dynamic list) {
      if (list is! List) {
        throw const FormatException('Callback steps must be a list');
      }
      const requiredKeys = {
        'setSwitch': ['name', 'value'],
        'addSwitch': ['name', 'value'],
        'addMoney': ['value'],
        'addHp': ['value'],
        'addStat': ['subject', 'value'],
        'grantItem': ['id'],
        'removeTrait': ['id'],
        'grantTrait': ['id'],
        'pulse': ['name'],
        'drawItem': ['pool'],
        'if': ['when', 'then'],
        'call': ['name'],
        'enableBlock': ['id'],
        'disableBlock': ['id'],
        'shiftCalendar': ['monthSwitch', 'daySwitch', 'days'],
        'setField': ['name', 'value'],
        'note': ['text'],
      };
      for (final step in list) {
        if (step is! Map || !operations.contains(step['op'])) {
          throw const FormatException('Invalid callback operation');
        }
        for (final key in requiredKeys[step['op']]!) {
          if (!step.containsKey(key)) {
            throw FormatException('${step['op']} requires $key');
          }
        }
        if (step['op'] == 'setField' && step['name'] != 'movementLocked') {
          throw const FormatException(
            'Only movementLocked is writable with setField',
          );
        }
        for (final entry in step.entries) {
          if (entry.key == 'op') continue;
          if (entry.key == 'then' || entry.key == 'else') {
            steps(entry.value);
          } else if (entry.key == 'args' && entry.value is List) {
            for (final arg in entry.value) {
              expression(arg, mutable: true);
            }
          } else {
            expression(entry.value, mutable: true);
          }
        }
      }
    }

    for (final name in ['predicates', 'switchGuards', 'textMacros']) {
      for (final e in parsed.section(name).values) {
        expression(e);
      }
    }
    for (final callback in parsed.section('callbacks').values) {
      steps(callback);
    }
    // Reject predicate cycles before they can affect action previews.
    void checkPredicate(String name, Set<String> visiting) {
      if (!visiting.add(name)) {
        throw FormatException('Predicate cycle at $name');
      }
      void visit(dynamic e) {
        if (e is Map) {
          if (e.containsKey('literal')) return;
          if (e['predicate'] is String) {
            checkPredicate(e['predicate'], {...visiting});
          }
          for (final child in e.values) {
            visit(child);
          }
        } else if (e is List) {
          for (final child in e) {
            visit(child);
          }
        }
      }

      visit(parsed.section('predicates')[name]);
    }

    for (final name in parsed.section('predicates').keys) {
      checkPredicate(name, {});
    }
    final ids = <String>{};
    for (final b in parsed.blocks) {
      if (b['id'] is! String ||
          (b['id'] as String).isEmpty ||
          !ids.add(b['id'] as String) ||
          (b['action'] is! Map && b['catalogOnly'] != true) ||
          b['locations'] is! List ||
          (b['locations'] as List).isEmpty) {
        throw const FormatException(
          'Each block needs a unique id, locations and action',
        );
      }
      if ((b['locations'] as List).any((id) => id is! int)) {
        throw const FormatException('Block locations must be integer IDs');
      }
      expression(b['when']);
    }
    for (final key in ['traitAbilities', 'characterAbilities']) {
      for (final entry in parsed.section(key).entries) {
        if (int.tryParse(entry.key) == null || entry.value is! List) {
          throw FormatException(
            '$key requires numeric catalog IDs and ability lists',
          );
        }
        for (final a in entry.value as List) {
          if (a is! Map || !abilityTypes.contains(a['type'])) {
            throw FormatException('Unknown ability in $key/${entry.key}');
          }
          expression(a['when']);
          if (a['type'] == 'callback') {
            if (a['callback'] is! String) {
              throw const FormatException(
                'Callback ability needs callback name',
              );
            }
            steps(a['steps']);
          }
          if (a['type'] == 'hpCost' && a['value'] is! num) {
            throw const FormatException('hpCost ability needs a numeric value');
          }
          if (a['type'] == 'priceOverride' &&
              (a['maxPrice'] is! num || a['price'] is! num)) {
            throw const FormatException(
              'priceOverride ability needs numeric maxPrice and price',
            );
          }
          if (a['type'] == 'blockItemUse' && a['itemTag'] is! String) {
            throw const FormatException('blockItemUse ability needs itemTag');
          }
          if (a['chance'] != null &&
              (a['chance'] is! num || a['chance'] < 0 || a['chance'] > 1)) {
            throw const FormatException('Ability chance must be 0..1');
          }
        }
      }
    }
    return parsed;
  }
}

class MechanicRuntime {
  final GameState state;
  final List<dynamic> args;
  int _steps = 0;
  MechanicRuntime(this.state, [this.args = const []]);
  PackMechanics get definitions => state.pack.mechanics;
  bool condition(dynamic expression) =>
      expression == null || truth(value(expression));
  static bool truth(dynamic v) => v is bool
      ? v
      : v is num
      ? v != 0
      : v != null;
  num number(dynamic expression) {
    final v = value(expression);
    return v is num
        ? v
        : v == true
        ? 1
        : 0;
  }

  dynamic value(dynamic e, [int depth = 0]) {
    if (depth > 32) {
      throw const FormatException('Mechanics expression recursion limit');
    }
    if (e is! Map) return e;
    dynamic at(dynamic v) => value(v, depth + 1);
    num n(dynamic v) {
      final x = at(v);
      return x is num
          ? x
          : x == true
          ? 1
          : 0;
    }

    List list(dynamic x) => (x as List? ?? const []);
    if (e.containsKey('literal')) return e['literal'];
    if (e.containsKey('arg')) {
      final i = (e['arg'] as num).toInt();
      return i >= 0 && i < args.length ? args[i] : null;
    }
    if (e.containsKey('args')) return args;
    if (e.containsKey('switch')) return state.switchValue('${at(e['switch'])}');
    if (e.containsKey('itemCount')) {
      return state.itemCount(n(e['itemCount']).toInt());
    }
    if (e.containsKey('trait')) {
      final id = n(e['trait']).toInt(), t = state.pack.traits[id];
      return state.traitsEnabled &&
          state.traits.contains(id) &&
          state.traitInForce(id) &&
          t != null &&
          (t.locationIds.isEmpty || t.locationIds.contains(state.locationId)) &&
          (t.locationType == null || t.locationType == state.location?.type);
    }
    if (e.containsKey('characterCode')) {
      return state.pack.characters[state.characterId]?.specialFuncCode ==
          e['characterCode'];
    }
    if (e.containsKey('field')) {
      return switch (e['field']) {
        'storyId' => state.pack.manifest.storyId,
        'characterId' => state.characterId,
        'locationId' => state.locationId,
        'tick' => state.date.tick,
        'dateInt' => state.date.asInt,
        'totalStat' => state.totalStat,
        'subjectCount' => state.pack.manifest.subjects.length,
        'exerciseLevel' => state.exerciseLevel.level,
        'exerciseMaxed' => state.exerciseMaxed,
        'studyLevel' => state.studyLevel.level,
        'money' => state.money,
        _ => throw FormatException('Unknown mechanics field ${e['field']}'),
      };
    }
    if (e.containsKey('rule')) {
      final keys = list(e['rule']);
      return state.pack.rules.number(
        '${keys[0]}',
        '${keys[1]}',
        keys.length > 2 ? n(keys[2]) : 0,
      );
    }
    if (e.containsKey('predicate')) {
      final name = '${e['predicate']}';
      if (!definitions.section('predicates').containsKey(name)) return false;
      return value(definitions.section('predicates')[name], depth + 1);
    }
    if (e.containsKey('all')) return list(e['all']).every((x) => truth(at(x)));
    if (e.containsKey('any')) return list(e['any']).any((x) => truth(at(x)));
    if (e.containsKey('not')) return !truth(at(e['not']));
    if (e.containsKey('if')) {
      final xs = list(e['if']);
      return at(xs[truth(at(xs[0])) ? 1 : 2]);
    }
    for (final key in [
      'eq',
      'ne',
      'gt',
      'gte',
      'lt',
      'lte',
      'add',
      'sub',
      'mul',
      'div',
    ]) {
      if (!e.containsKey(key)) continue;
      final xs = list(e[key]);
      if (key == 'eq') return at(xs[0]) == at(xs[1]);
      if (key == 'ne') return at(xs[0]) != at(xs[1]);
      final a = n(xs[0]), b = n(xs[1]);
      return switch (key) {
        'gt' => a > b,
        'gte' => a >= b,
        'lt' => a < b,
        'lte' => a <= b,
        'add' => a + b,
        'sub' => a - b,
        'mul' => a * b,
        'div' => b == 0 ? 0 : a / b,
        _ => 0,
      };
    }
    if (e.containsKey('round')) return n(e['round']).round();
    if (e.containsKey('concat')) {
      return list(e['concat']).map((x) => '${at(x) ?? ''}').join();
    }
    if (e.containsKey('lookup')) {
      final xs = list(e['lookup']);
      final table = at(xs[0]);
      return table is Map
          ? table['${at(xs[1])}'] ?? (xs.length > 2 ? at(xs[2]) : null)
          : null;
    }
    if (e.containsKey('grade')) {
      final xs = list(e['grade']);
      final score = n(xs[0]);
      return 1 + list(at(xs[1])).where((x) => score >= n(x)).length;
    }
    if (e.containsKey('subjectStat')) {
      final i = n(e['subjectStat']).toInt();
      final keys = state.pack.manifest.subjects;
      return i >= 0 && i < keys.length ? state.stats[keys[i]] ?? 0 : 0;
    }
    if (e.containsKey('subjectName')) {
      final i = n(e['subjectName']).toInt();
      final xs = state.pack.manifest.subjects;
      if (i < 0 || i >= xs.length) return '';
      final labels =
          definitions.section('bindings')['subjectLabels'] as Map? ?? const {};
      return labels[xs[i]] ?? xs[i];
    }
    if (e.containsKey('randomInt')) {
      final xs = list(e['randomInt']);
      final lo = n(xs[0]).toInt(), hi = n(xs[1]).toInt();
      return hi <= lo ? lo : lo + state.random.nextInt(hi - lo + 1);
    }
    if (e.containsKey('roll')) {
      final r = (e['roll'] as Map);
      final chance = n(r['chance']);
      final time = r['period'] == 'day'
          ? GameDate(state.date.day, 0).asInt
          : state.date.asInt;
      return Random(time * 31 + n(r['seed']).toInt() * 101).nextDouble() <
          chance;
    }
    if (e.containsKey('dateAfter')) {
      final r = e['dateAfter'] as Map;
      final m = n(r['month']).toInt(), d = n(r['day']).toInt();
      return m > 0 &&
          d > 0 &&
          state.date.compareTo(
                GameDate(DateTime(state.date.day.year, m, d), 0),
              ) >
              0;
    }
    throw FormatException('Unknown mechanics expression ${e.keys.join(',')}');
  }

  void setBlock(dynamic id, bool enabled) {
    var found = false;
    for (final b in definitions.blocks) {
      if ('${b['id']}' != '$id' &&
          !(b['aliases'] as List? ?? const []).any((x) => '$x' == '$id')) {
        continue;
      }
      found = true;
      state.blockOverrides['${b['id']}'] = enabled;
      if (b['enabledSwitch'] is String) {
        state.setSwitch(b['enabledSwitch'] as String, enabled ? 1 : 0);
      }
    }
    if (!found) {
      throw FormatException('Unknown block $id');
    }
  }

  bool blockEnabled(Map<String, dynamic> b) {
    final gate = b['enabledSwitch'];
    final enabled = gate is String
        ? state.switchValue(gate) != 0
        : state.blockOverrides['${b['id']}'] ?? (b['defaultEnabled'] == true);
    return enabled && condition(b['when']);
  }

  /// A subject key, or a position in the manifest's `subjects` order (the
  /// way event content addresses subjects). Anything else passes through,
  /// so `all` / `random` keep their GameState meaning.
  String subjectKey(dynamic v) {
    final keys = state.pack.manifest.subjects;
    if (v is num) {
      final i = v.toInt();
      return i >= 0 && i < keys.length ? keys[i] : '';
    }
    return '$v';
  }

  void execute(
    List<dynamic> steps, {
    required void Function(String, List<dynamic>) call,
    required void Function(String) pulse,
    void Function(String)? report,
  }) {
    for (final raw in steps) {
      if (++_steps > 1000) {
        throw const FormatException('Mechanics operation limit');
      }
      final s = (raw as Map).cast<String, dynamic>();
      dynamic v(String key) => value(s[key]);
      num n(String key) => number(s[key]);
      switch (s['op']) {
        case 'setField':
          if (v('name') != 'movementLocked') {
            throw const FormatException('Unsupported mutable field');
          }
          state.movementLocked = truth(v('value'));
        case 'setSwitch':
          state.setSwitch('${v('name')}', n('value').toInt());
        case 'addSwitch':
          state.addSwitch('${v('name')}', n('value').toInt());
        case 'addMoney':
          state.addMoney(n('value'));
        case 'addHp':
          state.addHp(n('value'));
        case 'addStat':
          final subject = subjectKey(v('subject'));
          if (subject.isNotEmpty) state.addStat(subject, n('value'));
        case 'note':
          final text = '${v('text') ?? ''}';
          if (text.isEmpty) break;
          state.note(text, 'effect');
          report?.call(text);
        case 'grantItem':
          state.addItem(
            n('id').toInt(),
            s['count'] == null ? 1 : n('count').toInt(),
          );
        case 'grantTrait':
          state.grantTrait(n('id').toInt());
        case 'removeTrait':
          state.removeTrait(n('id').toInt());
        case 'pulse':
          final name = '${v('name')}';
          state.setSwitch(name, 1);
          pulse(name);
        case 'drawItem':
          final choices = (v('pool') as List? ?? const [])
              .whereType<num>()
              .map((x) => x.toInt())
              .where(state.pack.items.containsKey)
              .toList();
          if (choices.isEmpty) break;
          final id = choices[state.random.nextInt(choices.length)];
          state.addItem(id);
          if (s['store'] != null) {
            state.setSwitch('${v('store')}', id);
          }
        case 'if':
          execute(
            (condition(s['when']) ? s['then'] : s['else']) as List? ?? const [],
            call: call,
            pulse: pulse,
            report: report,
          );
        case 'call':
          call('${v('name')}', [
            for (final x in s['args'] as List? ?? const []) value(x),
          ]);
        case 'enableBlock':
          setBlock(v('id'), true);
        case 'disableBlock':
          setBlock(v('id'), false);
        case 'shiftCalendar':
          final month = '${v('monthSwitch')}', day = '${v('daySwitch')}';
          final m = state.switchValue(month), d = state.switchValue(day);
          if (m <= 0 || d <= 0) break;
          final date = DateTime(state.date.day.year, m, d + n('days').toInt());
          state.setSwitch(month, date.month);
          state.setSwitch(day, date.day);
        default:
          throw FormatException('Unknown operation ${s['op']}');
      }
    }
  }
}
