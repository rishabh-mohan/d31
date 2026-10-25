# To-do: complete start-game initialization

Current follow-up (25 October 2026): Home Start opens Select Game before setup.
Both campaigns use shared account cookies and refresh tokens with one-time
starting grants; new runs do not refill an existing shared balance. Each new
run still starts fresh stationery ownership/equipment, while resuming a run
preserves its stationery. Prototype unlocked characters/badges/eligible traits
remain intentional. See [CURRENT-STATE.md](CURRENT-STATE.md); dated setup notes
below describe the implementation stage when written.

## Implementation checkpoint — 2026-10-23

Title Start now opens `SetupScreen`: mode, character, badges, traits, name.
Standard is playable; Elite is displayed disabled pending its rules. All 26
story-16 characters and all badges are unlocked for the prototype by user request.
Traits require `gachable: true` and global/matching story scope: event-only traits
cannot be selected. Selections are distinct, capped at seven badges/five traits.
Back preserves draft choices and names; no live run exists until Start Game.

`RunSetup.commit` validates again, creates fresh state, grants initial traits,
applies structured starting modifiers, fills modified maximum HP and issues the
goal. Character/badge passives reuse TraitEngine (including work EXP). Run JSON
stores the setup independently of current traits; loading never reapplies bonuses.
Game and My Info use the selected portrait; My Info lists selected badges.

Still outstanding: disk-persisted presets, account/save-slot integration, Elite
mechanics, compiled character special abilities and block unlocks, the navy
first-day screen/goal announcement. The existing preparation screen remains the
handoff. Prototype proposals are in `EFFECTS-REFERENCE.md`; not-yet-implemented
rules remain distinct from recovered facts. The setup and follow-up UI tests pass as part of the full
139-test suite; static analysis is clean.

The checklist below retains the full reference target and outstanding recovery
requirements; it is not a statement that every original feature is implemented.

## Evidence and versions

| Evidence | Source | What it establishes |
|---|---|---|
| Five setup screenshots | Local `004736` through `005149` | Ordering, layout, slot limits, displayed controls |
| Korean AOTopsy pseudocode | Korean **1.61.0**, build **1716**, `com.yeopcha.studentmaker` | Trait/badge selection and name presets are persisted and transferred to the run |
| English catalogs | Global **1.27.4**, build **184**, `com.basakansoft.koreanstudentsimulator` | Character availability/effects, trait inventory definitions, university badge effects |

Versions are verified against `korstu4CLAUDE/native/ko161/manifest.json` and
`kss/manifest.json`; both Global asset/native split metadata report build 184.
Earlier documentation called these local English assets 1.29.0 incorrectly.
The provided screenshots' application version is not recorded; do not assume
that their account/version matches the older local Global archive exactly.
No Global pseudocode export or AOTopsy executable is present locally. The existing
Korean export is useful evidence but does not prove every Global rule is identical.

`tools/extract_initialization_evidence.py` saves existing evidence separately:
`references/recovery/korean-1.61.0/initialization-pseudocode.dart.txt` and
`references/recovery/global-1.27.4/initialization-catalogs.json`, plus provenance
JSON containing manifest identity and source/native hashes. No new decompilation
was run, and Korean output is not relabeled as Global.

Recovered functions to consult when implementing:

- `sub_aeba30`: persists `<story>_firstTraitList` / `<story>_badgeIdList`, and
  assigns selected lists into run fields. These are distinct from ordinary
  current traits and should not be lost during run initialization.
- `sub_b4cdd8`: loads `character_make_trait_…` presets with fallback data.
- `sub_b4d2d8`: loads `character_make_badge_…` presets with fallback data.
- `sub_b4d740`: loads `character_make_tamgoo1` / `tamgoo2` subject presets.
- `sub_b4d978`: loads `character_make_firstName` / `lastName` presets.

The untouched excerpts retain unresolved `stub()` calls. Do not invent validation
limits, ownership-consumption rules, or probability percentages from those gaps.

## Before the five steps

- Select One Month / 31-Day mode, story 16, and the intended save slot.
- Keep account collections/cookies separate from the new run's money, EXP,
  stats, clock, book progress, events, weekly counters and shop stock.
- Load the player's available characters, badges, traits, stationery and stored
  setup preferences. Never use screenshot ownership totals as universal defaults.
- Back navigation must preserve choices made in the current setup attempt.
  No ticks or stamina are spent while selecting a character.

## Step 1/5 — difficulty

Reference `004736`: cream title strip, back arrow, "Select Character (1 / 5)",
large Standard Mode and Elite Mode cards, and Elite Support Pack information.

- Select Standard or Elite and carry that choice through all following steps.
- Show the Elite information/help affordance and support-pack description.
  The pictured offer says S-tier traits are available; do not grant an owned
  S-tier trait simply because the offer is displayed.
- Recover exact Elite modifiers/entitlement gates before implementing their
  gameplay effects. Preserve this distinction in saved setup state.

## Step 2/5 — character

Reference `004750`: collection/Owned filter, collection completion, carousel,
left/right arrows, Student ID card, stars, portrait, character name/effect text,
Select button and character-draw shortcut banner.

- Filter the global character catalog by `availableStoryIds` containing 16.
  The inspected catalog has 65 characters total and 26 eligible for story 16.
- Respect ownership/entitlements. The reference's 22/26 (85%) is one account,
  not an initial grant. Keep owned/other filtering and star tiers distinct.
- Carry selected character ID, gender, portrait/skeleton, expression/clothes
  data and its actual passive/special-block effects into the run.
- Keep story 16's subject order Korean, Maths, English, Science, Humanities.
  The shared controller's `tamgoo1`/`tamgoo2` presets do not establish an extra
  subject-selection screen in this five-step reference flow.
