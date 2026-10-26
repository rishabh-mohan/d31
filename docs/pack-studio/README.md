# Pack Studio — documentation foundation

Started 2026-10-25. "Pack Studio" is a working name for a sister app to
d30mode: a desktop-first editor that creates and edits content packs (events,
items, traits, characters, locations, colleges, art) and hands them to d30mode
to play.

These documents are the **foundation**, not a finished specification. They
record what the d30mode engine actually reads today (with code citations), the
rules an editor must enforce so that its output loads, and the decisions still
open. Where a statement comes from reading code it says so; where it is a
recommendation for the new app it is labeled as one.

## Audience

Developers (and coding agents) building Pack Studio, and anyone changing the
d30mode pack loader who needs to keep the editor in step.

## Document map

| Doc | Purpose |
|---|---|
| [01-PRODUCT-BRIEF.md](01-PRODUCT-BRIEF.md) | What the app is for, who uses it, MVP scope, non-goals, content-rights boundary |
| [02-ARCHITECTURE.md](02-ARCHITECTURE.md) | Recommended structure: shared engine package, editor model, file IO, preview/simulation |
| [03-PACK-CONTRACT.md](03-PACK-CONTRACT.md) | File-by-file field reference as the engine reads it: required/optional, defaults, failure behavior |
| [04-EVENT-AUTHORING.md](04-EVENT-AUTHORING.md) | Event graph model, node types, conditions, changers, selection algorithm, node-editor mapping |
| [05-ASSETS.md](05-ASSETS.md) | Image paths, resolution order, portraits/layers, backgrounds, crests, import pipeline |
| [06-VALIDATION.md](06-VALIDATION.md) | Checks the editor must run before export, mirroring the engine and its tests |
| [07-INSTALL-AND-TEST.md](07-INSTALL-AND-TEST.md) | Exporting a pack, installing it into d30mode on desktop/Android, reload and diagnostics |
| [08-OPEN-QUESTIONS.md](08-OPEN-QUESTIONS.md) | Decisions needed before or during the build |
| [schema/](schema/) | Starter JSON Schemas (draft 2020-12) for `pack.json`, `locations.json`, `events/*.json`, plus shared condition/changer definitions. Structural only; reference checks live in 06. Verified 2026-10-26: Workshop, kss16 and kss20 validate (kss20's only findings were the `sub` bug in 03 §18). Other files' schemas are still to write. |

## Existing d30mode references these build on

- [../PACK-FORMAT.md](../PACK-FORMAT.md) — prose description of every pack file.
- [../MODULAR-PACKS.md](../MODULAR-PACKS.md) — `mechanics.json`: predicates,
  callbacks, abilities, blocks, hooks.
- [../EVENT-PRESENTATION.md](../EVENT-PRESENTATION.md) — text tokens, markup,
  layered NPCs.
- `examples/packs/workshop/` — the smallest complete standalone pack. Treat it
  as the editor's first fixture and "new pack" template.

When this folder and the code disagree, the code wins; fix the doc.
