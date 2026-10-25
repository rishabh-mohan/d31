/// The D-Day flow's engine API: exam cards, the score announcement, the
/// draft candidates, the committed applications and the final decision.
///
/// This is the data/engine half of the recreated sequence documented in
/// docs/DDAY-FLOW.md (evidence: screenshots/dday-applications-2026-10-25/
/// HANDOFF.md). Screens call these methods and never touch the dice: every
/// outcome is rolled once, stored in [GameState] and saved with the run, so
/// rebuilding, resuming or replaying an animation can never reroll it.
///
/// Recovered vs reconstructed is marked on each member. In short: the
/// sequence, labels and arithmetic are recovered from the recording; exam
/// Scores / Top %, the draft rules and Auto Input's choice are FITTED or
/// RECONSTRUCTED.
library;

import 'admissions.dart';
import 'event_engine.dart';
import 'game.dart';
import 'game_date.dart';
import 'pack.dart';

/// Where the player is in the D-Day flow (derived from saved state, so a
/// resumed run lands on the same stage).
enum DDayStage {
  /// Not exam day, or the exam has not been started by its scene.
  none,

  /// The Graduation Exam scene is over; subject cards are being taken.
  examCards,

  /// All cards taken; the score announcement has not been confirmed.
  scoreAnnouncement,

  /// Choosing candidates (Submit route). Nothing is committed yet.
  drafting,

  /// Applications are committed; the envelopes / results are being shown.
  results,

  /// Results confirmed; the player picks a program or the retake academy.
  finalDecision,

  /// Enrolled: the ending events, completion summary and reward follow.
  ending,
}

/// One exam card in the hand area.
class ExamCard {
  /// The pack's subject key (`korean`, `math`, `english`, `science`,
  /// `society`).
  final String subject;

  /// Display name (`Korean`, `Maths`, `English`, `Science`, `Humanities`).
  final String label;
  final bool done;

  /// The short response line shown after the card was taken.
  final String? response;

  const ExamCard({
    required this.subject,
    required this.label,
    required this.done,
    this.response,
  });
}

/// What tapping an exam card did.
class ExamTurn {
  final String subject;
  final String label;

  /// "I'm not so sure about this..." or "That wasn't so bad..." (RECOVERED
  /// strings, RECONSTRUCTED choice by score threshold).
  final String response;

  /// This subject's announced Score (not shown on the card; informational).
  final int score;

  /// The clock after the card advanced one tick.
  final GameDate date;

  const ExamTurn({
    required this.subject,
    required this.label,
    required this.response,
    required this.score,
    required this.date,
  });
}

/// One committed application and its stored verdict.
class ApplicationResult {
  final Department department;
  final University? university;

  /// The displayed integer acceptance rate the roll used.
  final int rate;
  final bool accepted;

  /// This is the program the student enrolled in.
  final bool enrolled;

  const ApplicationResult({
    required this.department,
    required this.university,
    required this.rate,
    required this.accepted,
    required this.enrolled,
  });
}

/// One card on the Final Decision page.
class FinalOption {
  final Department department;
  final University? university;

  /// The Korea Retry Academy / Comprehensive Retake Course card.
  final bool isRetake;

  const FinalOption({
    required this.department,
    required this.university,
    required this.isRetake,
  });
}

extension DDayFlow on Game {
  // --- exam cards ----------------------------------------------------------

  Map<String, dynamic> get _gradExamRules {
    final v = pack.rules.section('exam')['gradExam'];
    return v is Map ? v.cast<String, dynamic>() : const {};
  }

  /// A subject's display name, from `rules.exam.subjectLabels` (the pack
  /// names the elective slots: story 16's are Science and Humanities), or
  /// its capitalised key.
  String subjectLabel(String subject) {
    final labels = pack.rules.section('exam')['subjectLabels'];
    if (labels is Map && labels[subject] is String) {
      return labels[subject] as String;
    }
    return subject.isEmpty
        ? subject
        : subject[0].toUpperCase() + subject.substring(1);
  }

  /// The five exam cards in the pack's subject order, with done flags.
  List<ExamCard> get examCards => [
    for (final s in pack.manifest.subjects)
      ExamCard(
        subject: s,
        label: subjectLabel(s),
        done: state.examCardsDone.contains(s),
        response: state.examResponses[s],
      ),
  ];

