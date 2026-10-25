/// The dev panel: change anything, inspect everything, reload the pack.
///
/// Five tabs:
///   State    edit stats / stamina / money / levels, jump days and ticks
///   Events   search all events, see which are eligible now, fire any of them
///   Content  switches, items, locations -- grant, set, unlock
///   Traits   what the held traits are doing right now, and grant any of 244
///   Rules    live edit of rules.json, saved back to the pack directory
///   Pack     where the pack came from, reload from disk, reset to bundled,
///            and the list of verbs the pack used that the engine lacks
library;

import 'dart:async';
import 'dart:convert';

import 'press_feedback.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/account_store.dart';
import '../engine/content_source.dart';
import '../engine/event_engine.dart';
import '../engine/game_date.dart';
import '../engine/game.dart';
import '../engine/pack.dart';
import '../engine/save_store.dart';
import '../engine/showcase.dart';
import '../engine/state.dart';
import 'game_screen.dart';
import 'theme.dart';

class DevPanel extends StatefulWidget {
  final Game game;
  final PackLocation packLocation;
  final PackReloaded? onPackReloaded;
  final VoidCallback onStateChanged;
  final Future<void> Function(EventRun run) playEvent;

  const DevPanel({
    super.key,
    required this.game,
    required this.packLocation,
    required this.onStateChanged,
    required this.playEvent,
    this.onPackReloaded,
  });

