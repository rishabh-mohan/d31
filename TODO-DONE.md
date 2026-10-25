# Finished TODOs

Moved verbatim from [TODO.md](TODO.md) on 2026-10-25. Open work, sorted by difficulty and estimated cost, stays in TODO.md.
Entry numbers and audit IDs are unchanged.

## Finished requests

1. Traits in the "Traits" menu on the day start screen should have a green, red, or purple background depending on the effect of the trait (positive green, negative red, neutral purple). The backgrounds are implemented in the info menu
   DONE — Shared green/red/purple trait colors now appear in preparation, My Info and setup.

2. Modify the Store menu (in the overall page, not the menu shared with items, books, stationery) so that the icons are more visible, even if it means that one item is cutoff/not visible from the outside menu.
   DONE — Hub Store has larger 48px icons; the follow-up taller panel now fits four previews. The full Store still lists every offer.

3. In the Books detailed menu, change the "Unlocked when you complete X" to "Unlocked when you complete the previous book" unless the previous book is already unlocked, which should then keep the "Unlocked when you complete X" structure.
   DONE — Locked books name the previous book only when it is unlocked; otherwise say “the previous book”.

5. Comb through the main project and create a .md detailing the effects of every item, trait, and event. Ask the prompter for clarification when psuedocde and other resources are not able to provide a good enough answer
   DONE — Generated references/recovery/EFFECTS-REFERENCE.md for all 177 items, 244 traits and 149 active-pack events, with conditional graph outcomes and source hashes. docs/EFFECTS-REFERENCE.md distinguishes current behavior, unresolved originals and concrete proposed prototype rules, as requested. Regenerate with tools/build_effect_reference.py; generated game text stays local-only.

6. Quizmaster (event) does not display the question being asked, it looks like the title for choices is not shown/is truncated. Needs fixing
   DONE — Choice panel displays authored optionText and the complete question above answers, with scrolling for long text; tested at 320px/393px.

7. Stamina depletion should not show up if the character runs out of stamina on the 14th tick
   DONE — Zero HP on the final action follows normal day rollover, without exhaustion dialogue or collapse penalty; final/penultimate boundaries tested.

8. Match the UI of the intitalization screen to the UI shown in the screenshots in references
   DONE — Reference-style mode cards, Student ID carousel, crest slots/list, portrait with five trait slots, tiered two-column trait cards and name screen. Elite/shop mechanics remain tracked under TODO 4.

9. It looks like location is broken for the first six ticks, the school picture does not appear in the background
   DONE — School uses its original bundled classroom, and image paths survive pack regeneration.

9B. In the location selection screen, the images for each location are blank.
   DONE — All eleven location cards resolve bundled art. Eight streamed originals recovered; Art Museum uses a documented temporary fallback because both original URLs return 404.

10. In events, the picture of the person speaking (sometimes built with multiple pictures to allow for changing expression, action, etc) should be visible (if the main character starts speaking, keep the previous speaking character on screen)
   DONE — NPC body/expression/clothing layers render and persist during player speech; explicit hide and expression changes are tested.

11. Store and Traits should be taller than Stationery and the books-items-scorecard-schedule block so more shop items and traits are visible at a glance. Once there are too many traits to display on the traits box, add the ability to scroll
   DONE — Traits/Store are taller (7:5), four Store previews fit, and overflow traits scroll inside their box.

12. Colleges should have their college icon, and closer resemble the examples provided in reference screenshots
   DONE — Original college crests, colored effect rows and fixed four-plus-three selected slots match the reference structure.

13. This will likely be fixed with the proper implementation of colleges matching the screenshots provided, but the My Info tab should not scroll, and the college section of it should more closely match the reference screenshots
   DONE — My Info uses a fitted fixed layout with seven crest slots and no scroll, tested with seven long college names and eighteen traits.

14. Add rotation lock to app, rename app to 30 Days, and add an app icon
   DONE — Portrait is locked in the Android manifest (so the launch theme cannot flash sideways) and again via SystemChrome in main.dart. The launcher label, the MaterialApp title and the desktop window title all read "30 Days"; the Dart package is still d30mode, since renaming it would rewrite every import and the Android applicationId for no user-visible gain. The icon is a cream "30" on the accent orange, drawn by tools/make_app_icon.py at all five densities plus an adaptive foreground/background and a monochrome layer — generated rather than cropped from KSS art, which must stay unpublished.

15. Schedule events should not be hardcodes as more scheduled events can be added by in-game events (ie. cooking competition, math competition).
   DONE — The Calendar is derived from the campaign's date-pinned events (docs/D30-MODE-SPEC.md §6.6 lists all 23), so nothing about it is hardcoded and a storyline that pins a National Cooking Contest shows up on its own. Which pinned events to list is our rule and is marked as such: an event belonging to a storyline set only appears once the run has met that storyline, otherwise day one would advertise every career at once. Finished and past entries drop off; the hub strip shows whichever entry is next. Game.schedule() with three tests in test/schedule_test.dart.

16. Events show the previous speaker from the last event on the first screen of the new event
   DONE — Your 16RESPONSE nailed it. `standingId` is the actor; `speakerId` only names the chip, and five NPCs answer to some form of "Friend" (ids 1, 23, 25, 26, 10002). Master of Massages (event 55) opens with standingId 8, the heavy-set friend, on a line whose speakerId is 1, the friend in glasses — and the next line carries no standing at all. We were falling back to the speaker, so the art swapped on that second line, which is exactly 16R1 to 16R2. Now only standingId moves the actor; a line with no standing of its own keeps whoever is there, which is also what keeps the NPC on screen while the player speaks. A line that names an expression or outfit without a standing still restyles them, so reaction shots keep working. test/event_portrait_test.dart walks event 55 and asserts the portrait never changes.

17. Stamina is being subtracted by one less than the stated rate (should subtract by the stated rate)
   DONE — Confirmed consistent: a probe comparing every block's card cost against the stamina actually spent matched exactly (lesson -9, study -16, part-time -28, sleep 0). The remaining mismatch was the old +4 max stamina per exercise level, which made a 16-point cost read as 15% of a 104 pool. That reading was wrong: stamina now caps at the pack's 100 in both campaigns, so card points and bar percent agree. See docs/RETRY-FOLLOWUP.md and docs/D30-MODE-SPEC.md 3.5.

18. Go through the screenshot descriptions in docs/ui-reference and move the UI closer to them
   DONE — Gameplay: HP percentage now sits inside the bar, centred on the filled part and red when low (UIR-17/18); the met-goal check moved to the far right of the goal row (UIR-28); the hamburger drawer is left-anchored with a red top-left close, Main Menu/Save restriction text, ON/OFF circle toggles and destination rows (UIR-30). Night screens got the raised card and green button (UIR-08/19). Preparation: weekly goals now announce themselves once per goal week in a two-inset-card dialog with "Let's do this!" (UIR-09); the schedule strip and Calendar entry share one rounded row with an orange date segment (UIR-10/16); Score Card is short with an integrated corner X (UIR-15). Commerce: acquisition popup with artwork, Use above Confirm (UIR-22); wallet/sort pills and a category line in store cards (UIR-11); filter pills carry the filled toggle and the set hint matches (UIR-12); locked books are washed under a large padlock and progress shows count/target markers (UIR-13); the combine result reveals on a dark glowing stage (UIR-27). Events: history is titled by the event with coloured speaker chips, rules and a red Close (UIR-32); choices are a full-width sheet with centred heading and orange branches (UIR-31). Stationery draw rolls until stopped, on a charcoal vignette (UIR-23/24/25).
   Not done, deliberately: the sudden-mission strip (UIR-28) needs a mission system that does not exist; the grey warning-triangle control (UIR-20/21) has no established action, so it was not invented; the quick stamina-item panel (UIR-33) remains the deferred item it already was.

