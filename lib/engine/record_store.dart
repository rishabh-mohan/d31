/// Finished runs, as Records lists them.
///
/// The original's Records button opens History (MM-09): one card per
/// completed run with its portrait, name, campaign and ending, each with a
/// trash corner. A run is recorded the moment it ends and its save is removed,
/// so it shows in History and no longer in Select Game. New records retain
/// the complete CSAT score card; legacy records with only a total still open
/// without inventing missing subject scores.
///
/// A record file is `record_<id>.json` holding one [RunRecord].
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'state.dart';
import 'admissions.dart';

class RunRecord {
  final int id;
  final String name;
  final String portrait;
  final String packId;
  final String modeTitle;

  /// The ending's title, or how the run closed when no ending named one.
  final String ending;
  final DateTime finishedAt;
  final Map<String, num> stats;
  final double? csatStandardScore;
  final CsatResult? scoreCard;

  /// "University — Department", when the run enrolled anywhere.
  final String? enrolled;
  final int? enrolledDepartmentId;
  final int? enrolledUniversityId;

  /// The ending code an END_GAME set (Achievements' Endings List).
  final int? endingCode;

  /// Levels reached, for Gym Rat and Work Addict.
  final int exerciseLevel;
  final int partTimeLevel;

  const RunRecord({
    required this.id,
    required this.name,
    required this.portrait,
    required this.packId,
    required this.modeTitle,
    required this.ending,
    required this.finishedAt,
    required this.stats,
    this.csatStandardScore,
    this.scoreCard,
    this.enrolled,
    this.enrolledDepartmentId,
    this.enrolledUniversityId,
    this.endingCode,
    this.exerciseLevel = 0,
    this.partTimeLevel = 0,
  });

  int get statTotal => stats.values.fold<num>(0, (a, b) => a + b).round();

  factory RunRecord.of(int id, GameState state, {required String ending}) {
    final department = state.enrolledDepartment == null
        ? null
        : state.pack.admissions.departments[state.enrolledDepartment];
    final university = department == null
        ? null
        : state.pack.admissions.universities[department.universityId];
    return RunRecord(
      id: id,
      name: state.fullName,
      portrait: state.portrait,
      packId: state.pack.manifest.id,
      modeTitle: state.modeTitle,
      ending: ending,
      finishedAt: DateTime.now(),
      stats: Map<String, num>.from(state.stats),
      csatStandardScore: state.csat?.standardScore,
      scoreCard: state.csat,
      enrolled: department == null
          ? null
          : [
              university?.name,
              department.name,
            ].whereType<String>().where((s) => s.isNotEmpty).join(' — '),
      enrolledDepartmentId: department?.id,
      enrolledUniversityId: department?.universityId,
      endingCode: state.endingCode,
      exerciseLevel: state.exerciseLevel.level,
      partTimeLevel: state.partTimeLevel.level,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'portrait': portrait,
    'packId': packId,
    'modeTitle': modeTitle,
    'ending': ending,
    'finishedAt': finishedAt.toIso8601String(),
    'stats': stats,
    'csatStandardScore': ?csatStandardScore,
    'scoreCard': ?scoreCard?.toJson(),
    'enrolled': ?enrolled,
    'enrolledDepartmentId': ?enrolledDepartmentId,
    'enrolledUniversityId': ?enrolledUniversityId,
    'endingCode': ?endingCode,
    'exerciseLevel': exerciseLevel,
    'partTimeLevel': partTimeLevel,
  };

  static RunRecord fromJson(int id, Map<String, dynamic> j) => RunRecord(
    id: id,
    name: j['name'] as String? ?? '',
    portrait: j['portrait'] as String? ?? '',
    packId: j['packId'] as String? ?? 'kss16',
    modeTitle: j['modeTitle'] as String? ?? '',
    ending: j['ending'] as String? ?? '',
    finishedAt:
        DateTime.tryParse(j['finishedAt'] as String? ?? '') ?? DateTime(2000),
    stats: ((j['stats'] as Map?) ?? const {}).map(
      (k, v) => MapEntry('$k', (v as num?) ?? 0),
    ),
    scoreCard: CsatResult.fromJson(
      (j['scoreCard'] as Map?)?.cast<String, dynamic>(),
    ),
    csatStandardScore: (j['csatStandardScore'] as num?)?.toDouble(),
    enrolled: j['enrolled'] as String?,
    enrolledDepartmentId: (j['enrolledDepartmentId'] as num?)?.toInt(),
    enrolledUniversityId: (j['enrolledUniversityId'] as num?)?.toInt(),
    endingCode: (j['endingCode'] as num?)?.toInt(),
    exerciseLevel: (j['exerciseLevel'] as num?)?.toInt() ?? 0,
    partTimeLevel: (j['partTimeLevel'] as num?)?.toInt() ?? 0,
  );
}

class RecordStore {
  RecordStore._();

  static final _recordFile = RegExp(r'^record_(\d+)\.json$');

  /// Overridden by tests, which must not touch the real documents directory.
  @visibleForTesting
  static Directory? directoryOverride;

  static Future<Directory?> _directory() async {
    final override = directoryOverride;
    if (override != null) return override;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/records');
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> _ids(Directory? dir) async {
    if (dir == null || !await dir.exists()) return const [];
    final ids = <int>[];
    await for (final entry in dir.list()) {
      final match = _recordFile.firstMatch(entry.uri.pathSegments.last);
      if (entry is File && match != null) ids.add(int.parse(match[1]!));
    }
    return ids;
  }

  /// Every readable record, most recently finished first.
  static Future<List<RunRecord>> list() async {
    final dir = await _directory();
    if (dir == null) return const [];
    final records = <RunRecord>[];
    for (final id in await _ids(dir)) {
      try {
        final text = await File('${dir.path}/record_$id.json').readAsString();
        records.add(
          RunRecord.fromJson(id, jsonDecode(text) as Map<String, dynamic>),
        );
      } catch (_) {
        // A corrupt record is skipped, not fatal.
      }
    }
    records.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return records;
  }

  /// Records a finished run. Returns null when there is nowhere to write.
  static Future<RunRecord?> add(
    GameState state, {
    required String ending,
  }) async {
    final dir = await _directory();
    if (dir == null) return null;
    try {
      await dir.create(recursive: true);
      final ids = await _ids(dir);
      final id = ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b) + 1;
      final record = RunRecord.of(id, state, ending: ending);
      final file = File('${dir.path}/record_$id.json');
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(record.toJson()));
      await temp.rename(file.path);
      return record;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(int id) async {
    final dir = await _directory();
    if (dir == null) return;
    final file = File('${dir.path}/record_$id.json');
    if (await file.exists()) await file.delete();
  }
}
