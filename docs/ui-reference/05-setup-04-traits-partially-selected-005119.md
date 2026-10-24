# UIR-05 — Setup 4/5 — trait selection with three occupied slots

[Full screenshot](../../references/screenshots/05-setup-04-traits-partially-selected-005119.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `05-setup-04-traits-partially-selected-005119.jpg` |
| Original image | `Screenshot_20261023_005119_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:51:19 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `1b6483fe60e0a38d86ff3df0cd7f249461c91ecafa7a1e6b4487fbe111a6f66c` |

## Visible state

Three selected traits and two empty slots; trait catalog near its top.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header/title | `0,0,100,17` | Select Character (4 / 5), then Add FiascoGreg’s Traits. The concatenated name is observed text, not a naming rule. |
| Selection panel | `5,19,90,25` | Cream rounded panel with brown border: large character left, five fixed vertical slots right. Green selected slots: Indestructible, Time Jumper, Energizer. Two cream/orange dashed slots below. |
| Catalog panel | `5,46,90,46` | Peach/brown outlined pane, Traits List heading, two-column cards with large vertical gaps between rows. |
| Trait cards | `11,53,78,38` | S headers black; A headers gold. Each header has tier and X1 count, cream body with centered name/description; a separate small rounded-square toggle sits below each card. |
| Footer | `9,94,82,5` | Purchase/Combine Traits left and Next right, both orange with darker bottom edge. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Indestructible: Stamina Cost -3. Time Jumper: 10% chance of no stamina cost.
- Next visible A row: Master of Notes, Obtain a Weird Workbook every time you finish a book; Paid Holidays, Part-Time earnings +300.
- Selected summary slots stay above the scrolling list. The picture shows the catalog and five-slot summary as distinct panels.
- Purchase/Combine Traits is a separate collection flow; it does not start gameplay.

## Fine-tuning checklist

1. Use black S and gold A headers rather than polarity-colored catalog cards; selected summary chips are green.
2. Keep portrait bottom-aligned and text/toggles centered within each column.
3. Pin footer actions and the selected-trait panel while the catalog scrolls.

## What this picture does not establish

The catalog’s sample inventory counts are not universal defaults. Screenshot does not establish compatibility, consumption, reroll prices or proc timing.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/setup_widgets.dart](../../lib/ui/setup_widgets.dart)
- [lib/ui/portrait.dart](../../lib/ui/portrait.dart)
- [lib/engine/setup.dart](../../lib/engine/setup.dart)

## Compare with

- [UIR-06 — Setup 4/5 — five traits selected, catalog scrolled](06-setup-04-traits-five-selected-scrolled-005128.md)
- [UIR-07 — Setup 5/5 — first and last name entry](07-setup-05-player-name-005149.md)

![Setup 4/5 — trait selection with three occupied slots](../../references/screenshots/05-setup-04-traits-partially-selected-005119.jpg)
