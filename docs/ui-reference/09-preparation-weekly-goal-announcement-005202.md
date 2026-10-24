# UIR-09 — Preparation — first Weekly Goals announcement

[Full screenshot](../../references/screenshots/09-preparation-weekly-goal-announcement-005202.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `09-preparation-weekly-goal-announcement-005202.jpg` |
| Original image | `Screenshot_20261023_005202_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:02 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `a652056a8503e5bb72a3ea464d834d1ee9675aa255b7ce8dc4c12f9f509f5af1` |

## Visible state

A centered goal dialog overlays the D-31 Monday preparation hub; all subject stats are 50.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Backdrop | `0,0,100,100` | Preparation hub is visible through a uniform dark scrim; top HUD, Traits/Store and lower equipment/shortcut panels remain recognizable. |
| Dialog | `4,29,92,46` | Cream modal, orange thick rounded border and large centered Check your Weekly Goals heading; brown horizontal rule below. |
| Objectives card | `11,38,78,13` | Pale peach rounded/shadowed rectangle. Objectives above Korean 50 tile, thick orange arrow, Korean 398 tile. |
| Reward card | `11,53,78,11` | Separate peach/shadowed rectangle. Reward above green Science chip and +294 in larger dark type. |
| Confirmation | `32,67,36,5` | Orange Let’s do this! button with shadow and darker lower edge; no top-right close icon. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- The primary control acknowledges the goal, not the day’s green Start button behind the scrim.
- Objective progression is shown as start value → target, not as a reward amount.
- Reward subject/color differs from target subject/color.
- Underlying HUD shows D-31 Mon, 0 Gold and 53 cookies; these are example account/run values.

## Fine-tuning checklist

1. Keep two inset cards clearly separated and align the arrow/tile centers.
2. Dim the background only; modal text and tiles retain their light palette.
3. Give the dialog enough width for its long title without truncation.

## What this picture does not establish

Screenshot does not establish the goal-generation formula or reward timing. Cookie count 53 is not an initialization default.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/day_menu.dart](../../lib/ui/day_menu.dart)
- [lib/engine/goals.dart](../../lib/engine/goals.dart)
- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)

## Compare with

- [UIR-08 — Initial day transition — D-31 Monday baseline](08-day-transition-initial-d31-005158.md)
- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)

![Preparation — first Weekly Goals announcement](../../references/screenshots/09-preparation-weekly-goal-announcement-005202.jpg)
