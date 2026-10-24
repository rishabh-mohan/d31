/// Exam day after the Graduation Exam: the CSAT report card, the
/// applications, and where to enrol.
///
/// The original's admission screens were not captured, so this layout is the
/// project's own. What it decides is the original's: the departments and their
/// cutoffs are the shipped catalog, and enrolling raises `ENDING_CODE`, which
/// is what every ending waits on.
library;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import '../engine/game.dart';
import 'press_feedback.dart';
import 'theme.dart';

enum _Phase { results, apply, verdict }

class CsatScreen extends StatefulWidget {
  final Game game;

  const CsatScreen({super.key, required this.game});

  /// Runs the whole sitting; returns once the student has enrolled (or chosen
  /// to retake the year).
  static Future<void> show(BuildContext context, Game game) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => CsatScreen(game: game),
        ),
      );

  @override
  State<CsatScreen> createState() => _CsatScreenState();
}

class _CsatScreenState extends State<CsatScreen> {
  late _Phase _phase = widget.game.state.applications.isEmpty
      ? _Phase.results
      : _Phase.verdict;
  final List<int> _chosen = [];
  int? _enrolIn;
  String _query = '';
  bool _reachableOnly = true;

  Game get game => widget.game;

  @override
  Widget build(BuildContext context) {
    final csat = game.takeCsat();
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: D30Colors.page,
        body: SafeArea(
          child: switch (_phase) {
            _Phase.results => _results(csat),
            _Phase.apply => _apply(csat),
            _Phase.verdict => _verdict(),
          },
        ),
      ),
    );
  }

  // --- report card --------------------------------------------------------

  Widget _results(CsatResult csat) {
    final subjects = game.pack.manifest.subjects;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const _Title('CSAT Results'),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: [
              const _Row(
                cells: ['Subject', 'Score', 'Grade'],
                header: true,
              ),
              const Divider(height: 12),
              for (final s in subjects)
                _Row(
                  cells: [
                    _cap(s),
                    (csat.subjectScores[s] ?? 0).toStringAsFixed(1),
                    '${csat.grades[s] ?? 9}',
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: [
              Text(
                'Standard score ${csat.standardScore.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 22, color: D30Colors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Top ${(100 - csat.percentile).clamp(0.1, 100).toStringAsFixed(1)}% '
                'of test takers',
                style: const TextStyle(fontSize: 15, color: D30Colors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        D30RaisedButton(
          onPressed: () => setState(() => _phase = _Phase.apply),
          child: const Text('Choose universities', style: TextStyle(fontSize: 17)),
        ),
      ],
    );
  }

  // --- applications -------------------------------------------------------

  Widget _apply(CsatResult csat) {
    final limit = game.applicationLimit;
    final query = _query.trim().toLowerCase();
    final departments = game.departmentsByCutoff().where((d) {
      if (_reachableOnly && game.admissionChance(d) < 0.15) return false;
      if (query.isEmpty) return true;
      final university = game.pack.admissions.universities[d.universityId];
      return d.name.toLowerCase().contains(query) ||
          (university?.name.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              _Title('Applications (${_chosen.length} / $limit)'),
              const SizedBox(height: 4),
              Text(
                'Your standard score: ${csat.standardScore.toStringAsFixed(1)}',
                style: const TextStyle(color: D30Colors.inkSoft),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search universities or departments',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: D30Colors.panel,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _reachableOnly,
                    onChanged: (v) => setState(() => _reachableOnly = v!),
                  ),
                  const Expanded(child: Text('Only show realistic choices')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: departments.length,
            itemBuilder: (context, i) => _departmentTile(departments[i], limit),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: PressFeedback(
                  child: TextButton(
                    onPressed: () => setState(() {
                      game.submitApplications(const []);
                      _phase = _Phase.verdict;
                    }),
                    child: const Text('Retake the year'),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: D30RaisedButton(
                  onPressed: _chosen.isEmpty
                      ? null
                      : () => setState(() {
                          game.submitApplications(_chosen);
                          _phase = _Phase.verdict;
                        }),
                  child: const Text('Submit applications'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _departmentTile(Department d, int limit) {
    final university = game.pack.admissions.universities[d.universityId];
    final allowed = game.canApply(d);
    final chosen = _chosen.contains(d.id);
    final chance = game.admissionChance(d);
    final (label, colour) = switch (chance) {
      >= 0.85 => ('Safe', D30Colors.hpGreen),
      >= 0.45 => ('Fair', D30Colors.accentDark),
      _ => ('Reach', D30Colors.alert),
    };
    return Card(
      color: chosen ? const Color(0xFFFFE6CF) : D30Colors.panel,
      child: ListTile(
        enabled: allowed && (chosen || _chosen.length < limit),
        onTap: () => setState(() {
          chosen ? _chosen.remove(d.id) : _chosen.add(d.id);
        }),
        title: Text(
          university?.name ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          allowed ? d.name : '${d.name}\n${d.condition ?? 'Not eligible'}',
        ),
        isThreeLine: !allowed,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(d.deviation.toStringAsFixed(1)),
            allowed
                ? Text(label, style: TextStyle(color: colour))
                : const Icon(Icons.lock, size: 16),
          ],
        ),
      ),
    );
  }

  // --- results and enrolment ----------------------------------------------

  Widget _verdict() {
    final admitted = game.state.admittedDepartments;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const _Title('Admission Results'),
        const SizedBox(height: 16),
        if (game.state.applications.isEmpty)
          const _Panel(
            child: Text(
              'No applications sent.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: D30Colors.ink),
            ),
          ),
        for (final id in game.state.applications) _verdictTile(id, admitted),
        const SizedBox(height: 24),
        if (admitted.isEmpty)
          D30RaisedButton(
            onPressed: _finish,
            child: const Text('Retake the year', style: TextStyle(fontSize: 17)),
          )
        else
          D30RaisedButton(
            onPressed: _enrolIn == null ? null : _finish,
            child: const Text('Enrol', style: TextStyle(fontSize: 17)),
          ),
      ],
    );
  }

  Widget _verdictTile(int id, List<int> admitted) {
    final d = game.pack.admissions.departments[id];
    if (d == null) return const SizedBox.shrink();
    final university = game.pack.admissions.universities[d.universityId];
    final accepted = admitted.contains(id);
    return Card(
      color: D30Colors.panel,
      child: ListTile(
        onTap: accepted ? () => setState(() => _enrolIn = id) : null,
        leading: accepted
            ? Icon(
                _enrolIn == id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: D30Colors.accent,
              )
            : const Icon(Icons.close, color: D30Colors.alert),
        title: Text(university?.name ?? ''),
        subtitle: Text(d.name),
        trailing: Text(
          accepted ? 'Accepted' : 'Rejected',
          style: TextStyle(
            color: accepted ? D30Colors.hpGreen : D30Colors.alert,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _finish() {
    game.enroll(_enrolIn);
    Navigator.of(context).pop();
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 26,
      color: D30Colors.ink,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: D30Colors.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: D30Colors.panelBorder, width: 2),
    ),
    child: child,
  );
}

class _Row extends StatelessWidget {
  final List<String> cells;
  final bool header;
  const _Row({required this.cells, this.header = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: i == 0 ? 2 : 1,
            child: Text(
              cells[i],
              textAlign: i == 0 ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                color: header ? D30Colors.inkSoft : D30Colors.ink,
                fontWeight: header ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
      ],
    ),
  );
}
