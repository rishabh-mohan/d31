# Original-game implementation evidence requests

Updated 2026-10-25 (E33 recording). Companion to [TODO 81-90](../TODO.md) and
[Original-game functions](ORIGINAL-GAME-FUNCTIONS.md). This is an evidence
collection checklist, not a claim that every listed feature is absent.
Home/account/History/save integration is complete for the documented prototype
scope; review CURRENT-STATE.md before implementing overlapping tasks. Requested captures should show
the ORIGINAL game, not d30mode, unless explicitly reproducing a d30mode bug.

## Later user clarifications (2026-10-25)

A14: granted Practice Blocks remain available until a later event removes them;
the user cites the soccer coach removing its block after sufficient skill.
No new capture is needed to implement this persistent-availability rule.

I03: the user explicitly chose a provisional 20% exact-herb duplicate with no
simultaneous Ginseng Digger ginseng. The imported graph instead used 40% and
another random herb; preserve the distinction. Do not ask the user to re-prove
the chosen prototype rule. See CLARIFIED-MECHANICS-2026-10-25.md.

I05: shop offers restock at the start of Saturday. Before buying anything,
refresh costs one cookie. First refresh removes one offer; later refreshes
keep the reduced count. Original offer pool/weights/prices remain unresolved.

The user knows no exact T03/T13 odds or published link. Local pseudocode review
has not recovered them; avoid repeatedly requesting the same unknown rates.

## Already supplied: do not resend

Evening batch received: [follow-up specification](ORIGINAL-GAME-FOLLOWUP-2026-10-24.md)
archives 30 screenshots and three recordings. Request status below overrides
the original broad request table; remaining sub-details are not new requests to
repeat captures already provided. None of these evidence statuses means the
corresponding implementation is complete.

| Request | Resolved now | Still unknown / next source |
|---|---|---|
| E01 | Full visible Settings, Regular/Orchestral selection, language and music entitlements (F01/F02) | Defaults/restart persistence, Carol state, actual audio/haptics |
| E02 | Empty Mail List, Claimed Mail rows, ten-claimed-message cap (F03/F04) | Unclaimed/claim/expiry behavior |
| E03 | Profile controls and nine-cookie rename, 2-16 characters (F05/F07) | Validation/success, invitation history; do not resend profile |
| E04 | Charging offers, cookie prices/bonuses, twice-daily ad limit, refresh shortcut (F08/F09/F14/F16) | Ad reward amount/reset, refresh-ticket route/exchange |
| E05/E40 | Ads/Packs/Expansion/Cookie Store tabs, owned entitlement posters, Focus contents (F10-F16) | Unseen product details/restore behavior; no purchases needed |
| E07 | History Application Results, Info and Score Card tabs, student ID/upload-photo control (F17/F18/F30) | History delete/cancel, ordering/capacity, photo flow |
| E08 | Save-delete confirmation layout and wording (F19) | Capacity/order/completion transition |
| E12 | All 12 pack probabilities and tier counts from supplied public Notion page | Product prices/mileage for other packs; exact pool membership/version reconciliation. Notion page does not contain combine/stationery odds |
| E13 | ANY S draw resets mileage, user-confirmed | Multi-card guarantee placement/overflow ordering |
| E18 | Protection survives restart; locked selection warning (F20) | Per-copy versus ID scope and entering protection with selected inputs |
| E22 | Workbook +90 popup precedes gacha; completion reward and next-book unlock views (F21/F22,V01/V02) | Exact book conditions/repeat counters and reward pool; no need to repeat workbook capture |
| E24 | Weekly Goals Met notification/Confirm during gameplay (V02), not solely next Monday | Final-week behavior, modifier activation and generation formula |
| E25 | Mission offer, stat success/claim, end-stamina/item reward, continuous failure (F23-F26); silent deadline expiry versus notified continuous failure | Generation/limits, other warnings and exact timing details |
| E32 | User confirms inventory XP does NOT show a level-up event; A13 withdrawn | Verify level state and suppress delayed scene leaks; Practice Block question remains |
| E33 | Current user's full D-Day/application/results video: [70-frame recreation handoff](D-DAY-APPLICATIONS-REFERENCE-2026-10-25.md), live major substring search, four school categories, manual add/remove, partial Auto Input, aggregate rejection arithmetic, colored envelope animations, rejection/retake enrollment, completion and doubled pack reward. Earlier successful tutorial remains separate evidence | Sort options, school-to-major destination, tray expansion, duplicate enforcement, partial submission, successful branch in current version, hidden scoring/RNG and external photo/share workflows; no repeat full user playthrough request |
| E34 | First college enrollment unlocks its achievement and grants two cookies | Repeat/department awards and other ending-reward rules |
| E37 | Full stationery wrapper/roulette/locks/redraw/confetti flow (V03) | Exact unrecovered odds and other pending original rules |
| E39 | English Riddle Expert question/answers and Death Cutlet reward example (F27/F28) | Dedicated bank recovery and full reward policy |