  /// The card to show now, or null when all are taken.
  ExamCard? get currentExamCard => examCards.where((c) => !c.done).firstOrNull;

  bool get examCardsComplete =>
      pack.manifest.subjects.every(state.examCardsDone.contains);

  /// Exam day, the Graduation Exam scene has closed (`START_SAT`), and cards
  /// remain. While true the hand area shows [currentExamCard].
  bool get examCardsPending => state.csatPending && !examCardsComplete;

  int _examSeed(String subject) =>
      GraduationExam.seedOf('${state.fullName}|${pack.manifest.id}|$subject');

  List<List<num>> _table(String key, List<List<num>> fallback) {
    final raw = _gradExamRules[key];
    if (raw is! List) return fallback;
    final out = [
      for (final p in raw)
        if (p is List && p.length == 2 && p[0] is num && p[1] is num)
          [p[0] as num, p[1] as num],
    ];
    return out.isEmpty ? fallback : out;
  }

  /// The Score-to-Top% table in force (`rules.exam.gradExam.topTable`, else
  /// the fitted default).
  List<List<num>> get examTopTable =>
      _table('topTable', GraduationExam.topTable);

  /// A subject's announced Score (0-100). FITTED: stat -> base Score curve
  /// plus a seeded variation (see [GraduationExam]). Stable for a given run
  /// and stats; once the card was taken the recorded value is returned.
  int examScoreFor(String subject) {
    final recorded = state.examCardScores[subject];
    if (recorded != null) return recorded;
    final spread = _gradExamRules['variation'];
    return GraduationExam.score(
      state.stats[subject] ?? 0,
      _examSeed(subject),
      curve: _table('scoreCurve', GraduationExam.scoreCurve),
      spread: spread is num ? spread.toDouble() : GraduationExam.variation,
    );
  }

  /// Takes the next exam card: records that subject's exam, advances the
  /// clock ONE tick and returns the response line. Null when no card is
  /// pending. Each subject can be taken once, in order; calling again after
  /// a resume continues at the first untaken card, never repeating one.
  ExamTurn? takeExamSubject() {
    if (!examCardsPending) return null;
    final card = currentExamCard;
    if (card == null) return null;
    final score = examScoreFor(card.subject);
    final confident = _gradExamRules['confidentScore'];
    final responses = _gradExamRules['responses'];
    final high = confident is num
        ? confident.toInt()
        : GraduationExam.confidentScore;
    final line = score >= high
        ? ((responses is Map ? responses['confident'] : null) as String? ??
              "That wasn't so bad...")
        : ((responses is Map ? responses['unsure'] : null) as String? ??
              "I'm not so sure about this...");
    state.examCardsDone.add(card.subject);
    state.examCardScores[card.subject] = score;
    state.examResponses[card.subject] = line;
    // One tick per card, never rolling past the day's last slot.
    final last = pack.manifest.ticksPerDay - 1;
    state.date = GameDate(state.date.day, (state.date.tick + 1).clamp(0, last));
    state.note('Exam: ${card.label}.', 'system');
    return ExamTurn(
      subject: card.subject,
      label: card.label,
      response: line,
      score: score,
      date: state.date,
    );
  }

  /// Takes every remaining card (headless runs and the legacy screen).
  void completeExamCards() {
    while (takeExamSubject() != null) {}
  }

  /// The one-line scene a tapped exam card plays: [ExamTurn.response] as a
  /// normal dialogue message from the player, over the current location (the
  /// existing event presentation). It is presentation only: it has no graph,
  /// no effects and touches no counters, so showing it twice changes nothing.
  EventRun examResponseEvent(ExamTurn turn) {
    final node = EventNode(
      id: -1,
      boxId: -1,
      type: 'last',
      text: turn.response,
      elseText: null,
      optionText: null,
      nextNodeId: null,
      nextNodeIdIfTrue: null,
      nextNodeIdIfFalse: null,
      options: const [],
      speakerId: 0,
      isHideSpeakerName: false,
      backgroundImg: null,
      imgPath: null,
      changer: null,
      actionChanger: null,
      conditionSet: null,
      eventSound: null,
    );
    final run = EventRun(
      event: GameEvent(
        id: -91001,
        name: 'Graduation Exam',
        rootNodeId: -1,
        priority: 'middle',
        rank: 'C',
        section: 'none',
        eventSetId: null,
        isRandomDate: false,
        isFake: true,
        conditionSet: null,
      ),
      pack: pack,
      state: state,
      effects: effects,
      conditions: conditions,
    );
    run.current = EventBeat(
      node: node,
      text: turn.response,
      speakerName: 'Me',
      backgroundImg: null,
      choices: const [],
      isEnd: true,
    );
    return run;
  }

