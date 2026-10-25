# D-Day flow: engine API (2026-10-25)

The engine/data layer for the recreated exam -> applications -> results flow.
Screens are built on this API; none of them rolls dice or keeps flow state of
its own. Evidence: `screenshots/dday-applications-2026-10-25/HANDOFF.md` and
`observations.json`. Implementation: `lib/engine/dday.dart` (an extension on
`Game`, re-exported by `game.dart`), `lib/engine/admissions.dart` (models,
fitted exam model, arithmetic), `lib/engine/state.dart` (saved fields),
`lib/engine/account_store.dart` (local counts, ending reward),
`tools/build_pack.py` (catalog). Tests: `test/dday_flow_test.dart`.

Labels: **RECOVERED** = visible in the recording or in shipped data.
**FITTED** = a model calibrated to recorded outputs. **RECONSTRUCTED** = a
rule chosen here because the evidence does not show it.

## Lifecycle order

1. **Graduation Exam event** (authored, unchanged in both campaigns). Its last
   node runs `START_SAT`, which sets `state.csatPending`. `Game.beginDay()`
   still starts it on exam day.
2. **Exam cards**: `game.examCardsPending` is true. The hand area shows
   `game.currentExamCard`, one at a time, Korean -> Maths -> English -> Science
   -> Humanities (the pack's subject order; labels from
   `rules.exam.subjectLabels`). Each tap calls `game.takeExamSubject()`.
3. **Score announcement**: `game.scoreCard` (a `CsatResult`; per subject
   `examScores[s]` int 0-100 and `topPercents[s]` one decimal). The staggered
   reveal is a UI concern. `game.confirmScoreAnnouncement()` on Next / Turn in
   Papers.
4. **Draft** (Submit route): `draftSlots`, `addToDraft`, `removeFromDraft`,
   `autoFill`, `recommendedDepartments`, `searchMajors`, `displayedRate`,
   `totalRejectionText`. Nothing is committed.
5. **Submit**: `game.submitDraft()` after the Apply? modal's Confirm.
6. **Results**: `game.applicationResults` (ordered). The envelopes animate over
   stored verdicts. `game.confirmResults()` after the combined results Confirm.
7. **Final decision**: `game.finalDecisionOptions`, then
   `game.enroll(departmentId)` or `game.enrollRetake()` after the Confirm
   Enrollment modal.
8. **Ending events**: unchanged. `GameScreen._sitCsat` loops
   `game.nextEndingEvent()` (the authored Retry/Retake Ending dialogue and any
   ending scenes), then `game.concludeRun()`.
9. **Completion summary**: from the stored run (`state.csat`, `state.stats`,
   `applicationResults`); `_closeRun` writes the History record
   (`RecordStore.add`) and `AccountStore.current.recordRun(record, catalog)`.
10. **Reward**: `recordRun` grants one Standard Trait Pack and sets
    `Account.pendingEndingReward`. Show "Ending Reward Obtained!" after
    Back to Main Menu; on Confirm call
    `AccountStore.current.acknowledgeEndingReward()` then `AccountStore.save()`.

`game.ddayStage` (`DDayStage`) derives the current step from saved state, so a
screen can resume anywhere: `none`, `examCards`, `scoreAnnouncement`,
`drafting`, `results`, `finalDecision`, `ending`.

## Exam cards

```dart
bool            game.examCardsPending      // csatPending && cards remain
List<ExamCard>  game.examCards             // subject, label, done, response
ExamCard?       game.currentExamCard
bool            game.examCardsComplete
ExamTurn?       game.takeExamSubject()     // null when nothing is pending
void            game.completeExamCards()   // headless / legacy screen
String          game.subjectLabel(subject)
```

