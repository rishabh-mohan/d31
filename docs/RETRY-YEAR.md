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
- All 218 events and 9,072 node records, declared switches and event sets.
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

## Remaining work

- Retry-specific callbacks: `DO_GATHER`, `DO_GO_BANJANG`, `DO_GO_LEE`,
  `DO_GO_PRO`, `DO_HELP_BANJANG`, `DO_KARAOKE`, `DO_MAKE_FOOD`, `DO_SINGKING`,
  `REMOVE_ITEM_ONCE`, `SET_GOLD_SUN_VALUE`, `SET_HIGH_GOGO`,
  `SET_NEXT_TARGET_BLOCK_CONDITION`, `SET_SING_TARGET`.
  These remain unsupported and appear in the dev panel when encountered.
  Location labels HOME/PARK/CAFE are not gameplay changers.
- Promotion exams, later demerit-triggered confinement, friend interactions,
  singing/crafting, special character abilities and ending presentation need
  their compiled rules recovered. The inherited balance and school schedule
  are provisional, not verified Retry Year rules.
- Twenty-one item descriptions have unparsed effect text. Those entries retain
  `unparsed` rather than inventing effects.
- The presentation audit still lists 136 unavailable source images, including
  some NPC/expression layers: `build/presentation-assets-report-20.json`.
  Default Retaking Boy/Girl layers, the early speakers and all location art
  are present. The SHOW_ENDING continuation switch works; its formal ending
  reward/gallery popup remains unbuilt.
- Remaining runtime text macros still need implementation. A few shared book
  descriptions and internal event labels remain Korean;
  these are separate from the fully imported English dialogue.

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
The kit's compiled proficiency-check action remains unimplemented; this change
does not implement promotion exams or reinterpret that action.

Mum (NPC 1) and Ji Suin (NPC 3) have event-only `eventOffsetY: -24` in story 20's
presentation metadata. Other NPCs and gameplay portraits keep their positions.
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
