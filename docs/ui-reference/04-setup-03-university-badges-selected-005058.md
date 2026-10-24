# UIR-04 — Setup 3/5 — seven selected university badges

[Full screenshot](../../references/screenshots/04-setup-03-university-badges-selected-005058.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `04-setup-03-university-badges-selected-005058.jpg` |
| Original image | `Screenshot_20261023_005058_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:50:58 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `970d835b355a456d1b9183bf283b191d2a090f1a984fe49bf7d7e345bce2e9ad` |

## Visible state

Same setup step and list position as 004804, now with all seven slots occupied.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header/title | `0,0,100,21` | Shared step-3 header, Select University Badges and seven-badge limit. |
| Selected row 1 | `4,24,92,11` | Korea Dream University; National Tseing Hwa University; National Taiwen University; Korea Movie University. |
| Selected row 2 | `16,35,68,10` | Oxfsword University; National Yaung Ming Chao Tung University; Tworonto University, centered below row one. |
| Catalog | `8,51,84,37` | Boryeong, Cheorwon and Chwang Gung effect rows remain at the same size as the empty state. |
| Footer | `32,92,36,5` | Next remains fixed; selected names are contained inside circles and do not grow the header area. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Selected badge colors vary: blue shield, purple crest, brown seal, red clapperboard, gold/navy lotus, blue tree and navy crest.
- Long university names wrap within the circular label area in small type.
- The same crest/name treatment is reused later in My Info.
- The catalog still shows unselected choices; selection summary is independent of scroll position.

## Fine-tuning checklist

1. Compare directly against 004804: filling seven slots must not change layout height.
2. Use real crest artwork and a double-ring badge border.
3. Keep the three lower badges centered under the gaps of the first row.

## What this picture does not establish

Selection/deselection gestures are not visible in a still image. Preserve the catalog’s spellings; these are fictionalized university names, not corrections to real institutions.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/university_badge.dart](../../lib/ui/university_badge.dart)
- [lib/ui/setup_widgets.dart](../../lib/ui/setup_widgets.dart)
- [lib/ui/my_info.dart](../../lib/ui/my_info.dart)

## Compare with

- [UIR-03 — Setup 3/5 — university badges with seven empty slots](03-setup-03-university-badges-empty-004804.md)
- [UIR-29 — My Info — identity, seven university crests and stationery](29-my-info-seven-badges-equipment-010143.md)

![Setup 3/5 — seven selected university badges](../../references/screenshots/04-setup-03-university-badges-selected-005058.jpg)
