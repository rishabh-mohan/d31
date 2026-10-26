/// Read-only History detail, based on F17/F18 and the original function atlas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/record_store.dart';
import 'home_screen.dart';
import 'pack_image.dart';
import 'score_card.dart';
import 'stationery_card.dart';
import 'theme.dart';

class RecordDetails extends StatefulWidget {
  final RunRecord record;
  const RecordDetails({super.key, required this.record});

  static Future<void> show(BuildContext context, RunRecord record) =>
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => RecordDetails(record: record),
        transitionBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  State<RecordDetails> createState() => _RecordDetailsState();
}

class _RecordDetailsState extends State<RecordDetails> {
  int tab = 1;
  RunRecord get record => widget.record;
  Map<String, dynamic> get details => record.details;
  static const titles = ['Application Results', 'Info', 'Score Card'];
  static const labels = ['University Apps', 'Info', 'Score Card'];
  static const icons = [Icons.school, Icons.account_box, Icons.bar_chart];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = math.min(box.maxWidth, 600.0);
      final u = width / 390;
      return DefaultTextStyle(
        style: TextStyle(
          fontSize: 14 * u,
          color: HomeColors.ink,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 88 * u,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: Material(
                color: HomeColors.paper,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: HomeColors.orange, width: 4 * u),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12 * u),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SizedBox(
                      height: 72 * u,
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 43 * u),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  titles[tab],
                                  style: TextStyle(fontSize: 23 * u),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Material(
                              color: const Color(0xFFE75554),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(9 * u),
                              ),
                              child: IconButton(
                                key: const ValueKey('record-close'),
                                tooltip: 'Close',
                                onPressed: () => Navigator.pop(context),
                                iconSize: 33 * u,
                                color: HomeColors.paper,
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * u),
                      child: const Divider(color: HomeColors.ink, height: 1),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: tab,
                        children: [_applications(u), _info(u), _scores(u)],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        color: HomeColors.orange,
                        height: 48 * u,
                        child: Row(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Expanded(
                                flex: i == tab ? 2 : 1,
                                child: InkWell(
                                  key: ValueKey('record-tab-$i'),
                                  onTap: () => setState(() => tab = i),
                                  child: SizedBox.expand(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          icons[i],
                                          color: HomeColors.paper,
                                          size: 25 * u,
                                        ),
                                        if (i == tab) ...[
                                          SizedBox(width: 6 * u),
                                          Flexible(
                                            child: Text(
                                              labels[i],
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 17 * u,
                                                color: HomeColors.paper,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _info(double u) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      key: const ValueKey('record-info'),
      padding: EdgeInsets.symmetric(horizontal: 25 * u, vertical: 28 * u),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0, box.maxHeight - 56 * u),
        ),
        child: Center(
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 12 * u),
            child: _infoCard(u),
          ),
        ),
      ),
    ),
  );

