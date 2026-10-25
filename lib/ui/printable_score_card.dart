/// The white, printable "Graduation Exam Score Card" of the completion
/// summary: a Name / Gender table over Subject, Score and Top % rows.
///
/// Reads the stored [CsatResult] only; it never recomputes a score.
library;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import 'theme.dart';

class PrintableScoreCard extends StatelessWidget {
  final String name;
  final bool isMale;
  final CsatResult? result;

  /// The pack's subjects in order (the order of the five columns).
  final List<String> subjects;

  const PrintableScoreCard({
    super.key,
    required this.name,
    required this.isMale,
    required this.result,
    required this.subjects,
  });

  static const _line = Color(0xFF555555);

  Widget _cell(
    String text, {
    bool header = false,
    bool bold = false,
    double size = 10.5,
  }) => Container(
    color: header ? const Color(0xFFE6E6E6) : Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
    alignment: Alignment.center,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size,
          fontWeight: header || bold ? FontWeight.w700 : FontWeight.w400,
          color: Colors.black87,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = result;
    String score(String s) => r?.examScores[s]?.toString() ?? '—';
    String top(String s) {
      final v = r?.topPercents[s];
      return v == null ? '—' : '${v.toStringAsFixed(1)} %';
    }

    return Container(
      key: const ValueKey('printable-score-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Graduation Exam Score Card',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Table(
            border: TableBorder.all(color: _line, width: .8),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: [
              TableRow(
                children: [
                  _cell('Name', header: true),
                  _cell('Gender', header: true),
                ],
              ),
              TableRow(
                children: [_cell(name), _cell(isMale ? 'Male' : 'Female')],
              ),
            ],
          ),
          Table(
            border: const TableBorder(
              left: BorderSide(color: _line, width: .8),
              right: BorderSide(color: _line, width: .8),
              bottom: BorderSide(color: _line, width: .8),
              horizontalInside: BorderSide(color: _line, width: .8),
              verticalInside: BorderSide(color: _line, width: .8),
            ),
            columnWidths: const {0: FlexColumnWidth(1.25)},
            children: [
              TableRow(
                children: [
                  _cell('Subject', header: true, size: 9.5),
                  for (final s in subjects)
                    _cell(subjectLabel(s), header: true, size: 9.5),
                ],
              ),
              TableRow(
                children: [
                  _cell('Score', header: true, size: 9.5),
                  for (final s in subjects) _cell(score(s), size: 10),
                ],
              ),
              TableRow(
                children: [
                  _cell('Top %', header: true, size: 9.5),
                  for (final s in subjects) _cell(top(s), size: 9),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
