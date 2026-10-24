# UIR-22 — Item acquired — Weird Workbook Use/Confirm modal

[Full screenshot](../../references/screenshots/22-commerce-item-acquired-use-confirm-010019.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `22-commerce-item-acquired-use-confirm-010019.jpg` |
| Original image | `Screenshot_20261023_010019_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:00:19 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `554d2887fd0a1b312fbb5eba4cd86885a8ece4e35a7661c99100a12e10aefd2a` |

## Visible state

Workbook reward/acquisition popup overlays the already-open Store; underlying wallet says 1170 Gold.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Layering | `0,0,100,100` | Store behind a second dark scrim; its title, Saturday notice, wallet, offer cards and bottom navigation remain visible. |
| Modal | `4,29,92,46` | Cream dialog, thick orange rounded border; large red workbook artwork centered near top. |
| Copy | `15,46,70,12` | Got a Weird Workbook! heading; Looks wacky, but pretty helpful.; Stats +90 for a random subject, centered on separate lines. |
| Actions | `32,60,36,12` | Smaller orange Use button above a wider orange Confirm button, both with darker lower edge/shadow. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Use and Confirm are separate controls; do not collapse them to one unlabeled tap target.
- Use is visually subordinate in width but presented before Confirm.
- The source of the acquisition cannot be identified from the popup alone; avoid assuming a particular reward or purchase path.
- Store Close/navigation remain dimmed beneath the acquisition modal.

## Fine-tuning checklist

1. Give the item artwork enough room to remain identifiable at a glance.
2. Keep flavor text separate from numeric effect; do not ellipsize the main effect in this detailed popup.
3. Maintain two-level modality, with only the top popup receiving input.

## What this picture does not establish

Popup confirms an available Use option; it does not show whether Use also dismisses it, when inventory is consumed, or purchase affordability. 1170 Gold is a sample state.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/engine/effects.dart](../../lib/engine/effects.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-11 — Expanded Store — price order and Saturday stock](11-commerce-store-price-sorted-005211.md)
- [UIR-14 — Expanded Bags/Items — empty consumables](14-commerce-items-empty-consumables-005225.md)

![Item acquired — Weird Workbook Use/Confirm modal](../../references/screenshots/22-commerce-item-acquired-use-confirm-010019.jpg)