  Widget _infoCard(double u) => Container(
    padding: EdgeInsets.all(14 * u),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEDB),
      borderRadius: BorderRadius.circular(23 * u),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: 78 * u,
              height: 130 * u,
              child: PackImage(
                path: record.portrait,
                alignment: Alignment.bottomCenter,
                placeholder: const PackImage(
                  path: genericPortrait,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
            SizedBox(width: 10 * u),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name.isEmpty ? 'Unnamed' : record.name,
                    style: TextStyle(fontSize: 22 * u),
                  ),
                  if (details['studyLevel'] != null)
                    Text(
                      'LV ${details['studyLevel']} ${details['studyName']} (${_number(details['studyExp'])}/${details['studyNext'] == null ? 'MAX' : _number(details['studyNext'])})',
                    ),
                  if (details['money'] != null)
                    Text('${_number(details['money'])} Gold'),
                  if (record.scoreCard case final card?)
                    Text(
                      'Deviation : ${card.standardScore.toStringAsFixed(1)}',
                    ),
                  Text(
                    'Exercise Level ${record.exerciseLevel}${_progress('exerciseProgress')}',
                  ),
                  Text(
                    'Part-Time Level ${record.partTimeLevel}${_progress('partTimeProgress')}',
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * u),
        Row(
          children: [
            for (final entry in record.stats.entries)
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 2 * u),
                  padding: EdgeInsets.symmetric(
                    vertical: 7 * u,
                    horizontal: 2 * u,
                  ),
                  decoration: BoxDecoration(
                    color: D30Colors.subject(entry.key),
                    borderRadius: BorderRadius.circular(9 * u),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        child: Text(
                          subjectLabel(entry.key),
                          style: TextStyle(fontSize: 10 * u),
                        ),
                      ),
                      FittedBox(
                        child: Text(
                          '${entry.value.round()}',
                          style: TextStyle(fontSize: 14 * u),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10 * u),
          child: const Divider(color: HomeColors.ink, thickness: 1.5),
        ),
        SizedBox(
          height: 200 * u,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _traits(u)),
              const VerticalDivider(color: HomeColors.ink),
              Expanded(child: _stationery(u)),
            ],
          ),
        ),
      ],
    ),
  );

  String _progress(String key) => details[key] is num
      ? ' (${((details[key] as num) * 100).toStringAsFixed(1)}%)'
      : '';
  String _number(dynamic value) => value is num ? '${value.round()}' : '—';

  Widget _traits(double u) {
    final traits = (details['traits'] as List? ?? const []).whereType<Map>();
    return traits.isEmpty
        ? const Center(child: Text('No traits'))
        : ListView(
            children: [
              for (final trait in traits)
                Container(
                  margin: EdgeInsets.only(bottom: 6 * u),
                  padding: EdgeInsets.all(7 * u),
                  decoration: BoxDecoration(
                    color: traitColor(trait['type'] as String?),
                    borderRadius: BorderRadius.circular(9 * u),
                  ),
                  child: Tooltip(
                    message: '${trait['description'] ?? ''}',
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 11 * u,
                          color: trait['rank'] == 'S'
                              ? Colors.black
                              : const Color(0xFFC5B24B),
                        ),
                        SizedBox(width: 5 * u),
                        Expanded(
                          child: Text(
                            '${trait['name']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12 * u,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
  }

  Widget _stationery(double u) {
    final items = (details['stationery'] as List? ?? const []).whereType<Map>();
    return items.isEmpty
        ? const Center(child: Text('No stationery'))
        : LayoutBuilder(
            builder: (context, box) => GridView.count(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 6 * u,
              mainAxisSpacing: 8 * u,
              childAspectRatio:
                  (box.maxWidth - 6 * u) / (box.maxHeight - 8 * u),
              children: [
                for (final item in items)
                  StationeryCard(
                    id: (item['id'] as num).toInt(),
                    item: (item['item'] as Map).cast<String, dynamic>(),
                    nameLines: 2,
                  ),
              ],
            ),
          );
  }

  Widget _scores(double u) => record.scoreCard == null
      ? Center(
          child: Padding(
            padding: EdgeInsets.all(24 * u),
            child: const Text(
              'This run did not sit the CSAT.',
              textAlign: TextAlign.center,
            ),
          ),
        )
      : Padding(
          padding: EdgeInsets.all(20 * u),
          child: ExamScoreCard(name: record.name, result: record.scoreCard!),
        );

  Color _schoolColor(Map row) {
    final hex = '${row['colorCode'] ?? ''}'.replaceAll('#', '');
    return Color(0xFF000000 | (int.tryParse(hex, radix: 16) ?? 0xAD283D));
  }

  Widget _applications(double u) {
    final rows = (details['applications'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final enrolled = details['enrollment'];
    return ListView(
      key: const ValueKey('record-applications'),
      padding: EdgeInsets.all(24 * u),
      children: [
        if (enrolled is Map) _certificate(enrolled, u),
        if (enrolled is! Map && record.enrolled != null)
          Padding(
            padding: EdgeInsets.only(bottom: 18 * u),
            child: Text(
              'Enrolled: ${record.enrolled}',
              style: TextStyle(fontSize: 18 * u),
            ),
          ),
        for (final row in rows)
          Container(
            margin: EdgeInsets.only(bottom: 12 * u),
            padding: EdgeInsets.all(12 * u),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              border: Border.all(color: _schoolColor(row), width: 3 * u),
              borderRadius: BorderRadius.circular(12 * u),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 62 * u,
                  height: 80 * u,
                  child: PackImage(path: row['crest'] as String?),
                ),
                SizedBox(width: 12 * u),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['university'] ?? ''}'),
                      Text('${row['department'] ?? ''}'),
                      SizedBox(height: 8 * u),
                      const Text(
                        'Acceptance Rate : —',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8 * u),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * u,
                    vertical: 18 * u,
                  ),
                  decoration: BoxDecoration(
                    color: row['accepted'] == true
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE45A56),
                    borderRadius: BorderRadius.circular(10 * u),
                  ),
                  child: Text(
                    row['accepted'] == true ? 'Accepted' : 'Rejected',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        if (rows.isEmpty)
          Padding(
            padding: EdgeInsets.all(20 * u),
            child: const Text(
              'No university applications in this run.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _certificate(Map row, double u) {
    final color = _schoolColor(row);
    return Container(
      key: const ValueKey('record-certificate'),
      margin: EdgeInsets.only(bottom: 22 * u),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        border: Border.all(color: color, width: 3 * u),
        borderRadius: BorderRadius.circular(12 * u),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: color,
            padding: EdgeInsets.all(8 * u),
            child: Text(
              '${row['university'] ?? ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16 * u),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12 * u),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: .12,
                    child: PackImage(path: row['crest'] as String?),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '[ S t u d e n t  I D  C a r d ]',
                      style: TextStyle(
                        fontSize: 14 * u,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10 * u),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Name: ${record.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${row['department']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 7 * u),
                              Text(
                                'The bearer of this certificate is hereby verified as a student of this university.',
                                style: TextStyle(fontSize: 11 * u),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 7 * u),
                        SizedBox(
                          width: 80 * u,
                          height: 100 * u,
                          child: PackImage(
                            path: record.portrait,
                            placeholder: const PackImage(path: genericPortrait),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10 * u),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 25 * u,
                          height: 25 * u,
                          child: PackImage(path: row['crest'] as String?),
                        ),
                        Flexible(
                          child: Text(
                            '${row['university']}, President',
                            style: TextStyle(fontSize: 10 * u),
                          ),
                        ),
                        SizedBox(
                          width: 24 * u,
                          height: 24 * u,
                          child: const PackImage(
                            path: 'kss/images/univ_stamp.png',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
