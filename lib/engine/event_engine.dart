/// Plays an event's node graph, and chooses which event fires.
///
/// The graph is KSS's: nodes link by `nextNodeId`, branch on `ifElse` via
/// `nextNodeIdIfTrue`/`nextNodeIdIfFalse`, and present choices as an `option`
/// node whose `options` list names *boxIds*, each of which is a separate
/// branch's entry node. `last` ends the event.
///
/// Presentation nodes (`standing`, `background`, `eventBGM`, `soundEffect`...)
/// carry no text: the runner applies their side effects and walks straight on,
/// so the UI only ever sees something to show.
library;

import 'conditions.dart';
import 'effects.dart';
import 'pack.dart';
import 'state.dart';
import 'event_text.dart';

/// One beat the UI must render.
class EventBeat {
  final EventNode node;
  final String text;
  final String? speakerName;
  final String? backgroundImg;
  final List<EventChoice> choices;
  final bool isEnd;

  EventBeat({
    required this.node,
    required this.text,
    required this.speakerName,
    required this.backgroundImg,
    required this.choices,
    required this.isEnd,
  });
}

class EventChoice {
  final String text;
  final EventOption option;
  EventChoice(this.text, this.option);
}

/// A single event, mid-play. Create with [EventEngine.begin], then call
/// [advance] / [choose] until [current] reports `isEnd`.
class EventRun {
  final GameEvent event;
  final ContentPack pack;
  final GameState state;
  final EffectEngine effects;
  final ConditionEvaluator conditions;

  EventBeat? current;
  String? backgroundImg;
  int? portraitId;
  String portraitExpression = 'defaults';
  String portraitClothes = 'defaults';
  List<String> portraitOtherLayers = const [];

  void _updatePortrait(EventNode node) {
    if (node.standingOff) {
      portraitId = null;
      return;
    }
    final id = node.standingId ?? (node.speakerId > 0 ? node.speakerId : null);
    // Player speech leaves the previous NPC on screen.
    if (id == null || id <= 0) return;
    portraitId = id;
    portraitExpression = node.standingExpression;
    portraitClothes = node.standingClothes;
    portraitOtherLayers = node.otherLayers;
  }

  /// Guards against a cycle in hand-edited content. A graph that loops
  /// forever would hang the UI thread with no clue why.
  static const _maxSteps = 2000;
  int _steps = 0;
  bool exhausted = false;

  EventRun({
    required this.event,
    required this.pack,
    required this.state,
    required this.effects,
    required this.conditions,
  });

  void start() {
    state.eventCounts[event.id] = (state.eventCounts[event.id] ?? 0) + 1;
    state.eventStates[event.id] = 1;
    state.eventsFiredToday++;
    _walkFrom(event.rootNodeId);
  }

  /// Advance past a plain text beat.
  void advance() {
    final node = current?.node;
    if (node == null || current!.isEnd || current!.choices.isNotEmpty) return;
    _walkFrom(node.nextNodeId);
  }

  /// Take a choice on an `option` beat. The branch target is the option's own
  /// `nextNodeId`; `nextBoxId` is the fallback for content that only names
  /// the box.
  void choose(EventChoice choice) {
    final target =
        choice.option.nextNodeId ??
        _entryNodeOfBox(choice.option.nextBoxId)?.id;
    _walkFrom(target);
  }

  EventNode? _entryNodeOfBox(int? boxId) {
    if (boxId == null) return null;
    final nodes = pack.nodesByBox[boxId];
    if (nodes == null || nodes.isEmpty) return null;
    return nodes.first;
  }

  /// Walks the graph applying side effects until it reaches something the
  /// player must see, or runs out of graph.
  void _walkFrom(int? nodeId) {
    var id = nodeId;
    while (true) {
      if (++_steps > _maxSteps) {
        exhausted = true;
        current = _endBeat();
        state.note(
          'Event "${event.name}" (#${event.id}) exceeded $_maxSteps nodes and '
              'was cut off -- the graph probably loops.',
          'system',
        );
        return;
      }
      if (id == null) {
        current = _endBeat();
        return;
      }
      final node = pack.nodes[id] ?? pack.systemNodes[id];
      if (node == null) {
        state.note(
          'Event "${event.name}" links to missing node $id; ending it here.',
          'system',
        );
        current = _endBeat();
        return;
      }

      // A node gated false is skipped, along with its effects.
      final gateOk = conditions.evaluate(node.conditionSet, state);

      if (gateOk) {
        _updatePortrait(node);
        effects.applyChanger(node.changer, state);
        if (effects.endRequested) {
          state.finished = true;
          state.endingLabel = effects.endLabel;
          state.endingCode = effects.endCode;
          current = _endBeat();
          return;
        }
      }

      if (node.backgroundImg != null && node.backgroundImg!.isNotEmpty) {
        backgroundImg = node.backgroundImg;
      }

      switch (node.type) {
        case 'ifElse':
          id = gateOk ? node.nextNodeIdIfTrue : node.nextNodeIdIfFalse;
          continue;

        case 'option':
          if (!gateOk) {
            id = node.nextNodeId;
            continue;
          }
          final choices = <EventChoice>[];
          for (final option in node.options) {
            if (!conditions.evaluate(option.conditionSet, state)) continue;
            choices.add(
              EventChoice(expandEventText(option.text, state), option),
            );
          }
          if (choices.isEmpty) {
            // Every branch gated out: fall through rather than deadlock.
            id = node.nextNodeId;
            continue;
          }
          current = EventBeat(
            node: node,
            text: _textOf(node, gateOk),
            speakerName: _speakerName(node),
            backgroundImg: backgroundImg,
            choices: choices,
            isEnd: false,
          );
          return;

        case 'last':
          current = _endBeat(node);
          return;

        case 'text':
          final body = _textOf(node, gateOk);
          if (body.trim().isEmpty) {
            id = node.nextNodeId;
            continue;
          }
          current = EventBeat(
            node: node,
            text: body,
            speakerName: _speakerName(node),
            backgroundImg: backgroundImg,
            choices: const [],
            isEnd: false,
          );
          return;

        default:
          // standing / background / eventBGM / soundEffect / mute nodes:
          // presentation only. Effects already applied above.
          id = node.nextNodeId;
          continue;
      }
    }
  }

