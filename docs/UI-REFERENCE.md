# UI reference atlas

All **33** supplied reference images have descriptive filenames and their own
Markdown specifications. Start with the relevant row below, read its state and
fine-tuning checklist, then open the linked full-resolution image. These are
original-game targets; they are not screenshots proving the current d30mode UI.

## How another agent should use this atlas

1. Read `CLAUDE.md`, the relevant TODO and the screen's individual specification.
2. Reproduce the same visible state: selected subject/traits/badges, currencies,
   tick, HP, dialog stack and scrolling position. Sample values are fixtures,
   not universal defaults. Compare structure before tuning data/formulas.
3. Compare like-for-like at the original **1080×2340** aspect ratio. For a logical
   canvas width W, use `scale = W / 1080` and reference height `2340 * scale`.
   For example, 390px width gives 845px of source-proportional height, before
   choosing how real system safe areas are handled. Do not assume 1080px are dp.
4. Rectangles in individual specs are approximate percentages, normally within
   a few percent. Convert each axis separately. A 50%-wide element is 540px on
   this source; remeasure its exact edge in the original before pixel-level work.
5. Preserve the reference's clipping, empty space and hierarchy. Verify keyboard,
   long labels, seven badges, many traits and narrow displays separately. Still
   images cannot establish frame timing, gesture outcomes or reward odds.
6. Use the listed implementation entry points to locate code, then run focused
   widget checks and inspect a render. Update the corresponding spec if new
   evidence changes the interpretation; retain provenance rather than silently
   converting a guess into a recovered fact.

## Shared visual language

- Cream paper surfaces; peach inset cards; orange borders, headings, buttons and
  tab bars; dark brown body text/rules. This is the visual target even when the
  host device uses dark mode. Source font family is unverified: match apparent
  size, line height, weight and alignment rather than guessing its identity.
- Rounded rectangles, warm shadows and darker bottom button edges create raised
  controls. Modal scrims dim underlying content; source event scenery can also
  be blurred. Do not apply the scrim or blur to foreground labels.
- Subject color order is Korean/pink, Maths/blue, English/yellow, Science/green,
  Humnts./purple. The Science/Humanities order is load-bearing in the engine.
- Gameplay top groups are hamburger, countdown/weekday, Gold/cookies, info.
  Large portraits sit in the scene above the compact goal/stat/status/action HUD.
- Commerce bottom navigation order is Books, Items (gift), Store, Stationery
  (pencil). Only the active tab expands its label. This differs from setup,
  history, result reveals and compact modals, which have their own footers.
- University badges use real crests, colored double rings and fixed four-plus-three
  geometry. Stationery cards use black category header, art, cream name band,
  subject-colored effect band. Tier art fill and subject effect fill are different.
- A faint gray vertical handle near the left screen edge recurs in unrelated
  captures. Treat it as a capture/system overlay, not a game scrollbar to copy.

## User instructions that supersede older captures

- Preparation Traits/Store should be taller than Stationery/shortcuts; make item
  icons readable even if fewer previews fit. Scroll excess traits inside their box.
- My Info should not scroll; long college names must stay inside fixed crest slots.
- Locked book text names the previous book only when that book is unlocked;
  otherwise say “the previous book”, despite older long raw lock labels.
- Keep event questions and authored choice headings readable. Keep the last NPC
  portrait when the player speaks, as the Karaoke capture illustrates.
- Zero stamina on the final player action does not show exhaustion dialogue.
- All setup-eligible collections are unlocked for this prototype; screenshot
  ownership/cookies are examples. Event-only traits remain excluded from setup.
- User clarified that the stationery draw rolls until stopped. One still does
  not establish speed or odds. The quick stamina-item interaction is documented
  as a target but was previously deferred; a reference is not an implementation request.

## Screen-by-screen catalog

