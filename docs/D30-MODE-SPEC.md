# Korean Student Simulator — 31-Day Mode (story 16): engine pseudocode + content spec

**Audience:** a developer who has never seen this game and has to rebuild its
31-day mode on a deadline.

**Scope, deliberately narrow:**

- **Content comes only from the English build's own story-16 campaign** —
  `com.basakansoft.koreanstudentsimulator` 1.27.4, `assets/assets/stories/16/`.
  No other campaign (3, 14, 18, 20, 68) and none of the Korean build's later
  story-16 content. Where the Korean build is a superset, §13 says so in one
  place and nowhere else.
- **Engine behaviour comes from the compiled Dart**, presented as pseudocode.
  Every block below is labelled `RECOVERED` (lifted from decompiler output,
  verbatim or lightly abridged) or `RECONSTRUCTED` (written by me from named
  evidence — implement this one).

---

## 0. Provenance, and how to read the pseudocode

| Artefact | What it is | Path |
|---|---|---|
| **EN campaign data** | story 16, English, 2.88 MB of events | `kss/assetpack1_dec/assets/assets/stories/16/` |
| **EN global catalogs** | traits, books, items, universities, endings, characters, equipment | `kss/assetpack1_dec/assets/assets/global_data/` |
| **EN native** | `libapp.so`, 13,960,112 B, Dart AOT, arm64 | `kss/arm64_dec/lib/arm64-v8a/libapp.so` |
| **Pseudocode** | AOTopsy `export-dart`, 486,928 lines, 21,095 methods | `korstu4CLAUDE/private-build/korean-base/analysis/decompiled/` |
| **Object pool** | blutter string/object dump | `.../analysis/pp.txt`, `objs.txt` |
| **String xrefs** | string → referencing function + pc | `.../analysis/aotopsy/string_refs.jsonl` |
| **EN UI strings** | 22,824 extracted strings | `korstu4/app-strings.txt` |
| **Existing rebuild** | a working Flutter implementation of ~70% of this | `d30mode/lib/engine/`, `packs/kss16/` |

### One caveat you must know before trusting a `RECOVERED` block

The stored pseudocode was generated from the **Korean 1.61.0 native** (Dart
3.11.0), not from the English 1.27.4 one. No pseudocode was ever generated for
the English binary and the AOTopsy tool is not kept in this workspace, so I
could not regenerate it.

I therefore verified, by extracting and comparing identifier sets from the
English `libapp.so` directly, that the two binaries are the same engine:

| Probe | English 1.27.4 native | Korean 1.61.0 native |
|---|---|---|
| Game class/method names in the string pool | `TimeManager.endToday`, `TimeManager.nextTime`, `MainViewController.onClickTodayFinishToTodayStart`, `DBHelper.getDataWhenSignIn` | identical set |
| `FUNC_*` predicates | **81** | 88 |
| Changer verbs | superset of the 27 the EN campaign uses | 178 registered |
| Block-type tokens | `STUDY_BLOCK SLEEP_BLOCK EXERCISE_BLOCK PART_TIME_JOB_BLOCK SPECIAL_BLOCK EVENT_BLOCK GO_BLOCK NA_BLOCK SCHOOL_STUDY_BLOCK SCHOOL_EXAM_BLOCK MOCK_EXAM_BLOCK GAME_BLOCK IDOL_BLOCK …` | identical |
| Engine pseudo-switches | `DATE_PROGRESS DATE_DAY DATE_MONTH DATE_WEEK DATE_INT TICK LOCATION_ID LOCATION_TYPE COMBO_STUDY PREV_STUDY_SUBJECT PREV_BLOCK_TYPE TIME_TO_MOVE_LOCATION IS_BEFORE_SAT_EXAM WEEKCODE` | identical |
| Per-run save keys | `_studyCountList _sleepCountList _exerciseCountList _partTimeJobCountList _schoolStudyCountList _specialCountList _locationCountList _suddenMissionCountList _goalSuccessList _examKoreanStatList _examEnglishStatList _examMathStatList _examTamgoo1StatList _examTamgoo2StatList _endingCode _badgeIdList _firstTraitList _rerollCount …` | identical |

The English native additionally has `FUNC_GET_CURRENT_EXAM_VIEW_PERCENTAGE`,
`VIEW_PERCENT` and `SHOW_SUDDEN_MISSION`, which the Korean 1.61 one dropped or
renamed. So: the pseudocode is from the sibling build, the architecture is
confirmed shared, and anything version-specific is called out where it matters.

### Reading conventions

Recovered pseudocode is obfuscated. `sub_xxxxxx` / `stub_xxxxxx` are unnamed
functions, `local_mN` are stack slots, `fNN` are object field offsets, `stub()`
is an unresolved dispatch, `unresolved_Closure` is a closure the decompiler
could not link to its body. String literals survive because they are data,
which is why the registries below are fully readable even though nothing around
them is.

Note also that only ~2,600 of the binary's 46,370 functions were exported with
bodies. The gameplay core lives in unnamed `stub_*` functions that got no body,
which is why some sections below are reconstruction rather than recovery — and
why I say which is which.

---

## 1. What this mode is, and where it sits

The game is a shell that plays **stories**. `global_data/stories.json` tags each
with a `gameMode`. The English build ships six:

| id | `name` | `originName` | `gameMode` | span | role |
|---|---|---|---|---|---|
| 14 | Tutorial | 튜토리얼 | `tutorial` | 5 d | onboarding |
| 3 | Amnesia | 기억상실증 | *(null)* | 101 d | the D-100 campaign |
| **16** | **31-Day Mode** | **한 달 모드** | **`extra`** | **32 d** | **this document** |
| 18 | Endless Winter | 끝나지 않는 겨울 | `extra` | 31 d | out of scope |
| 20 | The Year I Retook | 나의 재수 이야기 | `extra` | 32 d | out of scope |
| 68 | 在無人島上學習 | 무인도에서 공부하기 | `extra` | 32 d | out of scope |

`gameMode: "extra"` **is** the 31-day family. The Select Mode screen has no
campaign list — it has three fixed buttons (Tutorial → 14, **One Month Mode
(D-31)** → 16, Campaign (D-100) → 3) and an Expansion carousel for the rest.

The engine also carries a closed `extraType` enum, recovered from the Korean
disassembly at `0x5bf348`, mapping enum index → story id:

```asm
005bf36c  mov x1, #0x10   ; index 0 -> story 16   extraType "base"
005bf374  mov x1, #0x12   ; index 1 -> story 18   "eternalWinter"
005bf384  mov x1, #0x14   ; index 2 -> story 20   "myJaesooStory"
005bf38c  mov x1, #0x44   ; index 3 -> story 68   "island"
```

**Story 16 is `extraType: "base"`** — the plain variant, with no per-story
compiled subsystem. That is exactly why it is the right rebuild target.

### The story-16 manifest entry, verbatim from the English catalog

```json
{ "id": 16, "name": "31-Day Mode", "originName": "한 달 모드",
  "description": "See how far you can go!",
  "gameMode": "extra", "isDefault": true, "isShow": true,
  "isChallengeEnding": null,
  "startDate": { "dateCode": "DATE_2023101600" },
  "endDate":   { "dateCode": "DATE_2023111600" },
  "birthDate": { "dateCode": "DATE_2005071800" },
  "eventStartDate": null,
  "startLocationId": 1000,
  "maleFirstName": "Basakan",   "maleLastName": "Kim",
  "femaleFirstName": "Basakan", "femaleLastName": "Kim",
  "recentHistoryPlusStatDefault": 600,
  "startBgmId": "assets/audio/bgm/16/start.mp3",
  "paymentDate": null, "extraDescriptionList": [], "generatorVersion": 1,
  "password": "9e5ebb2c9eb2284e8095f0f74bf917c32d065d8148d08ee44889cd80c7907599" }
```

Derived: start **Monday 16 Oct 2023**, end **Thu 16 Nov 2023** (the real CSAT
date), **31 playable days**, day 32 is the exam and is terminal. 15 ticks per day
(proved in §2.1) → **465 action slots**. No `paymentDate`, so no trial gate.
`recentHistoryPlusStatDefault: 600` seeds the "recent history" stat bonus.

---

## 2. Engine architecture, recovered

### 2.1 The calendar: `DATE_YYYYMMDDTT`

The English native contains the literal regex **`DATE_[0-9]+`** and the sentinel
**`DATE_9999999999`** (ten digits → `YYYYMMDDTT`), plus a hardcoded
`DATE_2023111600` — story 16's exam day, baked into the binary.

`TT` is a **tick**, not an hour. Three independent proofs:

1. The engine switch `DATE_PROGRESS` is compared against 0–14 and never higher.
2. Story 16's 21 date conditions use suffixes `00 03 06 07 08 09 14` only.
3. `TICK` and `tickUpper` are engine state, and `TICK >= 10` is used as a trait
   gate described as "the last five ticks" — only consistent with a 15-tick day.

```dart
// RECONSTRUCTED — the calendar primitive
class GameDate {
  final DateTime day;   // Y/M/D
  final int tick;       // 0 .. ticksPerDay-1   (15 for story 16)

  static final _re = RegExp(r'^DATE_(\d{4})(\d{2})(\d{2})(\d{2})$');

  static GameDate? tryParse(String code) {            // malformed -> null, so a
    final m = _re.firstMatch(code);                   // bad pack degrades to
    if (m == null) return null;                       // "never matches"
    return GameDate(DateTime(int.parse(m[1]!), int.parse(m[2]!),
                             int.parse(m[3]!)), int.parse(m[4]!));
  }

  String get code    => 'DATE_$y4$m2$d2$t2';
  int    get asInt   => year*1000000 + month*10000 + day*100 + tick;  // DATE_INT
  bool   get isWeekend => weekday == sat || weekday == sun;

  GameDate advance(int n, int ticksPerDay) { /* carry into the next day */ }
  GameDate nextDay() => GameDate(day + 1.day, 0);
}

const NEVER = 'DATE_9999999999';   // the engine's "no such date" sentinel
```

### 2.2 The classes whose real names survived

Only four game identifiers survive as `Class.method` strings, because they are
used as log/analytics tags. They are the spine of the whole mode:

| String | Role |
|---|---|
| `TimeManager.nextTime` | advance one tick |
| `TimeManager.endToday` | roll the day over |
| `MainViewController.onClickTodayFinishToTodayStart` | the "day finished → next day" UI transition |
| `DBHelper.getDataWhenSignIn` | save sync |

### 2.3 `TimeManager.endToday` — RECOVERED

Decompiled body, abridged to the parts that read. The function is
`_wdc@282322095._CYf@282322095_b42508` at `0xf4932c`, in
`decompiled/wiq.dart:336`. Real string literals kept, obfuscated plumbing
collapsed.

```dart
// RECOVERED (abridged) -- TimeManager.endToday
dynamic _CYf_282322095_b42508() {
  ...
  // Reset the engine-maintained pseudo-switch namespace, with defaults:
  sub_adcb58(t27, "DATE_PROGRESS",         -2);   // tick; -2 == "between days"
  stub(t29,        "TIME_TO_MOVE_LOCATION", 0);
  stub(t31.f27,    "PREV_STUDY_SUBJECT",   -1);
  stub(t33.f27,    "COMBO_STUDY",          -1);
  stub(t35.f27,    "PREV_BLOCK_TYPE",      -1);
  stub(t37.f27,    "TICK",                 -1);
  stub(t39.f27,    "LOCATION_ID",          -1);
  stub(t41.f27,    "LOCATION_TYPE",        -1);
  ...
  stub(t91.f27,    "IS_BEFORE_SAT_EXAM",    1);   // still before the exam

  // Diagnostic: "called from endToday : " + <value>
  t46.f15 = "endToday에서 호출됨 : ";
  _StringBase._interpolate(local_m24, ...);

  // A story hook: DOK_BANG_ON / HIGH_GOGO grant an item (20007) or cash (1000)
  local_m32 = stub(t76, "DOK_BANG_ON", "TimeManager.endToday");
  final t79 = stub(..., "HIGH_GOGO",   "TimeManager.endToday");
  if (local_m32 == 1)  stub(stub(t79,"HIGH_GOGO",...), 20007, ...);  // item
  else if (t79 == 1)   stub(stub(t79,"HIGH_GOGO",...),  1000, ...);  // gold

  // Analytics
  accumulator.f7 = "play_days";
  _Kv.IAd(local_m24, accumulator);
}
```

What this tells you, and it is a lot:

- **Per-tick state is namespaced as switches and reset every day.** `TICK`,
  `LOCATION_ID`, `LOCATION_TYPE`, `PREV_STUDY_SUBJECT`, `COMBO_STUDY`,
  `PREV_BLOCK_TYPE` and `TIME_TO_MOVE_LOCATION` are not private fields — they
  live in the same `eventSwitchMap` that content reads. Your condition
  evaluator must see them.
- `DATE_PROGRESS = -2` and `TICK = -1` between days, so "a day is in progress"
  is `DATE_PROGRESS >= 0` — exactly the guard story 16's CSAT event uses.
- `COMBO_STUDY = -1` on rollover: **the study combo does not survive the night.**
- `IS_BEFORE_SAT_EXAM` is a maintained flag, not a computed predicate.
- The day boundary is also where story hooks pay out and `play_days` is logged.

```dart
// RECONSTRUCTED — endToday, as you should implement it
void endToday() {
  switches['DATE_PROGRESS']         = -2;
  switches['TICK']                  = -1;
  switches['LOCATION_ID']           = -1;
  switches['LOCATION_TYPE']         = -1;
  switches['PREV_STUDY_SUBJECT']    = -1;
  switches['COMBO_STUDY']           = -1;
  switches['PREV_BLOCK_TYPE']       = -1;
  switches['TIME_TO_MOVE_LOCATION'] =  0;

  usedActionKeysToday.clear();
  eventsFiredToday = 0;

  date = date.nextDay();
  mirrorCalendarSwitches();                   // DATE_DAY/MONTH/WEEK/INT, WEEKCODE
  switches['IS_BEFORE_SAT_EXAM'] = date < pack.endDate ? 1 : 0;

  if (date.weekday == Monday) rolloverWeeklyGoals();  // §8
  expireDayScopedEffects();                           // "the day consumed" items
  applyDayStartStoryHooks();                          // DOK_BANG_ON / HIGH_GOGO …
  log('play_days', dayNumber);

  if (date >= pack.endDate) { startExam(); return; }   // §7
  pickAndRunEvent();                                   // a day can open on an event
}
```

### 2.4 `TimeManager.nextTime` — RECONSTRUCTED

The string `TimeManager.nextTime` is referenced from `stub_3896c4` @ `0x7901e0`,
for which the stored export emitted no body. Reconstructed from the switch
namespace, the block vocabulary and the rollover above:

