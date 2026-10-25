For any agents reading this page: respond with progress or completion using 1R, 2R, 3R underneath the entry detailing what has been done if half complete, or writing DONE if complete

# Open TODOs

Reorganized 2026-10-25. Finished entries moved verbatim to [TODO-DONE.md](TODO-DONE.md), along with the
older status table, difficulty index and integration logs. Entry numbers and audit IDs are unchanged, so
references in other docs still resolve. Current implementation state: [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md).

Tiers are Claude's estimate of difficulty, sorted within each tier by estimated token cost for the whole task
(reading, implementing, testing and verifying), based on comparable tasks in this repo. Treat them as rough
guides. Quick: ~20-60k tokens. Moderate: ~60-200k. Large: ~200-600k. Very large: 600k+.

## Recurring

39. Don't do this, but remind me at the end of every finished prompt to add the item gatcha after finishing a book. Also remind me to add the shop refresh notification and reroll previews, and provide screenshots for both.

## Quick (~20-60k tokens each)

108. Add a Teaching Physics major to Ball State University
   *Estimate: ~20k. The D-Day handoff lists Ball State's Teaching Physics as an existing user choice; check whether the 137-university catalog rebuild dropped it.*
   DONE — Ball State University (US set, both campaigns) offers Teaching Physics (id 118022, cutoff 52.5, matching its sports major) via `US_DEPARTMENTS` in tools/us_colleges.py; the Korean set is unchanged. Covered by test/colleges_test.dart.

111. The refresh token button (to use one) shouldn't move down when pressed.
   *Estimate: ~20k. Press feedback on the in-game refresh control.*

110. The sort option in Achievements isn't filled in properly with orange.
   *Estimate: ~25k. Achievements sort/filter pill styling (lib/ui/achievements_page.dart).*

105. Remove the confirm button from the college decisions system, just have it go straight to showing the final decision button
   *Estimate: ~25k. Results flow only (lib/ui/dday_results.dart).*

104. Should be able to click anywhere on the screen to open the envelopes
   *Estimate: ~25k. Envelope stack tap target.*

109. For the college ID picture, have the seal in the background not be cutoff prematurely (have it be cutoff by the edges of the card and the title of the ID, but it currently cuts off a few pixels above and beloe)
   *Estimate: ~30k. StudentIdCard clipping in lib/ui/dday_widgets.dart.*

107. character icons from the retry year pack do not appear to show up in Records
   *Estimate: ~35k. Records/History portrait lookup for the kss20 pack.*

101. Beggar event is broken, even with enough gold he will claim you are broke
   *Estimate: ~50k. Debug the event condition against the gold check.*

- **F03** (audit 85): Effective Rumble/haptics with verified trigger points.
  *Estimate: ~50k. Trigger points would be reconstructed unless evidence turns up.*

## Moderate (~60-200k tokens each)

106. In records, the runs acceptance rates are not shown, and may not be recorded yet. Please have them shown.
   *Estimate: ~70k. Persist each application's displayed rate in the run record and show it.*

100. Stationery in the day-start menu is hidden by their titles covering the images, and the images are greatly squished, try to match the look from the original game more closely
   *Estimate: ~80k. Visual iteration against the original hub captures.*

97. Add a way to earn refresh tickets. Refresh tickets now come from the shared account wallet (one-time grant of 50, user decision 2026-10-25), and nothing refills them, so the balance runs out after a few runs. Find or design the earning source (original-game evidence first: quests, endings, ads, store) and wire it to the account wallet.
   *Estimate: ~80k once you choose the earning source.*

- **T04** (audit 82): Master of 108 Bows 47: acceptance multiplier x1.08.
  *Estimate: ~80k together with T05. Decide with U05 (acceptance semantics).*

- **T05** (audit 82): Blood Type A 74: acceptance +3%, with verified percent semantics.

99. Recreate documented History record details (ORIGINAL-GAME-FUNCTIONS and F17/F18).
   *Estimate: ~90k for the remaining items.*
   2R — Three-tab, near-full-height Info/Score Card/University Apps panel; new completion snapshots retain EXP, Gold, traits, equipped stationery and application outcomes. Legacy records remain readable without fabricated missing data. Photo upload/sharing, exact student-number rule and further score-card typography remain open. See docs/HISTORY-DETAILS.md.

