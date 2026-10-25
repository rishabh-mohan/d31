import 'package:flutter/material.dart';

import '../engine/goals.dart';
import 'theme.dart';
import 'transitions.dart';

/// "Weekly Goals Met": shown mid-day, the moment the goal is reached, with
/// the objective and the reward just paid, then Confirm (V02 in
/// docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md). Styled as the goal
/// announcement it answers.
class GoalMetDialog {
  static const _orange = Color(0xFFFF8C50);
  static const _cream = Color(0xFFFFF9E9);
  static const _peach = Color(0xFFFFEEDB);

  static Future<void> show(BuildContext context, WeeklyGoal goal) =>
      showFlyUpDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          key: const ValueKey('goal-met-dialog'),
          backgroundColor: _cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _orange, width: 5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Weekly Goals Met',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 2, color: const Color(0x44502B0B)),
                  const SizedBox(height: 18),
                  _card(
                    'Objectives',
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${subjectLabel(goal.targetSubject)} '
                        '${goal.startValue.round()} → ${goal.targetValue}',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    'Reward',
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${subjectLabel(goal.rewardSubject)} '
                        '+${goal.rewardValue}',
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 190,
                    child: D30RaisedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  static Widget _card(String label, Widget child) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _peach,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    ],
  );
}
