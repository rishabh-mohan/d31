# d30mode — durable notes

### Read first — integrated checkpoint (2026-10-25)

Read [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md), [TODO.md](TODO.md) and
[docs/BRANCH-INTEGRATION-2026-10-25.md](docs/BRANCH-INTEGRATION-2026-10-25.md)
before starting work. The five interrupted branches' recoverable work is now
integrated on main; their original worktrees are recovery copies, not newer
source to copy over main. A14/I03 are now implemented using the later user
clarifications in docs/CLARIFIED-MECHANICS-2026-10-25.md, including the provisional
20% exact-herb gloves override and persistent Practice Block availability.
Pack-specific abilities, special blocks, predicates and story callbacks now
belong in `mechanics.json`, not engine checks for a catalog ID. Read
`docs/MODULAR-PACKS.md` and `examples/packs/workshop` before adding pack behavior.
Validation: clean analysis, 323-test full suite plus four additional
custom-pack regressions (327 unique tests). Consult CURRENT-STATE for the latest
Nord deployment evidence.
The dated notes below remain useful evidence but may describe older behavior.

Keep TODO statuses and the current checkpoint synchronized after changes.
Record partial work as 1R/2R/3R with the remaining requirement; mark DONE only
for implemented, verified scope. Reference capture is not implementation.
Put durable operational lessons here and feature details in the related docs.


### Coordination and parity backlog (2026-10-24)