- **F05** (audit 85): Acceptance-photo/report-card sharing or export, using verified contents/layout.
  *Estimate: ~100k. D-Day already saves the score card and Student ID to the gallery; remaining work is verifying contents and layout.*

103. Graduation Exam event that plays after each subject test should be different based off the users stats in the subject (cutoffs may be in psuedocode)
   *Estimate: ~120k, mostly pseudocode research for the cutoffs.*

- **M05** (audit 84): Persistent earned badge collection for later runs when gating is enabled; keep the user's currently unlocked setup prototype. User confirms first college enrollment unlocks that college's achievement and grants two cookies. Repeat/department-specific awards are not established.
  2R (2026-10-25) — First enrollment now pays the configured two cookies once per school; existing persistent enrollment counts prevent repeat rewards after restart. Earned achievements retain ownership. Setup remains unlocked as requested; optional ownership-gated setup is still future work.
  *Estimate: ~120k. Gating must stay off by default (the setup prototype stays unlocked).*

- **M08** (audit 84): Owned trait copies and discovery database, duplicates, setup selection/consumption and persistence.
  *Estimate: ~120k. Same gating caveat as M05.*

- **T01** (audit 82): Master of Notes 8: Weird Workbook on book completion; a completion probe left inventory empty. User confirms workbook popup precedes the separate item gacha; supplied F21 shows random-subject +90, Use and Confirm. Do not substitute one reward for the other.
  *Estimate: ~150k. Separate from the book-completion item gacha (39).*

102. Unlock the event limited puzzles and implement the ability to select puzzles to use as the background
   *Estimate: ~180k. Puzzle unlock rules plus background selection on Home.*

## Large (~200-600k tokens each)

- **A10** (audit 81): Story 16 hidden fake events 122/123/162 never execute because their flag stays false (game.dart). Audit customer-date, curse and mining-restoration consequences/triggers.
  *Estimate: ~250k. Three hidden story-16 events and their consequences.*

- **I02** (audit 83): Recipe 80011 has no recipe/inspection interface; empty generated effects do not supply its intended function.
  *Estimate: ~250k. New recipe/inspection interface.*

74. Reorganize the Retry Year characters.
   *Estimate: unknown until scoped; ask the user what the reorganization should be first.*

- **F02** (audit 85): Effective BGM/SFX playback and settings; event audio commands and cosmetic switches need runtime behavior.
  *Estimate: ~350k. Needs audio assets and an audio package.*

78. Implement every item, and have the shop roll randomly every time, matching the original game's pseudocode for which items appear.
   *Estimate: ~400k together with I05. The original offer pool and weights are only partly recovered.*

- **I05** (audit 83): Replace fixed five-offer shop selection and estimated prices with original stock generation, eligibility, refresh timing, prices and limits. Expands 78; do not create a competing shop task.

## Very large (600k+ tokens)

- **F01** (audit 85): In-run Surprise/Sudden Missions: offers, requirements, progress, success/failure, expiry, rewards and location-risk warnings. New F23-F26 specify offer/success/failure/item-reward layouts. User confirms unmet end-of-day goals expire silently, but breaking continuous conditions (e.g. maintain stamina above X) shows Surprise Mission Failed. Failed dialog shows forgone reward; do not grant it.
  *Estimate: ~700k. Offers, requirements, progress, failure rules and four captured layouts.*

- **F08** (audit 85): Remaining compiled character abilities/action/crafting flows (48); verify each independently of imported event graphs.
  *Estimate: ~800k+, partly blocked. Compiled per-character abilities and crafting; also covers the remaining parts of 48, 34 and 4.*

48. If the character effects aren't imported, please import them or recreate them.
   1R — 7 of the 46 characters have data-form effects (plusEffect: start gold, EXP boosts, study efficiency) and those already apply. Recovered from the native so far: the Medicine / Mechanical Parts blocks for characters 70 and 74 (see 34) and Alley King (67)'s guaranteed sing-off wins and practice pay. The other characters' abilities ("occasionally gets money from students", "bakes cookies", …) are compiled per character id and are still to be recovered.
   2R - Imported global character-event graphs now supply 44 eligible character events in story 16 and 27 in Retry Year, filtered to the selected character. Character crafting counters feed those graphs; complete parity for compiled character/item callbacks remains unverified.

