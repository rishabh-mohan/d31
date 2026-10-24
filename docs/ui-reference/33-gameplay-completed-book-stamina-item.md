# UIR-33 — Gameplay — Reading Complete book and quick stamina-item panel

[Full screenshot](../../references/screenshots/33-gameplay-completed-book-stamina-item.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `33-gameplay-completed-book-stamina-item.jpg` |
| Original image | `ref-books-letter-tiers-reading-complete-stamina-item.jpg` |
| Capture label | Not encoded in original filename (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `864d3b14d86c22e0c55d536619f59be12c103196a2dd479ac2732d5f5632c9ca` |

## Visible state

Additional reference without capture timestamp. D-28 Thursday, School, 1170 Gold, 53 cookies, 9 actions left, HP53%, rerolls522.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Persistent HUD/scene | `2,4,96,50` | School frame, LV2 Hardworking 2300/4950, neutral player portrait. Tick strip shows five completed capsules. |
| Quick-use panel | `0,34,27,14` | Small cream/orange panel extends in from left over the scene: coffee-cup artwork, circular orange right-chevron, Stamina +25, quantity1, orange Use button. Left edge is cropped by screenshot boundary. |
| Goal/stats/status | `6,54,88,14` | Weekly goal checkmark visible. Stats Korean854, Maths145, English546, Science771, Humnts.678; clock9, green53% bar, refresh522. |
| Completed book | `52,69,35,13` | Korean Textbook, pink Korean chip, gray E badge and +93. Pink Reading Complete replaces the progress bar; HP-15 remains. |
| Other actions | `13,69,74,27` | Period6 Maths +79~101 / HP-8; two identical Science Textbook E +110 / HP-15 cards with progress bars and coin markers. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Use is a separate quick-item action; the panel is not part of the four-block hand.
- The chevron suggests cycling/collapsing or moving between items, but its exact action is not shown.
- A completed book remains offered and displays a positive reward; Reading Complete does not disable the entire card.
- Letter E is shown on study cards, not source rank1.

## Fine-tuning checklist

1. Preserve the completed-book message in the progress area without removing its subject, gain or stamina cost.
2. Keep quick-use UI over the scene without shifting the action grid.
3. The user previously deferred implementing this quick-use interaction; this image documents the target and does not by itself change that authorization.

## What this picture does not establish

The quick-panel entry gesture, cycling behavior and Use result are not visible. This extra screenshot’s original timestamp/version is unknown; keep it distinct from the numbered session.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)
- [lib/ui/pack_menus.dart](../../lib/ui/pack_menus.dart)

## Compare with

- [UIR-13 — Expanded Books — Korean E book and locked D/C tiers](13-commerce-books-korean-locked-tiers-005220.md)
- [UIR-28 — Gameplay — stamina mission and completed weekly goal](28-gameplay-school-mission-goal-complete-010138.md)

![Gameplay — Reading Complete book and quick stamina-item panel](../../references/screenshots/33-gameplay-completed-book-stamina-item.jpg)
