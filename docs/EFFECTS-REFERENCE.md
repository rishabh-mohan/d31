# Effects reference and prototype rules

The exhaustive local reference is [EFFECTS-REFERENCE.md](../references/recovery/EFFECTS-REFERENCE.md).
Regenerate with `python tools/build_effect_reference.py`. It covers all **177 items,
244 traits, 147 story events and 2 imported system events** in the current pack.
Each item/trait has its description and structured effects; each event has its
eligibility, reachable choices, branch conditions, changers and links. Input SHA-256
fingerprints identify the exact data used. Effects on mutually exclusive branches
must not be summed. Other campaigns are outside this engine's active content.

The generated reference contains source game text and stays under the already
ignored `references/recovery/` directory. The generator and this interpretation
guide are tracked; do not publish the generated catalog.

## What the current engine actually applies

- Items: `tools/item_effects.py` parses prose into the pack's `effects` list.
  `EffectEngine.applyItemEffect` handles consumption; `GameState.passiveSum` handles
  held passive items with their location/subject scopes. An empty effect list is
  not proof that the original item does nothing: it can mean unsupported parsing.
- Traits: `TraitEngine` evaluates scope, story, conditions, subject and temporary
  lifetime. `gachable: true` plus matching/global story is the prototype setup
  eligibility rule. Event-only traits remain grantable through event content.
- `firstPlusStat`, `firstPlusMoney`, `firstExerciseLevel` and
  `firstPlusPartTimeJobLevel` apply at setup commit. Loading JSON does not apply
  them again. Live trait acquisition does not retroactively award starting bonuses.
- Study efficiency adds one stat per authored unit. `plusStat` prefers nonzero
  `storyStat`, falling back to `extraStat` for effects with no story value.
  Genius of the Century is +3, not the alternate scaled +9. Setup labels use
  the same reader. Passive-item `NORMAL_STAT_n` also resolves to +n;
  consumable stat scaling is separate and unchanged.
- `percentPlusMoney`, `percentPlusExp` and `percentPlusReward` are factors:
  1.2 means 20% more. Character and badge structured effects use the same reader.
  Work-EXP factors now apply to work blocks as well as workout-EXP factors to workouts.
- Event effects: `lib/engine/effects.dart` is the dispatch authority. Conditions
  use `conditions.dart`; branch/box ordering uses `event_engine.dart`. Event state
  is 0 unseen / 1 running / 2 completed. Generated entries explicitly flag empty
  callback handlers; the presence of a handler does not prove original fidelity.
- The imported exhaustion and workout events are host-controlled system sequences,
  not ordinary random events. Their callbacks must not repeat host penalties.

## Unresolved original behavior

Korean 1.61.0 pseudocode is not Global 1.27.4 pseudocode. Existing `stub()` calls
do not establish probabilities or account entitlements. Original Elite modifiers,
character proc probabilities/crafting, trait compatibility/consumption, full
admissions, task-list callbacks and event-set ordering remain incompletely known.
Current default character portrait exports use the skeleton image; expression and
clothing composition still need implementation. A listed description is not proof
that a compiled special ability has been implemented.

## Proposed prototype rules (designed, not recovered; not enabled yet)

These fulfill the request to define rules for gaps while retaining the evidence
boundary. They are concrete future implementation defaults, not claims about KSS.

| Gap | Proposed prototype rule |
|---|---|
| Elite | Start at 25 in each subject instead of 50; multiply action stamina costs by 1.15 after discounts, round once. No paid support entitlement and no free S trait. Keep Standard unchanged. |
| Character money procs | After a completed School action, 10% chance of 100 Gold; upgraded money character earns 200. Roll once from run RNG and save the result, never in preview. |
| Character study assistance | Offer one help action at School per day: one tick, normal study stamina, +15 to the weakest subject. |
| Character baking | At Home offer one baking action per day: one tick, normal work stamina, one ordinary stamina snack from an explicitly configured item-ID pool. No pool means disable the action. |
| Character question solving | After class, one problem action per day: one tick, study stamina, +20 to the selected subject. |
| Crafting characters | One crafting action per day, one tick and normal work stamina. Spend two explicitly configured ingredient items to grant one configured output. Disable without a valid recipe; never choose IDs from names. |
| Trait inventory | All setup-eligible traits unlocked, maximum five distinct IDs, no consumption. Allow combinations; do not invent exclusions. This collection policy is already active. |
| Badges | All unlocked, maximum seven distinct IDs, no consumption. Structured effects stack once per badge. This collection policy is already active. |
| Unknown item effects | Mark unsupported and disable consumption until a structured effect is authored; do not silently consume for no benefit. |
| Task-list callbacks | Persist a set of task IDs; ADD inserts idempotently, REMOVE deletes idempotently. Display tasks without rewards unless a separate explicit changer grants one. |
| Event-set progression | Only the first unfinished eligible event in a set may fire. Completing a beat advances the set; evaluate dates/conditions normally. Recheck the existing #189 prerequisite overlay before enabling. |
| Location counters | Persist actions-per-location; START_LOCATION_COUNT records a baseline. Count completed player actions only, excluding menu browsing and exhausted-slot filling. |
| Unknown callback | Record verb/args in the log, apply no guessed reward, continue the event. Add a specific structured rule before supporting it. |

