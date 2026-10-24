import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/pack.dart';
import '../engine/setup.dart';
import 'pack_image.dart';
import 'theme.dart';
import 'setup_widgets.dart';
import 'portrait.dart';

class SetupScreen extends StatefulWidget {
  final ContentPack pack;
  final RunSetup draft;
  const SetupScreen({super.key, required this.pack, required this.draft});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int step = 0;
  bool committed = false;
  late final first = TextEditingController(text: widget.draft.firstName);
  late final last = TextEditingController(text: widget.draft.lastName);
  RunSetup get draft => widget.draft;
  ContentPack get pack => widget.pack;

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    super.dispose();
  }

  void toggle(Set<int> selection, int id, int limit) {
    setState(() {
      if (!selection.remove(id) && selection.length < limit) selection.add(id);
    });
  }

  Widget portrait() => SizedBox(
    height: 300,
    child: Portrait(
      pack: pack,
      id: draft.characterId,
      character: true,
      fallback: pack.characters[draft.characterId]?.portrait,
    ),
  );

  Widget content() {
    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 65),
            setupTitle('Select Difficulty', size: 30),
            const SizedBox(height: 22),
            for (final elite in [false, true])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 44,
                    vertical: 16,
                  ),
                  child: Material(
                    color: elite
                        ? const Color(0xFFD94642)
                        : const Color(0xFFF6C4C3),
                    elevation: 5,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: elite
                          ? () => showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Elite Mode'),
                                content: const Text(
                                  'Elite Mode and its support pack are coming soon.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            )
                          : () => setState(() {
                              draft.difficulty = 'standard';
                              step++;
                            }),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: elite
                                ? const Color(0xFFC42626)
                                : const Color(0xFFE78692),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: elite
                                  ? const Color(0xFF9E2725)
                                  : const Color(0xFFCC646A),
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.directions_run,
                              size: 140,
                              color: Colors.white.withValues(alpha: .18),
                            ),
                            Text(
                              elite ? 'Elite Mode' : 'Standard Mode',
                              style: TextStyle(
                                fontSize: 32,
                                color: elite ? Colors.white : setupInk,
                              ),
                            ),
                            if (elite)
                              const Positioned(
                                top: 12,
                                right: 12,
                                child: Icon(Icons.help, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 18, 50, 55),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: D30Colors.panel.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD85D60), width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_run, color: Color(0xFFD85D60), size: 32),
                    SizedBox(width: 10),
                    Expanded(child: Text('[Elite Support Pack]\nComing soon',
                      textAlign: TextAlign.center)),
                  ],
                ),
              ),
            ),
          ],
        );
      case 1:
        return CharacterCarousel(
          pack: pack,
          draft: draft,
          onChanged: () => setState(() {}),
        );
      case 2:
        return SetupBadgeList(
          pack: pack,
          selected: draft.badges,
          onToggle: (id) => toggle(draft.badges, id, 7),
          describe: effectLabel,
        );
      case 3:
        return SetupTraitList(
          pack: pack,
          draft: draft,
          onToggle: (id) => toggle(draft.traits, id, 5),
        );
      default:
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
          children: [
            setupTitle('Enter Name', size: 32),
            portrait(),
            const SizedBox(height: 16),
            const Text('First Name', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            TextField(
              controller: first,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26),
              decoration: const InputDecoration(
                filled: true,
                fillColor: D30Colors.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: setupInk, width: 2),
                ),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (v) => draft.firstName = v,
            ),
            const SizedBox(height: 20),
            const Text('Last Name', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            TextField(
              controller: last,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26),
              decoration: const InputDecoration(
                filled: true,
                fillColor: D30Colors.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: setupInk, width: 2),
                ),
              ),
              onChanged: (v) => draft.lastName = v,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFEEDB),
    appBar: AppBar(
      centerTitle: true,
      toolbarHeight: 72,
      elevation: 5,
      shadowColor: Colors.black26,
      title: Text(
        'Select Character (${step + 1} / 5)',
        style: const TextStyle(color: setupOrange, fontSize: 21),
      ),
      backgroundColor: D30Colors.panel,
      foregroundColor: setupOrange,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: ColoredBox(
          color: setupOrange,
          child: SizedBox(height: 3, width: double.infinity),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (step == 0) {
            Navigator.pop(context);
          } else {
            setState(() => step--);
          }
        },
      ),
    ),
    body: SafeArea(
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 390,
            height: 750,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: setupInk, fontSize: 14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const PackImage(path: 'scene/default_background.jpg'),
                  ColoredBox(color: D30Colors.page.withValues(alpha: .91)),
                  Column(
                    children: [
                      Expanded(child: content()),
                      if (step != 0) Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 45,
                          vertical: 18,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: step == 4 ? 70 : 46,
                          child: D30RaisedButton(
                            onPressed: committed || draft.characterId == null
                                ? null
                                : () {
                                    if (step < 4) {
                                      setState(() => step++);
                                      return;
                                    }
                                    final Game game = draft.commit(pack);
                                    setState(() => committed = true);
                                    Navigator.pop(context, game);
                                  },
                            child: Text(
                              step == 4
                                  ? 'Start Game'
                                  : step == 1
                                  ? 'Select'
                                  : 'Next',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String effectLabel(Map<String, dynamic> e) {
  final subject = e['plusStatType'] == 'all'
      ? 'All subjects'
      : subjectLabel(e['subjectType'] as String? ?? 'all');
  final extra = e['extraStat'] as num? ?? 0;
  final value = extra != 0 ? extra : e['storyStat'] ?? 0;
  return switch (e['type']) {
    'plusStat' => '$subject study efficiency +$value',
    'firstPlusStat' => 'Initial $subject stats +${e['stat']}',
    'firstPlusMoney' => 'Initial Gold +${e['money']}',
    'hpCost' => 'Stamina cost ${e['cost']}',
    'firstExerciseLevel' => 'Initial workout level ${e['level']}',
    'firstPlusPartTimeJobLevel' => 'Initial work level ${e['level']}',
    'partTimeJobExp' =>
      'Part-Time EXP +${(((e['percentPlusExp'] as num? ?? 1) - 1) * 100).round()}%',
    'exerciseExp' =>
      'Workout EXP +${(((e['percentPlusExp'] as num? ?? 1) - 1) * 100).round()}%',
    'goalReward' =>
      'Weekly Goal Reward +${(((e['percentPlusReward'] as num? ?? 1) - 1) * 100).round()}%',
    'plusSleepHp' => 'Sleep Stamina +${e['plusValue']}',
    'partTimeJobMoney' =>
      e['percentPlusMoney'] != null
          ? 'Part-Time Earnings +${(((e['percentPlusMoney'] as num) - 1) * 100).round()}%'
          : 'Part-Time Earnings +${e['intPlusMoney']}',
    _ => '${e['type']}',
  };
}
