# UIR-25 — Stationery draw — Cosmic Eraser kept/locked

[Full screenshot](../../references/screenshots/25-stationery-draw-kept-card-lock-010102.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `25-stationery-draw-kept-card-lock-010102.jpg` |
| Original image | `Screenshot_20261023_010102_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:01:02 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `cd15bdf4ad0c9a3de3324d144dc90122d9dee69f3b618f2d20867e5c343f7188` |

## Visible state

Same stopped result as 010059, with Cosmic Eraser visibly selected to keep.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Card layout | `4,11,92,37` | Same five card identities and slots as previous capture; the Cosmic Eraser occupies lower-left slot. |
| Lock state | `20,31,25,17` | Cosmic Eraser card is darkened over header, artwork and text; a large black padlock is centered on the gold art panel. |
| Help | `18,69,64,10` | Same guarantee and keep-before-redraw instruction in cream/orange box. |
| Wallet/actions | `27,80,46,17` | Cookies Owned : 53, Free re-draw, Close. No confetti obscures the selected card or action labels in this frame. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Only the kept card is dimmed/locked; the other four remain normally lit.
- The keep state must be visible beyond a tiny checkbox: the padlock covers a substantial portion of the artwork.
- Selection changes do not move the five cards, help panel or footer controls.
- The card’s identity and Science +12 strip remain faintly readable under the overlay.

## Fine-tuning checklist

1. Use a card-local dark scrim, not an extra full-screen modal.
2. Keep padlock centered within the art area and preserve outer card silhouette.
3. Retain a usable redraw action while at least one card is kept.

## What this picture does not establish

The screenshot does not show a redraw after locking or whether locked cards require an additional confirmation. It proves the keep-state styling, not its full persistence semantics.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/stationery_draw.dart](../../lib/ui/stationery_draw.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)
- [lib/engine/state.dart](../../lib/engine/state.dart)

## Compare with

- [UIR-24 — Stationery draw — stopped result with free redraw](24-stationery-draw-stopped-free-redraw-010059.md)
- [UIR-26 — Combine Stationery — four ingredient slots and owned cards](26-stationery-combine-four-empty-slots-010114.md)

![Stationery draw — Cosmic Eraser kept/locked](../../references/screenshots/25-stationery-draw-kept-card-lock-010102.jpg)
