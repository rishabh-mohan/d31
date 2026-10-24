/// Weekly Goals.
///
/// "Weekly Goals are renewed every Monday", and the run starts on a Monday, so
/// a 31-day run is 4 full goal weeks plus 3 days. A goal reads
/// `SCI1 398 → ENG 294`: reach a threshold in one subject this week, receive a
/// stat reward in another.
///
/// The original generates thresholds at runtime (they are Dart string
/// interpolation, not authored data), so the generator here is ours. What it
/// is fitted to:
///
///   * the player's current stat in the target subject, so a goal is always
///     reachable-but-not-free from where they actually are;
///   * how many study blocks they clicked last week — **including the ones
///     clicked after the goal was already met**. Surplus effort is not wasted;
///     it raises next week's bar. That is the `studyBlocksThisWeek` weighting.
library;

import 'state.dart';
import 'traits.dart';

class WeeklyGoal {
  /// Which Monday this goal belongs to; 0 is the first week of the run.
  final int weekIndex;

  final String targetSubject;
  final int targetValue;

  final String rewardSubject;
  final int rewardValue;

  /// Snapshot of the target stat when the goal was issued, so progress can be
  /// shown as a fraction of the week's work rather than of the whole run.
  final num startValue;

  bool met;

  WeeklyGoal({
    required this.weekIndex,
    required this.targetSubject,
    required this.targetValue,
    required this.rewardSubject,
    required this.rewardValue,
    required this.startValue,
    this.met = false,
  });

  double progressFrom(num current) {
    final span = targetValue - startValue;
    if (span <= 0) return 1;
    return ((current - startValue) / span).clamp(0, 1).toDouble();
  }

  Map<String, dynamic> toJson() => {
    'weekIndex': weekIndex,
    'targetSubject': targetSubject,
    'targetValue': targetValue,
    'rewardSubject': rewardSubject,
    'rewardValue': rewardValue,
    'startValue': startValue,
    'met': met,
  };

  static WeeklyGoal? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return WeeklyGoal(
      weekIndex: (j['weekIndex'] as num?)?.toInt() ?? 0,
      targetSubject: j['targetSubject'] as String? ?? 'korean',
      targetValue: (j['targetValue'] as num?)?.toInt() ?? 0,
      rewardSubject: j['rewardSubject'] as String? ?? 'korean',
      rewardValue: (j['rewardValue'] as num?)?.toInt() ?? 0,
      startValue: (j['startValue'] as num?) ?? 0,
      met: j['met'] as bool? ?? false,
    );
  }
}

class Goals {
  /// Week 0 is the run's first Monday. The run starts on one, so this is just
  /// whole weeks elapsed.
  static int weekIndexOf(GameState state) => state.dayIndex ~/ 7;

  /// Issues the goal for the current week. Called at run start and on every
  /// Monday rollover.
  static WeeklyGoal issue(GameState state) {
    final subjects = state.pack.manifest.subjects;
    final rules = state.pack.rules;
    final week = weekIndexOf(state);

    // Rotate the target so a run covers every subject, and reward a different
    // one so the goal pushes breadth.
    final target = subjects[week % subjects.length];
    final reward = subjects[(week + 1) % subjects.length];
    final current = state.stats[target] ?? 0;

    // The bar is a base step, scaled by how much studying actually happened
    // last week. `perStudyBlock` is what one study block is assumed to be
    // worth to the bar; surplus blocks are already counted in the total.
    final base = rules.number('goals', 'weeklyStep', 348);
    final perBlock = rules.number('goals', 'perStudyBlock', 12);
    final weighting = state.studyBlocksThisWeek * perBlock;

    final threshold = (current + base + weighting).round();
    final rewardRatio = rules.number('goals', 'rewardRatio', 0.74);

    return WeeklyGoal(
      weekIndex: week,
      targetSubject: target,
      targetValue: threshold,
      rewardSubject: reward,
      rewardValue: ((threshold - current) * rewardRatio).round(),
      startValue: current,
    );
  }

  /// True when the current goal's threshold has just been reached.
  static bool checkMet(GameState state) {
    final goal = state.weeklyGoal;
    if (goal == null || goal.met) return false;
    if ((state.stats[goal.targetSubject] ?? 0) < goal.targetValue) return false;
    goal.met = true;
    return true;
  }

  /// Pays a met goal's reward. Rewards scale with `goalReward` effects.
  static void payReward(GameState state) {
    final goal = state.weeklyGoal;
    if (goal == null || !goal.met) return;
    final percent = state.passiveSum('goalReward', valueKey: 'percent');
    final factor = TraitEngine(pack: state.pack).goalRewardFactor(state);
    final amount = (goal.rewardValue * (1 + percent / 100) * factor).round();
    state.addStat(goal.rewardSubject, amount);
    state.note('Weekly goal met: ${goal.rewardSubject} +$amount.', 'effect');
  }

  /// Called on each Monday rollover: settle the old goal, reset the weekly
  /// counters, issue the new one.
  static void rollOver(GameState state) {
    final old = state.weeklyGoal;
    if (old != null) {
      if (old.met) {
        payReward(state);
      } else {
        state.note('Weekly goal failed.', 'system');
      }
    }
    state.weeklyGoal = issue(state);
    state.studyBlocksThisWeek = 0;
    state.surplusStudyBlocks = 0;
  }

  /// Records a study block against the current week. Surplus blocks -- those
  /// clicked once the goal is already met -- are counted too, and feed the
  /// next goal's weighting.
  static void recordStudyBlock(GameState state) {
    state.studyBlocksThisWeek++;
    if (state.weeklyGoal?.met ?? false) state.surplusStudyBlocks++;
  }
}
