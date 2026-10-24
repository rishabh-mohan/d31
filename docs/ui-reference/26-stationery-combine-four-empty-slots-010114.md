# UIR-26 — Combine Stationery — four ingredient slots and owned cards

[Full screenshot](../../references/screenshots/26-stationery-combine-four-empty-slots-010114.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `26-stationery-combine-four-empty-slots-010114.jpg` |
| Original image | `Screenshot_20261023_010114_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:01:14 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `4dfba2b0aacd52712181cce73a782ec612a3f822f9f2380da5e9bdb816e3b86c` |

## Visible state

Large combination window over the dimmed game; four ingredient slots are empty, All filter selected.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Window/title | `1,5,98,93` | Cream/orange nearly full-height modal; Combine Stationery centered, integrated orange top-right X. |
| Ingredients | `14,14,72,15` | Four equal tall gray rounded rectangles with black outlines. Each has a red rounded remove button with white X directly below. |
| Combine action | `7,31,86,6` | Wide orange Combine button; brown separator beneath. |
| Filters | `7,40,86,3` | All, Pencils, Erasers, Notebooks, Fineliners outlined pills. All toggle filled orange. |
| Inventory | `9,44,78,23` | Four small cards across first row: Cosmic Eraser Science +12 and Invisible Fineliner English +6 carry a white stationery-box overlay and look muted; Mala Fineliner Maths +6; Mala Notebook English +6. Second-row Spiky Eraser English +6 at left. |
| Lower space | `7,67,86,27` | Large blank cream inventory area ending at a brown rule. No commerce bottom tabs or red footer Close button. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Four ingredient placeholders define maximum visible input slots.
- Individual red X controls remove an input; top-right X dismisses the window.
- Inventory overlays on the first two cards suggest equipped/reserved status, but their precise meaning requires code/catalog confirmation.
- Combine is visible even with no ingredients; the still does not prove that pressing it is valid.

## Fine-tuning checklist

1. Maintain a four-column inventory and equal slot/remove-button alignment.
2. Do not confuse the ingredient placeholders with the smaller owned cards.
3. Keep the large Combine action above filters, not at the bottom of the window.

## What this picture does not establish

Only four empty slots are established visually. The user’s separate 2–4-copy requirement controls valid counts; rarity odds, pricing and consumption are not recoverable from this frame.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-25 — Stationery draw — Cosmic Eraser kept/locked](25-stationery-draw-kept-card-lock-010102.md)
- [UIR-27 — Stationery result — Invisible Pencil confirmation](27-stationery-result-invisible-pencil-010121.md)

![Combine Stationery — four ingredient slots and owned cards](../../references/screenshots/26-stationery-combine-four-empty-slots-010114.jpg)
