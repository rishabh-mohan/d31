# Original-game follow-up evidence: 24 October 2026, evening batch

Source: 30 user screenshots, three screen recordings, explicit user answers and
the linked public trait-pack probability page. Original files are copied without
modification to `screenshots/original-game-followup-2026-10-24/`; `manifest.json`
records sizes, dimensions and SHA-256 hashes. The Gallery screenshot is retained
but is not game UI. Account email/identity in originals is not a recreation default.
Screenshots and frames remain local reference material, not publishable assets.

This document supplements [the first menu atlas](MAIN-MENU-REFERENCE.md),
[the functional reference](ORIGINAL-GAME-FUNCTIONS.md) and
[the evidence checklist](IMPLEMENTATION-EVIDENCE-REQUESTS.md). Claude owns current
main-menu implementation; these findings specify behavior without rewriting his
code. Evidence received does not mean implementation completed.

## User-confirmed corrections and rules

1. Trait protection survives restarting the app. A protected card cannot be
   selected for combining; the supplied warning provides its exact UI.
2. Mileage resets after ANY S-tier draw, including an early S and a guaranteed S.
   Do not restrict reset to the guarantee or preserve it because the draw was early.
   The exact order of multiple S cards within a batch is not separately demonstrated.
3. Master of Notes supplies a **Weird Workbook before the book-completion item
   gacha appears**. The workbook popup displays random-subject +90, Use, Confirm.
   This is a separate reward source and must not replace/suppress the gacha.
4. An unmet end-of-day objective expires without a failure notification. Breaking
   a continuous condition, such as maintaining stamina above a threshold, shows
   a Surprise Mission Failed dialog. Do not show failure dialogs for every expiry.
5. **Inventory XP does not show the level-up event.** Withdraw audit A13's demand
   to show it on closing inventory. Levels/EXP must still update correctly, and
   suppressed scenes must not leak into later unrelated events. Event-granted XP
   behavior is separate from this inventory rule.
6. First enrollment at a college unlocks that college's achievement and gives
   **two cookies**. This confirmation concerns first college enrollment; it does
   not establish department-specific or repeat awards.
7. Research E33's remaining exam/application flow using public videos/wiki.
   Do not ask the user to reproduce the complete exam run again. The new History
   captures already establish its final results/Info/Score Card presentation.

## Shared visual structure

Original screenshots are 1080 x 2340 portrait. They use warm cream surfaces,
peach inset panels, orange outlines and orange action faces; failures use red
and successes green. Overlays darken the underlying screen, preserving context.
Rounded borders sit above fills so square children cannot cover the corners.
Orange/red buttons generally have a lower shadow; follow existing user-specific
flat-button exceptions in TODO 77 rather than globally overriding those requests.

History details use almost the whole area below the History header, a large red
top-right close corner, title with a thin brown divider and an orange bottom tab
strip. Selected tab expands its label; inactive tabs show icons. Switching tabs
keeps the same record. Settings/profile/charging dialogs instead float centered
over Home, with generous cream margins and a bottom Close button.

## Screenshot inventory and recreation details

The timestamp below identifies `Screenshot_20261024_<timestamp>_Korean Student
Simulator.jpg`, except F06, whose suffix is `_Gallery.jpg`. IDs follow attachment
order, not timestamp order. Full originals and the manifest are the source of
pixel measurements; descriptions below specify hierarchy and behavior.

