/// Shared panel motion.
///
/// The menus that sit *over* the game — Books, Score Card, Schedule, the Store
/// and the stationery screens — fly up from the bottom edge rather than fading
/// in place. Keeping the curve and the distance in one file means the whole
/// app moves the same way, and retuning it is one edit.
///
/// Separate from the event panel, which keeps its own scale-and-fade: an event
/// interrupts you where you are, while a menu is somewhere you went.
library;

import 'package:flutter/material.dart';

/// How far below its resting place a panel starts, as a fraction of its own
/// height. Small on purpose — a full-height slide reads as a page push.
const _rise = Offset(0, 0.14);

const _enter = Duration(milliseconds: 300);
const _exit = Duration(milliseconds: 210);

/// Wraps [child] in the shared rise-and-fade.
Widget flyUpTransition(Animation<double> animation, Widget child) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(begin: _rise, end: Offset.zero).animate(curved),
      child: child,
    ),
  );
}

/// A dialog that flies up from the bottom.
///
/// `showDialog` hardcodes its own fade-and-scale, so this goes through
/// `showGeneralDialog` to supply the transition.
Future<T?> showFlyUpDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierDismissible
        ? MaterialLocalizations.of(context).modalBarrierDismissLabel
        : null,
    barrierColor: barrierColor,
    // showGeneralDialog has no reverse duration; the dismiss curve below is
    // what shortens the exit.
    transitionDuration: _enter,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (_, animation, _, child) =>
        flyUpTransition(animation, child),
  );
}

/// A full-screen route that flies up from the bottom, over the game.
Route<T> flyUpRoute<T>(WidgetBuilder builder, {Color? barrierColor}) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: _enter,
    reverseTransitionDuration: _exit,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (_, animation, _, child) =>
        flyUpTransition(animation, child),
  );
}

/// How long [showFadeDialog] takes to fade in.
const fadeDuration = Duration(milliseconds: 250);

/// A dialog that fades in where it stands, without the rise.
///
/// For panels that report on you rather than take you somewhere — My Info.
/// `showDialog`'s own fade is a barely visible 150ms with a scale; this one is
/// a plain opacity ramp, and it is instant when the platform asks for reduced
/// motion.
Future<T?> showFadeDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = Colors.black54,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : fadeDuration,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}
