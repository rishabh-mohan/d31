# Architecture (recommended)

Recommendations, not decisions. Open choices are collected in
[08-OPEN-QUESTIONS.md](08-OPEN-QUESTIONS.md).

## 1. Share the engine, don't re-implement it

Fact (checked 2026-10-25): d30mode's `lib/engine/` is about 11,000 lines, and
only four files import Flutter or `path_provider`. They are the storage and
loading edges: `account_store.dart`, `content_source.dart`,
`record_store.dart` and `save_store.dart`. The rest (`pack.dart`,
`pack_mechanics.dart`, `game.dart`, `event_engine.dart`, `conditions.dart`,
`effects.dart`, `traits.dart`, `goals.dart`, `admissions.dart`, `dday.dart`,
…) is plain Dart.

Recommendation: extract those pure files into a Dart package (working name
`d30_engine`), with the storage edges staying in the d30mode app behind small
interfaces. Both apps depend on it:

```
d30_engine/           pure Dart: pack model + loader from Map/JSON, mechanics
                      validator, game loop, event runner, conditions, effects
d30mode/              Flutter game: UI, storage, assets, bundle-stamp seeding
pack_studio/          Flutter desktop editor: UI, project IO, art import
```

Why: the editor's validation then *is* the engine's parser (no drifting
re-implementation), and the editor can run headless simulated runs, step an
event graph with a chosen state, and show the exact numbers the game would.

Prerequisite engine work in d30mode:
- A loader entry point that takes already-read JSON maps (or a file-reader
  callback) instead of `rootBundle`/`dart:io`, so `content_source.dart` keeps
  only discovery and seeding.
- A structured diagnostics result from loading and from a run (unknown
  funcCodes, unhandled predicates, unresolved IDs), instead of log-only.

Until the extraction happens, the editor can depend on d30mode via a path
dependency and import only the pure files, at the cost of pulling Flutter
dependencies it doesn't use.

## 2. Editor data model

- **Project = a pack directory.** No separate project file in MVP; editor-only
  metadata (canvas node positions, collapsed groups, notes) goes in a sidecar,
  e.g. `.studio/layout.json` inside the pack. Confirmed safe: the loader
  reads only its known file list plus `images/**` (`pack.dart:1217`).
- **Lossless documents.** Keep each file as its parsed JSON tree plus typed
  views over it; write back by patching the tree, so unknown keys and
  carried-through fields survive. Preserve key order where possible to keep
  diffs small (agents and git both benefit).
- **IDs.** Integer IDs per catalog, unique within the pack (overlap with other
  packs is allowed by design — see MODULAR-PACKS.md). Event node IDs follow the
  original's convention `eventId * 1000 + n`; keep it for readability, but the
  engine only requires uniqueness (to verify in 04).
- **References are first-class.** Build an index of every ID/name reference
  (item IDs in effects, location IDs in conditions, switch names, event IDs in
  `EVENT_<id>` targets, callback names in funcCodes, image paths). It powers
  pickers, "used by", rename/renumber refactors and validation.
- **Undo/redo** over tree patches; autosave to the pack directory.
- **External edits:** watch the directory; on change, reload and re-validate,
  and warn if there are unsaved in-editor changes.

## 3. UI shape

- Left: pack tree (Manifest, Rules, Locations, Items, Traits, Characters,
  Books, Events, Switches, Mechanics, Art, Colleges).
- Center: table/form for catalogs; graph canvas for an event.
- Right: inspector for the selected record/node; "used by"; diagnostics.
- Bottom: validation panel and simulation log.

Event canvas: nodes are cards by type (text, option, ifElse, last,
presentation nodes collapsed into the following card as badges), edges from
`nextNodeId`, option branches and if/else outputs. Details in 04.

## 4. Simulation (with the shared engine)

- **Event stepper:** pick an event, set a starting state (stats, money,
  switches, items, traits, date/tick, location), walk the graph choosing
  options, see changers applied and switches changed.
- **Eligibility probe:** for a given state/date, which events could fire and
  why the rest can't (failed condition shown).
- **Seeded full runs:** N automated runs with a simple policy, reporting events
  reached/unreached and endings, like d30mode's seeded run tests.

## 5. Platform

Flutter desktop (Windows first) is the natural fit: same language as the
engine and the game, and the project already has the Windows toolchain. Web is
possible later if file access is solved (File System Access API).

## 6. Hand-off to d30mode

See [07-INSTALL-AND-TEST.md](07-INSTALL-AND-TEST.md). In short: write the pack
into a d30mode editable pack root; d30mode discovers it by its manifest ID.
