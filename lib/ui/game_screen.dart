/// The main screen, laid out to match the reference screenshot.
///
/// Top to bottom: top bar (menu / date + D-count / weekday / money + cookies
/// / info), then one big orange panel holding the location banner, the tick
/// dots, the portrait, the goal strips, the subject chips, the status bar,
/// and the action card grid.
library;

import 'package:flutter/material.dart';

import '../engine/content_source.dart';
import '../engine/game.dart';
import '../engine/goals.dart';
import '../engine/pack.dart';
import '../engine/state.dart';
import 'dev_panel.dart';
import 'end_screen.dart';
import 'event_screen.dart';
import 'day_transition.dart';
import 'stationery_draw.dart';
import 'day_menu.dart';
import 'commerce_screen.dart';
import 'my_info.dart';
import 'location_picker.dart';
import 'pack_image.dart';
import 'theme.dart';

typedef PackReloaded = void Function(ContentPack pack, PackLocation location);

class GameScreen extends StatefulWidget {
  final Game game;
  final PackLocation packLocation;
  final PackReloaded? onPackReloaded;

  const GameScreen({
    super.key,
    required this.game,
    required this.packLocation,
    this.onPackReloaded,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Game get game => widget.game;
  GameState get state => game.state;
  bool _preparing = true;
  bool _resolving = false;
  bool _exhaustionPresentation = false;
  late DateTime _dayStartDate;
  late int _dayStartCountdown;

  @override
  void initState() {
    super.initState();
    PackImages.use(widget.packLocation);
    _preparing = !state.exhaustionPending && state.date.tick == 0;
    _dayStartStats = DayTransition.snapshot(state);
    _dayStartDate = state.date.day;
    _dayStartCountdown = state.daysRemaining;
    if (!state.exhaustionPending && state.date.tick == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && game.beginWeeklyStationeryDraw()) {
          await StationeryDraw.show(context, game);
          if (mounted) setState(() {});
        }
      });
    }
    if (state.exhaustionPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _resolving = true;
        try {
          await _runOutcome(
            ActionOutcome(
              'Too tired to act.',
              exhausted: true,
              event: game.beginExhaustionEvent(),
            ),
          );
        } finally {
          _resolving = false;
        }
      });
    }
  }

  GameBook? _bookFor(int index, LocationAction action) =>
      game.bookForSlot(index);

  /// Stats as the current day started, for the night screen'"'"'s deltas.
  Map<String, num> _dayStartStats = {};

  Future<void> _runOutcome(ActionOutcome outcome) async {
    for (final event in outcome.beforeEvents) {
      await EventScreen.show(context, event);
      if (!mounted) return;
    }
    if (outcome.exhausted && state.exhaustionPending) {
      setState(() => _exhaustionPresentation = true);
      if (outcome.event != null) {
        await EventScreen.show(context, outcome.event!);
      }
      if (!mounted) return;
      while (state.date.tick < game.actionTicksPerDay) {
        // Reconstructed presentation timing; the global event supplies wording.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        game.advanceExhaustedTick();
        setState(() {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _runOutcome(game.finishExhaustedDay());
      return;
    }
    setState(() {});

    final event = outcome.event;
    if (event != null) {
      await EventScreen.show(context, event);
      if (!mounted) return;
      setState(() {});
    }

    if (state.finished && mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EndScreen(outcome: game.outcome, state: state),
        ),
      );
      return;
    }

    if (outcome.dayEnded && mounted) {
      await DayTransition.show(
        context,
        game: game,
        before: _dayStartStats,
        completedDay: _dayStartDate,
        countdown: _dayStartCountdown,
      );
      if (!mounted) return;
      if (game.beginWeeklyStationeryDraw()) {
        await StationeryDraw.show(context, game);
        if (!mounted) return;
      }
      _dayStartStats = DayTransition.snapshot(state);
      _dayStartDate = state.date.day;
      _dayStartCountdown = state.daysRemaining;
      _preparing = true;
      _exhaustionPresentation = false;
      setState(() {});
    }
  }

  void _refresh() {
    if (game.refreshHand()) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refresh unavailable — no Refresh Tickets.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _act(int index, LocationAction action) async {
    if (_resolving || _preparing) return;
    _resolving = true;
    try {
      final wasInClass = game.inClass;
      final book = action.actionType == 'study'
          ? _bookFor(index, action)
          : null;
      await _runOutcome(game.act(action, book: book, deferExhaustion: true));
      if (!mounted) return;

      // The moment class lets out, the original asks where you are going.
      if (!_preparing && wasInClass && !game.inClass && !game.state.finished) {
        await _pickLocation(title: 'Class is over. Where do I go?');
      }
    } finally {
      _resolving = false;
    }
  }

  Future<void> _pickLocation({String title = 'Where do I go?'}) async {
    final chosen = await LocationPicker.show(
      context,
      game: game,
      title: title,
      dismissible: true,
    );
    if (!mounted) return;
    if (chosen != null) setState(() => game.move(chosen));
  }

  Future<void> _openDevPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DevPanel(
        game: game,
        packLocation: widget.packLocation,
        onPackReloaded: widget.onPackReloaded,
        onStateChanged: () => setState(() {}),
        playEvent: (run) async {
          await EventScreen.show(context, run);
          if (mounted) setState(() {});
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openInventory() async {
    await Navigator.of(context)
        .push(CommerceScreen.route(game, menu: PackMenu.items));
    if (mounted) setState(() {});
  }

  Future<void> _openCommerce({bool stationery = false}) async {
    await Navigator.of(context).push(
      CommerceScreen.route(
        game,
        menu: stationery ? PackMenu.stationery : PackMenu.shop,
      ),
    );
    if (mounted) setState(() {});
  }

  /// Moving is not in the reference layout's main screen; it lives behind the
  /// menu button until the real navigation is specified.
  Future<void> _openMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MenuSheet(
        game: game,
        onMove: () {
          Navigator.of(context).pop();
          _pickLocation();
        },
        onInventory: () {
          Navigator.of(context).pop();
          _openInventory();
        },
        onStore: () {
          Navigator.pop(context);
          _openCommerce();
        },
        onStationery: () {
          Navigator.pop(context);
          _openCommerce(stationery: true);
        },
        onReset: () {
          Navigator.pop(context);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        onDevPanel: () {
          Navigator.of(context).pop();
          _openDevPanel();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actions = _preparing || _exhaustionPresentation
        ? <LocationAction>[]
        : game.hand();

    return Scaffold(
      backgroundColor: D30Colors.page,
      body: AbsorbPointer(
        absorbing: _exhaustionPresentation || state.exhaustionPending,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  children: [
                    _TopBar(
                      state: state,
                      onMenu: _openMenu,
                      onInfo: () => MyInfoPanel.show(context, game),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _preparing
                          ? DayMenu(
                              game: game,
                              onStart: () async {
                                setState(() {
                                  _dayStartStats = DayTransition.snapshot(
                                    state,
                                  );
                                  _dayStartDate = state.date.day;
                                  _dayStartCountdown = state.daysRemaining;
                                  _preparing = false;
                                });
                                if (state.date.isWeekend) {
                                  await _pickLocation(
                                    title: 'Where do I go today?',
                                  );
                                }
                              },
                            )
                          : _MainPanel(
                              game: game,
                              exhausted:
                                  _exhaustionPresentation ||
                                  state.exhaustionPending,
                              actions: actions,
                              bookFor: _bookFor,
                              onAct: _act,
                              onRefresh: _refresh,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final GameState state;
  final VoidCallback onMenu;
  final VoidCallback onInfo;

  const _TopBar({
    required this.state,
    required this.onMenu,
    required this.onInfo,
  });

  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ];

  @override
  Widget build(BuildContext context) {
    final day = state.date.day;
    final weekday = _weekdays[(day.weekday - 1) % 7];

    return Row(
      children: [
        _SquareButton(icon: Icons.menu, onTap: onMenu),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: _WhitePill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    key: const ValueKey('header-countdown'),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'D-${state.daysRemaining}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: D30Colors.ink,
                      ),
                    ),
                  ),
                ),
                const _PillDivider(),
                Expanded(
                  flex: 2,
                  child: FittedBox(
                    key: const ValueKey('header-weekday'),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      weekday,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: D30Colors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 5,
          child: _WhitePill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: FittedBox(
                    key: const ValueKey('header-gold'),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${state.money.round()} Gold',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: D30Colors.ink,
                      ),
                    ),
                  ),
                ),
                const _PillDivider(),
                Expanded(
                  flex: 4,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: PackImage(
                            path: 'ui/cookie.png',
                            fit: BoxFit.contain,
                            placeholder: const Icon(
                              Icons.cookie,
                              size: 15,
                              color: D30Colors.coin,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${state.cookies}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: D30Colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _SquareButton(icon: Icons.info_outline, onTap: onInfo, circular: true),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool circular;

  const _SquareButton({
    required this.icon,
    required this.onTap,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(circular ? 24 : 12);
    return Material(
      color: D30Colors.accent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 56,
          child: Icon(icon, color: D30Colors.onAccent, size: 22),
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  final Widget child;
  const _WhitePill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: D30Colors.accent, width: 2),
      ),
      child: child,
    );
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 2, height: 40, color: D30Colors.accent);
}

// ---------------------------------------------------------------------------
// The orange panel that holds everything else
// ---------------------------------------------------------------------------

class _MainPanel extends StatelessWidget {
  final Game game;
  final bool exhausted;
  final List<LocationAction> actions;
  final GameBook? Function(int, LocationAction) bookFor;
  final Future<void> Function(int, LocationAction) onAct;
  final VoidCallback onRefresh;

  const _MainPanel({
    required this.game,
    this.exhausted = false,
    required this.actions,
    required this.bookFor,
    required this.onAct,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final state = game.state;
    final here = state.location;
    final weekly = state.weeklyGoal;

    return Container(
      decoration: BoxDecoration(
        color: D30Colors.accent,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Location banner
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                here?.name ?? '-',
                style: const TextStyle(
                  color: D30Colors.onAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _TickDots(
            state: state,
            total: game.actionTicksPerDay,
            filled: exhausted && !state.exhaustionPending
                ? game.actionTicksPerDay
                : null,
          ),
          const SizedBox(height: 6),
          Expanded(child: RepaintBoundary(child: _Portrait(state: state))),
          const SizedBox(height: 6),
          SizedBox(
            height: 330,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 480,
                child: Column(
                  children: [
                    if (weekly != null) ...[
                      _GoalStrip(goal: weekly, state: state),
                      const SizedBox(height: 4),
                    ],
                    _SubjectChips(state: state),
                    const SizedBox(height: 4),
                    _StatusBar(
                      state: state,
                      actionTicks: game.actionTicksPerDay,
                      onRefresh: onRefresh,
                    ),
                    const SizedBox(height: 6),
                    _ActionGrid(
                      game: game,
                      exhausted: exhausted,
                      actions: actions,
                      bookFor: bookFor,
                      onAct: onAct,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's action slots, one dot each.
class _TickDots extends StatelessWidget {
  final GameState state;
  final int total;
  final int? filled;
  const _TickDots({required this.state, required this.total, this.filled});

  @override
  Widget build(BuildContext context) {
    final used = (filled ?? state.date.tick).clamp(0, total);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: D30Colors.panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Shrink the dots rather than overflow when ticksPerDay is raised.
          final gap = 3.0;
          final size = ((constraints.maxWidth - gap * (total - 1)) / total)
              .clamp(4.0, 18.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                Container(
                  key: ValueKey('day-tick-$i-${i < used ? 'filled' : 'empty'}'),
                  width: size,
                  height: size,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : gap),
                  decoration: BoxDecoration(
                    color: i < used
                        ? D30Colors.accent.withValues(alpha: 0.45)
                        : const Color(0xFFF6E4CF),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Location background, character, level box, and the satiety pips.
class _Portrait extends StatelessWidget {
  final GameState state;
  const _Portrait({required this.state});

  @override
  Widget build(BuildContext context) {
    final here = state.location;
    final nextThreshold = state.pack.studyLevels.nextThresholdAfter(
      state.studyExp,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PackImage(
              path: here?.image,
              placeholder: const ColoredBox(color: Color(0xFFBFD4E6)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.92,
                child: PackImage(
                  path: 'character/portrait.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  placeholder: const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: D30Colors.levelBox.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'LV ${state.studyLevel.level} ${state.studyLevel.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${state.studyExp.round()} / ${nextThreshold?.round() ?? 'MAX'}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "This week's goal  [KOR 348+] -> [ENG 258]"
class _GoalStrip extends StatelessWidget {
  final WeeklyGoal goal;
  final GameState state;
  const _GoalStrip({required this.goal, required this.state});

  @override
  Widget build(BuildContext context) {
    final current = state.stats[goal.targetSubject] ?? 0;
    final progress = goal.progressFrom(current);

    return D30Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      radius: 10,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                goal.met ? Icons.check_circle : Icons.track_changes,
                size: 16,
                color: goal.met ? D30Colors.hpGreen : D30Colors.accentDark,
              ),
              const SizedBox(width: 6),
              Text(
                goal.met ? 'Goal met' : 'Weekly Goals',
                style: const TextStyle(fontSize: 11, color: D30Colors.ink),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      D30Chip(
                        text:
                            '${subjectLabel(goal.targetSubject)} Reach ${goal.targetValue}',
                        color: D30Colors.subject(goal.targetSubject),
                        fontSize: 11,
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_right_alt,
                        size: 16,
                        color: D30Colors.inkSoft,
                      ),
                      const SizedBox(width: 6),
                      D30Chip(
                        text:
                            '${subjectLabel(goal.rewardSubject)} Reward ${goal.rewardValue}',
                        color: D30Colors.subject(goal.rewardSubject),
                        fontSize: 11,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: D30Colors.hpTrack,
              valueColor: AlwaysStoppedAnimation(
                goal.met ? D30Colors.hpGreen : D30Colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The row of coloured subject tiles.
class _SubjectChips extends StatelessWidget {
  final GameState state;
  const _SubjectChips({required this.state});

  @override
  Widget build(BuildContext context) {
    final subjects = state.pack.manifest.subjects;
    return Row(
      children: [
        for (var i = 0; i < subjects.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: D30Colors.subject(subjects[i]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  FittedBox(
                    child: Text(
                      subjectLabel(subjects[i]),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: D30Colors.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${(state.stats[subjects[i]] ?? 0).round()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: D30Colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ticks left · stamina bar · rerolls.
class _StatusBar extends StatelessWidget {
  final GameState state;
  final int actionTicks;
  final VoidCallback onRefresh;
  const _StatusBar({
    required this.state,
    required this.actionTicks,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final ticksLeft = (actionTicks - state.date.tick).clamp(0, actionTicks);
    final pct = state.hpMax == 0
        ? 0.0
        : (state.hp / state.hpMax).clamp(0, 1).toDouble();

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: D30Colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: D30Colors.panelBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: D30Colors.ink),
                const SizedBox(width: 4),
                Text(
                  '$ticksLeft',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: D30Colors.ink,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1.5, height: 34, color: D30Colors.panelBorder),
          const SizedBox(width: 8),
          const Icon(Icons.favorite, size: 15, color: Color(0xFF3A2E24)),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: D30Colors.hpTrack,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(color: D30Colors.hpGreen),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${(pct * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: D30Colors.accent,
            child: InkWell(
              onTap: state.rerolls > 0 ? onRefresh : null,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 15,
                      color: state.rerolls > 0 ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.rerolls}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
// Action cards
// ---------------------------------------------------------------------------

class _ActionGrid extends StatelessWidget {
  final Game game;
  final bool exhausted;
  final List<LocationAction> actions;
  final GameBook? Function(int, LocationAction) bookFor;
  final Future<void> Function(int, LocationAction) onAct;

  const _ActionGrid({
    required this.game,
    this.exhausted = false,
    required this.actions,
    required this.bookFor,
    required this.onAct,
  });

  @override
  Widget build(BuildContext context) {
    if (exhausted) {
      return Semantics(
        label: 'Activities unavailable: exhausted',
        child: Container(
          key: const ValueKey('exhausted-blocks'),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: D30Colors.panel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var row = 0; row < 2; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    height: _ActionCard.height,
                    child: Row(
                      children: [
                        for (var col = 0; col < 2; col++)
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(left: col == 0 ? 0 : 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2DFC6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: D30Colors.panelBorder,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (actions.isEmpty) {
      return const D30Panel(
        padding: EdgeInsets.all(18),
        child: Center(
          child: Text(
            'Nothing available here right now.',
            style: TextStyle(fontSize: 12, color: D30Colors.ink),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: D30Colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: D30Colors.panelBorder, width: 1.5),
      ),
      child: Column(
        children: [
          for (var row = 0; row < (actions.length + 1) ~/ 2; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: _ActionCard.height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: RepaintBoundary(child: _cardAt(context, row * 2)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: row * 2 + 1 < actions.length
                          ? RepaintBoundary(
                              child: _cardAt(context, row * 2 + 1),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardAt(BuildContext context, int index) {
    final action = actions[index];
    final book = action.actionType == 'study' ? bookFor(index, action) : null;
    return _ActionCard(
      preview: game.preview(action, book: book),
      onTap: () => onAct(index, action),
    );
  }
}

class _ActionCard extends StatelessWidget {
  /// Fixed so a lesson, a textbook and a workout card all line up.
  static const double height = 132;

  final ActionPreview preview;
  final VoidCallback onTap;

  const _ActionCard({required this.preview, required this.onTap});

  bool get _filled =>
      preview.kind == ActionKind.partTimeJob ||
      preview.kind == ActionKind.exercise ||
      preview.kind == ActionKind.sleep;

  /// Study shows how far through its book it is; the two level-driven cards
  /// always show their progress to the next tier, even at zero. A finished
  /// book shows [_readingComplete] instead.
  bool get _showsProgress =>
      !preview.bookComplete &&
      (preview.kind == ActionKind.partTimeJob ||
          preview.kind == ActionKind.exercise ||
          preview.progress > 0 ||
          preview.showCoin);

  /// Sleep and the two level cards carry no subject/rank row, so their title
  /// should sit centred rather than leaving a gap where the row would be.
  bool get _hasBodyRow =>
      preview.kind != ActionKind.partTimeJob &&
      preview.kind != ActionKind.exercise &&
      preview.kind != ActionKind.sleep;

  Color get _fill {
    switch (preview.kind) {
      case ActionKind.partTimeJob:
        return const Color(0xFFA8AF35);
      case ActionKind.exercise:
        return D30Colors.exercise;
      case ActionKind.sleep:
        return const Color(0xFF1F3368);
      case ActionKind.lesson:
        return const Color(0xFFFFE9CE);
      default:
        return const Color(0xFFFFF1E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onFill = _filled ? Colors.white : D30Colors.ink;

    return Material(
      color: _fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _filled
                  ? Colors.black.withValues(alpha: 0.12)
                  : D30Colors.panelBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _title(onFill),
              if (_hasBodyRow) _body(onFill),
              if (preview.bookComplete)
                _readingComplete()
              else if (_showsProgress)
                _progressBar(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite,
                    size: 14,
                    color: _filled ? Colors.white : const Color(0xFF3A2E24),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    preview.kind == ActionKind.sleep
                        ? '+${preview.gain ?? 0}'
                        : '-${_trim(preview.hpCost)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: onFill,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(Color color) {
    switch (preview.kind) {
      case ActionKind.partTimeJob:
        return Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${preview.money ?? 0} Gold',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preview.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ],
        );
      case ActionKind.exercise:
        return Column(
          children: [
            const Icon(Icons.fitness_center, size: 22, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              preview.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        );

      case ActionKind.sleep:
        return Column(
          children: [
            const Icon(Icons.bedtime, size: 22, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              preview.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        );
      case ActionKind.lesson:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.co_present, size: 16, color: D30Colors.ink),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                preview.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        );

      default:
        return Text(
          preview.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        );
    }
  }

  Widget _body(Color color) {
    final gain = preview.gain;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (preview.subject != null) ...[
          D30Chip(
            text: subjectLabel(preview.subject!),
            color: D30Colors.subject(preview.subject!),
            fontSize: 11,
          ),
          const SizedBox(width: 4),
        ],
        if (preview.rank != null) ...[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFD9D9D9),
              shape: BoxShape.circle,
            ),
            child: Text(
              preview.rank!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: D30Colors.ink,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        if (gain != null)
          Flexible(
            child: Text(
              preview.gainMax != null && preview.gainMax != gain
                  ? '+$gain~${preview.gainMax}'
                  : '+$gain',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
      ],
    );
  }

  /// The pink line a read-through book carries in place of its bar.
  Widget _readingComplete() => const Text(
    'Reading Complete',
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFFE2566B),
    ),
  );

  Widget _progressBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              // On the filled cards a translucent track vanished against the
              // background; use a solid dark track so the bar always reads.
              color: _filled ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _filled ? Colors.white : D30Colors.panelBorder,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: preview.progress.clamp(0, 1),
              child: Container(color: _filled ? Colors.white : D30Colors.coin),
            ),
          ),
        ),
        if (preview.showCoin) ...[
          const SizedBox(width: 4),
          Container(
            width: 11,
            height: 11,
            decoration: const BoxDecoration(
              color: D30Colors.coin,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  static String _trim(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------

class _MenuSheet extends StatelessWidget {
  final Game game;
  final VoidCallback onMove;
  final VoidCallback onInventory;
  final VoidCallback onDevPanel;
  final VoidCallback onStore;
  final VoidCallback onStationery;
  final VoidCallback onReset;

  const _MenuSheet({
    required this.game,
    required this.onMove,
    required this.onInventory,
    required this.onDevPanel,
    required this.onStore,
    required this.onStationery,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.map_outlined),
            title: const Text('Go to'),
            subtitle: Text(game.state.location?.name ?? '-'),
            onTap: game.inClass ? null : onMove,
          ),
          if (game.inClass || game.state.movementLocked)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '  You cannot leave right now.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const Divider(height: 28),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Store'),
            onTap: onStore,
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Stationery'),
            onTap: onStationery,
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Reset / Main Menu'),
            onTap: onReset,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.backpack_outlined),
            title: const Text('Inventory'),
            onTap: onInventory,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.tune),
            title: const Text('Dev panel'),
            onTap: onDevPanel,
          ),
        ],
      ),
    );
  }
}
