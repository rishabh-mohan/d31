# UIR-10 — Preparation hub — Store previews, empty traits and equipment

[Full screenshot](../../references/screenshots/10-preparation-hub-empty-traits-equipment-005207.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `10-preparation-hub-empty-traits-equipment-005207.jpg` |
| Original image | `Screenshot_20261023_005207_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:07 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `ebcd2f6a9683f1be1733249970b7fdb1558b3a535d3a2dcb876f10f4370bea76` |

## Visible state

D-31 Monday, 0 Gold, 53 cookies; five subjects at 50, no traits or stationery equipped.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| HUD | `2,4,96,5` | Orange hamburger, segmented D-31/Mon cells, Gold/cookie cells and orange information button. Soft shadows under each group. |
| Goal/stat panel | `2,10,96,10` | Weekly Goals row: Korean Reach 398 → Science Reward 294. Five colored stat tiles below. |
| Schedule strip | `2,21,96,3` | Orange D-31 segment at left, Graduation Exam on cream right segment. |
| Traits/Store | `2,25,96,36` | Two equal-width peach panels. Left Traits has a dash; right Store has five small cream preview rows with icon, title and ellipsized effect. |
| Lower panels | `2,62,96,27` | Stationery at left with 2×2 black-header empty cards. Right orange 2×2 shortcuts: Books/Items above Score Card/Schedule. |
| Start | `2,91,96,7` | Full-width green play button, rounded corners and darker lower edge. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Store previews: Weird Workbook, Book Stand, Coffee Machine, Level 8 Suit, Ultimate Noteb…; final title is visibly truncated.
- Equipment categories: Pencils, Erasers, Notebooks, Fineliners. Empty art is gray and lower name area cream.
- The shortcuts use large cream line icons and separate labels.
- Store/Stationery/Books/Items are menu entries; the green play button starts actions.

## Fine-tuning checklist

1. Preserve aligned left/right panel edges, compact top HUD and oversized start button.
2. Keep item icons visibly larger than their effect text.
3. Later user instructions override the capture’s proportions: Traits/Store should be taller, and a crowded trait list should scroll within its panel.

## What this picture does not establish

Five preview rows are observed, but the user permits fewer rows to make icons readable. Do not copy sample goal/cookie numbers as fixed defaults.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/day_menu.dart](../../lib/ui/day_menu.dart)
- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)

## Compare with

- [UIR-09 — Preparation — first Weekly Goals announcement](09-preparation-weekly-goal-announcement-005202.md)
- [UIR-11 — Expanded Store — price order and Saturday stock](11-commerce-store-price-sorted-005211.md)
- [UIR-12 — Expanded Stationery — empty equipment and category filters](12-commerce-stationery-empty-equipment-005215.md)
- [UIR-13 — Expanded Books — Korean E book and locked D/C tiers](13-commerce-books-korean-locked-tiers-005220.md)
- [UIR-14 — Expanded Bags/Items — empty consumables](14-commerce-items-empty-consumables-005225.md)

![Preparation hub — Store previews, empty traits and equipment](../../references/screenshots/10-preparation-hub-empty-traits-equipment-005207.jpg)
