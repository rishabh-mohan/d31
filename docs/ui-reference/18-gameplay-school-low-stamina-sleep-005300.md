# UIR-18 — Gameplay — low stamina, exhausted expression and Sleep block

[Full screenshot](../../references/screenshots/18-gameplay-school-low-stamina-sleep-005300.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `18-gameplay-school-low-stamina-sleep-005300.jpg` |
| Original image | `Screenshot_20261023_005300_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:53:00 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `927787f5046e1133c3b6e9f2aebee6fe7c53ebea6b955e9f1b0abc3296bf02dd` |

## Visible state

D-31 Monday; eight capsules filled and 6 actions left; HP 6%; LV2 Hardworking 700/4950.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Persistent frame | `2,4,96,64` | Same School HUD/classroom/goal/stat/status layout as 005241, with progress and expression changed. |
| Portrait | `25,24,50,30` | Eyes closed, purple stress marks and sweat drop. Uniform/body remain aligned with the prior expression. |
| Stats/status | `6,58,88,10` | Korean 143, Maths 145, English 50, Science 374, Humnts. 266. HP bar nearly empty with red 6% at left; clock 6 and rerolls 520. |
| Action grid | `13,69,74,27` | Workout Level 0 twice, each HP -24; navy Sleep with white Zzz, HP +10; Science Textbook E +98, progress/coin and HP -16. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Duplicate workout cards are intentionally visible in the same hand.
- Sleep is an ordinary action-card treatment with a positive heart value, not an End Day button.
- The low-HP expression changes face layers without swapping clothing/body geometry.
- Subject totals and study book gain differ from the first-day baseline.

## Fine-tuning checklist

1. Preserve dark navy Sleep and magenta exercise colors, high-contrast white icons and raised shadows.
2. Show a very small red HP fill rather than hiding the percentage at low values.
3. Use this frame to verify card duplication and portrait-state changes visually.

## What this picture does not establish

The exact expression threshold and face-state selection rule cannot be derived from this one sample. Do not infer a no-stamina proc or sleep timing from the screenshot.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [lib/ui/portrait.dart](../../lib/ui/portrait.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-17 — Gameplay — initial School hand at full stamina](17-gameplay-school-initial-full-stamina-005241.md)
- [UIR-21 — System event — Stamina Depleted](21-event-system-stamina-depleted-010010.md)

![Gameplay — low stamina, exhausted expression and Sleep block](../../references/screenshots/18-gameplay-school-low-stamina-sleep-005300.jpg)
