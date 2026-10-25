# D-DAY comparison: D30 recreation vs. Korean Student Simulator

Review date: October 25, 2026. Status: documentation and change backlog only; no gameplay changes made.

## Main findings

The recreated results flow contains the main envelope, verdict, enrollment-confirmation, certificate and completion-summary steps. The highest-priority corrections are the ending-title interaction and the background behind ending dialogue. The title currently disappears after three seconds without a Confirm button, briefly exposing an empty dialogue window before the summary. Other visible differences concern previously revealed cards remaining behind the active verdict, long school-name truncation, envelope pacing, and the successful-offer card design.

The recordings show different branches. D30 has Harvard / Medical School (95%), Georgia Institute of Technology / School of Medicine (100%), and Purdue / Computer Science (100%), all accepted, followed by Elite Ending. The current original recording has three rejections followed by Korea Retry Academy and Retake Ending. Different schools, scores, names, colors and ending text are expected run/catalog differences. They are not evidence that D30 must reject these offers or use the original player's values.

## Sources and review limits

- D30 supplied recording: `Record_2026-10-25-16-06-16[1].mp4`, 1:08.61, 720 × 1600. [Archived copy](../screenshots/d30-dday-comparison-2026-10-25/d30-recording.mp4); [hash and method](../screenshots/d30-dday-comparison-2026-10-25/manifest.json).
- Current original recording: `Screen_Recording_20261025_011355_Korean Student Simulator.mp4`, 3:16.78, 1080 × 2340, in [original evidence folder](../screenshots/dday-applications-2026-10-25/). [Scenario handoff](../screenshots/dday-applications-2026-10-25/HANDOFF.md), [gallery](../screenshots/dday-applications-2026-10-25/index.html), [reference overview](D-DAY-APPLICATIONS-REFERENCE-2026-10-25.md).
- Separate older successful branch: locally archived `tutorial-approx-227s.jpg`, with provenance in [public-exam-video/manifest.json](../screenshots/original-game-followup-2026-10-24/public-exam-video/manifest.json). It supports a successful-offer layout comparison, with lower confidence for the current version. See [earlier observations](ORIGINAL-GAME-FOLLOWUP-2026-10-24.md#e33-online-research-handoff).
- Current implementation contracts: [DDAY-UI.md](DDAY-UI.md), [DDAY-FLOW.md](DDAY-FLOW.md). Source files were inspected to identify likely change locations; they do not prove the installed recording came from the exact current checkout.

D30's complete visual timeline was sampled at one frame per second, with selected full-size images inspected. The original results/ending contact sheets and selected native frames were checked against the notes. Times below are approximate source-video positions, not exact animation measurements. No separate audio or haptics analysis was performed. Device bars, recording indicators, touch circles and edge handles are excluded from the game comparison. Instructions embedded in references are treated as source material, not new user requests.

## Aligned timeline

| Stage | D30 | Current original | Assessment |
|---|---|---|---|
| D-Day preparation, five exam cards, scores, application selection | Before clip | 0:00–2:03 | Not assessable from D30 recording. |
| Results announcement title | Before clip | 2:03–2:07 | Not assessable; D30 begins on envelope stack. |
| First envelope and verdict | 0:00–0:09 | 2:08–2:16 | Shared sequence; different outcome. |
| Second envelope and verdict | 0:10–0:18 | 2:18–2:28 | Shared sequence; earlier cards remain behind D30 verdict. |
| Third envelope and verdict | 0:19–0:31 | 2:30–2:39 | Shared sequence; pacing differs. Reading time excluded. |
| Combined results | 0:32–0:33 | 2:40–2:42 | Three ordered cards and separate orange Confirm present. |
| Final Decision | 0:34–0:46 | 2:43–2:44 | Different branches; successful layout checked separately. |
| Enrollment modal/loading | 0:47–0:49 | 2:45–2:47 | Core two-step confirmation present. |
| Certificate/share scene | 0:50–0:54 | 2:48–2:54 | Present; ranking omission is intentional. |
| Ending dialogue | 0:55–1:00 | 2:54–3:00 | D30 backdrop differs. |
| Ending title | 1:01–1:03 | 3:00–3:06 | D30 lacks delayed Confirm and auto-dismisses. |
| Empty dialogue return | ~1:04 | Not present in this original sequence | D30 transition issue. |
| Completion summary | 1:05–1:08 | 3:07–3:10 | Core content present; visual proportions differ. |
| Leave summary / ending reward | After clip | 3:11–3:16.78 | Not assessable from D30 recording. |

## Difference log and required changes

P1 = interaction/sequence correction. P2 = visible fidelity/readability correction. P3 = visual polish or separately sourced behavior. All entries remain OPEN unless marked intentional or unverified.

| ID / priority / evidence strength | Difference and evidence | Required change and completion check | Likely implementation location |
|---|---|---|---|
| DDAY-C01 / P1 / high | D30 ~61–63s shows Elite Ending, then disappears without a visible Confirm. Original ~180–186s holds Retake Ending and introduces an orange bottom Confirm. Current source explicitly auto-pops after three seconds and allows any tap. | Use an ending-title state that reveals the bottom Confirm after a delay and waits for it. Tune delay against source; roughly five seconds is an observation, not a universal exact constant. Check that idle title remains open and only the intended action advances once. | `lib/ui/event_screen.dart`: `showEndingCard`. |
| DDAY-C02 / P1 / high | D30 ~64s briefly returns to an empty Elite dialogue window over a blurred gameplay screen before the summary. Original proceeds from title confirmation into completion summary without that empty window. | Close/replace the finished event as part of the title-to-summary transition. No blank dialogue frame, renewed dialogue input, or underlying gameplay flash should appear. Check normal and fast-forward paths. | `event_screen.dart`: `_announceItems`, ending-card return; `game_screen.dart`: `_sitCsat` and `_closeRun`. Exact cause requires a replay. |
| DDAY-C03 / P1 / high | D30 ~55–60s ending dialogue overlays the blurred normal game HUD. Original ~174–179s keeps the orange certificate/share scene behind its ending dialogue. | Preserve the certificate scene as the background while authored ending dialogue plays, then transition to the ending title. Verify on acceptance and rejection endings. Do not replace Elite dialogue with Retake dialogue. | `lib/ui/dday_results.dart` finish handoff; `game_screen.dart` ending event presentation. |
| DDAY-C04 / P2 / high for current rejection reference | D30 ~14–18s and ~27–31s retains earlier result cards immediately behind the active verdict. Original settled second/third verdicts ~145–148s and ~156–159s show the current card alone; earlier cards appear again during stack states. | Hide or move previously confirmed cards out during the isolated opening/verdict state; restore them for the envelope stack and combined results. Preserve order and stored outcomes. Current-version accepted-state equivalence still needs confirmation. | `lib/ui/dday_results.dart`: `_EnvelopeSequence` card stash and opening/card state composition. |
| DDAY-C05 / P2 / high readability, medium exact source behavior | Georgia Institute of Technology is truncated to “Georgia Institute of Techn...” on D30 result/combined cards (~14s, ~32s). Original examples fit their labels; these do not establish an exact long-US-name rule. | Fit or wrap long school/department names within the identity area while preserving crest, divider and verdict. Check all three selected US programs at the recorded viewport and a narrow viewport. Acceptance criterion is readable program identity; do not claim a recovered source wrapping algorithm. | `lib/ui/dday_widgets.dart`: `ResultCard`, currently single-line ellipsis for university and department. |
| DDAY-C06 / P2 / medium | D30 opening-to-verdict transitions are visibly more compressed (first ~4–6s, second ~12–14s) than original (~130–135s and ~140–146s). Both contain tilt, opening flap, emerging letter and glow, but the original gives these stages more time. | Compare activation-to-settled-verdict segments at finer sampling and lengthen/rebalance animation stages. Do not use time spent reading cards or idle stack time as animation duration. Current source uses one 2.8-second controller; original cues suggest a longer reveal. | `dday_results.dart`: `_open`, interval boundaries; `dday_widgets.dart`: envelope drawing. |
| DDAY-C07 / P2 / medium; older successful source | D30 Final Decision ~44–46s uses Accepted verdict cards with small inline crests and divider. Older successful reference ~227s has selection cards with large centered crests, school and department, without repeated Accepted text. | Use dedicated enrollment-choice cards after the Final Decision action, keeping verdict cards for results. Preserve the intermediate Final Decision button behavior documented as a user specification. Verify current-version successful styling when available; the older clip cannot override newer explicit scope decisions. | `dday_results.dart`: combined results/choice state; `dday_widgets.dart`: separate choice-card presentation. |
| DDAY-C08 / P3 / high visual, timing approximate | D30 certificate appears high at ~50s and moves down by ~52s. Original introduces rank text first and then the certificate around ~170–172s; D30 deliberately omits ranks. | Rebalance the rank-free certificate scene as an intentional layout, keeping card, upload, share and Confirm stable once entry finishes. Check whether the ~50–52s movement is intentional entry animation or an unwanted relayout; do not re-add rankings to fill space. | `dday_results.dart`: certificate/share layout and route entry. |
| DDAY-C09 / P3 / high visual | D30 title uses visibly different lettering and sits higher (~61–63s) than the original centered Retake Ending (~180–186s). | After C01, align title typography and vertical placement proportionally to usable screen space. Compare text styles rather than the different words. Keep font/content data reusable across endings. | `event_screen.dart`: `showEndingCard`. |
| DDAY-C10 / P3 / high visual | D30 summary ~65–67s is denser: its stats/scorecard panel has less lower breathing room than original ~188s. Header, certificate, stat chips, printable scorecard and bottom button are all present. | Tune panel height, padding and spacing using normalized safe-area screenshots. Keep scrolling on small screens and reserve room for long names and five-digit stats; do not hardcode original 1080×2340 coordinates. | `lib/ui/end_screen.dart`, `printable_score_card.dart`, `StudentIdCard`. |

### Visual evidence

Each pair preserves the different source aspect ratios; compare relative safe-area geometry rather than raw pixels.

![Isolated original verdict versus D30 background cards](../screenshots/d30-dday-comparison-2026-10-25/01-results.jpg)

![Older successful enrollment choices versus D30 verdict-style choices](../screenshots/d30-dday-comparison-2026-10-25/02-choice.jpg)

![Original certificate backdrop versus D30 gameplay backdrop](../screenshots/d30-dday-comparison-2026-10-25/03-dialogue.jpg)

![Original title Confirm versus D30 title without Confirm](../screenshots/d30-dday-comparison-2026-10-25/04-title.jpg)

## Differences to preserve or leave unresolved

| Difference | Disposition |
|---|---|
| US schools and their crests/colors versus Korean/Taiwan schools | Preserve selected college-set behavior and Purdue boost. These are authorized catalog differences. |
| Accepted/Elite versus Rejected/Retake, different player and final stats | Preserve run-specific outcomes. The recording does not show faulty odds or scoring. |
| No global-rank lines on D30 certificate | Intentional user scope: no leaderboard. Do not add a backend or fake ranks. |
| Original shows two packs with X2 entitlement | D30 reward is outside this clip. Current docs say one base pack and no X2 purchase. Do not classify an unrecorded reward as failed or grant two universally. |
| Instagram/X controls visible | Current docs describe unavailable-build messages. Neither recording exercises an external share. Presence does not prove integration works. |
| Photo upload and download controls visible | Not exercised in these clips. Current implementation claims require separate interaction verification. |
| Black ending artwork area | Both show a black artwork area in their respective endings; this comparison does not establish missing art. |
| Fast-forward, persistence, admission randomness, duplicate prevention | Not proven by this recording. Do not mark correct or broken from visual similarity alone. |
| Earlier exam and application screens absent from D30 clip | No finding. Use existing notes as a specification and capture those screens in a later verification run. |

## Changes that need replay verification

1. Fix C01–C03 first. Run through enrollment, ending dialogue, delayed title Confirm and completion without touching the screen during waits. Repeat with fast-forward. Confirm there is no blank dialogue return or gameplay backdrop.
2. Fix C04–C07. Exercise three results, a long US school name and a mixed accepted/rejected set. Keep stored verdicts unchanged through animations and selection. Recheck all-rejected academy path separately.
3. Apply C08–C10 visual polish after flow is stable. Compare at the captured aspect ratios with system overlays excluded.
4. Extend capture beyond Back to Main Menu to verify reward timing and exactly-once grant. Verify save/resume between results, enrollment and ending separately; video review alone cannot prove persistence.

This report records observed differences and proposed corrections. No items are marked implemented, tested or DONE. Scenario/reference instructions were not executed. Existing gameplay files, account data and saves were left unchanged.

## Status — 2026-10-25

All ten items were addressed in code and widget-tested; none has been replayed on a device (testing on device is left to the owner).

| ID | Outcome |
|---|---|
| DDAY-C01 | DONE. Every ending card (END_GAME and SHOW_ENDING) waits: no auto-dismiss, no tap-anywhere; a wide orange Confirm fades in after `endingConfirmDelay` (4.5 s, immediate under reduced motion) and closes it once. A mid-event SHOW_ENDING (Retry Year opening) still continues the dialogue afterwards (tested). |
| DDAY-C02 | DONE. Cause: the ending title is a dialog whose 250 ms fade-out and the event route's own 180 ms fade both exposed the finished event's empty dialogue box over the blurred game, and the game screen showed gameplay again while `_closeRun` awaited storage before the summary was pushed. Fix: the event panel renders plain black once only the ending title remains and leaves without a fade; the game pushes a black page before recording the run and replaces the game with the summary. Normal and fast-forward paths share this (fast-forward stops at the card). |
| DDAY-C03 | DONE. The results route is no longer popped before the ending events; they play over the certificate/share scene (existing blur and dim), for acceptance and retake endings alike. Ending text untouched. Resume mid-endings (no scene on the stack) still plays over gameplay. |
| DDAY-C04 | DONE. Earlier confirmed cards are hidden during opening/verdict and fade back for the stack and combined results. |
| DDAY-C05 | DONE. School and department names wrap to two lines and the identity block scales down as a last resort (tested with Georgia Institute of Technology / School of Medicine at 393 and 320 wide). |
| DDAY-C06 | DONE. Reveal lengthened to 5 s with named stage intervals; reduced motion unchanged. |
| DDAY-C07 | DONE. Final Decision turns accepted cards into `ChoiceCard`s (large crest, school, department, no verdict text); rejected still fade, accepted still centre. |
| DDAY-C08 | DONE (no relayout found). Frames 51 s and 52 s of the recording are identical; there is no entry animation or late-loading content that moves the layout (the card has a fixed aspect ratio). The rank-free gap was tightened to balance the block vertically, and a test asserts the scene is stable after entry. |
| DDAY-C09 | DONE. The old title lost its text style (a bare dialog had no Material, so it fell back to a monospace face); it now uses the theme font, bold white, sized to the screen width, centred. |
| DDAY-C10 | DONE. More space above and below the stats/scorecard panel; still scrollable. |
