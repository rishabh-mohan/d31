# UIR-12 — Expanded Stationery — empty equipment and category filters

[Full screenshot](../../references/screenshots/12-commerce-stationery-empty-equipment-005215.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `12-commerce-stationery-empty-equipment-005215.jpg` |
| Original image | `Screenshot_20261023_005215_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:15 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `2974f78824c5599c7c955956795745195831bfa6d5332d4b4438021e2bf167d1` |

## Visible state

Stationery tab open with four empty equipped slots and an empty collection area.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Title | `0,5,100,11` | Cream/orange commerce shell, centered Stationery title, brown horizontal rule. |
| Equipped section | `6,19,88,11` | Equipped label above one horizontal row of four black-header cards: Pencils, Erasers, Notebooks, Fineliners. Gray art boxes, cream lower strips. |
| Set hint | `11,32,78,3` | Peach rounded shadowed callout: Equip stationery with matching names for Set Effects! |
| Filters | `6,37,88,3` | Five outlined pills in one row: All, Pencils, Erasers, Notebooks, Fineliners. All has filled orange toggle; others hollow. |
| Collection/body | `6,41,88,35` | Large cream empty region; no fabricated items or empty-state text in this frame. |
| Actions/footer | `12,76,76,24` | Rule, centered orange Combine, large red Close, then bottom orange four-way navigation with Stationery active. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Equipped row is separate from owned collection below the filters.
- Combine is above Close and is not the active bottom tab.
- The set-effect hint is explanatory text rather than a reward or purchase button.
- Active category is conveyed by the small filled toggle inside its pill.

## Fine-tuning checklist

1. Keep all four equipped cards in a single row on this expanded screen, unlike the hub’s 2×2 arrangement.
2. Reserve distinct vertical space for hint, filters, collection and footer.
3. Reuse black card headers, rounded borders and cream name/effect strips.

## What this picture does not establish

The image does not show owned-item selection behavior or combining rules; consult 010114. Empty collection does not establish a universal starting inventory.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)

## Compare with

- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)
- [UIR-26 — Combine Stationery — four ingredient slots and owned cards](26-stationery-combine-four-empty-slots-010114.md)
- [UIR-27 — Stationery result — Invisible Pencil confirmation](27-stationery-result-invisible-pencil-010121.md)

![Expanded Stationery — empty equipment and category filters](../../references/screenshots/12-commerce-stationery-empty-equipment-005215.jpg)