  @override
  State<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<DevPanel> {
  Game get game => widget.game;

  void _change(VoidCallback mutate) {
    setState(mutate);
    widget.onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'State'),
                Tab(text: 'Events'),
                Tab(text: 'Content'),
                Tab(text: 'Traits'),
                Tab(text: 'Rules'),
                Tab(text: 'Pack'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _StateTab(game: game, onChange: _change),
                  _EventsTab(game: game, playEvent: widget.playEvent),
                  _ContentTab(game: game, onChange: _change),
                  _TraitsTab(game: game, onChange: _change),
                  _RulesTab(
                    game: game,
                    location: widget.packLocation,
                    onReloaded: widget.onPackReloaded,
                  ),
                  _PackTab(
                    game: game,
                    location: widget.packLocation,
                    onReloaded: widget.onPackReloaded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Persists an edit that landed on the account wallet.
void _saveWallet(GameState s) {
  if (s.usesAccountWallet) unawaited(AccountStore.save());
}

class _StateTab extends StatelessWidget {
  final Game game;
  final void Function(VoidCallback) onChange;
  const _StateTab({required this.game, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(context, 'Subject stats'),
        for (final key in s.stats.keys.toList())
          _NumberRow(
            label: key,
            value: s.stats[key]!,
            onChanged: (v) => onChange(() => s.stats[key] = v),
            steps: const [-1000, -100, 100, 1000],
          ),
        const Divider(height: 28),
        _header(context, 'Vitals'),
        _NumberRow(
          label: 'Stamina',
          value: s.hp,
          onChanged: (v) => onChange(() => s.hp = v.clamp(0, s.hpMax)),
          steps: const [-25, -5, 5, 25],
        ),
        _NumberRow(
          label: 'Money',
          value: s.money,
          onChanged: (v) => onChange(() => s.money = v < 0 ? 0 : v),
          steps: const [-10000, -1000, 1000, 10000],
        ),
        // A shared balance is the account's: editing it edits the wallet
        // Home shows, and saves it.
        _NumberRow(
          label: s.usesAccountWallet && s.sharesWallet('cookies')
              ? 'Cookies (account)'
              : 'Cookies',
          value: s.cookies,
          onChanged: (v) => onChange(() {
            s.cookies = v < 0 ? 0 : v.round();
            _saveWallet(s);
          }),
          steps: const [-50, -5, 5, 50],
        ),
        _NumberRow(
          label: s.usesAccountWallet && s.sharesWallet('refresh')
              ? 'Refresh tickets (account)'
              : 'Refresh tickets',
          value: s.rerolls,
          onChanged: (v) => onChange(() {
            s.rerolls = v < 0 ? 0 : v.round();
            _saveWallet(s);
          }),
          steps: const [-50, -5, 5, 50],
        ),
        const Divider(height: 28),
        _header(context, 'Experience'),
        _NumberRow(
          label: 'Study (${s.studyLevel.name})',
          value: s.studyExp,
          onChanged: (v) => onChange(() => s.studyExp = v < 0 ? 0 : v),
          steps: const [-5000, -500, 500, 5000],
        ),
        _NumberRow(
          label: 'Exercise (${s.exerciseLevel.name})',
          value: s.exerciseExp,
          onChanged: (v) => onChange(() => s.exerciseExp = v < 0 ? 0 : v),
          steps: const [-1000, -100, 100, 1000],
        ),
        _NumberRow(
          label: 'Part-time (${s.partTimeLevel.name})',
          value: s.partTimeExp,
          onChanged: (v) => onChange(() => s.partTimeExp = v < 0 ? 0 : v),
          steps: const [-1000, -100, 100, 1000],
        ),
        const Divider(height: 28),
        _header(context, 'Clock — ${s.date.code}'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in const [-5, -1, 1, 5])
              PressFeedback(
                child: OutlinedButton(
                  onPressed: () => onChange(() => s.date = _shiftDays(game, n)),
                  child: Text('${n > 0 ? '+' : ''}$n day'),
                ),
              ),
            PressFeedback(
              child: OutlinedButton(
                onPressed: () => onChange(() {
                  s.date = s.date.advance(1, s.ticksPerDay);
                }),
                child: const Text('+1 tick'),
              ),
            ),
            PressFeedback(
              child: OutlinedButton(
                onPressed: () => onChange(() {
                  s.date = game.pack.manifest.endDate;
                  s.finished = true;
                }),
                child: const Text('Jump to exam day'),
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        _header(context, 'Run'),
        // The in-game drawer only lets you leave between days; the dev panel
        // deliberately does not care.
        Row(
          children: [
            Expanded(
              child: PressFeedback(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: D30Colors.alert,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final slot = s.saveSlot;
                    if (slot != null) await SaveStore.write(slot, s);
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: Text(
                    s.saveSlot == null
                        ? 'Leave to main menu'
                        : 'Save and leave to main menu',
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        _header(context, 'Sex (FUNC_IS_MALE / FUNC_IS_FEMALE)'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Male')),
            ButtonSegment(value: false, label: Text('Female')),
          ],
          selected: {s.isMale},
          onSelectionChanged: (v) => onChange(() => s.isMale = v.first),
        ),
        const Divider(height: 28),
        _header(context, 'State dump'),
        _CopyBlock(text: s.toPrettyJson()),
      ],
    );
  }

  /// Jump the calendar, clamped to the pack's own start and end dates so the
  /// run cannot be pushed outside its own calendar.
  static GameDate _shiftDays(Game game, int days) {
    final s = game.state;
    final target = GameDate.addDays(s.date.day, days);
    final start = game.pack.manifest.startDate.day;
    final end = game.pack.manifest.endDate.day;
    final clamped = target.isBefore(start)
        ? start
        : (target.isAfter(end) ? end : target);
    return GameDate(clamped, s.date.tick);
  }
}

Widget _header(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: Theme.of(context).textTheme.titleSmall),
);

class _NumberRow extends StatelessWidget {
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final List<num> steps;

  const _NumberRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label: ${value.round()}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: PressFeedback(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onChanged(value + s),
                  child: Text(
                    s > 0 ? '+$s' : '$s',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EventsTab extends StatefulWidget {
  final Game game;
  final Future<void> Function(EventRun run) playEvent;
  const _EventsTab({required this.game, required this.playEvent});

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  String _query = '';
  bool _eligibleOnly = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final eligible = game.events.eligible(game.state).map((e) => e.id).toSet();
    var events = game.pack.events.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (_eligibleOnly) {
      events = events.where((e) => eligible.contains(e.id)).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      events = events
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) || e.id.toString().contains(q),
          )
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  hintText: 'Search events by name or id',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${eligible.length} of ${game.pack.events.length} '
                      'eligible now · section ${game.state.currentSection}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Eligible only'),
                    selected: _eligibleOnly,
                    onSelected: (v) => setState(() => _eligibleOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: PressFeedback(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.groups),
                    label: Text(
                      'Character showcase '
                      '(${CharacterShowcase.lines(game.pack).length} lines)',
                    ),
                    onPressed: () async {
                      final run = CharacterShowcase.begin(game);
                      Navigator.of(context).pop();
                      await widget.playEvent(run);
                      CharacterShowcase.cleanUp(game.state);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              final isEligible = eligible.contains(e.id);
              final seen = game.state.eventCounts[e.id] ?? 0;
              return ListTile(
                dense: true,
                leading: Icon(
                  isEligible ? Icons.play_circle : Icons.lock_outline,
                  size: 20,
                  color: isEligible
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
                title: Text(
                  e.name.isEmpty ? 'Event ${e.id}' : e.name,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '#${e.id} · rank ${e.rank} · ${e.priority} · '
                  'section ${e.section}'
                  '${e.isRandomDate ? ' · random' : ' · pinned'}'
                  '${seen > 0 ? ' · seen ${seen}x' : ''}',
                ),
                trailing: PressFeedback(
                  child: TextButton(
                    onPressed: () async {
                      final run = game.events.begin(e, game.state);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      await widget.playEvent(run);
                    },
                    child: const Text('Fire'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ContentTab extends StatefulWidget {
  final Game game;
  final void Function(VoidCallback) onChange;
  const _ContentTab({required this.game, required this.onChange});

  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final s = game.state;
    final q = _query.toLowerCase();
    bool hit(String text) => q.isEmpty || text.toLowerCase().contains(q);

    final items = game.pack.items.values
        .where((i) => hit('${i.id} ${i.name}'))
        .take(60);
    final switches = game.pack.switchDefaults.keys.where(hit).take(80);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            hintText: 'Filter items and switches',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        _header(context, 'Locations'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in game.pack.locations.values)
              FilterChip(
                label: Text(l.name),
                selected: s.unlockedLocations.contains(l.id),
                onSelected: (v) => widget.onChange(() {
                  if (v) {
                    s.unlockedLocations.add(l.id);
                  } else {
                    s.unlockedLocations.remove(l.id);
                  }
                }),
              ),
          ],
        ),
        const Divider(height: 28),
        _header(context, 'Items — tap to grant one'),
        for (final i in items)
          ListTile(
            dense: true,
            title: Text(
              '${i.name}  ·  ${i.id}',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              i.effectText.isEmpty ? i.kind : i.effectText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('×${s.itemCount(i.id)}'),
            onTap: () => widget.onChange(() => s.addItem(i.id)),
            onLongPress: () => widget.onChange(() => s.removeItem(i.id)),
          ),
        const Divider(height: 28),
        _header(context, 'Event switches'),
        for (final name in switches)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    game.pack.switchLabels[name] == null
                        ? name
                        : '$name  (${game.pack.switchLabels[name]})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                PressFeedback(
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () =>
                        widget.onChange(() => s.addSwitch(name, -1)),
                  ),
                ),
                Text('${s.switchValue(name)}'),
                PressFeedback(
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () =>
                        widget.onChange(() => s.addSwitch(name, 1)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Traits: what the held ones are doing *right now*, and a way to grant any
/// of the 244.
///
/// The live readout is the point. A trait's effect can be gated on the
/// location, the tick, the weekday, a held item, the weakest subject or a
/// seeded dice roll, so "I granted it and nothing happened" is usually a
/// condition that does not hold rather than a bug. This prints the numbers
/// the engine would actually use for a block taken here, this tick.
class _TraitsTab extends StatefulWidget {
  final Game game;
  final void Function(VoidCallback) onChange;
  const _TraitsTab({required this.game, required this.onChange});

  @override
  State<_TraitsTab> createState() => _TraitsTabState();
}

class _TraitsTabState extends State<_TraitsTab> {
  String _query = '';
  bool _hideOtherStories = true;
  String? _message;

  Game get game => widget.game;
  GameState get s => game.state;

  /// `grantTrait` refuses a trait that belongs to another story, which from
  /// the outside looks like a dead tap. Say so instead.
  void _toggle(GameTrait trait) {
    widget.onChange(() {
      if (s.removeTrait(trait.id)) {
        _message = 'Removed ${trait.name}.';
        return;
      }
      if (s.grantTrait(trait.id)) {
        final days = s.traitDaysLeft[trait.id];
        _message = days == null
            ? 'Granted ${trait.name}.'
            : 'Granted ${trait.name}, for $days days.';
        return;
      }
      _message =
          '${trait.name} belongs to story ${trait.storyId}, not '
          '${game.pack.manifest.storyId} — the engine refuses it.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final subjects = game.pack.manifest.subjects;
    final ownStory = game.pack.manifest.storyId;

    final held = s.traits.toList()..sort();
    final catalog =
        game.pack.traits.values.where((t) {
          if (_hideOtherStories &&
              t.storyId != null &&
              ownStory != null &&
              t.storyId != ownStory) {
            return false;
          }
          if (q.isEmpty) return true;
          return '${t.id} ${t.name} ${t.description}'.toLowerCase().contains(q);
        }).toList()..sort((a, b) {
          // Held first, so what is in play is never buried.
          final heldA = s.traits.contains(a.id);
          final heldB = s.traits.contains(b.id);
          if (heldA != heldB) return heldA ? -1 : 1;
          return a.id.compareTo(b.id);
        });

    final (ptFlat, ptFactor) = game.traits.partTimeMoney(s);
    final (exFlat, exFactor) = game.traits.exerciseExp(s);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: s.traitsEnabled,
          title: const Text('Trait effects'),
          subtitle: Text(
            s.traitsEnabled
                ? 'On. ${held.length} held of ${game.pack.traits.length}.'
                : 'Off — every trait contributes nothing while this is off.',
            style: const TextStyle(fontSize: 11),
          ),
          // Session-only: rules.json on disk is edited in the Rules tab.
          onChanged: (v) => widget.onChange(() {
            final section =
                (game.pack.rules.raw['traits'] as Map?) ??
                (game.pack.rules.raw['traits'] = <String, dynamic>{}) as Map;
            section['enabled'] = v;
            _message = v
                ? 'Effects on for this session.'
                : 'Effects off for this session.';
          }),
        ),
        const Divider(height: 24),
        _header(context, 'What they are doing right now'),
        Text(
          'At ${s.location?.name ?? s.locationId}, tick ${s.date.tick}, '
          '${_weekday(s.date)}'
          '${s.isDayBeforeExam ? ' — the day before an exam' : ''}.',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        _readout(
          'Study',
          [
            for (final subject in subjects)
              '$subject ${_signed(game.traits.studyBonus(s, subject: subject))}',
          ].join(' · '),
        ),
        _readout(
          'Class',
          _signed(
            game.traits.studyBonus(
              s,
              subject: subjects.first,
              schoolStudy: true,
            ),
          ),
        ),
        _readout(
          'Stamina',
          [
            for (final kind in ['study', 'exercise', 'partTimeJob', 'sleep'])
              '$kind ${_signed(game.traits.hpCostDelta(s, actionType: kind))}',
          ].join(' · '),
        ),
        _readout('Sleep restore', _signed(game.traits.sleepHp(s))),
        _readout('Part-time pay', '${_signed(ptFlat)} Gold · ×$ptFactor'),
        _readout('Workout exp', '${_signed(exFlat)} · ×$exFactor'),
        _readout('Goal reward', '×${game.traits.goalRewardFactor(s)}'),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(child: _header(context, 'Held (${held.length})')),
            if (held.isNotEmpty)
              PressFeedback(
                child: TextButton(
                  onPressed: () => widget.onChange(() {
                    for (final id in held) {
                      s.removeTrait(id);
                    }
                    _message = 'Cleared ${held.length} traits.';
                  }),
                  child: const Text('Clear all'),
                ),
              ),
          ],
        ),
        if (held.isEmpty)
          const Text(
            'None. Nothing grants a trait in play yet except event content, '
            'so this is the only way to try one.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in held)
                InputChip(
                  label: Text(
                    _chipLabel(id),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: game.pack.traits[id]?.type == 'bad'
                      ? const Color(0xFFFFCDD2)
                      : const Color(0xFFC8E6C9),
                  onDeleted: () {
                    final trait = game.pack.traits[id];
                    if (trait != null) _toggle(trait);
                  },
                ),
            ],
          ),
        const Divider(height: 24),
        _header(context, 'Grant — tap to toggle'),
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            hintText: 'Filter by id, name or description',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _hideOtherStories,
          title: const Text(
            'Hide other stories\' traits',
            style: TextStyle(fontSize: 12),
          ),
          subtitle: const Text(
            '104 of the 244 are story-scoped; the engine refuses the ones '
            'that are not this story\'s.',
            style: TextStyle(fontSize: 10),
          ),
          onChanged: (v) => setState(() => _hideOtherStories = v ?? true),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _message!,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        Text(
          '${catalog.length} shown',
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        for (final t in catalog)
          ListTile(
            dense: true,
            title: Text(
              '${t.name}  ·  ${t.id}',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                _tags(t),
                if (t.description.isNotEmpty)
                  t.description.replaceAll('\n', ' / '),
              ].join('  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Icon(
              s.traits.contains(t.id)
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 20,
            ),
            onTap: () => _toggle(t),
          ),
      ],
    );
  }

  Widget _readout(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );

  String _chipLabel(int id) {
    final trait = game.pack.traits[id];
    final name = trait?.name ?? '$id';
    final days = s.traitDaysLeft[id];
    return days == null ? name : '$name · ${days}d';
  }

  /// The facts about a trait that decide whether it will do anything:
  /// its rank and kind, where it is scoped, how long it lasts, and which of
  /// the effect types it carries.
  String _tags(GameTrait t) {
    final parts = <String>[
      t.type,
      if (t.rank != 'none') t.rank,
      if (t.storyId != null) 'story ${t.storyId}',
      if (t.lifeTimeDays != null) '${t.lifeTimeDays}d',
      if (t.locationIds.isNotEmpty)
        'at ${t.locationIds.map((id) => game.pack.locations[id]?.name ?? id).join('/')}',
      if (t.locationType != null) 'at ${t.locationType} places',
      if (t.effects.isEmpty) 'no effects',
      for (final type in t.effects.map((e) => e['type']).toSet()) '$type',
    ];
    return '[${parts.join(', ')}]';
  }

  String _signed(num v) {
    final rounded = v == v.roundToDouble() ? v.round() : v;
    return v > 0 ? '+$rounded' : '$rounded';
  }

  String _weekday(GameDate date) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][date.day.weekday - 1];
}

class _RulesTab extends StatefulWidget {
  final Game game;
  final PackLocation location;
  final PackReloaded? onReloaded;
  const _RulesTab({
    required this.game,
    required this.location,
    this.onReloaded,
  });

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  late final TextEditingController _controller = TextEditingController(
    text: const JsonEncoder.withIndent(' ').convert(widget.game.pack.rules.raw),
  );
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dir = widget.location.directory;
    if (dir == null) {
      setState(() {
        _error = true;
        _message =
            'This pack is read-only (loaded from bundled assets), so '
            'there is nowhere to save. Run on desktop from the repo, or push '
            'a pack directory to the device.';
      });
      return;
    }
    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('rules.json must be a JSON object');
      }
      parsed = decoded;
    } catch (e) {
      setState(() {
        _error = true;
        _message = 'Not valid JSON: $e';
      });
      return;
    }

    try {
      await ContentSource.writeFile(dir, 'rules.json', parsed);
      final pack = await ContentSource.loadFromDirectory(dir);
      widget.onReloaded?.call(pack, widget.location);
      setState(() {
        _error = false;
        _message =
            'Saved. The new rules apply to the next run you start; '
            'the run in progress keeps the rules it began with.';
      });
    } catch (e) {
      setState(() {
        _error = true;
        _message = 'Could not save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'rules.json — every tuning number. These are this project\'s '
            'model, not recovered from the original (its formulas are '
            'compiled). Change anything.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 12,
                  color: _error
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          PressFeedback(
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save to pack'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PackTab extends StatefulWidget {
  final Game game;
  final PackLocation location;
  final PackReloaded? onReloaded;
  const _PackTab({required this.game, required this.location, this.onReloaded});

  @override
  State<_PackTab> createState() => _PackTabState();
}

class _PackTabState extends State<_PackTab> {
  String? _message;

  Future<void> _reload() async {
    final dir = widget.location.directory;
    if (dir == null) {
      setState(
        () => _message =
            'Nothing to reload: this pack came from the '
            'bundled assets.',
      );
      return;
    }
    try {
      final pack = await ContentSource.loadFromDirectory(dir);
      widget.onReloaded?.call(pack, widget.location);
      setState(
        () => _message =
            'Reloaded from disk. Start a new run to play the reloaded pack.',
      );
    } catch (e) {
      setState(() => _message = 'Reload failed: $e');
    }
  }

  Future<void> _reset() async {
    final dir = widget.location.directory;
    if (dir == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset pack?'),
        content: Text(
          'This overwrites every file in\n${dir.path}\nwith the bundled copy. '
          'Edits you have made there will be lost.',
        ),
        actions: [
          PressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ),
          PressFeedback(
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ContentSource.resetToBundled(dir, widget.location.id);
      final pack = await ContentSource.loadFromDirectory(dir);
      widget.onReloaded?.call(pack, widget.location);
      setState(() => _message = 'Pack reset to the bundled copy.');
    } catch (e) {
      setState(() => _message = 'Reset failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.game.pack;
    final gaps = widget.game.gaps;
    final unknownFuncs = gaps['funcCodes'] ?? const <String>{};
    final unknownTargets = gaps['conditionTargets'] ?? const <String>{};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(context, 'Pack'),
        Text('${pack.manifest.name}  (${pack.manifest.id})'),
        const SizedBox(height: 4),
        SelectableText(
          widget.location.describe,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          '${pack.manifest.totalDays} days × ${pack.manifest.ticksPerDay} ticks\n'
          '${pack.locations.length} locations · ${pack.events.length} events · '
          '${pack.nodes.length} nodes\n'
          '${pack.switchDefaults.length} switches · ${pack.items.length} items · '
          '${pack.traits.length} traits · ${pack.books.length} books',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload from disk'),
            ),
            PressFeedback(
              child: OutlinedButton.icon(
                onPressed: widget.location.directory == null ? null : _reset,
                icon: const Icon(Icons.restore),
                label: const Text('Reset to bundled'),
              ),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _message!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(height: 32),
        _header(context, 'Engine gaps seen this run'),
        Text(
          'Verbs the pack used that this engine has no handler for. They did '
          'nothing. An empty list means the run exercised nothing unsupported '
          '— not that the pack uses nothing unsupported.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (unknownFuncs.isEmpty && unknownTargets.isEmpty)
          const Text('None so far.')
        else ...[
          if (unknownFuncs.isNotEmpty) ...[
            const Text('funcCode:', style: TextStyle(fontSize: 12)),
            SelectableText(
              unknownFuncs.join(', '),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
          if (unknownTargets.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('condition target:', style: TextStyle(fontSize: 12)),
            SelectableText(
              unknownTargets.join(', '),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CopyBlock extends StatelessWidget {
  final String text;
  const _CopyBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 240),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        PressFeedback(
          child: TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
        ),
      ],
    );
  }
}
