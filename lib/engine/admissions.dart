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

/// Which tab of the school browser a university belongs to.
///
/// Derived from the original `type`: none -> [korea]; `notReal` -> [special]
/// (Basakan, the Retry universities); `studyAbroad` -> [global];
/// `studyTw` -> [taiwan]; `notUniv` -> [retake] (the Retry Academy, which is
/// the failure outcome and never an application candidate).
enum UniversityCategory {
  korea,
  special,
  global,
  taiwan,
  retake;

  static UniversityCategory parse(Object? v, {required bool storyOnly}) {
    for (final c in values) {
      if (c.name == v) return c;
    }
    // Catalogs built before categories existed: story-only meant Special.
    return storyOnly ? special : korea;
  }
}

class University {
  final int id;
  final String name;
  final String rank;
  final String? colorCode;

  /// Which school-browser tab lists it.
  final UniversityCategory category;

  /// The gold-star rating the browser prints: rank ten is 5.0, nine is 4.5,
  /// down to one at 0.5 (0 for no rank).
  final double stars;

  /// The emblem, a path under the images folder. A pack may give any
  /// university its own (`crest` in colleges.json or an overlay); otherwise
  /// the original's crest for that id.
  final String? crest;

  String get crestPath => crest ?? 'kss/images/university/$id.png';

  /// Outside the regular Korean set: story-restricted, Special, Global,
  /// Taiwan or the Retry Academy. (The name is older than the categories;
  /// "regular" code and tests still ask `!storyOnly`.)
  final bool storyOnly;

  /// The stories allowed to apply, when the original restricts it (a Retry
  /// University is "Available for admission in ... Retry University").
  /// Empty means every story.
  final List<int> availableStories;

  /// Whether this pack's story may apply. A restricted school outside its
  /// story stays in the catalog (the browser shows it darkened) but has no
  /// departments and cannot be drafted.
  final bool available;

  const University({
    required this.id,
    required this.name,
    required this.rank,
    this.colorCode,
    this.crest,
    this.category = UniversityCategory.korea,
    this.stars = 0,
    this.storyOnly = false,
    this.availableStories = const [],
    this.available = true,
  });

  factory University.fromJson(Map<String, dynamic> j) {
    final restricted = j['storyOnly'] == true;
    final category = UniversityCategory.parse(
      j['category'],
      storyOnly: restricted,
    );
    return University(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? 'University ${j['id']}',
      rank: j['rank'] as String? ?? 'none',
      colorCode: j['colorCode'] as String?,
      crest: j['crest'] as String?,
      category: category,
      stars: (j['stars'] as num?)?.toDouble() ?? 0,
      storyOnly: restricted || category != UniversityCategory.korea,
      availableStories: [
        for (final n in j['availableStories'] as List? ?? const [])
          if (n is num) n.toInt(),
      ],
      available: j['available'] != false,
    );
  }
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

  static final Expando<Map<int, List<Department>>> _byUniversity = Expando();

