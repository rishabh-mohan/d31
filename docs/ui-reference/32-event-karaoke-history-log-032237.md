# UIR-32 — Karaoke Temptation — speaker-labelled dialogue history

[Full screenshot](../../references/screenshots/32-event-karaoke-history-log-032237.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `32-event-karaoke-history-log-032237.jpg` |
| Original image | `Screenshot_20261023_032237_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 03:22:37 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `72a3ac092fdc20148005c735886c1cb529e2587b0169dc6022c3c7e0e436884d` |

## Visible state

History window overlays the still-open Karaoke Temptation event; latest dialogue extends beyond the viewport.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Log surface | `0,25,100,75` | Tall cream window, thick orange rounded outline, large centered Karaoke Temptation heading. Event scene remains darkened behind upper portion. |
| History rows | `5,33,86,56` | Green Friend chips and orange Me chips precede dialogue, with brown horizontal rules separating turns. |
| Visible dialogue | `5,38,86,46` | Friend: Greg! Let’s go to the karaoke! Me: Of course not! We should study! Friend: Come on! Friend: I’ll pay for everything! Me: Hmm... |
| Overflow | `5,87,86,5` | Another Friend chip visible near the bottom with its following text outside the available body viewport. |
| Close | `5,93,90,5` | Wide red Close button pinned near bottom; no top-right X visible on this window. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- History retains consecutive turns by the same speaker as separate entries.
- Speaker chips are colored and positioned above their own line, not appended inline.
- Long history scrolls in the body while the title and Close stay accessible.
- Opening history must pause fast-forward per current project requirements; the still itself only proves the log appearance.

## Fine-tuning checklist

1. Do not flatten the history to plain concatenated text or omit speaker names.
2. Keep dividers inset and consistently spaced below each message.
3. Ensure the bottom button sits on an opaque surface so overflow text does not show through it.

## What this picture does not establish

The visible next Friend chip is intentional clipped content, not evidence that history was truncated in storage. Exact scroll position and whether choices are logged are unknown.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/event_screen.dart](../../lib/ui/event_screen.dart)
- [lib/ui/event_text.dart](../../lib/ui/event_text.dart)
- [lib/engine/event_engine.dart](../../lib/engine/event_engine.dart)

## Compare with

- [UIR-31 — Karaoke Temptation — player choice with Friend portrait retained](31-event-karaoke-choice-npc-retained-032118.md)

![Karaoke Temptation — speaker-labelled dialogue history](../../references/screenshots/32-event-karaoke-history-log-032237.jpg)