  // --- score announcement --------------------------------------------------

  /// The scores the announcement and score card print: per subject a Score
  /// and Top %. Computed once (after the cards) and saved with the run.
  CsatResult get scoreCard => takeCsat();

  /// The announcement's Next / Turn in Papers was confirmed: the flow moves
  /// on to drafting. Idempotent.
  void confirmScoreAnnouncement() {
    scoreCard;
    state.scoreAnnounced = true;
  }

  // --- stage ---------------------------------------------------------------

  /// Where the flow stands. Derived from saved state.
  DDayStage get ddayStage {
    if (state.finished) return DDayStage.ending;
    if (state.finalDecided) return DDayStage.ending;
    if (!state.csatPending) return DDayStage.none;
    if (!examCardsComplete) return DDayStage.examCards;
    if (!state.scoreAnnounced) return DDayStage.scoreAnnouncement;
    if (!state.applicationsCommitted) {
      return state.resultsReviewed
          ? DDayStage.finalDecision
          : DDayStage.drafting;
    }
    return state.resultsReviewed ? DDayStage.finalDecision : DDayStage.results;
  }

  // --- catalog queries -----------------------------------------------------

  /// A department the student may apply to in this story: its university is
  /// available here (Retry Universities are not in story 16), it is not the
  /// Retry Academy, and the items it needs are in the bag. (RECOVERED:
  /// handoff section 5 availability overlay; items from the catalog.)
  bool isEligible(Department department) {
    final university = pack.admissions.universities[department.universityId];
    return university != null &&
        university.available &&
        university.category != UniversityCategory.retake &&
        canApply(department);
  }

  /// Every eligible department, hardest cutoff first.
  List<Department> eligibleDepartments({UniversityCategory? category}) => [
    for (final d in departmentsByCutoff())
      if (isEligible(d) &&
          (category == null ||
              pack.admissions.universities[d.universityId]?.category ==
                  category))
        d,
  ];

  /// The integer acceptance rate shown on cards, the tray and the Apply?
  /// modal: [admissionChance] as a whole percent. The roll uses this value.
  int displayedRate(Department department) =>
      (admissionChance(department) * 100).round().clamp(0, 100);

