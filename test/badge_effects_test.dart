/// Badge runtime sweep: every badge in both bundled campaigns, alone in a run,
/// must move the runtime number its structured effect names. A control run
/// (same setup, no badge) supplies the baseline. Plain `test`s only.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/setup.dart';

/// A fresh committed run, optionally holding one badge.
Game run(ContentPack pack, {int? badge}) {
  final draft = RunSetup(pack);
  if (badge != null) draft.badges.add(badge);
  return draft.commit(pack);
}

/// Puts the run at the first location that offers [type] (preferring
/// [locationType]) and returns that action.
LocationAction place(Game game, String type, {String? locationType}) {
  final all = game.pack.locations.values
      .where((l) => l.actions.any((a) => a.actionType == type))
      .toList();
  final preferred = locationType == null
      ? all
      : all.where((l) => l.type == locationType).toList();
  final location = (preferred.isNotEmpty ? preferred : all).first;
  game.state.locationId = location.id;
  game.invalidateHand();
  return location.actions.firstWhere((a) => a.actionType == type);
}

void main() {
  for (final story in [16, 20]) {
    group('badges kss$story', () {
      late ContentPack pack;
      setUpAll(() async {
        pack = await ContentSource.loadFromDirectory(
          Directory('packs/kss$story'),
        );
      });

      test('all 136 badges are present with known effect types', () {
        expect(pack.badges.length, 136);
        const known = {
          'plusStat',
          'firstPlusStat',
          'firstPlusMoney',
          'partTimeJobExp',
          'partTimeJobMoney',
          'exerciseExp',
          'goalReward',
          'plusSleepHp',
        };
        for (final b in pack.badges.values) {
          expect(b.effects, isNotEmpty, reason: b.name);
          for (final e in b.effects) {
            expect(known, contains(e['type']), reason: b.name);
          }
        }
      });

      test('every badge applies its effects at runtime', () {
        final subjects = pack.manifest.subjects;
        final electives = subjects.skip(3).take(2).toList();
        Set<String> targets(Map e) {
          switch (e['plusStatType']) {
            case 'detail':
              return {e['subjectType'] as String};
            case 'tamgoos':
              return electives.toSet();
            default:
              return subjects.toSet();
          }
        }


        final problems = <String>[];
        void check(bool ok, String badge, String what) {
          if (!ok) problems.add('$badge: $what');
        }

        for (final badge in pack.badges.values) {
          final id = badge.universityId;
          final name = badge.name;
          final game = run(pack, badge: id);
          final control = run(pack);
          final fx = badge.effects;
          check(game.state.badgeIds.contains(id), name, 'badge not held');

          // Starting stats and money apply once at setup commit.
          final startStat = {for (final s in subjects) s: 0.0};
          var startMoney = 0.0;
          for (final e in fx) {
            if (e['type'] == 'firstPlusStat') {
              for (final s in targets(e)) {
                startStat[s] = startStat[s]! + (e['stat'] as num);
              }
            }
            if (e['type'] == 'firstPlusMoney') {
              startMoney += e['money'] as num;
            }
          }
          for (final s in subjects) {
            final got = game.state.stats[s]! - control.state.stats[s]!;
            check(got == startStat[s], name, 'starting $s $got vs ${startStat[s]}');
          }
          check(
            game.state.money - control.state.money == startMoney,
            name,
            'starting money',
          );

          // Study gain per subject (flat efficiency, any plusStat shape).
          final studyGain = {for (final s in subjects) s: 0.0};
          for (final e in fx.where((e) => e['type'] == 'plusStat')) {
            for (final s in targets(e)) {
              studyGain[s] = studyGain[s]! + (e['storyStat'] as num);
            }
          }
          final study = place(game, 'study');
          place(control, 'study');
          for (final s in subjects) {
            final book = pack.booksFor(s).first;
            final got =
                game.preview(study, book: book).gain! -
                control.preview(study, book: book).gain!;
            check(got == studyGain[s], name, 'study $s +$got vs ${studyGain[s]}');
          }

          var expF = 1.0, moneyF = 1.0, workoutF = 1.0, goalF = 1.0;
          var sleepHp = 0.0;
          for (final e in fx) {
            switch (e['type']) {
              case 'partTimeJobExp':
                expF *= e['percentPlusExp'] as num;
              case 'partTimeJobMoney':
                moneyF *= e['percentPlusMoney'] as num;
              case 'exerciseExp':
                workoutF *= e['percentPlusExp'] as num;
              case 'goalReward':
                goalF *= e['percentPlusReward'] as num;
              case 'plusSleepHp':
                sleepHp += e['plusValue'] as num;
            }
          }

          // Work money (preview) and work EXP (an actual shift).
          final job = place(game, 'partTimeJob');
          final jobC = place(control, 'partTimeJob');
          final payB = game.preview(job).money!;
          final payC = control.preview(jobC).money!;
          check(
            (payB - payC * moneyF).abs() <= 1,
            name,
            'work money $payB vs ${payC * moneyF}',
          );
          final expBefore = game.state.partTimeExp;
          final expBeforeC = control.state.partTimeExp;
          game.act(job);
          control.act(jobC);
          final dB = game.state.partTimeExp - expBefore;
          final dC = control.state.partTimeExp - expBeforeC;
          check(
            (dB - dC * expF).abs() < 1e-6,
            name,
            'work exp $dB vs ${dC * expF}',
          );

          // Workout EXP.
          final gym = place(game, 'exercise');
          final gymC = place(control, 'exercise');
          game.state.hp = game.state.hpMax;
          control.state.hp = control.state.hpMax;
          final exB = game.state.exerciseExp;
          final exC = control.state.exerciseExp;
          game.act(gym);
          control.act(gymC);
          final wB = game.state.exerciseExp - exB;
          final wC = control.state.exerciseExp - exC;
          check(
            (wB - wC * workoutF).abs() <= 1,
            name,
            'workout exp $wB vs ${wC * workoutF}',
          );

          // Goal reward is folded in when the goal is issued at setup.
          final gb = game.state.weeklyGoal, gc = control.state.weeklyGoal;
          if (gb != null && gc != null) {
            check(
              (gb.rewardValue - gc.rewardValue * goalF).abs() <= 1,
              name,
              'goal reward ${gb.rewardValue} vs ${gc.rewardValue * goalF}',
            );
          } else {
            check(false, name, 'no weekly goal');
          }

          final sleep = place(game, 'sleep', locationType: 'sleep');
          final sleepC = place(control, 'sleep', locationType: 'sleep');
          final sgB = game.preview(sleep).gain!;
          final sgC = control.preview(sleepC).gain!;
          check(sgB - sgC == sleepHp, name, 'sleep hp ${sgB - sgC} vs $sleepHp');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    });
  }
}
