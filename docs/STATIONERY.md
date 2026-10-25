# Stationery

## Ownership lifetime (user-confirmed, 2026-10-24)

Stationery starts fresh for every new run. It is not an account collection to
carry into later runs. Saving/resuming the same run must preserve its owned
copies, equipment and pending draws. Account cookies used for redraws have a
separate lifetime. Missing cross-run stationery carryover is not a parity bug.

## Flow and presentation

Wednesday's night summary closes first. At Thursday tick zero, a navy draw
screen offers five cards before the new-day preparation menu. No Gold is
charged. Monday and the other days do not grant stationery. The pending batch,
draw date, locked positions, and free-redraw status survive a saved-state reload.
Closing grants the final five cards once. A resumed pending draw reopens first.

The reference's redraw screen guarantees B or better; locked positions survive
redraws. The first redraw is free, subsequent redraws cost one cookie, matching
the recovered one-unit charge in `sub_ba75e0` (label: stationery redraw).
Ad-network integration is omitted. Cards cycle on the draw stage until a card
or Stop All is tapped; then lock/redraw/claim controls appear. Reduced motion
keeps faces still and suppresses confetti. Draw-stop and combination results
use stationery's S rainbow / A gold / B blue / C gray palette, distinct from
trait-pack confetti. Overlays ignore touches.

The shared real StationeryCard used by CommerceScreen reserves a two-pixel
outline inset, clips inner art/fills and paints its rounded outline last.
Empty hub slots use the same inset/clip approach. The 393×873 real-asset review
checks the expanded grid; the user's specific Nord corner complaint still
merits playtest confirmation. Preserve the measured stationery-name-fit cache.
See [the integration report](BRANCH-INTEGRATION-2026-10-25.md) for validation.

Inventory and combination use four compact columns, ordered S, A, B, C then ID.
Art occupies 64% of its tile. S uses a rainbow gradient, A gold, B pale blue,
and C gray. Cards show their category, tier, name, count, and subject bonus.
Combination accepts **two, three, or four** copies in four removable slots,
with a wide Combine button, type filters,
owned cards, and a separate result/Confirm dialog, based on the supplied image.
Duplicate copies can occupy multiple slots; an equipped copy is reserved.
One ingredient and more than four ingredients are rejected without consuming
anything. Four visible slots are a capacity, not a minimum (user correction).

All 18 catalog sets are functional. Equipping all four required IDs adds the
set's `studyStats` once to each applicable subject, in addition to individual
item bonuses. The menu names active sets and their bonuses; removing any piece
immediately removes that bonus. Values remain the global catalog's base study
efficiency units, not a screenshot's final action payout.

## Recovery evidence and unresolved probabilities

Source: `../korstu4CLAUDE/private-build/korean-base/analysis/`.
`decompiled/app/app.dart:sub_b060c8` branches on weekday 4 before advancing the
day menu; `sub_b0702c` navigates to `/dokidoki_equipment_item`. The draw controller
is `FXb` in library `Izr`, equipment catalogs are `fCb`/`gCb`/`iCb` in `afr`,
and the combination result controller is `PXb` in `Szr`. The screenshot confirms
four combination slots, a separate result, and B-or-above redraws.

**Exact original draw and combination percentages are not recovered.** This
dump contains unresolved `stub(...)` calls, and the corresponding assembly
method entries often have size -1. Do not describe the following as original
odds or infer percentages from unrelated object-pool constants.

Until the actual probability branch is available, `rules.json.stationery`
contains explicitly provisional balance:

- Initial draw: S 1%, A 9%, B 30%, C 60%. Rank is sampled first, then a uniform
  item within that rank. The number of catalog items cannot increase S's odds.
- Redraw: the same weights with C removed and the rest normalized (S 2.5%,
  A 22.5%, B 75%). Kept cards are unchanged.
- Combine: preserve the highest input tier, with a provisional 5% chance of
  the next tier (S stays S). The user explicitly confirmed B+C -> B and A+C -> A
  rather than a linear tier average. This applies to two, three or four copies;
  adding lower-tier inputs cannot lower the result. It is a user-directed rule,
  not a recovered original formula. `combineUpgradeChance` is editable in rules.

The original upgrade percentage remains unresolved: the recovered PXb result
controller contains presentation callbacks and unresolved stubs, not a usable
probability branch. Invalid selections or an
empty output pool do not consume materials. The random result is determined
before inventory changes. UI callbacks cannot bypass the engine's copy checks.

`tools/build_pack.py` preserves these settings when regenerating the pack.
Regression coverage includes Thursday cadence and reload, rare-tier frequency,
redraw guarantees/locks/cookie charges, duplicate and equipped-copy accounting,
invalid-selection atomicity, active set application/removal, and compact UI.