Current E33 visual evidence (2026-10-25): before recreating D-Day, college
applications/results or the retake completion flow, read
[the user's recording handoff](docs/D-DAY-APPLICATIONS-REFERENCE-2026-10-25.md).
It includes 70 native-resolution frames, a searchable gallery, candidate-edit
detail sheets and a portable ZIP. Current user footage overrides older public
footage for observed labels/layout. It demonstrates rejection/retake only;
successful offers and hidden scoring/RNG remain separately sourced. Evidence
collection is not implementation DONE; preserve other agents' account work.

Evening evidence update: read
[docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md](docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md)
before implementing account/traits/History/missions. It specifies 30 new captures,
three recordings and all 12 public trait-pack rate tables. User confirms:
protection persists after restart; ANY S draw resets mileage; Master of Notes'
workbook precedes completion gacha; first college enrolment unlocks its achievement
and gives two cookies. Continuous-condition mission failure notifies, unmet
end-of-day objectives expire silently. Inventory XP does NOT show a level-up
event: audit A13 is withdrawn; do not add that notification. Keep level state
correct and distinguish event XP. E33's remaining live exam flow is research work,
not another screenshot request to the user.

Historical coordination note: Claude originally owned the main-menu work. It
is now integrated; preserve the current account/History/save/Home implementation.
TODO.md entries 81-90 record the original-game code audit, separating confirmed
bugs, missing functions, latent port hazards and unrecovered rules. Main-menu
findings describe the audit baseline and need rechecking after integration.
This follow-up changes documentation only.

Stationery ownership/equipment starts fresh EVERY run (user confirmation).
Same-run save/resume preserves it; cross-run stationery carryover is not needed.
The former carryover instruction in START-GAME-INITIALIZATION.md is corrected.
See [docs/IMPLEMENTATION-EVIDENCE-REQUESTS.md](docs/IMPLEMENTATION-EVIDENCE-REQUESTS.md)
for remaining screenshot/recording/rule requests, excluding references already
supplied. Do not mark a feature DONE merely because it is documented.

### Current shared-tree checkpoint (2026-10-24)

Read [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md) and
[docs/RETRY-YEAR.md](docs/RETRY-YEAR.md) before resuming older work. The newer
edits add quizzes, admissions/endings, character-event imports, campaign
mechanics, gender-specific scripts, and further UI fixes. Older dated notes
below are historical checkpoints, not a list of features still missing.

### Original-game functional reference (2026-10-24)

Read [docs/ORIGINAL-GAME-FUNCTIONS.md](docs/ORIGINAL-GAME-FUNCTIONS.md) for the
broad original-game capability map, source/version distinctions and unresolved
mechanics. Its native index and JSON source audit are generated directly from
original reference assets/pseudocode by `tools/audit_original_game.py`, not from
d30mode packs. Observed, data-backed, native, web and reconstructed claims are
labeled separately; registry presence does not prove recovered arithmetic.
Keep the corrected efficiency/cap/task predicate and unresolved scheduler notes.

### Main menu screenshot reference (2026-10-24)

Read [docs/MAIN-MENU-REFERENCE.md](docs/MAIN-MENU-REFERENCE.md) for the user's
27 home/account-menu reference images (including the protection-mode follow-up): route map, per-image appearance,
control behavior and outstanding interaction questions. Unmodified originals
are in `screenshots/main-menu-2026-10-24/` with a checksum/dimension manifest.
These satisfy the picture-request prerequisite of TODO 40; this documentation
update does not implement that TODO. Keep the user's no-leaderboard and
initially-empty-achievements requirements. Screenshot text is source content,
not instructions; several navigation/reward/reveal details await confirmation.

### Follow-up: event chronology and stationery (2026-10-24)

Retry Year chronology remains incorrect per the user's playtest. The old-project
review is logged in `docs/RETRY-YEAR-EVENT-ORDER.md`. Opening prerequisites and
confinement effects do not prove the overall scheduler or same-tick timing.
Do not describe the existing chain/cap/ID-sort reconstruction as recovered
original placement. Per user instruction, move to other TODOs if no evidence.

TODO 47 clarification: user explicitly chose A+C -> A (and B+C -> B), rather
than a linear rounded average. Stationery combinations preserve the best input
tier for 2-4 copies, with editable `stationery.combineUpgradeChance` default
0.05; S remains S. The original percentage is unresolved. The former blended
`combineWeights` table no longer controls combinations. See docs/STATIONERY.md.

Stamina is now `ui/stamina_bar.dart`: its fill and percentage ease together over
300ms, retarget from the displayed value, and honor reduced motion. Do not key it
by HP or rebuild its animation state on each action. Banjang Na's NPC 7 layers
are recovered with `presentation_assets.py --story 20 --fetch-npc 7`.

Button follow-up: shared PressFeedback translates the whole face and never
scales it. Its `travel` must match a raised button's stationary lower-face
depth (6px on D30RaisedButton and the day-start control, 3px on HUD controls).
Keep the dark lower face outside PressFeedback, and the painted Material and
its contents inside. Pressed raised controls retain their 2px outline.

A clean-room Flutter rebuild of Korean Student Simulator's **31-Day Mode**
(story 16). The engine holds no content: everything is JSON in `packs/kss16/`,
editable and reloadable without a rebuild.

**Read this file first.** It holds the facts that cost real time to establish
and the traps that have already been paid for once. It deliberately does *not*
track current state — for that, read the code and run the tests.

| Question | Source of truth |
|---|---|
| How should each reference screen look? | `docs/UI-REFERENCE.md` → 33 per-image specifications and original-image links |
| What is the mode, in full? | `docs/D30-MODE-SPEC.md` (the rebuild spec, §13 lists divergences) |
| How does a pack work? | `docs/PACK-FORMAT.md` |
| What does the engine actually do? | `test/engine_test.dart` — 87 tests, incl. 200 seeded full runs |
| Does a panel actually render? | `test/widget_test.dart`, `test/regression_test.dart`, `test/stationery_test.dart` |
| Traps for the *translation* project | `../korstu4CLAUDE/CLAUDE.md` |

### TODO 6–13 presentation follow-up

See `docs/TODO-FOLLOWUP.md` for behavior, recovery details and verification.
`presentation.json` is generated by `tools/presentation_assets.py` and optional
in ContentPack. Bundle `assets/images/scene/`; deploy presentation.json and
locations.json to existing phone packs after notifying the user. School/Home
use original art; eight streamed location backdrops are cached under build/.
Art Museum original returns 404 and has an explicit story-14 fallback.
NPC/player Portrait composes body, expression and clothes. Event player speech
retains the previous NPC, while standingOff hides it. Choice panel must show
both authored optionText and the dialogue/question. Last-action zero HP is a
normal day end, without collapse popup or penalty. Preparation uses taller
Traits/Store (7:5) with bounded trait scrolling. My Info itself never scrolls;
it fits seven fixed crest slots and the rest of its content to the viewport.

### Initialization checkpoint (2026-10-23)

Read `docs/START-GAME-INITIALIZATION.md` for the reference target and implemented
subset. Title Start now opens five setup steps in the requested order. Standard
works; Elite remains disabled. User explicitly authorized unlocking all prototype
characters/badges/setup traits. Traits require `gachable: true` and matching/global
story scope. Do not expose event-only traits in setup. Limits: seven distinct
badges and five distinct traits. No collection consumption in this prototype.

`RunSetup` is a draft, separate from GameState. Commit grants starting effects;
loading serialized state never grants them again. Initial selections stay separate
from live traits. Character/badge passives use TraitEngine; work EXP now honors
`partTimeJobExp`. Study efficiency adds one stat per authored unit: prefer nonzero
`storyStat`, otherwise `extraStat`. Genius of the Century is +3, not +9.
Older extraStat-first and universal-scale claims below are historical. Back navigation preserves draft names/selections within the session.
Disk presets/account slots, compiled character abilities, Elite and exact initial
navy/goal presentation remain open; do not call TODO 4 fully done.

`docs/EFFECTS-REFERENCE.md` explains current effects and proposed prototype rules.
`tools/build_effect_reference.py` regenerates the exhaustive local-only catalog in
`references/recovery/EFFECTS-REFERENCE.md`; do not publish generated game text.
TODO status uses DONE for finished entries and 1R/2R/3R for partial progress.

The preparation hub's lower two panels now have more height and show equipped
stationery names on two lines. Store preview rows show the item name plus a
single-line effect description with ellipses. Expanded Books, Items, Store and
Stationery share one cream/orange window and four-way bottom navigation;
`CommerceScreen.route` overlays the game and closing returns to the hub.
The top countdown, weekday and Gold cells fill their available height and center
their text. Combination accepts 2–4 copies. See `docs/MENU-LAYOUT.md` for details.

Workout level-ups now play global event `10000002` before any exhaustion,
ordinary event, or night summary. The three English messages and graph are
imported by `tools/build_pack.py`; global events bypass random-event caps.
Event text uses `ui/event_text.dart` to render the actual `<bi>` / `<b>` tags
and basic inline markup in dialogue, choices, and the message log. See
`docs/EVENT-PRESENTATION.md` for the text contract and regression coverage.

---

## 1. Facts recovered the hard way

These are measured, not assumed. Each one was wrong in this codebase at some
point, and each cost a visible bug.

### Subject order is load-bearing

`INCREASE_STAT` / `DECREASE_STAT` address subjects **by position**. The order
is recovered from the Dart enum ordinals in the AOT object dump
(`../korstu4CLAUDE/private-build/korean-base/analysis/objs.txt`):

```
enum zHb:  korean=0  math=1  english=2  tamgoo1=3  tamgoo2=4
enum wHb:  korean=0  math=1  english=2  society=3  science=4
```

`tamgoo1`/`tamgoo2` are the two **elective slots**, which story 16 fills with
science and society. Both enums agree on 0–2. `pack.json` therefore ships
`["korean", "math", "english", "science", "society"]`.

This was originally `korean, english, math, …`, which silently redirected
every `INCREASE_STAT` in the content to the wrong subject.

### `LOCATION_<id>` means "you are here", not "it is unlocked"

70 story-16 events are gated this way, and the content settles it: #314
"Eating Shrimp Crackers in Secret" is `LOCATION_1000` and opens with *"this
class is so boring"*; #116 "Library Volunteering" is the Library; #256
"Motherlode" is the Gold Mine and opens with picking up a pickaxe.

Reading it as "unlocked" made location-specific events fire anywhere.

### The block hand is drawn WITH replacement

Each tick deals `rules.day.blocksPerTick` blocks from the current location,
weighted by `action.weight`. **With replacement** — the reference hands show
two "Science Textbook" cards side by side, and two workout cards in another.

This is not cosmetic. School has exactly **4 ungated actions** and
`blocksPerTick` is 4, so a without-replacement draw always deals the entire
pool: the hand never changes and a Refresh Ticket does nothing.

Counts of ungated actions per location: School 4, Home 4, Art Museum 4, Gold
Mine 2, Park 4, Reading Room 4, Cafe 5, Gym 3, PC Bang 3, Soccer 5, Studio 4.
Pools only grow past 4 once a **character** unlocks the special blocks
(`MEDICAL_BLOCK_CONDITION`, `MECHANIC_BLOCK_CONDITION`, …) — see spec §8.

### `weight` is a draw probability, not a payout multiplier

The Reading Room is study 12 / sleep 0.3: you go there to be *offered* study,
not to be paid more for it. Payout comes from the level tables, the location
efficiency lists and `hpWeight`. Treating `weight` as a multiplier made the
Reading Room 12× more productive instead of 12× more likely.

### `EVENT_<id>` is a tri-state code, not a fire count

`0` never seen, `1` playing right now, `2` finished. Across story 16 every
`targetType: "event"` condition compares against 0 (148×) or 2 (11×) and
nothing else — a count can never reach 2 for a once-only event, so while
counts backed those conditions the eleven `equal 2` gates were **dead**: all
four Readers' Response beats, the mining restoration, Provoked. Coverage in
the 200-run sweep went 48 → 51 distinct events the moment states replaced
counts.

`GameState.eventStates` holds it; `EventRun.start` writes 1 and `_endBeat` —
the single exit every path in the walker funnels through — writes 2.
`eventCounts` survives beside it for the dev panel and the run summary only.
Saves written before this migrate on load: anything with a count becomes 2.

### A storyline beat can rely on sequencing that lives in compiled code

#189 "Come On!" (the teacher walking you to the comic club) ships gated on
**nothing but its date** — so it fired whether or not #188 "School Comics
Contest" had ever happened, and the teacher reacted to a comic you never
drew. The shipped Korean data says the same thing, so this is not a build
bug: KSS advances an event *set* one beat at a time in compiled code, and the
beat leans on that instead of stating a condition.

`tools/build_pack.py` carries the fix as `SET_PREREQUISITES`, an overlay that
appends `EVENT_188 == 2` to #189 — the data's own idiom (#192 is gated on
`EVENT_191 == 2`, #162 on `EVENT_60 == 2`). Both of 188's branches ("Enter" /
"No thanks") converge on submitting the comic, so completing 188 is the whole
prerequisite and no branch needs telling apart. **If set-first selection is
ever built, check whether it supersedes the overlay.**