Validation for proposed rules should include seeded RNG, preview/act agreement,
save/load continuation, no duplicate start rewards, and malformed config rejection.


## Clarified callbacks — 2026-10-25

See [the rule/evidence record](CLARIFIED-MECHANICS-2026-10-25.md).
ADD_BLOCK [1] now enables the persistent IDOL_BLOCK gate for the two authored
story-16 Practice grants; source removal scenes clear it. Unknown mappings
remain visible in unsupported callbacks rather than becoming extra turns.
Retry Year Herb Collecting uses the explicitly overlaid SCAVENGE_ITEM and
DUPLICATE_SCAVENGED_ITEM callbacks for the user's provisional 20% exact-copy
rule and exclusive Ginseng Digger result. Item effectList emptiness alone does
not prove a graph-driven passive is absent.

Stubborn/I will not falter!/Energizer rates remain configurable 30%/70%/5%
prototype defaults: the latest local pseudocode/catalog review did not recover
attributable original arithmetic, and the user has no published odds source.


## Pack-owned trait abilities, second pass — 2026-10-25

Traits in story 16 and Retry Year (story 20) that ship no `effectList` now get
their behavior from `content/kss/mechanics.json` (`traitAbilities` + `hooks`),
not from engine checks on catalog IDs. Story-18 Winter traits were out of scope.
Tests: `test/trait_abilities_test.dart`.

