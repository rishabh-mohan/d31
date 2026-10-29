import 'press_feedback.dart';

import 'package:flutter/material.dart';

import 'pack_image.dart';
import 'theme.dart';

String stationeryTypeLabel(String type) =>
    const {
      'pencil': 'Pencils',
      'eraser': 'Erasers',
      'note': 'Notebooks',
      'markingPen': 'Fineliners',
    }[type] ??
    type;

/// Largest font size, down from 10pt, at which [text] still fits [lines]
/// lines inside [maxWidth].
///
/// Measured: the search costs up to ten `TextPainter.layout` calls and it sits
/// inside a `LayoutBuilder`, so it ran on every rebuild *and* every relayout.
/// On the preparation hub — four two-line cards inside a `FittedBox` — that
/// was ~11ms of a ~24ms rebuild. The answer only depends on the arguments, so
/// it is cached; the key set is bounded by the stationery catalogue.
double _fittedSize(
  String text,
  double maxWidth,
  int lines,
  TextDirection direction,
  TextScaler scaler,
) {
  final key = '$text|${maxWidth.round()}|$lines|$direction|$scaler';
  final cached = _fittedSizes[key];
  if (cached != null) return cached;

  var size = 10.0;
  final painter = TextPainter(
    maxLines: lines,
    textDirection: direction,
    textScaler: scaler,
  );
  while (size > 5) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(fontSize: size),
    );
    painter.layout(maxWidth: maxWidth);
    if (!painter.didExceedMaxLines) break;
    size -= .5;
  }
  painter.dispose();
  return _fittedSizes[key] = size;
}

final Map<String, double> _fittedSizes = {};

List<Color> stationeryRankColors(String rank) => switch (rank) {
  'S' => const [
    Color(0xFFFFB4D9),
    Color(0xFFFFED98),
    Color(0xFFABEDC8),
    Color(0xFF9BD9FF),
    Color(0xFFD8ACF0),
  ],
  'A' => const [Color(0xFFE4B600), Color(0xFFFFE47A)],
  'B' => const [Color(0xFFCADAF4), Color(0xFFE3E9FA)],
  _ => const [Color(0xFFBBBBBB), Color(0xFFDDDDDD)],
};

/// Shared by inventory, combination, and Thursday's draw.
class StationeryCard extends StatelessWidget {
  final int id;
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  final int? count;
  final bool equipped;
  final bool locked;
  final bool selected;
  final int nameLines;
  const StationeryCard({
    super.key,
    required this.id,
    required this.item,
    this.onTap,
    this.count,
    this.equipped = false,
    this.locked = false,
    this.selected = false,
    this.nameLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final rank = item['rank'] as String;
    final rows = (item['studyStats'] as List? ?? const []).whereType<Map>();
    final colors = stationeryRankColors(rank);
    return Semantics(
      label: '$rank tier ${item['name']}${equipped ? ', equipped' : ''}',
      child: PressFeedback(
        child: InkWell(
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            // Paint last as well as reserving an inset: fractional device
            // scaling must not let a stat fill erase the rounded outline.
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: selected ? context.packColors.accent : Colors.black87,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected ? context.packColors.accent : Colors.black87,
              borderRadius: BorderRadius.circular(9),
            ),
            // A real inset reserves the border: no image/blank placeholder or
            // colored stat row can paint into it, even at the rounded corners.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: ColoredBox(
                color: context.packColors.panel,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stationeryTypeLabel(item['type'] as String),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: FractionallySizedBox(
                                widthFactor: .64,
                                heightFactor: .64,
                                child: PackImage(
                                  path: 'stationery/$id.png',
                                  fit: BoxFit.contain,
                                  placeholder: const Icon(Icons.edit, size: 24),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 3,
                              left: 4,
                              child: Text(
                                rank,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (count != null)
                              Positioned(
                                bottom: 2,
                                right: 4,
                                child: Text(
                                  '×$count',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            if (equipped)
                              const Positioned(
                                top: 2,
                                right: 2,
                                child: Icon(
                                  Icons.backpack,
                                  color: Colors.black54,
                                  size: 20,
                                ),
                              ),
                            if (locked)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.black38,
                                  child: const Icon(
                                    Icons.lock,
                                    color: Colors.black,
                                    size: 42,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: nameLines == 1
                          ? Text(
                              item['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final size = _fittedSize(
                                  item['name'] as String,
                                  constraints.maxWidth,
                                  nameLines,
                                  Directionality.of(context),
                                  MediaQuery.textScalerOf(context),
                                );
                                return Text(
                                  item['name'] as String,
                                  maxLines: nameLines,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: size),
                                );
                              },
                            ),
                    ),
                    for (final row in rows)
                      Container(
                        width: double.infinity,
                        color: D30Colors.subject(
                          row['subjectType'] as String? ?? '',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${row['isAll'] == true ? 'All' : subjectLabel(row['subjectType'] as String? ?? '')} +${row['stat']}',
                            style: const TextStyle(fontSize: 11),
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
    );
  }
}
