import 'package:flutter/material.dart';

import '../engine/pack.dart';
import 'pack_image.dart';

Color badgeColor(UniversityBadge? badge) {
  final hex = badge?.colorCode?.replaceAll('#', '');
  return Color(int.tryParse('FF${hex ?? ''}', radix: 16) ?? 0xFFFF8B55);
}

class UniversityBadgeView extends StatelessWidget {
  final ContentPack pack;
  final int? id;
  final VoidCallback? onTap;
  const UniversityBadgeView({
    super.key,
    required this.pack,
    this.id,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = pack.badges[id];
    final color = badgeColor(badge);
    final path = (pack.presentation['badges'] as Map?)?['$id'] as String?;
    return Semantics(
      label: badge?.name ?? 'Empty university badge',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(Colors.white, color, .08),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: badge == null
                ? Center(
                    child: Text(
                      '—',
                      style: TextStyle(color: color, fontSize: 26),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: path == null
                            ? id == 2
                                  ? const CustomPaint(
                                      painter: _DreamCrest(),
                                      child: SizedBox.expand(),
                                    )
                                  : Icon(Icons.shield, color: color, size: 28)
                            : PackImage(path: path, fit: BoxFit.contain),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 95,
                              child: Text(
                                badge.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  height: 1.05,
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
    );
  }
}

/// Four crests above three centered crests; names never determine slot size.
class UniversityBadgeSlots extends StatelessWidget {
  final ContentPack pack;
  final List<int> ids;
  final ValueChanged<int>? onRemove;
  const UniversityBadgeSlots({
    super.key,
    required this.pack,
    required this.ids,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = (box.maxWidth - 18) / 4;
      Widget slot(int i) => SizedBox(
        width: size,
        height: size,
        child: UniversityBadgeView(
          pack: pack,
          id: i < ids.length ? ids[i] : null,
          onTap: i < ids.length && onRemove != null
              ? () => onRemove!(ids[i])
              : null,
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                slot(i),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 4; i < 7; i++) ...[
                if (i > 4) const SizedBox(width: 6),
                slot(i),
              ],
            ],
          ),
        ],
      );
    },
  );
}

// Exact local 2.svg path, retained as a vector so no SVG dependency is needed.
class _DreamCrest extends CustomPainter {
  const _DreamCrest();
  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width < size.height ? size.width : size.height) / 180;
    canvas.save();
    canvas.translate(
      (size.width - 180 * scale) / 2,
      (size.height - 180 * scale) / 2,
    );
    canvas.scale(scale);
    final shield = Path()
      ..moveTo(32, 0)
      ..lineTo(148, 0)
      ..lineTo(148, 122)
      ..cubicTo(148, 154.032515, 122.032515, 180, 90, 180)
      ..cubicTo(57.9674845, 180, 32, 154.032515, 32, 122)
      ..close();
    canvas.drawPath(shield, Paint()..color = const Color(0xFF082D84));
    canvas.drawPath(
      Path()
        ..moveTo(72, 136)
        ..lineTo(90, 118)
        ..lineTo(108, 136),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.square,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DreamCrest oldDelegate) => false;
}
