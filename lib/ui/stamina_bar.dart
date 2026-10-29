import 'package:flutter/material.dart';

import 'theme.dart';

/// The outlined stamina bar.
///
/// The reference prints the percentage *inside* the bar, against the right end
/// of the filled part: at 100% it sits at the bar's right end, at 6% it has
/// slid to the left edge and turned red. It is never hidden, however little is
/// left.
class StaminaBar extends StatelessWidget {
  final double pct;
  const StaminaBar({super.key, required this.pct});

  static const _labelWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final target = pct.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _contents(context, value),
    );
  }

  Widget _contents(BuildContext context, double value) {
    final low = value <= .25;
    // The outline is painted over the fill, not under it: drawn underneath,
    // the fill's square ends covered the inside of the rounded corners and
    // the border looked clipped there (TODO 61).
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: D30Colors.hpTrack,
        borderRadius: BorderRadius.circular(8),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.packColors.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final left = (width * value - _labelWidth - 4).clamp(
            0.0,
            (width - _labelWidth).clamp(0.0, double.infinity),
          );
          return Stack(
            children: [
              FractionallySizedBox(
                widthFactor: value,
                child: Container(color: D30Colors.hpGreen),
              ),
              Positioned(
                left: left,
                top: 0,
                bottom: 0,
                width: _labelWidth,
                child: Center(
                  child: Text(
                    '${(value * 100).round()}%',
                    key: const ValueKey('hp-percent'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: low ? D30Colors.alert : context.packColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
