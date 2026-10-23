/// Preparation screen between the night recap and the next day's actions.
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'stationery_card.dart';
import 'theme.dart';
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

  Future<void> _panel(String title, Widget child, {bool fullHeight = false}) =>
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: orange, width: 4),
          ),
          child: SizedBox(
            height: fullHeight ? MediaQuery.sizeOf(context).height * .86 : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470, maxHeight: 650),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Flexible(child: child),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _books() => _commerce(menu: PackMenu.books);

  void _schedule() => _panel(
    'Calendar',
    Align(
      alignment: Alignment.topCenter,
      child: _box(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              _tag('D-${game.state.daysRemaining}', orange),
              const Expanded(
                child: Text(
                  'Graduation Exam',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    fullHeight: true,
  );

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
                    InkWell(
                      onTap: () => _panel(
                        'Check your Weekly Goals',
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Objectives',
                              style: TextStyle(fontSize: 24),
                            ),
                            if (goal != null) ...[
                              const SizedBox(height: 16),
                              _tag(
                                '${subjectLabel(goal.targetSubject)} ${goal.startValue.round()} → ${goal.targetValue}',
                                D30Colors.subject(goal.targetSubject),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Reward',
                                style: TextStyle(fontSize: 24),
                              ),
                              _tag(
                                '${subjectLabel(goal.rewardSubject)} +${goal.rewardValue}',
                                D30Colors.subject(goal.rewardSubject),
                              ),
                            ],
                          ],
                        ),
                      ),
                      child: FittedBox(
                        child: Row(
                          children: [
                            const Icon(Icons.track_changes, color: Colors.red),
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
            SizedBox(
              height: 35,
              child: InkWell(
                onTap: _schedule,
                child: _box(
                  child: Row(
                    children: [
                      Text('D-${state.daysRemaining}'),
                      const Expanded(
                        child: Text(
                          'Graduation Exam',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _box(
                      child: Column(
                        children: [
                          const Text('Traits', style: TextStyle(fontSize: 23)),
                          const SizedBox(height: 14),
                          if (state.traits.isEmpty) const Text('-'),
                          for (final id in state.traits)
                            Text(game.pack.traits[id]?.name ?? 'Trait $id'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('open-store'),
                      onTap: () => _commerce(),
                      child: _box(
                        child: Column(
                          children: [
                            const Text('Store', style: TextStyle(fontSize: 23)),
                            const SizedBox(height: 6),
                            for (final offer in game.pack.shop.values)
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
                                          width: 30,
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
                                                overflow: TextOverflow.ellipsis,
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
                                                overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child:
                                                state.equippedStationery[type] ==
                                                    null
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFD9D9D9,
                                                      ),
                                                      border: Border.all(
                                                        color: Colors.black87,
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Container(
                                                          width:
                                                              double.infinity,
                                                          color: Colors.black87,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 3,
                                                              ),
                                                          child: FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            child: Text(
                                                              stationeryTypeLabel(
                                                                type,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        cream,
                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                        const Expanded(
                                                          child: SizedBox(),
                                                        ),
                                                        const SizedBox(
                                                          width:
                                                              double.infinity,
                                                          height: 25,
                                                          child: ColoredBox(
                                                            color: cream,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                                  () => _panel(
                                    'Score Card',
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No Score Card yet!'),
                                    ),
                                  ),
                                ),
                                _tile(
                                  'Schedule',
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
            SizedBox(
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CB52F),
                  foregroundColor: cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: widget.onStart,
                child: Semantics(
                  label: 'Start day',
                  child: const Icon(Icons.play_arrow, size: 42),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