```dart
// RECONSTRUCTED — TimeManager.nextTime: spend one tick
void nextTime({required BlockType clicked}) {
  switches['PREV_BLOCK_TYPE']     = clicked.index;
  switches['CLICK_BLOCK_TYPE_SW'] = clicked.index;

  tick += 1;
  if (tick >= ticksPerDay) { endToday(); return; }

  switches['TICK']          = tick;
  switches['DATE_PROGRESS'] = tick;

  maybeFireEvent();     // §6.4
  dealBlocks();         // §3.3 — a fresh hand for the new tick
}
```

### 2.5 Per-run persisted state — RECOVERED (save-key names)

Verbatim from the English native's string pool. These are the fields a save must
carry, and they tell you what the engine counts:

```
_studyCountList          per-subject study tallies      -> FUNC_STUDY_COUNT
_schoolStudyCountList    class-block tallies
_sleepCountList          _exerciseCountList  _partTimeJobCountList
_specialCountList        special-track tallies
_locationCountList       visits per location            -> FUNC_GET_LOCATION_COUNT
_goalSuccessList         weekly goals met               -> §8
_suddenMissionCountList  sudden missions                -> suddenMissionClearCount
_examKoreanStatList  _examEnglishStatList  _examMathStatList
_examTamgoo1StatList _examTamgoo2StatList               -> §7, per-subject score history
_endingCode              which ending fired
_badgeIdList             university badges collected
_firstTraitList          traits chosen before the run
_rerollCount             Refresh Tickets spent on action blocks
_equipmentRerollCount  _storeRerollCount  _storeBuyCountList
_nockDownCount           -> FUNC_NOCK_DOWN
_wallpaper  _valueToSum
```

Other engine-side field names worth copying (same source): `eventSwitchMap`,
`locationContainer`, `itemContainer`, `traitContainer`, `bookContainer`,
`examContainer`, `goalContainer`, `todoContainer`, `admissionContainer`,
`eventContainer`, `equipmentItemContainer`, `locationIndexMap`,
`locationCountPeriodMap`, `locationInfoChangerMap`, `subjectBookSetMap`,
`traitInfoMap`, `bookIdMap`, `currentExamReportCard`, `prevExamResult`,
`userAdmissionSelectInfo`, `revealAdmissionResult`, `highestSchoolRate`,
`topClassUnivEnterCount`, `univEnterNumber`, `departmentEnterNumber`.

---

## 3. The day loop and the action blocks

### 3.1 The eleven locations — English build, exact

`stories/16/data/locations.json`: 11 locations, 61 actions.

| id | Name | `type` | `funcCode` | starts | `description` |
|---|---|---|---|---|---|
| 1000 | School | `school` | `SCHOOL` | unlocked, default | Slightly Increased Part-Time, Workout Efficiency |
| 2000 | Home | `sleep` | `HOME` | unlocked, default | Increased Sleep Efficiency |
| 16000 | Art Gallery | `sleep` | `GALLERY` | **locked** | Increased Sleep Efficiency |
| 16001 | Gold Mine | `partTimeJob` | `GOLD_MINE` | **locked** | Increased Part-Time Efficiency |
| 16002 | Park | `exercise` | `PARK` | unlocked | Increased Workout Efficiency |
| 16003 | Library | `study` | *(null)* | unlocked | Increased Study Frequency |
| 16004 | Café | `partTimeJob` | `CAFE` | unlocked | Increased Part-Time Efficiency |
| 16005 | Gym | `exercise` | `HEALTH` | **locked** | Increased Workout Efficiency |
| 16006 | Arcade | *(null)* | `PC_ROOM` | **locked** | Training-Specific |
| 16007 | Football Field | `exercise` | `PARK` | **locked** | Increased Workout Efficiency |
| 16008 | Office | *(null)* | *(null)* | **locked** | Writing-Specific |

Five start available (School, Home, Park, Library, Café); six unlock through
content. Note "Increased Study **Frequency**" on the Library — the descriptions
talk about frequency, which is the first clue to §3.3.

### 3.2 The action schema and the full action table

```json
{ "locationActionType": "study",
  "text": "",                        // empty -> label from the action type
  "weight": 12,                      // BLOCK DRAW WEIGHT (see 3.3)
  "weightFunction": null,            // dynamic weight hook; unused in story 16
  "failEventId": null,               // event fired when the action fails
  "changer": { "funcCode": "SLEEP", "args": null, "changes": [] },
  "hpWeight": 1,                     // stamina cost
  "blockDuplicated": false,          // true -> at most once per day
  "duplicatedKey": null,
  "conditionFuncCode": null,         // switch that must be non-zero to appear
  "userBook": { "bookId": 0, "studyCount": 0, "subject": "none" } }
```

`locationActionType` ∈ `study | partTimeJob | exercise | sleep | special`
(the engine's full enum, from the native, also has
`school schoolStudy schoolExam mockExam event none`). Counts in story 16:
special 21, sleep 11, study 10, exercise 10, partTimeJob 9.

| Location | Action | type | weight | hpWeight | gate | `changer` | once/day |
|---|---|---|---|---|---|---|---|
| **School** 1000 | Collect Parts | special | 2 | 1 | `MECHANIC_BLOCK_CONDITION` | `MECHANIC_ACTION` | |
| | Study Medicine | special | 2 | 1 | `MEDICAL_BLOCK_CONDITION` | `MEDICAL_ACTION` | |
| | Sleep | sleep | 1 | 0 | — | `SLEEP` | |
| | *(study)* | study | 6 | 1 | — | `SLEEP` ¹ | |
| | *(part-time)* | partTimeJob | 2 | 3 | — | `PART_TIME_JOB` | |
| | *(workout)* | exercise | 3 | 2.5 | — | `EXERCISE` | |
| | Idol training | special | 1 | 0.5 | `IDOL_BLOCK_CONDITION` | `IDOL_ACTION` | ✔ |
| | Game training | special | 1 | 0.6 | `PRO_GAME_BLOCK_CONDITION` | `PRO_GAME_ACTION` | ✔ |
| **Home** 2000 | Collect components | special | 2 | 1 | `MECHANIC_BLOCK_CONDITION` | `MECHANIC_ACTION` | |
| | Study Medicine | special | 2 | 1 | `MEDICAL_BLOCK_CONDITION` | `MEDICAL_ACTION` | |
| | Sleep | sleep | 1 | 0 | — | `SLEEP` | |
| | *(study)* | study | 6 | 1 | — | `SLEEP` ¹ | |
| | "Idol Training" ² | partTimeJob | 2 | 3 | — | `PART_TIME_JOB` | |
| | "Game Training" ² | exercise | 3 | 2.5 | — | `EXERCISE` | |
| | Idol training | special | 1 | 0.5 | `IDOL_BLOCK_CONDITION` | `IDOL_ACTION` | ✔ |
| | Game training | special | **4** | 0.6 | `PRO_GAME_BLOCK_CONDITION` | `PRO_GAME_ACTION` | ✔ |
| **Art Gallery** 16000 | Collect components | special | 2 | 1 | `MECHANIC_BLOCK_CONDITION` | `MECHANIC_ACTION` | |
| | Study Medicine | special | 2 | 1 | `MEDICAL_BLOCK_CONDITION` | `MEDICAL_ACTION` | |
| | 공부하기 ³ | study | **10** | 1 | — | `STUDY` | |
| | Sleep | sleep | 5 | 0 | — | `SLEEP` | |
| | 운동하기 ³ | exercise | 1 | 3 | — | `EXERCISE` | |
| | 알바하기 ³ | partTimeJob | 1 | 2.5 | — | `PART_TIME_JOB` | |
| **Gold Mine** 16001 | 알바하기 ³ | partTimeJob | **10** | 2.5 | — | `PART_TIME_JOB` | |
| | Sleep | sleep | 2 | 0 | — | `SLEEP` | |
| **Park** 16002 | Collect components | special | 2 | 1 | `MECHANIC_BLOCK_CONDITION` | `MECHANIC_ACTION` | |
| | Study Medicine | special | 2 | 1 | `MEDICAL_BLOCK_CONDITION` | `MEDICAL_ACTION` | |
| | Sleep | sleep | 1 | 0 | — | `SLEEP` | |
| | *(study)* | study | 6 | 1 | — | `SLEEP` ¹ | |
| | *(workout)* | exercise | 3 | 2.5 | — | `EXERCISE` | |
| | *(part-time)* | partTimeJob | 2 | 3 | — | `PART_TIME_JOB` | |
| | Idol training | special | 2 | 0.5 | `IDOL_BLOCK_CONDITION` | `IDOL_ACTION` | ✔ |
| **Library** 16003 | Collect components | special | 2 | 1 | `MECHANIC_BLOCK_CONDITION` | `MECHANIC_ACTION` | |
| | Study Medicine | special | 2 | 1 | `MEDICAL_BLOCK_CONDITION` | `MEDICAL_ACTION` | |
| | Sleep | sleep | **0.3** | 0 | — | `SLEEP` | |
| | *(study)* | study | **12** | 1 | — | `SLEEP` ¹ | |
| | *(workout)* | exercise | 1 | 2.5 | — | `EXERCISE` | |
| | *(part-time)* | partTimeJob | 1 | 3 | — | `PART_TIME_JOB` | |
| **Café** 16004 | Collect components | special | 2 | 1 | `MECHANIC_BLOCK_CONDITION` | `MECHANIC_ACTION` | |
| | Study Medicine | special | 2 | 1 | `MEDICAL_BLOCK_CONDITION` | `MEDICAL_ACTION` | |
| | Sleep | sleep | 1 | 0 | — | `SLEEP` | |
| | *(study)* | study | 3 | 1 | — | `SLEEP` ¹ | |
| | *(part-time)* ×2 ⁴ | partTimeJob | 2 each | 3 | — | `PART_TIME_JOB` | |
| | *(workout)* | exercise | 3 | 2.5 | — | `EXERCISE` | |
| | Game training | special | 4 | 0.6 | `PRO_GAME_BLOCK_CONDITION` | `PRO_GAME_ACTION` | ✔ |
| **Gym** 16005 | 운동하기 ³ | exercise | **10** | 3 | — | `EXERCISE` | |
| | Sleep | sleep | 1 | 0 | — | `SLEEP` | |
| | 공부하기 ³ | study | 1 | 1.5 | — | `STUDY` | |
| **Arcade** 16006 | Sleep | sleep | 3 | 0 | — | `SLEEP` | |
| | 공부하기 ³ | study | 2 | 1.5 | — | `STUDY` | |
| | 운동하기 ³ | exercise | 2 | 3 | — | `EXERCISE` | |
| | Game training | special | **10** | 0.6 | `PRO_GAME_BLOCK_CONDITION` | `PRO_GAME_ACTION` | ✔ |
| **Football Field** 16007 | Sleep | sleep | 1 | 0 | — | `SLEEP` | |
| | *(study)* | study | 6 | 1 | — | `SLEEP` ¹ | |
| | *(workout)* | exercise | 3 | 2.5 | — | `EXERCISE` | |
| | *(part-time)* | partTimeJob | 2 | 3 | — | `PART_TIME_JOB` | |
| | Soccer Practice | special | 2 | 1.5 | — | `SOCCER_ACTION` | ✔ |
| **Office** 16008 | Sleep | sleep | 3 | 0 | — | `SLEEP` | |
| | 공부하기 ³ | study | 2 | 1.5 | — | `STUDY` | |
| | 운동하기 ³ | exercise | 1 | 3 | — | `EXERCISE` | |
| | Drawing Practice | special | 5 | 1.5 | — | `DO_DRAW` | |

¹ **Authoring bug in the shipped data, not a mechanic.** Ten `study` rows carry
`changer.funcCode: "SLEEP"`. Decisive evidence: the five locations authored
later (16000/16001/16005/16006/16008) have non-empty `text` *and* a changer
matching their `locationActionType` exactly, so on those rows the changer is
simply redundant with the type. The older rows have empty `text` and a
copy-pasted changer. **Drive behaviour from `locationActionType`; treat the
changer as an additive side effect** — and do not "fix" the data.

² Two Home rows are mislabelled in the English build: a `partTimeJob` action
captioned "Idol Training" and an `exercise` action captioned "Game Training".
Same conclusion: type authoritative, caption wrong.

³ Left untranslated in the English build: 공부하기 = Study, 운동하기 = Workout,
알바하기 = Part-time Job. Supply your own labels.

⁴ The Café genuinely has two identical part-time rows, doubling the chance a
part-time block appears there.

### 3.3 The block draw — the single most important mechanic

**The player is not shown a static menu of actions.** Each tick the game deals a
*hand of action blocks*, drawn from the current location's action list and
weighted by `weight`. Six independent lines of evidence:

1. The native contains the field name **`blockWeightList`** (plus
   `weightFunction`, `entryBlock`, `blockNode`).
2. A **block-type enum** is first-class in the binary: `STUDY_BLOCK`,
   `SLEEP_BLOCK`, `EXERCISE_BLOCK`, `PART_TIME_JOB_BLOCK`, `SPECIAL_BLOCK`,
   `EVENT_BLOCK`, `GO_BLOCK`, `NA_BLOCK`, `SCHOOL_STUDY_BLOCK`,
   `SCHOOL_EXAM_BLOCK`, `MOCK_EXAM_BLOCK`, `GAME_BLOCK`, `IDOL_BLOCK`,
   `MAKE_FOOD_BLOCK`, `SING_KING_BLOCK`, `LEE_BLOCK`, `CLICK_EXACTLY_BLOCK`.
3. There is a **Refresh Ticket** currency whose stated purpose is *"Use Refresh
   Tickets to refresh Action Blocks"*, with a *"Refresh unavailable!"* failure
   state and a `_rerollCount` save key. Rerolling only means something if the
   hand is random.
4. The tutorial strings are block-centric: *"Tap on the 'Part-Time Block' to
   gain 'Cash'"*, *"Tap on the 'Workout Block' to gain 'Workout EXP'"*, *"Tap on
   a 'Sleep Block' to restore a small amount of Stamina"*, *"There are Study
   Blocks as well as Class Blocks. Tap on them to obtain Subject stats"*,
   *"Tap on blocks to increase your Study stats!"*.
5. Verbs exist to manipulate the hand: `ADD_BLOCK`, `RELOAD_ACTIONS`,
   `SET_NEXT_TARGET_BLOCK_CONDITION`; switches track it: `PREV_BLOCK_TYPE`,
   `CLICK_BLOCK_TYPE_SW`, `ACTION_FUNC_CODE_SW`.
6. Location descriptions say "Increased Study **Frequency**" (Library, study
   weight 12), not efficiency.

