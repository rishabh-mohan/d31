# UIR-03 — Setup 3/5 — university badges with seven empty slots

[Full screenshot](../../references/screenshots/03-setup-03-university-badges-empty-004804.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `03-setup-03-university-badges-empty-004804.jpg` |
| Original image | `Screenshot_20261023_004804_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:48:04 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `a3609614dcd43d937834875114e8ffc8a94eb52d034155d7fa9cd397932b207f` |

## Visible state

No badge selected; alphabetical catalog starts with Boryeong, Cheorwon and Chwang Gung.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header/title | `0,0,100,21` | Select Character (3 / 5) header, then Select University Badges and (up to 7 Badges), centered. |
| Pinned selection | `4,24,92,21` | Four large empty circles across the first row; three centered below. Orange outline and short orange dash in every slot. |
| Ordering label | `20,46,60,3` | (Alphabetical order) centered above catalog. |
| Badge list | `8,51,84,37` | Three visible wide rounded colored rows. Circular crest/name badge overlaps left edge; effect fills right. Boryeong/blue: Korean Study Efficiency +7; Cheorwon/navy: All base stat +200; Chwang Gung/gold: Korean +18 and Science +18. |
| Footer | `32,92,36,5` | Orange Next button fixed beneath list; faded classroom remains visible around panels. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Seven is an upper bound, not a requirement to fill every slot.
- List rows are selection candidates; empty slots are a persistent selection summary.
- Next remains visible below the list. Back arrow retains the common setup position.
- Crest and university name share the circular badge; the effect belongs in the adjoining rounded rectangle.

## Fine-tuning checklist

1. Keep four-plus-three centered geometry even when names are long.
2. Use college-specific border/text colors and pale tinted effect-row fills.
3. Scroll the catalog beneath a stable selection area and footer, not the whole page.

## What this picture does not establish

Ownership/unlock rules are not shown. The screenshot proves empty-slot appearance, not whether selection consumes a badge. Compare the filled state in 005058.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/setup_widgets.dart](../../lib/ui/setup_widgets.dart)
- [lib/ui/university_badge.dart](../../lib/ui/university_badge.dart)
- [tools/presentation_assets.py](../../tools/presentation_assets.py)

## Compare with

- [UIR-04 — Setup 3/5 — seven selected university badges](04-setup-03-university-badges-selected-005058.md)
- [UIR-29 — My Info — identity, seven university crests and stationery](29-my-info-seven-badges-equipment-010143.md)

![Setup 3/5 — university badges with seven empty slots](../../references/screenshots/03-setup-03-university-badges-empty-004804.jpg)