  /// Recommended Majors: eligible departments whose displayed rate is within
  /// [minRate]..[maxRate], best odds first (ties: harder cutoff first).
  /// [hideApplied] drops every department of a drafted university.
  List<Department> recommendedDepartments({
    int minRate = 0,
    int maxRate = 100,
    bool hideApplied = true,
  }) {
    final rows = <(Department, int)>[
      for (final d in eligibleDepartments())
        if (!(hideApplied && isHiddenByApplied(d)))
          if (displayedRate(d) case final r when r >= minRate && r <= maxRate)
            (d, r),
    ];
    rows.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : b.$1.deviation.compareTo(a.$1.deviation);
    });
    return [for (final r in rows) r.$1];
  }

  /// Search Majors: eligible departments whose NAME contains [query]
  /// (case-insensitive substring, live as typed; RECOVERED for "com" ->
  /// "Telecommunication"). Whether school names also match is unknown, so
  /// they do not. A blank query lists everything.
  List<Department> searchMajors(String query, {bool hideApplied = true}) {
    final q = query.trim().toLowerCase();
    return [
      for (final d in eligibleDepartments())
        if (!(hideApplied && isHiddenByApplied(d)) &&
            (q.isEmpty || d.name.toLowerCase().contains(q)))
          d,
    ];
  }

  // --- draft candidates ----------------------------------------------------

  void _ensureDraft() {
    final n = applicationLimit;
    while (state.draft.length < n) {
      state.draft.add(null);
    }
  }

  /// The candidate slots, left to right; null is empty. Lives in the run
  /// (survives tab changes, modals, resume) until [submitDraft].
  List<int?> get draftSlots {
    _ensureDraft();
    return List.unmodifiable(state.draft);
  }

  /// The drafted departments in slot order (empty slots skipped).
  List<Department> get draftDepartments => [
    for (final id in draftSlots)
      if (id != null && pack.admissions.departments[id] != null)
        pack.admissions.departments[id]!,
  ];

  /// Whether [universityId] already has a candidate. With the Hide Applied
  /// Universities switch on, all of that school's majors are hidden
  /// (RECOVERED, handoff section 8).
  bool isUniversityDrafted(int universityId) =>
      draftDepartments.any((d) => d.universityId == universityId);

  bool isHiddenByApplied(Department department) =>
      isUniversityDrafted(department.universityId);

  /// Why [department] cannot be added right now, or null when it can.
  /// "One application per university" is the engine's standing rule
  /// (RECONSTRUCTED for the UI: the recording never tests it).
  String? draftProblem(Department department) {
    if (state.applicationsCommitted) return 'Applications are already sent.';
    final university = pack.admissions.universities[department.universityId];
    if (university == null) return 'Unknown university.';
    if (university.category == UniversityCategory.retake) {
      return 'Not an application.';
    }
    if (!university.available) {
      return 'Available for admission in another story.';
    }
    if (!canApply(department)) return department.condition ?? 'Not eligible';
    final drafted = state.draft.whereType<int>();
    if (drafted.contains(department.id)) return 'Already a candidate.';
    if (sameSchoolChosen(department, drafted)) {
      return 'Already applying to this school.';
    }
    _ensureDraft();
    if (!state.draft.contains(null)) return 'All candidate slots are filled.';
    return null;
  }

  /// Puts [departmentId] in the first empty slot (or in [slot] if empty).
  /// Returns the slot used, or null if refused (see [draftProblem]).
  int? addToDraft(int departmentId, {int? slot}) {
    final department = pack.admissions.departments[departmentId];
    if (department == null || draftProblem(department) != null) return null;
    final target = slot ?? state.draft.indexOf(null);
    if (target < 0 ||
        target >= state.draft.length ||
        state.draft[target] != null) {
      return null;
    }
    state.draft[target] = departmentId;
    return target;
  }

  /// Empties [slot] (tapping an occupied slot). False if nothing was there
  /// or the draft is already committed.
  bool removeFromDraft(int slot) {
    _ensureDraft();
    if (state.applicationsCommitted ||
        slot < 0 ||
        slot >= state.draft.length ||
        state.draft[slot] == null) {
      return false;
    }
    state.draft[slot] = null;
    return true;
  }

  void clearDraft() {
    if (state.applicationsCommitted) return;
    state.draft.clear();
    _ensureDraft();
  }

  /// Auto Input. Fills ONLY the empty slots, left to right, and never
  /// touches an occupied slot. Returns the slots it filled.
  ///
  /// RECONSTRUCTED rule (the recording shows only that slot 1 survived and
  /// that 9% and 10% majors from unrelated schools were added, outside the
  /// slider range): each empty slot takes the eligible department with the
  /// best displayed rate among those between [autoFillMinRate] and
  /// [autoFillMaxRate] (so neither hopeless nor a sure thing), from a
  /// university not already drafted. If that band is empty it relaxes to any
  /// rate of at least 1, then to anything eligible. Deterministic.
  List<int> autoFill({int autoFillMinRate = 5, int autoFillMaxRate = 90}) {
    if (state.applicationsCommitted) return const [];
    _ensureDraft();
    final filled = <int>[];
    final pool = eligibleDepartments();
    for (var slot = 0; slot < state.draft.length; slot++) {
      if (state.draft[slot] != null) continue;
      Department? pick;
      var pickRate = -1;
      for (final band in [
        (autoFillMinRate, autoFillMaxRate),
        (1, 100),
        (0, 100),
      ]) {
        for (final d in pool) {
          if (draftProblem(d) != null) continue;
          final r = displayedRate(d);
          if (r < band.$1 || r > band.$2) continue;
          if (r > pickRate) {
            pick = d;
            pickRate = r;
          }
        }
        if (pick != null) break;
      }
      if (pick == null) break;
      state.draft[slot] = pick.id;
      filled.add(slot);
    }
    return filled;
  }

  // --- arithmetic ----------------------------------------------------------

  /// 100 * product(1 - displayedRate / 100): the Apply? modal's "Chances of
  /// total rejection" (RECOVERED: 23/20/35 -> 40.04, 23/9/10 -> 63.063).
  double totalRejectionChance(List<Department> departments) =>
      Admissions.totalRejectionPercent(departments.map(displayedRate));

  /// [totalRejectionChance] as the modal prints it, without forced
  /// decimals ("40.04", "63.063").
  String totalRejectionText(List<Department> departments) =>
      Admissions.formatPercent(totalRejectionChance(departments));

  // --- commit --------------------------------------------------------------

  /// Commits the draft (1..3 candidates). Rolls each in submission (slot)
  /// order with its displayed rate, stores the verdicts and returns them.
  /// Idempotent: the second call (or a call after a save/load) returns the
  /// stored results without rolling. An empty draft commits nothing and
  /// returns an empty list.
  List<ApplicationResult> submitDraft() {
    if (state.applicationsCommitted) return applicationResults;
    _ensureDraft();
    final ids = state.draft.whereType<int>().toList();
    if (ids.isEmpty) return const [];
    takeCsat();
    for (final id in ids) {
      final department = pack.admissions.departments[id];
      if (department == null) continue;
      final rate = displayedRate(department);
      state.applications.add(id);
      state.applicationRates.add(rate);
      // Uniform 0..99 against the displayed rate: 0 never, 100 always.
      if (state.random.nextInt(100) < rate) {
        state.admittedDepartments.add(id);
      }
    }
    state.applicationsCommitted = true;
    state.note(
      'Applied to ${state.applications.length}; '
          '${state.admittedDepartments.length} accepted.',
      'system',
    );
    return applicationResults;
  }

  /// The committed verdicts in submission order (empty before the commit).
  List<ApplicationResult> get applicationResults => [
    for (var i = 0; i < state.applications.length; i++)
      if (pack.admissions.departments[state.applications[i]] case final d?)
        ApplicationResult(
          department: d,
          university: pack.admissions.universities[d.universityId],
          rate: i < state.applicationRates.length
              ? state.applicationRates[i]
              : displayedRate(d),
          accepted: state.admittedDepartments.contains(d.id),
          enrolled: state.enrolledDepartment == d.id,
        ),
  ];

  /// The accepted programs (0..3), in submission order.
  List<ApplicationResult> get acceptedPrograms => [
    for (final r in applicationResults)
      if (r.accepted) r,
  ];

  /// The results animation / combined list was confirmed. Idempotent.
  void confirmResults() {
    state.resultsReviewed = true;
    state.resultsRevealed = state.applications.length;
  }

  /// How many envelope results the player has opened and confirmed (saved).
  /// All of them once [confirmResults] ran.
  int get resultsRevealed => state.resultsReviewed
      ? state.applications.length
      : state.resultsRevealed.clamp(0, state.applications.length);

  /// The player confirmed the next envelope's result card. Advances by one,
  /// never past the number of applications; the UI calls it once per
  /// Confirm. Returns the new count.
  int confirmNextResult() {
    if (state.resultsReviewed) return resultsRevealed;
    if (state.resultsRevealed < state.applications.length) {
      state.resultsRevealed++;
    }
    return state.resultsRevealed;
  }

  // --- final decision ------------------------------------------------------

  /// The Korea Retry Academy card: the catalog's university 0 and its
  /// Comprehensive Retake Course (department 0).
  FinalOption get retakeOption {
    final university = pack.admissions.universities[0];
    final department =
        pack.admissions.departments[0] ??
        const Department(
          id: 0,
          universityId: 0,
          name: 'Comprehensive Retake Course',
          deviation: 25.3,
        );
    return FinalOption(
      department: department,
      university: university,
      isRetake: true,
    );
  }

  /// The Final Decision cards: each accepted program, or, when every
  /// application was rejected (or none sent), the retake academy.
  List<FinalOption> get finalDecisionOptions {
    final accepted = acceptedPrograms;
    if (accepted.isEmpty) return [retakeOption];
    return [
      for (final r in accepted)
        FinalOption(
          department: r.department,
          university: r.university,
          isRetake: false,
        ),
    ];
  }

  /// Takes the retake academy. Only when nothing accepted the student.
  /// Returns false (no change) if there are acceptances or the decision was
  /// already made. Enrollment -- `enroll(departmentId)` -- is the same
  /// commit for an accepted program.
  bool enrollRetake() {
    if (acceptedPrograms.isNotEmpty) return false;
    return enroll(null);
  }
}
