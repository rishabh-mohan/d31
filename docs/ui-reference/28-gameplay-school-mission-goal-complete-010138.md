# UIR-28 — Gameplay — stamina mission and completed weekly goal

[Full screenshot](../../references/screenshots/28-gameplay-school-mission-goal-complete-010138.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `28-gameplay-school-mission-goal-complete-010138.jpg` |
| Original image | `Screenshot_20261023_010138_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:01:38 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `472c10d20dc0d3d79e1f38e809a717419fa5b0180d932ca641a5fe2f6f639656` |

## Visible state

D-28 Thursday at School, 1170 Gold, 53 cookies, 14 actions remaining, 100% HP and rerolls 522.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| HUD/scene | `2,4,96,49` | Normal School frame and empty tick strip; portrait in neutral expression; level card LV2 Hardworking 1800/4950. |
| Mission strip | `13,49,74,4` | Cream rounded red-outlined strip overlays portrait just above Weekly Goals. Red exclamation marker at left. Maintain over 62 Stamina on left; olive Part-Time EXP +500 pill on right, separated by red vertical rule. |
| Goal/stats | `6,54,88,10` | Korean Reach 398 → Science Reward 294 with green checkmark at far right. Stats: Korean 527, Maths 145, English 546, Science 771, Humnts. 475. |
| Status | `6,64,88,4` | Clock14, green100% bar and refresh522. |
| Actions | `13,69,74,27` | Period1 Maths +79~101 / HP-8; olive work card 1036 Gold / Clean Classroom / HP-28 with level progress; two identical Science Textbook E +110 / HP-15 cards below. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- The mission strip is an additional overlay above the existing goal/stat panel; it should not replace Weekly Goals.
- The green checkmark marks the weekly goal as achieved while keeping its target/reward labels visible.
- The work block shows payout as the largest label and shift name below, distinct from magenta workout blocks.
- Duplicate subject/book blocks are valid visual content.

## Fine-tuning checklist

1. Fit the mission strip across the portrait without obscuring face or level card.
2. Keep red mission accents distinct from orange menu chrome and green goal completion.
3. Retain two equal action-card columns, readable stamina costs and the olive work progress bar.

## What this picture does not establish

This capture establishes mission wording/reward presentation, not the trigger, deadline or exact completion test. Current engine mission support must be verified separately.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [lib/engine/goals.dart](../../lib/engine/goals.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-17 — Gameplay — initial School hand at full stamina](17-gameplay-school-initial-full-stamina-005241.md)
- [UIR-29 — My Info — identity, seven university crests and stationery](29-my-info-seven-badges-equipment-010143.md)
- [UIR-33 — Gameplay — Reading Complete book and quick stamina-item panel](33-gameplay-completed-book-stamina-item.md)

![Gameplay — stamina mission and completed weekly goal](../../references/screenshots/28-gameplay-school-mission-goal-complete-010138.jpg)
