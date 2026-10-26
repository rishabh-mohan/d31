# Product brief

## Problem

d30mode is fully data-driven: a pack directory of JSON (plus optional art)
defines the calendar, locations, actions, events, items, traits, characters,
colleges and every tuning number. Today the only ways to make a pack are the
Python generators that convert Korean Student Simulator data
(`tools/build_pack.py`) or editing JSON by hand. Hand-editing event graphs is
the hard part: a single event is dozens of linked node records, conditions are
a recursive and/or tree, and a typo in a node ID or switch name fails silently
at runtime.

## Goal

A sister app in which a person can create a new campaign pack, or modify a
copy of an existing one, without editing JSON, and be confident it loads and
plays in d30mode.

## Users

1. **The project owner** authoring new campaigns and side stories.
2. **Coding agents** generating or bulk-editing content. The app's file format
   is plain pack JSON, so agents keep working on files directly; the app must
   tolerate (and validate) external edits.
3. Later, possibly, community authors. Not an MVP concern.

## MVP scope (recommended)

1. **Pack project:** create from the Workshop template, open an existing pack
   directory, save back to the same layout. Lossless round-trip: fields the
   editor doesn't understand are preserved untouched.
2. **Manifest and rules:** form editors for `pack.json` (name, calendar,
   subjects, start) and `rules.json` sections with defaults shown.
3. **Catalog editors:** locations and their actions; items with structured
   effects; traits; characters; books. Table + detail form, ID allocation,
   reference pickers (choose an item, not type its ID).
4. **Event editor:** node-graph canvas for one event, a list of events with
   eligibility summaries, condition builder, changer builder, dialogue text
   with token/markup preview.
5. **Switches:** a declared-switch list with "used by" lookups.
6. **Art:** import images into the pack's `images/` folder, assign them to
   locations, items, characters and event backgrounds; preview portrait layers.
7. **Validate:** the checks in [06-VALIDATION.md](06-VALIDATION.md), with
   clickable errors.
8. **Play-test:** export to a d30mode editable pack root (desktop) or produce
   an installable folder for Android; ideally run a headless simulated run
   inside the editor (see architecture).

## Later scope

- `mechanics.json` visual editor (predicates/callbacks/abilities/blocks); MVP
  can offer a JSON editor with validation for it.
- Colleges/departments and badges editors (large tables).
- Event-set and calendar timeline view.
- Female/alternate protagonist graphs (`events_female.json`).
- Quizzes, stationery/commerce, presentation layer editor.
- Localization workflow.

## Non-goals

- Changing d30mode's runtime behavior from the editor. If a pack needs a new
  kind of behavior, that is engine work in d30mode (a new generic primitive),
  documented in MODULAR-PACKS.md, then exposed in the editor.
- Hosting, sharing or a pack marketplace.
- Editing saves or account data.

## Content-rights boundary (important)

The generated `kss16`/`kss20` packs and `assets/images` contain Korean
Student Simulator text and art. They are gitignored and local-use only
(see CLAUDE.md and PACK-FORMAT.md "Art"). Pack Studio must:

- never bundle KSS packs or art in its own distribution;
- treat an opened KSS pack as a local reference/working copy only;
- make "new pack" start from the Workshop template (project-authored), with
  placeholder art supplied by the author.

## Success criteria for MVP

- A new pack made only in the editor (template → one location → three events
  with a choice and a condition → one item → one trait) loads in d30mode
  desktop with no diagnostics and plays to its end date.
- Opening and re-saving `examples/packs/workshop` produces byte-identical or
  semantically identical JSON (key order aside).
- Every validation error in 06 is reachable from a test fixture.