34. Special blocks like Singing Practice block (Idol route), Soccer Practice block (Soccer route) don't exist
   2R — Mostly fixed; one part needs the global character catalog. My earlier note was wrong on one count: UNLOCK_LOCATION *is* implemented (I had grepped for the effect-type spelling, not the funcCode), and the campaign uses it twelve times — 16000 Art Museum, 16001 Gold Mine, 16003, 16004, 16005 Gym, 16006 PC Bang, 16007 Soccer Practice Field (twice, which is your Watching Soccer event), 16008 Studio and 2000. So unlocking an area already works and Soccer Practice appears at its field once that event fires.
     The real bug was the gate: a special block's conditionFuncCode is a compiled predicate name (IDOL_BLOCK_CONDITION) while the content writes a plainer switch (IDOL_BLOCK), and we were reading the predicate name as a switch, so every gated block stayed hidden for ever. Game.blockSwitchFor now maps gate to switch, dropping _CONDITION and the PRO_ prefix (PRO_GAME_BLOCK_CONDITION reads GAME_BLOCK, which story 16 sets to 1 twice). Three tests in test/special_blocks_test.dart.
     Still open: unlocks that come from the character you picked (your ihyeon/medicine crafting example). Those gates — MECHANIC, MEDICAL, PRACTICE_PSYCHIC — declare no switch in story 16 at all, so they are other campaigns' routes and the trigger lives in the global character catalog rather than the campaign. That needs the character effects imported before it can work.
   3R — The character gates are now read from the Korean native's block-condition table instead of guessed: MEDICAL_BLOCK_CONDITION is Med Student Ihyeon (character 70) while MEDICAL_LEVEL ≤ 3; MECHANIC_BLOCK_CONDITION is Hyunho Park (74) until he holds Robotics Master (trait 160020); IDOL/PRO_GAME confirm the IDOL_BLOCK/GAME_BLOCK reading. PRACTICE_PSYCHIC belongs to character 10044, who is not in the shipped catalog, so it correctly stays shut. Picking Ihyeon or Hyunho now deals their block. What the medicine and robot blocks *do* (crafting) is still the provisional track counter; that crafting is compiled and not yet recovered (see 48).
   4R — The practice blocks were advancing switches nothing reads (IDOL_ACTION_COUNT and friends). The native handlers add 1 to the counters the storylines gate on: IDOL (idol beats at 10/25/50), GAME (pro-gaming results at 10/50/100), SOCCER (10/30/50), MEDICAL_COUNT and ROBOT_COUNT (the crafting level-ups). Fixed, so these careers can now progress.

## Blocked on recovery or evidence

Cost depends on what evidence turns up; none of these should be guessed.

36. Some events that should be random seem to appear every run (keep getting Watching Soccer event). Seed should be randomized and larger events made less likely (There should be 1-2 events that unlock an ending max per run, and they can be at any part of the game. Check psuedocode and treat it as a higher priority over what's written here). Events like library drink, massage, etc, should be at the same likeliness as current or whatever matches the pseudocode
   1R — Cause found, not yet changed. Watching Soccer (173) is date-pinned to 21 Oct and belongs to event set 18 (the soccer storyline), so it fires every run. Story 16 ships 18 weighted event sets; the 7 rank-A sets are the careers (cooking, idol, entrepreneur, soccer, webtoon, pro gamer, street fighting). The native keeps per-story settings `eventset_selected_a_<story>` (one chosen A set, -2 by default) and `eventset_toggles_a/b/c_<story>` (on/off maps) — i.e. the original runs one career storyline per run with side stories toggled. The code that applies these at run start has not been located yet (the "picker at 0x74b4dc" in korstu4CLAUDE notes is a hash loop, not a picker), so the per-run A-set selection is the next step.
   2R — Each run now plays one career storyline: at the start of a run one of story 16's seven rank-A event sets (cooking, idol, entrepreneur, soccer, webtoon, pro gamer, street fighting) is drawn by the sets' own weights, and the other careers' events never fire — so Watching Soccer only appears in a soccer run. Side stories (B/C sets: gym, art museum, contests, …) and the required set are untouched, so the library drink, massage and similar events keep their current odds. The choice is saved with the run and tunable as rules.events.careersPerRun (1, matching the original's single eventset_selected_a; 0 turns it off). Still open: the original also lets players pick or toggle sets in a settings screen, which we don't have.

