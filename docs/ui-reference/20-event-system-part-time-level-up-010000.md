# UIR-20 — System event — Part-Time Level Up

[Full screenshot](../../references/screenshots/20-event-system-part-time-level-up-010000.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `20-event-system-part-time-level-up-010000.jpg` |
| Original image | `Screenshot_20261023_010000_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:00:00 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `f4edc671686f42591ff95c42f65ab9c6972b2f9af5b44e78bbe50b7c02465877` |

## Visible state

D-30 Tuesday at Café; HUD shows 2670 Gold and 53 cookies; system event interrupts the game.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Backdrop | `0,0,100,100` | Underlying game remains positioned behind a dark scrim; top HUD and portions of action cards remain visible. |
| Event frame | `2,13,96,78` | Orange rounded perimeter/header with white Part-Time Level Up title. |
| Scene | `4,17,92,41` | Heavily blurred café/interior image with diagonal dark counter. No standing character is visible. |
| Dialogue | `8,58,84,31` | Large cream panel with orange border, rounded corners, Me orange speaker chip, and A sudden burst of professionalism rushes in me...! wrapped across two lines. |
| Controls | `10,83,80,5` | Outlined circular warning-triangle symbol in gray, red double-chevron, green next-chevron at left; dark-brown outlined history/list circle aligned right. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- The event is an overlay, not a separate blank background route.
- Dialogue remains bottom-aligned with large unused cream space below the short text.
- Double-chevron suggests fast-forward and single-chevron suggests advance; exact speed is not shown.
- The warning triangle’s action is not established by this capture; do not guess an effect.

## Fine-tuning checklist

1. Match scene blur separately from backdrop dimming; blur does not affect the dialogue text.
2. Retain event title, speaker chip and spacious text box as separate visual levels.
3. Use consistent circle diameters and colors, with history separated to the opposite edge.

## What this picture does not establish

Only the first displayed line of this system event is shown; subsequent dialogue and exact EXP rewards are not visible. No speaker portrait should be invented for a deliberately empty system scene.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/event_screen.dart](../../lib/ui/event_screen.dart)
- [lib/engine/event_engine.dart](../../lib/engine/event_engine.dart)
- [tools/build_pack.py](../../tools/build_pack.py)

## Compare with

- [UIR-21 — System event — Stamina Depleted](21-event-system-stamina-depleted-010010.md)
- [UIR-31 — Karaoke Temptation — player choice with Friend portrait retained](31-event-karaoke-choice-npc-retained-032118.md)
- [UIR-32 — Karaoke Temptation — speaker-labelled dialogue history](32-event-karaoke-history-log-032237.md)

![System event — Part-Time Level Up](../../references/screenshots/20-event-system-part-time-level-up-010000.jpg)