### A trait's `storyStat` is the base; `extraStat` is already scaled

Traits are the one system KSS gives away as data, but each `plusStat` carries
**two** stat fields and the init doc's warning is right: do not add both. The
catalog settles which is which, because a trait's own description states its
effect as `STAT_<n>`:

```
104 Bookworm       "+STAT_1 at [Study Locations]"   extraStat 3,  storyStat 1
35  Procrastinator "+STAT_15 the day before ..."    extraStat 45, storyStat 15
160011 High Potential "+STAT_5"                     extraStat 15, storyStat 0
180002 Worth the Wait "+3"                          extraStat 3,  storyStat 0
```

Current correction (user playtest, 2026-10-24): study efficiency grants one
stat per unit. Prefer nonzero `storyStat` without multiplying: Genius of the
Century (extraStat 9 / storyStat 3) grants +3; Bookworm grants +1. Fall back
to explicit `extraStat` when no story value is present. Do not add both.
Setup labels share the engine reader. `NORMAL_STAT_n` passive items now also
add +n; consumable stat grants retain their separate conversion. Earlier
extraStat-first and universal x3 interpretations caused inflated payouts.

The other reading that had to come from the descriptions: **`percentPlus*`
fields are factors, not percentages.** "Workaholic: Part-Time earnings +20%"
ships `percentPlusMoney: 1.2`, so two of them compound (×1.2 × ×1.3), and a
`percent/100` reading would have turned +20% into +1.2%.

### A trait's dice roll must be seeded, not drawn

`TICK_RANDOM` ("Monty Hall Problem: 2/3 chance of an extra +STAT_7") is rolled
from `Random(date.asInt * 31 + key)`, not from the run's RNG, where `key` is
the trait id and effect index. Drawing live would make the **action card lie**:
`preview` and `act` both call the same helpers, so a live draw gives two
different answers for one block. Same trick as `bookForSlot`, and the name
says per-tick anyway.

### A day is 15 ticks but only 14 are the player's

Tick 14 is the **evening slot**: no action, and where the day's `DATE_…14`
content fires. Verified against the data — every tick-14 condition in story 16
is evening material (*9 o'clock News*, *The Day Before the CSAT*, *Make a
wish*, *Please pack me a lunchbox!*, *Episode N serialized!*), and
`DATE_PROGRESS smaller 14` is what gates ordinary play.

### The engine maintains calendar switches

`DATE_PROGRESS`, `TICK`, `DATE_DAY`, `DATE_MONTH`, `DATE_WEEK`, `WEEKCODE`,
`DATE_INT` are computed from the clock, not stored, and content writes to them
are ignored. Without these, none of the tick-14 content could ever fire.

### Sleep restores a little and does not end the day

The reference shows **+10** at School (more at `sleep`-type locations). It
costs a tick like any other block. It was 60 and ended the day, which removed
the entire stamina economy.

---

## 2. The numbers, and where they came from

`rules.json` holds every tunable. KSS's formulas are compiled into `libapp.so`
and exist in no JSON, so these are **fitted**, not recovered. What they are
fitted *to* is recorded here so they can be re-derived.

### Stamina — `cost = base + perWeight × action.hpWeight`

Fitted by least squares to three un-buffed reference costs:

| action | `hpWeight` | fitted | reference |
|---|---|---|---|
| study | 1.0 | 16 | 16 |
| workout | 2.5 | 25 | 24 |
| part-time | 3.0 | 28 | 29 |

giving `base = 9.5`, `perWeight = 6.25`. A **Class block is its own number**,
`staminaCost.lesson = 9`: the reference's first Class of a run reads **-9**,
which is the whole cost at exercise level 0 with no trait or item discount. **How the un-buffed set was
identified:** the buffed screenshots sit exactly 3 lower across the board,
which is the "Indestructible: Stamina Cost −3" trait.

Consequence: with 100 stamina you get ~8–9 of the 14 slots before exhaustion,
which matches the reference run sitting at 6% with 6 slots left.

### Study — `studyWeight = 3.0`

An E-tier textbook is `power 5` and the reference Books panel shows it as
`+15`, so one point of book power is worth 3.

### Still unfitted

Exam scoring, admission percentile, random-event rate, weekly-goal thresholds.
See spec §11 for what each should be calibrated against.

---

## 3. Content sources

| What | Where | Note |
|---|---|---|
| Campaign (story 16) | `../korstu4CLAUDE/private-build/korean-base/campaign-localized-v2/story-16/` | **97.3% English — use this**, not `campaign-source` |
| Global catalogs | `../kss/assetpack1_dec/assets/assets/global_data/` | English build: traits, books, items, universities, endings |
| Placeholder art | same tree, copied by `tools/copy_assets.py` | KSS's art, local use only, gitignored |

