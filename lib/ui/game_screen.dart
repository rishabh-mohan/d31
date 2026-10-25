/// The main screen, laid out to match the reference screenshot.
///
/// Top to bottom: top bar (menu / date + D-count / weekday / money + cookies
/// / info), then one big orange panel holding the location banner, the tick
/// dots, the portrait, the goal strips, the subject chips, the status bar,
/// and the action card grid.
library;

import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/content_source.dart';
import '../engine/game.dart';
import '../engine/event_engine.dart';
import '../engine/goals.dart';
import '../engine/pack.dart';
import '../engine/save_store.dart';
import '../engine/state.dart';
import 'csat_screen.dart';
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
import 'portrait.dart';
import 'stamina_bar.dart';
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
    if (game.openingPending) {
      _preparing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _playOpening());
      return;
    }
    if (state.csatPending || _endingsOpen) {
      // A save from the middle of exam day picks the sitting back up.
      _preparing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _resolving = true;
        try {
          await _sitCsat();
        } finally {
          _resolving = false;
        }
      });
      return;
    }
    if (state.dayEndPending) {
      _preparing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _resolving = true;
        try {
          await _runOutcome(ActionOutcome('', dayEnded: true));
        } finally {
          _resolving = false;
        }
      });
      return;
    }
    if (!state.exhaustionPending && state.date.tick == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && game.beginWeeklyStationeryDraw()) {
          await StationeryDraw.show(context, game);
          if (mounted) setState(() {});
        }
        // The first day of a run reaches the hub this way rather than
        // through the rollover, so it is saved here instead.
        await _autoSave();
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

  Future<void> _playOpening() async {
    _resolving = true;
    try {
      await _autoSave();
      while (mounted) {
        final event = game.beginOpeningEvent();
        if (event == null) break;
        if (!mounted) return;
        await _showEvent(event);
        if (!mounted) return;
        await _autoSave();
      }
      if (!mounted) return;
      await DayTransition.show(
        context,
        game: game,
        before: DayTransition.snapshot(state),
        initial: true,
      );
      if (!mounted) return;
      _dayStartStats = DayTransition.snapshot(state);
      _dayStartDate = state.date.day;
      _dayStartCountdown = state.daysRemaining;
      setState(() => _preparing = true);
      await _autoSave();
    } finally {
      _resolving = false;
    }
  }

  Future<void> _showEvent(EventRun event) async {
    await EventScreen.show(context, event);
    while (mounted && !state.finished) {
      final levelUp = game.beginPendingLevelUpEvent();
      if (levelUp == null) break;
      if (!mounted) return;
      await EventScreen.show(context, levelUp);
    }
  }

  Future<void> _drainScheduledEvents() async {
    for (var beats = 0; mounted && beats < 256; beats++) {
      final event = game.nextScheduledEvent();
      if (event == null) break;
      await _showEvent(event);
      if (mounted) setState(() {});
    }
    game.invalidateHand();
  }

  /// Stats as the current day started, for the night screen'"'"'s deltas.
  Map<String, num> _dayStartStats = {};

  Future<void> _runOutcome(ActionOutcome outcome) async {
    for (final event in outcome.beforeEvents) {
      // These level-up runs were already constructed by act(), so draining
      // another pending level here would duplicate a later entry in this list.
      await EventScreen.show(context, event);
      if (!mounted) return;
    }
    if (outcome.exhausted && state.exhaustionPending) {
      setState(() => _exhaustionPresentation = true);
      if (outcome.event != null) {
        await _showEvent(outcome.event!);
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
      await _showEvent(event);
      if (!mounted) return;
      setState(() {});
    }

    await _drainScheduledEvents();
    if (!mounted) return;
    if (state.dayEndPending) {
      if (state.finished) {
        state.dayEndPending = false;
      } else {
        outcome = game.finishPendingDay();
      }
    }

    if (mounted && (state.csatPending || _endingsOpen)) {
      await _sitCsat();
      return;
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
      await _autoSave();
    }
  }

  /// Enrolment has turned the endings on but none has closed the run yet.
  bool get _endingsOpen =>
      !state.finished && state.switchValue('ENDING_CODE') == 1;

  /// The CSAT, the applications, then the ending scenes in turn until one
  /// ends the run (or none claims it, and the admission itself is the end).
  Future<void> _sitCsat() async {
    if (state.csatPending) {
      await CsatScreen.show(context, game);
      if (!mounted) return;
      await _autoSave();
    }
    for (var beats = 0; mounted && !state.finished && beats < 64; beats++) {
      final ending = game.nextEndingEvent();
      if (ending == null) break;
      await _showEvent(ending);
    }
    if (!mounted) return;
    game.concludeRun();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EndScreen(outcome: game.outcome, state: state),
      ),
    );
  }

  /// Each day is written as it begins, once the night screen has been
  /// acknowledged, so a run is never more than one day from where it was.
  /// A run with no slot — a dev-panel run, say — simply has nowhere to go.
  Future<void> _autoSave() async {
    final slot = state.saveSlot;
    if (slot == null) return;
    await SaveStore.write(slot, state);
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
          await _showEvent(run);
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
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => SafeArea(
        // The reference anchors this drawer to the left edge and leaves a
        // strip of the game visible on the right, unlike the centred modals.
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: SizedBox(
              width: (MediaQuery.sizeOf(context).width * .75).clamp(260, 400),
              child: _MenuSheet(
                game: game,
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
            ),
          ),
        ),
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
                                if (_resolving) return;
                                _resolving = true;
                                try {
                                  setState(() {
                                    _dayStartStats = DayTransition.snapshot(
                                      state,
                                    );
                                    _dayStartDate = state.date.day;
                                    _dayStartCountdown = state.daysRemaining;
                                    _preparing = false;
                                  });
                                  final opening = game.beginDay();
                                  if (opening != null || state.csatPending) {
                                    await _runOutcome(
                                      ActionOutcome('', event: opening),
                                    );
                                  }
                                  if (!mounted) return;
                                  if (state.date.isWeekend &&
                                      !state.movementLocked) {
                                    await _pickLocation(
                                      title: 'Where do I go today?',
                                    );
                                  }
                                } finally {
                                  _resolving = false;
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
            children: [
              _PillCell(
                flex: 3,
                cellKey: const ValueKey('header-countdown'),
                child: Text(
                  'D-${state.daysRemaining}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, color: D30Colors.ink),
                ),
              ),
              _PillCell(
                flex: 2,
                cellKey: const ValueKey('header-weekday'),
                child: Text(
                  weekday,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(fontSize: 15, color: D30Colors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Gold, cookies and the info button share one bar, as the reference
        // does: the dividers run the full height and the button is part of it.
        Expanded(
          flex: 6,
          child: _WhitePill(
            children: [
              _PillCell(
                flex: 5,
                cellKey: const ValueKey('header-gold'),
                child: Text(
                  '${state.money.round()} Gold',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: D30Colors.ink),
                ),
              ),
              _PillCell(
                flex: 4,
                cellKey: const ValueKey('header-cookies'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _CookieIcon(size: 17),
                    const SizedBox(width: 4),
                    Text(
                      '${state.cookies}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: D30Colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              _PillButton(
                icon: Icons.info_outline,
                onTap: onInfo,
                tooltip: 'My Info',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A simple drawn cookie, so the bar does not depend on pack art for a piece
/// of permanent chrome.
class _CookieIcon extends StatelessWidget {
  final double size;
  const _CookieIcon({required this.size});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _CookiePainter());
}

class _CookiePainter extends CustomPainter {
  const _CookiePainter();

  static const _dough = Color(0xFFD9A066);
  static const _chip = Color(0xFF5B3A21);

  // Chip positions as fractions of the radius, so they scale with the icon.
  static const _chips = [
    (-0.35, -0.30, 0.17),
    (0.32, -0.12, 0.15),
    (-0.10, 0.12, 0.19),
    (0.18, 0.42, 0.14),
    (-0.42, 0.38, 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final centre = Offset(r, r);
    canvas.drawCircle(centre, r, Paint()..color = _dough);
    final chip = Paint()..color = _chip;
    for (final (dx, dy, radius) in _chips) {
      canvas.drawCircle(centre + Offset(dx * r, dy * r), radius * r, chip);
    }
  }

  @override
  bool shouldRepaint(_CookiePainter oldDelegate) => false;
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: D30Colors.accentDark, offset: Offset(0, 3)),
        ],
      ),
      child: PressFeedback(
        child: Material(
          color: D30Colors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: D30Colors.accentDark, width: 2),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: D30Colors.onAccent, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// One bar of the top HUD.
///
/// The cells butt up against each other and the dividers run edge to edge: the
/// bar used to pad itself, which both left a gap above and below each divider
/// and pushed every cell's contents off the centre of its visible section.
/// Padding therefore belongs to the cells, never to the bar.
class _WhitePill extends StatelessWidget {
  final List<Widget> children;
  const _WhitePill({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: D30Colors.accent, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const _PillDivider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A section of a bar. Its contents are centred on the section itself.
class _PillCell extends StatelessWidget {
  final int flex;
  final Widget child;
  final Key? cellKey;
  const _PillCell({required this.flex, required this.child, this.cellKey});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      key: cellKey,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    ),
  );
}

/// The info button, built into the right end of its bar.
class _PillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _PillButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  // No press motion: it is a cell of the gold/cookie bar, and moving it
  // slid it out of the bar.
  @override
  Widget build(BuildContext context) => Material(
    color: D30Colors.accent,
    child: InkWell(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 44,
          child: Icon(icon, color: D30Colors.onAccent, size: 24),
        ),
      ),
    ),
  );
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 2, color: D30Colors.accent);
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

    return LayoutBuilder(
      builder: (context, constraints) => Container(
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
            // The location art runs the full height of the panel, and the
            // cream island of goals, stats, status and blocks sits over its
            // lower half rather than below it.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: _Portrait(
                        state: state,
                        panelHeight: constraints.maxHeight * .55,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        key: const ValueKey('action-panel'),
                        height: constraints.maxHeight * .55,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: 480,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: D30Colors.panel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: D30Colors.accent,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 5,
                                    offset: Offset(0, 7),
                                  ),
                                ],
                              ),
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
                  height: 24,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : gap),
                  decoration: BoxDecoration(
                    color: i < used
                        ? D30Colors.accent.withValues(alpha: 0.45)
                        : const Color(0xFFF6E4CF),
                    borderRadius: BorderRadius.circular(12),
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
  final double panelHeight;
  const _Portrait({required this.state, required this.panelHeight});

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
            Positioned.fill(
              bottom: panelHeight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                // The portrait canvas has transparent space beneath the torso.
                // Let that lower edge tuck behind the island instead of float.
                // Scaled from the bottom edge to the reference's size (hair
                // ~29% of the screen width at 393dp, crown ~24% down): 12%
                // larger raises the head ~36px, the offset the last ~6
                // (TODO 69). Every character shares one canvas size, so this
                // also lifts the ones that read small, such as the Teacher.
                child: Transform.translate(
                  offset: const Offset(0, 70),
                  child: Transform.scale(
                    scale: 1.12,
                    alignment: Alignment.bottomCenter,
                    child: Portrait(
                      key: const ValueKey('game-character'),
                      pack: state.pack,
                      id: state.characterId,
                      character: true,
                      fallback: state.portrait,
                    ),
                  ),
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
                  // A quieter, greyer card: the reference's is translucent
                  // slate that the scene reads through, not a solid block.
                  color: const Color(0xFF4A4F57).withValues(alpha: 0.55),
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
    return D30Panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      radius: 10,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.track_changes,
                size: 16,
                color: D30Colors.accentDark,
              ),
              const SizedBox(width: 6),
              const Text(
                'Weekly Goals',
                style: TextStyle(fontSize: 11, color: D30Colors.ink),
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
              // The reference keeps the target and reward labels and marks the
              // achieved goal with a check at the far right of the row.
              if (goal.met) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle,
                  key: ValueKey('goal-met-check'),
                  size: 18,
                  color: D30Colors.hpGreen,
                ),
              ],
            ],
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
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 4),
                  ),
                ],
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
          Expanded(child: StaminaBar(pct: pct)),
          const SizedBox(width: 8),
          PressFeedback(
            child: Material(
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
                        color: state.rerolls > 0
                            ? Colors.white
                            : Colors.white70,
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
      padding: const EdgeInsets.fromLTRB(38, 8, 38, 10),
      decoration: BoxDecoration(
        color: D30Colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: D30Colors.panelBorder, width: 1.5),
      ),
      child: Column(
        children: [
          for (var row = 0; row < (actions.length + 1) ~/ 2; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                height: _ActionCard.height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: RepaintBoundary(child: _cardAt(context, row * 2)),
                    ),
                    const SizedBox(width: 18),
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
  static const double height = 146;

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

    return _PressDown(
      onTap: onTap,
      radius: 12,
      edgeColor: _filled
          ? Color.lerp(_fill, Colors.black, .28)!
          : const Color(0xFFF7D4A3),
      child: Material(
        color: _fill,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          button: true,
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

/// The hamburger drawer, laid out like the reference: a red close square over
/// the upper-left corner, restricted Main Menu/Save rows carrying their own
/// explanation, circular ON/OFF settings toggles, then the destinations.
///
/// The three toggles have nothing to drive yet — there is no audio — so they
/// are session-local and say so in their semantics rather than pretending.
class _MenuSheet extends StatefulWidget {
  final Game game;
  final VoidCallback onInventory;
  final VoidCallback onDevPanel;
  final VoidCallback onStore;
  final VoidCallback onStationery;
  final VoidCallback onReset;

  const _MenuSheet({
    required this.game,
    required this.onInventory,
    required this.onDevPanel,
    required this.onStore,
    required this.onStationery,
    required this.onReset,
  });

  /// Whether the drawer offers Store, Stationery and Bags. The 31-Day
  /// campaign reaches all three from the preparation hub instead.
  static const bool campaignShortcuts = false;

  /// Kept outside the widget so a reopened drawer shows the same positions.
  static final Map<String, bool> settings = {
    'Rumble': true,
    'SFX': true,
    'BGM': true,
  };

  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> {
  Game get game => widget.game;

  /// The day has to be over before the original lets you leave or save.
  bool get _dayOver => game.state.date.tick == 0;

  /// Leaving mid-run throws away everything since the last Save, so it asks.
  Future<void> _leave() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave to the main menu?'),
        content: const Text('Anything since your last save is lost.'),
        actions: [
          PressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
          ),
          PressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave'),
            ),
          ),
        ],
      ),
    );
    if (go == true) widget.onReset();
  }

  Future<void> _save() async {
    final slot = game.state.saveSlot;
    if (slot == null) return;
    final ok = await SaveStore.write(slot, game.state);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved to slot ${slot + 1}.' : 'Could not save.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, left: 14),
          child: Material(
            color: D30Colors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: D30Colors.accent, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
              children: [
                _restricted(
                  'Main Menu',
                  'You may leave once the day is over.',
                  onTap: _leave,
                ),
                _restricted(
                  'Save',
                  'You may save once the day is over.',
                  onTap: _save,
                  unavailable: game.state.saveSlot == null
                      ? 'This run has no slot.'
                      : null,
                ),
                for (final name in _MenuSheet.settings.keys) _toggleRow(name),
                // The original's drawer has no Store, Stationery or Bags
                // entry — they are reached from the preparation hub — and no
                // location picker at all. Kept behind a flag because another
                // campaign may well want them.
                if (_MenuSheet.campaignShortcuts) ...[
                  _destination(Icons.card_giftcard, 'Store', widget.onStore),
                  _destination(Icons.edit, 'Stationery', widget.onStationery),
                  _destination(
                    Icons.backpack_outlined,
                    'Bags',
                    widget.onInventory,
                  ),
                ],
                _destination(Icons.tune, 'Dev panel', widget.onDevPanel),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEDB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '30 Days — clean-room rebuild',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: D30Colors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Unlike every other modal here, the close control sits top-left.
        Positioned(
          left: 0,
          top: 0,
          child: PressFeedback(
            child: Material(
              color: D30Colors.alert,
              borderRadius: BorderRadius.circular(10),
              elevation: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context),
                child: const Tooltip(
                  message: 'Close menu',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row({required Widget child}) => Column(
    children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: child),
      Container(height: 2, color: const Color(0x33502B0B)),
    ],
  );

  /// A row the original disables with a coral explanation, not just opacity.
  Widget _restricted(
    String label,
    String reason, {
    VoidCallback? onTap,
    String? unavailable,
  }) {
    final blocked = unavailable != null || !_dayOver;
    return _row(
      child: PressFeedback(
        child: InkWell(
          onTap: blocked ? null : onTap,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    color: blocked ? D30Colors.inkSoft : D30Colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Text(
                  blocked ? (unavailable ?? reason) : '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: D30Colors.alert),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(String name) => _row(
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, color: D30Colors.ink),
          ),
        ),
        for (final on in [true, false]) ...[
          const SizedBox(width: 8),
          _ToggleCircle(
            label: on ? 'ON' : 'OFF',
            selected: _MenuSheet.settings[name] == on,
            onTap: () => setState(() => _MenuSheet.settings[name] = on),
          ),
        ],
      ],
    ),
  );

  Widget _destination(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    String? note,
  }) => _row(
    child: PressFeedback(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 22, color: D30Colors.accentDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  color: onTap == null ? D30Colors.inkSoft : D30Colors.ink,
                ),
              ),
            ),
            if (note != null)
              Flexible(
                child: Text(
                  note,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: D30Colors.alert),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The ON/OFF circles: filled orange when chosen, outlined cream when not.
class _ToggleCircle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleCircle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PressFeedback(
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? D30Colors.accent : D30Colors.panel,
          shape: BoxShape.circle,
          border: Border.all(color: D30Colors.accent, width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : D30Colors.accent,
          ),
        ),
      ),
    ),
  );
}

/// A block that physically presses down.
///
/// At rest the card sits [depth] above its own shadow. While held it moves
/// down by exactly that much and the shadow closes up, so the bottom edge
/// matches the sides and the top never gains a shadow of its own. The
/// movement eases over 70ms in both directions, without scaling the face.
class _PressDown extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color edgeColor;
  final double radius;

  /// How far the block sits above its shadow at rest.
  static const double depth = 7;

  const _PressDown({
    required this.child,
    required this.onTap,
    required this.edgeColor,
    this.radius = 12,
  });

  @override
  State<_PressDown> createState() => _PressDownState();
}

class _PressDownState extends State<_PressDown> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  /// Short enough that a release still reads as simultaneous with the hand
  /// being dealt again, long enough not to be a jump cut.
  static const _travel = Duration(milliseconds: 70);

  @override
  Widget build(BuildContext context) {
    final drop = _down ? _PressDown.depth : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: drop),
        duration: _travel,
        curve: Curves.easeOut,
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, value),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: widget.edgeColor,
                  offset: Offset(0, _PressDown.depth - value),
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