Additional F29 documents the night-summary Trait removed popup. F06 is Gallery
UI and is excluded from game specifications. Protection/mileage/mission/workbook/
college confirmations need no repeated explanation.

[Main-menu reference](MAIN-MENU-REFERENCE.md) indexes 27 full-size images in
`screenshots/main-menu-2026-10-24/`. They cover:

- Home and hidden-UI background; University achievements and completion filter;
  Campaign achievements/Endings List; Other achievements; incomplete Daily Quest;
  History list; puzzle categories, Amnesia collection, unstarted/partial details.
- Standard/Jumbo packs, wrapper opening, results with/without Draw More; My
  Traits; database S and S/A boundary; Standard/Winter combining; separate
  single-card results before/after Confirm; saves; protection-editing mode.
- The [in-run/setup atlas](UI-REFERENCE.md) already covers 33 reference captures.
  Use it before requesting duplicate normal preparation/setup/gameplay views.

Confirmed behavior that does NOT need another explanation:

- Four arrows hide Home controls; tapping anywhere restores them. Records opens
  History. The sample balances are 53 cookies and 522 refresh tokens, not defaults.
- Save-card number is the sum of all five study stats (five 50s = 250).
  Ending cookie amounts are completion rewards, not replay prices.
- Trait combining uses exactly three copies. Padlock enters a mode where tapping
  copies protects/unprotects them. In that mode slots/remove buttons disappear,
  Combine is inactive, padlock darkens and protected cards show large center locks;
  ordinary mode uses small corner locks.
- Combining has NO roulette. Separate results Final Blow/Fruits of Labour are
  not animation frames of one result. Confetti uses the result tier's color;
  Confirm fades in after half a second without an extra tap.
- Trait packs use one-card roulette, stopped by tapping, without rerolls. After
  stopping, confetti mixes brown/gray/gold; results have arrows/index/Exit and
  sometimes Draw More. Stationery roulette also needs multicolor tier confetti.
- Stationery is fresh EVERY new run, but the same run retains it on save/resume.
  Its combining uses two to four copies, preserving the highest input tier
  (A+C -> A, B+C -> B), provisionally 5% upgrade unless stronger source evidence.
- Stamina caps at 100; one efficiency unit means one extra study stat. Flat
  item-report/bag buttons, no leaderboard and currently unlocked setup collections
  are intended. Elite and book-completion item gacha are deferred.

## How to send useful evidence

Send any subset here with its E-number; the order below is a suggested batching
order, not a requirement to collect everything before work continues. Full-size
uncropped screenshots preserve layout. Videos of 5-20 seconds help with roulette,
fade timing, route transitions and rewards; otherwise send before/during/after
screens and describe the taps. No need to buy anything or spend real money.

For numeric demonstrations include campaign/version, character, traits, badges,
stationery/items, date/tick/location and starting/ending stats, stamina, Gold or
account balances. Turn off unrelated bonuses where possible. Multiple screenshots
can satisfy one E-number; one screenshot can satisfy several. Empty, enabled,
disabled, insufficient-resource, claimed and success/failure variants matter when
they change behavior. Do not infer exact RNG rates from a few attempts: original
rate/help text or recovered code is needed. Some confirmed code bugs need tests,
not more screenshots; collect only unresolved original behavior below.

## Home/account and navigation (Claude's current area)

| ID / TODO | Screenshots or recordings still needed | Details to explain if not visible |
|---|---|---|
| E01 / M01,F02,F03 | Settings, every scrolled section and any secondary dialogs; before/after toggling | All options/defaults; persistence across restart; which sound/haptic actions each controls |
| E02 / M01 | Mailbox empty, unread/list, message detail with reward, collected state | Read/delete/claim behavior, expiry and whether mail can be received offline |
| E03 / M01 | Profile/info button page; edit screen and confirm/cancel if available | Editable fields, limits/costs and where updates appear |
| E04 / M04 | Charging page, all currency tabs, any recharge/refresh-token exchange/help/history | Cookie/token sources, exact exchange amounts, limits/timers/reset and spending rules; no purchase required |
| E05 / M01 | Account Store categories, product details, available confirmation/error dialogs | What each product grants, account/run scope, repeatability/entitlements; distinguish this Store from in-run Gold shop |
| E06 / M01 | Notices list/detail; seasonal Cookie Parade entry, progress/reward/help pages | Navigation/back behavior, availability/reset and reward claims |
| E07 / M03 | Tap a History card; detail if one exists; delete confirmation/cancel and post-delete | Whether card tap does anything, displayed ending/exam/stats, ordering, capacity and deletion scope |
| E08 / M02,M03 | Select Game plus/new-run transition, delete confirmation, save list after completing a run | Maximum saves, sorting, whether completed slot is removed/freed automatically, overwrite behavior; basic list already supplied |
| E09 / M05,M06 | University achievement card detail; Special/Global/Taiwan when layout differs; earned/unclaimed and claimed states | Unlock condition, reward claim/repeat rules, badge persistence; initial empty achievements remain intended |
| E10 / M06 | Tap an Endings List row; new-ending reward and already-discovered repeat completion | Preview/replay behavior if any; automatic versus manual cookie award; first-time versus repeat rewards |
| E11 / M11 | Daily Quest completed with Receive enabled, after receiving, and reset/help if present | Eligible quests, progress across runs, claim timing, reset clock/timezone, expiry and missed rewards |