- Default Boy has no extra effect. Other characters use structured `plusEffect`
  and/or `specialFuncCode`; do not derive mechanics from display prose alone.
- Draw-character promotions navigate to their own collection/shop flow; they
  must not silently change the currently selected character.

## Step 3/5 — university badges (colleges)

References `004804`, `005058`: "Select University Badges", **up to 7**, four
slots across the first row and three centered below, alphabetical badge list,
crest at left, effect description at right, Next button.

- Allow selecting/deselecting eligible owned badges, without duplicate IDs or
  more than seven active badges. Unfilled slots display an orange dash.
- Keep selected badges visible while scrolling the alphabetical list; reflect
  their selected state and restore valid remembered presets.
- Join `university_badges.json` by `universityId` to university names/crests.
  The inspected Global catalog has 136 badge effect records.
- Apply each selected badge once, using its structured effect and the correct
  story-specific stat/efficiency scaling. The schema distinguishes `storyStat`
  and `extraStat`; do not blindly add both.
- Support initial-stat and study-efficiency effects, including subject-specific
  and all-subject variants. Recover exact account unlock/acceptance rules before
  allowing locked badges to be selected.
- The pictured seven selections are examples: Korea Dream, National Tseing Hwa,
  National Taiwen, Korea Movie, Oxfsword, National Yaung Ming Chao Tung, Tworonto.
  Preserve catalog spellings rather than treating them as real university names.

## Step 4/5 — traits

References `005119`, `005128`: portrait and **five** active-trait slots above a
scrolling two-column trait list, tier headers, owned counts (e.g. ×1), selection
toggles, Purchase/Combine Traits button, Next button. Selected slots are green;
empty slots show an orange dash.

- Allow zero through five owned trait selections, respecting inventory counts,
  valid IDs and duplicates/compatibility rules once recovered.
- Show the actual tier, name, description and quantity. The Global catalog has
  244 trait records; S is black and A gold in these reference cards.
- Remember selected IDs as the initial trait list and transfer them into the
  new run. Keep this initial list distinct from traits gained/lost during play.
- Resolve passive starting stats, stamina reductions, proc chances, special
  actions, acceptance modifiers and other structured effects. Avoid applying
  the same starting effect both during selection and during run creation.
- The screenshots show Indestructible, Time Jumper, Energizer, MBTI S. Realistic
  and Master of 108 Bows as sample selections. They are not universal defaults.
- Purchase/combine is a separate meta-inventory flow. Inventory consumption,
  reroll pricing and exact incompatibilities still require Global verification.

## Step 5/5 — player name

Reference `005149`: "Enter Name", selected portrait, separate First Name and
Last Name fields, and large orange Start Game button.

- Restore remembered names and allow editing both fields, including Unicode.
  Confirm the original empty-name, length and whitespace validation before
  imposing restrictions. The screenshot's Greg Fiasco is sample input.
- Bind final values to `GameState.firstName` / `lastName`, persist them, and use
  the same full display name in My Info and save-slot labels.
- Keep the existing fixed event substitutions: `{이름}` first name, `{성}` last
  name, `{성이름}` full name, including choices, alternate/final lines and logs.
- Commit the setup transaction once when Start Game is pressed; repeated taps
  must not create multiple runs or apply selected effects twice.

## Commit and first-day handoff

- Seed the story calendar at its configured Monday, tick zero, D-31; set School
  as the initial location and reset the daily clock/used blocks/event allowance.
- Initialize ordinary run stats/EXP/money/book progress from the pack, then apply
  selected character, difficulty, badge and initial-trait modifiers exactly once.
- Start each new run with fresh stationery ownership and equipment (user
  confirmation, 2026-10-24); do not inherit another run's stationery bonuses.
  Preserve inventory, equipment and pending draws when resuming the same run.
  Keep the account cookie wallet separate from per-run stationery state.
- Start with full stamina at the correctly modified maximum. The unmodified
  reference has subject stats 50, 0 Gold, study LV1 0/495, exercise/part-time LV0.
- Show the initial navy D-31/Monday screen with baseline stats and no daily gains,
  then the preparation menu and first Weekly Goals announcement (`005158`,
  `005202`, `005207`). The initial navy screen has no goal assigned in the capture;
  the preparation announcement introduces Korean 398 → Science +294.
- Goal values, cookie balance (53 in the sample) and reroll count (520 in the
  sample) must come from actual rules/profile progression, not hardcoded captures.
- Preparation includes traits, Store previews, equipped stationery, Books,
  Items, Score Card, Calendar and the green Start button. Start opens School's
  14 empty action ticks at full stamina (`005241`). Setup/menu browsing spends
  neither a tick nor stamina. Weekends use immediate location selection.
- Save difficulty, character, badges, initial traits, identity and initialized
  run state atomically. Loading an existing run must not reapply setup bonuses.

## Remaining verification before implementing this flow

Confirm Global difficulty modifiers/entitlements, character/badge ownership gates,
trait duplicate/compatibility and consumption rules, name validation, exact badge
effect scaling, account/save-slot persistence, and preset scoping. Screenshots
establish the UI requirements; sibling-build pseudocode establishes persistence
patterns, not every missing Global numerical rule.

Deployment verified: debug APK installed on Nord N30 (7c2c1cc8), installed SHA-256 f687a22b1291300a849fb1866de08517304fdf59e00105982ba544f5a7f895c7 matches the local build. Missing character/badge catalogs added to the editable pack; existing rules retained.


## UI follow-up

See `TODO-FOLLOWUP.md` for the reference-style carousel, layered portraits, trait cards, original university crests and fixed seven-slot layout. Elite mechanics, account presets/slots and the exact first-day announcement remain outstanding.
