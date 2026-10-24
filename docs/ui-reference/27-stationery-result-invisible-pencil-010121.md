# UIR-27 — Stationery result — Invisible Pencil confirmation

[Full screenshot](../../references/screenshots/27-stationery-result-invisible-pencil-010121.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `27-stationery-result-invisible-pencil-010121.jpg` |
| Original image | `Screenshot_20261023_010121_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:01:21 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `dc19d1e559bda2131db037284c5503326ad081dffda0039c0e78306e94429fec` |

## Visible state

A single item reveal on the dark glow background; no origin of the reward is visible.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Backdrop | `0,0,100,100` | Dark vignette with bright gray radial glow centered behind the result; no game HUD. |
| Result card | `31,39,38,26` | Large rounded black-outlined card. Black Pencils header, pale gray/lavender art panel with dashed-outline pencil, cream Invisible Pencil name band, pink Korean +6 band. |
| Confirm | `15,86,70,7` | Wide orange rounded Confirm button in large white text; substantial gap between card and button. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Confirm is the only visible interactive control.
- Unlike the rolling 010049 frame, Invisible Pencil here has a dashed pencil illustration rather than the gold bar.
- The result reuses the normal stationery card’s category/name/subject-bonus anatomy at a larger scale.

## Fine-tuning checklist

1. Keep result art sharp and centered inside its art panel.
2. Preserve the contrast of black header, cream name and pink subject strip.
3. Do not add a second red Close button or collection navigation to this dedicated reveal.

## What this picture does not establish

This still does not prove whether the result came from combining, a draw or another grant. The filename describes the displayed result, not an assumed reward algorithm.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)
- [lib/ui/stationery_card.dart](../../lib/ui/stationery_card.dart)
- [lib/ui/stationery_draw.dart](../../lib/ui/stationery_draw.dart)

## Compare with

- [UIR-26 — Combine Stationery — four ingredient slots and owned cards](26-stationery-combine-four-empty-slots-010114.md)
- [UIR-23 — Stationery draw — rolling cards and Stop all Stationery](23-stationery-draw-rolling-stop-all-010049.md)

![Stationery result — Invisible Pencil confirmation](../../references/screenshots/27-stationery-result-invisible-pencil-010121.jpg)