## Trait packs, collections and combining

| ID / TODO | Screenshots or recordings still needed | Details to explain if not visible |
|---|---|---|
| E12 / M07 | Chances Info, all pages/tier/campaign variants; Royal pack and other campaign products | Pack contents, prices, mileage gains, guarantees, campaign pools and exact published probabilities; Standard/Jumbo baseline already supplied |
| E13 / M07 | Mileage just before/after full guarantee; early S-tier draw before/after | Guarantee trigger/consumption, reset value, overflow, whether campaign packs share mileage |
| E14 / M07 | Pack Buy confirmation, insufficient cookies if already encountered, owned count before/after Buy/Open | Does buying immediately open or add stock? Deduction point, quantity choices and cancellation behavior |
| E15 / M07 | Short wrapper -> roulette -> tap-stop -> results video; next/previous card and Draw More | Opening gesture, cycling/order/timing, when rewards commit, Draw More source/cost/remaining-count and dismissal behavior; stopping-on-tap/confetti/no-reroll already confirmed |
| E16 / M08,U03 | Trait detail if tapping opens one; account copy counts before setup selection and after run creation/completion; database before/after new discovery | Whether selecting uses a copy, when it returns (if ever), duplicate stacking/compensation, owned versus ever-discovered marking, career restriction |
| E17 / M09 | Combine with 1, 2 and 3 inputs, selected copy in grid, X removal, Combine Rates all pages | Mixed-tier outcome tables, cost/consumption, pool restrictions, duplicate selection, errors; three required/no roulette/0.5-second Confirm already known |
| E18 / M09 | Toggle protection while ingredients are selected; unlock/relock a card; reopen/relaunch | Are selected inputs cleared/retained? Is protection per copy or trait ID? Persistence and whether protected copies can be selected through another route; appearance already supplied |

## Puzzles and backgrounds

| ID / TODO | Screenshots or recordings still needed | Details to explain if not visible |
|---|---|---|
| E19 / M10 | Completed but unselected versus selected puzzle, full detail, background selection transition | Is the green check owned/completed or currently equipped? Toggle/default/reset and persistence; basic categories/collection already supplied |
| E20 / M10 | Puzzle ? help; a different partial piece count/cost; Complete Now confirmation and post-completion | Piece weighting explaining 2/4 = 52%, price/discount formula, failure/cancel behavior and how condition-earned pieces appear |
| E21 / M10 | Insta-draw help/pool/odds/result; other category grids if structurally different | Random complete-product pool, duplicate handling, cost; how a purchased expansion grants one complete puzzle (only if already owned) |

## In-run progression, items and character mechanics

