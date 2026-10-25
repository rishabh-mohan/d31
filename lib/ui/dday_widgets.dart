/// Shared pieces of the application-results flow and the completion summary:
/// school colours and crests, the envelope, the result card, confetti and the
/// Student ID card. Screens live in `dday_results.dart` and `end_screen.dart`.
/// See docs/DDAY-UI.md ("Results and enrollment").
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import '../engine/game.dart';
import '../engine/state.dart';
import 'pack_image.dart';
import 'portrait.dart';
import 'theme.dart';

/// True when the platform asks for reduced motion: every animation here
/// jumps to its end state instead.
bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// A school's colour (`colorCode` in the catalog), the orange chrome when it
/// has none.
Color schoolColor(University? university) {
  final hex = (university?.colorCode ?? '').replaceAll('#', '');
  final value = int.tryParse(hex, radix: 16);
  if (hex.length != 6 || value == null) return D30Colors.accent;
  return Color(0xFF000000 | value);
}

/// Dark text on light colours, white text on dark ones.
Color onColor(Color color) =>
    color.computeLuminance() > .55 ? D30Colors.ink : Colors.white;

/// The Korea Retry Academy's mark: an outlined and a filled pill, orange.
class AcademyLogo extends StatelessWidget {
  final Color color;
  const AcademyLogo({super.key, this.color = D30Colors.accent});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _AcademyLogoPainter(color),
    child: const SizedBox.expand(),
  );
}

class _AcademyLogoPainter extends CustomPainter {
  final Color color;
  const _AcademyLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Fit a 1.15 : 1 logo into the box, centred.
    final h = math.min(size.height, size.width / 1.15);
    final w = h * 1.15;
    final dx = (size.width - w) / 2;
    final dy = (size.height - h) / 2;
    final pillW = w * .38;
    final stroke = pillW * .2;
    final left = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        dx + stroke / 2,
        dy + stroke / 2,
        pillW - stroke,
        h - stroke,
      ),
      Radius.circular(pillW / 2),
    );
    canvas.drawRRect(
      left,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final right = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx + w - pillW * 1.08, dy, pillW * 1.08, h),
      Radius.circular(pillW * .54),
    );
    canvas.drawRRect(right, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AcademyLogoPainter old) => old.color != color;
}

/// A university's crest. The Retry Academy's art is a vector in the original
/// (`university/0.svg`), drawn here; every other school is its catalog PNG.
class SchoolCrest extends StatelessWidget {
  final University? university;
  final double? size;
  const SchoolCrest({super.key, required this.university, this.size});

  @override
  Widget build(BuildContext context) {
    final u = university;
    final Widget art = u == null
        ? const SizedBox.shrink()
        : (u.id == 0 || u.crestPath.endsWith('.svg'))
        ? const AcademyLogo()
        : PackImage(path: u.crestPath, fit: BoxFit.contain);
    return size == null ? art : SizedBox(width: size, height: size, child: art);
  }
}

// ---------------------------------------------------------------------------
// Result card
// ---------------------------------------------------------------------------

/// The white rounded verdict card: thick pale school-colour border, crest and
/// university, department, divider, big verdict.
///
/// RECOVERED for Rejected (red); the Accepted wording and green are
/// RECONSTRUCTED (the recording rejects all three).
class ResultCard extends StatelessWidget {
  final ApplicationResultView view;
  final double width;
  final double height;
  const ResultCard({
    super.key,
    required this.view,
    required this.width,
    required this.height,
  });

  static const rejectedRed = Color(0xFFF2403A);
  static const acceptedGreen = Color(0xFF1E9E50);

