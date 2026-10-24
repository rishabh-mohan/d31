# UIR-07 — Setup 5/5 — first and last name entry

[Full screenshot](../../references/screenshots/07-setup-05-player-name-005149.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `07-setup-05-player-name-005149.jpg` |
| Original image | `Screenshot_20261023_005149_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:51:49 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `5d7fa3fef5736305573f8f185749e9968c3253f9c8f47e3f88d58d89d9e1ac70` |

## Visible state

Final setup screen before starting; First Name Greg, Last Name Fiasco; keyboard hidden.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header/title | `0,0,100,21` | Select Character (5 / 5) header with back arrow; Enter Name centered below in large brown text. |
| Portrait | `27,24,47,27` | Complete character body/face/uniform, centered, chest cropped at a shared lower baseline. |
| First field | `17,55,66,9` | First Name label above large cream-filled, dark-brown outlined rounded input; Greg centered in large text. |
| Last field | `17,66,66,9` | Last Name label and same-sized input; Fiasco centered. Large gap from the first field. |
| Start CTA | `16,80,68,11` | Very large orange Start Game button with rounded corners, darker orange lower face, and soft shadow. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Back returns to prior setup while retaining current choices.
- Names are two distinct editable fields, not a combined display-name field.
- Start Game is the forward action; it should commit the draft once.
- No third subject-selection field, save-slot control, or purchase action is visible.

## Fine-tuning checklist

1. Use centered field values but left-aligned field labels.
2. Keep portrait and both field outlines unobstructed at rest; separately verify keyboard-open behavior.
3. Bind both names to event macros and My Info instead of rendering sample Greg/Fiasco permanently.

## What this picture does not establish

Empty-name handling, whitespace normalization, length limits and keyboard behavior are not shown. Screenshot version is not recorded.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/setup_screen.dart](../../lib/ui/setup_screen.dart)
- [lib/engine/setup.dart](../../lib/engine/setup.dart)
- [lib/engine/state.dart](../../lib/engine/state.dart)
- [lib/engine/event_text.dart](../../lib/engine/event_text.dart)

## Compare with

- [UIR-06 — Setup 4/5 — five traits selected, catalog scrolled](06-setup-04-traits-five-selected-scrolled-005128.md)
- [UIR-08 — Initial day transition — D-31 Monday baseline](08-day-transition-initial-d31-005158.md)

![Setup 5/5 — first and last name entry](../../references/screenshots/07-setup-05-player-name-005149.jpg)