| ID / TODO | Screenshots or recordings still needed | Details to explain if not visible |
|---|---|---|
| E22 / A02,I04,T01 | All book variants at one rank; completion -> next unlock; repeated completion reward; Master of Notes workbook receipt | Prerequisite AND/OR rules, progress reset, book condition/extraDoneCount meaning, one-time/repeat reward; no item-gacha implementation requested |
| E23 / A03,A04,U05 | Controlled study before/after High Potential, Entrepreneur, Level-8 Suit below/at required level; acceptance item before/after eligibility/odds view | Description and actual gain/threshold units, stacking/order; basic efficiency +1 per unit already confirmed |
| E24 / A07,A08,A09,U06 | Goal before/after meeting it through an item/event; normal settlement; final partial week; planner/goal trait acquired midweek then next week | Immediate versus scheduled payout, target/reward assignment, active-week modifier eligibility and CSAT settlement; one sample goal is not enough to infer formula |
| E25 / F01 | Sudden Mission offer/help, active progress, success/reward, failure/expiry; safe and warned location | Trigger/accept/decline rules, limits, tick/day duration, mission types/rewards and exact risk-warning behavior |
| E26 / A05,A06,I05,78 | In-run shop before/after refresh/day/week and reopening; stock/counts/price after purchase; sold-out/capped state | Refresh trigger/cost, selection weights or original help, quantity limits, original prices; distinguish shop stock from Home Store |
| E27 / A05,I01,I02,I03,78 | Recipe inspect/crafting pages, material requirements and success/missing-material states; Academic Potion, Pet Rock, Hiking Gloves in use | Actual multi-subject gains, collapse survival, extra gather outcome, consumption/cooldown; capture unimplemented special items' details/actions when encountered |
| E28 / T02,T03,T07-T13 | Controlled coffee/food purchase, movement, studying, work/collapse before/after their relevant traits; activation notices/help | Developer, Gourmet, Limited Offer, Walking Enthusiast, Multitasker, Time Jumper, Stubborn/falter, Bully, Energizer: proc eligibility, amounts, duration/reset and original published rates; no exhaustive random sampling needed |
| E29 / T04-T06,U05 | Admissions odds/eligibility before/after Bows, Blood Type A and Realistic separately; trait/help text | Multiplier versus percentage points versus score; stacking and caps. Exact hidden formula needs code/help, not acceptance streaks |
| E30 / A01,A12,T14-T16 | Retry Year Weird Cookie flow for character 66, ingredients and resulting gains; character 67 Scouter/practice; Singer practice, Street Performer singing, Exam Dreams sleep | Costs, counters, gain amounts, guaranteed/proc behavior and update timing; show campaign/date/tick/active effects |
| E31 / F08,34,48 | Other character-special action menus, especially medicine/mechanical parts/crafting; requirements, success/failure and reward | Character ID/name, trigger/cooldown, costs/pools/limits, item/counter changes; description alone may not expose compiled behavior |
| E32 / A13,A14 | A13 withdrawn: inventory XP must not show a level-up event. A14 persistent availability confirmed by user and implemented. | Only new block-ID mappings or exceptions beyond the known persistent grant/removal rule remain relevant. |

## Exams, events, audio and later scope

| ID / TODO | Screenshots or recordings still needed | Details to explain if not visible |
|---|---|---|
| E33 / A15,U04,F05 | Mock-exam results with every column and Scorecard history; final CSAT -> applications -> results -> enrollment -> ending; share/export preview | Elective/percentile/rank units, prerequisites/locks, max applications, same-university/different-program rules, acceptance/rejection and award timing; hide personal data if needed |
| E34 / M05,M06,F05 | University enrollment reward, new/duplicate badge, completed-run cookie/ending summary and acceptance photo | Reward repeatability, badge unlock/selection limits, ending priority, whether choosing among offers changes rewards; seven setup badge slots already known |
| E35 / A10,A11,U01,U02,L05,L06 | Short original event sequence with date/tick/location visible before and after; opening/day-end/mom/test/roll-call/confinement and delayed/location-count examples when encountered | Choice/action sequence, event titles, same-tick ordering, whether tick/date moves during scene, counting reset/delay timing. Existing event text alone cannot establish dispatcher order |
| E36 / F02,F03,79 | Short recording with game audio during Home -> preparation -> event -> action/reward; relevant toggles; info-menu fade | Track/SFX changes, sound interruption/resume and fade timing; describe vibration since video cannot show it |
| E37 / F04,U07 | Stationery roulette stop -> confetti -> locking/redraw -> grant; combine result; odds/help if available | Confetti distribution/timing, redraw guarantee/cost and exact published odds; known high-tier combination rule and fresh-per-run scope need no reconfirmation |
| E38 / same-run saves | Stationery inventory/equipment after earning, saving/resuming, then starting a separate run | Only if behavior has additional exceptions: which same-run states survive resume, pending draw commitment. Cross-run carryover is explicitly NOT requested |
| E39 / U08,37 | Original English Quizmaster question/answers/result and any dedicated bank/help; old-project asset location if known | Dedicated Quizmaster versus school exam, language/version, answer/reward rules; source bank is more useful than manually photographing every question |
| E40 / F06,F07,U04 | Later, only when these ports are requested: Elite help/level/perks/rewards and owned support-pack details; other campaign-specific exam/mechanic screens | Exact modifiers, level curve, entitlement scope and campaign differences. Elite is currently deferred; do not spend money to obtain evidence |

## Tracking incoming evidence

Each E-number remains pending until a linked capture or explicit answer resolves
its missing behavior; a template screenshot does not resolve unseen states.
Record filenames, original version/campaign and which table cells are resolved.
Keep the original files unmodified in a dated screenshot subfolder and add their
specification to the relevant atlas. Close corresponding TODO sub-items only
after implementation and appropriate verification, not merely after collection.

Priority batches: E07-E08/E12-E21 support Claude's current menu work; E22-E32
support demonstrated gameplay defects; E33-E39 support wider parity. Internal
stub/condition bugs can be fixed using existing code/data without waiting for
all requested media. Do not block unrelated TODO work on missing screenshots.