  /// `elseText` is what the node shows when its own condition was false --
  /// KSS's way of writing a one-node branch.
  String _textOf(EventNode node, bool gateOk) {
    if (!gateOk && node.elseText != null && node.elseText!.isNotEmpty) {
      return expandEventText(node.elseText!, state);
    }
    return expandEventText(node.text ?? '', state);
  }

  String? _speakerName(EventNode node) {
    if (node.isHideSpeakerName) return null;
    if (node.speakerId <= 0) return 'Me';
    return pack.speakers[node.speakerId] ?? 'Speaker ${node.speakerId}';
  }

  /// Every way out of the graph lands here, so this is the one place that
  /// can mark the event finished (state 2) for the conditions that wait on
  /// it -- `EVENT_191 equal 2` gates Readers' Response, and the storyline
  /// prerequisites the pack adds are written the same way.
  EventBeat _endBeat([EventNode? node]) {
    state.eventStates[event.id] = 2;
    return _buildEndBeat(node);
  }

  EventBeat _buildEndBeat([EventNode? node]) => EventBeat(
    node:
        node ??
        EventNode(
          id: -1,
          boxId: -1,
          type: 'last',
          text: null,
          elseText: null,
          optionText: null,
          nextNodeId: null,
          nextNodeIdIfTrue: null,
          nextNodeIdIfFalse: null,
          options: const [],
          speakerId: 0,
          isHideSpeakerName: true,
          backgroundImg: null,
          imgPath: null,
          changer: null,
          actionChanger: null,
          conditionSet: null,
          eventSound: null,
        ),
    text: expandEventText(node?.text ?? '', state),
    speakerName: node == null ? null : _speakerName(node),
    backgroundImg: backgroundImg,
    choices: const [],
    isEnd: true,
  );
}

class EventEngine {
  final ContentPack pack;
  final ConditionEvaluator conditions;
  final EffectEngine effects;

  EventEngine({
    required this.pack,
    ConditionEvaluator? conditions,
    EffectEngine? effects,
  }) : conditions = conditions ?? ConditionEvaluator(),
       effects =
           effects ??
           EffectEngine(conditions: conditions ?? ConditionEvaluator());

  EventRun begin(GameEvent event, GameState state) {
    effects.resetTransient();
    final run = EventRun(
      event: event,
      pack: pack,
      state: state,
      effects: effects,
      conditions: conditions,
    );
    run.start();
    return run;
  }

  /// Every event whose conditions hold right now.
  List<GameEvent> eligible(GameState state) {
    final section = state.currentSection;
    return pack.events.values.where((e) {
      if (e.isFake) return false;
      if (e.rootNodeId < 0 || !pack.nodes.containsKey(e.rootNodeId)) {
        return false;
      }
      if (e.section != 'none' && e.section != section) return false;
      return conditions.evaluate(e.conditionSet, state);
    }).toList();
  }

  /// Picks the event to fire this tick, or null for a quiet tick.
  ///
  /// Date-pinned events (`isRandomDate == false`) are scheduled content and
  /// fire as soon as they are eligible. Random-date ones are a weighted draw,
  /// gated by `rules.events.randomEventChancePerTick` and the daily cap.
  GameEvent? pick(GameState state) {
    // The daily cap applies to everything, scheduled content included.
    // Without this, a date-pinned event fires on every tick it is eligible
    // for, which buries the loop in dialogue.
    if (state.eventsFiredToday >= pack.rules.maxEventsPerDay) return null;

    final candidates = eligible(state);
    if (candidates.isEmpty) return null;

    final order =
        (pack.rules.section('events')['priorityOrder'] as List?)
            ?.whereType<String>()
            .toList() ??
        const ['veryHigh', 'high', 'middle', 'low'];

    final pinned = candidates.where((e) => !e.isRandomDate).toList();
    if (pinned.isNotEmpty) {
      pinned.sort((a, b) {
        final pa = order.indexOf(a.priority);
        final pb = order.indexOf(b.priority);
        final ra = pa < 0 ? order.length : pa;
        final rb = pb < 0 ? order.length : pb;
        if (ra != rb) return ra.compareTo(rb);
        return a.id.compareTo(b.id);
      });
      return pinned.first;
    }

    if (state.random.nextDouble() >= pack.rules.randomEventChance) return null;

    final weights = pack.rules.rankWeights;
    final random = candidates.where((e) => e.isRandomDate).toList();
    if (random.isEmpty) return null;

    num total = 0;
    for (final e in random) {
      total += weights[e.rank] ?? 1;
    }
    if (total <= 0) return random[state.random.nextInt(random.length)];

    var roll = state.random.nextDouble() * total;
    for (final e in random) {
      roll -= weights[e.rank] ?? 1;
      if (roll <= 0) return e;
    }
    return random.last;
  }
}
