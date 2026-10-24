# UIR-13 — Expanded Books — Korean E book and locked D/C tiers

[Full screenshot](../../references/screenshots/13-commerce-books-korean-locked-tiers-005220.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `13-commerce-books-korean-locked-tiers-005220.jpg` |
| Original image | `Screenshot_20261023_005220_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:20 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `70105100d21103fa809f9242d316716d70e552c330045aa9997393f1e8e59006` |

## Visible state

Korean selected; all subject totals 50; E-tier Korean Textbook has zero reading progress.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Title/subjects | `6,8,88,14` | Books heading and rule; five pastel subject tiles. Orange rounded underline beneath Korean indicates selected tab. |
| E-tier card | `11,28,78,17` | Gray E rail at left; peach body: Korean Textbook, separator, pink Korean chip and +15, separator, empty outlined progress bar, 0 above left and small crown/coin with (4) at right. |
| D-tier lock | `11,48,78,17` | Muted mauve D rail, blurred/washed body and large centered black padlock. Text: Unlocked when you complete reading Korean E Tier-1 book(s). |
| C-tier lock | `11,68,78,17` | Orange C rail, same lock treatment. Text names Korean D Tier-1 book(s). |
| Footer | `12,88,76,12` | Fixed red Close button and orange commerce bar; Books active with label at left. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Five subject tiles are interactive tabs, distinct from the unchanging tier rail.
- E/D/C are display letters; do not print raw numeric source ranks.
- Locked cards withhold the book’s normal descriptive layout.
- Progress/reward markers are aligned within the book body rather than below the whole card.

## Fine-tuning checklist

1. Keep the selected underline separate from the subject tile’s shadow.
2. Retain large card heights and the lock silhouette; do not render locks as tiny inline icons.
3. Later user wording overrides this screenshot: name the previous book only if it is unlocked; otherwise say the previous book.

## What this picture does not establish

(4) is a visible marker beside the crown/coin, not proof of an item reward algorithm. See the separate reading-complete capture for saturated progress behavior.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/pack_menus.dart](../../lib/ui/pack_menus.dart)
- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/engine/pack.dart](../../lib/engine/pack.dart)

## Compare with

- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)
- [UIR-33 — Gameplay — Reading Complete book and quick stamina-item panel](33-gameplay-completed-book-stamina-item.md)

![Expanded Books — Korean E book and locked D/C tiers](../../references/screenshots/13-commerce-books-korean-locked-tiers-005220.jpg)
