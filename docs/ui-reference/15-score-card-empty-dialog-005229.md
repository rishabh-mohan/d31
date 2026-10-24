# UIR-15 — Score Card — empty-state modal

[Full screenshot](../../references/screenshots/15-score-card-empty-dialog-005229.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `15-score-card-empty-dialog-005229.jpg` |
| Original image | `Screenshot_20261023_005229_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:29 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `bff5fb29eecfbfbc5b5851b65a17115c33492ced5666155f4f9957178e201653` |

## Visible state

No score has been recorded; preparation hub remains visible behind a dark scrim.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Backdrop | `0,0,100,100` | Same D-31 hub as 005207, darkened uniformly. |
| Dialog | `1,41,98,22` | Short wide cream modal, orange rounded outline; much shorter than Calendar. Title Score Card centered near top. |
| Close corner | `89,41,9,5` | Orange corner tab integrated into top-right border, white X. |
| Empty message | `20,51,60,3` | No Score Card yet! centered with generous blank area below; no red footer button. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- The only visible dismissal control is the top-right X.
- No subject scores, chart, tabs or sorting controls belong in this empty state.
- The dimmed hub remains in position; the overlay does not shift its layout.

## Fine-tuning checklist

1. Use the intentionally compact dialog height, unlike the tall Calendar modal.
2. Keep title/message centered and separated rather than stacking at the very top.
3. Match integrated corner-close geometry instead of floating a small plain X outside the border.

## What this picture does not establish

The image establishes only the empty state; populated score layout and dismissal by outside tap are unknown.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/day_menu.dart](../../lib/ui/day_menu.dart)
- [lib/ui/transitions.dart](../../lib/ui/transitions.dart)

## Compare with

- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)
- [UIR-16 — Calendar — tall modal with one exam entry](16-calendar-single-exam-entry-005234.md)

![Score Card — empty-state modal](../../references/screenshots/15-score-card-empty-dialog-005229.jpg)
