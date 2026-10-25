/// The palette and the small shared shapes the screen is built from.
///
/// Values are read off the reference screenshot. They live here rather than
/// inline so the look can be retuned in one place when the real guidelines
/// land.
library;

import 'press_feedback.dart';

import 'package:flutter/material.dart';

class D30Colors {
  // Page and panels
  static const page = Color(0xFFFFF3E2);
  static const panel = Color(0xFFFFF8EC);
  static const panelBorder = Color(0xFFF3C58E);

  // The orange chrome: top bar, location banner
  static const accent = Color(0xFFFF8B55);
  static const accentDark = Color(0xFFE2761F);
  static const onAccent = Colors.white;

  // Strips
  static const missionBorder = Color(0xFFF08A9B);
  static const missionFill = Color(0xFFFFF6F2);
  static const alert = Color(0xFFE8463C);

  // Meters
  static const hpGreen = Color(0xFF4CC14E);
  static const hpTrack = Color(0xFFE6E6E6);
  static const satietyGreen = Color(0xFF63C860);
  static const satietyEmpty = Color(0xFFD8D8D8);
  static const coin = Color(0xFFF5C33B);

  // The blue level box
  static const levelBox = Color(0xFF405366);
  static const levelBoxDark = Color(0xFF3F67A4);

  // The exercise card
  static const exercise = Color(0xFFC90068);

  // Subject chips, keyed by the pack's subject names. A subject with no
  // entry falls back to a neutral chip rather than vanishing.
  static const subjects = <String, Color>{
    'korean': Color(0xFFF5ACBD),
    'english': Color(0xFFFAE899),
    'math': Color(0xFFAFBFDF),
    'science': Color(0xFF98D4AA),
    'society': Color(0xFFD7BCE4),
  };
  static const subjectFallback = Color(0xFFE8E8E8);

  static Color subject(String name) => subjects[name] ?? subjectFallback;

  static const ink = Color(0xFF4A3B2E);
  static const inkSoft = Color(0xFF8A7765);
}

/// Raised controls share a dark lower face and a soft warm shadow.
class D30RaisedButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color? edgeColor;

  /// Height of the lower face, and how far a press sinks into it.
  final double depth;

  /// No lower face and no press motion (item buttons, TODO 77).
  final bool flat;

  const D30RaisedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = D30Colors.accent,
    this.edgeColor,
    this.depth = 6,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: flat ? 0 : depth),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: flat
            ? const []
            : [
                BoxShadow(
                  color: edgeColor ?? Color.lerp(color, Colors.black, .22)!,
                  offset: Offset(0, depth),
                ),
                BoxShadow(
                  color: const Color(0x264A2B10),
                  blurRadius: 8,
                  offset: Offset(0, depth + 2),
                ),
              ],
      ),
      child: PressFeedback(
        travel: flat ? 0 : depth,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            // The lower face is drawn under this box, so the button must be
            // exactly its painted face. Material's 48px tap-target padding
            // made the face smaller than the box: the lower face read 10px
            // instead of 6, and a held button uncovered it above the face,
            // which looked like a thicker top border (TODO 63).
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: edgeColor ?? Color.lerp(color, Colors.black, .22)!,
                width: 2,
              ),
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Display names for subjects, as the reference UI writes them.
String subjectLabel(String subject) {
  switch (subject) {
    case 'korean':
      return 'Korean';
    case 'english':
      return 'English';
    case 'math':
      return 'Maths';
    case 'science':
      return 'Science';
    case 'society':
      return 'Humnts.';
    default:
      return subject.isEmpty
          ? subject
          : subject[0].toUpperCase() + subject.substring(1);
  }
}

/// Badge shown on a location card, by the location'"'"'s `type`.
String? locationTypeLabel(String type) {
  switch (type) {
    case 'sleep':
      return 'Sleep';
    case 'exercise':
      return 'Workout';
    case 'study':
      return 'Study';
    case 'partTimeJob':
      return 'Part-Time';
    default:
      return null;
  }
}

Color locationTypeColor(String type) {
  switch (type) {
    case 'sleep':
      return const Color(0xFF1F3368);
    case 'exercise':
      return D30Colors.exercise;
    case 'study':
      return D30Colors.accent;
    case 'partTimeJob':
      return const Color(0xFFA8AF35);
    default:
      return D30Colors.inkSoft;
  }
}

/// The cream panel with a warm border that most of the screen sits inside.
class D30Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? border;
  final double radius;

  const D30Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.color,
    this.border,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? D30Colors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? D30Colors.panelBorder, width: 1.5),
      ),
      child: child,
    );
  }
}

/// A small rounded label — the subject tags, the rank tag, the reward tag.
class D30Chip extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final FontWeight weight;

  const D30Chip({
    super.key,
    required this.text,
    required this.color,
    this.textColor,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.weight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: textColor ?? D30Colors.ink,
        ),
      ),
    );
  }
}

/// The red "!" badge that sits on the corner of urgent cards and strips.
class D30AlertDot extends StatelessWidget {
  const D30AlertDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: D30Colors.alert,
        shape: BoxShape.circle,
      ),
      child: const Text(
        '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Shared polarity colors for setup, preparation and My Info.
Color traitColor(String? type) => switch (type) {
  'good' => const Color(0xFF66BB6A),
  'bad' => const Color(0xFFE57373),
  _ => const Color(0xFFBA68C8),
};
