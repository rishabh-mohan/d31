# UIR-11 — Expanded Store — price order and Saturday stock

[Full screenshot](../../references/screenshots/11-commerce-store-price-sorted-005211.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `11-commerce-store-price-sorted-005211.jpg` |
| Original image | `Screenshot_20261023_005211_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:11 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `5224a282bc148247fce7a9bed140630bb8af1702ba66863cf9a7ba52fa4be6f8` |

## Visible state

Store open over the dimmed hub; wallet 0 Gold; ascending-price arrow visible.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Window | `0,5,100,90` | Near-full-width cream modal with orange perimeter; centered Store heading, coral restock notice and brown rule. |
| Toolbar | `13,17,74,4` | Owned : 0 Gold in outlined cream pill; Sort by price ↑ in filled orange pill with filter icon. |
| Item list | `12,23,72,63` | Wide peach rounded cards, vertical scrolling. Icon left, item title/category right, separator, effect, separator, flavor text, price/stock button. |
| Visible offers | `15,25,68,56` | Weird Workbook (Consumables), random-subject Stats +90, Looks wacky, but pretty helpful., 1500 Gold (2/2). Book Stand (Others), all-subject study efficiency +3, Helps you study with proper posture., 9000 Gold (1/1). Coffee Machine, Get 8 Coffees, Amazing for caffeine addicts., 16000 Gold (1/1). Level 8 Suit is partially visible below. |
| Fixed footer | `12,88,76,11` | Brown rule, broad red Close button, orange bottom navigation. Book, gift/items, store and pencil icons; Store label expanded beside its icon. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- New items arrive at the store every Saturday. is above the list, not an item description.
- Price buttons have red/pink outlines and cream fill; stock is shown in parentheses.
- Bottom navigation switches commerce categories without dismissing the shell.
- Only the item list scrolls; the bottom Close/nav remain reachable.

## Fine-tuning checklist

1. Do not squeeze full item descriptions into the compact preview-row layout.
2. Maintain clear title/category/effect/flavor hierarchy and consistent icon column.
3. Allow the next offer to clip at the viewport edge while keeping the footer opaque.

## What this picture does not establish

A zero wallet with visible price buttons does not prove the purchase validation or disabled style. Only the first three visible prices are fully established here.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/ui/pack_menus.dart](../../lib/ui/pack_menus.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-10 — Preparation hub — Store previews, empty traits and equipment](10-preparation-hub-empty-traits-equipment-005207.md)
- [UIR-22 — Item acquired — Weird Workbook Use/Confirm modal](22-commerce-item-acquired-use-confirm-010019.md)

![Expanded Store — price order and Saturday stock](../../references/screenshots/11-commerce-store-price-sorted-005211.jpg)
