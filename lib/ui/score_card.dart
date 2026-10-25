/// A saved exam result; displaying it never recalculates scores from live stats.
library;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import 'theme.dart';

class ExamScoreCard extends StatelessWidget {
  final String name;
  final CsatResult result;
  const ExamScoreCard({super.key, required this.name, required this.result});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Container(
      key: const ValueKey('exam-score-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Graduation Exam Score Card',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Text(name, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: const Color(0xFFBCA58C)),
            columnWidths: const {0: FlexColumnWidth(1.4)},
            children: [
              _row(['Subject', 'Score', 'Top %'], header: true),
              for (final entry in result.subjectScores.entries)
                _row([
                  subjectLabel(entry.key),
                  entry.value.toStringAsFixed(1),
                  (100 - Admissions.percentileOf(entry.value)).toStringAsFixed(
                    1,
                  ),
                ]),
            ],
          ),
          const SizedBox(height: 16),
          Text('Standard score: ${result.standardScore.toStringAsFixed(1)}'),
        ],
      ),
    ),
  );
  TableRow _row(List<String> cells, {bool header = false}) => TableRow(
    decoration: BoxDecoration(
      color: header ? const Color(0xFFFFEEDB) : Colors.white,
    ),
    children: [
      for (final text in cells)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: header ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
    ],
  );
}
