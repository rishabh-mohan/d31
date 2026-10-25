/// PLACEHOLDER results flow so this branch stays playable: the plain verdict
/// list and enroll button the CSAT screen used to have. The results/enrollment
/// agent replaces this file; the public constructor below is the hand-off
/// contract (`DdayResultsFlow(game:, onFinished:)`): it is pushed after
/// `submitDraft()` and calls [onFinished] once the student has enrolled (or
/// chosen the retake academy).
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'theme.dart';

class DdayResultsFlow extends StatefulWidget {
  const DdayResultsFlow({
    super.key,
    required this.game,
    required this.onFinished,
  });

  final Game game;
  final VoidCallback onFinished;

  @override
  State<DdayResultsFlow> createState() => _DdayResultsFlowState();
}

class _DdayResultsFlowState extends State<DdayResultsFlow> {
  int? _enrolIn;
  bool _finished = false;

  Game get game => widget.game;

  @override
  void initState() {
    super.initState();
    game.confirmResults();
  }

  @override
  Widget build(BuildContext context) {
    final admitted = game.state.admittedDepartments;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: D30Colors.page,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              const Text(
                'Admission Results',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  color: D30Colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (game.state.applications.isEmpty)
                const Text(
                  'No applications sent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: D30Colors.ink),
                ),
              for (final id in game.state.applications) _tile(id, admitted),
              const SizedBox(height: 24),
              if (admitted.isEmpty)
                D30RaisedButton(
                  onPressed: _finish,
                  child: const Text(
                    'Retake the year',
                    style: TextStyle(fontSize: 17),
                  ),
                )
              else
                D30RaisedButton(
                  onPressed: _enrolIn == null ? null : _finish,
                  child: const Text('Enroll', style: TextStyle(fontSize: 17)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(int id, List<int> admitted) {
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
    if (_finished) return;
    _finished = true;
    if (_enrolIn == null) {
      game.enrollRetake();
    } else {
      game.enroll(_enrolIn);
    }
    widget.onFinished();
  }
}