| ID | Reference / specification | Capture | Family |
|---|---|---|---|
| UIR-01 | [Setup 1/5 — difficulty selection](ui-reference/01-setup-01-difficulty-004736.md) | `004736` | setup |
| UIR-02 | [Setup 2/5 — character collection and Student ID carousel](ui-reference/02-setup-02-character-carousel-004750.md) | `004750` | setup |
| UIR-03 | [Setup 3/5 — university badges with seven empty slots](ui-reference/03-setup-03-university-badges-empty-004804.md) | `004804` | setup |
| UIR-04 | [Setup 3/5 — seven selected university badges](ui-reference/04-setup-03-university-badges-selected-005058.md) | `005058` | setup |
| UIR-05 | [Setup 4/5 — trait selection with three occupied slots](ui-reference/05-setup-04-traits-partially-selected-005119.md) | `005119` | setup |
| UIR-06 | [Setup 4/5 — five traits selected, catalog scrolled](ui-reference/06-setup-04-traits-five-selected-scrolled-005128.md) | `005128` | setup |
| UIR-07 | [Setup 5/5 — first and last name entry](ui-reference/07-setup-05-player-name-005149.md) | `005149` | setup |
| UIR-08 | [Initial day transition — D-31 Monday baseline](ui-reference/08-day-transition-initial-d31-005158.md) | `005158` | transition |
| UIR-09 | [Preparation — first Weekly Goals announcement](ui-reference/09-preparation-weekly-goal-announcement-005202.md) | `005202` | preparation |
| UIR-10 | [Preparation hub — Store previews, empty traits and equipment](ui-reference/10-preparation-hub-empty-traits-equipment-005207.md) | `005207` | preparation |
| UIR-11 | [Expanded Store — price order and Saturday stock](ui-reference/11-commerce-store-price-sorted-005211.md) | `005211` | commerce |
| UIR-12 | [Expanded Stationery — empty equipment and category filters](ui-reference/12-commerce-stationery-empty-equipment-005215.md) | `005215` | commerce |
| UIR-13 | [Expanded Books — Korean E book and locked D/C tiers](ui-reference/13-commerce-books-korean-locked-tiers-005220.md) | `005220` | commerce |
| UIR-14 | [Expanded Bags/Items — empty consumables](ui-reference/14-commerce-items-empty-consumables-005225.md) | `005225` | commerce |
| UIR-15 | [Score Card — empty-state modal](ui-reference/15-score-card-empty-dialog-005229.md) | `005229` | modal |
| UIR-16 | [Calendar — tall modal with one exam entry](ui-reference/16-calendar-single-exam-entry-005234.md) | `005234` | modal |
| UIR-17 | [Gameplay — initial School hand at full stamina](ui-reference/17-gameplay-school-initial-full-stamina-005241.md) | `005241` | gameplay |
| UIR-18 | [Gameplay — low stamina, exhausted expression and Sleep block](ui-reference/18-gameplay-school-low-stamina-sleep-005300.md) | `005300` | gameplay |
| UIR-19 | [Day recap — completed D-31 Monday and daily gains](ui-reference/19-day-transition-completed-d31-gains-005939.md) | `005939` | transition |
| UIR-20 | [System event — Part-Time Level Up](ui-reference/20-event-system-part-time-level-up-010000.md) | `010000` | event |
| UIR-21 | [System event — Stamina Depleted](ui-reference/21-event-system-stamina-depleted-010010.md) | `010010` | event |
| UIR-22 | [Item acquired — Weird Workbook Use/Confirm modal](ui-reference/22-commerce-item-acquired-use-confirm-010019.md) | `010019` | commerce |
| UIR-23 | [Stationery draw — rolling cards and Stop all Stationery](ui-reference/23-stationery-draw-rolling-stop-all-010049.md) | `010049` | stationery |
| UIR-24 | [Stationery draw — stopped result with free redraw](ui-reference/24-stationery-draw-stopped-free-redraw-010059.md) | `010059` | stationery |
| UIR-25 | [Stationery draw — Cosmic Eraser kept/locked](ui-reference/25-stationery-draw-kept-card-lock-010102.md) | `010102` | stationery |
| UIR-26 | [Combine Stationery — four ingredient slots and owned cards](ui-reference/26-stationery-combine-four-empty-slots-010114.md) | `010114` | stationery |
| UIR-27 | [Stationery result — Invisible Pencil confirmation](ui-reference/27-stationery-result-invisible-pencil-010121.md) | `010121` | stationery |
| UIR-28 | [Gameplay — stamina mission and completed weekly goal](ui-reference/28-gameplay-school-mission-goal-complete-010138.md) | `010138` | gameplay |
| UIR-29 | [My Info — identity, seven university crests and stationery](ui-reference/29-my-info-seven-badges-equipment-010143.md) | `010143` | modal |
| UIR-30 | [Gameplay menu — save restrictions and settings toggles](ui-reference/30-gameplay-hamburger-settings-drawer-010150.md) | `010150` | modal |
| UIR-31 | [Karaoke Temptation — player choice with Friend portrait retained](ui-reference/31-event-karaoke-choice-npc-retained-032118.md) | `032118` | event |
| UIR-32 | [Karaoke Temptation — speaker-labelled dialogue history](ui-reference/32-event-karaoke-history-log-032237.md) | `032237` | event |
| UIR-33 | [Gameplay — Reading Complete book and quick stamina-item panel](ui-reference/33-gameplay-completed-book-stamina-item.md) | `extra` | gameplay |

## Coverage and limits

Seven setup states, initial/completed day transitions, preparation and goal
announcement, four commerce tabs, score/calendar/My Info/settings modals,
three gameplay states plus a completed-book/quick-item example, system/event
choices/history, stationery rolling/stopped/locked/combine/result states are covered.
There is **no reference screenshot here for the location picker**, Elite help
contents, keyboard-open names, a populated Score Card, or exam/admission/endings.
Do not invent those from unrelated pictures. The exact original app version and
capture-device safe areas are unverified; recovered catalog versions are separate evidence.

## Provenance and maintenance

Images remain local-only under ignored `references/screenshots/`. The 33 textual
specs, this index and [manifest](ui-reference/manifest.json) are tracked project
documentation. Original filenames, capture labels, dimensions and SHA-256 hashes
are preserved in the manifest and each spec; renaming did not modify image bytes.
The extra completed-book image has no timestamp in its original filename.

Run `python tools/verify_ui_references.py` to check one-to-one image/spec coverage,
hashes, dimensions and local links. Keep existing six-digit capture labels in
historical notes: they remain searchable in the descriptive filenames and manifest.
See also [initialization requirements](START-GAME-INITIALIZATION.md),
[menu layout](MENU-LAYOUT.md), [event presentation](EVENT-PRESENTATION.md) and
[recent implementation notes](TODO-FOLLOWUP.md).
