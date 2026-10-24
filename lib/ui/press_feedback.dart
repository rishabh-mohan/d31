import 'package:flutter/material.dart';

/// Shared motion for menu buttons, cards and icon controls. The child keeps
/// its own gestures, focus, semantics and click timing; this only moves paint.
class PressFeedback extends StatefulWidget {
  final Widget child;

  /// Match a raised face's travel to the stationary lower face underneath it.
  final double travel;
  const PressFeedback({super.key, required this.child, this.travel = 3});

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  int? _pointer;
  bool _down = false;

  bool get _enabled {
    var child = widget.child;
    while (child is Material) {
      if (child.child == null) return true;
      child = child.child!;
    }
    if (child is ButtonStyleButton) return child.onPressed != null;
    if (child is IconButton) return child.onPressed != null;
    if (child is InkWell) {
      return child.onTap != null || child.onLongPress != null;
    }
    return true;
  }

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  void _release() {
    _pointer = null;
    _setDown(false);
  }

  @override
  void didUpdateWidget(PressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pointer = null;
      _down = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (!_enabled || _pointer != null) return;
      _pointer = event.pointer;
      _setDown(true);
    },
    onPointerMove: (event) {
      if (event.pointer != _pointer) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null &&
          !(Offset.zero & box.size).contains(event.localPosition)) {
        _release();
      }
    },
    onPointerUp: (event) {
      if (event.pointer == _pointer) _release();
    },
    onPointerCancel: (event) {
      if (event.pointer == _pointer) _release();
    },
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: _down && _enabled ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 70),
      curve: Curves.easeOut,
      child: widget.child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, widget.travel * value),
        child: child,
      ),
    ),
  );
}
