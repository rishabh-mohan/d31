/// The Submit route (HANDOFF sections 3-9): a full-screen page with the
/// Quests / University Collection / Turn In header, the orange tab band over
/// a sliding PageView, and the pinned three-slot candidate tray. Turn In opens
/// the Apply? confirmation; its Confirm commits the draft once and hands over
/// to the results flow.
///
/// Every number comes from the engine (docs/DDAY-FLOW.md); the draft lives in
/// the run, so tabs, modals and a resume never lose it.
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'account_widgets.dart';
import 'csat_screen.dart';
import 'daily_quest.dart';
import 'press_feedback.dart';
import 'submit_tabs.dart';
import 'submit_widgets.dart';
import 'theme.dart';
import 'toast.dart';
import 'university_collection.dart';

class SubmitPage extends StatefulWidget {
  final Game game;
  final EndingsOverScene? endings;
  const SubmitPage({super.key, required this.game, this.endings});

  @override
  State<SubmitPage> createState() => _SubmitPageState();
}

class _SubmitPageState extends State<SubmitPage> {
  late final SubmitModel _model = SubmitModel(widget.game);
  final _pages = PageController();
  int _tab = 0;
  bool _committing = false;

  Game get game => widget.game;

  static const _tabLabels = [
    'Recommended Majors',
    'Search within Schools',
    'Search Majors',
  ];

