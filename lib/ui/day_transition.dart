/// The night screen between days.
///
/// A navy page with a moon, the countdown and weekday, the week's goal and
/// the subject stats — with the deltas earned that day underneath — and a
/// green play button to start the next day.
library;

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

  const DayTransition({
    super.key,
    required this.game,
    required this.before,
    this.completedDay,
    this.countdown,
  });

  static Future<void> show(
    BuildContext context, {
    required Game game,
    required Map<String, num> before,
    DateTime? completedDay,
    int? countdown,
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
    final goal = state.weeklyGoal;

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
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.track_changes,
                              color: Color(0xFFD5392F),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Weekly Goals',
                              style: TextStyle(
                                fontSize: 19,
                                color: D30Colors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (goal == null)
                          const Text('-', style: TextStyle(fontSize: 20))
                        else
                          Row(
                            children: [
                              Expanded(
                                child: D30Chip(
                                  text:
                                      '${subjectLabel(goal.targetSubject)} Reach ${goal.targetValue}',
                                  color: D30Colors.subject(goal.targetSubject),
                                  fontSize: 16,
                                  padding: const EdgeInsets.all(10),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.arrow_right_alt,
                                  color: D30Colors.accent,
                                ),
                              ),
                              Expanded(
                                child: D30Chip(
                                  text:
                                      '${subjectLabel(goal.rewardSubject)} Reward ${goal.rewardValue}',
                                  color: D30Colors.subject(goal.rewardSubject),
                                  fontSize: 16,
                                  padding: const EdgeInsets.all(10),
                                ),
                              ),
                            ],
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
                  SizedBox(
                    width: double.infinity,
                    height: 62,
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
                  style: const TextStyle(fontSize: 11, color: D30Colors.ink),
                ),
              ),
              Text(
                '${value.round()}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: D30Colors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Only gains are shown, as in the reference; a flat day shows nothing.
        Text(
          delta > 0 ? '+${delta.round()}' : '',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: D30Colors.ink,
          ),
        ),
      ],
    );
  }
}
