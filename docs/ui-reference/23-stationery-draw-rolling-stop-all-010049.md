# UIR-23 — Stationery draw — rolling cards and Stop all Stationery

[Full screenshot](../../references/screenshots/23-stationery-draw-rolling-stop-all-010049.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `23-stationery-draw-rolling-stop-all-010049.jpg` |
| Original image | `Screenshot_20261023_010049_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:00:49 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `ef8e8c59d2b901366642960e8e4210aef709a8ece1e37dca38152e3e8a2b738b` |

## Visible state

Five-card draw on a dark vignette; Stop all Stationery is present, so this is the pre-stop presentation.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Canvas | `0,0,100,100` | Black/charcoal vignette with pale glow behind cards; no gameplay HUD or commerce navigation. |
| Top three cards | `4,29,92,18` | Pencils/Invisible Pencil/Korean +6 (gold-bar artwork), Fineliners/Dirty Fineliner/Science +3, Erasers/Seoul Eraser/Korean +27 (rainbow art panel). |
| Bottom two cards | `20,50,60,18` | Pencils/Mala Pencil/Humnts. +6 and Erasers/Spiky Eraser/English +6, centered under the first row. |
| Instruction | `12,74,76,3` | Tap on a stationery to obtain them. in large white centered text. |
| Stop action | `27,77,46,5` | Wide orange rounded Stop all Stationery button; no Free re-draw/Close controls in this frame. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Three-over-two arrangement has fixed card slots, equal card widths and rounded black outlines.
- Each card separates black category header, large art panel, cream name strip and subject-colored bonus strip.
- The gold bar paired with Invisible Pencil is an observed transient mismatch; do not permanently assign gold art to that item.
- User clarified the cards cycle continuously until stopped; the still proves this frame and button label, not the animation rate.

## Fine-tuning checklist

1. Keep the glow behind the card group and whitespace above it.
2. Respect tier art backgrounds: pale gray/lavender, brown, gold and rainbow are visually distinct.
3. Do not replace the rolling state with a permanently dealt static hand.

## What this picture does not establish

The image does not establish odds, animation speed, per-card stopping order, or whether the mismatched art is an intermediate update. Use the later stopped/locked captures as separate states.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/stationery_draw.dart](../../lib/ui/stationery_draw.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)
- [docs/STATIONERY.md](../../docs/STATIONERY.md)

## Compare with

- [UIR-24 — Stationery draw — stopped result with free redraw](24-stationery-draw-stopped-free-redraw-010059.md)
- [UIR-25 — Stationery draw — Cosmic Eraser kept/locked](25-stationery-draw-kept-card-lock-010102.md)

![Stationery draw — rolling cards and Stop all Stationery](../../references/screenshots/23-stationery-draw-rolling-stop-all-010049.jpg)
