/// A dev-panel scene in which every NPC with portrait art speaks in turn,
/// once in their default look and once per extra expression, so portrait
/// layers and nameplates can be checked without hunting for the event that
/// uses them.
///
/// It is built at run time from `presentation.json` and the speaker list, is
/// never eligible, changes nothing, and is scrubbed from the run's event
/// bookkeeping when it ends, so it never reaches a save.
library;

import 'event_engine.dart';
import 'game.dart';
import 'pack.dart';
import 'state.dart';

class CharacterShowcase {
  /// Outside every authored id range (story ids are at most 6 digits, nodes
  /// eventId * 1000 + n).
  static const eventId = -900;
  static const _nodeBase = 990000000;

  static GameEvent _event(int root) => GameEvent(
    id: eventId,
    name: 'Character showcase',
    rootNodeId: root,
    priority: 'middle',
    rank: 'C',
    section: 'none',
    eventSetId: null,
    isRandomDate: false,
    isFake: false,
    conditionSet: null,
  );

  /// Every NPC with art, by id: the line they say and the expression to wear.
  static List<(int npc, String expression, String line)> lines(
    ContentPack pack,
  ) {
    final npcs = (pack.presentation['npcs'] as Map?) ?? const {};
    final ids =
        npcs.keys
            .map((k) => int.tryParse('$k'))
            .whereType<int>()
            .where((id) => (npcs['$id'] as Map?)?['skeleton'] != null)
            .toList()
          ..sort();
    final out = <(int, String, String)>[];
    for (final id in ids) {
      final name = pack.speakers[id] ?? 'NPC $id';
      out.add((id, 'defaults', '$name (#$id).'));
      final expressions = ((npcs['$id'] as Map)['expressions'] as Map?) ?? {};
      for (final entry in expressions.entries) {
        if (entry.key == 'defaults' || entry.value == null) continue;
        out.add((id, '${entry.key}', '$name — expression "${entry.key}".'));
      }
    }
    return out;
  }

  static EventRun begin(Game game) {
    final pack = game.pack;
    final cast = lines(pack);
    final nodes = <EventNode>[
      for (var i = 0; i < cast.length; i++)
        EventNode(
          id: _nodeBase + i,
          boxId: 0,
          type: i == cast.length - 1 ? 'last' : 'text',
          text: cast[i].$3,
          elseText: null,
          optionText: null,
          nextNodeId: i == cast.length - 1 ? null : _nodeBase + i + 1,
          nextNodeIdIfTrue: null,
          nextNodeIdIfFalse: null,
          options: const [],
          speakerId: cast[i].$1,
          isHideSpeakerName: false,
          backgroundImg: null,
          imgPath: null,
          changer: null,
          actionChanger: null,
          conditionSet: null,
          eventSound: null,
          standingId: cast[i].$1,
          standingExpression: cast[i].$2,
        ),
    ];
    for (final node in nodes) {
      pack.nodes[node.id] = node;
    }
    final state = game.state;
    final fired = state.eventsFiredToday;
    final run = game.events.begin(_event(_nodeBase), state);
    state.eventsFiredToday = fired;
    state.eventCounts.remove(eventId);
    return run;
  }

  /// Removes the scene's trace once it has been played.
  static void cleanUp(GameState state) {
    state.eventStates.remove(eventId);
    state.eventCounts.remove(eventId);
  }
}
