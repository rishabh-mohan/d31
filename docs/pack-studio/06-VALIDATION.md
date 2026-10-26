# Validation

The engine validates little at load (03-PACK-CONTRACT.md §0), so the editor
must. Checks are grouped by severity. **Error** = d30mode would crash, refuse
the pack, or silently lose behavior; export should be blocked. **Warning** =
loads, but probably not what the author meant.

Each check should report file, record ID and JSON path, and link to the
record in the editor.

## 1. Mirror of d30mode's own tests

These are what d30mode already asserts for its packs (`test/engine_test.dart`,
`test/custom_pack_test.dart`); the editor must pass them for any pack.

| Check | Source |
|---|---|
| Every event's `rootNodeId` exists in `nodes` | engine_test ~L65 |
| Every `option` node has non-empty `options`; every option has non-empty `text` | ~L77 |
| Every option has `nextNodeId` in `nodes` (or a `nextBoxId` with nodes) | ~L101 |
| Every changer `funcCode` (nodes, `actionChanger`, location actions) is a built-in verb or a `mechanics.callbacks` name | ~L119 |
| Every `targetType: func` target (events, nodes, options, `changes`) is a built-in `FUNC_` or a `mechanics.predicates` name | ~L119 |
| Every item has `effects`, or is `flavour`, or has empty `effectText` | ~L188 |
| Every `LOCATION_<id>` condition names an existing location | ~L1138 |
| `mechanics.json` passes the validator (version, ops, expressions, cycles, blocks) | custom_pack_test ~L166 |
| Seeded simulated runs all terminate with no unknown condition targets | ~L1550 (200 seeds) |

## 2. Errors (block export)

Structure:
- Required files present; each file's top level is an object; list keys are lists.
- Every record has a numeric `id` (per catalog) / `universityId` (badges); node and event IDs numeric.
- IDs unique within each catalog; node IDs unique pack-wide; mechanics block IDs unique.
- `pack.json` `id` equals the folder name and matches `^[A-Za-z0-9_-]+$`; not `kss16`/`kss20`.
- `calendar.startDate`/`endDate` are valid `DATE_YYYYMMDDTT`, start < end.
- `subjects` non-empty, all strings.
- `speakers[].name` non-null strings; `events/system.json` bindings numeric.
- At least one character with `isDefault: true`.

References:
- `start.locationId`, `school.locationId`, `levels.*.locationEfficiency[].locationId`, `mechanics.blocks[].locations`, `UNLOCK_LOCATION`/`LOCK_LOCATION`/`MOVE_LOCATION` args, item `unlockLocation` → existing locations.
- `ACQUIRE_ITEM`/`REMOVE_ITEM` args, `FUNC_ITEM_*` args, `commerce.offers[].itemId`, `colleges` `requires.items`, item `acquireItem.itemId`, mechanics `grantItem`/`drawItem.pool`/`itemCount` → existing items.
- `ACQUIRE_TRAIT`/`REMOVE_TRAIT` args, `FUNC_TRAIT_*` args, `traitAbilities` keys, mechanics `grantTrait`/`trait` → existing traits.
- `characterAbilities` keys, events' `characterIdList`, `presentation.characters` keys → existing characters.
- `EVENT_<id>` targets and `rules.events.openingEventIds` → existing events.
- `eventSetId` → existing set in `sets.json`.
- `ENABLE_BLOCK`/`DISABLE_BLOCK` args → existing block ID or alias.
- `conditionFuncCode` → a mechanics predicate or a declared switch.
- `standingId` → an NPC in `presentation.npcs` (when it has art) or at least in `speakers`.
- Node `nextNodeId`/`nextNodeIdIfTrue`/`nextNodeIdIfFalse` → existing nodes.
- Subject-index args (`INCREASE_STAT[i,…]`, `FUNC_GET_CURRENT_EXAM_GRADE`) within `subjects` length; subject keys in effects/books/`stats.initial` ∈ `subjects`.
- `quizzes` `answer` within `options` range.

Engine rules:
- `isFake` events contain no `option` nodes (auto-play can't choose).
- Writes to read-only engine switches (`TICK`, `DATE_*`, `WEEKCODE`, `MONEY`) are ignored → error.
- Item effects with an unknown `type`, or a `ui` action outside `predictedGrades`/`checkAbilities`/`recipes`.
- Trait effect types / condition targets outside the supported lists (they fail closed).
- Every referenced image path exists in the pack's `images/` (bundled-only paths: error for a shareable pack, warning otherwise).

## 3. Warnings

Graph:
- Unreachable nodes in an event; events no condition can make eligible (e.g. a date outside the calendar, a switch nothing sets).
- `text` node with a `conditionSet` and no `elseText` (silently skipped).
- `option` node whose every option can be gated off.
- `ifElse` node with a changer (runs only on the true branch).
- Cycles (allowed; capped at 2000 nodes per run).
- Event without the `EVENT_<id> equal 0` once-only gate.
- Options relying on `nextBoxId` (pack-wide box lookup).
- No `rules.events.openingEventIds`.

Switches:
- Switch read but never written, or written but never read.
- Undeclared switch in a condition or `changes` (works, but typo-prone).

Content:
- Items with no usable effect (can't be used in game).
- Traits with empty `effectList` and no `traitAbilities` (do nothing).
- `gachable` traits whose `storyId` differs from the pack's (never selectable).
- Badges whose `universityId` isn't in the college catalog.
- Rules keys the engine never reads (likely typos), and keys whose value falls back because of type.

Art:
- Layer images for one actor with different pixel sizes.
- `standingExpression`/`standingClothes` names missing for that actor.
- `backgroundImg` keys not in `presentation.backgrounds`.
- SVG files; images larger than 2048 px per side; unused images.

Saves:
- Renumbering/removing IDs that existing saves reference (03 §16).

## 4. Implementation note

With the shared engine package (02-ARCHITECTURE.md), the structural checks
and the mechanics validator come for free from the real loader, and the
seeded simulation can run in-process. The reference checks need the
reference index the editor builds anyway. Keep the check list in one place
(data-driven), so d30mode's tests and the editor can share it.
