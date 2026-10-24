# UIR-30 — Gameplay menu — save restrictions and settings toggles

[Full screenshot](../../references/screenshots/30-gameplay-hamburger-settings-drawer-010150.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `30-gameplay-hamburger-settings-drawer-010150.jpg` |
| Original image | `Screenshot_20261023_010150_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 01:01:50 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `7a751b933746264178ea7e1532409513fc871c0ed6757f6004e69a65d413cb64` |

## Visible state

Large left-anchored menu overlays and dims the D-28 School game; Main Menu and Save look unavailable mid-day.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Drawer | `2,4,75,66` | Cream tall rectangle with orange rounded border; starts near left edge and leaves a substantial strip of the game visible on the right. |
| Close | `2,4,11,6` | Large red rounded square with white X overlaps the upper-left corner, unlike right-corner close on other modals. |
| Restricted rows | `5,11,69,12` | Main Menu gray label with coral You may leave once the day is over. Save gray label with You may save once the day is over. Thick brown separators between rows. |
| Settings | `5,24,69,18` | Rumble, SFX, BGM labels left; each has orange-filled ON circle and cream/orange-outlined OFF circle right. Labels and circles share row centers. |
| Navigation/support | `5,44,69,25` | Store with gift icon; Cookie Charging Station with cookie icon; Bug Report. Bottom peach rounded label Korean Student Simulator Supporters’ Edition. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Close position is top-left and replaces the hamburger area visually.
- ON is visibly filled for all three toggles; OFF remains outlined.
- Main Menu and Save use explanatory red restriction text, not just disabled opacity.
- Store and Cookie Charging Station are distinct destinations; do not confuse the premium/store entry with the in-run Gold offers.

## Fine-tuning checklist

1. Preserve the broad horizontal row dividers and large circular toggle targets.
2. Keep disabled explanations on the right without colliding with their labels.
3. Use left anchoring rather than centering this drawer like My Info.

## What this picture does not establish

Outside-tap dismissal, settings persistence, purchase flows and whether the restriction lifts exactly at day-end are not demonstrated by the still. No screenshot of an enabled Save row is present.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/game_screen.dart](../../lib/ui/game_screen.dart)
- [lib/ui/commerce_screen.dart](../../lib/ui/commerce_screen.dart)

## Compare with

- [UIR-28 — Gameplay — stamina mission and completed weekly goal](28-gameplay-school-mission-goal-complete-010138.md)
- [UIR-29 — My Info — identity, seven university crests and stationery](29-my-info-seven-badges-equipment-010143.md)

![Gameplay menu — save restrictions and settings toggles](../../references/screenshots/30-gameplay-hamburger-settings-drawer-010150.jpg)
