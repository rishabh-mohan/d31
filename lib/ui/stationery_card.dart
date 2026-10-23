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
    final colors = switch (rank) {
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
    return Semantics(
      label: '$rank tier ${item['name']}${equipped ? ', equipped' : ''}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: D30Colors.panel,
            border: Border.all(
              color: selected ? D30Colors.accent : Colors.black87,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stationeryTypeLabel(item['type'] as String),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
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
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: nameLines == 1
                    ? Text(
                        item['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          var size = 10.0;
                          final painter = TextPainter(
                            maxLines: nameLines,
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          );
                          while (size > 5) {
                            painter.text = TextSpan(
                              text: item['name'] as String,
                              style: TextStyle(fontSize: size),
                            );
                            painter.layout(maxWidth: constraints.maxWidth);
                            if (!painter.didExceedMaxLines) break;
                            size -= .5;
                          }
                          painter.dispose();
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
                  color: D30Colors.subject(row['subjectType'] as String? ?? ''),
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
    );
  }
}