- **U02** (audit 87): Flat per-beat random-event selection versus unrecovered set dispatcher (36).

- **U01** (audit 87): Chronology sorts priority then ID; native placement and index/customPriority semantics remain unverified (50). Matching authored list order does not prove dispatcher parity despite previous DONE notes.

- **U03** (audit 87): Prototype one-A-tier-career-trait-per-run restriction: recover original eligibility/stacking.

- **U04** (audit 87): Fitted CSAT/admissions meanTotal, standard deviation and admissionSpread: recover scoring/distributions/odds. Do not lower thresholds to compensate for intended book/efficiency fixes (70/71).

- **U05** (audit 87): Acceptance items add standard score instead of directly modifying probability; verify original semantics and percentile/trait interactions.

- **U06** (audit 87): Weekly Goals use reconstructed rotation, base 348 plus prior study weighting and reward factor 0.74. Recover generation/modifier timing; reference Korean 398 -> Science 294 is not a universal formula.

- **U07** (audit 87): Stationery draw weights 1/9/30/60 and provisional 5% upgrade remain unrecovered. Keep confirmed highest-input-tier rule A+C -> A / B+C -> B; change odds only with evidence.

- **U08** (audit 87): Quizmaster uses a 68-question school-exam fallback/generated Mathematics/English rather than recovered dedicated English bank (37). Continue old-project recovery; label stand-ins accurately.

- **T06** (audit 82): MBTI S. Realistic 40: higher acceptance chance; recover exact rule.

- **T12** (audit 82): Bully 44: 200 Gold proc and eligibility.

- **T14** (audit 82): Talented Singer 201: karaoke/practice improvement.

- **T15** (audit 82): Exam Dreams 206: random-subject sleep stat reward.

- **I04** (audit 83): Recover book condition and extraDoneCount semantics. GameBook omits these original fields; verify replacement progress rules, repeat-completion rewards and same-rank variants.

- **L05** (audit 86): START_LOCATION_COUNT is a no-op; related predicate tests current location rather than a count. Recover counter lifecycle and implement together.

- **L06** (audit 86): Delayed/timed changes execute immediately; EffectEngine.applyChanger has no scheduler. Recover timing semantics before dependent ports; no active timer regression is claimed.