* `takeExamSubject()` records the subject's exam, advances the clock exactly
  one tick (never past the day's last slot) and returns `ExamTurn`
  (`response`, `score`, `date`). The first untaken card is always next, so a
  resumed run never repeats a step.
* Response line: **RECOVERED** strings "I'm not so sure about this..." /
  "That wasn't so bad..."; **RECONSTRUCTED** choice: Score >= 60 is the second
  (recording: 58/59/50/53 unsure, 66 fine). Tunable in
  `rules.exam.gradExam.confidentScore` / `responses`.
* Both campaigns: the elective slots are Science and Humanities (`society`).
  The exam cards are inserted after the authored Graduation Exam event; that
  event is untouched.
* State: `state.examCardsDone`, `examCardScores`, `examResponses`, all saved.
  Old saves infer "cards done" from an existing score card.

## Exam scoring (FITTED)

`GraduationExam` in `admissions.dart`. Per subject: stat -> base Score by a
piecewise-linear curve (1253 -> 50, 1630 -> 53, 2181 -> 58, 3476 -> 66, rising
to 100), plus a seeded variation of +-1.0 point (the recording is not monotonic:
2205 -> 58 but 2158 -> 59). The seed is a stable hash of name, pack id and
subject, so the same run always gets the same number; the value is also stored
when the card is taken (`examCardScores`) and in `state.csat.examScores`.
Top % is a piecewise-linear table through the five recorded
(Score, Top %) pairs (58 -> 47.7, 59 -> 46.1, 50 -> 58.6, 53 -> 55.0,
66 -> 35.8) following a normal curve elsewhere (mean 56.5, sd 26.2); it is
monotone in Score. Any seed lands within 2 points of every recorded Score
(tested). Override with `rules.exam.gradExam.{scoreCurve,topTable,variation}`.

The older admission model (`standardScore`, `subjectScores`, `grades`) is
unchanged and still drives acceptance rates. The two are separate: the printed
Score/Top % do not feed the odds.

## Catalog (RECOVERED data)

`colleges.json` now carries all 137 universities for both campaigns. Each has
`category` (`UniversityCategory`: korea 51, special 5, global 10, taiwan 70,
retake 1 -> from the original `type`), `rank`, `stars` (rank/2: ten = 5.0,
nine = 4.5 ... one = 0.5), `colorCode`, `crest` (path under images; id 0 is an
`.svg`), `available`, `availableStories`. Global/Taiwan names come from
`content/kss/university-names.json` via `tools/university_names.py`.

* Departments exist for every university reachable in the story (about 3,340
  per pack) with the original id and `deviation`. IDs are unchanged.
* Story-only schools stay in the catalog with `available: false` when the
  story may not apply (Retry Universities in 31-Day Mode; Basakan in Retry
  Year). They have no departments there and cannot be drafted; a screen shows
  them darkened with "Available for admission in ..." from `availableStories`.
* The Retry Academy (id 0, category retake) is never an application; it is the
  Final Decision card (`game.retakeOption`).
* `University.storyOnly` keeps its older meaning "outside the regular Korean
  set" (true for special/global/taiwan/retake). The US set
  (`colleges_us.json`) still renames only the regular Korean universities.
* Helpers: `catalog.inCategory(cat)` (stars desc), `catalog.departmentsOf(id)`.

## Acceptance rates and arithmetic

```dart
int    game.displayedRate(Department)               // 0..100, the shown rate
double game.totalRejectionChance(List<Department>)  // 100*prod(1 - rate/100)
String game.totalRejectionText(List<Department>)    // "40.04", "63.063"
Admissions.totalRejectionPercent(Iterable<int> rates) / formatPercent(double)
```

`displayedRate` is `admissionChance` (the existing fitted model) rounded. The
roll uses the same integer (`nextInt(100) < rate`: 0 never accepts, 100 always
does). **RECOVERED**: 23/20/35 -> 40.04 and 23/9/10 -> 63.063; the formatter
drops trailing zeros (it is not fixed at two decimals).

## Draft candidates

```dart
List<int?>        game.draftSlots            // 3 slots, null = empty
List<Department> game.draftDepartments
int?  game.addToDraft(id, {slot})            // slot used, or null if refused
bool  game.removeFromDraft(slot)
void  game.clearDraft()
List<int> game.autoFill({autoFillMinRate: 5, autoFillMaxRate: 90})  // slots filled
String? game.draftProblem(Department)        // why it cannot be added
bool  game.isUniversityDrafted(universityId)
bool  game.isHiddenByApplied(Department)     // Hide Applied Universities
bool  game.isEligible(Department)
List<Department> game.eligibleDepartments({category})
List<Department> game.recommendedDepartments({minRate, maxRate, hideApplied})
List<Department> game.searchMajors(query, {hideApplied})
```

* The draft is `state.draft`, separate from committed `state.applications`; it
  survives tabs, modals, backgrounding and save/load.
* Eligibility (**RECOVERED** availability): university `available` for this
  story, not the Retry Academy, items the department needs are in the bag.
* One candidate per university is refused (the engine's standing rule;
  **RECONSTRUCTED** for the UI, the recording does not test it). Hide Applied
  hides every major of a drafted school (**RECOVERED**).
* `autoFill` fills ONLY empty slots, left to right, and never alters an
  occupied slot (**RECOVERED**: slot 1 survived). **RECONSTRUCTED** choice:
  each slot takes the best displayed rate within 5..90 from a university not
  already drafted; if that band is empty it relaxes to rate >= 1, then to any
  eligible department. Deterministic. It is not constrained by the slider (the
  recording added 9% and 10% majors outside 20-80).
* `searchMajors`: case-insensitive substring over department names only
  (**RECOVERED** for "com" -> Telecommunication; school-name matching is
  unknown so it is not done).
* Sort options, the slider default (43-80 was just the recorded setting),
  duplicate-major policy and the zero-chance Apply behavior are unknown; zero
  rate majors are listed and addable.

## Commit

```dart
List<ApplicationResult> game.submitDraft()   // 1..3 candidates, once
List<ApplicationResult> game.applicationResults   // ordered
List<ApplicationResult> game.acceptedPrograms
void game.confirmResults()
```

`submitDraft()` rolls each candidate in slot order against its displayed rate
with the run RNG, stores `applications`, `applicationRates` (the rate used),
`admittedDepartments` and `applicationsCommitted`, then returns the verdicts
(`department`, `university`, `rate`, `accepted`, `enrolled`). It is idempotent:
later calls, and calls after save/load, return the stored results and never
roll again. An empty draft commits nothing. After the commit the draft is
frozen. `submitApplications(ids)` is the older headless entry (fills the draft,
then commits). `FUNC_GET_SUCCESS_LENGTH` still reads `admittedDepartments`.

## Final decision and enrollment

```dart
List<FinalOption> game.finalDecisionOptions  // accepted programs, or [retake]
FinalOption       game.retakeOption          // Korea Retry Academy / Comprehensive Retake Course
bool game.enroll(int? departmentId)          // accepted id; null = retake
bool game.enrollRetake()                     // only when nothing accepted
```

Supports 0..3 acceptances. `enroll` returns false and changes nothing for an
unaccepted id or after the decision was made (idempotent). On success it sets
`enrolledDepartment` (null for a retake), `finalDecided`, clears `csatPending`
and sets `ENDING_CODE = 1`, exactly what the previous `enroll` did, so the
endings, `concludeRun`, `RecordStore.add` and `Account.recordRun` behave as
before. The existing retake path in both campaigns (`enroll(null)` -> ending
events -> `concludeRun` -> "Retake the year") is unchanged. The retake is not
counted as a university enrollment and pays no first-enrollment cookies; a
real enrollment still pays the existing two cookies once per school
(`Account.recordRun`), and nothing here pays them again.

## Local counts (no online service)

The recording's online counts become this account's own:

* `Account.universityEnrollees(universityId)` -> "enrollees : n" (existing
  `enrollments` counter).
* `Account.majorEnrollments(departmentId)` -> "# Enrollments" (new
  `departmentEnrollments`, incremented in `recordRun`; runs finished before
  this field existed are not backfilled).
* `Account.countByDepartment(records)` recounts from History records.

No global rank lines or "Ranked Nth globally" text; Loading placeholders are
unnecessary because the numbers are local and synchronous.

## Ending reward

`Account.recordRun` grants one Standard Trait Pack per completed run, once
(keyed by record id and finish time in `endingRewardsPaid`), and sets
`Account.pendingEndingReward` (`packId`, `count`). The packs are already in
`Account.packs['standard']`; the pending record only drives the dialog and
persists until `acknowledgeEndingReward()`. **RECONSTRUCTED**: the recording
shows 2 packs with "X2 Reward Pack active"; the base of 1 is inferred, and this
build has no purchase that could double it. Constants:
`endingRewardPackId`, `endingRewardPacks` in `account_store.dart`.

## Save and resume guarantees

* Saved in the run: `examCardsDone`, `examCardScores`, `examResponses`,
  `scoreAnnounced`, `draft`, `applications`, `applicationRates`,
  `admittedDepartments`, `applicationsCommitted`, `resultsReviewed`,
  `finalDecided`, `enrolledDepartment`, `csat` (with `examScores`,
  `topPercents`). Saves from before the flow infer their stage from what exists
  (a score card means cards done and announced; applications mean committed and
  reviewed), so nothing is replayed backwards.
* Nothing is rerolled: exam Scores are seeded and stored; admission verdicts
  are rolled once at `submitDraft()` and stored; rebuilding, rotating,
  resuming or replaying an animation reads stored values.
* Idempotent: `takeExamSubject` (each subject once), `confirm*`, `submitDraft`,
  `enroll`/`enrollRetake`, and the account reward.
* Save slots: GameScreen only auto-saves between days. A save taken
  mid-exam-day is the screen's responsibility; the state above is complete for
  it, and `GameScreen.initState` already resumes `csatPending` runs through the
  CSAT screen.

## UI integration notes

* `CsatScreen` is a plain functional screen over this API (it takes any
  remaining exam cards itself via `completeExamCards()`). The recreated
  screens replace it: render `examCards` in the hand area of `GameScreen` when
  `examCardsPending`, then the announcement, Submit route, envelopes, Final
  Decision and certificate from the methods above.
* `_sitCsat` in `game_screen.dart` still runs the ending loop after the
  decision; keep it.
* Rejection and enrollment animations must finish before the next
  state-changing call (`confirmResults`, `enroll`); the engine does not time
  anything.

## Not covered

Sort options, school pages (tapping a school), tray expansion, successful-offer
card art and animation, certificate Student ID number, photo upload/share, and
the Collection mode label mismatch are UI or unsourced and untouched here.
