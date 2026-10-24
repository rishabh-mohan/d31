# UIR-14 — Expanded Bags/Items — empty consumables

[Full screenshot](../../references/screenshots/14-commerce-items-empty-consumables-005225.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `14-commerce-items-empty-consumables-005225.jpg` |
| Original image | `Screenshot_20261023_005225_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:25 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `13dbfcf8d8978de2bb56489b1da0f5bce0f57e7ed2debde6bcee1df9cbc27990` |

## Visible state

Consumables selected, no items in that category; bottom tab calls this section Items while title says Bags.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header/filters | `20,8,60,10` | Bags heading. Two large outlined cream pills: Consumables with filled orange capsule, Other Items with hollow capsule. |
| Sort toolbar | `11,19,78,5` | Brown rule across content; Sort by recency ↑ orange pill aligned right with filter symbol. |
| Empty body | `11,25,78,61` | Large cream area with centered No items obtained yet. around the vertical middle. |
| Footer | `11,86,78,14` | Bottom brown rule, red Close button, orange navigation bar with gift icon and Items label active. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Category filters, sort direction and bottom navigation are three different controls.
- No item cards, counts, Use buttons or grid placeholders are visible in this state.
- Switching to Books/Store/Stationery uses the common bottom shell.
- Close returns to the dimmed caller; underlying gameplay is not replaced by an unrelated background.

## Fine-tuning checklist

1. Do not collapse the empty body to the height of its single message.
2. Keep the selected pill marker filled and the other marker outlined.
3. Retain the observed Bags-versus-Items distinction when comparing references; choose consistent product wording only through an explicit design decision.

## What this picture does not establish

Sorting behavior with multiple items and Other Items content are not shown. Do not infer inventory counts or prices from this empty view.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/ui/pack_menus.dart](../../lib/ui/pack_menus.dart)

## Compare with

- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)
- [UIR-11 — Expanded Store — price order and Saturday stock](11-commerce-store-price-sorted-005211.md)
- [UIR-22 — Item acquired — Weird Workbook Use/Confirm modal](22-commerce-item-acquired-use-confirm-010019.md)

![Expanded Bags/Items — empty consumables](../../references/screenshots/14-commerce-items-empty-consumables-005225.jpg)
