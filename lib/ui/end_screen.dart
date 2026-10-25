/// Exam day. Shows how the run finished: the ending an END_GAME named, the
/// CSAT result and where the student enrolled.
library;

import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/state.dart';

class EndScreen extends StatelessWidget {
  final String outcome;
  final GameState state;

  const EndScreen({super.key, required this.outcome, required this.state});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                  'Exam day',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  outcome,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final e in state.stats.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_cap(e.key)),
                                Text('${e.value.round()}'),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total'),
                            Text('${state.totalStat.round()}'),
                          ],
                        ),
                        if (state.csat case final csat?)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('CSAT standard score'),
                              Text(csat.standardScore.toStringAsFixed(1)),
                            ],
                          ),
                        if (state.enrolledDepartment case final id?)
                          if (state.pack.admissions.departments[id]
                              case final d?)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${state.pack.admissions.universities[d.universityId]?.name ?? ''}'
                                ' — ${d.name}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Money'),
                            Text('${state.money.round()}'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Events seen'),
                            Text('${state.eventCounts.length}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                PressFeedback(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