| ID / time / requests | Location, contents and behavior |
|---|---|
| F01 / 214331 / E01 | Settings over Home. Top row has labeled BGM, SFX, Rumble orange square icon toggles. Two-line BGM explanation, brown divider, Type of Music three-way segmented control with Orchestral selected. Entitlement explanations below: Orchestra from Ad Removal Premium, Carol from Endless Winter Deluxe. Another divider, Language English/Traditional Chinese with English selected; wide red Close. |
| F02 / 214340 / E01 | Same Settings hierarchy with Regular selected. Selected music segment is solid orange/cream text; unselected segments pale peach/brown text. This is selection evidence, not proof of defaults or restart persistence. No numeric volume sliders are visible. |
| F03 / 214350 / E02 | Mail Box overlay with orange title bar/cream X, equal Mail List and Claimed Mail tabs, orange underline under Mail List. Large empty cream body, 'Mail Box is empty.' below center. |
| F04 / 214358 / E02 | Claimed Mail selected, underline moves right. Bold note caps history at ten claimed mails. Peach rounded rows contain framed reward icon with overlapping x10 quantity badge, title, horizontal divider, description and gray Collected button with dark lower edge. Examples include cookies and character-pack tickets. Unclaimed claim/expiry behavior remains unseen. |
| F05 / 214418 / E03,E04 | Account/profile modal. Avatar and username/edit pencil above email row. Two large balance tiles: Cookies and Refresh Tickets, each with icon, number and plus button. Invite Friend panel: ten cookies when invited friend finishes tutorial, up to ten people; Copy Code / View History. Email-updates checkbox; large Q&A button; copyright/terms/privacy/sign-out/delete-account links; red Close. Do not hardcode the photographed email or username. |
| F06 / 214452 / none | Android Gallery screen, black empty body and Pictures/Albums/Collections/Menu bottom navigation. Archive only; not an in-game screen or evidence of a game feature. |
| F07 / 214513 / E03 | Nested Change Username dialog dims profile and Home. Bold title specifies 2-16 characters; underlined input, right-aligned cookie balance, Cancel left and orange Change with cookie icon/9 right. Captures a nine-cookie rename price; successful validation/deduction and cancel transition not shown. |
| F08 / 214528 / E04 | Cookie Charging modal: top-right owned balance, three-column cookie package grid (last package centered), red bonus pills crossing card top edges, bold total plus small base+bonus, price beneath; invitation panel and ad-obtain action below; red Close. Scroll content inside modal. |
| F09 / 214534 / E04 | Same Charging modal scrolled lower. Ad-obtain section explicitly says up to twice daily. This does not expose amount per ad, reset timezone or refresh-ticket exchange pricing. |
| F10 / 214549 / E05,E40 | Store Ads tab: full-width orange header/X, Ads/Packs/Expansion/Cookie Store tabs and orange underline; Restore Purchase above scroll area. Owned Ad Removal active banner excludes cookie charging station. Premium poster lists six benefits: ad removal, Fund Manager storyline, Patron trait (part-time +400 shown), Hypnotist character, Orchestra BGM, Token of Gratitude item. |
| F11 / 214555 / E05,E40 | Packs tab, large vertical promotional cards: Elite Mode Support Pack advertises S-tier random trait; Study Starter Pack is Purchase Complete; Reward x2 Booster is Active. These are photographed account entitlements, not universal starting ownership. |
| F12 / 214601 / E05 | Lower Packs scroll: Reward x2 poster; Focus Pack shows one each Standard/Jumbo/Royal/Ultra, 54 refresh tickets, 50 cookies, $7.49. Full Focus shows two each, 110 refresh tickets, 100 cookies, Creator's Thank You Puzzle, $14.99. Record observed version/prices, not a mandatory real-money store implementation. |
| F13 / 214612 / E05,E40 | Expansion tab: two large purchased banners, Endless Winter Deluxe and Retry Year Deluxe, with campaign-specific art and Purchased ribbon. Restore Purchase stays above scrolling banners. |
| F14 / 214617 / E04,E05 | Cookie Store tab: Cookie Charging Station gradient bar, owned balance, seven cookie offers in a 3/3/1 arrangement; Product gradient divider and character-draw banner below. This route is distinct from the floating Charging modal despite reusing offers. |
| F15 / 214623 / E05 | Lower Cookie Store: campaign character-draw shortcuts for Winter and Retry Year, then Road to Acceptance Trait Pack banner showing Standard/Jumbo/Royal/Ultra. Each campaign banner has its own art, featured cards and Shortcut label. |
| F16 / 214627 / E04,E05 | Further Cookie Store scroll: trait-pack shortcut, large Refresh Ticket shortcut and Trait slot card showing 5/5 orange slots. The visible refresh-ticket banner does not establish a 'rewind time' engine effect; confirm the actual route before inferring mechanics from marketing text. |
| F17 / 214648 / E07,E33,E34 | History record Application Results tab. Student ID certificate uses college-colored border/header, watermark, student number/name/department, character portrait, crest/president signature and red seal. Orange upload-photo button below. Vertically stacked program cards show crest, department, Acceptance Rate label and green Accepted buttons; screenshot leaves the rate value blank, so do not invent one. Bottom strip selects University Apps; other tabs are Info and Score Card. |
| F18 / 214656 / E07 | Same record, Info tab. Centered peach rounded card: portrait/name; LV 9 Legendary and EXP fraction; Gold; Deviation 59.6; exercise level/progress and part-time level/progress. Five colored subject-stat chips. Divider below splits scrollable trait list on left from four equipped stationery cards in a two-by-two grid on right. Trait rows have effect-color background and tier dot. Preserve the record snapshot even though new runs reset stationery. |
| F19 / 214733 / E08 | Save deletion confirmation overlays Select Game. Original wording 'Uninstall Game?' refers to deleting a run in this context, not uninstalling Android app. Cream/orange rounded panel, orange close corner, centered title and orange Confirm/Cancel buttons. Do not execute deletion merely because the screenshot contains Confirm. |
| F20 / 214830 / E18 | Attempting to select a protected combine card opens centered cream/orange warning over dimmed Combine Traits: 'Combine-locked cards cannot be selected.' Only top-right X closes it; no bottom Confirm. Keeps slots/grid underneath visible. Protection restart persistence is user-confirmed separately. |
| F21 / 215200 / E22 | Master of Notes acquisition popup over a just-completed Math Textbook action: workbook art, title, short description, random-subject Stats +90, orange raised Use then Confirm with clear separation. User confirms it appears before general completion gacha. |
| F22 / 215228 / E22 | Subsequent Reading Complete reward UI: large title, divider, Math Textbook name, Maths chip and E-rank circle, second divider, Reward label, item artwork and red tap-to-obtain instruction. It is not the previous workbook receipt; reward roulette/claim sequence belongs to the separate gacha. |
| F23 / 215348 / E25 | Surprise Mission offer: compact centered cream panel/red border, exclamation icon/title, peach objective row Humanities achieve 946, red downward arrow, peach Humanities +636 reward row, red raised Confirm. Background hand shows red mission marker; offer overlay has no accept/decline pair. |
| F24 / 215415 / E25 | Same goal met: green border/title 'Surprise Mission Successful', same objective/reward, green arrow and Collect Reward button. Achievement occurs mid-day (eight filled ticks visible), distinct from final-day-only conditions. Grant/close must follow claim interaction, not a guessed toast. |
| F25 / 215434 / E25 | End-state mission: 'Finish with 26-33 Stamina' -> Donut-Shaped Cushion with icon and orange reward pill. Red offer styling as F23; active mission strip behind says to finish in that range. Do not evaluate it as a continuously maintained range. |
| F26 / 220004 / E25 | Continuous-condition failure: red 'Surprise Mission Failed', 'Maintain over 61 Stamina', red arrow and displayed forgone reward Part-Time EXP +540, Confirm. Displaying reward in failure dialog does not grant it. User contrasts this notification with silent end-of-day objective expiry. |
| F27 / 220310 / E39 | Riddle Expert event over Gold Mine: character stays visible above a tall cream answer sheet with wrapped English question and four full-width orange raised answer buttons. Question asks UN financial agency acronym; options IMF, ING, INT, PNG. IMF is the correct acronym; source does not prove all other bank contents. |
| F28 / 220323 / E39 | Same Riddle Expert scene awards Death Cutlet in standard acquisition popup: illustration, short description, 'All Stats Increase', Use and Confirm. It is an observed correct-answer reward example; do not infer every quiz has this fixed reward. |
| F29 / 220336 / presentation | End-of-day navy summary with 'Trait removed!' popup, red Hair Loss pill and orange Confirm. Shows removal presentation and ordering before proceeding from summary; it does not establish every trait's duration formula. |
| F30 / 214700 / E07,E33 | History Score Card tab: centered white paper with shadow on cream, 'Graduation Exam Score Card', table of name/gender, five subjects, Score and Top %. Values: 88/71/83/78/75, Top 6.8/29.1/12.2/19.8/24.1%. Selected bottom tab expands Score Card label. This historical card is not the unseen full live application process. |

