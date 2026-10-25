/// The Graduation Exam Score Announcement (HANDOFF section 2): a centered
/// cream panel over the dimmed School screen. A big orange Confirm opens the
/// peach table, whose subject columns reveal left to right; Next swaps in the
/// printable Score Card, Turn in Papers hands on to the Submit route.
///
/// Reads the stored scores (`game.scoreCard`); nothing here rolls anything.
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'press_feedback.dart';
import 'share_image.dart';
import 'theme.dart';
import 'toast.dart';

const _ink = Color(0xFF4A2508);
const _orange = Color(0xFFFF8B55);
const _peach = Color(0xFFFFEBD8);
const _rule = Color(0xFF6B3A1B);

/// How long each subject column takes to appear after the previous one.
const scoreRevealStep = Duration(milliseconds: 400);

/// Shows the announcement and returns once Turn in Papers was tapped
/// (`confirmScoreAnnouncement` has then been called).
Future<void> showScoreAnnouncement(BuildContext context, Game game) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => PopScope(
      canPop: false,
      child: ScoreAnnouncementPanel(
        game: game,
        onDone: () => Navigator.of(context).pop(),
      ),
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

enum _Phase { confirm, table, card }

class ScoreAnnouncementPanel extends StatefulWidget {
  final Game game;
  final VoidCallback onDone;
  const ScoreAnnouncementPanel({
    super.key,
    required this.game,
    required this.onDone,
  });

  @override
  State<ScoreAnnouncementPanel> createState() => _ScoreAnnouncementPanelState();
}

class _ScoreAnnouncementPanelState extends State<ScoreAnnouncementPanel>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.confirm;
  late final AnimationController _reveal;
  final _cardKey = GlobalKey();
  bool _done = false;

  Game get game => widget.game;
  List<String> get _subjects => game.pack.manifest.subjects;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: scoreRevealStep * _subjects.length,
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _confirm() {
    setState(() => _phase = _Phase.table);
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  /// Columns visible now: the first at once, then one per [scoreRevealStep].
  int get _shown => _reveal.isCompleted
      ? _subjects.length
      : (_reveal.value * _subjects.length).floor() + 1;

  void _turnIn() {
    if (_done) return;
    _done = true;
    game.confirmScoreAnnouncement();
    widget.onDone();
  }

  Future<void> _download() async {
    final name = game.state.fullName.replaceAll(RegExp(r'\W+'), '_');
    final ok = await saveWidgetImage(_cardKey, 'score_card_$name');
    if (!mounted) return;
    D30Toast.show(
      context,
      ok
          ? 'Score card saved to your gallery.'
          : 'Could not save the score card.',
    );
  }

  void _unavailable() => D30Toast.show(context, 'Not available in this build.');

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final u = (width / 393).clamp(0.8, 1.4);
    final side = (_phase == _Phase.card ? 24 : 28) * u;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 10 * u, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _MaybeAnimatedSize(
                animate: !MediaQuery.disableAnimationsOf(context),
                child: Container(
                  key: const ValueKey('score-announcement'),
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(side, 28 * u, side, 28 * u),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E6),
                    borderRadius: BorderRadius.circular(14 * u),
                    border: Border.all(color: _orange, width: 4 * u),
                  ),
                  child: switch (_phase) {
                    _Phase.confirm => _confirmBody(u),
                    _Phase.table => _tableBody(u),
                    _Phase.card => _cardBody(u),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(double u) => Text(
    'Graduation Exam Score Announcement',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: (_phase == _Phase.card ? 25 : 18) * u,
      color: _ink,
    ),
  );

  Widget _confirmBody(double u) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _title(u),
      SizedBox(height: 56 * u),
      PressFeedback(
        travel: 3,
        child: Material(
          color: _orange,
          shape: const CircleBorder(),
          elevation: 5,
          child: InkWell(
            key: const ValueKey('score-confirm'),
            customBorder: const CircleBorder(),
            onTap: _confirm,
            child: SizedBox.square(
              dimension: 118 * u,
              child: Center(
                child: Text(
                  'Confirm',
                  style: TextStyle(fontSize: 26 * u, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: 64 * u),
    ],
  );

  // --- the reveal table --------------------------------------------------

  Widget _tableBody(double u) {
    final card = game.scoreCard;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(u),
        SizedBox(height: 22 * u),
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) {
            final shown = _shown;
            Widget cell(
              String text, {
              required bool visible,
              Color? chip,
              Key? key,
            }) => Expanded(
              child: SizedBox(
                height: 40 * u,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    child: Container(
                      key: key,
                      padding: EdgeInsets.symmetric(
                        horizontal: chip == null ? 0 : 4 * u,
                        vertical: chip == null ? 0 : 3 * u,
                      ),
                      decoration: chip == null
                          ? null
                          : BoxDecoration(
                              color: chip,
                              borderRadius: BorderRadius.circular(10 * u),
                            ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          text,
                          maxLines: 1,
                          style: TextStyle(fontSize: 14 * u, color: _ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            Widget row(String label, List<Widget> cells, {bool last = false}) =>
                Container(
                  decoration: BoxDecoration(
                    border: last
                        ? null
                        : const Border(
                            bottom: BorderSide(color: _rule, width: 1),
                          ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 78 * u,
                        height: 40 * u,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: _rule, width: 1.5),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 15 * u, color: _ink),
                        ),
                      ),
                      ...cells,
                    ],
                  ),
                );
            return Container(
              key: const ValueKey('score-table'),
              padding: EdgeInsets.all(6 * u),
              decoration: BoxDecoration(
                color: _peach,
                borderRadius: BorderRadius.circular(12 * u),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  row('Subject', [
                    for (final s in _subjects)
                      cell(
                        _chipLabel(s),
                        visible: true,
                        chip: D30Colors.subject(s),
                      ),
                  ]),
                  row('Score', [
                    for (var i = 0; i < _subjects.length; i++)
                      cell(
                        '${card.examScores[_subjects[i]] ?? 0}',
                        visible: i < shown,
                        key: ValueKey('score-${_subjects[i]}'),
                      ),
                  ]),
                  row('Top %', [
                    for (var i = 0; i < _subjects.length; i++)
                      cell(
                        '${_top(card.topPercents[_subjects[i]])}%',
                        visible: i < shown,
                      ),
                  ], last: true),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 26 * u),
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) => Opacity(
            opacity: _reveal.isCompleted ? 1 : 0,
            child: SizedBox(
              width: 190 * u,
              child: D30RaisedButton(
                onPressed: _reveal.isCompleted
                    ? () => setState(() => _phase = _Phase.card)
                    : null,
                child: Text('Next', style: TextStyle(fontSize: 24 * u)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The compact header uses the short Humanities form the screens print.
  static String _chipLabel(String subject) => subjectLabel(subject);

  static String _top(double? v) => (v ?? 0).toStringAsFixed(1);

  // --- the printable card ------------------------------------------------

  Widget _cardBody(double u) {
    final card = game.scoreCard;
    final state = game.state;
    Widget share(Widget child, Color color, VoidCallback onTap, String tip) =>
        PressFeedback(
          child: Tooltip(
            message: tip,
            child: Material(
              color: color,
              shape: const CircleBorder(),
              child: InkWell(
                key: ValueKey('share-$tip'),
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 46 * u,
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(u),
        SizedBox(height: 16 * u),
        RepaintBoundary(
          key: _cardKey,
          child: PrintableScoreCard(
            name: state.fullName,
            gender: state.isMale ? 'Male' : 'Female',
            subjects: [
              for (final s in _subjects)
                (
                  label: _chipLabel(s),
                  score: card.examScores[s] ?? 0,
                  top: _top(card.topPercents[s]),
                ),
            ],
            u: u,
          ),
        ),
        SizedBox(height: 18 * u),
        SizedBox(
          width: double.infinity,
          child: D30RaisedButton(
            onPressed: _turnIn,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4 * u),
              child: Text('Turn in Papers', style: TextStyle(fontSize: 24 * u)),
            ),
          ),
        ),
        SizedBox(height: 12 * u),
        const Divider(color: _rule, height: 1),
        SizedBox(height: 22 * u),
        Text(
          'Show off your Score Card!',
          style: TextStyle(fontSize: 22 * u, color: _ink),
        ),
        SizedBox(height: 18 * u),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            share(
              Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 26 * u,
              ),
              const Color(0xFFE6007E),
              _unavailable,
              'Instagram',
            ),
            SizedBox(width: 12 * u),
            share(
              Text(
                'X',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24 * u,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Colors.black,
              _unavailable,
              'X',
            ),
            SizedBox(width: 12 * u),
            share(
              Icon(
                Icons.file_download_outlined,
                color: Colors.white,
                size: 30 * u,
              ),
              _orange,
              _download,
              'Save to gallery',
            ),
          ],
        ),
        SizedBox(height: 22 * u),
      ],
    );
  }
}

/// The white printable paper: Name / Gender, then Subject, Score, Top %.
class PrintableScoreCard extends StatelessWidget {
  final String name;
  final String gender;
  final List<({String label, int score, String top})> subjects;
  final double u;
  const PrintableScoreCard({
    super.key,
    required this.name,
    required this.gender,
    required this.subjects,
    this.u = 1,
  });

  static const _gray = Color(0xFFD9D9D9);

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, int flex, {bool gray = false}) => Expanded(
      flex: flex,
      child: Container(
        height: 31 * u,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: gray ? _gray : Colors.white,
          border: const Border(
            left: BorderSide(color: Colors.black, width: 1),
            top: BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(fontSize: 13 * u, color: Colors.black),
          ),
        ),
      ),
    );
    // Name takes two thirds of the subject-side width, Gender the rest.
    final units = subjects.length + 1;
    final genderFlex = (units / 3).round().clamp(1, units - 1);
    return Container(
      key: const ValueKey('exam-score-paper'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16 * u, 14 * u, 16 * u, 18 * u),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 5,
            offset: Offset(1, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Graduation Exam Score Card',
            style: TextStyle(fontSize: 16 * u, color: Colors.black),
          ),
          SizedBox(height: 16 * u),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.black, width: 1),
                bottom: BorderSide(color: Colors.black, width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 1, bottom: 1),
              child: Column(
                children: [
                  Row(
                    children: [
                      cell('Name', units - genderFlex, gray: true),
                      cell('Gender', genderFlex, gray: true),
                    ],
                  ),
                  Row(
                    children: [
                      cell(name, units - genderFlex),
                      cell(gender, genderFlex),
                    ],
                  ),
                  Row(
                    children: [
                      cell('Subject', 1, gray: true),
                      for (final s in subjects) cell(s.label, 1, gray: true),
                    ],
                  ),
                  Row(
                    children: [
                      cell('Score', 1, gray: true),
                      for (final s in subjects) cell('${s.score}', 1),
                    ],
                  ),
                  Row(
                    children: [
                      cell('Top %', 1, gray: true),
                      for (final s in subjects) cell('${s.top} %', 1),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The panel grows between phases; with reduced motion it just jumps.
class _MaybeAnimatedSize extends StatelessWidget {
  final bool animate;
  final Widget child;
  const _MaybeAnimatedSize({required this.animate, required this.child});

  @override
  Widget build(BuildContext context) => animate
      ? AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          child: child,
        )
      : child;
}
