/// Fixed reference-sized My Info panel, fitted to the available viewport.
library;

import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/state.dart';
import 'portrait.dart';
import 'theme.dart';
import 'transitions.dart';
import 'stationery_card.dart';
import 'university_badge.dart';

class MyInfoPanel extends StatelessWidget {
  final Game game;
  const MyInfoPanel({super.key, required this.game});

  /// Fades in (TODO 79) rather than popping up.
  static Future<void> show(BuildContext context, Game game) =>
      showFadeDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .4),
        builder: (_) => MyInfoPanel(game: game),
      );

  @override
  Widget build(BuildContext context) {
    final state = game.state;
    final next = game.pack.studyLevels.nextThresholdAfter(state.studyExp);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 390,
          height: 660,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: D30Colors.ink, fontSize: 14),
            child: Container(
              decoration: BoxDecoration(
                color: D30Colors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: D30Colors.accent, width: 3),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const SizedBox(width: 44),
                        const Expanded(
                          child: Text(
                            'My Info',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26),
                          ),
                        ),
                        PressFeedback(
                          child: IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: D30Colors.accent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEDB),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 104,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Portrait(
                                    pack: game.pack,
                                    id: state.characterId,
                                    character: true,
                                    fallback: state.portrait,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.fullName,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        Text(
                                          'LV ${state.studyLevel.level} ${state.studyLevel.name} (${state.studyExp.round()}/${next?.round() ?? 'MAX'})',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          '${state.money.round()} Gold',
                                          style: const TextStyle(fontSize: 17),
                                        ),
                                        Text(
                                          'Exercise Level ${state.exerciseLevel.level} (${_pct(game, exercise: true)})',
                                        ),
                                        Text(
                                          'Part-Time Level ${state.partTimeLevel.level} (${_pct(game, exercise: false)})',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 46,
                            child: Row(
                              children: [
                                for (final subject
                                    in game.pack.manifest.subjects)
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: D30Colors.subject(subject),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FittedBox(
                                            child: Text(
                                              subjectLabel(subject),
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${state.stats[subject]?.round() ?? 0}',
                                              maxLines: 1,
                                              style: const TextStyle(
                                                fontSize: 15,
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
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: UniversityBadgeSlots(
                              pack: game.pack,
                              ids: state.badgeIds,
                            ),
                          ),
                          const Divider(color: D30Colors.ink, thickness: 1.5),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Traits',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.topCenter,
                                          child: Column(
                                            children: [
                                              if (state.traits.isEmpty)
                                                const Text('—'),
                                              for (final id in state.traits)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 2,
                                                      ),
                                                  child: D30Chip(
                                                    text: _traitLabel(
                                                      game,
                                                      state,
                                                      id,
                                                    ),
                                                    color: traitColor(
                                                      game
                                                          .pack
                                                          .traits[id]
                                                          ?.type,
                                                    ),
                                                    textColor: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const VerticalDivider(
                                  color: D30Colors.ink,
                                  width: 14,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Stationery',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: _SlotRow(
                                          game: game,
                                          left: 'pencil',
                                          right: 'eraser',
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: _SlotRow(
                                          game: game,
                                          left: 'note',
                                          right: 'markingPen',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  static String _pct(Game game, {required bool exercise}) {
    final table = exercise
        ? game.pack.exerciseLevels
        : game.pack.partTimeLevels;
    final exp = exercise ? game.state.exerciseExp : game.state.partTimeExp;
    final tier = table.tierFor(exp);
    final next = table.nextThresholdAfter(exp);
    if (next == null || next <= tier.exp) return '100.0%';
    return '${((exp - tier.exp) / (next - tier.exp) * 100).toStringAsFixed(1)}%';
  }
}

/// Two slots side by side.
/// A trait's chip text: its name, plus the days left when it is one of the
/// nine temporary ones (Flu 4, Fever Time 2, Hemorrhoids 5).
String _traitLabel(Game game, GameState state, int id) {
  final name = game.pack.traits[id]?.name ?? '$id';
  final left = state.traitDaysLeft[id];
  return left == null ? name : '$name ($left d)';
}

class _SlotRow extends StatelessWidget {
  final Game game;
  final String left;
  final String right;
  const _SlotRow({required this.game, required this.left, required this.right});

  Widget slot(String type) {
    final id = game.state.equippedStationery[type];
    return id == null
        ? _StationerySlot(label: stationeryTypeLabel(type))
        : StationeryCard(id: id, item: game.pack.stationery[id]!);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 115,
      child: Row(
        children: [
          Expanded(child: slot(left)),
          const SizedBox(width: 8),
          Expanded(child: slot(right)),
        ],
      ),
    );
  }
}

/// An empty equipment slot when no item of this type is equipped.
class _StationerySlot extends StatelessWidget {
  final String label;
  const _StationerySlot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const Expanded(child: ColoredBox(color: Color(0xFFD9D9D9))),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
