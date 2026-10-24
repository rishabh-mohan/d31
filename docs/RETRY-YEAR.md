# Retry Year port checkpoint

Story 20 is selectable as **Retry Year** in the first setup step. This is an
initial prototype using the existing day engine and balance, not a completed
reproduction of Retry Year's special systems. Its shipped title is *The Year I
Retook*. Its shipped English event dialogue is imported from `translatedText`,
`translatedElseText` and `translatedOptionText`. The earlier claim that its
dialogue was Korean was incorrect: Korean runtime macros had been mistaken
for untranslated prose. No new machine translation was used.

## Imported

- A separate `packs/kss20`, generated with `python tools/build_pack.py --story 20`.
  The default command still builds story 16.
- All 218 main-story events and 9,072 node records, declared switches and event
  sets, plus the global character events supported by the selectable cast.
- The original October 14–November 14, 2024 calendar, eight locations, exercise
  and part-time tables, 122 merged story/global items, and 20 eligible characters.
- Global books, traits, badges and system dialogues, with story-20 trait scoping.
- All eight location backgrounds recovered from their authored URLs. Reproduce
  with `python tools/presentation_assets.py --story 20 --fetch-locations`.
- Campaign selection scrolls beneath the fixed setup header. Standard 31-Day
  Mode stays first; the unimplemented Elite/support-pack controls are hidden.
- Save summaries include the pack ID. Continue loads that campaign; reads with
  a different pack are refused. Existing story-16 saves remain compatible.
- The opening now plays at tick zero in the recovered order: rejection,
  mother, academy/placement test, then Suin in the Reflection Room. Confinement,
  its first evening release, and the next morning's class introductions work.
  See [RETRY-YEAR-LIFECYCLE.md](RETRY-YEAR-LIFECYCLE.md) for native evidence,
  the first-day location override, scheduling policies and save recovery.
- Hidden `???` speakers, Jian Lee's two actors, the 100 stamina cap, level-up
  scenes after event XP and the tick-12 Hurry!/Roll Call! gate are covered in
  [RETRY-FOLLOWUP.md](RETRY-FOLLOWUP.md).

The selector discovers bundled `packs/<id>/pack.json` assets and desktop pack
directories. A new bundled pack also needs its asset directories in pubspec.
Cards use a stable color derived from the pack ID so rebuilds do not recolor
them. Setup drafts are separate per campaign.

## Compiled mechanics recovered from the native (2026-10-24)

Read from the Korean `libapp.so` (SHA-256 `cadee9c8…`) by disassembling each
closure with capstone and labelling object-pool loads from `pp.txt`; the
pool gives each `FUNC_`/block closure's address beside its name. None of
these are guesses. Where Dart's Smi tagging shows a literal 2, the value is 1.

| Name | Native | Behaviour |
|---|---|---|
| `GO_PRO_CONDITION` | RJl 0x6cca58 | `GO_BLOCK == 0 && GO_SEE >= 2 && past target && EXAM_SW != 1` |
| `GO_LEE_CONDITION` | SJl 0x6cc930 | `LEE_BLOCK == 0 && LEE_SEE >= 3 && past target && EXAM_SW != 1` |
| `GO_BANJANG_CONDITION` | TJl 0x6cc5b0 | `NA_BLOCK == 0 && BANJANG_HEALTH >= 2 && past target && EXAM_SW != 1` |
| `HELP_BANJANG_CONDITION` | UJl 0x6cc460 | `BANJANG_STUDY_BLOCK_ON == 1 && BANJANG_CLEAR == 0 && NA_BLOCK == 1 && EXAM_SW != 1` |
| `SINGKING_CONDITION` | VJl 0x6cc374 | `SING_POINT >= 15 && SING_WIN != 1` |
| `KARAOKE_CONDITION` | WJl 0x6cc2c4 | `SING_WIN != 1` |
| past target | 0x6cc6dc | now later than `DATE_2024<BLOCK_TARGET_MONTH><BLOCK_TARGET_DAY>00` |
| `DO_GO_BANJANG/LEE/PRO` | sub_bdc1b0/264/318 | `NA_BLOCK` / `LEE_BLOCK` / `GO_BLOCK` = 1 |
| `DO_HELP_BANJANG` | sub_bdb8dc | `BANJANG_COUNT += 1` (diagnosis beats at 5, 12, 22) |
| `DO_GATHER`, `DO_MAKE_FOOD`, `DO_SINGKING` | sub_bdc0d0, sub_bdb9d8, sub_bdbab8 | raise `GRASS_SW` / `MAKE_FOOD_BLOCK` / `SING_KING_BLOCK`, check events, lower it |
| `DO_KARAOKE` | sub_bdbb98 | `SING_COUNT += 2` holding item 90008, else 1; pays remote-config `SING_MONEY` (not in the binary; `rules.karaoke.money`, 0) |
| `SET_NEXT_TARGET_BLOCK_CONDITION` | sub_be9578 | target date += 3 days |
| `SET_SING_TARGET` | 0xff1048 | `SING_TARGET = round(SING_POINT * 1.5 + rand(3))`, `SING_ENEMY = 1 + rand(6)` |
| `SET_GOLD_SUN_VALUE(n)` | sub_be9f38 | `GOLD_ORDER = n`, `GOLD_SUN_SUBJECT` = a subject |
| `SET_HIGH_GOGO` | sub_be973c | `HIGH_GOGO = 1`, closes 2000 and 20001-20004, to the classroom |
| `FUNC_MOCK_EXAM_GOOD(n)` | qtl 0xadfef0 | stat total vs `[1500,1750]`, `[3500,4250]`, `[8500,9500]` -> 1/2/3 |
| `FUNC_IS_GOLD_WIN` | rtl 0xadfc04 | stat in the bet subject >= 370 / 1180 / 2450 for bets 1-3 |
| `FUNC_SING_TARGET` | ttl 0xadf8a4 | `SING_COUNT >= SING_TARGET` |
| `EXAM_POINT` | itemEffect* | raised only by notes/guides (+5/+10/+20); the kit reads it |

