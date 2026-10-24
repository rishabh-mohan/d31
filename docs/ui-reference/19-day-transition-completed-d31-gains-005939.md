# UIR-19 — Day recap — completed D-31 Monday and daily gains

[Full screenshot](../../references/screenshots/19-day-transition-completed-d31-gains-005939.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `19-day-transition-completed-d31-gains-005939.jpg` |
| Original image | `Screenshot_20261023_005939_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:59:39 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `18fd87a56deee0eabe5f7a69e346d71974393db7688b7833efa3c85e56ac779e` |

## Visible state

Navy recap still labels the completed day D-31 Monday, with changed totals and separate gain row.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Date stack | `40,28,22,17` | Same crescent/D-31/Monday stack as the fresh-run handoff. |
| Goal header | `4,47,92,4` | Weekly Goals row now includes Korean Reach 398 → Science Reward 294, rather than the initial dash. |
| Totals | `7,52,86,5` | Pastel subject tiles: Korean 236, Maths 145, English 50, Science 374, Humnts. 364. |
| Daily gains | `8,58,84,2` | Aligned below totals: +186, +95, blank under unchanged English, +324, +314. Pale blue panel has thick dark outline and shadow. |
| Continue | `4,65,92,8` | Same full-width green play button as 005158. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Continue is the only visible action.
- Totals and daily deltas are different text rows; unchanged English has no +0 printed in this capture.
- Display the completed-day date even if the engine has already rolled its internal clock forward.

## Fine-tuning checklist

1. Align each gain under its subject tile, not in a separate unstructured list.
2. Use the same card height for initial and completed summaries.
3. Keep goal content within its header row without squeezing five subject columns.

## What this picture does not establish

The image does not establish recap animation duration or goal reward collection. Do not automatically replace D-31 with the next day’s D-30 label.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/day_transition.dart](../../lib/ui/day_transition.dart)
- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)

## Compare with

- [UIR-08 — Initial day transition — D-31 Monday baseline](08-day-transition-initial-d31-005158.md)
- [UIR-20 — System event — Part-Time Level Up](20-event-system-part-time-level-up-010000.md)

![Day recap — completed D-31 Monday and daily gains](../../references/screenshots/19-day-transition-completed-d31-gains-005939.jpg)
