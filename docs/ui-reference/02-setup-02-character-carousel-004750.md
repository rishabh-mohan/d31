# UIR-02 — Setup 2/5 — character collection and Student ID carousel

[Full screenshot](../../references/screenshots/02-setup-02-character-carousel-004750.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `02-setup-02-character-carousel-004750.jpg` |
| Original image | `Screenshot_20261023_004750_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:47:50 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `e09bb55f5e82918aeeb25212a4069ea4938584e6e77d15563f9081096280501c` |

## Visible state

Default Boy is displayed; account sample says 85% (22/26), filter Owned.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header | `0,0,100,11` | Same cream header/back arrow, title Select Character (2 / 5). |
| Promotion | `1,12,98,24` | Large coral-to-peach character-draw banner with three-star heading, card artwork, Draw Character text and Shortcut>> at upper right. |
| Collection heading | `2,37,96,10` | Rounded peach panel begins; My Character centered, Owned dropdown at top right; completion line below. |
| Carousel | `20,48,80,41` | Selected Student ID card centered left of a cropped next card. Pink patterned card, star rail, portrait, Default Boy, No additional effects. Next card deliberately peeks from right. |
| Navigation/CTA | `3,66,94,32` | Orange circular double-chevron arrows straddle the carousel. Orange Select button centered near bottom with darker lower edge. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Owned dropdown distinguishes collection filtering from character selection.
- Left/right arrows and the partial neighboring card indicate horizontal browsing.
- The displayed card has one visible star; stars are rarity indicators, not selection toggles.
- Select commits the shown candidate to the next step; exact tap timing is not visible.
- Draw Character/Shortcut is a separate promotion, not a character automatically granted on entry.

## Fine-tuning checklist

1. Portrait must include body, face/expression and clothing aligned on their shared canvas.
2. Keep the portrait as the dominant card content; reserve separate space for name and effect prose.
3. Maintain the clipped neighboring card and avoid turning this screen into a vertical list.

## What this picture does not establish

22/26 and 85% are this account’s sample values. User later authorized all eligible characters unlocked in the prototype. Screenshot does not prove draw cost or odds.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/setup_widgets.dart](../../lib/ui/setup_widgets.dart)
- [lib/ui/portrait.dart](../../lib/ui/portrait.dart)
- [lib/engine/pack.dart](../../lib/engine/pack.dart)

## Compare with

- [UIR-01 — Setup 1/5 — difficulty selection](01-setup-01-difficulty-004736.md)
- [UIR-03 — Setup 3/5 — university badges with seven empty slots](03-setup-03-university-badges-empty-004804.md)

![Setup 2/5 — character collection and Student ID carousel](../../references/screenshots/02-setup-02-character-carousel-004750.jpg)
