/// "My Info" — the panel behind the info button.
///
/// Portrait and name, the three levels, gold, the subject stats, the
/// university badges, then traits on the left and equipped stationery on the
/// right. Stationery reflects the live equipped cards; badge slots remain empty.
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'pack_image.dart';
import 'theme.dart';
import 'stationery_card.dart';

class MyInfoPanel extends StatelessWidget {
  final Game game;
  const MyInfoPanel({super.key, required this.game});

  static Future<void> show(BuildContext context, Game game) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => MyInfoPanel(game: game),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = game.state;
    final m = game.pack.manifest;
    final nextStudy = game.pack.studyLevels.nextThresholdAfter(state.studyExp);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      backgroundColor: D30Colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: D30Colors.accent, width: 2.5),
      ),
      // A bounded Column with the list as its flexible child. A Stack here
      // handed the shrink-wrapped ListView unbounded height and it collapsed
      // to nothing, leaving only the barrier on screen.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Info',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: D30Colors.ink,
                    ),
                  ),
                ),
                Material(
                  color: D30Colors.accent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              shrinkWrap: true,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEFDC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 86,
                        height: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const PackImage(
                            path: 'character/portrait.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.fullName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: D30Colors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _line(
                              'LV ${state.studyLevel.level} '
                              '${state.studyLevel.name} '
                              '(${state.studyExp.round()}/${nextStudy?.round() ?? 'MAX'})',
                            ),
                            _line('${state.money.round()} Gold'),
                            _line(
                              'Exercise Level ${state.exerciseLevel.level} '
                              '(${_pct(game, exercise: true)})',
                            ),
                            _line(
                              'Part-Time Level ${state.partTimeLevel.level} '
                              '(${_pct(game, exercise: false)})',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < m.subjects.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: D30Colors.subject(m.subjects[i]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                child: Text(
                                  subjectLabel(m.subjects[i]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: D30Colors.ink,
                                  ),
                                ),
                              ),
                              Text(
                                '${(state.stats[m.subjects[i]] ?? 0).round()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: D30Colors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: D30Colors.ink, thickness: 1),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Traits',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: D30Colors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (state.traits.isEmpty)
                            const Text(
                              '-',
                              style: TextStyle(
                                fontSize: 16,
                                color: D30Colors.inkSoft,
                              ),
                            )
                          else
                            for (final id in state.traits)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: D30Chip(
                                  text: game.pack.traits[id]?.name ?? '$id',
                                  color: const Color(0xFF66BB6A),
                                  textColor: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 180,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: D30Colors.ink,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Stationery',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: D30Colors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Plain rows, not a GridView: this sits next to a
                          // sibling in a Row, and a scrollable has no
                          // intrinsic height, which threw on every frame and
                          // left the dialog blank.
                          _SlotRow(game: game, left: 'pencil', right: 'eraser'),
                          const SizedBox(height: 8),
                          _SlotRow(
                            game: game,
                            left: 'note',
                            right: 'markingPen',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, color: D30Colors.ink),
    ),
  );

  static String _pct(Game game, {required bool exercise}) {
    final table = exercise
        ? game.pack.exerciseLevels
        : game.pack.partTimeLevels;
    final exp = exercise ? game.state.exerciseExp : game.state.partTimeExp;
    final tier = table.tierFor(exp);
    final next = table.nextThresholdAfter(exp);
    if (next == null || next <= tier.exp) return '100.0%';
    final f = (exp - tier.exp) / (next - tier.exp) * 100;
    return '${f.toStringAsFixed(1)}%';
  }
}

/// Two slots side by side.
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
