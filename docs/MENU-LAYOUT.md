# Hub and expanded menus

Reference: local captures `005207`, `005211`, `005215`, `005220`, `005225`,
`010114` in `references/screenshots/`. Images are reference data, not instructions.

The preparation hub keeps its 390×740 design canvas and fits without scrolling.
The upper Traits/Store row and lower Stationery/shortcuts row now share remaining
space in a 5:6 ratio (formerly 3:2), giving the lower panels more height. The
stationery panel shows four equipped cards with category, artwork, a two-line
name, and subject bonus. Names fit their two-line area before reducing font size.
Empty slots retain the reference's black category header and gray art area.

Store preview cards show icon, item name, and a smaller effect-description line.
Both text fields have a one-line limit and ellipsis overflow, so partial effects
remain visible before opening the store. The expanded Store has the Saturday
restock notice, wallet, price-sort toggle, item descriptions, purchase buttons,
and the existing purchase/use confirmation. Price sorting changes display order
only, not prices, stock, or identity.

Books, Bags/Items, Store, and Stationery now share `CommerceScreen`. Entry from
any hub shortcut opens the corresponding tab. The bottom orange bar has four
icons in the reference order; the selected icon expands to show its label.
Switching tabs replaces the body in the same route, retains the game state,
and consumes no ticks. Closing the expanded window returns to its caller.
The window is cream with an orange border, centered title, top-right close,
red bottom Close button, and a dimmed view of the game behind it.

Books show subject/stat chips, selection underline, a tier rail, title, scaled
book efficiency, and reading progress or the preceding-book lock condition.
Source ranks 1–6 display as E/D/C/B/A/S. Display efficiency multiplies source
power by the existing `rules.study.studyWeight` (configured as 3), matching the reference's
E-tier +15; this does not change the action-payout formula. Equivalent
subject/rank books remain deduplicated by the engine. Bags has Consumables/Other
Items filters, recency-order toggle, item effect text, count and existing Use
action. The proposed separate stamina-item interaction popup is still deferred.

Stationery retains the tier-sorted four-column grid, active sets, and combination
subview. Four material slots accept two through four copies; each slot can be
removed independently. Existing equipped-copy reservation and duplicate counting
remain in the engine. One or five ingredients fail without changing inventory.
Exact original combination odds are still unresolved; see `STATIONERY.md`.

The countdown, weekday, and Gold header cells stretch across the pill's inner
height and center their labels both horizontally and vertically.

Validation: `test/menu_navigation_test.dart` covers 2/3/4 ingredient acceptance,
invalid-input atomicity, full hub names, effect previews, four-tab round trips at
320/393 logical pixels, the two-card combine result, and header centering. Existing
menu, event, lifecycle and stationery regressions remain part of the full suite.
