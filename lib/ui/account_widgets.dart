/// Pieces shared by Home's account pages, measured off the main-menu
/// captures (docs/MAIN-MENU-REFERENCE.md):
///
///   * [AccountSheet]: Manage Traits, a near-full-height
///     sheet under an orange title strip with a dark X;
///   * [ChildPanel]: the cream, orange-outlined panels opened over them
///     (Endings List, My Traits, Combine Traits, puzzle detail);
///   * [TraitCard]: account trait cards, rank header over a white body;
///   * [GraySegments], [CookieAmount], [ConfettiLayer].
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/pack.dart';
import 'home_screen.dart';
import 'pack_image.dart';

const _cookieArt = 'kss/images/cookie.png';

/// Opens [child] over a dimmed parent, without replacing it.
Future<T?> pushOverlay<T>(BuildContext context, Widget child) =>
    Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

/// Achievements / Manage Traits: orange strip, white title, dark X, cream
/// body, from just under the status bar to the bottom.
class AccountSheet extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, double u) body;

  /// A small cream control at the strip's left (Chances Info).
  final Widget? leading;

  const AccountSheet({
    super.key,
    required this.title,
    required this.body,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, box) {
        final u = box.maxWidth / 390;
        return Padding(
          padding: EdgeInsets.only(top: top + 2 * u),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12 * u)),
            child: Material(
              color: HomeColors.paper,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 48 * u,
                    color: HomeColors.orange,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 21 * u,
                            color: Colors.white,
                          ),
                        ),
                        if (leading != null)
                          Positioned(left: 12 * u, child: leading!),
                        Positioned(
                          right: 4 * u,
                          child: IconButton(
                            key: const ValueKey('sheet-close'),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              size: 28 * u,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: body(context, u)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A cream child panel with a thick orange outline. Either an orange
/// corner X ([cornerClose]) or a footer the caller supplies closes it.
class ChildPanel extends StatelessWidget {
  final double u;
  final Widget child;
  final bool cornerClose;

  /// Fraction of the screen height the panel may take.
  final EdgeInsets margin;

  const ChildPanel({
    super.key,
    required this.u,
    required this.child,
    this.cornerClose = false,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14 * u);
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.paper,
          borderRadius: radius,
          border: Border.all(color: HomeColors.orange, width: 4 * u),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                child,
                if (cornerClose)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Material(
                      color: HomeColors.orange,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8 * u),
                      ),
                      child: InkWell(
                        key: const ValueKey('panel-close'),
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 36 * u,
                          height: 36 * u,
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30 * u,
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

/// A wide raised button: coral face over a darker lower edge, or red.
class FaceButton extends StatelessWidget {
  final double u;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double height;
  final double fontSize;
  final Widget? child;

  const FaceButton({
    super.key,
    required this.u,
    required this.label,
    required this.onTap,
    this.color = HomeColors.orange,
    this.height = 44,
    this.fontSize = 20,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final face = enabled ? color : const Color(0xFFA0A0A0);
    final radius = BorderRadius.circular(10 * u);
    return Container(
      height: height * u,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color.lerp(face, Colors.black, .18)!,
            offset: Offset(0, 4 * u),
          ),
        ],
      ),
      child: Material(
        color: face,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child:
                child ??
                Text(
                  label,
                  style: TextStyle(fontSize: fontSize * u, color: Colors.white),
                ),
          ),
        ),
      ),
    );
  }
}

