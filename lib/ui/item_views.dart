/// The interfaces checking items open: the Mock Exam Paper's predicted
/// grades, the Bizarre Author's Note's abilities and the Recipe.
///
/// PROJECT DESIGN, not a recreation: no capture of the original screens
/// exists. They reuse the acquisition popup's frame (cream panel, orange
/// border) and the score card's table. What they show is pack data: the
/// item's `ui` effect names the view and carries its rows or recipes.
library;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import '../engine/game.dart';
import '../engine/pack.dart';
import '../engine/state.dart';
import 'pack_image.dart';
import 'pack_menus.dart';
import 'theme.dart';

/// Shows what an item use asked for: its report lines, then each view.
Future<void> showItemOutcome(
  BuildContext context,
  ItemUseOutcome outcome,
) async {
  if (outcome.reports.isNotEmpty) {
    await showReportLines(context, outcome.reports);
  }
  for (final view in outcome.views) {
    if (!context.mounted) return;
    final body = itemViewFor(outcome.state, view);
    if (body == null) continue;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ItemViewDialog(child: body),
    );
  }
}

/// The view a `ui` effect names, or null for one this build cannot show
/// (such an item is not offered for use: see [GameItem.canUse]).
Widget? itemViewFor(GameState state, Map<String, dynamic> view) =>
    switch (view['action']) {
      'predictedGrades' => PredictedGradesView(state: state),
      'checkAbilities' => AbilitiesView(state: state, view: view),
      'recipes' => RecipeView(state: state, view: view),
      _ => null,
    };

/// The shared frame: the acquisition popup's panel with one Confirm button.
class ItemViewDialog extends StatelessWidget {
  final Widget child;
  const ItemViewDialog({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: D30Colors.panel,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: D30Colors.accent, width: 5),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: SingleChildScrollView(child: child)),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: D30RaisedButton(
                depth: 3,
                onPressed: () => Navigator.pop(context),
                child: const Text('Confirm', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Title(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, color: D30Colors.ink),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: D30Colors.inkSoft),
      ),
      const SizedBox(height: 14),
    ],
  );
}

/// The score card's table look: tan rules, peach header row.
Widget _table(
  String name,
  List<List<Widget>> rows, {
  Map<int, TableColumnWidth>? widths,
}) => Table(
  key: ValueKey('item-view-$name'),
  border: TableBorder.all(color: const Color(0xFFBCA58C)),
  columnWidths: widths ?? const {0: FlexColumnWidth(1.4)},
  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
  children: [
    for (var i = 0; i < rows.length; i++)
      TableRow(
        decoration: BoxDecoration(
          color: i == 0 ? const Color(0xFFFFEEDB) : Colors.white,
        ),
        children: [
          for (final cell in rows[i])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Center(child: cell),
            ),
        ],
      ),
  ],
);

Widget _cell(String text, {bool header = false}) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: D30Colors.ink,
      fontWeight: header ? FontWeight.bold : FontWeight.normal,
    ),
  ),
);

Widget _subjectCell(String subject) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: D30Colors.subject(subject),
    borderRadius: BorderRadius.circular(8),
  ),
  child: _cell(subjectLabel(subject)),
);

String _stat(num v) => v.round().toString();