19. Find and fix the source of lag
   1R — Measured, not guessed. StationeryCard's auto-fit name search ran up to ten TextPainter layouts inside a LayoutBuilder, so it re-ran on every rebuild and relayout; four of them on the preparation hub cost ~11ms of a ~24ms rebuild. Caching the fitted size takes the hub from 24.2ms to 9.6ms and the expanded stationery menu from 15.9ms to 10.1ms (debug, 393x852). Method and numbers are in CLAUDE.md §5e.
   2R - Reopened after deployment: the app was launched with software rendering for screenshot checks. Nord logs showed about 500ms raster frames, unlike Claude's earlier ~8ms. The same debug APK has now been restarted with hardware rendering; a profile build is now installed without software rendering, removing debug overhead for further measurements. Keep the stationery fit cache. Representative post-fix gameplay verification is still pending.
   DONE - The hardware-rendered profile APK is installed and its hash verified. The user confirms the whole game is much smoother. The global FPS regression was the software-renderer launch setting, not a reason to remove animations or Claude's caches. Keep normal deployment hardware-rendered; investigate any later screen-specific cost separately with frame timings.

20. Select button, and all subsequent bottom-positioned buttons on select character screens is cut off (screenshot on Nord)
   DONE — The footer button was inside the scaled 390x750 canvas, so on a real device it was scaled along with everything else and cropped against the bottom. The canvas is now content-only and the button is laid out at device scale beneath it, where nothing can crop it; the top banner stays put. I could not reproduce the crop in a widget test at 393x873 or 360x800, so if it still happens on the Nord please send the screenshot.

21. Store, stationery, Go to, and bags in the Menu screen are nice features but don't exist in the main game. Get rid of Go to, and hide the other three (may be nice to use for other campaigns in the future)
   DONE — Go to is gone, along with its plumbing. Store, Stationery and Bags sit behind _MenuSheet.campaignShortcuts, a const false, so another campaign can switch them back on in one line.

