# d30mode

A data-driven rebuild of Korean Student Simulator's **31-Day Mode** (story 16)
in Flutter — the same engine KSS uses. The point is modifiability: the engine
holds no content, so everything the game is made of lives in an editable
content pack, and changing the pack changes the game.

Personal use / dev-pitch prototype. See **Scope** at the bottom.

## What works now

A playable 31-day loop driven entirely by pack data:

- **Calendar** — 2023-10-16 → 2023-11-16 (수능 exam day), 15 action ticks a day
- **11 locations** with their real action lists, weights and stamina costs;
  locking and unlocking as content dictates
- **The block loop** — each tick deals a weighted hand of action blocks from
  the current location; Refresh Tickets redeal it. Study / part-time /
  exercise / sleep, with 54 books, study combos, and the original'"'"'s study,
  exercise and part-time level tables
- **The event engine** — 321 events over 10,755 nodes: text, inline choices,
  `ifElse` branching, `elseText`, 226 event switches, and the full recursive
  condition language (37 `FUNC_` predicates, 55 effect verbs)
- **177 items** with structured effects, consumable and passive
- **244 traits** driving their own `effectList`
- **A gameplay screen** laid out to the reference UI: date + D-count top bar,
  location banner, tick dots, portrait with level box, goal strips, subject
  chips, stamina bar, and the action-block grid — drawn with placeholder art
  lifted from KSS by `tools/copy_assets.py`
- **A dev panel** that edits stats, stamina, money, exp, the clock, switches,
  items, traits and locations live; searches and fires any of the 321 events;
  edits `rules.json` in place; reloads the pack from disk; and lists any verb
  the pack used that the engine lacks

Verified by `flutter test`: 327 tests (2026-10-25), including 200 seeded full runs that all
reach exam day, and a static check that the engine implements every verb the
pack uses.

Not built yet — audio, recovered exam/admission formulas (the current scoring is
fitted), the original event-set dispatcher and the rest of TODO.md. Current
state: [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md).

## Run it

Flutter SDK lives at `C:\Users\stewc\flutter`; add `flutter\bin` to `PATH`.

```bash
flutter pub get
flutter test                      # 327 tests, ~90 s (the 200-run sweep is most of it)

flutter run -d windows            # desktop, fastest iteration
flutter run -d <serial>           # the Nord N30 over adb
```

Or build and install by hand:

```bash
flutter build apk --debug
adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk
```

> Use **PowerShell** for `adb`, not Git Bash. MSYS2 rewrites `/sdcard/...`
> into a Windows path and `adb push` then reports success while nothing lands.

## Change the game

Everything is JSON in `packs/kss16/`. The app copies it to a writable
directory on first run and loads that copy, so edits need no rebuild:

- **desktop** — `packs/kss16/` in this repo, loaded directly
- **Android** — `/sdcard/Android/data/dev.d30mode.d30mode/files/packs/kss16/`

Edit, then open the dev panel (slider icon) → **Pack** → **Reload from disk**,
and start a new run. The **Rules** tab edits `rules.json` from inside the app
and writes it back, which is the quickest way to tune.

`rules.json` holds every number the loop multiplies — stat gains, stamina
costs, pay, sleep recovery, event frequency. Those numbers are **this
project's model, not KSS's**: the original's formulas are compiled into
`libapp.so` and exist in no JSON. They are fitted to what *is* observable
(action weights, `hpWeight`, book power, level-table weights), and they are
meant to be retuned.

[docs/PACK-FORMAT.md](docs/PACK-FORMAT.md) documents every file, every effect
verb, every condition target, and how to add new ones.

## Rebuild the pack

`packs/kss16` is generated from the KSS reference data in this workspace:

```bash
python tools/build_pack.py
```

- `tools/build_pack.py` — assembles the pack from
  `korstu4CLAUDE/.../campaign-localized-v2/story-16` (97.3% English) and the
  English build's global catalogs
- `tools/item_effects.py` — parses item effects out of `effectText`, because
  the original keeps them compiled rather than in data
- `tools/copy_assets.py` — copies placeholder art out of the KSS trees into
  `assets/images/` (gitignored, local use only)

Re-running overwrites the pack, so copy a tuned `rules.json` aside first.

## UI reference atlas

For a broader evidence-based description of the **original game's functions**,
read [docs/ORIGINAL-GAME-FUNCTIONS.md](docs/ORIGINAL-GAME-FUNCTIONS.md).
It covers account systems, runs, progression, events, exams and campaigns, with
version boundaries, internet sources and an extracted native-function index.
Regenerate its source audit with `python tools/audit_original_game.py`.

[docs/UI-REFERENCE.md](docs/UI-REFERENCE.md) indexes all 33 reference screenshots.
Each has a descriptive image filename and a detailed Markdown specification,
including visible state, approximate geometry, controls, fine-tuning checklist,
uncertainties and code entry points. Original filename/hash provenance is retained.

## Layout

```
lib/engine/
  pack.dart            models + the pack loader
  content_source.dart  where a pack is read from, and the editable copy
  game_date.dart       the DATE_YYYYMMDDTT calendar
  state.dart           everything about a run in progress
  conditions.dart      the condition language + the FUNC_ registry
  effects.dart         the funcCode registry + item effects
  event_engine.dart    node-graph runner + event selection
  game.dart            the day loop
lib/ui/                title, game screen, event player, inventory, dev panel
                       theme.dart, pack_image.dart
packs/kss16/           the content
tools/                 the pack builder
docs/PACK-FORMAT.md    the modding contract
test/engine_test.dart  87 tests incl. 200 seeded full runs
test/widget_test.dart  14 panel-render tests
```

## Scope

The engine and all of its code are original. The content pack is built from
KSS's own data and is for **local use only** — it is not redistributable, and
nothing in `packs/` should ship anywhere. To make this shareable or pitchable,
author a second pack with your own content in the same format and point the
app at it; the engine does not care which pack it loads.

[docs/D30-MODE-SPEC.md](docs/D30-MODE-SPEC.md) is the full rebuild spec for the
original mode, including the list of where this implementation still diverges
from it (§13).

Background, the reverse-engineering that informed the schema, and the
boundaries of this work are in [RE-BRIEF.md](RE-BRIEF.md).