Cookie packages in F08/F14 (observed USD pricing):

| Cookies | Base + bonus | Bonus label | Price |
|---|---|---|---|
| 17 | 16 + 1 | 6% | $0.99 |
| 36 | 32 + 4 | 12% | $1.99 |
| 56 | 48 + 8 | 16% | $2.99 |
| 118 | 98 + 20 | 20% | $5.99 |
| 373 | 298 + 75 | 25% | $17.99 |
| 832 | 640 + 192 | 30% | $38.99 |
| 1728 | 1280 + 448 | 35% | $74.99 |

## Supplied recordings

Each filename is `Screen_Recording_20261024_<time>_Korean Student Simulator.mp4`.
Derived contact sheets under `video-frames/` sample every five seconds and label
approximate timestamps. Use originals for exact timings; sampled frames can miss
short transitions and are not proof that intervening events did not occur.

| ID / recording | Observed sequence and implementation implications |
|---|---|
| V01 / 215300 / E22 | Reading Complete Math Textbook E reward cycles through item/stat outcomes; sampled frame near 2.5s shows Korean +40. Next sampled frame near 7.5s is Unlock Book, Abacus Practice D, with Confirm. Confirms a distinct unlock popup following completion-reward handling. Exact candidate pool/odds require assets/code, not this one draw. |
| V02 / 220239 / E22,E24,E36 | Preparation at D-10 Monday includes Korean reach 1602 -> Korean reward 40. Weekly Goals Met popup appears during gameplay with objective 1562 -> 1602 and reward Korean +40, then Confirm; thus notification can occur mid-day, not only next Monday. Later workbook receipt precedes Reading Complete for Abacus Practice; another completed book shows Humanities +105. Ends on D-10 night summary. Effects shown are from this buffed run, not unmodified study baselines. |
| V03 / 220428 / E37 | Stationery gift wrapper on navy -> five rolling cards on dark radial background -> stopped results with mixed tier confetti -> locks -> free redraw -> stop controls -> results, paid redraw/Close. Redraw text guarantees B tier or higher. Owned cookies display and free/one-cookie labels visible. One locked position is retained while other cards change. Separate per-card tap/Stop all Stationery controls are visible; do not replace the roulette with immediately final cards. |