  @override
  void dispose() {
    _pages.dispose();
    _model.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _turnIn() async {
    if (_committing) return;
    if (game.draftSlots.every((s) => s == null)) {
      D30Toast.show(context, 'Add at least one application candidate.');
      return;
    }
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => ApplyDialog(game: game),
      transitionBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    );
    if (confirmed != true || !mounted || _committing) return;
    _committing = true;
    await CsatScreen.pushResults(context, game, endings: widget.endings);
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      // No way out except submitting; Back only closes an open school.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _model.openSchool != null) {
          _model.openSchoolMajors(null);
        }
      },
      child: Scaffold(
        key: const ValueKey('submit-page'),
        backgroundColor: submitCream,
        body: SafeArea(
          child: Column(
            children: [
              _header(u),
              _tabBand(u),
              Expanded(
                child: ClipRect(
                  child: PageView(
                    key: const ValueKey('submit-pages'),
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _tab = i),
                    children: [
                      _KeepAlive(child: RecommendedTab(model: _model)),
                      _KeepAlive(child: SchoolsTab(model: _model)),
                      _KeepAlive(child: SearchTab(model: _model)),
                    ],
                  ),
                ),
              ),
              // The keyboard covers the tray in the original; the page just
              // uses the remaining height.
              if (!keyboard) _Tray(model: _model),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(double u) => Padding(
    padding: EdgeInsets.fromLTRB(8 * u, 8 * u, 8 * u, 6 * u),
    child: ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final full = game.draftSlots.every((s) => s != null);
        return Row(
          children: [
            SubmitHeaderButton(
              buttonKey: const ValueKey('quests-button'),
              width: 58 * u,
              color: const Color(0xFF14171C),
              onTap: () => pushOverlay<void>(
                context,
                DailyQuestPanel(catalog: game.pack.admissions),
              ),
              child: Text(
                'Quests',
                style: TextStyle(fontSize: 14 * u, color: Colors.white),
              ),
            ),
            SizedBox(width: 6 * u),
            SubmitHeaderButton(
              buttonKey: const ValueKey('collection-button'),
              width: 62 * u,
              color: const Color(0xFF4F6B85),
              onTap: () => pushOverlay<void>(
                context,
                UniversityCollectionPanel(game: game),
              ),
              child: Text(
                'University Collection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12 * u,
                  height: 1.15,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Submit',
                  style: TextStyle(fontSize: 27 * u, color: submitOrange),
                ),
              ),
            ),
            SubmitHeaderButton(
              buttonKey: const ValueKey('turn-in-button'),
              width: 72 * u,
              color: full ? const Color(0xFFE5173F) : const Color(0xFFC95A24),
              onTap: _turnIn,
              child: Text(
                'Turn In',
                style: TextStyle(fontSize: 17 * u, color: Colors.white),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _tabBand(double u) => Container(
    color: submitOrange,
    height: 42 * u,
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / 3;
        return Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  SizedBox(
                    width: w,
                    child: InkWell(
                      key: ValueKey('submit-tab-$i'),
                      onTap: () => _goTo(i),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4 * u),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _tabLabels[i],
                              style: TextStyle(
                                fontSize: 13.5 * u,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // The cream notch under the selected tab follows the swipe.
            AnimatedBuilder(
              animation: _pages,
              builder: (context, _) {
                final page = _pages.hasClients
                    ? (_pages.page ?? _tab.toDouble())
                    : _tab.toDouble();
                return Positioned(
                  left: page * w,
                  width: w,
                  bottom: 0,
                  height: 4 * u,
                  child: const IgnorePointer(
                    child: ColoredBox(color: submitCream),
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// The candidate tray
// ---------------------------------------------------------------------------

class _Tray extends StatelessWidget {
  final SubmitModel model;
  const _Tray({required this.model});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final game = model.game;
        final slots = game.draftSlots;
        return Container(
          key: const ValueKey('submit-tray'),
          color: const Color(0xFFFFF1DE),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The handle suggests expanding the tray; it does nothing here
              // (the recording never activates it).
              Container(
                height: 30 * u,
                color: submitOrange,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: Size(34 * u, 15 * u),
                  painter: const _TrianglePainter(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * u, 8 * u, 16 * u, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PressFeedback(
                    travel: 2,
                    child: Material(
                      color: submitOrange,
                      borderRadius: BorderRadius.circular(10 * u),
                      child: InkWell(
                        key: const ValueKey('auto-input'),
                        borderRadius: BorderRadius.circular(10 * u),
                        onTap: () => model.autoInput(context),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12 * u,
                            vertical: 6 * u,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.autorenew,
                                color: Colors.white,
                                size: 22 * u,
                              ),
                              SizedBox(width: 6 * u),
                              Text(
                                'Auto Input',
                                style: TextStyle(
                                  fontSize: 16 * u,
                                  color: Colors.white,
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
              Padding(
                padding: EdgeInsets.fromLTRB(25 * u, 8 * u, 25 * u, 6 * u),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final gap = 22 * u;
                    final size = ((box.maxWidth - gap * 2) / 3).clamp(
                      60.0,
                      130.0,
                    );
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < slots.length; i++)
                          _Slot(model: model, slot: i, size: size),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10 * u, 0, 10 * u, 8 * u),
                child: Text(
                  'In-game university data does not reflect real-life '
                  'university and major rankings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5 * u, color: submitInk),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = submitCream,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => false;
}

class _Slot extends StatelessWidget {
  final SubmitModel model;
  final int slot;
  final double size;
  const _Slot({required this.model, required this.slot, required this.size});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final game = model.game;
    final id = game.draftSlots[slot];
    final d = id == null ? null : game.pack.admissions.departments[id];
    final radius = BorderRadius.circular(12 * u);
    if (d == null) {
      return Container(
        key: ValueKey('slot-$slot-empty'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EC),
          borderRadius: radius,
          border: Border.all(color: submitOrange, width: 2.5 * u),
        ),
        child: Text(
          'Application\nCandidate',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5 * u, color: submitCoral, height: 1.3),
        ),
      );
    }
    final school = game.pack.admissions.universities[d.universityId];
    final color = Color.lerp(schoolColor(school), Colors.black, .3)!;
    return Semantics(
      button: true,
      label: 'Remove ${model.labelOf(d)}',
      child: InkWell(
        key: ValueKey('slot-$slot-filled'),
        borderRadius: radius,
        onTap: () => model.removeSlot(context, slot),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: radius,
            border: Border.all(color: color, width: 2.5 * u),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: .3,
                  child: Crest(university: school, size: size * .78),
                ),
                Text(
                  '${game.displayedRate(d)}%',
                  style: TextStyle(fontSize: 32 * u, color: submitInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Apply? confirmation
// ---------------------------------------------------------------------------

/// Pops `true` once Confirm committed the draft (`submitDraft`, exactly once),
/// `false` when the X closed it; the draft is untouched either way until
/// Confirm.
class ApplyDialog extends StatefulWidget {
  final Game game;
  const ApplyDialog({super.key, required this.game});

  @override
  State<ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<ApplyDialog> {
  bool _busy = false;

  void _confirm() {
    if (_busy) return;
    _busy = true;
    widget.game.submitDraft();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final game = widget.game;
    final departments = game.draftDepartments;
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  key: const ValueKey('apply-dialog'),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E6),
                    borderRadius: BorderRadius.circular(14 * u),
                    border: Border.all(color: submitOrange, width: 5 * u),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16 * u,
                          32 * u,
                          16 * u,
                          26 * u,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Apply?',
                              style: TextStyle(
                                fontSize: 30 * u,
                                color: submitInk,
                              ),
                            ),
                            SizedBox(height: 22 * u),
                            for (final d in departments) ...[
                              Text(
                                game
                                        .pack
                                        .admissions
                                        .universities[d.universityId]
                                        ?.name ??
                                    '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22 * u,
                                  color: submitInk,
                                ),
                              ),
                              Text(
                                d.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16 * u,
                                  color: submitInk,
                                ),
                              ),
                              SizedBox(height: 4 * u),
                              Text(
                                'Acceptance Rate : ${game.displayedRate(d)}',
                                style: TextStyle(
                                  fontSize: 18 * u,
                                  color: submitInk,
                                ),
                              ),
                              SizedBox(height: 16 * u),
                            ],
                            Text(
                              'Chances of total rejection : '
                              '${game.totalRejectionText(departments)}%',
                              key: const ValueKey('total-rejection'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20 * u,
                                color: submitCoral,
                              ),
                            ),
                            SizedBox(height: 24 * u),
                            SizedBox(
                              width: 140 * u,
                              child: D30RaisedButton(
                                key: const ValueKey('apply-confirm'),
                                onPressed: _confirm,
                                child: Text(
                                  'Confirm',
                                  style: TextStyle(fontSize: 22 * u),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: PressFeedback(
                          travel: 2,
                          child: Material(
                            color: submitOrange,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8 * u),
                              bottomLeft: Radius.circular(10 * u),
                            ),
                            child: InkWell(
                              key: const ValueKey('apply-close'),
                              onTap: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: SizedBox.square(
                                dimension: 46 * u,
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 34 * u,
                                ),
                              ),
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
    );
  }
}
