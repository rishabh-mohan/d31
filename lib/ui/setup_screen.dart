import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/content_source.dart';
import '../engine/pack.dart';
import '../engine/setup.dart';
import '../engine/traits.dart';
import 'pack_image.dart';
import 'theme.dart';
import 'setup_widgets.dart';
import 'portrait.dart';

class SetupScreen extends StatefulWidget {
  final ContentPack pack;
  final RunSetup draft;
  final List<ContentPack>? campaigns;
  final Map<String, PackLocation> campaignLocations;
  const SetupScreen({
    super.key,
    required this.pack,
    required this.draft,
    this.campaigns,
    this.campaignLocations = const {},
  });
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int step = 0;

  /// Step 2 shows the gender page after the carousel when the pack offers it.
  bool choosingGender = false;
  bool committed = false;
  late final first = TextEditingController(text: widget.draft.firstName);
  late final last = TextEditingController(text: widget.draft.lastName);
  late ContentPack _pack = widget.pack;
  late RunSetup _draft = widget.draft;
  late final Map<String, RunSetup> _drafts = {
    widget.pack.manifest.id: widget.draft,
  };
  RunSetup get draft => _draft;
  ContentPack get pack => _pack;

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
            const SizedBox(height: 32),
            setupTitle('Select Game Mode', size: 30),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 34,
                  vertical: 12,
                ),
                children: [
                  for (final campaign in widget.campaigns ?? [widget.pack])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: PressFeedback(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() {
                            _pack = campaign;
                            final location =
                                widget.campaignLocations[campaign.manifest.id];
                            if (location != null) PackImages.use(location);
                            PackThemes.use(campaign.manifest.colorScheme);
                            _draft = _drafts.putIfAbsent(
                              campaign.manifest.id,
                              () => RunSetup(campaign),
                            );
                            // Ownership is account-wide: every campaign's
                            // draft offers the same owned badges/traits.
                            draft.useOwnership(
                              widget.draft.ownership,
                              campaign,
                            );
                            first.text = draft.firstName;
                            last.text = draft.lastName;
                            draft.difficulty = 'standard';
                            step = 1;
                          }),
                          child: Container(
                            height: 174,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Color(
                                campaign.manifest.colorScheme.color(
                                  'iconBackground',
                                ),
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Color(
                                  campaign.manifest.colorScheme.color(
                                    'accentDark',
                                  ),
                                ),
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 7),
                                ),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 280,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.extension,
                                      size: 28,
                                      color: Color(
                                        campaign.manifest.colorScheme.color(
                                          'iconForeground',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      campaign.manifest.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: Color(
                                          campaign.manifest.colorScheme.color(
                                            'iconForeground',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      campaign.manifest.storyId == 16
                                          ? 'Standard Mode'
                                          : campaign.manifest.storyId == 20
                                          ? 'Prototype - English dialogue'
                                          : 'Standard Mode',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(
                                          campaign.manifest.colorScheme.color(
                                            'iconForeground',
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
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case 1 when choosingGender:
        return GenderSelectPage(
          recommendedMale: draft.recommendedMale(pack),
          onSelect: (male) => setState(() {
            draft.isMale = male;
            choosingGender = false;
            step = 2;
          }),
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
          ownership: draft.ownership,
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
              decoration: InputDecoration(
                filled: true,
                fillColor: context.packColors.panel,
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
              decoration: InputDecoration(
                filled: true,
                fillColor: context.packColors.panel,
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
      backgroundColor: context.packColors.panel,
      foregroundColor: setupOrange,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: ColoredBox(
          color: setupOrange,
          child: SizedBox(height: 3, width: double.infinity),
        ),
      ),
      leading: PressFeedback(
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (step == 0) {
              Navigator.pop(context);
            } else if (choosingGender) {
              setState(() => choosingGender = false);
            } else {
              setState(() => step--);
            }
          },
        ),
      ),
    ),
    // The step's artwork is a fixed 390-wide canvas scaled to fit, but the
    // footer button is **not** inside it: scaled along with everything else it
    // ended up clipped against the bottom of a real device. It is laid out at
    // device scale under the canvas, where nothing can crop it.
    body: SafeArea(
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: setupInk, fontSize: 14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PackImage(path: 'scene/default_background.jpg'),
            ColoredBox(color: context.packColors.page.withValues(alpha: .91)),
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 390,
                        height: 670,
                        child: content(),
                      ),
                    ),
                  ),
                ),
                if (step != 0 && !choosingGender)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(45, 6, 45, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: step == 4 ? 64 : 48,
                      child: D30RaisedButton(
                        onPressed: committed || draft.characterId == null
                            ? null
                            : () {
                                if (step == 1 && pack.genderSelection) {
                                  setState(() => choosingGender = true);
                                  return;
                                }
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
  );
}

String effectLabel(Map<String, dynamic> e, {String description = ''}) {
  final subject = e['plusStatType'] == 'all'
      ? 'All subjects'
      : subjectLabel(e['subjectType'] as String? ?? 'all');
  final value = studyEfficiencyValue(e, description: description);
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
