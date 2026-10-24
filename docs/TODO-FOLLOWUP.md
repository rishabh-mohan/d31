# TODO 6–13 implementation notes

## Event questions and portraits (6, 10)

The choice panel previously painted over the dialogue with a generic “Choose”
heading. It now renders the authored `optionText`, expands name variables, and
includes the current dialogue/question above the answer buttons. The content is
bounded and scrollable for long quizzes; no ellipsis discards question text.

EventNode retains standing ID, expression, clothing and extra layer names.
EventRun maintains the current NPC portrait: positive standing/speaker IDs select
an NPC, player speech keeps the last NPC, and explicit `standingOff` clears it.
Presentation changes apply only when the node's gate passes. Portrait composes
skeleton, expression, clothing and extra layers within common bounds. Player
portraits in gameplay, setup and My Info use the same composition. Source aliases
remain untouched. Missing optional expressions fall back to `defaults`.

## End-of-day stamina (7)

The last player action (tick index 13 in the configured 14-action day) follows the
ordinary evening/day rollover even if HP reaches zero. It neither opens the
exhaustion event nor applies the collapse stat penalty. Earlier exhaustion keeps
the existing deferred popup, lost-slot animation, penalty and single reset.
The boundary uses `actionTicksPerDay`, including edited day lengths.

## Location images and packaging (9, 9B)

`build_locations` writes an image path on every build; it no longer relies on
running the old placeholder copier afterward. `tools/presentation_assets.py`
exports `presentation.json` plus `assets/images/scene/`. It reads the English
asset pack and the base APK art tree without modifying either. School and Home
use the original bundled classroom/bedroom. Eight other location originals were
recovered from catalog URLs and validated as images. Downloads are cached under
`build/presentation-source/`; `--fetch-locations` repeats the recovery when needed.

The Art Museum original returns HTTP 404 from both English and Korean catalog
URLs. It uses the existing story-14 university exterior as an explicit temporary
fallback. Other unavailable optional event backdrops fall back to the location.
A clean build without downloaded files also uses the documented story-14
fallbacks rather than broken paths. `build/presentation-assets-report.json`
lists missing source files; many belong to optional backgrounds outside the
active event graph. Art and generated catalogs remain ignored and local-only.

## Initialization and university badges (8, 12)

Setup now uses cream/orange reference styling, large difficulty cards, a paged
Student ID carousel with stars/arrows, selected portrait, the seven crest slots
(four above three), colored crest/effect rows, five selected-trait slots alongside
the portrait, a two-column tiered trait catalog and a larger name-entry portrait.
All-collection prototype ownership and event-only trait exclusion are retained.
Elite remains an information-only coming-soon card. Promotions that require a
collection/shop system are represented by a character banner; no fake purchase
flow is introduced.

The exporter imports 135 raster crests from the base APK. Korea Dream's original
`2.svg` is reproduced by a small CustomPainter using its exact shield/chevron
paths. Crest slots have fixed geometry and scale their labels; even seven long
university names cannot make the slot section grow vertically. Badge effect
labels now cover the supported EXP, earnings, sleep and goal modifiers.

## Preparation and My Info (11, 13)

The preparation panel allocation is now 7:5 in favor of Traits/Store. Four store
previews are visible. Traits scroll within their own bounded box when crowded;
the outer preparation menu remains fitted and does not scroll.

My Info fits a fixed 390×660 design into the available dialog area. Identity,
levels, stats, seven crests, traits and four stationery slots remain visible
without a page scroll. Long names scale inside the identity/crest bounds and a
large trait collection scales inside its column. This prevents the old badge
name chips from increasing the dialog height.

## Verification and deployment

`test/todo_followup_test.dart` covers last/penultimate-action exhaustion, NPC
persistence and explicit hiding, local image/crest coverage, question visibility,
seven long badge names, crowded trait inventories and non-scrolling My Info at
320px and 393px widths. Existing menu tests now assert the requested taller Store
and the bounded trait scroller rather than the former opposite proportions.

Optional visual review output is generated with:

```
flutter test test/todo_followup_test.dart --update-goldens --dart-define=RENDER_REVIEW=true
```

This writes ignored `build/ui-review/` images. The font-loading branch is for
local review only. Deployment must include the new `presentation.json` and
updated `locations.json` in existing editable phone packs; preserve tuned rules
and save data. Notify the user before installing a new APK on the Nord N30.

Final verification: Dart analysis reports no issues; all 139 Flutter tests pass, including the 200 seeded complete runs. Local visual review was rendered at 320px and 393px. Python presentation/builder scripts compile successfully.


Deployment completed on Nord N30 (`7c2c1cc8`). Installed APK SHA-256:
`6c77e348e3c58f9dd5ce40dd0447c105c431d05012a377fe9105cb131a04600a`.
The installed bytes match the local debug APK. Presentation and merged location
catalog hashes also match their local files. The phone's rules hash is unchanged:
`c12369e5ecad8edcb267c0540a9626e9ed6f51f17bcd2d4386239c44ade2a720`.
Catalog backups are under ignored `build/nord-todo-followup-backup/`.
Only image fields were merged into the phone's existing location records;
its other location values were preserved. The app was restarted for hand testing.