```dart
// RECONSTRUCTED — the per-tick hand
List<Block> dealBlocks() {
  final here = locations[locationId]!;

  final candidates = here.actions.where((a) {
    if (a.blockDuplicated &&
        usedActionKeysToday.contains(a.duplicatedKey ?? '${a.type}:${a.text}')) {
      return false;                                   // once-per-day already spent
    }
    final gate = a.conditionFuncCode;                 // IDOL_BLOCK_CONDITION, …
    if (gate != null && switchValue(gate) == 0) return false;
    return true;
  }).toList();

  // Weighted draw without replacement. `weight` is a probability, not a payout.
  final hand = weightedSample(candidates, n: rules.blocksPerTick,
                              weightOf: (a) => a.weightFunction == null
                                  ? a.weight
                                  : evalWeightFunction(a.weightFunction, this));

  // The engine also injects its own blocks:
  if (isClassTick())        hand.add(Block.schoolStudy());   // SCHOOL_STUDY_BLOCK
  if (pendingEvent != null) hand.add(Block.event());         // EVENT_BLOCK
  if (canMove)              hand.add(Block.go());            // GO_BLOCK
  for (final b in addedBlocksThisTick) hand.add(b);          // from ADD_BLOCK
  if (hand.isEmpty)         hand.add(Block.na());            // NA_BLOCK

  return hand;
}

bool reroll() {                                  // Refresh Ticket
  if (refreshTickets <= 0) return false;         // -> "Refresh unavailable!"
  refreshTickets--; rerollCount++;
  dealBlocks();
  return true;
}
```

`blocksPerTick` is compiled and not recoverable. Expose it as a tuning number;
4–6 is consistent with the screenshots and with weights spanning 0.3–12.

This reading is what makes the weights make sense: the Gold Mine's `partTimeJob`
weight 10 against `sleep` 2 means *at the Gold Mine you are almost always
offered mining*. The Library's study 12 against sleep 0.3 means you go there to
be offered study and nothing else.

### 3.4 Resolving a tapped block — RECONSTRUCTED

```dart
void onBlockTapped(Block b) {
  final a = b.action;

  switch (a.type) {
    case 'study':       doStudy(a, selectedBookFor(a));  break;
    case 'partTimeJob': doPartTime(a);                   break;
    case 'exercise':    doExercise(a);                   break;
    case 'sleep':       doSleep(a);  return;             // ends the day
    case 'special':     spendHp(a);  break;              // the changer does the work
  }

  applyChanger(a.changer);                               // §5
  if (a.blockDuplicated) usedActionKeysToday.add(keyOf(a));
  bumpCounters(a);                 // _studyCountList, _locationCountList, …

  if (hp <= 0) { onExhausted(); return; }                // §3.6
  nextTime(clicked: b.type);                             // §2.4
}

void doStudy(Action a, Book book) {
  final subject = book.subject;

  // Combo: consecutive studies of the same subject. Reset nightly and on switch.
  if (switchValue('PREV_STUDY_SUBJECT') == subjectIndex(subject)) {
    switches['COMBO_STUDY'] = switchValue('COMBO_STUDY') + 1;
  } else {
    switches['COMBO_STUDY'] = 0;
  }
  switches['PREV_STUDY_SUBJECT'] = subjectIndex(subject);

  final gain = studyFormula(                      // NOT RECOVERABLE — §11
      power:      book.power,                     // 5/7/10/15/22/35 by rank
      plusStat:   studyLevel.plusStat,            // 0..8
      efficiency: passiveSum('studyEfficiency', subject),  // items+traits+equipment
      combo:      switchValue('COMBO_STUDY'));

  addStat(subject, gain);
  studyExp += rules.studyExpPerAction;
  spendHp(a);

  book.readCount++;
  if (book.readCount == book.doneCount) onBookDone(book);  // BOOK_DONE / DONE_BOOK_
}

void spendHp(Action a) {
  var cost = a.hpWeight + passiveSum('hpCost');   // hpCost effects are negative
  hp = max(0, hp - max(0, cost));                 // trait gates read TICK -> pass it
}
```

### 3.5 Sleep

```dart
// RECONSTRUCTED
void doSleep(Action a) {
  var recovery = rules.sleepRestoresHp;
  if (locations[locationId]!.type == 'sleep') recovery += rules.sleepLocationBonus;
  recovery += passiveSum('sleepEfficiency');      // plusSleepHp traits, items
  hp = min(hpMax, hp + recovery);
  fireOnSleepItemEffects();          // e.g. "random subject +30 when sleeping"
  endToday();
}
```

`hpMax` is the pack's base cap, 100 in both campaigns, and does not grow. The
user confirmed the cap; an earlier reading that added 4 per workout level was
wrong. *"Higher Workout Levels make your Stamina more efficient"* refers to
the workout action-cost discount instead. See `docs/RETRY-FOLLOWUP.md`.

### 3.6 Exhaustion

Implementation update (2026-10-23): the English global data supplies event
10000000 (Stamina Depleted), root node 10000000000, a `last` node carrying
`DEFAULT_FAIL_EVENT` and the translated exhaustion message. The recovered
`app.dart` references EVENT_10000000 in the failure path, and `wiq.dart`'s
endToday body resets the day state described in section 2.3. The precise UI
tick-animation delay is not recovered: this rebuild uses 120ms per lost slot
after acknowledging the global event. Remaining slots grant no action effects;
the day date and zero HP are preserved until this sequence ends. The system
event is host-triggered and excluded from ordinary story event eligibility.

Stamina is the only real resource. Reaching zero is a discrete punished state,
not merely "out of actions": an item effect is described as *"Chance to maintain
Stamina at 1 instead of exhaustion"* (`surviveExhaustion`).

```dart
// RECONSTRUCTED
void onExhausted() {
  if (rollChance(passiveSum('surviveExhaustion'))) { hp = 1; return; }
  addStatAll(rules.exhaustedPenaltyStat);   // a flat loss across subjects
  showExhaustionDialog();
  endToday();                               // the rest of the day is lost
}
```

A secondary hunger track exists (`HUNGRY`, `INCREASE_HUNGRY`,
`DECREASE_HUNGRY`, `THIRSTY_SWITCH`) and is displayed, but no story-16 content
drives it. Skip it.

---

## 4. The condition language

### 4.1 Shape

One recursive structure gates events, nodes, choices and individual changes. The
field names are confirmed present in the English native: `conditionSet`,
`conditions`, `left`, `right`, `operator`, `target`, `targetType`,
`compareType`, `value`, `intValue`, `strValue`, `args`, `argTypes`, `type`.

```json
{ "operator": "and",
  "left":  { "conditions": [] },
  "right": { "conditions": [
     { "type": "defaults", "target": "EVENT_69", "targetType": "event",
       "compareType": "equal", "value": 0, "args": null, "argTypes": null } ] } }
```

Measured over the whole English story-16 campaign:

| | counts |
|---|---|
| `targetType` | eventSwitch 171, event 159, func 103, location 38, date 23 |
| `compareType` | equal 414, equalOrBigger 65, smaller 10, notEqual 4, bigger 1 |
| `type` | `defaults` (plain) and `func` |

```dart
// RECONSTRUCTED — the evaluator
bool evaluate(Map? set) {
  if (set == null) return true;

  for (final c in (set['conditions'] as List? ?? const [])) {
    if (!single(c)) return false;                 // a conditions list is ANDed
  }

  final l = set['left'], r = set['right'];
  if (l == null && r == null) return true;

  final lv = isEmpty(l) ? null : evaluate(l);     // an empty side is "no opinion",
  final rv = isEmpty(r) ? null : evaluate(r);     // which is why the common
                                                  // single-condition case is an
  if ((set['operator'] ?? 'and') == 'or') {       // empty left + populated right
    if (lv == null) return rv ?? true;
    if (rv == null) return lv;
    return lv || rv;
  }
  return (lv ?? true) && (rv ?? true);
}

bool single(Map c) {
  final actual = actualValue(c);
  if (actual == null) return false;               // unknown target -> false, and log
  return compare(actual, c['compareType'], (c['value'] as num?) ?? 0);
}

num? actualValue(Map c) {
  final target = c['target'] as String;
  switch (c['targetType']) {
    case 'event':       return eventState[idOf(target)] ?? 0;   // 'EVENT_69' — see 4.2
    case 'eventSwitch': return switchValue(target);             // incl. engine mirrors
    case 'date':        final w = GameDate.tryParse(target);
                        if (w == null) return null;
                        return w.tick != 0
                            ? (w.day == date.day && w.tick == date.tick ? 1 : 0)
                            : (w.day == date.day ? 1 : 0);
    case 'location':    return unlocked.contains(idOf(target)) ? 1 : 0;  // 'LOCATION_16003'
    case 'func':        return funcs[target]?.call(this, c['args'] ?? const []);
  }
  return null;
}
```

### 4.2 Event state is a tri-state code, not a counter

Across the whole English story-16 campaign, `targetType: "event"` conditions
compare against **only two values: 0 (148×) and 2 (11×)**. The Korean superset
adds 1 (16×) and still never exceeds 2.

```
0 = never seen      1 = started / in progress      2 = completed
```

`EVENT_<id> equal 0` is the universal "has not happened yet" guard that every
event puts on itself; `EVENT_<id> equal 2` is "that storyline beat is finished"
and is used as a precondition. Store a code, not a count.

### 4.3 Engine pseudo-switches

Some names read through `targetType: "eventSwitch"` are written by the engine,
never by content. Measured against the English story-16 `event_switches.json`
(444 declared switches):

| Switch | Declared in the campaign? | Written by |
|---|---|---|
| `DATE_PROGRESS`, `DATE_DAY`, `DATE_MONTH`, `DATE_WEEK`, `MONEY`, `STUDY_LEVEL`, `ENDING_CODE`, `ENDING_SW` | yes (so content can read them) | engine — except `ENDING_SW`, which content sets |
| `EXERCISE_LEVEL`, `PART_TIME_JOB_LEVEL`, `TICK`, `LOCATION_ID`, `LOCATION_TYPE`, `DATE_INT`, `WEEKCODE`, `COMBO_STUDY`, `PREV_STUDY_SUBJECT`, `PREV_BLOCK_TYPE`, `TIME_TO_MOVE_LOCATION`, `IS_BEFORE_SAT_EXAM` | **no** — pure engine state | engine |

**Mirror your game state into this namespace before evaluating anything.**
`ENDING_CODE` is the one to watch: it is declared, read 13 times by story-16
content, and **set by no content node anywhere** — it is the engine's "the exam
is scored, endings may now fire" flag (§7).

### 4.4 The `FUNC_` registry — RECOVERED

The registry is a single map literal built at isolate start. From
`decompiled/app/app.dart:37073`:

```dart
// RECOVERED (abridged) — the FUNC_ predicate registry
dynamic init_usl() {
  final accumulator = AllocateArray(null, 340)
    ..f15  = "TEST"                            ..f19  = unresolved_Closure
    ..f23  = "FUNC_IS_TAMGOO"                  ..f27  = unresolved_Closure
    ..f31  = "FUNC_GET_TAMGOO_CATEGORY"        ..f35  = unresolved_Closure
    ..f39  = "FUNC_MOVE_LOCATION_EXCEPT"       ..f43  = unresolved_Closure
    ..f47  = "FUNC_MOCK_EXAM_TOTAL_RAW_SCORE"  ..f51  = unresolved_Closure
    ..f55  = "FUNC_ITEM_COUNT"                 ..f59  = unresolved_Closure
    /* … 78 more name/closure pairs … */ ;
  (accumulator + (292 << 1)).f15 = "FUNC_ITEM_HAVE";
  (accumulator + (296 << 1)).f15 = "FUNC_ITEM_HAVE_LIST";
  (accumulator + (300 << 1)).f15 = "FUNC_IS_MALE";
  (accumulator + (304 << 1)).f15 = "FUNC_IS_FEMALE";
  (accumulator + (308 << 1)).f15 = "FUNC_GET_CURRENT_EXAM_GRADE";
  /* … */
  return new Map.Map._fromLiteral(338, accumulator + 676);
}
```

84 keys recovered in registration order (one is the sentinel `TEST`); the
closures are present but the decompiler could not link their bodies, so each
predicate's arithmetic has to be reconstructed. **The English native registers
81 `FUNC_*` names.** The English story-16 campaign uses only **17** — those are
your must-haves:

| Predicate | uses | semantics |
|---|---|---|
| `FUNC_ITEM_COUNT` | 16 | how many of item `args[0]` are held |
| `FUNC_RANDOM_TRUE` | 12 | percentage roll; `args[0]` is the percent |
| `FUNC_GET_EXERCISE_LEVEL` | 11 | 0–10 |
| `FUNC_RANDOM_VALUE` | 11 | uniform integer in `[args[0], args[1]]` |
| `FUNC_TODO_DAY` | 9 | days remaining to the exam |
| `FUNC_IS_ENTER_UNIV_THAT_RATE` | 8 | 1 if admitted at/above percentile `args[0]` — §7 |
| `FUNC_GET_PLUS_STAT` | 7 | the study level's `plusStat` (0–8) |
| `FUNC_TRAIT_HAVE` | 5 | 1 if trait `args[0]` is held |
| `FUNC_GET_HIGH_STAT` | 5 | **index** of the highest subject |
| `FUNC_GET_LOW_STAT` | 5 | **index** of the lowest subject |
| `FUNC_MOVE_LOCATION_EXCEPT` | 4 | 1 if the current location is not in `args` |
| `FUNC_GOOD_DRAW_VALUE` | 4 | the committed draw/gacha roll |
| `FUNC_GET_SUCCESS_LENGTH` | 2 | current study-combo length |
| `FUNC_ROUGH_TODO_DAY` | 1 | days remaining ÷ 7 |
| `FUNC_STUDY_COUNT` | 1 | total studies (`_studyCountList` sum) |
| `FUNC_IS_NO_ITEM_IN_POCKET` | 1 | 1 if the inventory is empty |
| `FUNC_IS_TRAIT_LIST` | 1 | 1 if any trait in `args` is held |

`FUNC_GET_LOW_STAT` / `FUNC_GET_HIGH_STAT` return a **subject index**, because
the effect verbs address subjects positionally too (`INCREASE_STAT [1, 150]` =
"subject 1"). Both sides must agree on the ordering
`[korean, english, math, science, society]`.

