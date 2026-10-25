/// Preparation screen between the night recap and the next day's actions.
library;

import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'stationery_card.dart';
import 'score_card.dart';
import 'theme.dart';
import 'transitions.dart';
import 'commerce_screen.dart';
import 'pack_image.dart';

class DayMenu extends StatefulWidget {
  final Game game;
  final VoidCallback onStart;
  const DayMenu({super.key, required this.game, required this.onStart});

  @override
  State<DayMenu> createState() => _DayMenuState();
}

class _DayMenuState extends State<DayMenu> {
  Game get game => widget.game;
  static const orange = Color(0xFFFF8C50);
  static const cream = Color(0xFFFFF9E9);
  static const peach = Color(0xFFFFEEDB);

  @override
  void initState() {
    super.initState();
    // A fresh weekly goal announces itself over the hub, as in the reference.
    final goal = game.state.weeklyGoal;
    if (goal != null && game.state.announcedGoalWeek != goal.weekIndex) {
      game.state.announcedGoalWeek = goal.weekIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announceGoal();
      });
    }
  }

  /// The shared cream/orange modal.
  ///
  /// The reference integrates the close control into the top-right border as
  /// an orange corner tab rather than floating a plain X, and it does not let
  /// a one-line body collapse the window: [heightFactor] keeps the Calendar
  /// tall and the Score Card deliberately short.
  Future<void> _panel(
    String title,
    Widget child, {
    bool fullHeight = false,
    double? heightFactor,
    EdgeInsets? insetPadding,
  }) => showFlyUpDialog<void>(
    context: context,
    builder: (context) {
      final factor = heightFactor ?? (fullHeight ? .86 : null);
      return Dialog(
        insetPadding:
            insetPadding ??
            const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        backgroundColor: cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: orange, width: 4),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: factor == null
              ? null
              : MediaQuery.sizeOf(context).height * factor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470, maxHeight: 650),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(height: 18),
                      Flexible(child: child),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _CornerClose(onTap: () => Navigator.pop(context)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  void _books() => _commerce(menu: PackMenu.books);

  /// Tapping a trait explains it: the trait's own plate above its description,
  /// and one Confirm. See references/screenshots/trait tap example.jpg.
  Future<void> _explainTrait(int id) {
    final trait = game.pack.traits[id];
    return showFlyUpDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: orange, width: 4),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                D30Chip(
                  text: trait?.name ?? 'Trait $id',
                  color: traitColor(trait?.type),
                  textColor: Colors.white,
                  fontSize: 19,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  trait?.description.trim().isNotEmpty == true
                      ? trait!.description
                      : 'No description.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, height: 1.35),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 170,
                  child: D30RaisedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontSize: 17),
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

  /// The weekly-goal announcement.
  ///
  /// Two separate inset cards — the objective as `start → target` tiles either
  /// side of a thick orange arrow, then the reward — and a single
  /// acknowledging button. The reference has no close cross on this one.
  Future<void> _announceGoal() {
    final goal = game.state.weeklyGoal;
    if (goal == null) return Future<void>.value();
    return showFlyUpDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: orange, width: 5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Check your Weekly Goals',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 12),
                Container(height: 2, color: const Color(0x44502B0B)),
                const SizedBox(height: 18),
                _insetCard(
                  label: 'Objectives',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _tag(
                          '${subjectLabel(goal.targetSubject)} ${goal.startValue.round()}',
                          D30Colors.subject(goal.targetSubject),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_right_alt,
                          color: orange,
                          size: 38,
                        ),
                      ),
                      Expanded(
                        child: _tag(
                          '${subjectLabel(goal.targetSubject)} ${goal.targetValue}',
                          D30Colors.subject(goal.targetSubject),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _insetCard(
                  label: 'Reward',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tag(
                          subjectLabel(goal.rewardSubject),
                          D30Colors.subject(goal.rewardSubject),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '+${goal.rewardValue}',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 190,
                  child: D30RaisedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Let's do this!",
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
  }

  /// A peach, shadowed rectangle with its heading above the content.
  Widget _insetCard({required String label, required Widget child}) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: peach,
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

  /// One agenda row: an orange date segment and a peach title segment that
  /// share a single rounded, shadowed rectangle.
  Widget _agendaRow(
    ScheduledEntry entry, {
    double height = 76,
    double titleSize = 22,
  }) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: peach,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: orange),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 4)),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: height * 1.15,
          height: double.infinity,
          color: orange,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'D-${game.state.date.daysUntil(entry.date)}',
              style: const TextStyle(fontSize: 20, color: cream),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(entry.name, style: TextStyle(fontSize: titleSize)),
            ),
          ),
        ),
      ],
    ),
  );

  void _schedule() {
    final entries = game.schedule();
    _panel(
      'Calendar',
      // An agenda, not a month grid, and it keeps its height with one entry.
      ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _agendaRow(entries[i]),
      ),
      fullHeight: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    );
  }

  Future<void> _commerce({
    bool stationery = false,
    PackMenu menu = PackMenu.shop,
  }) async {
    await Navigator.push(
      context,
      CommerceScreen.route(game, menu: stationery ? PackMenu.stationery : menu),
    );
    if (mounted) setState(() {});
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, softWrap: false, textAlign: TextAlign.center),
    ),
  );

  Widget _box({required Widget child}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: peach,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: orange),
    ),
    child: child,
  );

  Widget _tile(String text, IconData icon, VoidCallback onTap) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: PressFeedback(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: cream,
            padding: const EdgeInsets.all(4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              FittedBox(child: Text(text)),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox(width: 390, height: 740, child: _menu()),
      ),
    ),
  );

  Widget _menu() {
    final state = game.state;
    final goal = state.weeklyGoal;
    return DefaultTextStyle(
      style: const TextStyle(color: Color(0xFF502B0B), fontSize: 14),
      child: ColoredBox(
        color: cream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 92,
              child: _box(
                child: Column(
                  children: [
                    PressFeedback(
                      child: InkWell(
                        onTap: _announceGoal,
                        child: FittedBox(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.track_changes,
                                color: Colors.red,
                              ),
                              const Text(' Weekly Goals  '),
                              if (goal == null)
                                const Text('-')
                              else ...[
                                _tag(
                                  '${subjectLabel(goal.targetSubject)} Reach ${goal.targetValue}',
                                  D30Colors.subject(goal.targetSubject),
                                ),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: orange,
                                  size: 18,
                                ),
                                _tag(
                                  '${subjectLabel(goal.rewardSubject)} Reward ${goal.rewardValue}',
                                  D30Colors.subject(goal.rewardSubject),
                                ),
                                if (goal.met)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        children: [
                          for (final subject in game.pack.manifest.subjects)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _tag(
                                  '${subjectLabel(subject)}\n${state.stats[subject]?.round() ?? 0}',
                                  D30Colors.subject(subject),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // The strip shows whatever is next on the calendar, which is the
            // exam until a storyline pins something sooner.
            SizedBox(
              height: 35,
              child: PressFeedback(
                child: InkWell(
                  onTap: _schedule,
                  child: _agendaRow(
                    game.schedule().first,
                    height: 35,
                    titleSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 7,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _box(
                      child: Column(
                        children: [
                          const Text('Traits', style: TextStyle(fontSize: 23)),
                          const SizedBox(height: 14),
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('hub-traits-scroll'),
                              child: Column(
                                children: [
                                  if (state.traits.isEmpty) const Text('-'),
                                  for (final id in state.traits)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: PressFeedback(
                                        child: InkWell(
                                          key: ValueKey('hub-trait-$id'),
                                          onTap: () => _explainTrait(id),
                                          child: D30Chip(
                                            text:
                                                game.pack.traits[id]?.name ??
                                                'Trait $id',
                                            color: traitColor(
                                              game.pack.traits[id]?.type,
                                            ),
                                            textColor: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PressFeedback(
                      child: InkWell(
                        key: const ValueKey('open-store'),
                        onTap: () => _commerce(),
                        child: _box(
                          child: Column(
                            children: [
                              const Text(
                                'Store',
                                style: TextStyle(fontSize: 23),
                              ),
                              const SizedBox(height: 6),
                              for (final offer in game.shopOffers.take(4))
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cream,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: orange),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 48,
                                            child: PackImage(
                                              path:
                                                  'items/${offer['itemId']}.png',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  game
                                                          .pack
                                                          .items[offer['itemId']]
                                                          ?.name ??
                                                      'Item',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    height: 1.1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  game
                                                          .pack
                                                          .items[offer['itemId']]
                                                          ?.effectText ??
                                                      '',
                                                  key: ValueKey(
                                                    'store-preview-${offer['itemId']}',
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: PressFeedback(
                      child: InkWell(
                        key: const ValueKey('open-stationery'),
                        onTap: () => _commerce(stationery: true),
                        child: _box(
                          child: Column(
                            children: [
                              const Text(
                                'Stationery',
                                style: TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              for (var row = 0; row < 2; row++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        for (final type
                                            in row == 0
                                                ? ['pencil', 'eraser']
                                                : ['note', 'markingPen'])
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child:
                                                  state.equippedStationery[type] ==
                                                      null
                                                  ? _EmptyStationerySlot(
                                                      label:
                                                          stationeryTypeLabel(
                                                            type,
                                                          ),
                                                      cream: cream,
                                                    )
                                                  : StationeryCard(
                                                      id: state
                                                          .equippedStationery[type]!,
                                                      item:
                                                          game
                                                              .pack
                                                              .stationery[state
                                                              .equippedStationery[type]]!,
                                                      nameLines: 2,
                                                    ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _box(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tile('Books', Icons.menu_book, _books),
                                _tile(
                                  'Items',
                                  Icons.backpack,
                                  () => _commerce(menu: PackMenu.items),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tile(
                                  'Score Card',
                                  Icons.fact_check_outlined,
                                  // Deliberately short next to the Calendar,
                                  // with the message high and blank below it.
                                  () => _panel(
                                    'Score Card',
                                    game.state.csat == null
                                        ? const Align(
                                            alignment: Alignment.topCenter,
                                            child: Text(
                                              'No Score Card yet!',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                          )
                                        : ExamScoreCard(
                                            name: game.state.fullName,
                                            result: game.state.csat!,
                                          ),
                                    heightFactor: game.state.csat == null
                                        ? .26
                                        : .75,
                                  ),
                                ),
                                _tile(
                                  'Calendar',
                                  Icons.calendar_today,
                                  _schedule,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Raised like the reference: a darker lower face under the green.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF2B8422), offset: Offset(0, 6)),
                ],
              ),
              child: SizedBox(
                height: 60,
                child: PressFeedback(
                  travel: 6,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3CB52F),
                      foregroundColor: cream,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                          color: Color(0xFF2B8422),
                          width: 2,
                        ),
                      ),
                    ),
                    onPressed: widget.onStart,
                    child: Semantics(
                      label: 'Start day',
                      child: const Icon(Icons.play_arrow, size: 42),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// The orange tab that the reference builds into a modal's top-right border.
class _CornerClose extends StatelessWidget {
  final VoidCallback onTap;
  const _CornerClose({required this.onTap});

  @override
  Widget build(BuildContext context) => PressFeedback(
    child: Material(
      color: D30Colors.accent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
      ),
      child: InkWell(
        onTap: onTap,
        child: const Tooltip(
          message: 'Close',
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(Icons.close, color: Colors.white, size: 26),
          ),
        ),
      ),
    ),
  );
}

/// Empty hub slots use the same reserved border inset as StationeryCard.
class _EmptyStationerySlot extends StatelessWidget {
  final String label;
  final Color cream;
  const _EmptyStationerySlot({required this.label, required this.cream});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(9),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: cream, fontSize: 10)),
            ),
          ),
          const Expanded(
            child: ColoredBox(
              color: Color(0xFFD9D9D9),
              child: SizedBox.expand(),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 25,
            child: ColoredBox(color: cream),
          ),
        ],
      ),
    ),
  );
}