  /// A university's departments, hardest cutoff first.
  List<Department> departmentsOf(int universityId) {
    final index = _byUniversity[this] ??= () {
      final map = <int, List<Department>>{};
      for (final d in departments.values) {
        (map[d.universityId] ??= []).add(d);
      }
      for (final list in map.values) {
        list.sort((a, b) {
          final c = b.deviation.compareTo(a.deviation);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      }
      return map;
    }();
    return index[universityId] ?? const [];
  }

  /// The universities of one browser tab, highest rank first (the browser's
  /// tier panels), then by name.
  List<University> inCategory(UniversityCategory category) =>
      universities.values.where((u) => u.category == category).toList()
        ..sort((a, b) {
          final c = b.stars.compareTo(a.stars);
          return c != 0 ? c : a.name.compareTo(b.name);
        });

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

/// One sitting of the CSAT, and of the Graduation Exam it is announced as.
///
/// [subjectScores] / [grades] / [standardScore] are the admission model's
/// (the scale department cutoffs are written on). [examScores] and
/// [topPercents] are what the score announcement and score card print: an
/// integer 0-100 Score and a one-decimal Top % per subject (HANDOFF section 2).
/// Both are FITTED, not recovered; see [GraduationExam].
class CsatResult {
  /// The run's standard score (the scale department cutoffs are written on).
  final double standardScore;

  /// Per-subject standard scores and grades (1 best .. 9).
  final Map<String, double> subjectScores;
  final Map<String, int> grades;

  /// The announced per-subject Score (0-100). Empty in records written before
  /// the announcement existed.
  final Map<String, int> examScores;

  /// The announced per-subject Top %, one decimal. Empty in old records.
  final Map<String, double> topPercents;

  const CsatResult({
    required this.standardScore,
    required this.subjectScores,
    required this.grades,
    this.examScores = const {},
    this.topPercents = const {},
  });

  double get percentile => Admissions.percentileOf(standardScore);

  Map<String, dynamic> toJson() => {
    'standardScore': standardScore,
    'subjectScores': subjectScores,
    'grades': grades,
    if (examScores.isNotEmpty) 'examScores': examScores,
    if (topPercents.isNotEmpty) 'topPercents': topPercents,
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
      examScores: {
        for (final e in (j['examScores'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      },
      topPercents: {
        for (final e in (j['topPercents'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
    );
  }
}

/// The Graduation Exam's per-subject Score (0-100) and Top %.
///
/// FITTED, not recovered: the original computes both in compiled code. The
/// fixture it is fitted to is the user's recording (HANDOFF section 2): final
/// study stats 2205 / 2158 / 1253 / 1630 / 3476 were announced as Scores
/// 58 / 59 / 50 / 53 / 66 and Top % 47.7 / 46.1 / 58.6 / 55.0 / 35.8.
///
/// * [scoreCurve] maps a subject's stat to a base Score (straight lines
///   between `[stat, score]` points; 1253 -> 50, 1630 -> 53, 2181 -> 58,
///   3476 -> 66). The recording is not monotonic (2205 -> 58 but 2158 -> 59),
///   so a seeded per-subject variation of +-[variation] (1.0) points is added.
/// * [topTable] maps a Score to Top % by straight lines between
///   `[score, top]` points; it passes exactly through the recording's five
///   (score, Top %) pairs and follows a normal curve (mean 56.5, sd 26.2)
///   elsewhere. Top % is monotonic in Score.
class GraduationExam {
  static const scoreCurve = <List<num>>[
    [0, 18],
    [500, 36],
    [1253, 50],
    [1630, 53],
    [2181, 58],
    [3476, 66],
    [6000, 77],
    [10000, 87],
    [15000, 93],
    [25000, 99],
    [50000, 100],
  ];

  static const topTable = <List<num>>[
    [0, 98.4],
    [10, 96.2],
    [20, 91.8],
    [30, 84.4],
    [40, 73.6],
    [45, 67.0],
    [50, 58.6],
    [53, 55.0],
    [58, 47.7],
    [59, 46.1],
    [66, 35.8],
    [75, 24.0],
    [85, 13.8],
    [95, 7.1],
    [100, 4.8],
  ];

  /// Seeded variation in Score points (uniform in -v..+v before rounding; chosen so the fixture stays within two points).
  static const variation = 1.0;

  /// A Score at or above this draws "That wasn't so bad..." at the exam card;
  /// below it "I'm not so sure about this...". Reconstructed: the recording
  /// has 58/59/50/53 unsure and 66 fine.
  static const confidentScore = 60;

  static double _line(num x, List<List<num>> pts) {
    if (pts.isEmpty) return 0;
    if (x <= pts.first[0]) return pts.first[1].toDouble();
    for (var i = 1; i < pts.length; i++) {
      if (x <= pts[i][0]) {
        final x0 = pts[i - 1][0], y0 = pts[i - 1][1];
        final x1 = pts[i][0], y1 = pts[i][1];
        return (y0 + (y1 - y0) * (x - x0) / (x1 - x0)).toDouble();
      }
    }
    return pts.last[1].toDouble();
  }

  /// The Score before variation (not rounded).
  static double baseScore(num stat, [List<List<num>> curve = scoreCurve]) =>
      _line(stat, curve);

  /// A subject's announced Score: base plus a deterministic variation
  /// derived from [seed] (any stable integer), rounded and clamped 0-100.
  static int score(
    num stat,
    int seed, {
    List<List<num>> curve = scoreCurve,
    double spread = variation,
  }) {
    final unit = Random(seed).nextDouble() * 2 - 1;
    return (baseScore(stat, curve) + unit * spread).round().clamp(0, 100);
  }

  /// Top % for a Score, one decimal.
  static double topPercent(int score, [List<List<num>> table = topTable]) =>
      (_line(score, table) * 10).round() / 10;

  /// A stable 31-bit hash of text (Dart's String.hashCode is not stable
  /// across runs), for seeding.
  static int seedOf(String text) {
    var h = 0x811C9DC5;
    for (final c in text.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
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

  /// 100 * product(1 - rate / 100) over the DISPLAYED integer rates: the
  /// Apply? modal's "Chances of total rejection" (40.04 for 23/20/35, 63.063
  /// for 23/9/10). Computed in integers, so it is exact to four decimals.
  static double totalRejectionPercent(Iterable<int> displayedRates) {
    var product = 1;
    var count = 0;
    for (final r in displayedRates) {
      product *= 100 - r.clamp(0, 100);
      count++;
    }
    if (count == 0) return 100;
    // product / 100^count is the fraction; times 100 is the percentage.
    var divisor = 1;
    for (var i = 1; i < count; i++) {
      divisor *= 100;
    }
    return product / divisor;
  }

  /// A percentage without forced decimals: 40.04, 63.063, 100, 7.5. At most
  /// [maxDecimals] places, trailing zeros dropped.
  static String formatPercent(double value, {int maxDecimals = 4}) {
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

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