/// Gray pill with the selected segment in orange (Standard / Endless
/// Winter / The Year I Retook).
class GraySegments<T> extends StatelessWidget {
  final double u;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const GraySegments({
    super.key,
    required this.u,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: EdgeInsets.all(3 * u),
        decoration: BoxDecoration(
          color: const Color(0xFF8E8E8E),
          borderRadius: BorderRadius.circular(9 * u),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in options.entries)
              GestureDetector(
                key: ValueKey('segment-${e.key}'),
                onTap: () => onChanged(e.key),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9 * u,
                    vertical: 4 * u,
                  ),
                  decoration: BoxDecoration(
                    color: e.key == selected
                        ? HomeColors.orange
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7 * u),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(fontSize: 13.5 * u, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CookieAmount extends StatelessWidget {
  final double u;
  final int amount;
  final double size;
  final Color color;

  const CookieAmount({
    super.key,
    required this.u,
    required this.amount,
    this.size = 16,
    this.color = HomeColors.ink,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: size * 1.25 * u,
        child: const PackImage(path: _cookieArt, fit: BoxFit.contain),
      ),
      SizedBox(width: 3 * u),
      Text(
        '$amount',
        style: TextStyle(fontSize: size * u, color: color),
      ),
    ],
  );
}

/// The green round check of completed rows.
class DoneCheck extends StatelessWidget {
  final double size;
  const DoneCheck({super.key, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFF4CB848),
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.check, color: Colors.white, size: size * .75),
  );
}

/// Account trait card colours: S black, A olive, B gray, C ochre (shared
/// card rules in MAIN-MENU-REFERENCE).
Color rankColor(String rank) => switch (rank) {
  'S' => const Color(0xFF0B0B0B),
  'A' => const Color(0xFFBFB862),
  'B' => const Color(0xFF9C9C9C),
  _ => const Color(0xFFA6742F),
};

/// Endless Winter and Retry Year cards keep their campaign skins.
String? cardSkin(GameTrait t) => switch (t.storyId) {
  18 => 'kss/images/trait_card_background/eternal_winter.png',
  20 => 'kss/images/trait_card_background/my_jaesoo_story.png',
  _ => null,
};

class TraitCard extends StatelessWidget {
  final GameTrait trait;
  final double u;

  /// Darkened: not owned (database) or combine-locked.
  final bool dimmed;

  /// none, small (bottom-right) or large (centred, protection mode).
  final LockMark lock;
  final bool selected;
  final VoidCallback? onTap;

  const TraitCard({
    super.key,
    required this.trait,
    required this.u,
    this.dimmed = false,
    this.lock = LockMark.none,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8 * u);
    final skin = cardSkin(trait);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: selected ? HomeColors.orange : const Color(0xFF3B2412),
            width: (selected ? 3 : 2) * u,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x33000000),
              blurRadius: 3 * u,
              offset: Offset(0, 2 * u),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6 * u),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Container(
                    height: 24 * u,
                    color: rankColor(trait.rank),
                    alignment: Alignment.center,
                    child: Text(
                      trait.rank,
                      style: TextStyle(
                        fontSize: 15 * u,
                        color: const Color(0xFFFFF6E6),
                      ),
                    ),
                  ),
                  Container(height: 1.5 * u, color: const Color(0xFF3B2412)),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (skin != null)
                          PackImage(path: skin)
                        else
                          const ColoredBox(color: Colors.white),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5 * u,
                            vertical: 4 * u,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  trait.name,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 13.5 * u,
                                    color: HomeColors.ink,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2 * u),
                              Flexible(
                                child: Text(
                                  trait.description,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8.5 * u,
                                    height: 1.2,
                                    color: HomeColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (dimmed) const ColoredBox(color: Color(0x88000000)),
              if (lock == LockMark.small)
                Positioned(
                  right: 4 * u,
                  bottom: 4 * u,
                  child: Icon(
                    Icons.lock,
                    color: const Color(0xFFFFF6E6),
                    size: 16 * u,
                  ),
                ),
              if (lock == LockMark.large)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20 * u),
                    child: Icon(
                      Icons.lock,
                      color: const Color(0xFFFFF6E6),
                      size: 38 * u,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum LockMark { none, small, large }

/// Falling confetti over a reveal: pack results mix brown, gray and gold;
/// a combine result uses its tier's colour (MM-17, MM-25).
class ConfettiLayer extends StatefulWidget {
  final List<Color> colors;
  const ConfettiLayer({super.key, required this.colors});

  static const packColors = [
    Color(0xFF8A5A2B),
    Color(0xFF9C9C9C),
    Color(0xFFE8C04A),
  ];

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();
  final _bits = <_Bit>[];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    for (var i = 0; i < 90; i++) {
      _bits.add(
        _Bit(
          x: rng.nextDouble(),
          delay: rng.nextDouble() * .35,
          speed: .7 + rng.nextDouble() * .6,
          drift: (rng.nextDouble() - .5) * .25,
          spin: rng.nextDouble() * 6,
          color: widget.colors[rng.nextInt(widget.colors.length)],
        ),
      );
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _clock,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_bits, _clock.value),
      ),
    ),
  );
}

class _Bit {
  final double x, delay, speed, drift, spin;
  final Color color;
  _Bit({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  final double t;
  _ConfettiPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in bits) {
      final local = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * b.speed * (size.height + 40);
      final x = (b.x + b.drift * local) * size.width;
      paint.color = b.color.withValues(alpha: 1 - max(0, local - .8) * 5);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * local * pi);
      canvas.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// The dark radial stage behind pack and combine reveals (MM-16..25).
class RevealStage extends StatelessWidget {
  final Widget child;
  const RevealStage({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        radius: .8,
        colors: [Color(0xFF5A5A5A), Color(0xFF151515)],
      ),
    ),
    child: child,
  );
}
