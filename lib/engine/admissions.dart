/// The CSAT, university applications and enrollment.
///
/// The catalog is recovered: `admissions.json` is the global university and
/// department lists, each department carrying its admission cutoff
/// (`deviation`, a CSAT standard score from 25.3 to 80.85). The scoring is
/// **not** recovered -- it is compiled in the original -- so a run's standard
/// score is fitted in `rules.exam` (see docs/D30-MODE-SPEC.md §7).
///
/// What content reads afterwards is recovered: `ENDING_CODE` turns the
/// endings on, `FUNC_GET_SUCCESS_LENGTH` counts the departments that
/// accepted you, and `FUNC_IS_ENTER_UNIV*` ask where you enrolled.
library;

import 'dart:convert';
import 'dart:math';

/// The pack's catalog file: `colleges.json`, or `admissions.json`, the name
/// packs built before TODO 41 used.
String? collegesFile(Map<String, String> files) =>
    files.containsKey('colleges.json')
    ? 'colleges.json'
    : files.containsKey('admissions.json')
    ? 'admissions.json'
    : null;

/// Lays a university set over a pack's files. [overlay] is a
/// `colleges_<set>.json`: `{"universities": [{"id", "name", "colorCode"?,
/// "crest"?}]}`. Each listed university is renamed (recoloured, and given its
/// own emblem, a path under the images folder) in the catalog and in
/// `badges.json`. Optional `departments` adds majors for this set; existing
/// departments retain their IDs and cutoffs.
Map<String, String> overlayColleges(Map<String, String> files, String overlay) {
  final overlayData = jsonDecode(overlay) as Map<String, dynamic>;
  final replace = <int, Map<String, dynamic>>{
    for (final u
        in (overlayData['universities'] as List? ?? const [])
            .whereType<Map<String, dynamic>>())
      if (u['id'] is num) (u['id'] as num).toInt(): u,
  };
  String rewrite(String text, String listKey, String idKey) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    for (final row
        in (json[listKey] as List? ?? const [])
            .whereType<Map<String, dynamic>>()) {
      final id = row[idKey];
      final swap = id is num ? replace[id.toInt()] : null;
      if (swap == null) continue;
      if (swap['name'] is String) row['name'] = swap['name'];
      if (swap['colorCode'] is String) row['colorCode'] = swap['colorCode'];
      if (swap['crest'] is String) row['crest'] = swap['crest'];
    }
    return jsonEncode(json);
  }

  final out = Map<String, String>.of(files);
  final catalog = collegesFile(files);
  if (catalog != null) {
    final data = jsonDecode(
      rewrite(files[catalog]!, 'universities', 'id'),
    ) as Map<String, dynamic>;
    if (overlayData['departments'] case final List additions) {
      data['departments'] = [
        ...data['departments'] as List? ?? const [],
        ...additions,
      ];
    }
    out[catalog] = jsonEncode(data);
  }
  if (files['badges.json'] case final badges?) {
    out['badges.json'] = rewrite(badges, 'badges', 'universityId');
  }
  return out;
}

class University {
  final int id;
  final String name;
  final String rank;
  final String? colorCode;

  /// The emblem, a path under the images folder. A pack may give any
  /// university its own (`crest` in colleges.json or an overlay); otherwise
  /// the original's crest for that id.
  final String? crest;

  String get crestPath => crest ?? 'kss/images/university/$id.png';

  /// Belongs to one story (Retry Year's two retry universities, say).
  final bool storyOnly;

  const University({
    required this.id,
    required this.name,
    required this.rank,
    this.colorCode,
    this.crest,
    this.storyOnly = false,
  });

  factory University.fromJson(Map<String, dynamic> j) => University(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? 'University ${j['id']}',
    rank: j['rank'] as String? ?? 'none',
    colorCode: j['colorCode'] as String?,
    crest: j['crest'] as String?,
    storyOnly: j['storyOnly'] == true,
  );
}

class Department {
  final int id;
  final int universityId;
  final String name;

  /// The admission cutoff, on the CSAT standard-score scale.
  final double deviation;

  /// The catalog's own wording of an application condition, if any.
  final String? condition;

  /// Items the application needs in the bag (a Student Recommendation).
  final List<int> requiredItems;

  const Department({
    required this.id,
    required this.universityId,
    required this.name,
    required this.deviation,
    this.condition,
    this.requiredItems = const [],
  });

  factory Department.fromJson(Map<String, dynamic> j) => Department(
    id: (j['id'] as num).toInt(),
    universityId: (j['universityId'] as num).toInt(),
    name: j['name'] as String? ?? 'Department ${j['id']}',
    deviation: (j['deviation'] as num).toDouble(),
    condition: j['condition'] as String?,
    requiredItems: ((j['requires'] as Map?)?['items'] as List? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList(),
  );

  /// The share of applicants this cutoff sits above, 0-100.
  double get percentile => Admissions.percentileOf(deviation);
}

class AdmissionsCatalog {
  final Map<int, University> universities;
  final Map<int, Department> departments;