## Trait-pack rates recovered from the user-linked public page

Source: [Trait Pack Probability Information](https://caring-challenge-9d3.notion.site/Trait-Pack-Probability-Information-3f1c3e34652d808d8414f8645b477285),
retrieved 2026-10-24 through its public Notion page data after the web reader
could not render it. All pagination was consumed (223 block records; no remaining
cursor). Original responses/ordered extraction are local under
`build/original-evidence-web/`; normalized factual rates are retained below.
Machine-readable transcription: [original-game-trait-pack-rates.json](original-game-trait-pack-rates.json).

The page states independent trials and uniform selection within each tier. It
advertises rounding to three decimal places, but several displayed results use
two; preserve its displayed values rather than assuming they are exact runtime
weights. Separate per-card **exact tiers** from whole-pack **at least one card
of that tier or higher**. Mileage guarantee/reset is a separate user-confirmed
rule, not included in these ordinary independent-draw rates.

| Campaign / pack | Cards | S per card | A per card | B per card | C per card | Pack S+ | Pack A+ | Pack B+ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 31-Day / Standard | 3 | 0.34% | 4.66% | 15% | 80% | 1.02% | 14.26% | 48.8% |
| 31-Day / Jumbo | 5 | 0.34% | 4.66% | 15% | 80% | 1.69% | 22.62% | 67.23% |
| 31-Day / Royal | 3 | 1.05% | 10% | 88.95% | 0% | 3.12% | 29.62% | 100% |
| 31-Day / Ultra | 5 | 1.05% | 10% | 88.95% | 0% | 5.14% | 44.32% | 100% |
| Winter / Rudolph | 3 | 0.34% | 4.66% | 15% | 80% | 1.02% | 14.26% | 48.8% |
| Winter / Snowman | 3 | 1.05% | 10% | 88.95% | 0% | 3.12% | 29.62% | 100% |
| Winter / Santa | 5 | 1.26% | 10% | 88.74% | 0% | 6.14% | 44.97% | 100% |
| Winter / Snow Maiden | 5 | 1.47% | 10% | 88.53% | 0% | 7.14% | 45.62% | 100% |
| Retry / Second Retake | 3 | 0.34% | 4.66% | 15% | 80% | 1.02% | 14.26% | 48.8% |
| Retry / Exam Retake | 3 | 1.05% | 10% | 88.95% | 0% | 3.12% | 29.62% | 100% |
| Retry / No Retakes | 5 | 1.26% | 10% | 88.74% | 0% | 6.14% | 44.97% | 100% |
| Retry / Advanced Class | 5 | 1.47% | 10% | 88.53% | 0% | 7.14% | 45.62% | 100% |

Card counts for named premium campaign packs agree with their published pack
probabilities under independent trials; verify product labels when implementing
their stock UI. Tier population counts on this source version:

| Pool | S | A | B | C |
|---|---:|---:|---:|---:|
| 31-Day | 16 | 35 | 30 | 17 |
| Winter ordinary | 21 | 46 | 38 | 23 |
| Winter Snow Maiden | 5 | 46 | 38 | not offered |
| Retry ordinary | 21 | 43 | 38 | 24 |
| Retry Advanced Class | 5 | 43 | 38 | not offered |

Individual-trait probability is tier rate divided by eligible pool count, using
the actual source-version membership. Do not distribute uniformly across the
entire global catalog or assume all 21 S traits belong to the special five-S
pool. Named membership, guarantee placement in a multi-card batch, exact internal
unrounded weights and newly added traits still require reconciliation. This page
does **not** contain trait-combine rates, stationery odds or mission-generation
probabilities; it does not resolve TODO U07 or every probability question.

## E33 online research handoff

Update 2026-10-25: the user supplied a complete current D-Day/application/results
recording. Prefer its [70-frame recreation handoff](D-DAY-APPLICATIONS-REFERENCE-2026-10-25.md)
for current labels, candidate editing, live search, envelope animation and the
rejection/retake/reward route. The older successful branch below remains a
separate source; the new recording does not show accepted offers. This is an
evidence update, not implementation completion.

Inspected the first-hand [One Month Mode walkthrough, Part 3](https://www.youtube.com/watch?v=m8EDSlMogHc)
(9m30s): it stops around D-12, so it does NOT establish the final application
flow despite its broad search description. Then found and visually inspected
[Part 4](https://www.youtube.com/watch?v=KIy1lFnmIIU) (12m09s), which does show it.
Sampled source frames are local under `public-exam-video/part4-<seconds>s.jpg`.
These are separately sourced from the user's media and retain the creator's
watermark. Do not publish or use those frames as recreated game assets.

| Video position | Verified original behavior / UI |
|---|---|
| 10:06 (606s) | D-Day has a single large purple subject exam card, e.g. Science, in the normal hand area. This is the 31-Day campaign's exam presentation; do not apply it automatically to Retry Year. |
| 10:14 (614s) | Graduation Exam Score Announcement floating modal: five colored subject headers, Score and Top % rows, orange Next. This older footage uses Society where the supplied current English capture uses Humanities. |
| 10:18 (618s) | Second announcement modal displays a white printable scorecard with name/gender and the same two numeric rows. Turn in Papers button; divider and share section with Instagram, X and download icons. Distinguish summary results from the export-style scorecard. |
| 10:24 (624s) | Full-screen Submit route: Quests top left, Turn In top right; Recommended Majors / Search within Schools / Search Majors tabs; Sort dropdown, Hide Applied Universities toggle, acceptance-rate range slider 20%-80%; scrollable crest/college/department/rate/enrollment-count cards and green Apply buttons. Bottom collapsible application tray has three slots, Auto Input and a handle. Two visible departments from the same university are offered; this does not prove duplicate identical programs can be submitted. |
| 10:30-10:36 (630-636s) | Apply fills the three candidate slots; slots show crests and predicted rates. In this example the chosen rates are 32%, 25%, 19%. Applied-university filter behavior/alternative search pages were not exercised in these sampled frames. |
| 10:40 (640s) | Turn In opens Apply? confirmation listing all three college/department/rate choices, total-rejection chance 41.31%, top-right X and orange Confirm. The displayed value matches 0.68 x 0.75 x 0.81 = 0.4131 for this example; that arithmetic does not recover the upstream individual probability model. |
| 10:44-11:08 (644-668s) | Dark Application Results Announcement, stacked colored crest envelopes animate/reveal one by one. Rejected result cards show college/department, red outcome and gold Confirm. The first and second sampled choices reject; this is not the static History list presentation. |
| 11:20 (680s) | Final Decision screen shows Korea Retry Academy / Comprehensive Retake Course after rejection flow. This branch does not demonstrate selecting among several successful offers. |
| 11:30-11:40 (690-700s) | Ending dialogue over results and black Retry Ending title/Confirm. Visible order should be preserved separately from fitted scoring logic. |
| 11:44 (704s) | 'Obtain First Enrollment Reward!' with one Jumbo Trait Pack and 20 refresh tickets, with confetti and Confirm. This appears to be the account's first-enrollment reward in the older footage; it is a distinct context from the user's confirmed two-cookie first-college-achievement reward. Do not replace that confirmation with this different award. |

Also inspected [Tutorial True Ending walkthrough, Part 2](https://www.youtube.com/watch?v=z9I19uKLRE0)
(5m42s), which supplies a successful branch. Approximate sampled timestamps:

- 2:57-3:07: score announcement then the same application tray structure.
- 3:17-3:37: sequential crest-envelope reveals and green accepted result cards.
  Applied program cards/percentages are shown, including three eventual offers.
- 3:47: Final Decision presents three accepted college/department cards stacked
  vertically; this is a choice of enrollment, not enrollment in all three.
- 3:57: selected Inje University certificate/result page, photo-upload control,
  confetti, sharing/download controls and Confirm; then ending dialogue.
- 4:37: Tutorial True Ending title. Around 4:47, Ending Reward Obtained grants
  one Jumbo Trait Pack. This is an ending reward in this older tutorial, not
  proof that current first-college achievement cookies or all ending rewards match.

Selected tutorial frames are archived separately under `public-exam-video/`,
with source URL and approximate timestamps in its manifest. The scorecard,
successful-offer selection and rejected-application paths now have visual
evidence. Duplicate-program enforcement, alternate search/sort controls and
exact scoring/odds remain distinct questions. Use native code for hidden
arithmetic, and prefer the user's current captures over older labels/rewards.
Do not request another complete exam run from the user.
