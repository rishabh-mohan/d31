/// The application-results sequence: title, envelopes, combined results,
/// Final Decision, Confirm Enrollment and the Student ID / share scene.
///
/// Everything here is presentation over stored engine state
/// (docs/DDAY-FLOW.md): the verdicts were rolled once by `submitDraft()`;
/// this flow only reveals them, so rebuilding, rotating or resuming never
/// rerolls anything. It ends by calling [DdayResultsFlow.onFinished]; the host
/// then plays the authored ending events. See docs/DDAY-UI.md ("Results and
/// enrollment") for the reconstructed choices.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'dday_widgets.dart';
import 'press_feedback.dart';
import 'share_image.dart';
import 'student_photo.dart';
import 'theme.dart';

enum _Phase { title, envelopes, cards, scene }

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
  Game get game => widget.game;
  late _Phase _phase;
  bool _picking = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final state = game.state;
    final results = game.applicationResults;
    if (state.finalDecided) {
      _phase = _Phase.scene;
    } else if (state.resultsReviewed || results.isEmpty) {
      // Nothing to reveal (no applications) or already confirmed: straight to
      // the Final Decision page, which offers the academy when nothing
      // accepted the student.
      if (results.isEmpty) game.confirmResults();
      _phase = _Phase.cards;
    } else if (game.resultsRevealed >= results.length) {
      _phase = _Phase.cards;
    } else if (game.resultsRevealed > 0) {
      _phase = _Phase.envelopes;
    } else {
      _phase = _Phase.title;
    }
  }

  void _go(_Phase phase) {
    if (!mounted) return;
    setState(() => _phase = phase);
  }

  Future<void> _pick(FinalOption option) async {
    if (_picking || game.state.finalDecided) return;
    _picking = true;
    try {
      final confirmed = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: .72),
        transitionDuration: reducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        pageBuilder: (context, _, _) =>
            _ConfirmEnrollmentDialog(game: game, option: option),
        transitionBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );
      if (confirmed != true || !mounted) return;
      // The loading square has finished: now, and only now, the engine
      // records the decision (idempotent if it was somehow made already).
      if (option.isRetake) {
        game.enrollRetake();
      } else {
        game.enroll(option.department.id);
      }
      _go(_Phase.scene);
    } finally {
      _picking = false;
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_phase) {
      _Phase.title => _ResultsTitle(
        key: const ValueKey('results-title'),
        onDone: () => _go(_Phase.envelopes),
      ),
      _Phase.envelopes => _EnvelopeStage(
        key: const ValueKey('results-envelopes'),
        game: game,
        onAllRevealed: () => _go(_Phase.cards),
      ),
      _Phase.cards => _CardsPage(
        key: const ValueKey('results-cards'),
        game: game,
        onPick: _pick,
      ),
      _Phase.scene => _ShareScene(
        key: const ValueKey('results-scene'),
        game: game,
        onConfirm: _finish,
      ),
    };
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          child: page,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Title
// ---------------------------------------------------------------------------

/// Near-black page; "Application Results Announcement" fades in, holds
/// about 1.5 s and fades out. A tap skips it. (RECOVERED sequence; the
/// timings are reconstructed, HANDOFF section 10.)
class _ResultsTitle extends StatefulWidget {
  final VoidCallback onDone;
  const _ResultsTitle({super.key, required this.onDone});

  @override
  State<_ResultsTitle> createState() => _ResultsTitleState();
}