```dart
// RECONSTRUCTED — the 17 predicates story 16 needs
final funcs = <String, num Function(Game, List)>{
  'FUNC_ITEM_COUNT':            (g, a) => g.itemCount(a.i(0)),
  'FUNC_IS_NO_ITEM_IN_POCKET':  (g, a) => g.inventory.isEmpty ? 1 : 0,
  'FUNC_TRAIT_HAVE':            (g, a) => g.traits.contains(a.i(0)) ? 1 : 0,
  'FUNC_IS_TRAIT_LIST':         (g, a) => a.any((t) => g.traits.contains(t)) ? 1 : 0,
  'FUNC_RANDOM_TRUE':           (g, a) => g.rng.nextDouble()*100 < (a.n(0) ?? 50) ? 1 : 0,
  'FUNC_RANDOM_VALUE':          (g, a) => g.rng.between(a.i(0), a.i(1)),
  'FUNC_GOOD_DRAW_VALUE':       (g, a) => g.drawValue,
  'FUNC_GET_EXERCISE_LEVEL':    (g, a) => g.exerciseLevel.level,
  'FUNC_GET_PLUS_STAT':         (g, a) => g.studyLevel.plusStat,
  'FUNC_GET_SUCCESS_LENGTH':    (g, a) => g.switchValue('COMBO_STUDY'),
  'FUNC_STUDY_COUNT':           (g, a) => g.studyCountList.sum,
  'FUNC_GET_LOW_STAT':          (g, a) => g.subjectIndexOfExtreme(lowest: true),
  'FUNC_GET_HIGH_STAT':         (g, a) => g.subjectIndexOfExtreme(lowest: false),
  'FUNC_TODO_DAY':              (g, a) => g.daysRemaining,
  'FUNC_ROUGH_TODO_DAY':        (g, a) => g.daysRemaining ~/ 7,
  'FUNC_MOVE_LOCATION_EXCEPT':  (g, a) => a.contains(g.locationId) ? 0 : 1,
  'FUNC_IS_ENTER_UNIV_THAT_RATE': (g, a) => g.admission.percentile >= a.n(0) ? 1 : 0,
};
```

Everything else the engine registers — the mock-exam family, school-exam points,
the location/date predicates, the store and region predicates — is unused by
this campaign. Register them returning 0 so content that branches on them takes
the ordinary path, and log unknown ones rather than failing silently.

---

## 5. Changers: the effect system

### 5.1 Shape

```json
"changer": {
  "funcCode": "INCREASE_STAT",
  "args": [1, 150],
  "changes": [ { "type": "set", "target": "ENDING_SW", "value": 5,
                 "timer": null, "conditionSet": null } ] }
```

- `changes` is **switch bookkeeping and always runs**: `set` assigns, `add`
  increments. Each entry may carry its own `conditionSet` and a `timer`.
- `funcCode` + positional `args` is the gameplay verb.
- Nodes may also carry an `actionChanger` (an effect bound to the action that
  triggered the event rather than to the node).

### 5.2 The complete verb registry — RECOVERED

`init_jvl()` in `decompiled/app/app.dart` is the whole changer registry: a
712-slot array literal holding **178 verbs** with their closures, in
registration order. This is the single most useful recovered artefact in the
binary.

```dart
// RECOVERED (abridged) — the changer/funcCode registry
dynamic init_jvl() {
  final accumulator = AllocateArray(null, 712);
  ...
  accumulator.f111 = "SET_RANDOM_MONEY";   accumulator.f115 = unresolved_Closure;
  accumulator.f119 = "DECREASE_MONEY";     accumulator.f123 = unresolved_Closure;
  accumulator.f127 = "ADD_TODO";           accumulator.f131 = unresolved_Closure;
  accumulator.f135 = "REMOVE_TODO";        accumulator.f139 = unresolved_Closure;
  accumulator.f143 = "INCREASE_STAT_ALL";  accumulator.f147 = unresolved_Closure;
  accumulator.f151 = "INCREASE_STAT";      accumulator.f155 = unresolved_Closure;
  accumulator.f159 = "INCREASE_TAMGOO_STAT";
  accumulator._Xzi = "INCREASE_TAMGOO_LOW_STAT";
  accumulator._pxh = "DECREASE_TAMGOO_HIGH_STAT";
  accumulator.f191 = "SET_MOVE_LOCATION_LIST";
  accumulator._sxh = "INCREASE_HP";        accumulator._uxh = "DECREASE_HP";
  accumulator.f215 = "ACQUIRE_ITEM_RANDOM";
  accumulator.f223 = "INCREASE_HIGH_STAT"; accumulator.f231 = "INCREASE_LOW_STAT";
  /* … 160 more … */
}
```

The 178 verbs in registration order, grouped for reading:

```
exams      START_SCHOOL_EXAM START_SHORT_MOCK_EXAM START_MOCK_EXAM START_SAT
           END_MOCK_EXAM END_SHORT_MOCK_EXAM CLEAR_SCHOOL_EXAM
items      ACQUIRE_ITEM ACQUIRE_ITEM_RANDOM ACQUIRE_ITEM_LIST REMOVE_ITEM
           REMOVE_ITEM_LIST REMOVE_ITEM_ONCE REMOVE_ITEM_LIST_COUNT
           REMOVE_ITEM_RANDOM USE_ITEM OPEN_GIFT OPEN_GIFT_ITEM
traits     ACQUIRE_TRAIT ACQUIRE_TRAIT_RANDOM REMOVE_TRAIT
           REMOVE_TRAIT_FROM_EXERCISE REMOVE_BAD_TRAIT_RANDOM EVOLVE_TRAIT
money      CASHING INCREASE_MONEY INCREASE_RANDOM_MONEY SET_RANDOM_MONEY
           DECREASE_MONEY
stats      INCREASE_STAT INCREASE_STAT_ALL DECREASE_STAT DECREASE_STAT_ALL
           INCREASE_HIGH_STAT INCREASE_LOW_STAT DECREASE_HIGH_STAT
           DECREASE_LOW_STAT INCREASE_RANDOM_STAT INCREASE_RANDOM_STAT_REAL
           DECREASE_RANDOM_STAT INCREASE_TAMGOO_STAT DECREASE_TAMGOO_STAT
           INCREASE_TAMGOO_LOW_STAT DECREASE_TAMGOO_HIGH_STAT SET_RANDOM_SUBJECT
hp/exp     INCREASE_HP DECREASE_HP INCREASE_HUNGRY DECREASE_HUNGRY
           INCREASE_EXERCISE_EXP INCREASE_PART_TIME_JOB_EXP
locations  UNLOCK_LOCATION LOCK_LOCATION UNLOCK_LOCATION_ALL
           UNLOCK_LOCATION_EXCEPT LOCK_LOCATION_EXCEPT MOVE_LOCATION
           LOCK_MOVE_LOCATION SET_MOVE_LOCATION_LIST CHANGE_LOCATION_INFO
           START_LOCATION_COUNT END_LOCATION_COUNT SHOW_LOCATION_LIST
switches   SET_RANDOM_SWITCH SET_RANDOM_SWITCH_3 INCREASE_SWITCH
           INCREASE_VALUE_WITH_MAX SET_VALUE_TARGET SET_CHALLENGE_VALUE
           ADD_CHALLENGE_VALUE SUB_CHALLENGE_VALUE TURN_ON TURN_OFF
           SET_DRAW_VALUE SET_GOLD_SUN_VALUE SET_DOK_BANG SET_HIGH_GOGO
todos      ADD_TODO ADD_TODO_2 ADD_TODO_BY_WEEK REMOVE_TODO MODIFY_TODO_TITLE
blocks     ADD_BLOCK RELOAD_ACTIONS SET_NEXT_TARGET_BLOCK_CONDITION
goals      SET_STUDY_GOAL SHOW_GOAL_DIALOG
missions   TURN_OFF_WARNING_MISSION RELOAD_WARNING_SWITCH COACH_WARNING_INFO_ICON
run        END_GAME EXIT_STORY SHOW_ENDING START_CHAPTER SHOW_CHAPTER
actions    PART_TIME_JOB EXERCISE SLEEP STUDY SCHOOL_STUDY WALKING EVENT
           FORCE_OPEN_EVENT_POPUP DEFAULT_FAIL_EVENT
tracks     IDOL_ACTION PRO_GAME_ACTION SOCCER_ACTION MEDICAL_ACTION
           MECHANIC_ACTION SSUL_MAE_ACTION LEARN_PSYCHIC_SKILL PRACTICE_PSYCHIC
           DO_DRAW DO_SKI DO_EXPLORE DO_GATHER DO_STEAL_GIFT DO_GAME DO_KARAOKE
           DO_SINGKING DO_MAKE_FOOD DO_BROADCAST DO_GO_PRO DO_GO_LEE
           DO_GO_BANJANG DO_HELP_BANJANG PLAY_GAME VOICE ACT FISH GETGET COOK
clicks     FISH_BLOCK_CLICK PIANO_BLOCK_CLICK DRAWING_BLOCK_CLICK
           EXPLAIN_BLOCK_CLICK CALM_BLOCK_CLICK FEELINGS_BLOCK_CLICK
           YELL_BLOCK_CLICK
ui/misc    TUTORIAL_ALERT REQUEST_TUTORIAL REQUEST_REVIEW REQUEST_IN_APP_SHEET
           COACH_TUTORIAL BLINK_EFFECT SIREN ADD_REROLL ALIVE_ART
           HACKING_LESSON GO_WEB_BROWSER SHOW_CALENDAR SHOW_RECIPE SHOW_CONCH
           SHOW_MATERIAL SHOW_IMAGE_PAGE SHOW_PUZZLE LOOK_NOTE LOOK_BACK_LOG
           LOOK_MAKING_GUIDE RECORD_SPEAK RECORD_SPEAK_ALL SHOW_SPEAK_LIST
           SHOW_SELECT_REACTION_POPUP SHOW_BATTLE_SCORE_POPUP
           SHOW_PSYCHIC_REWARD_POPUP SHOW_PSYCHIC_TUTORIAL_POPUP
           COPY_CHARACTER_EFFECT NALSI_DATE NALSI_RANDOM_DATE NALSI_AFTER_DATE
detective  SHOW_SEARCH_CRIMINAL SHOW_SELECT_CRIMINAL SHOW_SUSPICIOUS_POINTS
           SHOW_STALKER_POSITION UNLOCK_CLUE UNLOCK_CLUE_2 GUESS_DYING_MESSAGE
           GUESS_LETTER_MESSAGE SOLVE_THE_PROBLEM
```

Two things fall out:

1. **Location-action changers and event changers go through the same registry.**
   `PART_TIME_JOB`, `EXERCISE`, `SLEEP`, `STUDY`, `SCHOOL_STUDY` are registered
   verbs — which is why the action rows in §3.2 name them.
2. A second, much smaller registry exists for **timed changes**: `init_EDl()`
   builds a 17-entry map of `ACQUIRE_ITEM, ACQUIRE_TRAIT, REMOVE_TRAIT,
   INCREASE_MONEY, DECREASE_MONEY, INCREASE_STAT_ALL, INCREASE_STAT,
   INCREASE_RANDOM_STAT, INCREASE_TAMGOO_STAT, INCREASE_HP, DECREASE_HP,
   DECREASE_STAT, DECREASE_STAT_ALL, REMOVE_ITEM, INCREASE_EXERCISE_EXP,
   INCREASE_PART_TIME_JOB_EXP, **REMAIN_TIME**`. The presence of `REMAIN_TIME`
   and the `timer` field on each `changes` entry says this is the subset of
   verbs allowed on a *delayed* change.

### 5.3 What story 16 actually uses — 27 verbs

```
DECREASE_HP 44        DECREASE_MONEY 26       ADD_TODO_2 26
INCREASE_STAT_ALL 19  ACQUIRE_ITEM_RANDOM 16  END_GAME 14
ACQUIRE_TRAIT 13      UNLOCK_LOCATION 10      ACQUIRE_ITEM 10
REMOVE_TODO 9         LOCK_LOCATION 9         INCREASE_STAT 9
INCREASE_HP 7         INCREASE_MONEY 6        SET_RANDOM_SWITCH 5
REMOVE_ITEM 5         SET_DRAW_VALUE 4        ADD_CHALLENGE_VALUE 3
DECREASE_STAT_ALL 3   REMOVE_BAD_TRAIT_RANDOM 3   MOVE_LOCATION 2
ADD_BLOCK 2           DECREASE_STAT 2         START_SAT 1
REMOVE_ITEM_RANDOM 1  ADD_TODO 1              LOCK_LOCATION_EXCEPT 1
```

```dart
// RECONSTRUCTED — the applier, and the 27 verbs this campaign needs
void applyChanger(Map? ch) {
  if (ch == null) return;

  for (final c in (ch['changes'] as List? ?? const [])) {
    if (!evaluate(c['conditionSet'])) continue;      // per-change gate
    final t = c['target'] as String, v = (c['value'] as num).toInt();
    if (c['timer'] != null) { scheduleChange(c); continue; }   // see 5.2 note 2
    if (c['type'] == 'add') switches[t] = switchValue(t) + v;
    else                    switches[t] = v;
  }

  final verb = verbs[ch['funcCode']];
  if (verb == null) { reportUnknownVerb(ch['funcCode']); return; }
  verb(this, (ch['args'] as List?) ?? const []);
}

final verbs = <String, void Function(Game, List)>{
  'INCREASE_STAT':     (g,a) => g.addStat(g.subjectAt(a.i(0)),  a.n(1)),
  'DECREASE_STAT':     (g,a) => g.addStat(g.subjectAt(a.i(0)), -a.n(1)),
  'INCREASE_STAT_ALL': (g,a) => g.addStatAll( a.n(0)),
  'DECREASE_STAT_ALL': (g,a) => g.addStatAll(-a.n(0)),
  'INCREASE_HP':       (g,a) => g.addHp( a.n(0)),
  'DECREASE_HP':       (g,a) => g.addHp(-a.n(0)),
  'INCREASE_MONEY':    (g,a) => g.addMoney( a.n(0)),
  'DECREASE_MONEY':    (g,a) => g.addMoney(-a.n(0)),
  'ACQUIRE_ITEM':      (g,a) => g.addItem(a.i(0), a.i(1) ?? 1),
  'ACQUIRE_ITEM_RANDOM': (g,a) => g.addItem(g.rng.pick(a.ints)),
  'REMOVE_ITEM':       (g,a) => g.removeItem(a.i(0), a.i(1) ?? 1),
  'REMOVE_ITEM_RANDOM': (g,a) => g.removeItem(g.rng.pick(g.inventory.keys)),
  'ACQUIRE_TRAIT':     (g,a) => g.traits.add(a.i(0)),
  'REMOVE_BAD_TRAIT_RANDOM': (g,a) => g.removeRandomTraitOfType('bad'),
  'UNLOCK_LOCATION':   (g,a) => g.unlocked.add(a.i(0)),
  'LOCK_LOCATION':     (g,a) => g.unlocked.remove(a.i(0)),
  'LOCK_LOCATION_EXCEPT': (g,a) => g.unlocked.retainAll(a.ints),
  'MOVE_LOCATION':     (g,a) { g.unlocked.add(a.i(0)); g.locationId = a.i(0); },
  'SET_RANDOM_SWITCH': (g,a) => g.switches[a.s(0)] = g.rng.between(a.i(1), a.i(2)),
  'SET_DRAW_VALUE':    (g,a) => g.drawValue = g.rng.nextInt(100),
  'ADD_CHALLENGE_VALUE': (g,a) => g.switches[a.s(0)] = g.switchValue(a.s(0)) + a.i(1),
  'ADD_TODO':          (g,a) => g.todos.add(a),
  'ADD_TODO_2':        (g,a) => g.todos.add(a),
  'REMOVE_TODO':       (g,a) => g.todos.removeWhere((t) => t.id == a.i(0)),
  'ADD_BLOCK':         (g,a) => g.addedBlocksThisTick.add(Block.fromArgs(a)),
  'START_SAT':         (g,a) => g.startExam(),                      // §7
  'END_GAME':          (g,a) { g.endingCode = a.i(0); g.endingName = a.s(1);
                               g.finished = true; },
};
```

