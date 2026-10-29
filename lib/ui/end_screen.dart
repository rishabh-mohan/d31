/// The completion summary shown when a run is over (after the ending
/// events), and the "Ending Reward Obtained!" modal behind Back to Main Menu.
///
/// Built from the stored run only: the Student ID, the five stat chips and the
/// printable Graduation Exam Score Card read `GameState` (stats, `csat`,
/// enrolment, photo); nothing is recomputed or rerolled. Evidence: HANDOFF
/// section 13; see docs/DDAY-UI.md ("Results and enrollment").
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/account_store.dart';
import '../engine/state.dart';
import 'dday_widgets.dart';
import 'pack_image.dart';
import 'printable_score_card.dart';
import 'theme.dart';

class EndScreen extends StatefulWidget {
  /// The ending's name (`Game.outcome`), the panel's title.
  final String outcome;
  final GameState state;

  const EndScreen({super.key, required this.outcome, required this.state});

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> {
  bool _leaving = false;

  GameState get state => widget.state;

  Future<void> _backToMenu() async {
    if (_leaving) return;
    _leaving = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .55),
      transitionDuration: reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => const _ReturnDialog(),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final csat = state.csat;
    return Scaffold(
      backgroundColor: context.packColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7EC),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22B05A20),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'Korean Student Simulator',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  color: context.packColors.accent,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('completion-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: w * .78,
                      child: StudentIdCard.forRun(state),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      key: const ValueKey('completion-panel'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 34, 12, 46),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF8A7765),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.outcome,
                            key: const ValueKey('completion-title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              color: context.packColors.ink,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              for (final s in state.pack.manifest.subjects)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: _StatChip(
                                      subject: s,
                                      value: (state.stats[s] ?? 0).round(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFF8A7765)),
                          const SizedBox(height: 12),
                          PrintableScoreCard(
                            name: state.fullName,
                            isMale: state.isMale,
                            result: csat,
                            subjects: state.pack.manifest.subjects,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: D30RaisedButton(
                key: const ValueKey('back-to-main-menu'),
                onPressed: _backToMenu,
                child: const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Back to Main Menu',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String subject;
  final int value;
  const _StatChip({required this.subject, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: D30Colors.subject(subject),
      borderRadius: BorderRadius.circular(8),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            subjectLabel(subject),
            style: TextStyle(fontSize: 11.5, color: context.packColors.ink),
          ),
          Text(
            '$value',
            key: ValueKey('stat-$subject'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.packColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Back to Main Menu: a brief spinner, then (when this account has an
/// unclaimed ending reward) the "Ending Reward Obtained!" modal. Claiming is
/// idempotent: the pending reward is cleared by the first Confirm, so a
/// second visit goes straight home.
class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog();

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  EndingReward? _reward;
  bool _spinning = true;
  bool _claimed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final reward = AccountStore.current.pendingEndingReward;
      if (reward == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _reward = reward;
        _spinning = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _claim() {
    if (_claimed) return;
    _claimed = true;
    AccountStore.current.acknowledgeEndingReward();
    unawaited(AccountStore.save());
    Navigator.of(context).pop();
  }

  static String _packName(String id) =>
      id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final reward = _reward;
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: _spinning || reward == null
              ? const SizedBox(
                  key: ValueKey('return-spinner'),
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Colors.white,
                  ),
                )
              : Container(
                  key: const ValueKey('ending-reward'),
                  width: MediaQuery.sizeOf(context).width * .8,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: context.packColors.page,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: context.packColors.accent,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ending Reward Obtained!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          color: context.packColors.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 110,
                        height: 150,
                        child: PackImage(
                          path: 'kss/images/trait_pack/normal.png',
                          fit: BoxFit.contain,
                          placeholder: const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${reward.count} ${_packName(reward.packId)} '
                        'Trait Pack(s)',
                        key: const ValueKey('ending-reward-count'),
                        style: TextStyle(
                          fontSize: 18,
                          color: context.packColors.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 150,
                        child: D30RaisedButton(
                          key: const ValueKey('ending-reward-confirm'),
                          onPressed: _claim,
                          child: const Text(
                            'Confirm',
                            style: TextStyle(fontSize: 19),
                          ),
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