**Generic engine additions.** Engine moments a pack can bind in `hooks`, each
running a named callback that trait `callback` abilities attach to:
`actionCompleted` (after any block's payout and changer, args `[actionType]`),
`bookCompleted` (the read that reaches a book's `doneCount`, args `[bookId]`;
later re-reads do not fire), `sleep`, `dayStarted` (each rollover except exam
day), `arriveAtSchool` (weekday rollover that puts the player at School),
`exhausted` (a block's collapse) and `traitAcquired` (args `[id, type]`).
New ability types: `hpCost` (`value`), `priceOverride` (`maxPrice`, `price`),
`blockItemUse` (`itemTag`) and `blockNegativeTrait`. New operations: `addHp`
and `note` (log line plus an on-screen report); `addStat` also takes a subject
index; new expression `concat`. Items a hook hands over and ability notes ride
on `ActionOutcome.acquiredItems` / `.reports`; the game screen shows the items
in the standard acquisition popup (Use, then Confirm), then the notes, before
any other follow-up. `ACQUIRE_TRAIT` / `ACQUIRE_TRAIT_RANDOM` now go through
`EffectEngine.acquireTrait`; setup and dev-panel grants are not "obtained".

Evidence labels: **description** = the amount/trigger is stated by the
catalog text (and, where noted, a capture); **provisional** = a configurable
default chosen because no native arithmetic was recovered. The Korean 1.61.0
pseudocode (`korstu4CLAUDE/.../decompiled/app/app.dart`) was searched for
literal trait-ID checks and the relevant handlers (`doKaraoke` sub_bdbb98,
`SLEEP`, `study`, `walking`); apart from one trait-201 check inside
`doKaraoke`, no attributable arithmetic for these traits was found. Absence of
a recovered value is not proof that no compiled value exists.

| Trait | Behavior now | Evidence |
|---|---|---|
| Master of Notes 8 | One Weird Workbook (item 8, Stats +90 random subject) when a book is finished; receipt popup with Use/Confirm. The book-completion item gacha is still not implemented (TODO 39). | Description; F21 capture and user statement on ordering. |
| Bully 44 | 200 Gold on a completed block, rolled once per tick (seeded); "Bully: +200 Gold." report. | 200 from the description; the 10% chance and the per-block trigger are **provisional** (`chance` in the ability, override `rules.traits.chances.44`). |
| Talented Singer 201 | +1 extra `SING_COUNT` per Singing Practice at the Karaoke (trait scope 20002), on top of the microphone. | Native `doKaraoke` reads trait 201 after the item-90008 test, but its arithmetic did not decompile. The +1 is **provisional** (`rules.karaoke.talentedSingerBonus`). |
| Brilliant Microphone 90008 | Singing Practice adds 2 instead of 1 (already in `DO_KARAOKE`). Both held: 3. | Recovered (docs/RETRY-YEAR.md, sub_bdbb98). |
| Exam Dreams 206 | Each Sleep block: +45 to one random subject (run RNG at act time; the Sleep card does not roll); report names the subject. | Trigger from the description. "STAT_15" is read with the x3 placeholder scale already used for Multitasker's STAT_1 → 3; the 45 is **provisional** (`rules.traits.examDreamsStat`; set 15 for the unscaled reading). |
| Professional Latecomer 9 | 30% (seeded per day) to lose 10 stamina on the morning walk to School; removed after five rollovers without a collapse (`LATECOMER_CLEAN_DAYS`, reset by a collapse). | Trigger and five-day rule from the description; 30% and 10 are **provisional** (`chance`, `rules.traits.latecomerStamina`). |
| Salt and Light 48 | Turns away the next *obtained* negative (`type: bad`) trait and is used up. | Description (Korean: defends once). |
| Scrooge 53 | Store offers listed at 3000 Gold or less cost 100 (never more than the discounted price). | Description. |
| Stocks Manager 54 | Next obtained trait: good → +1000 Gold, bad → −1000 (floored at 0); then the trait is removed. A blocked or refused trait settles nothing. | Trigger from the description; the amount and one-shot reading ("the next trait"; Korean is ambiguous) are **provisional** (`rules.traits.stocksManagerMoney`). |
| Lactose Intolerant 70 | `milk`-tagged items (White Milk, Chocolate Milk) cannot be used; the item stays and a report says why. Lactase Pills now cure it (the parser's "Lactose Intolerance" name is aliased to the trait). | Description. The cure was previously a silent no-op. |
| Sunstroke 100 / Heat Stroke 102 | Stamina cost +5 / +100 on every block while held; the catalog's 5 / 3-day lifetime cures them. | Description and catalog lifetime. |
| Customer's Lover 160004 / Curse 160005 | Holding them keeps `SON_NIM_LOVE` / `SON_NIM_COURSE` at 1 (set on acquisition and each morning). These switches are the only gates of Customer Date (90) and Customer's Curse (96) and no event sets them, so both scenes were unreachable. | The switch reading is **provisional** (inferred from the graph). Repeat dates/curses need the fake "restore" events 122/123, which story 16 still does not execute (TODO A10). |
| MBTI J. Judger 38 | Unchanged code: `Goals.issue` folds the factor into a goal when it is posted, so a mid-week acquisition affects only the next Monday's goal. A setup trait is held before the first goal is posted, so week one includes it (Korean text: goals that appear from now on). | Description; the earlier "applied immediately" audit note is superseded. |

**Already delivered by the event graphs (no ability added):** Jailbreaker 214
(event 4, nodes 4008/4014, All Stats +40), Delinquent 216 (event 11, node
11014, +20) and Cooking Master 221 (event 120, four nodes in each script, +50)
are `FUNC_TRAIT_HAVE`-gated nodes in both Retry Year scripts. Favourite
Student 160012 is granted in event 181 next to `COOK_ON = 1`, which gates the
Training Sessions 182-185. Lower Student 200010 is granted in event 3 and
removed by event 66; no condition reads it and no native effect was
recovered, so it has no mechanical effect here.

Reachability: Latecomer, Salt and Light, Scrooge, Stocks Manager, Lactose
Intolerant, Sunstroke and Heat Stroke are not setup-eligible and no story-16 or
Retry Year graph grants them; in these campaigns they arrive only through the
dev panel. Bully and Judger are also in Retry Year's `ACQUIRE_TRAIT_RANDOM` pools.
