# UIR-31 — Karaoke Temptation — player choice with Friend portrait retained

[Full screenshot](../../references/screenshots/31-event-karaoke-choice-npc-retained-032118.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `31-event-karaoke-choice-npc-retained-032118.jpg` |
| Original image | `Screenshot_20261023_032118_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 03:21:18 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `49b05aa9a1d3b14d10f5cbf73daac5ab24f8d717d901294179cde022d49284c5` |

## Visible state

D-28 Thursday School, 1170 Gold, 53 cookies; event is at a player-choice beat.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Backdrop/frame | `2,13,96,78` | Orange Karaoke Temptation event frame over dimmed gameplay. Classroom scene matches School, rather than replacing it with a blank field. |
| NPC portrait | `22,25,56,34` | Large Friend with dark hair, round reflective glasses and green hoodie, bottom-aligned behind dialogue. |
| Dialogue | `8,58,84,21` | Cream dialogue panel with orange Me chip and Hmm...; it remains visible behind the choice sheet. |
| Choice sheet | `0,79,100,21` | Full-width cream bottom window with orange border and rounded top corners. Centered heading What should I do?; stacked orange Go and Don’t go buttons. |
| Layering | `0,0,100,100` | Choice layer darkens the event scene/dialogue behind it. The portrait remains visible even though Me is the current speaker. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Go and Don’t go are explicit branches; the screenshot does not show their outcomes.
- The choice heading is content, not a generic Choose replacement.
- Changing speaker to Me does not swap Friend for the player portrait.
- The choice sheet covers the bottom of the dialogue but must not erase necessary question text; later Quizmaster TODO explicitly requires keeping questions readable.

## Fine-tuning checklist

1. Use the same layered NPC artwork across adjacent dialogue beats.
2. Separate scene, dialogue, choice scrim and choice surface in the overlay order.
3. Keep choice labels large and centered with visible spacing and full-width hit areas.

## What this picture does not establish

This frame does not establish automatic branch selection, skip timing or the Friend’s internal NPC ID. Those require event data and engine rules.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/event_screen.dart](../../lib/ui/event_screen.dart)
- [lib/engine/event_engine.dart](../../lib/engine/event_engine.dart)
- [lib/ui/portrait.dart](../../lib/ui/portrait.dart)

## Compare with

- [UIR-32 — Karaoke Temptation — speaker-labelled dialogue history](32-event-karaoke-history-log-032237.md)
- [UIR-20 — System event — Part-Time Level Up](20-event-system-part-time-level-up-010000.md)

![Karaoke Temptation — player choice with Friend portrait retained](../../references/screenshots/31-event-karaoke-choice-npc-retained-032118.jpg)