- **M01** (audit 84): Home hub/navigation: supplied layout, hidden-UI background view, Settings, mailbox, profile, Charging, Store, Notices and seasonal entry. Rank/leaderboard is intentionally omitted.
  NOTE (user, 2026-10-25) — These screens WERE supplied and are saved in screenshots/original-game-followup-2026-10-24/, specified per file in docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md: Settings F01-F02 (214331, 214340); Mail Box F03-F04 (214350, 214358); account/profile F05 (214418) and Change Username F07 (214513); Cookie Charging F08-F09 (214528, 214534); Store F10-F16 (214549-214627: Ads, Packs, Expansion, Cookie Store tabs). Not found in any capture folder: Notices and the seasonal Cookie Parade entry. So M01 is no longer blocked on evidence except Notices/seasonal; the destinations are still unbuilt (Settings is the project's own).
  2R (2026-10-25) — Settings, Mail Box, Profile, Change Username (first rename free, then 9 cookies), Charging and Store are built from F01-F16 (lib/ui/account_menus.dart); purchases/ads/mail show an unavailable notice. Notices and the seasonal entry still lack captures. See "Home implementation follow-up" below.
  *Estimate: remaining scope only. Notices and the seasonal entry have no captures; real mail, purchases, ads and invitations are out of scope.*

- Combine Rates and non-Standard/Jumbo trait-pack prices: unrecovered (see M07 and M09 in TODO-DONE.md).

## Deferred or out of scope

4. (Highest priority) Continue implementing the game initalization menu, which contains character selection, college badge selection, trait selection (note that not every trait can be selected as some are only obtainable through in-game events), name, and gamemode (Order should be gamemode, character, college badges, trait selection, name)
   *Estimate: Elite is deferred by the user; the remaining compiled character abilities are tracked under F08.*
   1R — Implemented the five-step Standard flow: mode -> character -> badges -> traits -> name, with back navigation, portraits, Unicode names, 7/5 selection limits and event-only trait exclusion. All setup-eligible collections unlocked per user request.
   2R — Run JSON preserves difficulty, character, badges, initial traits and identity; structured initial/passive bonuses apply, including work EXP. My Info displays selected portrait and badges. Added setup engine/widget tests; all 132 tests and analysis pass.
   3R — Still open: Elite gameplay (currently disabled), compiled character special abilities, disk-persisted presets/account/save-slot UI and the exact first-day navy/announcement presentation. See docs/START-GAME-INITIALIZATION.md.
   4R — The first-day presentation is now done: committing setup hands off through the navy D-31 screen with a dash where the goal goes (UIR-08), and the objective announces itself over the hub immediately after (UIR-09), which is the order the captures show. Still open: Elite gameplay, compiled character special abilities, and disk-persisted presets/account/save-slot UI. The last of those is the only one that is merely unbuilt rather than unrecovered.
   5R — Save slots are in: three of them, written atomically to <documents>/saves, listed on the title screen with name, D-count and timestamp, and continued or deleted from there. The in-game Save row now works and is offered only between days, as UIR-30 states; Main Menu asks before discarding anything since the last save. There is no reference capture of a slot list, so that screen is the project's own and is not presented as recovered. Still open from this entry: Elite gameplay and compiled character special abilities, both of which need evidence that has not been recovered.
   NOTE — Elite gameplay is outside the current focus (user, 2026-10-24); leave it until asked.

- **F06** (audit 85): Elite gameplay is rejected and its 37-level catalog unused. Deferred by user (4); do not activate/tune until requested.

- **F07** (audit 85): Stories 14/3/18/68 remain outside the two bundled campaigns. Future-port scope (42), not current-campaign regressions.

23. Try and import the Retry Year campaign to this app, adding it as a new option under elite mode (remove the elite support pack and remove the button under Elite Mode). Add scrolling if neccesary, but keep the top banner visible (Select Character (1 / 5))
   *Estimate: umbrella; specific Retry Year gaps are tracked by their own entries.*
   2R — Located story 20: 218 events and 9,072 node records. The earlier language assessment was incorrect: English dialogue is already shipped in translatedText/translatedElseText/translatedOptionText; see 4R below.
   3R — Retry Year is now a separate selectable prototype (packs/kss20), with all 218 events, 9,072 node records, eight locations and recovered original backgrounds, 20 eligible characters, its own calendar and campaign-aware saves. Elite/support-pack controls are hidden. Shipped English dialogue is imported (language assessment corrected in 4R). Special callbacks, 21 unparsed item effects, some art layers and ending/exam mechanics remain; see docs/RETRY-YEAR.md. Basic setup, save/load and a full calendar smoke run pass; this is not yet a completed port.
   4R — Verified the old English APK and extracted/mod trees: the generated pack contains 7,350 nonempty dialogue/choice/heading fields with no Korean prose outside runtime macros. Recovered matching English work-level/action labels from the older localized project. Added tools/audit_retry_english.py and corrected the selector/manifest/docs language status. Special mechanics remain incomplete.
   5R — Recovered the prologue and first-day lifecycle against English graphs and Korean native pseudocode: opening events 1 -> 169 -> 2 -> 3 now play before any action, including Mum and the scripted placement test. Reflection Room is the first playable location; SET_DOK_BANG, its escape task, evening release, next-morning introductions, hidden reset events and same-tick scheduled chains work. Evening dialogue finishes before rollover. Recovered 34 opening portrait/background files. Added save/legacy continuation recovery and lifecycle regressions. Evidence and remaining limits: docs/RETRY-YEAR-LIFECYCLE.md.
   6R — The campaign now plays start to finish and reaches its endings. Read Retry Year's compiled mechanics straight from the Korean native (disassembled, not guessed): the six special-block gates (friends' troubles, Presidential Assist, Karaoke, Battling the Champion), all eight DO_ block callbacks, SET_NEXT_TARGET_BLOCK_CONDITION (+3 days), SET_SING_TARGET, SET_GOLD_SUN_VALUE, SET_HIGH_GOGO, REMOVE_ITEM_ONCE, and the FUNC_MOCK_EXAM_GOOD / FUNC_IS_GOLD_WIN / FUNC_SING_TARGET / FUNC_AFTER_DAY predicates; nodes' continueTargetSwitch now chains the Sing-Off into its results. Fixed a daylight-saving bug that stopped every date-pinned event after 3 Nov (5 Nov in story 16) from ever firing on a US-timezone device — the Promotion Exam among them. Exam day plays the Graduation Exam, then the CSAT, applications (recovered catalog of universities/departments and cutoffs, Retry Year's own two universities and their recommendation requirements) and enrollment, which turns on the endings. Study is scaled to the native exam bands for this campaign only. A 40-run probe now reaches 92 of 197 visible events (was 53) and every run ends on an authored ending. Details: docs/RETRY-YEAR.md.