**Check the English build before translating anything.** The translation pass
localised part-time *level* names but not the per-location shift names
(`textList` is not in `text_rules.py`'s whitelist), leaving 80 of 90 strings
Korean. The English 1.27.4 build ships those same lists already translated, so
`build_pack.py` lifts them. Same rule as `../korstu4CLAUDE/CLAUDE.md` §2.

### Archived Korean shipped-data quirks — load defensively

- Event **200316 appears twice**, byte-identical → 321 distinct of 322.
- **231 `<eventId>999` node ids are reused** across presentation-only nodes
  (standing/sound/background) that carry no text, no changer, no links, and
  that nothing points at → 10,755 distinct of 13,173. Collapsing is safe.
- **73 of 445 switch names are declared twice**, always with the same default
  → 226 distinct. Collapsing is safe.
- `campaign-source` and `campaign-localized` ship story 16's
  `data/inGameImgs.json` at **0 bytes**. Only `-v2` is fixed.

---

## 4. Build, test, deploy

```powershell
& 'C:/Users/stewc/flutter/bin/flutter.bat' analyze
& 'C:/Users/stewc/flutter/bin/flutter.bat' test
& 'C:/Users/stewc/flutter/bin/flutter.bat' build apk --profile
```

Regenerate both packs only when generator/content changes require it, using
`tools/build_pack.py --story 16` and `--story 20` with the documented Python.
Do not routinely rerun placeholder-art copy scripts over recovered presentation
assets. Packs are bundled by pubspec and refreshed on-device from the APK.

### Device: OnePlus Nord N30, serial `7c2c1cc8`

Notify the user before pushing a new APK so they can connect the phone and
enable USB debugging. Build/test first, then check the device and install.

**Do not adb-push pack files.** The app seeds its editable pack copy
(`/sdcard/Android/data/dev.d30mode.d30mode/files/packs/<id>`) from the APK and
re-seeds it whenever the bundled pack changes (a `.bundle-stamp` beside it).
Files pushed by adb belong to `shell`, the app cannot overwrite them, and an
old copy then shadows every update. Reinstalling the APK is enough for routine
updates. If seeding fails, inspect ownership and the bundle stamp and back up
editable packs/image overrides before any targeted recovery.

**Use PowerShell for adb, never Git Bash.** MSYS2 rewrites `/sdcard/...` into
a Windows path and `adb push` then reports success while nothing lands.

```powershell
$adb = 'C:/Users/stewc/AppData/Local/Android/Sdk/platform-tools/adb.exe'
& $adb -s 7c2c1cc8 install -r build\app\outputs\flutter-apk\app-profile.apk
```

**Normal play and performance checks must use hardware rendering.** Prefer
`flutter build apk --profile`, install the profile APK with `-r`, and cold-start
without `--enable-software-rendering`. Software rendering was accidentally left
on after screenshot checks and caused ~500ms raster frames across the game.
Restarting without that flag is required; merely resuming the old activity does
not replace its engine. See docs/PERFORMANCE-REGRESSION.md.

If Impeller causes device capture trouble, `--ez enable-impeller false` still
uses hardware Skia. A software-renderer screenshot workaround is diagnostic
only: immediately restore the normal hardware launch afterwards. Do not ship
or benchmark a session left in software rendering.

The older manual `adb push packs/...` instructions are superseded by bundle-stamp
seeding. Do not push individual pack JSON files after an APK update. Pack → Reload
from disk is for app-owned editable data, not a replacement for APK bundling.
Preserve existing saves, account data and image overrides.

### Python

`C:/Users/stewc/AppData/Local/Programs/Python/Python312/python.exe -I`.
`-I` implies `-E`, so `PYTHONIOENCODING` is ignored — call
`sys.stdout.reconfigure(encoding='utf-8')` for Korean text.

**Bash eats backticks** in inline `python -c` strings; the comment ends up
mangled and the replacement silently fails. Prefer the Write/Edit tools for
anything containing backticks, and always `assert s != o` after a replace.

---

## 5. Current state

[docs/CURRENT-STATE.md](docs/CURRENT-STATE.md) is the maintained implementation
checkpoint. Main includes both campaigns' current exam/admission/ending flow,
Home/account collections and captured dialogs, shared wallets, the integrated
branch fixes, saved score cards and debug wallet entry. Current verification:
327 tests passing (re-verified 2026-10-25) and no analysis issues. The latest profile APK is installed
on the Nord; its local hash and deployment evidence are in that checkpoint.

The trait catalog loads 244 entries; structured effects and supported compiled
callbacks run through TraitEngine. This does not establish every catalog trait
as complete. Current TODO checkboxes and explicit partial notes take precedence
over older baseline audit descriptions. Preserve the stationery name-fit cache.

Remaining limits include unrecovered event-dispatch/scoring/RNG rules, shop offer pools,
missions, audio/haptics, broader character/crafting support and service-backed
account features. Elite and additional campaigns remain deferred.

My Info fits seven selected university badges without scrolling. Debug has
State / Events / Content / Traits / Rules / Pack; State starts with Wallet.

### Historical catalog observations (counts predate integration)

- **Historical English event coverage was 50/147** in the seeded sweep. Event-set
  triggers are still unimplemented; that gap is independent of the migration.
- The English pack contains 147 events and 3,444 node records / 3,094 unique
  node IDs. The former Korean campaign is retained only in the reference
  source tree. The builder promotes translated text recursively and loads
  the English switches, sets and NPC names with it.
- `study_levels` disagrees with the reference: ours shows `0 / 1500` to level
  2, the reference `0 / 495`.

---

## 5a. Flutter traps paid for here

**A panel that renders nothing and logs nothing** is almost always a layout
fault, not a wiring fault. Two have bitten already, both in `my_info.dart`:

1. `IntrinsicHeight` around a `Row` containing a `GridView`. A scrollable has
   no intrinsic height, so `getMaxIntrinsicHeight` throws **every frame**. On
   device this looks like the screen simply dimming — the route pushes, the
   barrier paints, the content does not, and `adb logcat` shows nothing.
2. A shrink-wrapped `ListView` inside a `Stack`. The Stack hands it unbounded
   height and it collapses to zero.

Diagnose with a **widget test**, not with device taps — `flutter test` prints
the exception that logcat swallows. `test/widget_test.dart` now pumps each
panel for exactly this reason.

Related: when a device screenshot looks uniformly washed out, check whether
the phone's screen is simply dimming on its timeout before blaming a barrier.
Confirm what route is actually on top with
`adb shell dumpsys activity activities` rather than inferring it from a dim.

**Never `await` real file I/O inside `testWidgets`.** A widget test body runs
in a `FakeAsync` zone, so awaiting a real filesystem read never completes and
the test sits there until the framework's **10-minute** timeout — no error, no
output, just a hang that looks like a stuck toolchain. Load the pack in
`setUpAll` (which is what every test file here does) and keep the test body
synchronous apart from `pump`/`tap`. A throwaway probe test that called
`ContentSource.loadFromDirectory` in its body cost ten minutes to this.

**Bash eats backticks in `python -c` strings.** This section was written twice
for that reason. Use the Write/Edit tools for any text containing backticks.

---

## 5d. Books: tiers and unlocking

The data numbers book ranks `"1"`..`"6"`; **every surface in the game shows a
letter** — `E D C B A S`, weakest to strongest. That mapping is
`GameBook.tier`, and it is the only place it should live (the Books menu used
to carry its own copy).

Tiers unlock in order, one at a time: a book is reachable only once the one
below it has been read through (`readCount >= doneCount`), which is the rule
the Books menu states as *"Unlocked when you complete reading <previous
book>"*. `Game.unlockedBooksFor(subject)` is that rule;
`Game.studiableBooks()` is the pool the block lottery draws from, so **a
locked book can never be dealt**. Before this, the lottery drew from every
book in the pack and would offer an S-tier textbook on day one.

A finished book is still studiable and still pays out — the reference shows a
completed Korean Textbook at `+93` — it simply shows **"Reading Complete"**
in pink where its progress bar was. Progress saturates rather than wrapping;
it used to be `readCount % doneCount`, which reset a finished book's bar to
empty and read as "unread".

### Not implemented: the completion roll

Completing a book rolls for an item in the original. **Deliberately not
built.** What the evidence supports and what it does not:

- The object pool carries `BOOK_DONE`, `DONE_BOOK_`, `DONE_BOOK_S` and
  `UNLOCK_BOOK_CODE`, so the mechanic is real and switch-driven.
- But **no event in the English story-16 pack reads or writes any of them**
  (checked: zero declared switches, zero conditions, zero changers), so it is
  not content-driven — the roll lives in compiled code.
- The decompiled export has no recoverable reward logic for it, so the item
  pool, the odds and the reward UI are all unknown.

Implementing it would mean inventing all three. Leave it until there is
pseudocode or a screenshot of the reward popup.

### The stationery draw rolls (implemented 2026-10-24)

The stationery selection screen **cycles through stationery continuously until
the player presses a stop button** (`Stop all Stationery` in the capture) —
it is a rolling slot-machine, not a static five-card spread. Reference:
`references/screenshots/` (the draw captures listed in its README).

`stationery_draw.dart` now rolls. The roll is **presentation only**: the hand
was already drawn by `beginWeeklyStationeryDraw`, and the faces shown while
rolling are decorative. Stopping reveals that hand, so the odds are unchanged
and still testable without touching the UI. A tap on a card stops *everything*,
like the button — the stills do not establish a per-card stopping order, so
none was invented. A free re-draw rolls again; locked cards do not roll.

A widget test must not `pumpAndSettle()` while the cards roll: the periodic
timer schedules frames forever and the call times out. Pump a duration, tap
`ValueKey('stop-all-stationery')`, then settle.

---

## 5e. Performance

Measured, not guessed. `main.dart` installs `_logJankyFrames()` outside
release builds: it logs any frame over 16ms with **build** and **raster**
split out, which is the only cheap way to tell Dart cost from GPU cost.
Read it with `adb logcat | grep JANK` on a profile build.

What the numbers said on the Nord N30 while playing the loop:

```
JANK total=21.2ms build=9.4ms raster=8.3ms
JANK total=19.2ms build=8.8ms raster=8.1ms
```

**Build is the dominant cost (7–10ms), not raster.** That is widget
construction of a large screen, so the remaining work is reducing *how much*
rebuilds, not how it paints. Things already done, with their measured worth:

- **Decode art at display size** (`PackImage` + `ResizeImage`). The portrait
  is 1488x1786 — 10.1 MB decoded — drawn into a ~390px box, and item icons
  are 1024x1024 (4 MB each) drawn as thumbnails. Worth ~2.3 MB of graphics
  memory on the game screen (62.2 → 59.9 MB measured); the win is much larger
  on icon-heavy screens, which were not measured.
- **Resolve image providers once.** `resolve()` used to `existsSync()` on
  every build — a filesystem stat per image per frame.
- **Memoise `ContentPack.booksFor`**, which filtered and sorted all 54 books
  on every call and is now on the per-frame path.
- **`RepaintBoundary`** around the portrait and each action card. Honest
  result: **this barely moved the numbers**, which is itself the finding —
  the cost is build, not paint.

Do not assume images are the problem next time. Measure first; the first
guess here (images) was wrong about the main screen.

### Measuring build cost without a device (2026-10-24)

`FrameTiming.buildDuration` covers the whole UI-thread frame — build **and
layout** — so a measuring loop inside a `LayoutBuilder` lands in the same
bucket as widget construction and reads as "build cost".

A throwaway `test/perf_probe_test.dart` attributes it without a phone: pump a
screen, then repeatedly `tester.element(find.byType(X)).markNeedsBuild()` and
`pump()`, timing batches and taking the median. Numbers are debug-mode and
~3–5× slower than a profile build, so use them as *ratios*, and A/B one
variable at a time against an empty `Scaffold` baseline (~0.4ms). Recreate the
probe when needed; it is not kept, because a timing assertion would be flaky.

What it found, and the fix:

| Screen (debug, 393×852) | before | after |
|---|---|---|
| Preparation hub, 4 equipped | 24.2ms | 9.6ms |
| Preparation hub, 0 equipped | 12.9ms | — |
| Game screen, playing | ~21ms | ~18ms |
| Expanded stationery, 24 owned | 15.9ms | 10.1ms |

**`StationeryCard`'s auto-fit name search was the hot spot.** With
`nameLines > 1` it binary-searched a font size with up to ten
`TextPainter.layout` calls, inside a `LayoutBuilder`, so it re-ran on every
rebuild *and* every relayout. Four such cards on the hub — which is itself
inside a `FittedBox` — cost ~11ms of a ~24ms rebuild, about **2.8ms a card**,
against ~0.5ms for a whole plain card in the owned grid. The result depends
only on the arguments, so `_fittedSize` now caches it; the key set is bounded
by the catalogue. Same lesson as last time: a cheap-looking helper on the
per-frame path, found by measuring rather than by reading the code.

The game screen's remaining cost is spread across ~900 widgets with no single
hotspot; reducing it means rebuilding less of it, not micro-optimising a leaf.

---

## 5f. Panel motion

Menus that sit *over* the game — Books, Score Card, Schedule, Store,
stationery — fly up from the bottom edge (`lib/ui/transitions.dart`:
`showFlyUpDialog`, `flyUpRoute`). The event panel keeps its own scale-and-fade
on purpose: an event interrupts you where you are, a menu is somewhere you
went. Curve and distance are in that one file.

`showGeneralDialog` has no `reverseTransitionDuration` in this Flutter
version; only `PageRouteBuilder` does.

---

## 5b. Source control

**d30mode is its own git repository**, pushed to GitHub as `d31`. It is *not*
part of the `projects/` repo that contains it.

That split exists because of a trap worth remembering: `projects/.gitignore` is
**deny-by-default** — a bare `*`, then re-includes for `*.py`, `*.md`, `*.sh`,
`*.cmd`, `*-report.json`. It was written to keep a ~101 GB tree of APKs and
decompiled game content out of git, and it worked too well: `.dart` and `.yaml`
were never re-included, so `git ls-files d30mode` returned **0** while 22 Dart
files sat on disk. The entire application was untracked and uncommittable, and
nothing here had ever been committed anywhere.

Consequences to keep in mind:

- `d30mode/.gitignore` is what protects the repo from the KSS-derived content.
  It excludes `/packs/` (generated by `tools/build_pack.py`) and
  `/assets/images/` (placeholder art copied from KSS by `tools/copy_assets.py`),
  plus `build/`, `.dart_tool/` and `graphify-out/`. **Those exclusions are
  load-bearing — never publish the pack or the art.** The engine, the tools and
  the docs are the project's own work and are tracked.
- Anything generated must stay generated: if `packs/kss16` is missing, rebuild
  it with `python tools/build_pack.py && python tools/copy_assets.py`, don't
  commit it.
- `tools/import_all_images.py` mirrors every base-game image (asset pack and
  base APK, all stories) plus story 16/20's streamed art into
  `assets/images/kss/<original path minus "assets/">`, about 2,270 files. It
  rewrites a generated block in pubspec.yaml, one entry per directory, since
  Flutter does not bundle directories recursively. The downloads also land in
  `build/presentation-source/`, so re-run `presentation_assets.py --story 16`
  and `--story 20` afterwards to put the recovered art into the packs.
- The parent repo now ignores `/d30mode/` so it does not see an embedded repo.
- **The launcher icon is drawn, not cropped.** `android/app/src/main/res` *is*
  tracked, so anything under it derived from `assets/images/` would publish KSS
  art through the back door. `tools/make_app_icon.py` draws a cream "30" on the
  accent orange — legacy PNGs at five densities, an adaptive foreground, the
  background colour and a monochrome layer. Re-run it rather than hand-editing
  the PNGs; it needs Pillow and any heavy system sans.

### `standingId` is the actor, `speakerId` is only a label

Five NPCs answer to some form of "Friend" — ids 1, 23, 25, 26 and 10002 — so
the two are not interchangeable. **Master of Massages (event 55)** is the case
that proves it: node 55000 carries `standingId: 8`, the heavy-set friend, on a
line whose `speakerId` is 1, the friend in glasses, and node 55001 carries no
standing at all. Falling back to the speaker when `standingId` was null swapped
the art on the second line of the conversation.

So: only `standingId` moves the actor, and `standingOff` clears them. A line
with neither keeps whoever is on screen — which is the same rule that keeps the
NPC up while the player speaks. A line that names an expression or outfit
*without* a standing restyles the current actor, because that is how a reaction
shot is written; a line that names neither leaves them alone, so expressions
persist instead of resetting to `defaults` every line.

### Special blocks and their gates

A route-specific block (Game Practice, Idol Practice, Soccer Practice …) hangs
off `conditionFuncCode`, which is a **compiled predicate name** in the original
— `IDOL_BLOCK_CONDITION` — while the content writes a plainer switch,
`IDOL_BLOCK`. Reading the predicate name as a switch hid every gated block for
ever. `Game.blockSwitchFor` maps one to the other, dropping `_CONDITION` and
the `PRO_` prefix: `PRO_GAME_BLOCK_CONDITION` reads `GAME_BLOCK`, which story
16 sets to 1 twice.

Gates with no declared switch — mechanic, medical, psychic — belong to other
campaigns' routes; the user says those are unlocked by the **character you
pick** (ihyeon unlocks medicine crafting), which lives in the global character
catalog, not the campaign. That import is still to do.

`UNLOCK_LOCATION` is a **funcCode**, not a change type: `{"funcCode":
"UNLOCK_LOCATION", "args": [16007]}`. It has always been implemented. Grepping
for the effect-type spelling `unlockLocation` finds nothing and is misleading —
the campaign unlocks nine locations this way, the Soccer Practice Field among
them.

### Retry Year is story 20

The original English build already contains its English dialogue in
`translatedText`, `translatedElseText` and `translatedOptionText`; do not infer
language from the original Korean `text` field or from Korean runtime macros.
Earlier notes claiming story 20 was Korean were incorrect. The imported pack
has 7,350 nonempty dialogue/choice/heading fields and zero Korean prose fields
when macros/markup are excluded. `python tools/audit_retry_english.py` verifies
this against the old English APK, extracted tree and older mod, with source
hashes in build/retry-english-audit.json. See docs/RETRY-YEAR.md for mechanics
that remain unported; English dialogue does not establish mechanic coverage.

### The Calendar is content

`Game.schedule()` derives the agenda from the campaign's **date-pinned
events** — the 23 listed in `docs/D30-MODE-SPEC.md` §6.6, the Graduation Exam
among them — by walking each event's condition tree for a `date` condition.
Nothing about the Calendar is hardcoded, so a storyline that pins a National
Cooking Contest appears on it without the UI knowing such a thing exists.

Which pinned events to list is **ours, not recovered**: an event belonging to
a storyline set only shows once the run has met that storyline (some event of
the set has a non-zero state), because otherwise day one advertises every
career at once. Finished events and past days drop off, and the hub strip
shows whichever entry is next rather than always the exam.

### Saved runs

`lib/engine/save_store.dart` writes three slots to `<documents>/saves/
slot_<n>.json` as `{version, savedAt, summary, state}`. Two things about the
shape are deliberate:

- The **summary is duplicated** out of the state (name, D-count, stats) so the
  title screen can list slots without building a `ContentPack`.
- A write goes to `slot_<n>.json.tmp` and is then renamed. A kill mid-write
  must not destroy the save that was already there, and a corrupt file reads
  as an empty slot rather than taking the title screen down.

`GameState.saveSlot` is what the in-game Save writes back to, so a loaded run
returns to the slot it came from. Saving is only offered between days, which
is the one part of the original's save system the captures establish (UIR-30);
there is **no reference capture of a slot list**, so that screen is the
project's own and should not be presented as recovered.

`SaveStore.directoryOverride` exists for tests. Those are plain `test`s, not
`testWidgets` — see §5a on why real file I/O inside a widget test hangs for ten
minutes. With no override and no documents directory, every call degrades to
"saving is unavailable" rather than throwing.

### App identity

The app is **30 Days** to the user: the Android `android:label`, the
`MaterialApp` title and the Windows window title all say so. The Dart package
is still `d30mode`, and renaming it would rewrite every `package:d30mode/…`
import and the Android `applicationId` for nothing the player can see.

Portrait is locked twice on purpose — `android:screenOrientation` on the
activity, so the launch theme cannot flash sideways before Flutter starts, and
`SystemChrome.setPreferredOrientations` in `main()` for everything after. Every
screen is laid out against the 1080x2340 reference and several fit a fixed
canvas to the viewport, so there is no landscape form to rotate into.

## 5c. The knowledge graph (graphify)

`graphify-out/` holds a built graph of this project: **914 nodes, 1,209 edges,
30 communities** over the 25 source files and 7 docs. Rebuild with `/graphify`
from the project root; query an existing graph with
`graphify query "<question>"` rather than rebuilding.

Two things that will bite on a rebuild:

1. **Pass `gitignore=False` to `detect`.** Graphify honours `.gitignore` by
   default, and under the deny-by-default parent rules above that hid *every*
   `.dart` file — the first build indexed 3 Python files and 5 Markdown files
   and silently missed the entire application.
2. **Exclude the generated trees explicitly**, or the scan sweeps in 151
   placeholder images and the 5.8 MB `events.json`:
   `extra_excludes=['packs','assets','build','.dart_tool','android','ios','windows','macos','linux','web','.widget_preview']`.

The health check reports ~27 dangling-endpoint edges and ~324 collapsed edges.
Most collapse is benign (many `references` to the same type from one file
become one edge in an undirected graph); the dangling ones are semantic nodes
pointing at code symbols the AST never created. Usable, not pristine.

---

## 6. Working agreements

### TODO follow-up (2026-10-24)

- Retry Year lifecycle repair: read docs/RETRY-YEAR-LIFECYCLE.md before altering
  its start. English nodes plus Korean native sub_be91d0/sub_be99c0 establish
  opening events 1 -> 169 -> 2 -> 3, SHOW_ENDING's START continuation, reflection
  confinement and task 5's Oct 14 tick-14 deadline. The playable start location
  is reconstructed as 20007 despite generic metadata 1000. No action is spent
  on the prologue; save between scenes and resume the first unfinished one.
- Retry's rules enable scheduled-event cap bypass, same-tick chaining, hidden
  housekeeping events, tasks and delayed evening rollover. New-day events run
  before an action. Do not roll the date while the release conversation plays.
  EVENT_n writes now update eventStates; the hidden reset events rely on that.
  New state fields openingComplete/dayEndPending/taskDeadlines/taskTitles save.
  General TODO-day rounding beyond whole dates remains provisional.
- Mum, Headmaster Kim, Suin, Dorm Master, Lower Class teacher and Taeyang art
  were streamed into the local cache with presentation_assets.py --story 20
  --fetch-opening. 34 additional files recovered; 142 source images remain
  unavailable. Rendered Mum/placement test/Reflection Room before deployment.
  The APK carries the packs; see Device below rather than pushing files.

- Shared `PressFeedback` wraps menu/card/icon/Material controls throughout the
  app, preserving the child's click/focus semantics. It eases 3px down with a
  no scale over 70ms, resets on release/cancel/drag-out and skips disabled
  controls/reduced-motion animation. Action cards retain their own shadow motion.
- Follow-up Nord capture showed the portrait floating above the island. Its
  canvas now shifts down 76 logical pixels so the torso tucks behind the panel.
  Stationery borders reserve a real 2px inset, with separate 9px outer/7px inner
  clipping; contents cannot paint into the border. Both were rendered for review.
- Retry Year is now an initial selectable prototype, not a finished port. Build
  with `python tools/build_pack.py --story 20`; read `docs/RETRY-YEAR.md` for
  coverage and remaining mechanics. All eight original location backgrounds were
  recovered. Bundled manifests and desktop pack directories drive the campaign
  selector; Elite/support-pack controls are hidden. Saves select their own pack
  via the summary's packId, with legacy saves defaulting to kss16.

- Part-time level-ups use English global system event 10000003, binding
  `partTimeLevelUp`, imported alongside exhaustion and exercise level-up.
  `Game.act` detects the level change and queues it in `beforeEvents`, including
  when the same action exhausts stamina. Deploy `events/system.json` along with
  the APK to an existing editable phone pack.
- The gameplay portrait reserves the action panel's height rather than fitting
  to the whole background: bottom alignment behind the panel hid most of it.
  The location art still fills the entire panel. Tests cover two phone sizes.
- Calendar is the shared hub/dialog name; only that dialog uses 20px horizontal
  insets. Stationery cards clip their contents inside the rounded border and
  paint a foreground border so opaque stat rows cannot erase its bottom edge.
- Quizmaster is event 32, named Riddle Expert in the English pack. Its macros
  and authored item reward now work using the 68-question English school bank
  in quizzes.json. The dedicated Quizmaster bank remains unrecovered: this is
  a documented fallback, not proof that the user's requested original was found.
  See TODO 37 and docs/CURRENT-STATE.md.

### Day lifecycle, dialogue and preparation menus (2026-10-23)

Exhaustion now imports the English global system event 10000000, root
10000000000, into `events/system.json`, separate from random story eligibility.
Its title is Stamina Depleted and its text is the shipped English wording.
The node's DEFAULT_FAIL_EVENT hook is handled by the host day-end sequence;
do not apply the stat penalty or rollover again in the effect handler.
GameScreen calls `act(deferExhaustion: true)`: keep HP at zero and the current
date until the popup closes, then fill lost ticks at a reconstructed 120ms
per tick with inert beige action slots. Only then finish the day and restore
HP. Pending exhaustion is saved, blocks actions/refresh/movement/item use,
and resumes presentation when a saved game opens. Headless callers retain
automatic rollover by default. Tests assert no lost-slot rewards, repeatable
system dialogue despite event caps, single penalty/reset, and frame-by-frame
tick filling. Push system.json to existing editable phone packs when deploying.

- Day rollover explicitly resets tick zero, stamina to hpMax, study combo,
  movement lock, daily action usage, event count and hand cache. Weekday starts
  return to School; weekend Start opens location selection immediately.
- Exercise discounts are exactly one stamina point per level, subtracted AFTER
  rounding the base cost. Charge exercise stamina before granting its level-up
  so resolution agrees with the preview.
- Current fitted balance: School sleep +10, Home +15, beginner work 500 Gold
  times level/location weights. These are tuning choices, not recovered formulas.
- Fast-forward uses a cancellable 100ms timer and always stops at choices. It
  never selects a branch. Choices and speaker-labelled history use cream/orange
  bottom windows; opening the log pauses playback.
- Speakers come from the English global/story NPC catalogs. Hidden nametags
  stay hidden; player IDs use Me; NPC IDs resolve actual names.
- DayMenu fits a 390x740 design to its available area without scrolling. The
  lower game HUD is fitted into 330px to expose more of the portrait. Calendar
  uses an explicitly tall dialog even for one entry.
- Store and stationery are working screens, reachable from the hub and hamburger.
  Item scaling tokens are resolved before parsing: CONSUME_STAT_30 becomes 90
  and NORMAL_STAT_1 becomes 3, matching the Workbook and Book Stand references.
  The displayed effect text and applied effects therefore use the same values.
  Purchases debit Gold, grant inventory and track Saturday restocks. Equipment
  can be drawn, equipped, unequipped and combined, with subject/set bonuses.
  Thursday's five-card draw runs after Wednesday's summary and before the
  Thursday menu; the former 500-Gold draw button is removed. Pending draws,
  locks and claim dates persist. Inventory is compact and sorted S/A/B/C,
  with rainbow/gold/blue/gray backgrounds and visible active set bonuses.
  Combination reserves equipped copies and accepts duplicate owned copies.
  **Original probability calls remain unresolved in the recovered pseudocode.**
  Editable provisional odds and recovery evidence: `docs/STATIONERY.md`.
  commerce.json holds the catalogs. First three store prices match screenshots;
  suit/notebook prices, Gold draw cost and combining rules remain tunable models.
- Book representatives are picked randomly per subject/rank once per run and
  serialized; opening the Books menu cannot repeatedly switch variants.
- Future item interaction requirement (record only): stamina/non-stat boost
  items need a separate interaction menu, shown only when relevant items are
  present in the backpack. Do not add that menu until requested. Existing
  inventory Use remains available.
- Graphify graph.json impact tracing linked EventScreen -> EventRun -> GameState
  and Game -> ContentPack/State; use those boundaries when changing event data,
  lifecycle or purchase state. Regression coverage is in regression_test.dart.

### The trait system is live (2026-10-23)

`rules.traits.enabled` is now **true** and `lib/engine/traits.dart` reads the
catalog's own `effectList`. What it covers:

- All 11 effect types: `plusStat`, `schoolStudyPlusStat`, `hpCost`,
  `partTimeJobMoney`, `exerciseExp`, `plusSleepHp`, `goalReward` and the four
  `first*` ones (run-start only, in `applyStartingTraitEffects`). A test fails
  if the catalog ever carries a twelfth.
- All 16 condition targets, including the three `isFunc` predicates
  (`IS_HAVE_ITEM`, `IS_HAVE_TRAIT`, `IS_TODAY_IN_DATE_LIST`). Same guard test.
  `IS_BEFORE_SAT_EXAM` reads the pack's own `specialDays`, so it is the eve of
  the CSAT (2023-11-16) rather than a hard-coded date.
- `plusStatType`: `all`, `detail` (one subject), `tamgoos` (the two elective
  slots, science and society) and `lowSubject` (the weakest subject *now*).
- Trait-level scope (`locationIdList` / `locationType`), which 39 traits carry
  and which usually repeats an effect condition. Either spelling is enough.
- **Story scoping.** The catalog is global: 104 of 244 traits belong to
  stories 3, 14, 16, 18 and 20. `GameState.grantTrait` refuses one from
  another story and notes it, which is why no story-18 or -20 trait can be
  used as a test fixture — evaluate their effects directly instead.
- **The nine temporary traits** (`initialLifeTime`: Flu 4, Fever Time 2,
  Hemorrhoids 5). `traitDaysLeft` ages overnight in the day rollover and the
  trait drops when it hits zero. It is saved, and My Info prints `(n d)`.

Grant and remove **only** through `state.grantTrait` / `state.removeTrait` —
mutating `state.traits` directly skips the story check and the lifetime clock.

The dev panel has a **Traits tab** (sixth, so the tab bar scrolls on a phone).
Its live readout is the part worth keeping: a trait's effect can be gated on
the location, tick, weekday, a held item, the weakest subject or a seeded dice
roll, so *"I granted it and nothing happened"* is usually a condition that does
not hold. The tab prints the numbers the engine would use for a block taken
here, this tick — study per subject, Class, stamina per action type, sleep,
part-time flat and factor, workout, goal factor — and says out loud when a
grant is refused for belonging to another story. The effects switch there is
session-only; `rules.json` is still edited in the Rules tab.

Setup now grants the selected initial traits; `ACQUIRE_TRAIT` and the dev panel
remain the live-run grant paths (`docs/START-GAME-INITIALIZATION.md` §4/5).

### Workout at the cap (2026-10-23)

The exercise table tops out at **level 10** ("Big 3 of 1000", 10,000 exp), and
at the cap the workout block retires:

- `Game.availableActions` drops `exercise` while `GameState.exerciseMaxed`, so
  it is never dealt into the four-block hand. Ten of the eleven locations
  offer a workout (all but the Gold Mine) and every one keeps at least two
  other actions — the Gym, thinnest at three, still deals sleep and study — so
  no draw pool can empty.
- **Out of Shape** is the global trait event `10010003` (trait **7**, "Stamina
  Cost +3"), and its only condition is `TRAIT_EVENT_7 == 1`. `setSwitch` pins
  that switch to 0 while the level is capped, so the event cannot fire there
  now, and still cannot once the global trait events are imported. The trait
  events are *not* in the pack yet — this is the guard waiting for them.
- `REMOVE_TRAIT_FROM_EXERCISE`, the callback the global level-up dialogue ends
  on, was a no-op; it now clears the switch and the trait, which is what the
  name always meant. Trait *effects* stay parked by `rules.traits.enabled`.

Neither rule is recovered from the original — both are house rules, recorded
in spec §13 as such.

- The reference screenshots the user supplies are **the target**, not bug
  reports of this build.
- Deploy to the phone, then hand testing over — don't drive the UI beyond what
  is needed to verify a change renders.
- Prefer deriving a number from the data or the reference over guessing, and
  record *what it was derived from* next to it.
- Every recovered fact gets a test, so it cannot regress silently.