  @override
  Widget build(BuildContext context) {
    final u = height / 178; // the 393x873 design height
    final color = view.color;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 8 * u),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22 * u),
        border: Border.all(
          color: Color.lerp(color, Colors.white, .55)!,
          width: 6 * u,
        ),
      ),
      // Long school and department names wrap to two lines inside the card's
      // width and, as a last resort, the whole identity block scales down
      // (DDAY-C05) instead of ending in an ellipsis.
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SchoolCrest(university: view.university, size: 24 * u),
                      SizedBox(width: 6 * u),
                      Flexible(
                        child: Text(
                          view.universityName,
                          key: const ValueKey('result-card-school'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16 * u,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3 * u),
                  Text(
                    view.departmentName,
                    key: const ValueKey('result-card-department'),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5 * u,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6 * u),
                    child: const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    view.accepted ? 'Accepted' : 'Rejected',
                    style: TextStyle(
                      fontSize: 31 * u,
                      fontWeight: FontWeight.w900,
                      color: view.accepted ? acceptedGreen : rejectedRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The enrollment-choice card of Final Decision (DDAY-C07): a large centred
/// crest, the school and the department, with no verdict text. The older
/// successful reference shows exactly this after the Final Decision button.
class ChoiceCard extends StatelessWidget {
  final ApplicationResultView view;
  final double width;
  final double height;
  const ChoiceCard({
    super.key,
    required this.view,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final u = height / 178;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 8 * u),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22 * u),
        border: Border.all(
          color: Color.lerp(view.color, Colors.white, .55)!,
          width: 4 * u,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SchoolCrest(university: view.university, size: 62 * u),
                  SizedBox(height: 6 * u),
                  Text(
                    view.universityName,
                    key: const ValueKey('choice-card-school'),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17 * u,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2 * u),
                  Text(
                    view.departmentName,
                    key: const ValueKey('choice-card-department'),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12 * u,
                      height: 1.15,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a result card / envelope needs, so widgets never touch the engine.
class ApplicationResultView {
  final University? university;
  final Department department;
  final int rate;
  final bool accepted;
  final Color color;

  ApplicationResultView({
    required this.university,
    required this.department,
    required this.rate,
    required this.accepted,
  }) : color = schoolColor(university);

  factory ApplicationResultView.of(ApplicationResult r) =>
      ApplicationResultView(
        university: r.university,
        department: r.department,
        rate: r.rate,
        accepted: r.accepted,
      );

  /// A Final Decision option shown as an accepted card.
  factory ApplicationResultView.option(FinalOption o) => ApplicationResultView(
    university: o.university,
    department: o.department,
    rate: 0,
    accepted: !o.isRetake,
  );

  String get universityName => university?.name ?? '';
  String get departmentName => department.name;
}

// ---------------------------------------------------------------------------
// Envelope
// ---------------------------------------------------------------------------

/// A pastel envelope with folded flaps and a crest seal.
///
/// [flap] runs 0 (closed) to 1 (open). [letter], when given, slides up out of
/// the pocket by [letterRise] (0..1). The painting is split in three layers
/// (interior and open flap, letter, front pocket and closed flap) so the
/// letter really emerges from inside.
class EnvelopeView extends StatelessWidget {
  final Color color;
  final University? university;
  final double flap;
  final double letterRise;
  final Widget? letter;
  final double glow;

  const EnvelopeView({
    super.key,
    required this.color,
    required this.university,
    this.flap = 0,
    this.letterRise = 0,
    this.letter,
    this.glow = 1,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final seal = w * .19;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _EnvelopePainter(color, flap, glow, 0)),
          ),
          if (letter != null)
            Positioned(
              left: w * .07,
              width: w * .86,
              top: h * .12 - letterRise * h * .62,
              height: h * .82,
              child: letter!,
            ),
          Positioned.fill(
            child: CustomPaint(painter: _EnvelopePainter(color, flap, glow, 1)),
          ),
          Positioned(
            left: (w - seal) / 2,
            top: h * .5 - seal / 2 - (flap > .5 ? 0 : 0),
            width: seal,
            height: seal,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(Colors.white, color, .16),
              ),
              child: Padding(
                padding: EdgeInsets.all(seal * .17),
                child: SchoolCrest(university: university),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _EnvelopePainter extends CustomPainter {
  final Color color;
  final double flap;
  final double glow;

  /// 0 paints the interior and the open flap, 1 the pocket and closed flap.
  final int layer;
  const _EnvelopePainter(this.color, this.flap, this.glow, this.layer);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Rect.fromLTWH(0, 0, w, h);
    final side = Color.lerp(Colors.white, color, .10)!;
    final top = Color.lerp(Colors.white, color, .20)!;
    final bottom = Color.lerp(Colors.white, color, .58)!;
    final interior = Color.lerp(Colors.white, color, .32)!;
    // flap apex: closed it points down to the centre; open it points up.
    final apexY = h * .5 * math.cos(math.pi * flap);
    final flapPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w / 2, apexY)
      ..close();

    if (layer == 0) {
      if (glow > 0) {
        canvas.drawRect(
          body.inflate(2),
          Paint()
            ..color = color.withValues(alpha: .85 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
      canvas.drawRect(body, Paint()..color = interior);
      if (flap > .5) {
        canvas.drawPath(
          flapPath,
          Paint()..color = Color.lerp(interior, color, .45)!,
        );
      }
      return;
    }
    // Pocket: two side triangles and the bottom triangle.
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, h * .5)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(w, 0)
      ..lineTo(w / 2, h * .5)
      ..lineTo(w, h)
      ..close();
    final bottomTri = Path()
      ..moveTo(0, h)
      ..lineTo(w / 2, h * .5)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(left, Paint()..color = side);
    canvas.drawPath(right, Paint()..color = side);
    canvas.drawPath(bottomTri, Paint()..color = bottom);
    if (flap <= .5) {
      canvas.drawPath(flapPath, Paint()..color = top);
      canvas.drawPath(
        flapPath,
        Paint()
          ..color = Color.lerp(top, color, .25)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_EnvelopePainter old) =>
      old.color != color ||
      old.flap != flap ||
      old.glow != glow ||
      old.layer != layer;
}

// ---------------------------------------------------------------------------
// Confetti
// ---------------------------------------------------------------------------

/// Falling confetti. One-shot (about three seconds) or looping, in the
/// given colours. Presentation only: it never touches game state. Nothing is
/// drawn when the platform asks for reduced motion.
class ConfettiField extends StatefulWidget {
  final List<Color> colors;
  final bool loop;
  final int count;
  final Duration duration;
  const ConfettiField({
    super.key,
    required this.colors,
    this.loop = false,
    this.count = 70,
    this.duration = const Duration(seconds: 3),
  });

  /// The multicolour palette of the enrolment scene.
  static const party = [
    Color(0xFFFF4D6D),
    Color(0xFFFFC233),
    Color(0xFF3BB4F2),
    Color(0xFF7B4DFF),
    Color(0xFF3BD16F),
    Color(0xFFFFFFFF),
    Color(0xFFFF8B55),
  ];

  @override
  State<ConfettiField> createState() => _ConfettiFieldState();
}

class _Piece {
  final double x, phase, speed, drift, spin, w, h;
  final Color color;
  const _Piece(
    this.x,
    this.phase,
    this.speed,
    this.drift,
    this.spin,
    this.w,
    this.h,
    this.color,
  );
}

class _ConfettiFieldState extends State<ConfettiField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.colors.length * 31 + widget.count);
    _pieces = [
      for (var i = 0; i < widget.count; i++)
        _Piece(
          rng.nextDouble(),
          rng.nextDouble(),
          .7 + rng.nextDouble() * .7,
          (rng.nextDouble() - .5) * .12,
          2 + rng.nextDouble() * 6,
          4 + rng.nextDouble() * 6,
          9 + rng.nextDouble() * 12,
          widget.colors[rng.nextInt(widget.colors.length)],
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating && _clock.value == 0) {
      widget.loop ? _clock.repeat() : _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _clock.value, widget.loop),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  final bool loop;
  _ConfettiPainter(this.pieces, this.t, this.loop);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final double fall;
      if (loop) {
        fall = (t * p.speed + p.phase) % 1;
      } else {
        fall = ((t - p.phase * .3) / .7 * p.speed).clamp(0.0, 1.3);
        if (fall <= 0 || fall >= 1.15) continue;
      }
      final y = -20 + fall * (size.height + 40);
      final x =
          p.x * size.width + math.sin(fall * 6 + p.spin) * 14 * p.drift * 8;
      final angle = fall * p.spin * math.pi * 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      // Flutter: squash one axis so the piece seems to turn over.
      canvas.scale(1, .35 + .65 * math.cos(angle * 1.7).abs());
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
        paint..color = p.color.withValues(alpha: .95),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Student ID card
// ---------------------------------------------------------------------------

/// The landscape Student ID: cream fill, thick outline and header in the
/// school colour, spaced "[Student ID Card]", the student's details on the
/// left, the run's portrait (or the player's own photo) on the right, a
/// faint crest watermark and the school's name with a red seal at the bottom.
///
/// RECOVERED layout (HANDOFF section 12). The Student ID number is blank in
/// the recording and unsourced, so it is left blank.
class StudentIdCard extends StatelessWidget {
  final String school;
  final String course;
  final String name;
  final Color color;
  final University? university;
  final Widget portrait;
  final String studentId;

  const StudentIdCard({
    super.key,
    required this.school,
    required this.course,
    required this.name,
    required this.color,
    required this.university,
    required this.portrait,
    this.studentId = '',
  });

  /// The card for the run's enrolment (or the retake academy), from the
  /// stored run. Uses the player's photo when [GameState.studentPhotoPath]
  /// names a readable file.
  factory StudentIdCard.forRun(GameState state, {Key? key}) {
    final department = state.enrolledDepartment == null
        ? state.pack.admissions.departments[0]
        : state.pack.admissions.departments[state.enrolledDepartment];
    final university = department == null
        ? state.pack.admissions.universities[0]
        : state.pack.admissions.universities[department.universityId];
    final photo = state.studentPhotoPath;
    final Widget portrait = (photo != null && File(photo).existsSync())
        ? Image.file(File(photo), fit: BoxFit.cover)
        : Portrait(
            pack: state.pack,
            id: state.characterId,
            character: true,
            fallback: state.portrait,
          );
    return StudentIdCard(
      key: key,
      school: university?.name ?? 'Korea Retry Academy',
      course: department?.name ?? 'Comprehensive Retake Course',
      name: state.fullName,
      color: schoolColor(university),
      university: university,
      portrait: portrait,
    );
  }

  static const cream = Color(0xFFFFF3E3);

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.62,
    child: LayoutBuilder(
      builder: (context, box) {
        final u = box.maxWidth / 330;
        final fg = onColor(color);
        return Container(
          key: const ValueKey('student-id-card'),
          decoration: BoxDecoration(
            color: cream,
            borderRadius: BorderRadius.circular(5 * u),
            border: Border.all(color: color, width: 3 * u),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // The faint crest watermark runs past the card, so only the card's
              // rounded border and the title band (drawn after it) clip it.
              Positioned(
                left: 20 * u,
                top: 8 * u,
                width: 190 * u,
                height: 205 * u,
                child: Opacity(
                  opacity: .10,
                  child: SchoolCrest(university: university),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                    padding: EdgeInsets.symmetric(vertical: 3 * u),
                    color: color,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 1.5 * u),
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: cream.withValues(alpha: .8),
                            width: .8 * u,
                          ),
                        ),
                      ),
                      child: Text(
                        school,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5 * u,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 3 * u),
                  Text(
                    '[ S t u d e n t   I D   C a r d ]',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10 * u,
                      fontWeight: FontWeight.w800,
                      color: D30Colors.ink,
                    ),
                  ),
                  SizedBox(height: 6 * u),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12 * u, 0, 12 * u, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, left) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: left.maxWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Student ID: $studentId',
                                        style: TextStyle(
                                          fontSize: 9.5 * u,
                                          color: D30Colors.ink,
                                        ),
                                      ),
                                      SizedBox(height: 3 * u),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(text: 'Name: '),
                                            TextSpan(
                                              text: name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: TextStyle(
                                          fontSize: 10.5 * u,
                                          color: D30Colors.ink,
                                        ),
                                      ),
                                      SizedBox(height: 3 * u),
                                      Text(
                                        course,
                                        style: TextStyle(
                                          fontSize: 10 * u,
                                          fontWeight: FontWeight.w800,
                                          color: D30Colors.ink,
                                        ),
                                      ),
                                      SizedBox(height: 3 * u),
                                      Text(
                                        'The bearer of this certificate is hereby '
                                        'verified as a student of this institution.',
                                        style: TextStyle(
                                          fontSize: 7.5 * u,
                                          height: 1.15,
                                          color: D30Colors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8 * u),
                          SizedBox(
                            width: 78 * u,
                            child: ClipRect(child: portrait),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(10 * u, 2 * u, 10 * u, 5 * u),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SchoolCrest(university: university, size: 14 * u),
                        SizedBox(width: 4 * u),
                        Flexible(
                          child: Text(
                            school,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5 * u,
                              fontWeight: FontWeight.w700,
                              color: D30Colors.ink,
                            ),
                          ),
                        ),
                        SizedBox(width: 4 * u),
                        Container(
                          width: 14 * u,
                          height: 14 * u,
                          decoration: BoxDecoration(
                            color: ResultCard.rejectedRed.withValues(
                              alpha: .85,
                            ),
                            borderRadius: BorderRadius.circular(2 * u),
                          ),
                          child: Center(
                            child: Container(
                              width: 7 * u,
                              height: 7 * u,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white70,
                                  width: .8 * u,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
