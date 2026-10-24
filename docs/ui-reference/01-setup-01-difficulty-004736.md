# UIR-01 — Setup 1/5 — difficulty selection

[Full screenshot](../../references/screenshots/01-setup-01-difficulty-004736.jpg) · [Reference index](../UI-REFERENCE.md)

| Provenance | Value |
|---|---|
| Current image | `01-setup-01-difficulty-004736.jpg` |
| Original image | `Screenshot_20261023_004736_Korean Student Simulator.jpg` |
| Capture label | 2026-10-23 00:47:36 (filename time; timezone unverified) |
| Source dimensions | 1080 × 2340 px, portrait (6:13) |
| Source status | User-supplied original-game reference, not a d30mode render |
| App version | Not established by the screenshot |
| SHA-256 | `ccd6c3b419a0e8fba78385dc2ffeff62acce8f1b505e2bca12d427d167dbc77a` |

## Visible state

Full-screen setup; neither gameplay HUD nor keyboard is visible.

## Layout map

Approximate rectangles are `x, y, width, height` as percentages of the full source image. Origin is top-left. These are visual estimates, not recovered Flutter constraints; regions may overlap intentionally. See the index for scaling and shared styling.

| Region | Approx. bounds (%) | Visible design |
|---|---|---|
| Header | `0,0,100,11` | Cream strip, orange back chevron at left, centered Select Character (1 / 5), thin orange bottom rule and shadow. |
| Background/title | `0,11,100,18` | Faded classroom fills the canvas. Select Difficulty is centered in large dark brown type with generous space above it. |
| Standard card | `14,30,72,24` | Wide rounded pink card with darker pink border and bottom shadow; large running-person silhouette behind Standard Mode. |
| Elite card | `14,56,72,23` | Same size and alignment as Standard; red fill, darker red border, pale running silhouette, white Elite Mode label and small question-mark circle. |
| Support offer | `15,82,70,8` | Cream outlined banner: red runner icon, [Elite Support Pack], S-Tier Trait Available, right-pointing red chevron. |

## Text, options and controls

Labels and states below are observed. Intended actions are inferred from affordances unless an existing project requirement is explicitly cited.

- Back chevron is the only explicit back control.
- Standard Mode and Elite Mode are presented as large tap targets, not small radio buttons.
- The Elite question mark and support-pack chevron are separate affordances; the screenshot does not show their destinations.
- There is no bottom Next button in this capture; the two difficulty cards are the primary forward choices.

## Fine-tuning checklist

1. Keep equal card widths and heights, centered text, and a visible gap between the cards.
2. Use the same classroom crop as later setup steps, with enough cream opacity for dark text.
3. Preserve the hierarchy: header < section title < difficulty labels. Avoid adding a gameplay HUD here.

## What this picture does not establish

This image does not establish Elite modifiers, price, entitlement, or a selected-mode marker. Current prototype Elite is information-only; do not infer mechanics from the offer.

## Implementation entry points

These are navigation hints into the current d30mode implementation, not proof that the existing widget already matches the image.

- [lib/ui/setup_screen.dart](../../lib/ui/setup_screen.dart)
- [lib/engine/setup.dart](../../lib/engine/setup.dart)
- [docs/START-GAME-INITIALIZATION.md](../../docs/START-GAME-INITIALIZATION.md)

## Compare with

- [UIR-02 — Setup 2/5 — character collection and Student ID carousel](02-setup-02-character-carousel-004750.md)

![Setup 1/5 — difficulty selection](../../references/screenshots/01-setup-01-difficulty-004736.jpg)
