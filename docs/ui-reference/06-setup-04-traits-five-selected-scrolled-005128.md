# UIR-06 — Setup 4/5 — five traits selected, catalog scrolled

[Full screenshot](../../references/screenshots/06-setup-04-traits-five-selected-scrolled-005128.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `06-setup-04-traits-five-selected-scrolled-005128.jpg` |
| Original image | `Screenshot_20261023_005128_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:51:28 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `af4e72c24f9e9d2b51ec4359ec0388824de3de52e4aa11948d185bba912caffa` |

## Visible state

All five slots occupied; lower catalog position demonstrates independent scrolling.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Pinned top | `0,0,100,44` | Step header, Add FiascoGreg’s Traits, same portrait/selection panel as 005119. |
| Selected slots | `58,20,29,23` | Indestructible; Time Jumper; Energizer; MBTI S. Realistic; Master of 108 Bows. All green, equal width/height. |
| Scrolled list | `5,46,90,46` | Traits List title fixed. Partial toggles from previous row visible at top; A-tier Stubborn and Master of 108 Bows cards fully visible; next row clipped at bottom. |
| Card details | `11,60,78,19` | Stubborn: Random chance to remain at 1 Stamina instead of fainting. Master of 108 Bows: University acceptance chance X1.08. X1 inventory at top right. |
| Footer | `9,94,82,5` | Same Purchase/Combine Traits and Next controls as before scrolling. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Stubborn toggle is cream/empty; Master of 108 Bows toggle is orange/filled.
- The portrait, five selections and footer do not move with the catalog.
- A selected card is represented both in the grid toggle and in its top slot.
- This frame demonstrates that row clipping at the scroll viewport edge is intentional.

## Fine-tuning checklist

1. Do not stretch the five summary chips to fit their text; scale or wrap inside fixed slots.
2. Clip catalog content to the rounded pane without clipping its fixed title/footer.
3. Allow deselection at the five-item limit; prevent a sixth selection without hiding the list.

## What this picture does not establish

Exact maximum and toggling behavior are supported by setup requirements; a screenshot alone does not establish trait consumption or incompatibilities. X1.08 is printed prose, not independently recovered admission code.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/setup_widgets.dart](../../lib/ui/setup_widgets.dart)
- [lib/engine/setup.dart](../../lib/engine/setup.dart)
- [lib/engine/traits.dart](../../lib/engine/traits.dart)

## Compare with

- [UIR-05 — Setup 4/5 — trait selection with three occupied slots](05-setup-04-traits-partially-selected-005119.md)
- [UIR-07 — Setup 5/5 — first and last name entry](07-setup-05-player-name-005149.md)

![Setup 4/5 — five traits selected, catalog scrolled](../../references/screenshots/06-setup-04-traits-five-selected-scrolled-005128.jpg)