## Process and standing decisions

88. Collect remaining implementation evidence.
   3R - E33 (2026-10-25): archived and reviewed the user's complete 3:16.78 D-Day/application/results recording. Recreation handoff: docs/D-DAY-APPLICATIONS-REFERENCE-2026-10-25.md; 70 full-resolution frames, full timeline/detailed candidate contact sheets, searchable gallery and portable ZIP. Documents current search/categories, manual add/remove, partial Auto Input, confirmation arithmetic, colored rejection envelopes, retake enrollment/certificate, ending summary and doubled reward. Evidence only; implementation is not DONE. Sort options, duplicates and hidden scoring/RNG remain unresolved.
   1R - Archived 30 screenshots and three recordings in screenshots/original-game-followup-2026-10-24 with hashes/metadata and sampled video frames. Per-file specification and recovered public trait-pack rates: docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md. Evidence checklist records resolved versus remaining details; E33 research is assigned to public footage/wiki rather than another user playthrough. Documentation received is not implementation DONE.
   2R - E33: visually inspected original public One Month Part 4 and Tutorial True Ending Part 2: score summary/export card, three-slot applications/filter controls, confirmation, envelope reveals, rejection route and successful-offer choice/certificate. Recorded timestamped evidence and version differences; original scoring formulas and unexercised controls remain unresolved. No gameplay changes/deployment in this evidence update.
   - [ ] Work through docs/IMPLEMENTATION-EVIDENCE-REQUESTS.md; link incoming references to these audit IDs and the existing atlas.
   - [ ] Use full-screen originals plus short videos for transitions; include campaign, character, traits/badges/equipment, date/tick and before/after values when relevant.
   - [ ] Keep uncertainty explicit. RNG rates/arithmetic need original help/rate pages, assets/pseudocode or controlled evidence; screenshots alone cannot establish them.

89. Verify integration and update completion status.
   - [ ] Reconcile Claude's completed Home/account work with 40/41/84 before implementing remaining gaps.
   - [ ] Add meaningful regression tests as demonstrated engine defects are fixed. Existing audit probes are local build/parity_review_probe_test.dart, build/parity-review-probes.json and build/parity-review-probe.log, not permanent production tests.
   - [ ] Update functional docs with verified outcomes; documentation does not make an unimplemented/reconstructed function DONE.

90. Preserve user scope decisions throughout parity work.
   NOTE - Fresh stationery per run, unlocked prototype setup collections, no
   leaderboard, initially empty achievements and flat item-report/bag buttons
   are intentional. Elite is deferred. Book-completion item gacha stays reminder
   only (39); Master of Notes' workbook callback is separate. Use hardware-
   rendered profile builds and preserve Claude's stationery name-fit cache.