class _ResultsTitleState extends State<_ResultsTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      // No fading title under reduced motion: go straight on.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
    } else if (!_clock.isAnimating && _clock.value == 0) {
      _clock.forward().whenComplete(() {
        if (mounted) _finish();
      });
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 25),
      TweenSequenceItem(tween: ConstantTween(1), weight: 47),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 28),
    ]).animate(_clock);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: ColoredBox(
        color: const Color(0xFF111111),
        child: Center(
          child: FadeTransition(
            opacity: opacity,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Application Results\nAnnouncement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF4F1EC),
                  fontSize: 34,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2-3. Envelopes
// ---------------------------------------------------------------------------

enum _Step { idle, opening, card, stashing }

/// Browse reveal (DDAY-C06): from the Browse tap to the settled verdict card.
/// The original gives each stage more time than the first rebuild's 2.8 s;
/// the stages below are fractions of [envelopeOpenDuration] and overlap.
const Duration envelopeOpenDuration = Duration(milliseconds: 5000);

/// Others leave, the active envelope centres and enlarges.
const (double, double) _stageMove = (0.0, 0.16);

/// The tilt wobble.
const (double, double) _stageTilt = (0.16, 0.38);

/// The flap opens.
const (double, double) _stageFlap = (0.36, 0.54);

/// The letter rises out of the pocket.
const (double, double) _stageLetter = (0.50, 0.72);

/// The school-coloured glow expands.
const (double, double) _stageGlow = (0.60, 0.88);

/// The envelope fades and the verdict card appears.
const (double, double) _stageCard = (0.84, 1.0);

/// Confetti starts here.
const double _confettiFrom = 0.84;

class _EnvelopeStage extends StatefulWidget {
  final Game game;
  final VoidCallback onAllRevealed;
  const _EnvelopeStage({
    super.key,
    required this.game,
    required this.onAllRevealed,
  });

  @override
  State<_EnvelopeStage> createState() => _EnvelopeStageState();
}

class _EnvelopeStageState extends State<_EnvelopeStage>
    with TickerProviderStateMixin {
  Game get game => widget.game;
  late final List<ApplicationResultView> _views = [
    for (final r in game.applicationResults) ApplicationResultView.of(r),
  ];
  late int _revealed = game.resultsRevealed;
  _Step _step = _Step.idle;

  /// Browse: the staged envelope animation (about 5 s), driven through
  /// Intervals: others leave, the active one centres and wobbles, the flap
  /// opens, the letter rises, the school-coloured glow expands and the
  /// verdict card appears.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: envelopeOpenDuration,
  );

  /// Confirm: the card moves up behind the stack and the next envelope
  /// comes forward.
  late final AnimationController _stash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    _open.addStatusListener((status) {
      if (status == AnimationStatus.completed && _step == _Step.opening) {
        setState(() => _step = _Step.card);
      }
    });
    _stash.addStatusListener((status) {
      if (status == AnimationStatus.completed && _step == _Step.stashing) {
        _afterStash();
      }
    });
  }

  @override
  void dispose() {
    _open.dispose();
    _stash.dispose();
    super.dispose();
  }

  bool get _reduced => reducedMotion(context);

  void _browse() {
    if (_step != _Step.idle || _revealed >= _views.length) return;
    if (_reduced) {
      _open.value = 1;
      setState(() => _step = _Step.card);
      return;
    }
    setState(() => _step = _Step.opening);
    _open.forward(from: 0);
  }

  /// The green double-chevron. RECONSTRUCTED: the recording shows the button
  /// but never taps it. It skips straight to the revealed result card of the
  /// current envelope (never past the Confirm, which stays the player's).
  void _fastForward() {
    if (_step == _Step.idle || _step == _Step.opening) {
      _open.value = 1;
      setState(() => _step = _Step.card);
    }
  }

  void _confirm() {
    if (_step != _Step.card) return;
    game.confirmNextResult();
    setState(() {
      _revealed = game.resultsRevealed;
      _step = _Step.stashing;
    });
    if (_reduced) {
      _afterStash();
    } else {
      _stash.forward(from: 0);
    }
  }

  void _afterStash() {
    if (!mounted) return;
    if (_revealed >= _views.length) {
      widget.onAllRevealed();
      return;
    }
    _open.value = 0;
    setState(() => _step = _Step.idle);
  }

  static double _seg(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      return AnimatedBuilder(
        animation: Listenable.merge([_open, _stash]),
        builder: (context, _) => _stage(w, h),
      );
    },
  );

  Widget _stage(double w, double h) {
    final n = _views.length;
    final stashing = _step == _Step.stashing;
    final s = stashing ? Curves.easeInOutCubic.transform(_stash.value) : 1.0;
    final o = _open.value;
    final opening = _step == _Step.opening;
    final cardStep = _step == _Step.card;
    final active = math.min(_revealed, n - 1);
    final view = stashing || _revealed >= n
        ? null
        : _views[active]; // the envelope being worked on
    final shown = stashing ? _views[_revealed - 1] : view;

    final frontW = w * .68;
    final frontH = frontW / 1.57;
    final frontTop = h * .46;
    final cx = w / 2;
    final centerY = h * .5;
    final cardW = w * .70;
    final cardH = h * .204;
    final rankStep = h * .058;

    // Browse timeline.
    final move = Curves.easeInOut.transform(_seg(o, _stageMove.$1, _stageMove.$2));
    final wobble = _seg(o, _stageTilt.$1, _stageTilt.$2);
    final flap = Curves.easeInOut.transform(_seg(o, _stageFlap.$1, _stageFlap.$2));
    final rise = Curves.easeOut.transform(_seg(o, _stageLetter.$1, _stageLetter.$2));
    final glowGrow = Curves.easeOut.transform(_seg(o, _stageGlow.$1, _stageGlow.$2));
    final fade = Curves.easeIn.transform(_seg(o, _stageCard.$1, _stageCard.$2));
    final angle = .085 * math.sin(wobble * math.pi * 3) * (1 - wobble * .4);
    final glowColor = shown?.color ?? D30Colors.accent;
    final glowing = (opening || cardStep) && shown != null;

    // Remaining (unopened) envelopes; the front one is `_revealed` (or the
    // next one while stashing).
    final children = <Widget>[];

    // Page tint behind everything while the glow expands.
    children.add(
      Positioned.fill(
        child: ColoredBox(
          color: Color.lerp(
            const Color(0xFF111111),
            glowColor,
            glowing ? .20 * glowGrow * (1 - fade * .8) : 0,
          )!,
        ),
      ),
    );

    // --- stash: revealed cards peeking out behind the stack ----------------
    final remaining = n - _revealed;
    final ranksBehind = math.max(0, remaining - 1) + (stashing ? 1 - s : 0);
    final topmost = frontTop - ranksBehind * rankStep;
    // While one envelope opens and its verdict shows, only that card is on
    // screen (DDAY-C04); the earlier ones return for the stack and, as the
    // confirmed card tucks away, fade back in.
    final stashVisible = opening ? 1 - move : (cardStep ? 0.0 : 1.0);
    for (var j = 0; j < _revealed; j++) {
      final justConfirmed = stashing && j == _revealed - 1;
      final vis = justConfirmed ? 1.0 : (stashing ? s : stashVisible);
      if (vis <= 0) continue;
      final depth =
          (_revealed - 1 - j) - (stashing && !justConfirmed ? 1 - s : 0);
      final scale = (.82 - depth * .06).clamp(.5, 1.0);
      final stashH = cardH * scale;
      final stashW = cardW * scale;
      final stashTop = topmost - h * .062 * (1 + depth * .72) - 0;
      final top = justConfirmed
          ? (centerY - cardH / 2) + (stashTop - (centerY - cardH / 2)) * s
          : stashTop;
      final width = justConfirmed ? cardW + (stashW - cardW) * s : stashW;
      final height = justConfirmed ? cardH + (stashH - cardH) * s : stashH;
      children.add(
        Positioned(
          left: cx - width / 2,
          top: top,
          width: width,
          height: height,
          child: Opacity(
            opacity: justConfirmed ? 1 : .88 * vis,
            child: ResultCard(
              key: ValueKey('stash-card-$j'),
              view: _views[j],
              width: width,
              height: height,
            ),
          ),
        ),
      );
    }

    // --- envelopes, back to front -------------------------------------------
    for (var k = n - 1; k >= _revealed; k--) {
      final isActive = !stashing && k == _revealed;
      final rank = (k - _revealed) + (stashing ? 1 - s : 0);
      final ev = _views[k];
      if (isActive) {
        final scale = 1 + .18 * move;
        final ew = frontW * scale;
        final eh = frontH * scale;
        final y =
            (frontTop + frontH / 2) + (centerY - frontTop - frontH / 2) * move;
        final envelopeAlpha = 1 - fade;
        if (envelopeAlpha > 0) {
          children.add(
            Positioned(
              left: cx - ew / 2,
              top: y - eh / 2,
              width: ew,
              height: eh,
              child: Opacity(
                opacity: envelopeAlpha,
                child: Transform.rotate(
                  angle: angle,
                  child: EnvelopeView(
                    key: ValueKey('envelope-$k'),
                    color: ev.color,
                    university: ev.university,
                    flap: flap,
                    letterRise: rise,
                    letter: (opening || cardStep) ? _letter(ev, ew) : null,
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        final scale = math.max(.6, 1 - .09 * rank);
        final ew = frontW * scale;
        final eh = frontH * scale;
        final top = frontTop - rank * rankStep + (frontH - eh) * .0;
        // Others leave downward and fade while the active one is opened.
        final away = opening || cardStep ? move : 0.0;
        children.add(
          Positioned(
            left: cx - ew / 2,
            top: top + away * h * .25,
            width: ew,
            height: eh,
            child: Opacity(
              opacity: (rank > 0 ? .92 : 1) * (1 - away),
              child: EnvelopeView(
                key: ValueKey('envelope-$k'),
                color: ev.color,
                university: ev.university,
              ),
            ),
          ),
        );
      }
    }

    // --- the expanding school-coloured rectangle (glow) ---------------------
    if (glowing && glowGrow > 0 && fade < 1) {
      final gw = frontW * (1 + .45 * glowGrow);
      final gh = frontH + (h * .5 - frontH) * glowGrow;
      children.add(
        Positioned(
          left: cx - gw / 2,
          top: centerY - gh / 2,
          width: gw,
          height: gh,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: glowColor.withValues(
                  alpha: .30 * (1 - fade) * math.min(1, glowGrow * 1.5),
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: .35 * (1 - fade)),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // --- the result card ------------------------------------------------------
    if (cardStep || (opening && fade > 0)) {
      final v = _views[active];
      final appear = cardStep ? 1.0 : fade;
      children.add(
        Positioned(
          left: cx - cardW / 2,
          top: centerY - cardH / 2,
          width: cardW,
          height: cardH,
          child: Opacity(
            opacity: appear,
            child: Transform.scale(
              scale: .9 + .1 * appear,
              child: ResultCard(
                key: ValueKey('result-card-$active'),
                view: v,
                width: cardW,
                height: cardH,
              ),
            ),
          ),
        ),
      );
    }

    // --- confetti in the school's colours (both verdicts) ----------------------
    if (shown != null && ((opening && o > _confettiFrom) || cardStep || stashing)) {
      final idx = stashing ? _revealed - 1 : active;
      children.add(
        Positioned.fill(
          child: ConfettiField(
            key: ValueKey('confetti-$idx'),
            colors: [
              shown.color,
              Color.lerp(shown.color, Colors.white, .45)!,
              Color.lerp(shown.color, Colors.black, .2)!,
            ],
            count: 46,
          ),
        ),
      );
    }

    // --- idle UI: rate, Browse control ----------------------------------------
    if (_step == _Step.idle && view != null) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: h * .655,
          child: Text(
            '${view.rate}% Acceptance Rate',
            key: const ValueKey('acceptance-rate'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEDEDED), fontSize: 16),
          ),
        ),
      );
      children.add(
        Positioned(
          left: w * .12,
          right: w * .12,
          top: h * .75,
          height: h * .12,
          child: _BrowseButton(view: view, onTap: _browse),
        ),
      );
    }

    // --- Confirm (school-coloured) ----------------------------------------------
    if (cardStep) {
      final v = _views[active];
      children.add(
        Positioned(
          left: w * .27,
          right: w * .27,
          top: h * .70,
          child: _SchoolConfirm(
            key: const ValueKey('result-confirm'),
            color: v.color,
            onPressed: _confirm,
          ),
        ),
      );
    }

    // --- fast-forward (RECONSTRUCTED semantics) -----------------------------------
    if (_step == _Step.idle || _step == _Step.opening) {
      children.add(
        Positioned(
          right: w * .07,
          top: MediaQuery.paddingOf(context).top + h * .03,
          width: w * .14,
          height: w * .14 * .8,
          child: PressFeedback(
            travel: 2,
            child: GestureDetector(
              key: const ValueKey('results-fast-forward'),
              onTap: _fastForward,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2FA84F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB5F2C2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3CE06A).withValues(alpha: .55),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fast_forward_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(clipBehavior: Clip.hardEdge, children: children);
  }

  Widget _letter(ApplicationResultView v, double envelopeWidth) {
    final u = envelopeWidth / 267;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: EdgeInsets.fromLTRB(8 * u, 10 * u, 8 * u, 0),
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          Text(
            v.universityName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14 * u,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          Text(
            v.departmentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11 * u,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// The large school-coloured, glowing rectangle: school, department and the
/// "Browse Application Results" caption.
class _BrowseButton extends StatelessWidget {
  final ApplicationResultView view;
  final VoidCallback onTap;
  const _BrowseButton({required this.view, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = view.color;
    return PressFeedback(
      travel: 3,
      child: GestureDetector(
        key: const ValueKey('browse-results'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Color.lerp(color, Colors.black, .25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color.lerp(color, Colors.white, .5)!,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .7), blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  view.universityName,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
                Text(
                  view.departmentName,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Browse Application Results',
                  style: TextStyle(color: Color(0xFFE6E6E6), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A school-coloured Confirm with a white outline and white text.
class _SchoolConfirm extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;
  const _SchoolConfirm({
    super.key,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => D30RaisedButton(
    color: color,
    edgeColor: Colors.white,
    depth: 4,
    onPressed: onPressed,
    child: const Text(
      'Confirm',
      style: TextStyle(fontSize: 18, color: Colors.white),
    ),
  );
}

// ---------------------------------------------------------------------------
// 4-5. Combined results and Final Decision
// ---------------------------------------------------------------------------

class _CardsPage extends StatefulWidget {
  final Game game;
  final Future<void> Function(FinalOption option) onPick;
  const _CardsPage({super.key, required this.game, required this.onPick});

  @override
  State<_CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<_CardsPage> {
  Game get game => widget.game;
  late final List<ApplicationResult> _results = game.applicationResults;
  late final List<ApplicationResultView> _views = [
    for (final r in _results) ApplicationResultView.of(r),
  ];
  late bool _reviewed = game.state.resultsReviewed;

  /// The Final Decision button was pressed: rejected cards fade away and the
  /// accepted ones centre (only when something accepted the student).
  bool _choosing = false;

  List<int> get _accepted => [
    for (var i = 0; i < _results.length; i++)
      if (_results[i].accepted) i,
  ];

  void _confirmAll() {
    if (_reviewed) return;
    game.confirmResults();
    setState(() => _reviewed = true);
  }

  Duration get _choiceSwap => reducedMotion(context)
      ? Duration.zero
      : const Duration(milliseconds: 320);

  Duration get _move => reducedMotion(context)
      ? Duration.zero
      : const Duration(milliseconds: 480);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final accepted = _accepted;
      final anyAccepted = accepted.isNotEmpty;
      final n = _views.length;

      // Three layouts of the same cards.
      Rect rect(int i) {
        if (_choosing && _results[i].accepted) {
          final m = accepted.length;
          final ch = h * .2;
          final pitch = math.min(h * .26, (h * .66 - ch) / math.max(1, m - 1));
          final total = ch + (m - 1) * pitch;
          final top = h * .54 - total / 2 + accepted.indexOf(i) * pitch;
          return Rect.fromLTWH(w * .15, top, w * .70, ch);
        }
        if (_reviewed) {
          // Compact stack under the Final Decision title.
          final ch = h * .17;
          final pitch = math.min(h * .205, (h * .66 - ch) / math.max(1, n - 1));
          return Rect.fromLTWH(w * .15, h * .17 + i * pitch, w * .70, ch);
        }
        final ch = h * .204;
        final pitch = math.min(h * .266, (h * .76 - ch) / math.max(1, n - 1));
        return Rect.fromLTWH(w * .15, h * .07 + i * pitch, w * .70, ch);
      }

      final showTitle = _reviewed;
      final titleTop = anyAccepted ? h * .075 : h * .15;
      final hideStack = _reviewed && !anyAccepted;

      return Stack(
        children: [
          // Title
          Positioned(
            left: 0,
            right: 0,
            top: titleTop,
            child: AnimatedOpacity(
              opacity: showTitle ? 1 : 0,
              duration: reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              child: const Text(
                'Final Decision',
                key: ValueKey('final-decision-title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          // The stacked result cards
          for (var i = 0; i < n; i++)
            AnimatedPositioned(
              key: ValueKey('card-slot-$i'),
              duration: _move,
              curve: Curves.easeInOutCubic,
              left: rect(i).left,
              top: rect(i).top,
              width: rect(i).width,
              height: rect(i).height,
              child: AnimatedOpacity(
                duration: reducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                opacity: hideStack || (_choosing && !_results[i].accepted)
                    ? 0
                    : 1,
                child: IgnorePointer(
                  ignoring: !(_choosing && _results[i].accepted),
                  child: GestureDetector(
                    key: ValueKey('final-card-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onPick(
                      FinalOption(
                        department: _results[i].department,
                        university: _results[i].university,
                        isRetake: false,
                      ),
                    ),
                    child: LayoutBuilder(
                      // After Final Decision the accepted cards turn into
                      // enrollment-choice cards (crest, school, department;
                      // DDAY-C07); results keep the verdict cards.
                      builder: (_, c) => AnimatedSwitcher(
                        duration: _choiceSwap,
                        child: _choosing && _results[i].accepted
                            ? ChoiceCard(
                                key: ValueKey('choice-card-$i'),
                                view: _views[i],
                                width: c.maxWidth,
                                height: c.maxHeight,
                              )
                            : ResultCard(
                                key: ValueKey('combined-card-$i'),
                                view: _views[i],
                                width: c.maxWidth,
                                height: c.maxHeight,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // The academy (nothing accepted the student)
          if (_reviewed && !anyAccepted)
            Positioned(
              left: w * .19,
              right: w * .19,
              top: h * .51,
              height: h * .2,
              child: _FadeIn(
                child: GestureDetector(
                  key: const ValueKey('final-retake-card'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onPick(game.retakeOption),
                  child: _RetakeCard(option: game.retakeOption),
                ),
              ),
            ),
          // Buttons
          Positioned(
            left: w * .12,
            right: w * .12,
            bottom: MediaQuery.paddingOf(context).bottom + h * .04,
            child: !_reviewed
                ? D30RaisedButton(
                    key: const ValueKey('results-confirm-all'),
                    onPressed: _confirmAll,
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontSize: 21),
                    ),
                  )
                : (anyAccepted && !_choosing)
                ? D30RaisedButton(
                    key: const ValueKey('final-decision-button'),
                    onPressed: () => setState(() => _choosing = true),
                    child: const Text(
                      'Final Decision',
                      style: TextStyle(fontSize: 21),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Hint once the accepted cards are centred.
          if (_choosing)
            Positioned(
              left: 0,
              right: 0,
              bottom: h * .06,
              child: const _FadeIn(
                child: Text(
                  'Tap the university you will attend.',
                  key: ValueKey('final-hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 15),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Fades its child in once, on build.
class _FadeIn extends StatelessWidget {
  final Widget child;
  const _FadeIn({required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: reducedMotion(context) ? 1 : 0, end: 1),
    duration: reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 600),
    builder: (_, v, child) => Opacity(opacity: v, child: child),
    child: child,
  );
}

/// The white peach-bordered Korea Retry Academy card.
class _RetakeCard extends StatelessWidget {
  final FinalOption option;
  const _RetakeCard({required this.option});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFFC7A5), width: 5),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 62, height: 46, child: AcademyLogo()),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            option.university?.name ?? 'Korea Retry Academy',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            option.department.name,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Confirm Enrollment
// ---------------------------------------------------------------------------

/// The cream/orange "Confirm Enrollment" modal. Confirm swaps the dialog for
/// a small cream loading square (about 0.8 s, duplicate taps ignored), then
/// pops `true`; X pops `false`. The engine is called by the host AFTER this.
class _ConfirmEnrollmentDialog extends StatefulWidget {
  final Game game;
  final FinalOption option;
  const _ConfirmEnrollmentDialog({required this.game, required this.option});

  @override
  State<_ConfirmEnrollmentDialog> createState() =>
      _ConfirmEnrollmentDialogState();
}

class _ConfirmEnrollmentDialogState extends State<_ConfirmEnrollmentDialog> {
  bool _loading = false;
  Timer? _timer;

  void _confirm() {
    if (_loading) return;
    setState(() => _loading = true);
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final o = widget.option;
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: _loading
              ? Container(
                  key: const ValueKey('enrollment-loading'),
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: D30Colors.page,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: D30Colors.accent, width: 3),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: D30Colors.accent,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        key: const ValueKey('confirm-enrollment'),
                        width: math.min(w * .8, 340),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        decoration: BoxDecoration(
                          color: D30Colors.page,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: D30Colors.accent, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Confirm Enrollment',
                              style: TextStyle(
                                fontSize: 21,
                                color: D30Colors.accent,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SchoolCrest(university: o.university, size: 104),
                            const SizedBox(height: 8),
                            Text(
                              o.university?.name ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                color: D30Colors.accentDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              o.department.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                color: D30Colors.accentDark,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 140,
                              child: D30RaisedButton(
                                key: const ValueKey('enrollment-confirm'),
                                onPressed: _confirm,
                                child: const Text(
                                  'Confirm',
                                  style: TextStyle(fontSize: 19),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: PressFeedback(
                          travel: 2,
                          child: GestureDetector(
                            key: const ValueKey('enrollment-close'),
                            onTap: () => Navigator.of(context).pop(false),
                            child: Container(
                              width: 40,
                              height: 40,
                              color: D30Colors.accent,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
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
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Enrollment / share scene
// ---------------------------------------------------------------------------

class _ShareScene extends StatefulWidget {
  final Game game;
  final VoidCallback onConfirm;
  const _ShareScene({super.key, required this.game, required this.onConfirm});

  @override
  State<_ShareScene> createState() => _ShareSceneState();
}

class _ShareSceneState extends State<_ShareScene> {
  final _cardKey = GlobalKey();
  bool _picking = false;
  bool _saving = false;

  Game get game => widget.game;

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _upload() async {
    if (_picking) return;
    _picking = true;
    try {
      final path = await StudentPhotos.pick();
      if (path == null || !mounted) return;
      setState(() => game.state.studentPhotoPath = path);
    } finally {
      _picking = false;
    }
  }

  Future<void> _download() async {
    if (_saving) return;
    _saving = true;
    try {
      final ok = await saveWidgetImage(_cardKey, 'student_id');
      _notice(ok ? 'Saved to your gallery.' : 'Could not save the image.');
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = game.state;
    final department = state.enrolledDepartment == null
        ? null
        : state.pack.admissions.departments[state.enrolledDepartment];
    final university =
        state.pack.admissions.universities[department?.universityId ?? 0];
    final tint = Color.lerp(D30Colors.accent, schoolColor(university), .35)!;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.25),
                    radius: 1.15,
                    colors: [
                      Color.lerp(tint, Colors.white, .42)!,
                      tint,
                      Color.lerp(tint, const Color(0xFF7A2E10), .18)!,
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: ConfettiField(
                key: ValueKey('scene-confetti'),
                colors: ConfettiField.party,
                loop: true,
                count: 60,
                duration: Duration(seconds: 6),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: h - MediaQuery.paddingOf(context).vertical,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: w * .75,
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: StudentIdCard.forRun(state),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: w * .75,
                          child: D30RaisedButton(
                            key: const ValueKey('upload-photo'),
                            depth: 4,
                            onPressed: _upload,
                            child: const Text(
                              'Upload your photo to your student ID!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        SizedBox(height: h * .04),
                        _SharePanel(
                          width: w * .64,
                          onInstagram: () =>
                              _notice('Not available in this build.'),
                          onX: () => _notice('Not available in this build.'),
                          onDownload: _download,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: w * .75,
                          child: D30RaisedButton(
                            key: const ValueKey('scene-confirm'),
                            onPressed: widget.onConfirm,
                            child: const Text(
                              'Confirm',
                              style: TextStyle(fontSize: 22),
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
        );
      },
    );
  }
}

class _SharePanel extends StatelessWidget {
  final double width;
  final VoidCallback onInstagram;
  final VoidCallback onX;
  final VoidCallback onDownload;
  const _SharePanel({
    required this.width,
    required this.onInstagram,
    required this.onX,
    required this.onDownload,
  });

  Widget _icon(
    Key key,
    Widget child,
    Color color,
    VoidCallback onTap, {
    Gradient? gradient,
  }) => PressFeedback(
    travel: 2,
    child: GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gradient == null ? color : null,
          gradient: gradient,
        ),
        child: Center(child: child),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Korean Student Simulator',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _icon(
              const ValueKey('share-instagram'),
              const Icon(Icons.camera_alt_outlined, color: Colors.white),
              Colors.pink,
              onInstagram,
              gradient: const LinearGradient(
                colors: [Color(0xFFF5337E), Color(0xFFD1167A)],
              ),
            ),
            const SizedBox(width: 12),
            _icon(
              const ValueKey('share-x'),
              const Text(
                'X',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Colors.black,
              onX,
            ),
            const SizedBox(width: 12),
            _icon(
              const ValueKey('share-download'),
              const Icon(Icons.download, color: Colors.white, size: 28),
              D30Colors.accent,
              onDownload,
            ),
          ],
        ),
      ],
    ),
  );
}
