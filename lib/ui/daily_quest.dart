/// Daily Quests (MM-08), opened by Home's Missions: enrol in one named
/// department today for 4 cookies. The quest is picked from the date, so it
/// holds all day and changes at local midnight; a run finished today that
/// enrolled there completes it, and Receive pays it out once.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/account_store.dart';
import '../engine/pack.dart';
import '../engine/record_store.dart';
import 'account_widgets.dart';
import 'home_screen.dart';
import 'pack_image.dart';

class DailyQuestPanel extends StatefulWidget {
  /// The catalog the quest names departments from (Settings set applied).
  final AdmissionsCatalog catalog;
  final DateTime? now;
  const DailyQuestPanel({super.key, required this.catalog, this.now});

  @override
  State<DailyQuestPanel> createState() => _DailyQuestPanelState();
}

class _DailyQuestPanelState extends State<DailyQuestPanel> {
  List<RunRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    // Issued on first look and kept, so the day's quest survives a restart.
    AccountStore.current.questFor(widget.now ?? DateTime.now(), widget.catalog);
    AccountStore.save();
    RecordStore.list().then((r) {
      if (mounted) setState(() => _records = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final account = AccountStore.current;
    final quest = account.questFor(now, widget.catalog);
    final done = quest != null && Account.questComplete(quest, _records);
    final claimed = quest?.claimed ?? false;
    final department = widget.catalog.departments[quest?.departmentId];
    final university = widget.catalog.universities[quest?.universityId];
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    String two(int v) => v.toString().padLeft(2, '0');
    final reset =
        '${two(tomorrow.month)}/${two(tomorrow.day)}/${tomorrow.year}, '
        '00:00 AM';
    return LayoutBuilder(
      builder: (context, box) {
        final u = box.maxWidth / 390;
        final body = TextStyle(fontSize: 14.5 * u, color: HomeColors.ink);
        return Center(
          child: Container(
            width: 350 * u,
            decoration: BoxDecoration(
              color: HomeColors.paper,
              borderRadius: BorderRadius.circular(10 * u),
              border: Border.all(color: HomeColors.orange, width: 4 * u),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 42 * u,
                    color: HomeColors.orange,
                    alignment: Alignment.center,
                    child: Text(
                      'Daily Quests',
                      style: TextStyle(fontSize: 20 * u, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 26 * u),
                  if (quest == null)
                    Padding(
                      padding: EdgeInsets.all(20 * u),
                      child: Text('Failed to load Daily Quests!', style: body),
                    )
                  else ...[
                    Text(
                      'Enroll in the following major',
                      style: TextStyle(fontSize: 17 * u, color: HomeColors.ink),
                    ),
                    SizedBox(height: 14 * u),
                    SizedBox.square(
                      dimension: 74 * u,
                      child: PackImage(
                        path: 'kss/images/university/${quest.universityId}.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 10 * u),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14 * u,
                        vertical: 3 * u,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13285A),
                        borderRadius: BorderRadius.circular(20 * u),
                      ),
                      child: Text(
                        university?.name ?? 'University ${quest.universityId}',
                        style: TextStyle(
                          fontSize: 13.5 * u,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 10 * u),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14 * u),
                      child: Text(
                        '<${department?.name ?? ''}>',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19 * u,
                          color: HomeColors.ink,
                        ),
                      ),
                    ),
                    SizedBox(height: 18 * u),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 50 * u),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('resets at $reset', style: body),
                          ),
                          SizedBox(height: 6 * u),
                          Row(
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Completion Reward : ',
                                    style: body,
                                  ),
                                ),
                              ),
                              CookieAmount(
                                u: u,
                                amount: dailyQuestCookies,
                                size: 14.5,
                              ),
                              SizedBox(width: 8 * u),
                              _ReceiveButton(
                                u: u,
                                onTap: done && !claimed
                                    ? () async {
                                        account.claimQuest(_records);
                                        unawaited(AccountStore.save());
                                        if (mounted) setState(() {});
                                      }
                                    : null,
                                label: claimed ? 'Received' : 'Receive',
                              ),
                            ],
                          ),
                          SizedBox(height: 6 * u),
                          Row(
                            children: [
                              Text('Progress :  ', style: body),
                              Flexible(
                                child: Text(
                                  done ? 'Complete' : 'Incomplete',
                                  style: body.copyWith(
                                    color: done
                                        ? const Color(0xFF4CA846)
                                        : const Color(0xFFE05050),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 24 * u),
                  SizedBox(
                    width: 128 * u,
                    child: FaceButton(
                      key: const ValueKey('quest-confirm'),
                      u: u,
                      label: 'Confirm',
                      height: 34,
                      fontSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(height: 26 * u),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiveButton extends StatelessWidget {
  final double u;
  final String label;
  final VoidCallback? onTap;
  const _ReceiveButton({required this.u, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: onTap == null ? const Color(0xFF9A9A9A) : HomeColors.orange,
    borderRadius: BorderRadius.circular(5 * u),
    elevation: 2,
    child: InkWell(
      key: const ValueKey('quest-receive'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 9 * u, vertical: 3 * u),
        child: Text(
          label,
          style: TextStyle(fontSize: 13 * u, color: Colors.white),
        ),
      ),
    ),
  );
}