"TAMGOO" (탐구) is the **elective/inquiry subject pair** — science and society in
a five-subject run. `TAMGOO1`/`TAMGOO2` are the slots,
`_examTamgoo1StatList`/`_examTamgoo2StatList` their exam scores.

### 5.4 Item effects are named compiled functions — RECOVERED

An important correction to how this is usually described. Item effects are *not*
anonymous and *not* keyed only by id: the English native contains **199 named
`itemEffect<ItemName>` functions**, one per item:

```
itemEffectCoffee                  itemEffectDecaffeinatedCoffee
itemEffectButterCookie            itemEffectWhiteCookie   itemEffectYellowCookie
itemEffectGreenCookie             itemEffectRedCookie     itemEffectBlackCookie
itemEffectEmeraldCookie           itemEffectPuffedRice
itemEffectChocolateMilk           itemEffectFireChickenRamen
itemEffectDiePolkCutlet           itemEffectInstantLottery
itemEffectHighEndLottery          itemEffectStrangeWorkBook
itemEffectSurasang                itemEffectChickenBreastFishCakeBar
itemEffectArginine                itemEffectSalt
itemEffectCollectionOfQuotations  itemEffectColdMedicine
itemEffectCoffeeMachine           itemEffectSecretsOfEnglishStudy
itemEffectDarkMatter              itemEffectVoynichManuscript
itemEffectGaussHandwritingNote    itemEffectHunminjeongeum
itemEffectDoughnutShapedCushion   itemEffectFinasteride   itemEffectMinoxidil
itemEffectMockTest                itemEffectDice          itemEffectSilverRing
itemEffectSafeHome itemEffectSafeCafe itemEffectSafeLibrary
itemEffectRecipe   itemEffectKnowHowRecipe   itemEffectSatSpecialLecture
/* … 160 more … */
```

The names map one-to-one onto item names in `global_data/item/*.json` and
`stories/16/item/*.json`, so the registry you need is
`itemId → named effect function`, and the English `name` + `effectText` pair
tells you which function is which. That is a far better basis than guessing.