`continueTargetSwitch` on a node raises that switch when the scene closes; the
Sing-Off (219) hands to its results (220) through `GOGO_SING` this way.

The exam bands above are recovered raw-stat thresholds. The former
studyWeight=9 override was a fitted attempt to reach those thresholds, not a
recovered study formula; it tripled starter-book gains and has been removed.
Both packs now retain the observed studyWeight=3 baseline (power 5 -> +15
unbuffed). Exam progression balance remains open and is not a reason to
silently inflate ordinary book payouts.

## Exam day, admissions and endings

Exam day has no blocks. Starting it plays the Graduation Exam (74), whose last
line is `START_SAT`; the host then sits the CSAT (`lib/ui/csat_screen.dart`):
report card, up to three applications, results, enrolment. Enrolling raises
`ENDING_CODE`, and the endings play in turn until one runs `END_GAME`.

- The catalog (`admissions.json`, built by `build_pack.py`) is the shipped
  university and department lists: regular universities plus this story's
  own two, Elite Retry (54) and Standard Retry (55). Medicine and Pharmacy at
  54 need the Elite Student Recommendation (90019), which the promotion grants;
  the deluxe purchase Pharmacy also names is treated as owned.
- `FUNC_GET_SUCCESS_LENGTH` counts acceptances, `FUNC_IS_ENTER_UNIV*` read the
  enrolment. With none, "Third Try"/"Second Retake" (160) plays.
- The CSAT score is **not** recovered: a standard score over the stat total,
  `rules.exam.meanTotal`/`sdTotal`, graded on the real CSAT bands. Admission is
  a draw around each department's cutoff (`admissionSpread`).

## Remaining work

- The overall scheduler (TODO 50): pinned events still go by priority then id,
  unverified against the native dispatcher.
- Full crafting recipes, Scouter/Hiking Gloves item actions, complete character
  ability parity and the formal ending gallery/reward popup remain incomplete.
  Demerit-triggered confinement and its next-day release task are implemented. `GOGO_LOCATION` is only ever set to
  2 by content, so events 139 and 232-234 are unreachable in the data itself.
- Some item descriptions still have unparsed effect text and keep `unparsed`
  rather than inventing effects.
- The presentation audit lists 15 unavailable source images:
  `build/presentation-assets-report-20.json`.
- Remaining runtime text macros still need implementation. A few shared book
  descriptions and internal event labels remain Korean.

## English recovery evidence

`python tools/audit_retry_english.py` checks the extracted English asset tree,
the older `korstu4/mod-decoded` tree, the old English APK at
`kor2/Korean Student Simulator apks/asset_pack_1_en.apk`, and the generated pack.
The current source, old English APK and generated pack each have **7,350
non-empty dialogue/choice/heading fields, with zero Korean prose fields** after
excluding runtime macros and markup. The old mod has 7,348 such fields; it is
an older graph and is not used to replace the current campaign logic.
The local-only report `build/retry-english-audit.json` records source hashes,
counts and any gaps. Korean placeholders are preserved for runtime expansion.
Matching part-time level names and action labels are also reused from the old
story-16 localized project by exact source strings. No numeric progression,
switches or event links are copied with these labels.

## Event rewards and portrait follow-up (2026-10-24)

The Nord's existing Retry Year save had EVENT_211 completed and one item 80042
(Promotion Exam Kit). The authored reward at node 211010 was reaching inventory;
there was no item receipt, and the story item's icon had not been copied.
EventRun now records actual positive inventory deltas from node changers, and
EventScreen displays the received names, counts and icons until the scene ends.
This covers fixed and random rewards without granting a second copy for display.
Story item art is copied by `presentation_assets.py` along with presentation art.
The later item-mechanics update implements the kit's proficiency check using
EXAM_POINT and keeps the kit in the bag. Notes and guides raise that value;
the original reward grant is unchanged.

Mum (NPC 1) and Ji Suin (NPC 3) have event-only `eventOffsetY: -24` in story 20's
presentation metadata. All event portraits also receive the later 40px lift;
Mum and Suin therefore stand 64px higher in events. Gameplay portraits retain
their separate layout.
Tests check the actual reward node, save persistence, bag and receipt at 320px,
and both portrait offsets plus an unchanged Headmaster portrait.

Banjang Na (NPC 7) now has his original body, outfit and four expressions.
Recover these with `python tools/presentation_assets.py --story 20 --fetch-npc 7`.
All six authored layers are verified present; no replacement portrait is used.

## Verification

`test/retry_year_test.dart` checks catalog counts, dates, all location-image
files and event roots, story-scoped traits, setup selection on a narrow phone,
and a seeded full calendar run that terminates without hanging. That smoke run
does not establish that every storyline, ending or special callback works.
`test/save_store_test.dart` checks campaign identity, wrong-pack rejection and
legacy story-16 saves. Generated packs/art remain local-only and gitignored.

See [CURRENT-STATE.md](CURRENT-STATE.md) for the combined review and deployment checklist.
