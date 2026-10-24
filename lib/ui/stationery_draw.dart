/// The weekly stationery draw.
///
/// The reference has two states on one dark, glowing stage. The cards first
/// *roll* — they cycle continuously under a "Tap on a stationery to obtain
/// them." line and a `Stop all Stationery` button — and only once stopped do
/// the kept/redraw controls appear. The rolling is presentation only: the
/// hand itself was already drawn by `beginWeeklyStationeryDraw`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'stationery_card.dart';
import 'theme.dart';

class StationeryDraw extends StatefulWidget {
  final Game game;
  const StationeryDraw({super.key, required this.game});

  static Future<void> show(BuildContext context, Game game) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => StationeryDraw(game: game)));

  @override
  State<StationeryDraw> createState() => _StationeryDrawState();
}

class _StationeryDrawState extends State<StationeryDraw> {
  Game get game => widget.game;

  /// How fast the faces cycle. The still frames cannot establish this; it is
  /// chosen to read as motion without strobing.
  static const _rollInterval = Duration(milliseconds: 45);

  Timer? _roll;
  int _frame = 0;
  bool _rolling = true;

  late final List<int> _faces = game.pack.stationery.keys.toList();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _roll?.cancel();
    super.dispose();
  }

  void _start() {
    _roll = Timer.periodic(_rollInterval, (_) {
      if (!mounted) return;
      setState(() => _frame++);
    });
  }

  /// Stops every card at once. A tap on a card does the same thing as the
  /// button: the captures do not establish a per-card stopping order, so none
  /// is invented here.
  void _stop() {
    _roll?.cancel();
    _roll = null;
    setState(() => _rolling = false);
  }

  void _redraw() {
    setState(() {
      game.redrawStationery();
      _rolling = true;
      _frame = 0;
    });
    _start();
  }

  void close() {
    _roll?.cancel();
    game.claimStationeryDraw();
    Navigator.pop(context);
  }

  /// The face a slot shows right now: a cycling one while rolling, the real
  /// drawn card once stopped. A locked card never rolls.
  int _cardAt(int index) {
    if (!_rolling || game.state.stationeryLocks.contains(index)) {
      return game.state.pendingStationery[index];
    }
    return _faces[(_frame + index * 7) % _faces.length];
  }

  bool get _canRedraw =>
      game.state.stationeryLocks.length != 5 &&
      !(game.state.stationeryFreeRedrawUsed &&
          game.state.cookies <
              game.pack.rules.number('stationery', 'redrawCookies', 1));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: const Color(0xFF14110F),
      body: DecoratedBox(
        // A pale glow sits behind the card group on the charcoal vignette.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.35),
            radius: .85,
            colors: [Color(0x33FFFFFF), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 390,
                height: 840,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      for (final indexes in [
                        const [0, 1, 2],
                        const [3, 4],
                      ]) ...[
                        SizedBox(
                          height: 178,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final index in indexes)
                                SizedBox(
                                  width: 105,
                                  child: StationeryCard(
                                    key: ValueKey('draw-card-$index'),
                                    id: _cardAt(index),
                                    item: game.pack.stationery[_cardAt(index)]!,
                                    locked: game.state.stationeryLocks.contains(
                                      index,
                                    ),
                                    onTap: () => _rolling
                                        ? _stop()
                                        : setState(() {
                                            if (!game.state.stationeryLocks.add(
                                              index,
                                            )) {
                                              game.state.stationeryLocks.remove(
                                                index,
                                              );
                                            }
                                          }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (_rolling) ...[
                        const Spacer(),
                        const Text(
                          'Tap on a stationery to obtain them.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 19),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 260,
                          height: 52,
                          child: FilledButton(
                            key: const ValueKey('stop-all-stationery'),
                            style: FilledButton.styleFrom(
                              backgroundColor: D30Colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _stop,
                            child: const Text(
                              'Stop all Stationery',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: D30Colors.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: D30Colors.accent,
                              width: 3,
                            ),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'Re-draw: B-Tier and above guaranteed',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: D30Colors.alert,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Tap on stationery you'd like to keep before a "
                                're-draw.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cookies Owned : ${game.state.cookies}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 240,
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: D30Colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _canRedraw ? _redraw : null,
                            child: Text(
                              game.state.stationeryFreeRedrawUsed
                                  ? 'Re-draw · ${game.pack.rules.number('stationery', 'redrawCookies', 1)} Cookie'
                                  : 'Free re-draw',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 240,
                          height: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: D30Colors.panel,
                              foregroundColor: D30Colors.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: close,
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
