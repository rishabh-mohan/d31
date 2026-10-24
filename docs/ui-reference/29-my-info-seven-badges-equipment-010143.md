# UIR-29 — My Info — identity, seven university crests and stationery

[Full screenshot](../../references/screenshots/29-my-info-seven-badges-equipment-010143.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `29-my-info-seven-badges-equipment-010143.jpg` |
| Original image | `Screenshot_20261023_010143_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:01:43 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `af53f244463b774d1b45189e87103f0fc1bbafff63a7c780268db8f27422d613` |

## Visible state

My Info open over the D-28 School screen; seven university badges, no traits, three equipped stationery items.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Dialog | `1,15,98,73` | Cream/orange rounded modal with centered My Info title and integrated orange top-right X. Peach rounded/shadowed inner content panel. |
| Identity | `12,24,76,13` | Small full-layer portrait left; Greg Fiasco right; LV2 Hardworking Student (1800/4950), 1170 Gold, Exercise Level1 (20.0%), Part-Time Level2 (0.0%). |
| Subjects | `12,38,76,5` | Five pastel tiles: Korean527, Maths145, English546, Science771, Humnts.475. |
| Universities | `15,45,70,15` | Four circular crests above three centered ones. Same selected universities as 005058, with double rings, real icons and small labels. |
| Lower grid | `10,61,80,24` | Brown horizontal separator and vertical center divider. Traits side left has dash. Right 2×2 equipment: Invisible Pencil/Korean+6, Cosmic Eraser/Science+12; empty Notebooks, Invisible Fineliner/English+6. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Top-right X is the only visible close control.
- All sections fit in one displayed panel; the user explicitly requires no My Info scrolling.
- Crests contain university names, rather than wrapping name chips that grow the dialog.
- Equipped stationery keeps black category header, art, name, subject strip; the empty notebook keeps its gray art box.

## Fine-tuning checklist

1. Use a small portrait/identity block so the seven badges and equipment remain visible.
2. Keep the four-plus-three crest rows centered and fixed in height, including very long university names.
3. Align the trait/equipment divider under the badge section and scale contents within their bounds when crowded.

## What this picture does not establish

The faint gray left-edge handle appears in many captures and is not a My Info scrollbar. This screenshot does not show long player names or many traits; verify those edge cases separately.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/my_info.dart](../../lib/ui/my_info.dart)
- [lib/ui/university_badge.dart](../../lib/ui/university_badge.dart)
- [lib/ui/portrait.dart](../../lib/ui/portrait.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)

## Compare with

- [UIR-04 — Setup 3/5 — seven selected university badges](04-setup-03-university-badges-selected-005058.md)
- [UIR-28 — Gameplay — stamina mission and completed weekly goal](28-gameplay-school-mission-goal-complete-010138.md)

![My Info — identity, seven university crests and stationery](../../references/screenshots/29-my-info-seven-badges-equipment-010143.jpg)
