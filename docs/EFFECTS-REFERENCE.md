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