  const AdmissionsCatalog({
    this.universities = const {},
    this.departments = const {},
  });

  bool get isEmpty => departments.isEmpty;

  factory AdmissionsCatalog.fromJson(Map<String, dynamic> j) =>
      AdmissionsCatalog(
        universities: {
          for (final u
              in (j['universities'] as List? ?? const [])
                  .whereType<Map<String, dynamic>>())
            (u['id'] as num).toInt(): University.fromJson(u),
        },
        departments: {
          for (final d
              in (j['departments'] as List? ?? const [])
                  .whereType<Map<String, dynamic>>())
            (d['id'] as num).toInt(): Department.fromJson(d),
        },
      );
}

/// One sitting of the CSAT.
class CsatResult {
  /// The run's standard score (the scale department cutoffs are written on).
  final double standardScore;

  /// Per-subject standard scores and grades (1 best .. 9).
  final Map<String, double> subjectScores;
  final Map<String, int> grades;

  const CsatResult({
    required this.standardScore,
    required this.subjectScores,
    required this.grades,
  });

  double get percentile => Admissions.percentileOf(standardScore);

  Map<String, dynamic> toJson() => {
    'standardScore': standardScore,
    'subjectScores': subjectScores,
    'grades': grades,
  };

  static CsatResult? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return CsatResult(
      standardScore: (j['standardScore'] as num?)?.toDouble() ?? 0,
      subjectScores: {
        for (final e in (j['subjectScores'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
      grades: {
        for (final e in (j['grades'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      },
    );
  }
}

class Admissions {
  /// The CSAT's cumulative grade bands: grade 1 is the top 4%, grade 2 the
  /// next 7% (to 11%), and so on to grade 9.
  static const gradeBands = [4, 11, 23, 40, 60, 77, 89, 96];

  /// Standard score -> percentile, on the normal curve the scale assumes
  /// (mean 50, standard deviation 10).
  static double percentileOf(double standardScore) =>
      100 * _phi((standardScore - 50) / 10);

  static int gradeFor(double standardScore) {
    final top = 100 - percentileOf(standardScore);
    for (var i = 0; i < gradeBands.length; i++) {
      if (top <= gradeBands[i]) return i + 1;
    }
    return 9;
  }

  /// The curve a pack gets when its rules name none: calibrated so 10k in
  /// every subject is ~10% at the hardest regular cutoff (73.24) and ~50%
  /// one tier down, 15k ~50% at the top, 25k ~99% (admission spread 2).
  static const defaultCurve = <List<num>>[
    [0, 20],
    [1000, 38],
    [3000, 50],
    [6000, 60],
    [10000, 68.94],
    [15000, 73.24],
    [25000, 81.84],
    [50000, 95],
  ];

  static const defaultSpread = 2.0;

  /// Fitted, not recovered: one subject's standard score from its stat,
  /// read off [curve], a list of `[stat, score]` points in rising order and
  /// joined by straight lines (flat past either end).
  static double subjectScoreFor(num stat, List<List<num>> curve) {
    if (curve.isEmpty) return 50;
    if (stat <= curve.first[0]) return curve.first[1].toDouble();
    for (var i = 1; i < curve.length; i++) {
      final x0 = curve[i - 1][0], y0 = curve[i - 1][1];
      final x1 = curve[i][0], y1 = curve[i][1];
      if (stat <= x1) {
        return (y0 + (y1 - y0) * (stat - x0) / (x1 - x0)).toDouble();
      }
    }
    return curve.last[1].toDouble();
  }

  /// Fitted, not recovered: `50 + 10 * (total - mean) / sd`. The older
  /// curve, used by packs whose rules still name meanTotal/sdTotal.
  static double standardScoreFor(
    num total, {
    required num mean,
    required num sd,
  }) => 50 + 10 * (total - mean) / (sd <= 0 ? 1 : sd);

  /// The chance a department accepts this score. Even at the cutoff it is a
  /// coin flip; `spread` points either side makes it about 73% / 27%.
  static double acceptanceChance(
    double standardScore,
    double cutoff, {
    double spread = 1.5,
  }) => 1 / (1 + exp(-(standardScore - cutoff) / (spread <= 0 ? 1 : spread)));

  // Abramowitz-Stegun 7.1.26, good to 1.5e-7.
  static double _phi(double x) {
    final t = 1 / (1 + 0.3275911 * x.abs() / sqrt2);
    final y =
        1 -
        (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                        0.284496736) *
                    t +
                0.254829592) *
            t *
            exp(-x * x / 2);
    return x >= 0 ? (1 + y) / 2 : (1 - y) / 2;
  }
}