The `effectText` shown to the player is written in a small regular sublanguage
("Stamina +30", "Korean stat +CONSUME_STAT_150", "Study Efficiency in Art
Gallery +NORMAL_STAT_3", "Gold Mine Efficiency +20%"), and
`d30mode/tools/item_effects.py` already parses it into structured effects —
**reuse that parser** and use the function names above to sanity-check it.

Two scaling tokens appear literally inside `effectText` and must be handled:
`CONSUME_STAT_<n>` and `NORMAL_STAT_<n>`. The number is a **base** the engine
multiplies by a factor held in code. Keep the base; make the multiplier a
tuning number.

```dart
// RECONSTRUCTED — item use and passive sums
bool useItem(int id) {
  final item = items[id]!;
  if (!item.isConsumable || itemCount(id) == 0) return false;
  for (final e in item.effects) { if (e.trigger == null) applyItemEffect(e); }
  itemUseCounts[id] = (itemUseCounts[id] ?? 0) + 1;   // FUNC_ITEM_USE_COUNT
  removeItem(id);
  return true;
}

num passiveSum(String type, [String? subject]) {
  num total = 0;
  for (final id in inventory.keys) {                  // held (non-consumable) items
    for (final e in items[id]!.effects) {
      if (e.type != type) continue;
      if (!scopeMatches(e.scope)) continue;           // {locationId} or {locationType}
      if (subject != null && e.subject != null &&
          e.subject != 'all' && e.subject != subject) continue;
      total += e.value;
    }
  }
  for (final t in traits) {                           // traits ship effects as JSON
    for (final e in traitDefs[t].effectList) {
      if (e.type != type) continue;
      if (!traitGateOpen(e.conditions)) continue;     // LOCATION_ID, TICK, STUDY_LEVEL, …
      total += e.value ?? e.extraStat ?? e.plusValue;
    }
  }
  for (final eq in equipped) total += eq.studyStatsFor(type, subject);
  return total;
}
```

---

## 6. The event engine

### 6.1 Size of the English story-16 campaign

| | |
|---|---|
| `event/events.json` | 2,880,423 B |
| events | **147** (3 `isFake`) |
| nodes | **3,444** |
| event sets (storylines) | **18**, covering 106 events; 41 events have no set |
| event switches | **444** declared |
| NPCs | 40 (`data/npcs.json`) |
| backgrounds / BGM / SFX | 89 / 42 / 61 |
| nodes with English text | 2,903 of 2,906 |

Node ids follow **`eventId × 1000 + index`** (event 69's root is node 69000).
A handful of later events break the convention; load defensively.

### 6.2 Node schema and the display-text rule

Node types with real counts: `text` 2,535, `last` 297, `standing` 277,
`background` 110, `option` 74, `ifElse` 64, `soundEffect` 36, `mainBGM` 20,
`eventBGM` 18, `loopSoundEffect` 9, `mainBGMMute` 4.

A real node, verbatim from the English build:

```json
{ "id": 35000, "boxId": 0, "index": 0, "type": "text",
  "firebaseId": "1b87ff40-34d5-11ee-9e1b-3372bb4b1f7c",
  "speakerId": 0, "isHideSpeakerName": false,
  "standingId": null, "standingOff": false,
  "standingExpression": "defaults", "standingClothes": "defaults",
  "otherLayerList": [],
  "text": "졸업 시험이다...!",
  "translatedText": "Finally, it's CSAT...!",
  "originTextVersion": 1, "translatedTextVersion": 1,
  "elseText": null, "translatedElseText": null,
  "originElseTextVersion": null, "translatedElseTextVersion": null,
  "backgroundImg": null, "backgroundImgFromHttp": null,
  "nextNodeId": 35001, "nextLinkedBoxId": null,
  "changer": null, "eventSound": null, "vibration": null,
  "conditionSet": null,
  "minVersion": { "major": 1, "minor": 0, "patch": 0 }, "maxVersion": null }
```

**This is how the English build is English.** `text` holds the Korean source and
`translatedText` the English, each with a version counter so a stale translation
can be detected. The engine's display-text resolution is therefore:

```dart
// RECONSTRUCTED — display text, from the version-pair schema
String displayText(Node n) {
  if (n.translatedText != null &&
      n.translatedTextVersion == n.originTextVersion) {
    return n.translatedText!;            // translation is current
  }
  return n.text ?? '';                   // stale or missing -> show the source
}
```

The same pair exists for `elseText` and for each option's `optionText`
(`translatedOptionText` / `…Version`). For a clean-room rebuild you collapse
this to one string per node — but you must *read the right side of it*, or your
pack comes out in Korean.

Three fields are **identifiers that happen to hold Korean** and must never be
translated or renamed: `standingExpression`, `standingClothes`, and the sprite
names under `otherLayerList`. Translating a lookup key like this once broke 154
audio ids in an earlier pass on this codebase.

### 6.3 The node walker — RECONSTRUCTED

```dart
// RECONSTRUCTED
class EventRun {
  void start(Event e) {
    eventState[e.id] = 1;                              // 1 == in progress
    eventsFiredToday++;
    walk(e.rootNodeId);
  }

  void walk(int? id) {
    var steps = 0;
    while (true) {
      if (++steps > 2000) { bail('graph loops'); return; }   // authoring guard
      if (id == null) { finish(); return; }
      final n = nodes[id];
      if (n == null) { bail('missing node $id'); return; }

      final gate = evaluate(n.conditionSet);

      if (gate) {
        applyChanger(n.changer);                       // side effects first
        applyChanger(n.actionChanger);
        if (finished) { finish(); return; }             // END_GAME
      }
      if (n.backgroundImg != null) background = n.backgroundImg;
      if (n.vibration != null) vibrate(n.vibration);

      switch (n.type) {
        case 'ifElse':
          id = gate ? n.nextNodeIdIfTrue : n.nextNodeIdIfFalse;
          continue;                      // also: nextBoxIdIfTrue / nextBoxIdIfFalse

        case 'option':
          if (!gate) { id = n.nextNodeId; continue; }
          final shown = n.options.where((o) => evaluate(o.conditionSet)).toList();
          if (shown.isEmpty) { id = n.nextNodeId; continue; }   // never deadlock
          present(text: bodyOf(n, gate), choices: shown);
          return;                                       // wait for the player

        case 'last':
          finish(n); return;

        case 'text':
          final body = bodyOf(n, gate);
          if (body.trim().isEmpty) { id = n.nextNodeId; continue; }
          present(text: body, speaker: speakerOf(n));
          return;

        default:
          // standing / background / eventBGM / soundEffect / loopSoundEffect /
          // mainBGM / mainBGMMute: presentation only. Effects already applied;
          // walk straight through so the player only sees real beats.
          applyPresentation(n);
          id = n.nextNodeId;
          continue;
      }
    }
  }

  // `elseText` is what a node shows when its OWN condition is false -- the
  // author's shorthand for a one-node branch.
  String bodyOf(Node n, bool gate) =>
      (!gate && n.elseText != null) ? displayElseText(n) : displayText(n);

  void finish([Node? n]) {
    eventState[event.id] = 2;                           // 2 == completed
    closePopup();
  }
}
```

Choices are inline on the `option` node:

```json
"options": [
  { "text": "…", "translatedOptionText": "Thank you!",
    "nextNodeId": 263012, "nextBoxId": 1 },
  { "text": "…", "translatedOptionText": "Whatever.",
    "nextNodeId": 263019, "nextBoxId": 2, "conditionSet": { … } } ]
```

`boxId` groups nodes into branches; `nextBoxId` names a branch's entry node and
is the fallback when `nextNodeId` is absent.

### 6.4 Selection

```dart
// RECONSTRUCTED
Event? pickEvent() {
  final section = currentSection();                   // one..six over the 31 days
  final eligible = events.where((e) {
    if (eventState[e.id] == 1) return false;          // already mid-run
    if (e.section != 'none' && e.section != section) return false;
    return evaluate(e.conditionSet);
  }).toList();

  // (a) Scheduled content fires as soon as it is eligible, by priority.
  final pinned = eligible.where((e) => !e.isRandomDate).toList();
  if (pinned.isNotEmpty) {
    pinned.sort(byPriority);                          // veryHigh, then middle
    return pinned.first;                              // ties: customPriority, then id
  }

  // (b) Otherwise a weighted random draw, capped per day.
  if (eventsFiredToday >= rules.maxEventsPerDay) return null;
  if (rng.nextDouble() >= rules.eventChancePerTick) return null;

  // Draw the SET first (sets carry their own weight), then the beat within it.
  final set = weightedPick(setsOf(eligible), weightOf: (s) => s.weight);
  final pool = eligible.where((e) => e.eventSetId == set?.id).toList();
  return weightedPick(pool.isEmpty ? eligible : pool,
                      weightOf: (e) => rules.rankWeights[e.rank]!);
}
```

Measured distributions over the 147 English events:

| field | values |
|---|---|
| `isRandomDate` | false **82** (scheduled), true **65** (random) |
| `priority` | middle 146, veryHigh **1** (event 104, the pro-gamer ending) |
| `rank` | C 131, B 12, A 4 |
| `section` | none 90; one 9, two 11, three 11, four 10, five 8, six 8 |

**Sets are drawn before events.** `event_sets.json` gives each set its own
`rank` and `weight` (0.5 to 5) — weights only make sense at the level they are
attached to, so a storyline advances one beat at a time rather than competing
beat-against-beat with 146 others. Set 16 "Location Lock" has weight **5** and
set 13 "Gym" weight **4**; those are the most frequent interruptions in the game.

**`isFake` events (3 of 147)** are silent bookkeeping: they fire and apply their
changers but open no dialogue. In the English campaign they are 162
(불법 채굴 원상복구, "restore illegal mining site"), 122 (손님과 데이트 원상복구) and
123 (손님의 저주 원상복구) — all three *undo* a previous state change. They must
still run.

### 6.5 The 18 storylines — English build

| set | `name` (source is Korean; the events are English) | rank | w | events | nodes |
|---|---|---|---|---|---|
| 2 | 친구와의내기 — Bet with a Friend | C | 1 | 2 | 33 |
| 4 | 거지의구걸 — Beggar's Begging | C | 1 | 4 | 69 |
| 5 | 콤플렉스극복 — Overcoming Weaknesses | C | 1 | 2 | 38 |
| 6 | 미술관 — Art Gallery | B | 0.5 | 2 | 27 |
| 7 | 일진 — Street fighting | A | 1 | 5 | 297 |
| 8 | 수학경시대회 — Math Contest | B | 1 | 2 | 23 |
| 9 | 영어대회 — English Vocab Contest | B | 1 | 2 | 21 |
| 10 | 금광 — Gold Mine | B | 0.5 | 3 | 40 |
| 11 | 아이돌 — Idol | A | 1 | 5 | 104 |
| **12** | **필수 — Mandatory (the spine)** | C | 1 | **18** | 290 |
| 13 | 헬스장 — Gym | B | **4** | 5 | 57 |
| 14 | 알바고백 — Confession at the Part-time Job | B | 1 | 13 | 273 |
| 15 | 프로게이머 — Pro Gamer | A | 1 | 5 | 311 |
| **16** | **장소락 — Location Lock** | B | **5** | 4 | 49 |
| 17 | 기업가 — Entrepreneur | A | 1 | 9 | 158 |
| 18 | 축구세트 — Soccer | A | 1 | 5 | 153 |
| 19 | 요리 — Cooking | A | 1 | 8 | 452 |
| 20 | 웹툰 — Webtoon | A | 1 | 12 | 356 |
| — | *(no set)* | — | — | **41** | 693 |

Note what the English `event_sets.json` does **not** have: no `isToggleable`,
no `unlockCondition`, no `requiredTamgooType`. There is no pre-run storyline
toggle screen and no premium-currency gate in this version. All 18 sets are
simply live. That is a materially simpler mode to rebuild.

Set contents worth knowing:

- **Set 12 "Mandatory"** — the spine: 35 Graduation Exam, 66 Supreme Elite,
  67 Elite, 68 Happy Ending, 69 Epiphany, 70 End of College Apps!, 71 Retry
  Ending, 144 Library Restoration, 145 Cheer Up Manager, 146 Reconstruction,
  and the Library study/sleep-counter utilities (210–220).
- **Set 16 "Location Lock"** — takes places away from you: 23 House on Fire,
  98 Coffee Shop Closes, 99 Park Under Construction, 110 Library Arson. The
  three restoration items (20011/20012/20013) exist to undo these.
- **The career arcs**: 7 street fighting → GOAT, 11 Idol, 15 Pro Gamer,
  17 Entrepreneur, 18 Soccer, 19 Cooking, 20 Webtoon. Each is a 5-to-12-beat
  escalation ending in its own ending (§7.4).
- **The 41 unbound events** are the ambient texture: Orthostatic Hypotension
  (5 variants), Turd (3), Smash! (3), Master of Massages (3), Fishy Vendor,
  Focus Pill, Riddle Expert, Arm Wrestling Contest, Karaoke Temptation,
  Library Work, Spring-Clean, Cushy Bed!, Discovery (5).

### 6.6 The scheduled spine — exact timetable

All 23 date-pinned conditions in the English campaign, in order. This *is* the
career storylines' schedule, and it is the cheapest high-value thing to copy:

| Date (tick) | Event | Set |
|---|---|---|
| 2023-10-17 t03 | 180 Great News | 19 Cooking |
| 2023-10-17 t03 | 188 School Comics Contest | 20 Webtoon |
| 2023-10-20 t00 | 189 Come On! | 20 |
| 2023-10-20 t06 | 190 New Office | 20 |
| 2023-10-20 t08 | 181 Generosity | 19 |
| 2023-10-20 t09 | 124 Need advice! | 17 Entrepreneur |
| 2023-10-21 t00 | 173 Watching Soccer | 18 Soccer (rank A) |
| 2023-10-22 t14 | 191 Launching My Comic! | 20 |
| 2023-10-24 t07 | 182 First Training Session | 19 |
| 2023-10-26 t09 | 125 / 126 Financial Update | 17 |
| 2023-10-29 t14 | 193 Episode 2! | 20 |
| 2023-10-30 t09 | 127 Financial Advice | 17 |
| 2023-10-31 t07 | 183 Second Training Session | 19 |
| 2023-11-01 t09 | 128 Financial Update | 17 |
| 2023-11-04 t09 | 129 Financial Update | 17 |
| 2023-11-05 t14 | 195 Episode 3! | 20 |
| 2023-11-07 t08 | 184 Third Training Session | 19 |
| 2023-11-08 t09 | 130 Financial Update | 17 |
| 2023-11-12 t14 | 197 Episode 4! | 20 |
| 2023-11-13 t08 | 131 Final Update → sets `ENDING_SW = 5` | 17 |
| 2023-11-14 t07 | 185 Final Training Session | 19 |
| 2023-11-15 t08 | 186 National Cooking Contest → sets `ENDING_SW = 7` | 19 |
| 2023-11-16 t≥0 | **35 Graduation Exam** → `START_SAT` | 12 |

Three career arcs (Cooking, Webtoon, Entrepreneur) are on fixed rails; the other
four (Street fighting, Idol, Pro Gamer, Soccer) advance on conditions instead.

---

## 7. The exam, admission and the endings

### 7.1 The flow — RECOVERED conditions, RECONSTRUCTED mechanism

The exam event's gate, verbatim from the English campaign (event 35, "Graduation
Exam", `originName` 졸업 시험, set 12):

```
EVENT_35 equal 0  AND  DATE_PROGRESS equalOrBigger 0
                  AND  DATE_DAY   equal 16
                  AND  DATE_MONTH equal 11
```

— "not yet run, a day is in progress, and it is 16 November". Node 35000 is
"Finally, it's CSAT...!", node 35001 is "Let's go!!!" carrying
`changer.funcCode: "START_SAT"`.

```dart
// RECONSTRUCTED — the terminal sequence
void startExam() {
  final card = scoreExam();                 // §7.2
  currentExamReportCard = card;
  examKoreanStatList.add(card.korean);      // the five _exam*StatList save keys
  examEnglishStatList.add(card.english);
  examMathStatList.add(card.math);
  examTamgoo1StatList.add(card.tamgoo1);
  examTamgoo2StatList.add(card.tamgoo2);

  admission = resolveAdmission(card);       // §7.3
  revealAdmissionResult(admission);
  badgeIdList.add(admission.universityBadgeId);

  switches['ENDING_CODE'] = 1;              // "endings may now fire"
  switches['IS_BEFORE_SAT_EXAM'] = 0;
  pickAndRunEvent();                        // the ending events now compete
}
```

`ENDING_CODE` is read 13 times by story-16 content and **set by no content node
anywhere in the campaign** — confirming it is the engine's own post-exam flag.

### 7.2 Scoring

The formula is compiled and not recoverable, but the native names its parts:
`examKoreanStatList`, `examEnglishStatList`, `examMathStatList`,
`examTamgoo1StatList`, `examTamgoo2StatList`, `currentExamReportCard`,
`prevExamResult`, `examDifficultyType`, `examType`, `grade`, `targetGrade`,
`score`, `deviation`, `percentage`, `averagePercent`, `VIEW_PERCENT`,
`FUNC_GET_CURRENT_EXAM_VIEW_PERCENTAGE` (English build only),
`FUNC_GET_CURRENT_EXAM_GRADE`, `GRADE`, `GRAD`, `SCORE`, `EXAM_POINT`,
`DEVIATION`.

Story 16 has **no mid-run exams** — `data/school_exam_uses.json` is
`{"useList":[]}` and there is exactly one `specialDays` entry, the CSAT, on the
final day. So you need the scoring pipeline exactly once.

```dart
// RECONSTRUCTED — the pipeline, with the right interface
ReportCard scoreExam() {
  final card = ReportCard();
  for (final s in subjects) {
    card.raw[s]   = rawScoreFrom(stats[s]!);     // monotone; NOT RECOVERABLE
    card.grade[s] = gradeBand(card.raw[s]!);     // 1 (best) .. 9 — CSAT bands
  }
  card.percentile = overallPercentile(card.raw); // 0..100 <- FUNC_IS_ENTER_UNIV_THAT_RATE
  card.percentile += passiveSum('acceptanceRate');   // Totem of Fortune +1%, etc.
  return card;
}
```

That grades run 1–9 with 1 best is confirmed by the Korean build's astronaut
ending, which requires `FUNC_GET_CURRENT_EXAM_GRADE(n) == 1` on three subjects
simultaneously — only sensible if 1 is the top band.

### 7.3 Admission

- `global_data/university/universities.json` — **137** universities,
  `{id, korName, engName, twName, rank: one…ten|none, type, sortId, colorCode,
  real, imageIsPNG}`. Prestige tiers: ten 12, nine 23, eight 11, seven 13,
  six 13, five 17, four 10, three 11, two 9, one 17, none 1. Id 0 is
  "Korea Retry Academy" (`type: notUniv`) — the failure outcome.
- `global_data/university/departments.json` — **3,358** departments
  `{id, universityId, name, deviation}`. `deviation` is the admission cutoff,
  spanning **25.3 … 80.85**; a university carries up to 56 departments.
- `global_data/university_badges.json` — the per-university collectible.

```dart
// RECONSTRUCTED
Admission resolveAdmission(ReportCard card) {
  final reachable = departments.where((d) =>
      card.percentile >= percentileFor(d.deviation)).toList();
  final best = reachable.reduce((a, b) => a.deviation >= b.deviation ? a : b);
  univEnterNumber++;  departmentEnterNumber = best.id;
  if (universities[best.universityId].rank == 'ten') topClassUnivEnterCount++;
  highestSchoolRate = max(highestSchoolRate, card.percentile);
  return Admission(university: universities[best.universityId], department: best);
}
```

Calibrate `rawScoreFrom` and `overallPercentile` so an optimised 31-day run
lands near 99 and a lazy one below 80 — §7.4's thresholds tell you exactly where
the bands must sit.

### 7.4 The 14 endings — exact triggers, English build

Ending codes are `storyId × 10000 + n`. The English campaign contains **14**
`END_GAME` nodes, matching `global_data/endings.json`'s 160001–160014 exactly.

| code | Ending name (from `END_GAME` args) | Event | Trigger (plus `ENDING_CODE == 1` and `EVENT_<self> == 0`) |
|---|---|---|---|
| 160004 | Super Elite Ending | 66 Supreme Elite | `RATE(99)` ∧ `ENDING_SW == 0` |
| 160005 | Elite Ending | 67 Elite | `RATE(95)` ∧ ¬`RATE(99)` ∧ `ENDING_SW == 0` |
| 160006 | Happy Ending | 68 Happy Ending | `RATE(90)` ∧ ¬`RATE(95)` ∧ `ENDING_SW == 0` |
| 160007 | Enlightenment | 69 Epiphany | `RATE(80)` ∧ ¬`RATE(90)` ∧ `ENDING_SW == 0` |
| 160008 | End of the Line | 70 End of College Apps! | ¬`RATE(80)` ∧ `SUCCESS_LENGTH ≥ 1` ∧ `ENDING_SW == 0` |
| 160009 | Second Try Ending | 71 Retry Ending | `SUCCESS_LENGTH == 0` ∧ `ENDING_SW == 0` |
| 160001 | Nationwide Champion | 40 GOAT | `TRAIT_HAVE(160001)` ∧ `ENDING_SW == 1` |
| 160002 | Retired Champion | 40 GOAT (other branch) | `TRAIT_HAVE(160001)` ∧ `ENDING_SW == 1` |
| 160003 | Ultimate Idol | 52 Idol Ending | `TRAIT_HAVE(160002)` ∧ `ENDING_SW == 3` |
| 160010 | World Champion Gamer | 104 International Contest (**veryHigh**) | `TRAIT_HAVE(160006)` ∧ `ENDING_SW == 4` |
| 160011 | Successful Entrepreneur | 132 | `TRAIT_HAVE(160007)` ∧ `ENDING_SW == 5` |
| 160012 | Soccer Star Ending | 177 | `TRAIT_HAVE(160011)` ∧ `ENDING_SW == 6` |
| 160013 | Master Chef | 187 Ending | `ENDING_SW == 7` |
| 160014 | Comic Artist Ending | 199 | `ENDING_SW == 8` |

The structure is clean and worth copying exactly:

- **`ENDING_SW == 0` means "no career claimed"**, and then six endings fire on
  percentile bands: **≥99 Super Elite, 95–99 Elite, 90–95 Happy, 80–90
  Enlightenment, <80** split by the study combo — *End of the Line* if you ever
  built one, *Second Try* if `FUNC_GET_SUCCESS_LENGTH == 0`, i.e. you never once
  studied the same subject twice in a row and so never engaged with the
  mechanic at all. That is a lovely piece of design; keep it.
- **Career endings set `ENDING_SW` to a unique small integer** at their
  storyline's climax, which both selects the ending and suppresses the stat
  endings. The complete set of setters in the English campaign:

  | `ENDING_SW` | set by node | event |
  |---|---|---|
  | 1 | 39061 | 39 Final Encounter (street fighting) |
  | 3 | 51015 | 51 3rd Feedback (idol) |
  | 4 | 103017 | 103 Fighting the Pros (pro gamer) |
  | 5 | 131013 | 131 Final Update (entrepreneur) |
  | 6 | 176014 | 176 Overseas Match (soccer) |
  | 7 | 186048 | 186 National Cooking Contest (chef) |
  | 8 | 198021 | 198 Readers' Response (webtoon) |

- Five career endings **also require a story-scoped trait** awarded by the arc
  (160001, 160002, 160006, 160007, 160011 — same `storyId × 10000` id space).
- Event 40 "GOAT" carries two `END_GAME` nodes on different branches, which is
  how one arc yields two endings (160001 / 160002) from a player choice.

`endings.json` also gives each ending a `cookieCount` (1–5 premium-currency
reward for a first clear) and `isSpecialEnding`. The English native contains
named handlers `ending160001 … ending160014` plus `ending160017/18/19`, so the
engine was already forward-compatible with the Korean build's later additions.

---

## 8. Weekly Goals and Sudden Missions

### 8.1 Weekly Goals

Engine-side names: `goalContainer`, `currentGoal`, `normalGoal`, `hardGoal`,
`goalSuccessList` / `_goalSuccessList`, `goalReward`, `goalRewardStat`,
`goalPowerType`, `percentPlusReward`, `targetStat`, `SET_STUDY_GOAL`,
`SHOW_GOAL_DIALOG`, and the tutorial step `te_9_weekly_goal_69_start/_end`.

What the UI strings establish:

- *"Weekly Goals are renewed every Monday."* The run starts on Monday 16 Oct,
  so a 31-day run is **4 full goal weeks + 3 days**.
- A goal row reads **`Phys I 398 → Math +294`**: hit 398 in one subject this
  week, receive +294 in another. The row is Dart string interpolation with the
  number at element offset 15 — i.e. **thresholds and rewards are generated at
  runtime, not authored**.
- Outcomes: *"Weekly Goals Met!"*, *"Weekly Goals completed."*, *"Weekly Goals
  Failed"*, *"goal reward provided."*, *"added to user's trait list by goal
  reward"* — rewards can be stats **or traits**.
- Two difficulties exist (`normalGoal`, `hardGoal`) and the reward scales:
  items 3001 Study Planner (+5%) and 3029 Study Hen (+15%), both *"effect begins
  the week after obtaining"*; a `goalReward` trait; elite tiers; and a string
  *"Upcoming Weekly Goals stat rewards +30%"*.

**Implemented timing (A08/A09, 2026-10-25).** The sketch below pays on the
Monday rollover; the user's V02 recording instead shows a *"Weekly Goals
Met"* popup mid-day, with objective, reward and Confirm. `Goals.settleIfMet`
therefore pays the moment the threshold is reached (after an action, an
event, or an item) and the host shows `GoalMetDialog`; Monday only reports a
failure. The final partial week is settled on the rollover into exam day. The
reward is snapshotted with the modifiers held when the goal is *issued*, so a
planner bought midweek counts from the next goal, as its text says. Saves
from before carry `rewardFinal: false` and keep the old payout-time bonus.

```dart
// RECONSTRUCTED
void rolloverWeeklyGoals() {
  if (currentGoal != null) {
    final met = stats[currentGoal!.subject]! >= currentGoal!.threshold;
    goalSuccessList.add(met);
    if (met) {
      final bonus = 1 + passiveSum('goalReward') / 100;
      addStat(currentGoal!.rewardSubject,
              (currentGoal!.rewardAmount * bonus).round());
      if (currentGoal!.rewardTraitId != null) traits.add(currentGoal!.rewardTraitId!);
      notify('Weekly Goals Met!');
    } else {
      notify('Weekly Goals Failed');
    }
  }
  currentGoal = generateGoal(week: weekIndex, difficulty: goalDifficulty);
  showGoalDialog(currentGoal!);                 // SHOW_GOAL_DIALOG
}
```

### 8.2 Sudden Missions — RECOVERED templates

`global_data/sudden_missions.json`, complete, nine entries. The verb
`SHOW_SUDDEN_MISSION` exists in the English native; counters are
`suddenMissionClearCount` and `_suddenMissionCountList`.

| `funcCode` | difficulties | meaning |
|---|---|---|
| `MONEY_OVER` | hard | finish holding more than N gold |
| `STAT_OVER` | normal, hard | get a subject above N |
| `HP_EXACTLY` | normal | be on exactly N stamina |
| `HP_EXACTLY_FINISH` | hard | *finish the day* on exactly N stamina |
| `HP_NOT_UNDER` | normal, hard | never drop below N |
| `HP_BETWEEN` | normal, hard | stay between N and M |

The native also has `STAT_EXACTLY`. Targets are generated at runtime
(`SUDDEN_MISSION_CODE`); the engine also marks risky places
(`LOCATION_WARNING_FACTOR_`, `WARNING_LOCATION_PERCENT_FACTOR`,
`TURN_OFF_WARNING_MISSION`, `RELOAD_WARNING_SWITCH`).

---

## 9. Progression tables — English build, exact

### 9.1 Study level — `global_data/study_levels.json`

| Lv | Name | cumulative EXP | `plusStat` |
|---|---|---|---|
| 1 | Student | 0 | 0 |
| 2 | Hardworking Student | 1,500 | 1 |
| 3 | Model Student | 15,000 | 2 |
| 4 | Elite | 40,000 | 2 |
| 5 | Genius | 70,000 | 3 |
| 6 | The Enlightened | 100,000 | 4 |
| 7 | First Class | 150,000 | 5 |
| 8 | Mythic | 200,000 | 6 |
| 9 | Legendary | 300,000 | 7 |
| 10 | Godly | 500,000 | 8 |

### 9.2 Exercise level — `stories/16/data/exercise_info.json`

Levels 0–10, named generically `Level 0 … Level 10` in the English build (the
Korean originals are the gym joke "Big 3 of 0/100/…/1000"). EXP thresholds
0, 300, 900, 1600, 2700, 4000, 4700, 5800, 7000, 8300, 10000; `weight`
1.0 → 11.0 in steps of 1. `locationEfficiencyList` has only `{1000: 1.0}` and
`{2000: 1.0}`; `exerciseTextInfoList` is empty.

Level 8 (7,000 EXP) is a content threshold — item 3028 "Level 8 Suit" keys off
it.

### 9.3 Part-time level — `stories/16/data/part_time_job_info.json`

Levels 1–10, EXP 0, 300, 1000, 1600, 2600, 4000, 5600, 7600, 10000, 16600;
`weight` 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5. Level **names are
left untranslated** in the English build (초보자 Beginner → 초월자 Transcendent).

`partTimeJobTextInfoList` is fully English and gives **ten shift descriptions
per location, indexed by part-time level** — the cheapest way to make the loop
feel alive. Eight locations have them; the first three of each:

| Location | Lv 1 → 3 … |
|---|---|
| 1000 School | Buy Bread · Clean Classroom · Clean Teachers' Office |
| 2000 Home | Give Massage · Pluck White Hair · Clean House |
| 16000 Art Gallery | Painting Appreciation Report · Doodle on Painting · Color Painting |
| 16001 Gold Mine | Mine Rocks · Mine Copper · Mine Silver |
| 16002 Park | Pick Up Trash · Recycle · Burn Trash |
| 16003 Library | Arrange Books · Organize Returned Books · Library Errands |
| 16004 Café | Clean Coffee Shop · Clean Coffee Shop Restroom · Wait Tables |
| 16007 Football Field | Pick Up Balls · Pick Up Trash · Weeding |

### 9.4 Books — `global_data/book/<subject>/<rank>_book_<subject>.json`

54 books, six ranks per subject.
`{id, name, description, condition, bookRank, subject, power, doneCount,
extraDoneCount, hpWeight}`.

- `power` by rank: 1→5, 2→7, 3→10, 4→15, 5→22, 6→35. This is the study-gain input.
- `doneCount` by rank: 8, 11, 13, 16, 21, 31 — reads needed to **finish** a book,
  which is a real event (`BOOK_DONE`, `DONE_BOOK_`, `UNLOCK_BOOK_CODE`; a trait
  grants an item *"every time you finish a book"*). `extraDoneCount` (4–8) is the
  bonus run past completion.
- `condition` unlocks the book: `{"type":"none"}`,
  `{"type":"after", subjectType, stat}` or `{"type":"stat", subjectType, stat}` —
  higher-rank books unlock as stats rise. That *is* the study progression.
- Distribution: science 15, society 13, math 9, english 9, korean 8.

Rank-1 and rank-6 of each subject, to anchor the curve: Korean Textbook (5) →
Create a New Language (35); Math Textbook → Solve All Conundrums; English
Textbook → Acquire Citizenship; Social Studies Textbook → World Peace / Build
Egyptian Civilization; Science Textbook → Win Nobel Prize / Run Faster than
Light.

### 9.5 Traits — `global_data/traits.json`, 244, effects already data

The one system you get for free: **traits ship their `effectList` as JSON.**
219 good, 24 bad, 1 normal; ranks S 26, A 55, B 46, C 30, none 87; `gachable`
marks trait-pack drops.

Eleven effect types, with usage counts:

| type | n | meaning |
|---|---|---|
| `plusStat` | 137 | flat add to a study gain (`extraStat`, `storyStat`, `subjectType`, `plusStatType: detail\|all`) |
| `hpCost` | 22 | stamina-cost delta (negative = discount) |
| `partTimeJobMoney` | 22 | pay modifier |
| `firstPlusStat` | 9 | one-off starting stat |
| `exerciseExp` | 6 | exercise-EXP modifier (`percentPlusExp`) |
| `plusSleepHp` | 3 | sleep-restoration delta |
| `firstPlusMoney` | 2 | starting cash |
| `schoolStudyPlusStat` | 1 | bonus on Class blocks only |
| `goalReward` | 1 | Weekly Goal reward multiplier |
| `firstExerciseLevel` | 1 | start at an exercise level |
| `firstPlusPartTimeJobLevel` | 1 | start at a part-time level |

`first*` applies once at run start; the rest feed `passiveSum`. Effects may carry
`conditions` on `LOCATION_ID`, `LOCATION_TYPE`, `TICK`, `PREV_STUDY_SUBJECT`,
`EXERCISE_LEVEL`, `PART_TIME_JOB_LEVEL`, `STUDY_LEVEL`, `DATE_INT`. Traits also
have `initialLifeTime` (temporary), `locationIdList`/`locationType` (scope) and
`storyId`.

Copy these verbatim as calibration points:

```json
{ "id": 1, "name": "TOEIC 800", "rank": "C", "type": "good", "gachable": true,
  "description": "Initial English Stats +100",
  "effectList": [ { "type": "firstPlusStat", "plusStatType": "detail",
                    "subjectType": "english", "stat": 100 } ] }

{ "id": 5, "name": "Night Owl", "rank": "B", "type": "good",
  "description": "Stamina Cost -3 in the last five ticks",
  "effectList": [ { "type": "hpCost", "cost": -3,
                    "conditions": [ { "target": "TICK",
                                      "compareType": "greaterEqual",
                                      "intValue": 10 } ] } ] }

{ "id": 7, "name": "Out of Shape", "rank": "none", "type": "bad",
  "description": "Stamina Cost +3\nRegular exercise might help…",
  "effectList": [ { "type": "hpCost", "cost": 3 } ] }
```

Trait 5 proves the stamina-cost formula must be **tick-aware**.

### 9.6 Items — 103 total for a story-16 run

| file | count | kind |
|---|---|---|
| `stories/16/item/story_consume_items.json` | **25** | consumable, story-scoped |
| `stories/16/item/story_normal_items.json` | **12** | held/passive, story-scoped |
| `global_data/item/global_consume_items.json` | 38 | consumable, all stories |
| `global_data/item/global_normal_items.json` | 28 | held/passive, all stories |

The 37 story items in full (`id | name | effectText`):

```
consumable
20003 Silver Ring                 Sell for 20000 Gold
20004 Butter Cookie               Stamina +30                            [food]
20005 White Cookie                Korean stat +CONSUME_STAT_150           [food]
20006 Yellow Cookie               Science stat +CONSUME_STAT_150          [food]
20007 Green Cookie                Social Studies stat +CONSUME_STAT_150   [food]
20008 Red Cookie                  English stat +CONSUME_STAT_150          [food]
20009 Black Cookie                Math stat +CONSUME_STAT_150             [food]
20010 Emerald Cookie              All Stats +CONSUME_STAT_150             [food]
20011 Library Restoration Ticket  Restores Library.
20012 The Cheer Up! Book          Restores Café.
20013 House Blueprint             Restores Home.
20014 Creme Brulee                Maths +300
20015 Grilled Fish                Korean +300
20016 Korean Soft Tofu Stew       English +300
20017 Master's Masterpiece        All subject stats +100
20018 Strangely Creative Notes    Check requirements
20020 Cure-All                    Removes all negative Traits.
20021 Red Potion                  Stamina +100
20022 Focus Potion                Study efficiency for all subjects +15 the day consumed.
20023 Golden Potion               All Stats +50
20024 Ultimate Potion             All Stats +100, Stamina Cost -3 the day consumed.
20025 Better Emerald Cookie       All Stats +400
20026 Better Black Cookie         Stats of selected subject +400
20027 Better Purple Cookie        Sell for 5000 Gold
20028 Beggar's Repayment          All Stats +100

held (maxCount 1 unless noted)
30001 Art Gallery Ticket          Used to enter Art Gallery
30002 Bouquet                     Wait, what...?                        (flavour)
30003 Anti-Headrush Band          Prevents Head Rush
30004 Park Owner                  Prevent Park Renovation from happening
30005 Romanticist Spirit          Study Efficiency in Art Gallery +NORMAL_STAT_3  [loc 16000]
30006 Renaissance Spirit          Study Efficiency in Art Gallery +NORMAL_STAT_3  [loc 16000]
30007 Neo Classicism              Study Efficiency in Art Gallery +NORMAL_STAT_3  [loc 16000]
30008 Mining Permit               Protection against mine security      [loc 16001]
30009 Super Drill                 Gold Mine Efficiency +20%             [loc 16001]
30010 Non-Slip Shoes              Prevents slipping on dog droppings.
30011 How to Haggle               Get things at a cheaper price from the Peculiar Peddler
30012 Become a Dishwasher         Prevent mistakes in the Café.
```

Note the clean subject mapping of the cookies in this build (White→Korean,
Yellow→Science, Green→Social Studies, Red→English, Black→Math, Emerald→all),
and that the three "Restores X" items pair exactly with set 16 Location Lock.
Several held items are pure **insurance** against specific ambient events
(Anti-Headrush Band vs. Orthostatic Hypotension, Non-Slip Shoes vs. Turd, Park
Owner vs. Park Under Construction, Become a Dishwasher vs. the Café mistake) —
that interlock is worth preserving.

Global held items show the scope vocabulary: 3012 Pet Rock *Stamina Cost −1*;
3023 Calculator *Part-Time earnings +20% at [Part-Time Locations]*; 3027
Stopwatch *Study Efficiency +NORMAL_STAT_4 at [Study Locations]*; 3010 Yoga Mat
*Exercise Efficiency +10% at {HOME}*; 3016/3017 *Sleep Efficiency +2 at
{SCHOOL}/{HOME}*; 3004/3007/3011 *acceptance rate +1% / +0.1% / +2%*;
3001/3029 *Weekly Goals rewards +5% / +15%*; 3028 Level 8 Suit.

### 9.7 Equipment (stationery) — 72 items, 18 sets

Equipped before a run (*"Tap on stationery to equip item"*).
`{id, name, type: pencil|…, rank, studyStats: [{isAll, subjectType, stat}], setId}`
plus `equipment_item_sets.json` giving `{equipmentItemIds, studyStats}` for the
set bonus. Example: id 0 "Seoul Pencil", rank S, society +9, setId 0 "Seoul
Stationery Series" (ids 0–3), set bonus all +5. All 18 sets now apply in the
engine and active sets are named in the stationery menu. Weekly draws appear
Thursday after Wednesday's summary, before the new-day menu. Two-to-four-copy
combination, tier styling, redraw locks, and saved pending draws are implemented.
See [STATIONERY.md](STATIONERY.md) for recovered evidence and the explicitly
provisional probability tables; original combination odds remain unresolved.

### 9.8 Elite levels — 37 tiers

`global_data/elite_levels.json`, a parallel meta track with its own EXP curve and
an `effectList` in the trait vocabulary (e.g. *Korean base stats +40*, *Sleep
Recovery +1 in Sleep Locations*, *Exercise EXP 4%*, *Part-time Efficiency +10%*,
*Starting Cash 1000 Golds*, *Upcoming Weekly Goals stat rewards +10%*, *Stamina
cost −1*). Tiers 1–35 cost 450–900 each; tier 36 costs 100,000 and is terminal.
Low priority.

---

## 10. Character select, and the screens around the run

```
Title
 └─ Select Mode ──► [One Month Mode (D-31)]
      └─ Save slot select            (multiple slots; each has a delete button)
           └─ Character select       (26 characters available to story 16)
                └─ Pre-run: equip stationery, pick starting traits (_firstTraitList)
                     └─ 31 days × 15 ticks        (§2–§6)
                          └─ Day 32: CSAT → admission → ending   (§7)
```

### To-do: character selection screen

The complete five-step flow and initialization contract are recorded in
[START-GAME-INITIALIZATION.md](START-GAME-INITIALIZATION.md), with versioned
pseudocode/catalog provenance and unresolved Global rules called out separately.

The rebuild still needs the step 5/5 first-name / last-name entry UI. Runs now
save those fields, and the retained Korean `{이름}`, `{성}`, and `{성이름}`
event variables are fixed to use them. Until name entry is implemented, new
runs inherit `pack.json.start` names. Keep the substitution fix when adding
selection; see [EVENT-PRESENTATION.md](EVENT-PRESENTATION.md) and the local
`references/screenshots/` folder for the naming screenshot and text contract.

`global_data/characters.json` holds 65 characters; **26 list 16 in
`availableStoryIds`**. Each is `{id, firstName, lastName, description,
genderType, rank: one|two|three, effectDescription, plusEffect, specialFuncCode,
isDefault, availableStoryIds, gachaPackTypes, skeleton, expressions[],
clothesList[], otherLayerList[], backgroundImgPath, colorValue}`.

Two kinds of character effect:

- **`plusEffect`** — a structured passive in the trait vocabulary. 10 Lil'
  Brother `{firstPlusMoney: 2500}`; 16 Jaehyun Kim `{exerciseExp,
  percentPlusExp: 1.05}`; 21 Hannah Kim `{partTimeJobExp, percentPlusExp: 1.05}`;
  17 Siho Kang `{plusStat, detail, korean, extraStat: 6, storyStat: 2}`;
  18 Sieun Kang the same for english.
- **Compiled behaviours** described only in `effectDescription` — and crucially,
  **some add action blocks**, which is where §3.2's gated `special` actions come
  from:
  - 70/71 Med Student Ihyeon — *"Medicine Block added. Craft various
    medicines."* → sets `MEDICAL_BLOCK_CONDITION`
  - 74 Hyunho Park — *"Adds Collect Mechanical Parts Block. Craft various Robot
    Traits."* → `MECHANIC_BLOCK_CONDITION`
  - 6/9 SeoA/Seowoo Shin — *"Bake random cookies at home"*; 72/73 bake better ones
  - 3/4 Beggar / Scouter Beggar — *"Occasionally gets money from students"*
  - 75 Successful Beggar — *"Generates huge profits using stocks"* (the
    `STOCK_SW` / `FIRST_STOCK_GO` / `STOCK_MANAGER` switches, which are the most
    referenced non-ending switches in the campaign: 20 and 22 conditions)
  - 5 Teacher, 7/8 Ihyeon Kang, 13/14 Geum siblings, 15 Hypnotist, 19/20
    Haeseol, 22 Kid — each a periodic bonus

Full roster: 1 Default Boy, 2 Default Girl, 3 Beggar, 4 Scouter Beggar,
5 Teacher, 6 SeoA Shin, 7 Ihyeon Kang (F), 8 Ihyeon Kang (M), 9 Seowoo Shin,
10 Lil' Brother, 13 Taeyang Geum, 14 Harin Geum, 15 Hypnotist, 16 Jaehyun Kim,
17 Siho Kang, 18 Sieun Kang, 19 Haeseol Na, 20 Haeseol Nam, 21 Hannah Kim,
22 Kid, 70/71 Med Student Ihyeon (M/F), 72 International Student SeoA,
73 International Student Seowoo, 74 Hyunho Park, 75 Successful Beggar.

Character choice also drives `FUNC_IS_MALE` / `FUNC_IS_FEMALE` and
`FUNC_IS_IN_CHARACTER_LIST`.

### The onboarding sequence — RECOVERED

The native holds 15 tutorial-element keys as `te_<n>_<name>_<eventId>_start|_end`.
They are story 14's, but they tell you the order the game teaches its own
mechanics, which is the order your UI should reveal them:

```
te_1_prologue_1             te_2_hr_2                te_3_too_overwhelmed_6
te_4_sleep_is_important_3   te_5_leave_school_4      te_6_exercise_hard_8
te_7_favor_56               te_8_donation_16         te_9_weekly_goal_69
te_10_practice_exam_70      te_11_practice_exam_result_71
te_12_exam_eve_61           te_13_advice_62          te_14_sorry_72
te_15_graduation_exam_64
```

So: prologue → homeroom → overwhelm → sleep matters → leave school → exercise →
a favour → a donation → **weekly goals** → practice exam → its result → exam eve
→ advice → apology → graduation exam.

---

## 11. What is not recoverable, and what to fit it to

Put every one of these in a single tuning file. That is what
`d30mode/packs/kss16/rules.json` is for, and it is the difference between a game
you can balance in minutes and one you have to recompile.

| Unknown | Why | Fit it to |
|---|---|---|
| `blocksPerTick` | compiled | 4–6; weights span 0.3–12, so the hand must be small enough for weight to matter |
| Study gain formula | compiled | `f(book.power, studyLevel.plusStat, efficiency, combo)`. Rank-1 book early ≈ 50; rank-6 late ≈ 500+; a maximal run must clear percentile 99 |
| Part-time pay | compiled | `base × partTimeLevel.weight × locationFactor + earnings`. Calibrate against what events charge (`DECREASE_MONEY`, 26 sites) and item sale prices (20003 = 20,000; 20027 = 5,000) |
| Exercise EXP per session | compiled | Level 8 (7,000 EXP) must be reachable in 31 days; level 10 is 10,000 |
| Sleep restoration | compiled | ~60 plus a `sleep`-type location bonus; must make a 15-tick day sustainable |
| Exhaustion penalty | compiled | A flat all-subject loss plus the rest of the day |
| Random-event rate / daily cap | compiled | A few beats a day. `d30mode` uses 0.12 per tick, cap 3, rank weights A 1 / B 2 / C 4 |
| Exam scoring + percentile | compiled | The §7.2 pipeline, calibrated against the §7.4 bands (99 / 95 / 90 / 80) |
| Weekly Goal thresholds and rewards | generated at runtime | Expected weekly stat growth; honour `goalReward` multipliers |
| Sudden Mission targets | generated at runtime | The nine templates in §8.2 |
| `CONSUME_STAT_<n>` / `NORMAL_STAT_<n>` multipliers | compiled | Keep `n` as the base; one global multiplier each |
| Item effect bodies | compiled, but **named** (199 `itemEffect*` functions) | Parse `effectText` with `tools/item_effects.py`, cross-check against the function names |
| Special-track mechanics (idol / pro gamer / mechanic / medical / soccer / draw) | compiled | Each advances a counter; the content keyed to the counter is all in the data |

---

## 12. Build order for a deadline

1. **Calendar and day loop** — `DATE_YYYYMMDDTT`, 31 days × 15 ticks,
   `nextTime` / `endToday` including the switch-namespace reset (§2.3–2.4).
   *Half a day.*
2. **Locations and the block draw** — load `locations.json`, the five action
   behaviours, weighted hand, `blockDuplicated`, `conditionFuncCode` gates,
   tick-aware `hpWeight` (§3). *One day.*
3. **Progression tables** — the four exact tables in §9.1–9.4, book unlock
   conditions, `doneCount` completion. *Half a day.*
4. **Conditions and changers** — the recursive evaluator, 17 `FUNC_`s, 27 verbs,
   the engine pseudo-switch mirror, tri-state event codes (§4–5). This is the
   gate to all 3,444 nodes, so it pays for itself immediately. *One day.*
5. **Node walker** — 11 node types, `ifElse`, `option`, `elseText`, box
   branches, cycle guard, `isFake` silent events, and the
   `translatedText`/version display rule (§6.2–6.3). *One day.*
6. **Event selection** — scheduled by date and priority (the §6.6 timetable),
   random by set weight then event, with `section` and the daily cap. *Half a day.*
7. **Items and traits** — 103 items via the existing parser, 244 traits straight
   from JSON, passive sums with location scope and conditions (§5.4, §9.5–9.6).
   *One day.*
8. **Exam → admission → endings** — `START_SAT`, the scoring pipeline, 3,358
   departments by `deviation`, `ENDING_CODE = 1`, the 14 triggers in §7.4.
   *One day.*
9. **Weekly Goals and Sudden Missions** — Monday rollover, generated
   threshold/reward, the nine mission templates (§8). *Half a day.*
10. **Presentation** — backgrounds (89), standings, BGM (42), SFX (61), speaker
    names from the 40 NPCs. *Open-ended.*

Steps 1–7 already exist in `d30mode/`, covered by 21 tests including 200 seeded
full runs that all reach exam day. Steps 8–9 plus the corrections in §13 are the
real remaining work.

---

## 13. Gaps and divergences in the existing `d30mode` rebuild

Read this before trusting that code as a reference implementation.

| Area | State | Fidelity |
|---|---|---|
| Calendar, locations, actions, levels, books | implemented from JSON | faithful |
| Condition language, `FUNC_` registry, verb registry | implemented | faithful |
| Node walker (types, options, `elseText`, cycle guard) | implemented | faithful |
| Traits (244) | implemented in `lib/engine/traits.dart`: all 11 effect types, all 16 condition targets, trait scope, story scoping and the nine temporary lifetimes | faithful — traits ship effects as JSON. Two readings had to be settled from the catalog's own descriptions: `storyStat` is the base and the story scales it by `rules.traits.statScale` (3), while `extraStat` is the already-scaled number; and `percentPlus*` fields are **factors** (`1.2` is +20%), not percentages |
| Trait selection | **not built** — traits arrive only from `ACQUIRE_TRAIT` and the dev panel | gap: the character-select trait step is in `docs/START-GAME-INITIALIZATION.md` §4/5 |
| Items, effects parsed from `effectText` | implemented | derived, not recovered; now cross-checkable against the 199 `itemEffect*` names (§5.4) |
| **Content source** | built from the **Korean** `campaign-localized-v2/story-16` (322 events / 13,173 nodes, 97.3% translated) | **divergent from this spec** — the English build's own story 16 is 147 events / 3,444 nodes, fully English, and is the simpler target. Point `tools/build_pack.py` at `kss/assetpack1_dec/assets/assets/stories/16/` and read `translatedText` |
| `weight` semantics | used as a **payout multiplier**, actions shown as a static list | **divergent** — it is the block **draw weight** (§3.3) |
| Event state | tri-state 0/1/2 in `GameState.eventStates`, set to 1 on `EventRun.start` and 2 at the single exit `_endBeat` | faithful (§4.2). The fire count is kept alongside it for the dev panel only |
| Storyline prerequisites | `tools/build_pack.py` adds `EVENT_188 == 2` to #189 "Come On!" (`SET_PREREQUISITES`) | **divergent, deliberately** — the shipped event carries only its date and relies on compiled set sequencing, so without this the teacher takes you to the comic club whether or not you ever drew a comic. Written in the data's own idiom (`EVENT_191 == 2` gates #192). Delete the overlay if set-first selection is ever built and supersedes it |
| Workout block at max exercise level | `Game.availableActions` drops `exercise` once `exerciseLevel == exerciseLevels.maxLevel` (10) | **not recovered** — a house rule: at the cap a workout earns nothing, so it stops being dealt. All ten locations that offer it keep at least two other actions, so no draw pool empties |
| Out of Shape at max exercise level | `GameState.setSwitch` pins `TRAIT_EVENT_7` to 0 while the level is capped | **not recovered** — the global trait event 10010003 ("Out of Shape", trait 7) has exactly one condition, `TRAIT_EVENT_7 == 1`, so holding the switch down is what makes it unreachable. `REMOVE_TRAIT_FROM_EXERCISE` now clears the switch and the trait, as its name says |
| `isFake` events | **excluded from selection** | **divergent** — they must fire silently (§6.4) |
| Event sets | metadata loaded, **not used in selection** | **gap** — sets carry the weights, so the draw must go set-first; 200 seeded runs currently reach only 118 of 322 events |
| Engine pseudo-switches | partially mirrored | **gap** — `COMBO_STUDY`, `PREV_BLOCK_TYPE`, `TIME_TO_MOVE_LOCATION`, `LOCATION_TYPE`, `IS_BEFORE_SAT_EXAM`, `WEEKCODE` are missing, and the nightly reset in §2.3 is not implemented |
| Exam, admission, endings | `rules.exam.enabled = false`; exam predicates return 0; a run just ends on exam day | **gap** — all of §7 unbuilt, though content calling `END_GAME` does set an ending |
| Weekly Goals, todos, Sudden Missions | `ADD_TODO`/`REMOVE_TODO` accepted and do nothing | **gap** (§8) |
| Refresh Tickets / reroll | not implemented | **gap** (§3.3) |
| Book completion (`doneCount`) | `doneCount` carried, not read | gap |
| Equipment, elite levels | not loaded / loaded but unused | gap, low priority |
| Presentation | parsed and walked, nothing rendered or played | gap; `npcs.json` absent from the pack so dialogue is unattributed |

### One note on the Korean build, and then no more

The Korean 1.61 build's story 16 is a **later superset** of the same campaign:
322 events / 13,173 nodes, 44 event sets (27 of them gated behind a premium
cookie purchase), 111 story items, a sixth special track (Psychic), 21 endings
instead of 14, and additional engine verbs. If you ever want that content, the
schema in this document reads it unchanged — the only structural additions are
`isToggleable` / `unlockCondition` / `requiredTamgooType` on event sets. Nothing
else here changes. Build against the English campaign first.

---

## 14. One-page cheat sheet

```
MODE        story 16 "31-Day Mode" / 한 달 모드 — gameMode=extra, extraType=base
            family siblings (out of scope): 18, 20, 68 — also gameMode=extra
            reached from the fixed "One Month Mode (D-31)" button

CALENDAR    DATE_2023101600 (Mon) → DATE_2023111600 (CSAT). 31 playable days.
            DATE_YYYYMMDDTT, TT = tick 0..14 → 15 ticks/day → 465 slots.
            Weekly Goals renew every Monday. No mid-run exams.

RESOURCES   Stamina (100, max rises with exercise level) · Money
            5 subject stats (korean english math science society — positional)
            study / exercise / part-time EXP

LOOP        nextTime(): tick++ → deal a weighted hand of action blocks at the
            current location → player taps one → spend hpWeight → pay out
            → maybe an event. Sleep block or tick 15 → endToday().
            endToday() resets TICK / DATE_PROGRESS / COMBO_STUDY / LOCATION_ID /
            PREV_* / TIME_TO_MOVE_LOCATION, sets IS_BEFORE_SAT_EXAM, logs play_days.
            Stamina 0 = exhaustion: stat penalty + day lost.

LOCATIONS   11 — School 1000, Home 2000, Art Gallery 16000, Gold Mine 16001,
            Park 16002, Library 16003, Café 16004, Gym 16005, Arcade 16006,
            Football Field 16007, Office 16008.  5 start unlocked, 61 actions.

CONTENT     147 events / 3,444 nodes / 444 switches / 18 storyline sets
            103 items · 244 traits · 54 books · 26 characters · 72 stationery
            17 FUNC_ predicates used (81 registered) · 27 verbs used (178 registered)
            11 node types · 89 backgrounds / 42 BGM / 61 SFX / 40 NPCs

CLIMAX      day 32: event 35 → START_SAT → per-subject grades 1..9 → percentile
            → best department by `deviation` (3,358 of them, 25.3..80.85)
            at one of 137 universities → ENDING_CODE=1 → one of 14 endings.
            ENDING_SW==0 → stat endings at 99 / 95 / 90 / 80 / below
                           (below splits on whether a study combo ever existed)
            ENDING_SW==1,3,4,5,6,7,8 → the seven career endings

NOT IN DATA every formula — study gain, pay, exam score, blocks per tick,
            event rate, sleep recovery, goal thresholds. Fit them; keep them
            in one tuning file.
```
