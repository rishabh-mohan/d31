/// Short burnt-orange toasts, centered over the content, auto-dismissing and
/// queued (HANDOFF section 8: "queued older messages appear after later
/// taps"). They never take touches, so they can sit over modals and lists.
library;

import 'dart:collection';

import 'package:flutter/material.dart';

class D30Toast {
  D30Toast._();

  static const burntOrange = Color(0xFFC9511D);
  static const shown = Duration(milliseconds: 1800);
  static const fade = Duration(milliseconds: 180);

  static final Queue<String> _queue = Queue();
  static OverlayEntry? _entry;

  /// Queues [message]; it shows now if no toast is up, else after the ones
  /// ahead of it.
  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _queue.add(message);
    if (_entry == null) _next(overlay);
  }

  static void _next(OverlayState overlay) {
    if (_queue.isEmpty) return;
    final message = _queue.removeFirst();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        onDone: () {
          entry.remove();
          entry.dispose();
          _entry = null;
          if (_queue.isNotEmpty && overlay.mounted) _next(overlay);
        },
        onAbort: () {
          _entry = null;
          _queue.clear();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Test hook: forget anything queued or showing.
  @visibleForTesting
  static void reset() {
    _queue.clear();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  final VoidCallback onAbort;
  const _ToastView({
    required this.message,
    required this.onDone,
    required this.onAbort,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: D30Toast.shown + D30Toast.fade * 2,
    )..forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_finished) {
        _finished = true;
        // Removing the entry inside the animation callback is safe; defer a
        // frame so the overlay is not mutated while building.
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
      }
    });
  }

  @override
  void dispose() {
    if (!_finished) widget.onAbort();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = D30Toast.shown + D30Toast.fade * 2;
    final edge = D30Toast.fade.inMicroseconds / total.inMicroseconds;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.05),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            final opacity = reduced
                ? 1.0
                : (t < edge
                      ? t / edge
                      : t > 1 - edge
                      ? (1 - t) / edge
                      : 1.0);
            return Opacity(opacity: opacity.clamp(0, 1), child: child);
          },
          child: Container(
            key: const ValueKey('toast'),
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: D30Toast.burntOrange,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