22. On the navy night screen, weekly goals should more closely match the structure of the original game (see screenshots' descriptions in docs)
   DONE — The goal is now one compact header row inside the card (label, target chip, arrow, reward chip, or a dash before the objective is announced), per UIR-08 and UIR-19, instead of two oversized chips stacked above the stats. It no longer squeezes the five subject columns.

24. When tapping on traits in the trait menu, a small window with the trait plate and its description should show up (screenshot in references but no description, sorry!) (trait tap example.jpg)
   DONE — Tapping a trait in the preparation hub opens a cream, orange-bordered dialog: the trait's own plate in its polarity colour, its description, and one Confirm, as in the screenshot.

25. When a study/part time/exercise/ect button is pressed, it should look like it is pressed down by moving down to make the bottom shadow the same size as the side and top shadow (top shadow should not grow), and should pop up when let go on or when no longer pressed on. Pop up should be at the same time as blocks changing if the user lets go over the block
   DONE — Blocks are built on _PressDown: held, the card drops by exactly the 7px it sits above its shadow and the shadow closes up, so the bottom edge matches the sides and nothing appears above. It is instant both ways, so releasing over a block pops it up on the same frame the hand is dealt again.

26. The student XP tracker should be less opqaue and gray
   DONE — The level card is a greyer slate at 55% opacity instead of 88%, so the scene reads through it.

27. Gold, Cookies, and the info button should share a bar (make the divider not have gaps and be connected to the top and bottom edge, an do this for the D- and date block too). Check screenshots and descriptions for reference.
   DONE — Gold, cookies and the info button share one bar, and the dividers run edge to edge. The bars used to pad themselves, which both left a gap above and below each divider and pushed cell contents off centre; padding now belongs to the cells.

28. D-X, the date, gold, and cookies should not be bolded. Would prefer a different icon for cookies as well
   DONE — All four are regular weight. The cookie is a small drawn icon rather than pack art, so permanent chrome does not depend on the pack.

29. The date (mon, tue, wed) is not centered in its section, and neither is the gold
   DONE — Same cause as 27: the bar's own horizontal padding meant each cell's layout box did not match its visible section. Cells now span edge to divider and centre their contents on themselves.

30. The background image should be behind the block selection area as well (check screenshots). For clarification, the island containing the blocks to select, alongside resets, stamina, and the weekly goals and stats should be over the image of the location (which should have the orange border)
   DONE — The location art now fills the whole orange-bordered panel, and the cream island of goals, stats, status and blocks sits over its lower half rather than below it.

31. Add rerolls to the dev panel, and have the player start with 50 in every run (would like this to be global like cookies later on)
   DONE — The dev panel's State tab edits Refresh tickets and Cookies alongside the other vitals, and refresh.initial is 50 in both the pack and tools/build_pack.py. Noted there that both are account-level in the original and only start-of-run here until account progression exists.

32. add the option to leave the game whenever to dev panel
   DONE — The dev panel's State tab has Leave to main menu, which saves first when the run has a slot. Unlike the in-game drawer it does not care whether the day is over.

33. Player progress should be saved at the start of every day (after navy screen)
   DONE — Each day is written as it begins, once the night screen is acknowledged, and the first day of a run is written when it reaches the hub. A run with no slot (a dev-panel run) has nowhere to write and is skipped.

35. Item roulette needs to shuffle faster
   DONE — The draw's roll interval is 45ms instead of 110ms.

37. Quizmaster quizzes are broken, showing the question variable and incorrect and correct answer variables instead of a question and answers. Quizmaster does not give an item like she should after getting the correct answer
   1R — {문제}/{정답}/{오답} are filled from the shipped question bank (global school_exam_problems.json, 68 English questions): the question is drawn when the choice appears, each {오답} is a different wrong answer, a three-option question drops its spare button, and the options are shuffled so the answer is not always first. The correct answer reaches the prize node (ACQUIRE_ITEM_RANDOM), and the receipt shows it. Retry Year's Banjang's Quiz uses the same macros; its {MATH_*}/{ENGLISH_*} quizzes draw that bank's maths/English questions as a stand-in for the native generator. Also implemented {이벤트스위치(X)}, {과목(n)}, {GOLD_SUBJECT}, {ENTERED_UNIV_NAME}/{ENTERED_DEPART_NAME}, {NAME_TRAITS_IN_LIST(…)}, {GET_ITEM_OF_SWITCH(…)}, the recipe {IS_ALREADY_*} markers and the Scouter's {IS_SING_WIN} forecast.
   2R - The dedicated Quizmaster bank is still unrecovered: the current 68-question school bank is an explicit English fallback. Macro rendering and prize delivery work; original bank fidelity remains open.
   DONE — Checked for a dedicated bank: school_exam_problems.json is the only question data in either install (English asset pack, base APK, and the Korean device's own runtime cache, which holds a copy of exactly this file), and the native's quiz macros ({문제}/{정답}/{오답}, regexes in class gC) have no other data behind them. So the 68-question bank is the original source, not a fallback; Retry Year's {MATH_*}/{ENGLISH_*} generator remains the only stand-in.

38. The part-time level up event does not play when part time levels up
   DONE — Imported the original English global event 10000003 and trigger it when a block raises the part-time level, before ordinary events/exhaustion/night recap. Its level macro resolves and its completion clears PART_TIME_JOB_LEVEL_UP. Regression covers repeated levels and simultaneous exhaustion.

40. Save every run, saving complete runs in a separate menu (Records), and incomplete runs under a Play button. Ask for pictures of the home screen UI before doing this. Note that there will be no leaderboard, and achievements will empty for a while
   NOTE — References now exist: docs/MAIN-MENU-REFERENCE.md with screenshots in references/, and docs/ORIGINAL-GAME-FUNCTIONS.md. Applies to 41 too.
   Reference update (2026-10-24): Home/History/Select Game pictures received in the main-menu collection (26 initial images plus the protection-mode follow-up). Archived originals and per-screen specifications: docs/MAIN-MENU-REFERENCE.md. The picture prerequisite is met; implementation is still open. Some interaction questions remain pending.
   DONE — Home (MM-01) replaces the old three-slot title screen: desk wallpaper under the paper blocks, the right-edge stack Traits / Puzzles / Records / Missions / Achievements / Start with no Rank, the gear (Settings), the cookie / refresh-token pill (both 0: nothing earns them yet) and the four-arrow background view (tap anywhere to return). Start opens Select Game (MM-26): a plus tile, then one card per unfinished run (portrait, D-n, name, campaign, five-stat total, red trash), with no save limit; every run is saved from its first day. A finished run is recorded and its save deleted, so it shows under Records → History (MM-09: two-column cards with portrait, name, campaign, ending, orange trash; tapping a card shows its stats, CSAT and enrollment). Traits, Puzzles, Missions and Achievements open empty pages for now. Mail, the seasonal badge, Charging, Store and Notices are left out: their destinations were never captured.
   DONE (subtabs) — Traits: Manage Traits with mileage, Standard / Endless Winter / The Year I Retook packs (recovered per-card odds and card counts; only Standard 15/10 and Jumbo 20/20 prices are recovered, the rest are placeholders), buy/open, wrapper → tap-to-stop roulette → results with arrows, index, brown/gray/gold confetti, Exit / Draw More; Chances Info; My Traits; Traits Database by rank with owned counts; Combine with three slots, S-only-with-S, combine-lock mode (padlock) and a tier-confetti reveal whose Confirm fades in after 0.5s. Combine results are PROVISIONAL (highest input rank, 25% one higher): Combine Rates was never recovered. Puzzles: category banners, collections, detail with weighted progress and Complete Now (prices recovered from piece cookies); game-count pieces are provisional (one per finished run) and Insta-draw is not built. Achievements: University (regions, stars, crests, own enrollment counts), Campaign (installed campaigns, Endings List) and Other, with the All/Incomplete/Complete filter. Missions opens Daily Quests (a dated department, 4 cookies). Cookies come from first-time endings, Story Addict and the quest. The account trait collection does not gate setup yet.

41. Add the ability to modify the colleges in the game by adding a colleges.json to packs, and create a variation where all of the colleges (minus Basakan and special universities) with US universities. Would like Purdue in a prominent position. Make this a toggle in settings between Korean and US universities. Make sure there are no duplicates with global univerities (which shouldn't be changed for this). These (40-41) should probably be done after adding the main menu
   DONE — The catalog is now colleges.json in each pack (edit it to change the colleges; packs that still have admissions.json load it). colleges_us.json renames all 51 regular Korean universities to US ones, keeping departments, cutoffs and ids, in the original's selectivity order. Purdue is a top-level college: North Chungcheong University's rank-eight slot (aerospace, agriculture, robotics); Harvard takes the top slot; the arts/sports schools get US schools known for the same (USC for film, Juilliard for music, Cornell for food, ...). Basakan, the other story-only universities and the global set are untouched, and the builder fails on any US name echoing a global one (no Stanford, no Oakland). Settings → Universities switches Korean/US; badges follow, and a run keeps the set it started with. Event text that names a Korean university by name is not rewritten.

42. Add a new button to the gamemode selection area (hide elite mode button for now) for each pack in packs, named after the pack name and colored randomly. Add scrolling (but keeping the header) when the packs don't fit on screen. Keep the original d31, and translated DLC at the top.
   1R — Campaign buttons now derive from bundled manifests and desktop packs, with 31-Day Mode first and stable per-pack colors. The list scrolls beneath the fixed header. Retry Year is the second bundled campaign; no other DLC packs have been generated yet.
   DONE — Complete as described: one button per bundled or desktop pack, 31-Day Mode first and Retry Year (the translated DLC) second, stable colours, scrolling under the fixed header, Elite Mode hidden.

16RESPONSE. This seems to be an issue with just events where the friend is speaking. There are multiple people called friend, and after one message in the event they all seem to become the friend with glasses (screenshots in reference labeled 16R1 and 16R2)

43. Button pressing should be animated, there should be a transition between unpressed and pressed
   DONE — The press now travels over 70ms with an ease-out instead of snapping. Short enough that releasing over a block still reads as simultaneous with the hand being dealt again.

44. It appears that the character icon now is behind the block selection section and only the tip of their head is visible
   DONE — Follow-up Nord capture exposed a floating torso after the first fix. The portrait now shifts down 76 logical pixels, tucking its bottom behind the island; rendered with both Default Boy and Retaking Boy. Layout regression covers 320x740 and 393x873.

45. Curve the bottom two corners of each stationery icon when in the larger menu (it's cutting off the black border)
   DONE — Already fixed by the stationery border rework (a real 2px inset with 9px outer / 7px inner clipping); verified by rendering the large-menu grid — the bottom corners are rounded and the black border is intact.
   REOPENED (user, 2026-10-24) — The border cutoff is still visible on the Nord, so the DONE above was wrong: my check rendered the cards in a test harness, not the device's larger menu. Still open.
   2R — StationeryCard now paints its outline as a foreground layer and the hub's empty slots (_EmptyStationerySlot) clip their contents; renders at 393x873 show intact borders. Awaiting confirmation on the Nord before DONE.
   DONE (user, 2026-10-25) - Confirmed fixed on the Nord.

46. Make the opened Schedule/Calendar menu a bit wider and also standardize a name
   DONE — Calendar is now the name on both the hub button and dialog; its horizontal inset is 20px instead of 40px. Existing panel regressions verify the wider window at 320px and 393px.

47. Rerolling an object should always ensure that it rerolls to the average (rounded up) tier (B and C always makes B or very rarely A, A and C always makes A or very rarely S, etc) Check psuedocode for absolute answer
   DONE - User confirmed A+C -> A: combining preserves the highest input tier for 2-4 copies, with an editable provisional 5% one-tier upgrade chance (S stays S). Original probability branch remains unresolved; see docs/STATIONERY.md. Mixed-tier, duplicate-copy and inventory checks covered.

49. Exam day should start by playing the Graduation Exam event
   DONE — Exam day has no blocks: starting the day plays the Graduation Exam (story 16's 35, Retry Year's 74), whose last line is START_SAT. That opens the CSAT screen (report card, up to three applications, admission results, enrollment); enrolling raises ENDING_CODE and the endings play in turn until one ends the run. Applies to both campaigns. The original's admission screens were never captured, so that layout is our own, and the CSAT score is a fitted model (rules.exam) rather than recovered.

50. Retry Year event ordering remains incorrect (user follow-up).
   1R - Reviewed korstu4 and korstu4CLAUDE references; no authoritative overall placement rule recovered. Logged source evidence and unverified same-tick/priority/ID assumptions in docs/RETRY-YEAR-EVENT-ORDER.md. No further guessed reordering; moved to TODO 47 as requested.
   2R — Much of what looked like bad ordering was events not firing at all: the daylight-saving bug (every DATE_ event after 3 Nov dead on a US-timezone phone), the friend-trouble blocks never appearing (their gates are compiled and are now recovered), and exam day ending the run before the Graduation Exam. With those fixed the scheduler itself is unchanged: pinned events still go by priority then id, which remains unverified against the native dispatcher.
   DONE — Checked the remaining ordering data: in Retry Year every event's authored index equals its id (all 218), every priority is middle and every customPriority is 0, so our pinned-event order (priority, then id) is exactly the authored list order — there is no hidden ordering field left unused. Together with 2R's fixes (date events after 3 Nov, friend blocks, exam day, and since then the native block gates and continueTargetSwitch chaining), the known causes are addressed. If a specific scene still plays out of order on the Nord, note the two scenes and I'll trace that pair.

51. Raise Ji Suin and Mom in events and investigate missing Nice to Meet You item.
   DONE - Both event portraits raised 24 logical pixels. Existing Nord save confirms item 80042 was granted; added persistent event reward receipts with actual gained counts and recovered story-item icons. Regression checks the reward, save, bag and portrait placement. The later item-mechanics update under 60 implements the persistent proficiency check.

52. Recover Banjang Na's portrait, animate stamina changes, and set combination upgrades to 5% unless original code establishes otherwise.
   DONE - Recovered all six original NPC 7 portrait layers. Stamina fill and percentage ease together over 300ms and smoothly retarget on rapid changes; reduced-motion mode updates immediately. Both campaign rules and the engine default use 5%; original combination probability remains unresolved in the pseudocode. The best-input tier guarantee remains.

53. Retroactively change button presses from shrinking to lowering the light face into its bottom shadow.
   DONE - Removed scaling from shared PressFeedback. Raised confirm and start controls travel the full 6px lower-face depth and retain a 2px outline; HUD buttons use a fixed 3px lower face. Moved nine inner feedback wrappers around the full painted face so icons/text do not move independently. Existing action-block depth animation retained. Checks cover unchanged painted width/height, a stationary lower face, travel, cancel/disabled handling and single clicks.

54. In events, every portrait can be moved further up (torsos are hidden behind event text). This applies to all portraits, including Mum and Ji Suin, who can go further up than the 24px raise from 51.
   DONE — Every event portrait now stands 40 logical pixels higher (EventScreen.portraitLift), and Mum and Ji Suin keep their extra 24 on top, so they sit 64 higher than before. Tuned blind; send a Nord capture if it needs another nudge.

55. Hidden speakers and missing names should show as unknown
   DONE — A speaker with isHideSpeakerName shows ??? on a dark grey nameplate in dialogue and the log; narration with no person keeps its unnamed presentation, and a later ordinary line shows the authored name. Person IDs with a missing or empty name also show ???. See docs/RETRY-FOLLOWUP.md.

56. Recover Jian Lee's portraits
   DONE — Jian Lee has two actor IDs, 9 and 27; all 16 body, expression and outfit layers for both were recovered from their source URLs (presentation_assets.py --story 20 --fetch-npc 9 --fetch-npc 27).

57. Level-up scenes after event or item XP
   DONE — Workout and part-time levels gained from event changers or items now set their level-up switches, and the global level-up scene plays after the story closes without spending an action or using the random-event budget. Action-driven level-ups still play once.

58. Retry Year tick-12 Hurry! / Roll Call! never fired
   DONE — FUNC_ROUGH_TODO_DAY returned days until the CSAT instead of the native same-day task check (Korean binary, 0xae1a74), so Roll Call never passed its gate. It now returns 1 only for an active task due today. The first trip back to the dorm is compulsory, later nights offer the choice, and a second miss confines the player with a next-day tick-14 release task. Evidence: docs/RETRY-FOLLOWUP.md and local references/recovery/RETRY-ROLL-CALL-NATIVE.md. The overall scheduler (50) is still unresolved.

59. Import every image from the base game and Retry Year (story 20) as temporary assets
   DONE — tools/import_all_images.py mirrors 2,274 images into assets/images/kss/<original path>: 2,020 shipped in the base APK and asset pack (all stories) and 254 streamed story 16/20 files downloaded from their source URLs. It regenerates the pubspec asset block (35 directories). Rebuilding presentation for both packs cut Retry Year's missing art from 142 files to 15. Four story 16 backgrounds remain unavailable (three have no URL, one returns 404); see build/import-all-images-report.json. The debug APK is now ~445 MB.

60. Special item functions don't seem to exist, like exam proficiency checker (given by lower class teacher) should list my exam proficiency (measured by the amount and quality of notes i've recieved from mock tests/friends/karaoke championship), and give itself back to me/be a persistent item so I can continue checking.
   DONE — Proficiency is EXAM_POINT, and the native confirms it is raised only by items: the mock-exam guides (+5/+10/+20%), each friend's promotion notes (+10%) and the Teacher's Notes from the karaoke championship (+20%). Using one adds its amount; the Promotion Exam Kit shows "Promotion Exam proficiency: N%" and stays in the bag (the native hands it back). 90% is what the promotion results ask for.

60. Have the event fast-forward button stop on the last message, instead of closing the event
   DONE — Fast-forward stops on the last line instead of closing the scene; the player closes it. Regression test opens a scene as a route and checks it is still there after fast-forwarding past the end.

61. Stamina bar is cutting off the corners of the stamina bar's border, please fix (same issue as stationery)
   DONE — The outline is now painted over the fill (foregroundDecoration) instead of under it, so the fill's square ends no longer cover the inside of the rounded corners.

62. Jailbreaker trait is active even when the player does not have the trait. This may happen with other traits too, if usage is plentiful then do a complete sweep of traits that rely on an event and ensure they aren't activated without the prerequisite trait
   DONE — The trait itself never fired: the engine skipped the gated +40 but still showed its line. A node whose condition fails now shows its elseText, or is skipped entirely when it has none. Swept both campaigns: 12 gated lines in Retry Year (7 trait announcements — Jailbreaker, cooking master and others — plus manga and confinement lines) and 22 in story 16 (the rival who was announcing every subject at once now picks one). No content keys off TRAIT_EVENT_ switches, and trait predicates read only held traits.

63. When looking at a trait's description in game by clicking on the trait in the trait menu, the Confirm button's top border grows when the button is held on, when it should stay the same size as before (see other buttons with the "shadow" in the game)
   DONE — Every D30RaisedButton (this Confirm included) was 48px tall for the touch target while its painted face was smaller, so the lower face read 10px instead of 6 and a held button uncovered it above the face. The button is now exactly its face (shrinkWrap tap target): held, it sinks into the lower face with no band above. Rendered before/after.

64. El Nino/La Nina icon does not show up. Please ensure that characters show up when they're speaking in the event
   DONE — Their portraits were among the art never downloaded; TODO 59's import fetched them and every Retry Year NPC now has all its layers on disk. Their nameplates also read "Niño El"/"Niña La" (first-then-last); the dialogue calls them El Niño and La Niña, so the pack now does too. The dev panel's Character showcase plays every NPC speaking in each expression for checking.

65. Add a gender selection to Retry Year initialization. Male means female ji suin, female lee jian, etc, while female means male lee jian, male ji suin.
   DONE — Retry Year ships a separate female-protagonist script (events_female.json, fully translated). The name step now has Male / Female (defaulting to the chosen character): Male plays the usual script with female Ji Suin and Jian Lee; Female plays the female script, where Jian, Suin and Inmul are their male actors. Saves reload into the right script.

66. In the calendar, the player should only see events that they found out about through events (i.e. Friendly Challenge with Taeyand), or major events like Mock Exams and the CSAT. Other events should not be laid out
   DONE — The Calendar is now the to-do list, as the original's is: the story's fixed dates from todos.json (story 16: the CSAT; Retry Year: mock exams #31–33, the Promotion Exam and the CSAT) plus what events tell the player through ADD_TODO / ADD_TODO_2 (the National Cooking Contest, Taeyang's challenge, a match with the pros, …). Other pinned events no longer appear. This also switched on story 16's task list, which its content already reads (FUNC_TODO_DAY(id) == 1 "due tomorrow" ten times) and which had been falling back to days-left-in-the-run; three-argument ADD_TODO_2 calls (no tick) now register, and day-only tasks last through their day.

67. Change the recieved item popup to match the screenshot in references
   DONE — Items an event hands over now appear one at a time in the reference's acquisition popup over the scene — artwork, "Got a X!", description, effect, Use (consumables) above Confirm — instead of the receipt strip. It is the same shared popup the store uses; Use applies the item there and then (and shows a report, e.g. the Promotion Exam Kit's proficiency). Fast-forward pauses for it.

68. When a play ending function is called, the screen should look like the provided screenshot for about three seconds before continuing/playing the next event.
   DONE — SHOW_ENDING (Retry Year's opening "Retake Ending") and END_GAME's ending name now show the title alone on black, as in "ending example.jpg", for three seconds before the scene continues; a tap skips it.

69. In the main play screen, it looks like the player character can be shifted up slightly, about the same shift as the event characters should do. For some characters, it looks like they are smaller than the others, would like a size up to match the scale in the reference screenshots (smaller characters noticed with Teacher)
   DONE — Compared a render at the reference's size (393×851 dp) with capture 17: our portrait was ~11% small and its head ~41px low. It is now scaled 1.12× from its bottom edge (which lifts the head ~36px) and raised a further 6px, matching the reference. Every character shares one 744×893 canvas, so this lifts the Teacher and the other small-reading ones by the same proportion.

70. Beginner books give inflated stats with no traits or college badges.
   NOTE — Lower CSAT scores from the 3x study baseline are intended (user): traits, college badges and strategies such as Kang Hyoeun's Strange Cookies are meant to carry a run. Do not recalibrate the exam to compensate.
   DONE - Removed the unrecovered Retry Year studyWeight=9 override. Both campaigns again use 3: a power-5 entry-tier book previews and grants +15 instead of +45 with no modifiers. Generator and editable phone pack corrected; regression covers actual grants as well as previews. The fix affects future gains; existing accumulated stats are retained. Native exam thresholds are preserved; exam progression tuning remains separate.

71. Study efficiency must add one stat per boost unit (Genius of the Century +3, not +9).
   DONE - Corrected the shared trait/badge efficiency reader and setup labels to prefer storyStat units. Removed the threefold NORMAL_STAT passive-item conversion; consumable stat grants are unchanged. Genius of the Century previews and grants +3 (starter book +15 -> +18) in both campaigns. All 114 engine/campaign/setup tests pass, including 200 seeded runs; analysis clean. Hardware-profile APK and both corrected item files installed on Nord and hashes verified; saves retained. See docs/CURRENT-STATE.md.

72. (Follows 65.) Move the gender selection to Select Character (2 / 5) — preferably its own page with the gender recommended by the selected character highlighted — and make it a per-pack toggle so pack authors can enable or disable it. With the switch on, a character with two gendered forms becomes the opposite gender of the protagonist.
   DONE — rules.setup.genderSelection is a switch in every pack (off in 31-Day Mode, on in Retry Year). With it on, Select on the character carousel opens a "Select Gender" page under the same Select Character (2 / 5) header, laid out from the reference capture: "The selected character's gender is X. We recommend you to select X!", then Play as male / Play as female cards with the recommended one bright and the other muted; a card chooses and moves to 3 / 5, back returns to the carousel. The name step no longer has the choice. rules.setup.genderPairs lists two-form NPCs ({forMale, forFemale}); Retry Year pairs Jian Lee 9/27, Ji Suin 3/32 and Inmul Ko 8/28, so they always appear as the opposite gender of the protagonist, on top of Retry Year's own female script.
   Item text vs. effect (failing test): store text now matches the reference screenshots (Book Stand "Study Efficiency for All Subjects +3", NORMAL_STAT x3 as displayed), while passive items grant one stat per authored unit (+1), per the playtest. Consumables keep x3 in both.

73. Select Gender page does not appear (the protagonist's gender follows the character's recommended gender instead). Fix the Select Character (2 / 5) flow so the page shows. (Follows 72.)
   DONE — Not a UI bug: on Android the first launch copies the bundled pack to editable storage, and every later launch loaded that copy, so no APK update since then had reached the phone's pack data (the gender switch, character events, admissions catalog, quiz bank and female script included). The loader now records a stamp of the bundled files beside the copy and re-seeds it whenever the bundled pack changes; the repo's packs/ folder still wins on desktop. Dev-panel edits to the phone's copy are replaced on the next update.

75. "Got a X!" popup: the Use and Confirm buttons overlap slightly. Shift Use up and shrink its shadow a bit (and the press animation with it).
   DONE — Use and Confirm in the acquisition popup now have a shallower 3px lower face (with matching 3px press travel) and 10px between them, so they no longer touch. D30RaisedButton takes the depth as a parameter.

76. Capitalize "Proficiency" in the Promotion Exam Kit's reading.
   DONE — The kit now reads "Promotion Exam Proficiency: N%".

77. Remove the shadows and press animation from item-based buttons.
   DONE — The item report's Confirm is flat (no lower face, no press motion: D30RaisedButton(flat: true)), as is the bag's Use. The acquisition popup's buttons follow 75 instead.

79. Add a fade in transition for the info menu
   DONE — My Info fades in (showFadeDialog, 250ms; instant with reduced motion). See "Interrupted branches integrated — 2026-10-25" below.

80. In the top left hamburger menu, "Main Menu" instead shows "Main M..." when there is plenty of space for the full title
   DONE — The label now takes its full width and the "day is over" explanation wraps beside it; it was squeezed to a third of the row.

91. Home's four-arrow (show background) button: fade the rest of the menu out, and back in on the tap that restores it, instead of switching with no transition.
   DONE — Home fades its menu out and back in around the four-arrow background view. See "Interrupted branches integrated — 2026-10-25" below.

92. Events should still play during exhaustion's automatic tick progression. When the player is exhausted and ticks advance without user input, check and play eligible events at those ticks instead of skipping them. Verify this in both campaigns, including ticks leading up to day rollover.
   DONE — Exhaustion checks eligible events at each skipped tick in both campaigns. See "Interrupted branches integrated — 2026-10-25" below.

93. The banners in the main menu's submenus are all broken (Puzzles category banners and other submenu banner art).
   DONE — The shared submenu header was shrinking to its title; it now spans the page. Banner art itself was intact. See "Interrupted branches integrated — 2026-10-25" below.

94. Achievements should be a full-page submenu like the other Home menus (Records, Puzzles, Select Game), not the current sheet over Home.
   DONE — Achievements is a full Home page (AchievementsPage). See "Interrupted branches integrated — 2026-10-25" below.

95. In Select Game, ongoing games character icons look squished. Check portrait aspect ratio/cropping against MM-26 at the Nord phone size; preserve the character proportions.
   DONE (user, 2026-10-25) - Confirmed fixed on the Nord: image decoding preserves the source aspect ratio before cropping.

96. **DONE — modular pack mechanics.** Custom trait/character abilities, special
blocks, predicates, callbacks and text macros are pack-owned. Independent
workshop example proves isolation, persistent block unlock/removal and custom
action payouts. Both KSS packs regenerate; clean analysis, 323-test full suite
plus four additional custom regressions. See
[MODULAR-PACKS.md](docs/MODULAR-PACKS.md) for authoring and supported primitives.

98. Correct the Global and Taiwan school names.
   DONE — Shared tracked name overlay corrects 80 account/badge labels in both campaigns, preserving IDs and mechanics. See docs/UNIVERSITY-NAMES.md for sources and the explicitly inferred Bombay counterpart.

101. Beggar event is broken, even with enough gold he will claim you are broke
   DONE — Root cause: the Beggar's branch checks MONEY < 500, but MONEY was an unset content switch that always read 0. GameState.switchValue now maps MONEY to the wallet (and events cannot overwrite it); this also fixes the other MONEY conditions in both campaigns.

104. Should be able to click anywhere on the screen to open the envelopes
   DONE — A tap anywhere on the idle envelope stack opens the active envelope; Browse and fast-forward keep their own taps; a second tap while opening is ignored.

105. Remove the confirm button from the college decisions system, just have it go straight to showing the final decision button
   DONE — The combined-results page has no aggregate Confirm; it settles straight into the Final Decision layout and calls confirmResults() once (resume-safe). Per-envelope Confirms are unchanged.

107. character icons from the retry year pack do not appear to show up in Records
   DONE — Root cause: tools/copy_assets.py copied portraits only for kss16's roster, so the 20 Retry Year portraits never existed in assets/images/characters. The script now covers every pack (the 20 missing files were copied without overwriting anything), and Records/Select Game fall back to the generic portrait when a file is missing.

108. Add a Teaching Physics major to Ball State University
   DONE — Ball State University (US set, both campaigns) offers Teaching Physics (id 118022, cutoff 52.5, matching its sports major) via `US_DEPARTMENTS` in tools/us_colleges.py; the Korean set is unchanged. Covered by test/colleges_test.dart.

109. For the college ID picture, have the seal in the background not be cutoff prematurely (have it be cutoff by the edges of the card and the title of the ID, but it currently cuts off a few pixels above and beloe)
   DONE — The Student ID crest watermark now runs to the card edge and under the title band, clipped only by the card border and the title.

111. The refresh token button (to use one) shouldn't move down when pressed.
   DONE — The in-game Refresh control uses PressFeedback(travel: 0): it no longer moves down when pressed; the ink ripple still shows the press.

## Finished parity-audit items (entries 81-87)

Each parent entry's heading and notes are kept for context; its open sub-items are in TODO.md.

81. Fix demonstrated engine and progression defects.
   - [x] A01: FUNC_IS_IN_CHARACTER_LIST returns constant 0 (conditions.dart), blocking active Retry Year checks including character 66's Weird Cookie and character 58 branches. Matching character 66 / argument 66 returned 0 in a probe.
   - [x] A02: Books UI exposes one book per rank while progression checks all variants (pack_menus.dart / game.dart). After completing 1 and 1001, rank-three 2001 can appear unlocked while actual availability remains 1, 1001, 1002. Use one prerequisite model.
   - [x] A03: Level-8 Suit 3028 contributes its passive below level 8 (state.dart held-passive sum); level-zero starter gain became 18 instead of 15. Apply passive conditions.
   - [x] A04: High Potential 160011 (+5) and Entrepreneur 160007 (+2) grant +15/+6 because zero storyStat falls back to NORMAL_STAT conversion (traits.dart). Audit this fallback separately from fixed Genius of the Century (71).
   - [x] A05: Academic Potion 35 parses as Humanities +2 / Science +0 instead of +2 to both (item-effect parser). Correct multi-subject parsing and regenerate affected data. Follows 78.
   - [x] A06: Shop purchases bypass maxCount: Book Stand 3005 goes from owned 1 to 2 despite cap 1 (game.dart purchase path). Follows 78.
   - [x] A07: Event/item stat gains do not update Weekly Goal completion until the action-only check runs: target 398 / current 1050 can remain met=false. Check every relevant stat mutation.
   - [x] A08: Weekly Goal reward bonuses apply retroactively: buying Study Planner 3001 midweek changes the existing reward 258 -> 271. Respect authored next-week activation and snapshot eligible modifiers.
   - [x] A09: Final partial-week goal lacks settlement before CSAT; current payout happens only Monday. V02 now shows an original mid-day Weekly Goals Met/Confirm reward flow. Implement the evidenced settlement behavior and verify final-week boundary handling rather than assuming all rewards wait for Monday.
   - [x] A11: Story 16 evening rollover occurs before dialogue finishes, changing date, stamina and trait age under the scene. Deferred evening rollover currently applies only to Retry Year.
   - [x] A12: Scouter predicts loss for character 67 although sing-off resolution guarantees a win (event_text.dart versus conditions.dart). Share resolution rules.
   - A13 WITHDRAWN as a parity bug (user confirmation, evening 2026-10-24): inventory XP does NOT show the level-up event in the original. Do not add that scene on inventory close. Verify levels/EXP update and suppressed notifications do not leak into later unrelated scenes; event-granted XP is a separate rule.
   - [x] A14: ADD_BLOCK handler is empty (effects.dart). Story 16 nodes 48012/48022 announce Practice Block but only their IDOL switch changes. Implement authored block insertion/consumption.
   - [x] A15: Scorecard menu always shows literal 'No ScoreCard yet!' (day_menu.dart); retain/display actual exam results and history.

82. Implement missing compiled trait callbacks (follows 48/78).
   Each line is independently open. Recover unresolved rates/conditions rather
   than inventing them; descriptions/data alone do not execute an effect.
   NOTE: Cooking Master 221, Ginseng Digger 200, Jailbreaker 214 and Delinquent
   216 have inline event-graph effects; missing compiled callbacks alone do not
   make those effects absent.
   - [x] T02: Time Jumper 69: 10% chance of no stamina cost.
   - [x] T03: Stubborn 41 / I will not falter! 51: their distinct chances to remain at 1 stamina instead of collapsing.
   - [x] T07: Solitary Gourmet 21: food discount.
   - [x] T08: Limited Offer 34: 50% discount for its three-day window.
   - [x] T09: Developer 43: doubled coffee recovery.
   - [x] T10: Walking Enthusiast 77: 50% chance of +20 stamina on movement.
   - [x] T11: Multitasker 49: random-subject +1 when studying.
   - [x] T13: Energizer 84: daily no-cost proc and reset rule.
   - [x] T16: Street Performer 210: 600 Gold singing reward.

83. Finish item/book behavior (follows 78/3).
   - [x] I01: Pet Rock 30207's parsed surviveExhaustion effect is unused by collapse handling.
   - [x] I03: Hiking Gloves 90009's 20% extra-gather effect has no runtime implementation.

84. Re-audit main-menu/account parity after Claude's current integration (40/41).
   Integrated on main: see docs/BRANCH-INTEGRATION-2026-10-25.md for the
   assignment audit, finished behavior and remaining evidence gaps.
   WITHDRAWN FINDING: cross-run stationery carryover. Stationery is new each
   run; preserve it only when resuming that same run. Account currencies and
   trait/puzzle collections have different lifetimes.
   - [x] M02: Old hardcoded three-save limit versus reference with at least five resumable runs; real portrait, D-count, mode and five-subject stat sum, add/delete ordering and capacity.
     DONE (Claude, 2026-10-24) — Unlimited saves; Select Game cards show portrait, D-n, name, mode and the five-subject sum; newest first; trash deletes after a confirm (40).
   - [x] M03: Automatic completed-run persistence: old ending path saved only before completion. Separate History from resumable Play; verify ending transition, reopening/relaunch and deletion.
     DONE (Claude, 2026-10-24) — A finished run is recorded and its save deleted at the end transition; History lists records, a card shows stats/CSAT/enrollment, trash deletes (40).
   - [x] M04: Account cookies/refresh tokens instead of separate run wallets; shared transactions, persistence and migration. Starting balances are not screenshot examples 53/522.
     1R (Claude) — Account wallet exists (cookies/refresh tokens on Home, persisted, earned from endings/achievements/quests). Still separate from the in-run cookie/refresh counters; unifying them is open.
     DONE (2026-10-25) — Runs spend and earn from the account wallet. Both cookies and refresh tickets are shared in both packs (user decision: one-time grants of 20 cookies and 50 refresh tickets). Nothing earns refresh tickets yet: TODO 97.
   - [x] M06: Discovered endings and authored cookie rewards, including first-time/repeat rules.
     DONE (Claude) — Endings reached are kept per account; first-time reach pays the ending's catalog cookies; Endings List shows cookie or check. Repeat rules beyond 'pay once' are not established.
   - [x] M07: Trait-pack stock, purchase/open, mileage guarantee/reset, tap-stopped one-card roulette, result browsing and optional Draw More. User confirms mileage resets after ANY S-tier draw. All 12 pack rate tables recovered from the supplied public Notion page; see docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md (per-card rates differ from pack-wide cumulative rates).
     DONE (Claude) — Recovered per-card odds and card counts for all 12 packs, 1000-mileage S guarantee, reset on any S, buy/open, tap-stopped roulette, result browsing, Draw More. Prices other than Standard/Jumbo are placeholders.
   - [x] M09: Exactly-three-input trait combining, pool filters, protected copies and protection-editing mode. Protection persists after restart; selecting a protected card shows the supplied warning (F20). No combine roulette; tier-colored confetti and Confirm fading in after 0.5 seconds are confirmed.
     DONE (Claude) — Three inputs, S only with S, protection mode with per-copy locks (persisted with the account), warnings, tier confetti, Confirm after 0.5s. Combine result odds are provisional (rates unrecovered).
   - [x] M10: Puzzle pieces, conditions, weighted progress/cost, purchases, complete backgrounds and selection; match supplied locked/partial/complete states.
     DONE (Claude) — Pieces from endings/story ownership/runs, cookie-weighted progress and Complete Now price, locked/partial/complete art. Only the Amnesia desk has full-screen background art; Insta-draw not built; game-count thresholds provisional.
   - [x] M11: Home Daily Quests: progress, reset, Receive states, claim persistence and rewards.
     DONE (Claude) — Dated quest (one department), local-midnight reset, Receive enabled once completed by a run finished that day, claim persisted, 4 cookies.
   - [x] M12: Korean/US university toggle and Purdue setting (41) after main-menu integration.
     DONE (Claude) — Settings toggle, colleges_us.json from tools/us_colleges.csv (user-editable), seals as crests, Purdue a top-level college (41).

85. Other missing original functions, within agreed scope.
   - [x] F04: Stationery roulette/result confetti with the different tier colors; distinguish trait-pack mixed brown/gray/gold and combine's result-tier confetti.
- **F03** (audit 85): Effective Rumble/haptics with verified trigger points.
  DONE — Rumble drives HapticFeedback through lib/ui/haptics.dart, gated by the Settings toggle, at five reconstructed triggers (collapse, level-up, envelope reveal, stationery draw stop, trait-pack roulette stop) listed in docs/MAIN-MENU-REFERENCE.md.

86. Latent engine hazards to fix before dependent ports.
   - [x] L01: INCREASE_TAMGOO_STAT / DECREASE_TAMGOO_STAT affect all subjects; DECREASE_TAMGOO_HIGH_STAT picks global highest (effects.dart). Respect elective subset. Not exercised by current two main graphs.
   - [x] L02: EventEngine._buildEndBeat ignores gated final-node elseText and uses primary text. Synthetic probe reproduces; neither active main graph contains an affected last node.
   - [x] L03: submitApplications engine API accepts duplicate program IDs and can produce three acceptances for one program; UI filtering does not enforce the invariant.
     DONE (Claude, 2026-10-25) — submitApplications now refuses a second program at a university already applied to, which also refuses duplicate program ids.
   - [x] L04: Unknown trait conditions fail open (traits.dart). Explicitly handle unsupported gates before new catalogs depend on them; current global condition coverage is largely present.

87. Verify reconstructed rules before claiming original parity.
   These are evidence/model gaps, not all proven user-facing bugs.
   NOTE: Original shop generation and book condition/extraDoneCount gaps are
   I05/I04 above and belong to this same verification backlog.

## Historical status notes

Superseded checkpoints, kept for their evidence and decisions. They may describe older behavior.


### Current status - 2026-10-25

Historical checkpoint before entries 73 onward: **56 implemented entries,
15 open/partial, and one recurring reminder** (72 entries at that checkpoint).
This is not a current total or an original-game parity percentage. Later entries
and the audit below remain part of the backlog; this older summary can lag fixes.

**Current integration:** recoverable work from all five interrupted branches is
on main; 333 tests pass (re-verified 2026-10-25) and analysis is clean. Read
[CURRENT-STATE.md](docs/CURRENT-STATE.md) and
[the per-branch completion report](docs/BRANCH-INTEGRATION-2026-10-25.md).
A14 and I03 have since been implemented using the user's clarified persistent-block
and provisional scavenging rules; see docs/CLARIFIED-MECHANICS-2026-10-25.md. The older difficulty index is historical, not
an authoritative current open-item list. Preserve original worktrees as recovery
copies and do not overwrite newer main files with them.
**Stationery starts fresh every run.** Missing cross-run stationery ownership
is NOT a bug. Same-run inventory, equipment and pending draws must survive saves.

See entries 81-90 for the full parity audit and
[implementation evidence requests](docs/IMPLEMENTATION-EVIDENCE-REQUESTS.md)
for the remaining screenshots, recordings and rule details the user can supply.

| Status | Entries and important context |
|---|---|
| Regressions fixed | 19: software-rendered launches caused the whole-game low FPS. Hardware-rendered profile build installed and verified; user confirms it is much smoother. 70: starter-book gains restored from +45 to +15 without buffs. |
| Implemented prototype | Setup/save slots, inventory/stationery, portraits and unknown names, 100 stamina, global level-up scenes, dorm return/roll call, gender scripts, proficiency kit, character-event imports, exam/admissions/ending flow. |
| Partial | 4 setup/Elite/entitlements; 18 reference UI extras; 23 full Retry Year parity; 34 special blocks; 37 original Quizmaster bank; 42 more campaign packs; 48 full character abilities; 50 original event dispatcher. |
| Open / in progress | 36 random-event/set selection; 74 character organization; 78 items/shop; unresolved audit/evidence items 81-89. Home/account/college-toggle and 79/80 are integrated; broader original parity remains partial. See checked audit IDs and the current integration report. |
| Later completed UI fixes | 66 calendar discovery filtering; 67 acquisition popup; 68 ending title presentation; 69 gameplay portrait placement/scale; 72/73 gender flow and phone pack refresh; 75-77 item-popup/button refinements. See each entry for scope. |
| Recurring only | 39: remind about book-completion item gacha; do not implement it yet. |

Important: Claude's measured stationery name-fit cache remains intact (CLAUDE.md
section 5e). Compare performance in a hardware-rendered profile build; never
use --enable-software-rendering for normal play or FPS comparisons. Screenshot
workarounds must be temporary. Profile CPU/build and raster separately before
changing widgets. Exam scoring/admission odds and stationery upgrade odds are
prototype tuning; the dedicated Quizmaster bank and general scheduler remain
unrecovered. Recovered exam thresholds are unchanged by the book-gain fix, so
Retry Year's exam progression balance needs separate verification.

Latest completed combined review (2026-10-25): **333 tests passed** (school names, History snapshots and enrollment rewards), analysis
clean; the integrated profile APK is installed on the Nord. Current deployment,
artifact hash and evidence: [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md).
Historical 214/114-test checkpoints are retained in the archived state document.

### Original-game parity audit follow-up - 2026-10-24

Unchecked items are OPEN. Documentation alone does not complete a feature.
Baseline: docs/ORIGINAL-GAME-FUNCTIONS.md, original assets/pseudocode and the
preceding code audit. Separate demonstrated defects from missing features,
future-port hazards and unrecovered rules. Claude's concurrent Home/account
work must be reviewed before asserting those baseline gaps still exist.

### Difficulty index - 2026-10-25

Open work sorted by difficulty and complexity (Claude's classification; ids
refer to the entries above). Effort is a rough guide, not a commitment.

- Quick (minutes, clear spec): 79 info-menu fade; 91 four-arrow fade; 94
  Achievements as a full page; A01 FUNC_IS_IN_CHARACTER_LIST; A03 Suit level
  condition; A04 NORMAL_STAT fallback; A06 shop maxCount; A07 goal re-check
  after event/item gains; A12 Scouter vs sing-off rule; L02 end-beat elseText;
  F04 stationery tier confetti.
- Moderate (hours, clear spec): 45 stationery border (needs a Nord capture);
  93 broken submenu banners (needs a look at what is broken); A02 one book
  prerequisite model; A05 multi-subject item parsing; A08/A09 goal reward
  timing and final-week settlement; A11 story 16 deferred evening rollover;
  A14 ADD_BLOCK; A15 Score Card from the CSAT result; 92 events during
  exhaustion ticks; trait callbacks with clear text T02 T03 T07-T11 T13 T16;
  T04/T05 acceptance traits (decide with U05); I01 Pet Rock; I03 Hiking
  Gloves; L01 elective subjects; L04 unknown trait gates; M05/M08 account
  collections gating setup; F03 haptics; M01 Settings/Mail/Profile/Charging/
  Store screens now that captures exist.
- Large (days): 78 + I05 every item and original shop stock; F01 Surprise
  Missions; F02 BGM/SFX; F05 report-card/acceptance export; T01 Master of
  Notes workbook; I02 recipe screen; A10 story 16 hidden events; 48/F08 and
  34 compiled character abilities and crafting; 74 Retry Year characters
  (scope unclear - ask).
- Blocked on recovery or evidence: 36/U02 and 50/U01 event dispatcher; U03
  career eligibility; U04/U05 CSAT and acceptance semantics (formula bodies
  are compiled, unresolved closures); U06 weekly goals; U07 stationery odds;
  T06 T12 T14 T15; I04 book conditions; L05 L06; 37/U08 quiz generator;
  combine rates and non-Standard/Jumbo pack prices; M01 Notices and seasonal
  entry (no capture).
- Deferred or out of scope: 4/F06 Elite; 42/F07 other campaigns; 23 umbrella;
  88-90 process; 39 recurring reminder.

### Interrupted branch checkpoint — 2026-10-25 (superseded)

SUPERSEDED by "Interrupted branches integrated" below: everything this section lists as missing from main has since been integrated.


See [the branch audit](docs/INTERRUPTED-BRANCH-AUDIT-2026-10-25.md) before resuming: branch tips are merged, but b-flow/c-traits/d-ui/e-account retain uncommitted drafts. In particular A11, Walking Enthusiast, the empty stationery border refactor, and M01 account dialogs are not in main. Free first rename and TODO 92 remain incomplete. Earlier unchecked entries and the difficulty index have not been comprehensively reconciled with merged commits; do not use them alone to infer implementation state.


### Home implementation follow-up — 2026-10-25

M01 partial implementation: integrated and refined the e-account worktree's Settings, Mail Box, Profile/rename, Charging and Store screens. Home now has the captured envelope, username/info, Charging and Store entry points. Dialogs follow F01-F16; nested views retain the parent. Settings preferences persist, university/pack controls remain under expandable Game settings, balances read the account wallet, and trait-pack shortcuts open Manage Traits. First rename is free, subsequent renames cost nine cookies; the count persists and older custom usernames migrate as already renamed.

Fixed shared orange title bars shrinking around their labels in account overlays. Image decoding now preserves source aspect ratio, addressing the likely cause of TODO 95's squished ongoing-save portraits and distorted banner art; confirm those on the Nord. Existing 91 fade and 94 full-page Achievements preserved.

Remaining Home scope: real audio/haptics, mail delivery/claims, paid purchases/restoration, invitations/account services, Notices/seasonal entry (no destination evidence), History's detailed Info/Score Card/University Apps recreation, remaining puzzle full-screen art and provisional collection rules. Store/Charging purchases and external-service actions currently display an unavailable notice and make no transaction. Settings audio toggles persist preferences but playback is not implemented. Do not mark all of M01 DONE.


### Interrupted branches integrated — 2026-10-25

Current report: [branch assignments, completed work and blockers](docs/BRANCH-INTEGRATION-2026-10-25.md). This supersedes the draft-only checkpoint above. Main includes the verified b-flow/c-traits/d-ui drafts, completed Home/account work and new regression coverage. Original worktrees remain untouched as recovery copies.

- A11: DONE — evening scenes retain their evening date/stamina/trait ages; deferred rollover surfaces the following morning event.
- 92: DONE — exhaustion checks eligible events at each skipped action tick in both campaigns, including the first skipped tick; the normal evening event runs before rollover. Dialogue pauses progression. No lost-slot action rewards are granted.
- T10: DONE — Walking Enthusiast checks actual movement, once per tick, with a saved guard against free-movement farming. The once-per-tick limit is a prototype safeguard, not recovered native parity.
- T11: DONE — Multitasker's authored STAT_1 pays three stat points to its deterministic random subject on a Study block, consistent with the recorded STAT_ scaling rule; the card previews the bonus separately. The older '+1' shorthand above is one authored unit.
- T16: DONE — Street Performer grants 600 Gold on the Karaoke singing callback, respecting trait enablement and its location scope. Existing character singing pay still stacks.
- F04: DONE — weekly stationery draw and combination results use stationery tier colors (S rainbow, A gold, B blue, C gray); confetti does not block controls and is suppressed with reduced motion.
- A15: DONE for retained CSAT results — day-menu Score Card displays the saved per-subject scores and top percentages. Newly completed History records retain/open the same result. Old records containing only an overall score are not backfilled. Mock-exam per-subject results are not currently generated by the engine, so none are invented.
- 45: Added a final foreground outline to the real shared StationeryCard used by CommerceScreen, retaining its reserved inset and inner clip. Completed the interrupted clipped empty-slot widget too. Expanded grid and hub rendered at 393x873; borders remain intact. Confirm the original Nord complaint during playtesting.
- 79/91/93/94: Integrated — My Info fade, Home background fade, full-page Achievements, full-width headers and undistorted banner decoding remain present.
- M01: Captured local screens integrated. Real mail/purchases/ads/invitations remain unavailable by original assignment; Notices and seasonal entry lack destination references. The broader M01 stays partial.
- A14: OPEN, evidence-blocked — E32 explicitly lacks the granted block's insertion/expiry/consumption semantics. Native sub_bec688 still calls an unresolved closure; args [1] cannot safely be treated as either an ID or a quantity.
- I03: OPEN, evidence-blocked — Hiking Gloves states 20% for 'more items' while Collecting at the mountain. Native DO_GATHER establishes the GRASS_SW pulse, but neither its extra yield nor reward-selection semantics are recovered (E27). Do not guess a double grant, reroll or Gold Mine effect.

Previously integrated trait proc/discount defaults remain configurable reconstructions where original rates are unstated (Stubborn, I will not falter!, Energizer, Solitary Gourmet). Checked items mean the implementation exists, not that every original rate has been recovered.


### User clarifications implemented — 2026-10-25


Current evidence/rule record: [CLARIFIED-MECHANICS-2026-10-25.md](docs/CLARIFIED-MECHANICS-2026-10-25.md). This supersedes the A14/I03 blocker entries above.

- A14 DONE — authored Practice Block grants remain available until a later event removes them. The two shipped ADD_BLOCK [1] calls enable IDOL_BLOCK; existing authored removal clears it. Use, day rollover and save/resume do not consume the unlock. Existing daily duplicate restrictions remain.
- I03 DONE under the user's provisional choice — 20% chance of one extra copy of the exact herb scavenged. Ginseng Digger's ginseng outcome prevents the gloves bonus; ginseng takes priority if both seeded rolls would succeed. Both Retry Year gender scripts use the same overlay. The imported graph actually already had a gloves path (40%, another random herb); the earlier audit incorrectly called the mechanic absent from an empty item-effects list. This is a deliberate user-selected rule, not claimed recovered native parity.
- I05 / 78 1R — Saturday-start restock and saved shop rerolls: one cookie before any purchase; the first reroll reduces offers by one, later rerolls keep that count. Purchase locks rerolls until Saturday. Hidden offers cannot be bought through the engine API; Home/preparation previews use the current offers. The original larger offer pool, selection weights and full price/eligibility rules remain open; current rerolls sample the configured prototype catalog.
- T03/T13 evidence review — the user knows no exact rates or published help for Stubborn, I will not falter!, or Energizer. A read-only smaller-agent review of local pseudocode/catalogs did not recover attributable arithmetic. Keep 30%/70%/5% labeled provisional, with existing rules.traits.chances overrides; do not present them as original odds.

