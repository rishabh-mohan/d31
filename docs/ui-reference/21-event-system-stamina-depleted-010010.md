# UIR-21 — System event — Stamina Depleted

[Full screenshot](../../references/screenshots/21-event-system-stamina-depleted-010010.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `21-event-system-stamina-depleted-010010.jpg` |
| Original image | `Screenshot_20261023_010010_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:00:10 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `b1347da1a2833d23777d3a3ceb3ddd9e4789b4bd4043f85b793e909880d62b1a` |

## Visible state

D-30 Tuesday at Café, immediately following the same session’s level-up capture.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Event frame | `2,13,96,78` | Same orange-framed system event geometry as 010000. Header changes to Stamina Depleted. |
| Scene | `4,17,92,41` | Same blurred interior without a character portrait. |
| Dialogue | `8,58,84,31` | Cream dialogue box, orange Me chip, visible line You’re out of stamina today...; the rest of the box is intentionally open space. |
| Controls | `10,83,80,5` | Gray warning symbol, red fast-forward, green next at lower left; brown history control at right. |
| Backdrop state | `0,0,100,100` | 2670 Gold and 53 cookies remain visible in dimmed top HUD; magenta workout and olive work blocks are visible below event frame. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Advance and history controls retain the same places as the level-up event.
- This is a system dialogue state, not the navy day-summary screen.
- Underlying game should remain inert until the event is resolved, as required by the host lifecycle.

## Fine-tuning checklist

1. Reuse the system-event shell so header/text changes do not move controls.
2. Keep the dialogue text near the top of its large cream panel.
3. Later user instruction overrides triggering: zero stamina on the final action must not open this event.

## What this picture does not establish

This screenshot alone does not show the lost-slot animation, stat penalty, HP restoration, or the tick on which depletion occurred. Those come from engine requirements/tests, not this image.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/event_screen.dart](../../lib/ui/event_screen.dart)
- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [lib/engine/game.dart](../../lib/engine/game.dart)

## Compare with

- [UIR-20 — System event — Part-Time Level Up](20-event-system-part-time-level-up-010000.md)
- [UIR-19 — Day recap — completed D-31 Monday and daily gains](19-day-transition-completed-d31-gains-005939.md)

![System event — Stamina Depleted](../../references/screenshots/21-event-system-stamina-depleted-010010.jpg)