/// Mock Exam Paper: the CSAT forecast from current stats. Uses the same
/// arithmetic as the real CSAT ([Game.forecastCsat]) and records nothing.
class PredictedGradesView extends StatelessWidget {
  final GameState state;
  const PredictedGradesView({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final forecast = Game.forecastCsat(state);
    final top = 100 - forecast.percentile;
    return Column(
      key: const ValueKey('predicted-grades'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Title('Predicted Grades', 'If the CSAT were today'),
        _table('grades', [
          [
            _cell('Subject', header: true),
            _cell('Stat', header: true),
            _cell('Score', header: true),
            _cell('Grade', header: true),
          ],
          for (final subject in state.pack.manifest.subjects)
            [
              _subjectCell(subject),
              _cell(_stat(state.stats[subject] ?? 0)),
              _cell((forecast.subjectScores[subject] ?? 0).toStringAsFixed(1)),
              _cell('${forecast.grades[subject] ?? 9}'),
            ],
        ]),
        const SizedBox(height: 14),
        Text(
          'Standard score ${forecast.standardScore.toStringAsFixed(1)}'
          ' (top ${top.toStringAsFixed(1)}%)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: D30Colors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Overall grade ${Admissions.gradeFor(forecast.standardScore)}',
          style: const TextStyle(fontSize: 16, color: D30Colors.ink),
        ),
      ],
    );
  }
}

/// Bizarre Author's Note: the student's abilities. The view's `progress`
/// rows (comic DRAW_* against TARGET_DRAW_*) appear once a target is set.
class AbilitiesView extends StatelessWidget {
  final GameState state;
  final Map<String, dynamic> view;
  const AbilitiesView({super.key, required this.state, required this.view});
  @override
  Widget build(BuildContext context) {
    final progress = [
      for (final row in (view['progress'] as List? ?? const []))
        if (row is Map && state.switchValue('${row['target']}') > 0) row,
    ];
    String level(LevelTier tier) => tier.name.isEmpty
        ? 'Lv. ${tier.level}'
        : 'Lv. ${tier.level} ${tier.name}';
    return Column(
      key: const ValueKey('abilities'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Title('Abilities', 'Your current study stats and levels'),
        _table(
          'stats',
          [
            [_cell('Subject', header: true), _cell('Stat', header: true)],
            for (final subject in state.pack.manifest.subjects)
              [_subjectCell(subject), _cell(_stat(state.stats[subject] ?? 0))],
            [_cell('Total', header: true), _cell(_stat(state.totalStat))],
          ],
          widths: const {0: FlexColumnWidth(1.2)},
        ),
        const SizedBox(height: 12),
        _table(
          'levels',
          [
            [_cell('Skill', header: true), _cell('Level', header: true)],
            [_cell('Study'), _cell(level(state.studyLevel))],
            [_cell('Exercise'), _cell(level(state.exerciseLevel))],
            [_cell('Part-Time'), _cell(level(state.partTimeLevel))],
          ],
          widths: const {0: FlexColumnWidth(1.2)},
        ),
        if (progress.isNotEmpty) ...[
          const SizedBox(height: 12),
          _table(
            'comic',
            [
              [_cell('Comic', header: true), _cell('Progress', header: true)],
              for (final row in progress)
                [
                  _cell('${row['label']}'),
                  _cell(
                    '${state.switchValue('${row['value']}')} / '
                    '${state.switchValue('${row['target']}')}',
                  ),
                ],
            ],
            widths: const {0: FlexColumnWidth(1.2)},
          ),
        ],
      ],
    );
  }
}

/// Recipe: each potion with its ingredients, ticked when held.
class RecipeView extends StatelessWidget {
  final GameState state;
  final Map<String, dynamic> view;
  const RecipeView({super.key, required this.state, required this.view});

  Widget _ingredient(GameItem item) {
    final held = state.itemCount(item.id);
    return Container(
      key: ValueKey('recipe-input-${item.id}'),
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: held > 0 ? D30Colors.hpGreen : D30Colors.panelBorder,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: PackImage(path: 'items/${item.id}.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 4),
          Text(
            '${item.name} ×$held',
            style: const TextStyle(fontSize: 13, color: D30Colors.ink),
          ),
          if (held > 0) ...[
            const SizedBox(width: 2),
            const Icon(Icons.check, size: 16, color: D30Colors.hpGreen),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = state.pack.items;
    final fee = (view['fee'] as num?)?.toInt();
    final recipes = [
      for (final r in (view['recipes'] as List? ?? const []))
        if (r is Map && items[(r['output'] as num?)?.toInt()] != null) r,
    ];
    return Column(
      key: const ValueKey('recipes'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Title('Recipes', '${view['where'] ?? ''}'),
        for (final r in recipes) ...[
          Builder(
            builder: (_) {
              final output = items[(r['output'] as num).toInt()]!;
              final inputs = [
                for (final id in (r['inputs'] as List? ?? const []))
                  if (id is num && items[id.toInt()] != null)
                    items[id.toInt()]!,
              ];
              final ready = inputs.every((i) => state.itemCount(i.id) > 0);
              return Container(
                key: ValueKey('recipe-${output.id}'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEDB),
                  border: Border.all(color: D30Colors.accent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: PackImage(
                            path: 'items/${output.id}.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                output.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: D30Colors.ink,
                                ),
                              ),
                              Text(
                                output.effectText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: D30Colors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (ready)
                          const Text(
                            'Ready',
                            style: TextStyle(
                              fontSize: 13,
                              color: D30Colors.hpGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final i in inputs) _ingredient(i)],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        if (fee != null)
          Text(
            'Cooking fee: $fee Gold each',
            style: const TextStyle(fontSize: 14, color: D30Colors.ink),
          ),
      ],
    );
  }
}
