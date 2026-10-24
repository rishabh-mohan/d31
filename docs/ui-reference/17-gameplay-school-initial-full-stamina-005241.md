# UIR-17 — Gameplay — initial School hand at full stamina

[Full screenshot](../../references/screenshots/17-gameplay-school-initial-full-stamina-005241.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `17-gameplay-school-initial-full-stamina-005241.jpg` |
| Original image | `Screenshot_20261023_005241_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:52:41 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `11e4ab1c73babb67ec3fff6bdabdab16404ccca99abdac7f7b0f2ad26c06a5fb` |

## Visible state

D-31 Monday, School, all 14 tick capsules unfilled, LV1 Student 0/495, stats 50, HP 100%, rerolls 520.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| HUD/location | `2,4,96,14` | Top hamburger/date/Gold/cookies/info groups. Orange School header above a cream strip containing 14 pale vertical capsules. |
| Scene | `3,19,94,35` | Blue classroom background, full layered boy portrait centered; translucent slate level card at upper right. |
| Goal/stats | `6,54,88,10` | Cream orange-outlined overlay attached to action area. Weekly goal Korean Reach 398 → Science Reward 294; five pastel stat tiles below. |
| Status | `6,64,88,4` | Clock/14 left, heart and outlined green HP bar 100% center, orange refresh icon/520 right. |
| Action grid | `13,69,74,27` | 2×2 large cards: Period 1 / Science +93~115 / HP -9; magenta Workout Level 0 / HP -24; English Textbook E +90 / HP -16; Korean Textbook E +90 / HP -16. Study cards have progress bar and coin; Korean has goal target marker. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Action cards combine type/subject, reward, progress and stamina cost in a single large tap target.
- Class and study use cream cards; exercise uses saturated magenta with white icon/text.
- Reroll button is a separate orange status-bar segment; calendar/goal figures remain visible while playing.
- Portrait is cropped at the top of the lower HUD, not stretched behind action cards.

## Fine-tuning checklist

1. Keep School art visible from the first six class ticks, not only after class.
2. Align action-card rows/columns and preserve deep bottom shadows.
3. Keep HP percentage inside the bar and remaining ticks beside a clock icon; do not confuse it with completed capsules.

## What this picture does not establish

Sample card payouts are observed values, not recovered universal formulas. 0/495 is strong display evidence; account cookie/reroll counts are examples.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [lib/ui/portrait.dart](../../lib/ui/portrait.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-18 — Gameplay — low stamina, exhausted expression and Sleep block](18-gameplay-school-low-stamina-sleep-005300.md)
- [UIR-28 — Gameplay — stamina mission and completed weekly goal](28-gameplay-school-mission-goal-complete-010138.md)
- [UIR-33 — Gameplay — Reading Complete book and quick stamina-item panel](33-gameplay-completed-book-stamina-item.md)

![Gameplay — initial School hand at full stamina](../../references/screenshots/17-gameplay-school-initial-full-stamina-005241.jpg)
