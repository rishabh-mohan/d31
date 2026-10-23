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

  void close() {
    game.claimStationeryDraw();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: const Color(0xFF16285A),
      body: SafeArea(
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
                    const Text(
                      'Thursday Stationery',
                      style: TextStyle(color: Colors.white, fontSize: 25),
                    ),
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
                                  id: game.state.pendingStationery[index],
                                  item:
                                      game.pack.stationery[game
                                          .state
                                          .pendingStationery[index]]!,
                                  locked: game.state.stationeryLocks.contains(
                                    index,
                                  ),
                                  onTap: () => setState(() {
                                    if (!game.state.stationeryLocks.add(
                                      index,
                                    )) {
                                      game.state.stationeryLocks.remove(index);
                                    }
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: D30Colors.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: D30Colors.accent, width: 3),
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
                            "Tap stationery you'd like to keep before a re-draw.",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cookies Owned: ${game.state.cookies}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
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
                        onPressed:
                            game.state.stationeryLocks.length == 5 ||
                                (game.state.stationeryFreeRedrawUsed &&
                                    game.state.cookies <
                                        game.pack.rules.number(
                                          'stationery',
                                          'redrawCookies',
                                          1,
                                        ))
                            ? null
                            : () => setState(() {
                                game.redrawStationery();
                              }),
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
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
