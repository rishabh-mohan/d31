# UIR-24 — Stationery draw — stopped result with free redraw

[Full screenshot](../../references/screenshots/24-stationery-draw-stopped-free-redraw-010059.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `24-stationery-draw-stopped-free-redraw-010059.jpg` |
| Original image | `Screenshot_20261023_010059_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:00:59 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `1eac7091783aafc81f7386cf17f3cd8bbb8992436763ed7c1ae78e7ac8de76c4` |

## Visible state

Five stopped cards, confetti in flight, no lock overlay visible yet; cookies owned 53.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Card group | `4,11,92,37` | Top: Faded Fineliner / Maths +3; Rectangular Eraser / Science +3; Rectangular Notebook / Korean +3. Bottom: Cosmic Eraser / Science +12 on gold; Dirty Pencil / Maths +3 on brown. |
| Guarantee/help | `18,69,64,10` | Cream rounded orange-outlined panel: coral Re-draw : B-Tier and above guaranteed, then Tap on stationery you’d like to keep before a re-draw. |
| Wallet | `32,80,36,2` | Cookies Owned : 53 in centered white text. |
| Actions | `27,84,46,13` | Orange Free re-draw button above cream Close button with orange text. |
| Decoration | `0,45,100,55` | Tan/yellow confetti overlays lower cards and the space around the help/action area. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Tap a card to keep it before redrawing; this instruction is explicit.
- Free re-draw and Close are separate stacked actions.
- No card is visibly dimmed/locked in this capture.
- The rectangular notebook label reaches near the card edges; avoid letting text escape its cream name strip.

## Fine-tuning checklist

1. Keep help and wallet readable over confetti with opaque cream help background.
2. Reserve stable space for buttons; confetti should not change their position or hit areas.
3. Match the five-card arrangement from 010049 despite moving the group upward to make room for redraw controls.

## What this picture does not establish

Guarantee text is observed but exact tier probabilities and later redraw costs are unknown. A free button does not establish unlimited free redraws.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/stationery_draw.dart](../../lib/ui/stationery_draw.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)
- [docs/STATIONERY.md](../../docs/STATIONERY.md)

## Compare with

- [UIR-23 — Stationery draw — rolling cards and Stop all Stationery](23-stationery-draw-rolling-stop-all-010049.md)
- [UIR-25 — Stationery draw — Cosmic Eraser kept/locked](25-stationery-draw-kept-card-lock-010102.md)

![Stationery draw — stopped result with free redraw](../../references/screenshots/24-stationery-draw-stopped-free-redraw-010059.jpg)
