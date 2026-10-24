# UIR-08 — Initial day transition — D-31 Monday baseline

[Full screenshot](../../references/screenshots/08-day-transition-initial-d31-005158.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `08-day-transition-initial-d31-005158.jpg` |
| Original image | `Screenshot_20261023_005158_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:51:58 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `79fc2965512bc9d1177b2a0d1cb66011e9933c8110751ca1edf354269b01e2e7` |

## Visible state

Initial navy handoff after setup, before a goal is displayed.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Canvas | `0,0,100,100` | Solid dark navy, no orange gameplay HUD or classroom artwork. |
| Date stack | `40,28,22,17` | Pale crescent moon above D-31 and Monday, vertically centered as one stack. |
| Summary panel | `4,47,92,15` | Pale blue/gray rounded card with dark outline/shadow; Weekly Goals header row and dash, then five pastel subject tiles. |
| Subject values | `7,52,86,5` | Korean 50, Maths 50, English 50, Science 50, Humnts. 50. No daily gain row is populated. |
| Continue | `4,65,92,8` | Wide bright-green rounded button with white play triangle and darker lower edge; substantial navy whitespace below. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Play is the sole visible forward control.
- Weekly Goals is a dash here; the objective announcement appears later in 005202.
- No gain values should be fabricated for a fresh-run summary.
- Moon/date/card/button share a common centerline.

## Fine-tuning checklist

1. Preserve navy breathing room and the compact central summary; do not stretch the card to fill the screen.
2. Use pale blue lettering distinct from cream/orange menus.
3. Compare with 005939 to distinguish baseline totals from end-of-day gains.

## What this picture does not establish

A still frame does not establish animation or auto-dismiss timing. The tiny left-edge gray handle is a capture/system artifact, not a game control.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/day_transition.dart](../../lib/ui/day_transition.dart)
- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [docs/START-GAME-INITIALIZATION.md](../../docs/START-GAME-INITIALIZATION.md)

## Compare with

- [UIR-07 — Setup 5/5 — first and last name entry](07-setup-05-player-name-005149.md)
- [UIR-09 — Preparation — first Weekly Goals announcement](09-preparation-weekly-goal-announcement-005202.md)
- [UIR-19 — Day recap — completed D-31 Monday and daily gains](19-day-transition-completed-d31-gains-005939.md)

![Initial day transition — D-31 Monday baseline](../../references/screenshots/08-day-transition-initial-d31-005158.jpg)
