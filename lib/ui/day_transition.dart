/// The night screen between days.
///
/// A navy page with a moon, the countdown and weekday, the week's goal and
/// the subject stats — with the deltas earned that day underneath — and a
/// green play button to start the next day.
library;

import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/state.dart';
import 'theme.dart';

class DayTransition extends StatelessWidget {
  final Game game;

  /// Stats as they were when the day began, so the gains can be shown.
  final Map<String, num> before;
  final DateTime? completedDay;
  final int? countdown;

  /// The handoff straight after setup, before the day has been played. The
  /// reference shows a dash where the goal row normally is: the objective is
  /// announced afterwards, over the preparation hub, not here.
  final bool initial;

  const DayTransition({
    super.key,
    required this.game,
    required this.before,
    this.completedDay,
    this.countdown,
    this.initial = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Game game,
    required Map<String, num> before,
    DateTime? completedDay,
    int? countdown,
    bool initial = false,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => DayTransition(
          game: game,
          before: before,
          completedDay: completedDay,
          countdown: countdown,
          initial: initial,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final state = game.state;
    final subjects = game.pack.manifest.subjects;
    final weekday =
        _weekdayNames[((completedDay ?? state.date.day).weekday - 1) % 7];
    final goal = initial ? null : state.weeklyGoal;

    return Scaffold(
      backgroundColor: const Color(0xFF152757),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.nightlight_round,
                    size: 64,
                    color: Color(0xFFC9D4EA),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'D-${countdown ?? state.daysRemaining}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekday,
                    style: const TextStyle(fontSize: 26, color: Colors.white),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFE4F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1.5),
                      // The reference card is raised off the navy, not flat.
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // UIR-08/19: one compact header row — the label, then
                        // the target and reward on the same line, or a dash
                        // before any objective has been announced. It must
                        // not grow and squeeze the five subject columns.
                        SizedBox(
                          height: 30,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.track_changes,
                                  color: Color(0xFFD5392F),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Weekly Goals',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: context.packColors.ink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (goal == null)
                                  Text(
                                    '-',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: context.packColors.ink,
                                    ),
                                  )
                                else ...[
                                  D30Chip(
                                    text:
                                        '${subjectLabel(goal.targetSubject)} Reach ${goal.targetValue}',
                                    color: D30Colors.subject(
                                      goal.targetSubject,
                                    ),
                                    fontSize: 13,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Icon(
                                      Icons.arrow_right_alt,
                                      size: 20,
                                      color: context.packColors.accent,
                                    ),
                                  ),
                                  D30Chip(
                                    text:
                                        '${subjectLabel(goal.rewardSubject)} Reward ${goal.rewardValue}',
                                    color: D30Colors.subject(
                                      goal.rewardSubject,
                                    ),
                                    fontSize: 13,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < subjects.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: _StatColumn(
                                  subject: subjects[i],
                                  value: state.stats[subjects[i]] ?? 0,
                                  delta:
                                      (state.stats[subjects[i]] ?? 0) -
                                      (before[subjects[i]] ?? 0),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  // A raised control: darker lower face, then the soft shadow.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF3D8138),
                          offset: Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 8,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: PressFeedback(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF55B14E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
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

  /// Snapshots the stats, for passing back in as `before`.
  static Map<String, num> snapshot(GameState state) =>
      Map<String, num>.from(state.stats);
}

class _StatColumn extends StatelessWidget {
  final String subject;
  final num value;
  final num delta;

  const _StatColumn({
    required this.subject,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: D30Colors.subject(subject),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  subjectLabel(subject),
                  style: TextStyle(fontSize: 11, color: context.packColors.ink),
                ),
              ),
              Text(
                '${value.round()}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.packColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Only gains are shown, as in the reference; a flat day shows nothing.
        Text(
          delta > 0 ? '+${delta.round()}' : '',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.packColors.ink,
          ),
        ),
      ],
    );
  }
}
