# UIR-16 — Calendar — tall modal with one exam entry

[Full screenshot](../../references/screenshots/16-calendar-single-exam-entry-005234.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `16-calendar-single-exam-entry-005234.jpg` |
| Original image | `Screenshot_20261023_005234_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:34 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `340d1b93ef861b12f4a8d3fb88a803728b910dc8945d231cb18994049aecbaaa` |

## Visible state

Calendar open over preparation; only Graduation Exam entry is visible.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Dialog | `2,17,96,69` | Tall cream/orange modal with top-centered Calendar title and integrated orange X corner at upper right. |
| Entry card | `8,26,79,9` | One wide peach shadowed row near the top. Orange left segment contains D-31 and small capsule/0 line; right segment says Graduation Exam in large brown type. |
| Empty remainder | `7,36,86,48` | Large intentionally empty cream region; no month grid or extra fictional entries. |
| Backdrop | `0,0,100,100` | Darkened preparation HUD/goal above; equipment and green start remain faintly visible behind modal. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Top-right X is visible; there is no red Close footer in this screenshot.
- This is an agenda/list presentation, not a conventional calendar grid.
- Single entry does not cause the modal to shrink to its content height.

## Fine-tuning checklist

1. Retain tall bounded geometry for one entry; avoid content-driven collapse.
2. Keep orange date strip and peach title region part of one rounded row.
3. Align the row below the heading with generous horizontal insets and a large blank lower area.

## What this picture does not establish

The small 0/capsule line is transcribed as visible; its semantic meaning is not proven. Entry tapping and multiple-entry scrolling are not demonstrated.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/day_menu.dart](../../lib/ui/day_menu.dart)
- [lib/ui/transitions.dart](../../lib/ui/transitions.dart)
- [lib/engine/game_date.dart](../../lib/engine/game_date.dart)

## Compare with

- [UIR-15 — Score Card — empty-state modal](15-score-card-empty-dialog-005229.md)
- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)

![Calendar — tall modal with one exam entry](../../references/screenshots/16-calendar-single-exam-entry-005234.jpg)
