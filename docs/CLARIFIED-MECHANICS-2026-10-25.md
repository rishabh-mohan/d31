# User-clarified mechanics — 25 October 2026

This record supersedes A14/I03 blocker descriptions in the earlier branch report. User decisions and imported-source behavior are intentionally distinguished.

| Mechanic | Evidence / choice | Implemented behavior |
| --- | --- | --- |
| Hiking Gloves | User explicitly selected 20% exact duplicate as a provisional choice. | One extra copy of the exact scavenged herb; no second random draw. Applied to both Retry Year protagonist scripts. |
| Ginseng exclusivity | User recalled no simultaneous double gather and ginseng, then approved that rule. | Ginseng Digger's seeded 20% check runs first. A successful ginseng outcome skips the gloves bonus; otherwise gloves may proc at 20%. No three-reward path. |
| Practice Block | User says the block remains until a later event removes it; soccer coach is the example. | ADD_BLOCK [1] enables the existing story-16 Idol Practice gate. Use/new day/save does not remove that unlock. Authored removal clears it; existing once-per-day duplicate restrictions remain. Other unknown numeric mappings are not guessed. |
| Shop refresh | User says stock resets at Saturday start; refresh is one cookie before any purchase, first reroll removes one item, later rerolls retain count. | Current offer IDs/reroll count persist, hidden offers cannot be purchased, spending uses shared cookies, and Saturday resets stock and the reroll lock/count. |

## Source discrepancy and audit correction

The imported English 1.27.4 Herb Collecting graph **already implemented a gloves branch**. Node 23002 checked item 90009 plus FUNC_RANDOM_TRUE [40,123]. Node 23004 performed ACQUIRE_ITEM_RANDOM from 80003–80007 again. The gloves-failure branch checked Ginseng Digger 200; a post-gloves trait-155 branch could independently award ginseng. Empty item effects did not mean this passive was missing. The earlier I03 audit was incorrect on that point.

The generator now applies an explicit, documented user-choice overlay rather than claiming those source values were 20%/same item. SCAVENGE_ITEM grants/stores the base herb and saved exclusive outcome; DUPLICATE_SCAVENGED_ITEM grants the stored herb once. Dialogue/reward receipts still use the authored event, with its post-gloves ginseng branch bypassed. Location and trait scope remain enforced. Seeded rolls are this port's deterministic implementation choice.

## What is still unresolved

- Shop refresh currently samples the configured prototype offer catalog. The original broader item pool, selection weights and complete eligibility/price rules are still I05/78 work. No full original stock generator is claimed.
- Stubborn, I will not falter!, Energizer: user knows no exact odds or website. A read-only smaller-agent inspection of the local Korean AOT pseudocode and catalogs found descriptions/empty effect lists, but no attributable numerical arithmetic. Keep defaults 30%/70%/5% and rules.traits.chances overrides labeled provisional. Absence of a recoverable result is not proof no compiled value exists.
- Recovery references for that odds review: references/recovery/EFFECTS-REFERENCE.md sections 41/51/84, packs/kss20/traits.json, lib/engine/traits.dart, and korstu4CLAUDE/private-build/korean-base/analysis/decompiled/app/app.dart. No native or remote-config rates were established.

## Verification

Seven targeted tests cover both gender graphs, seeded 20% duplicate behavior, exact item identity, ginseng exclusivity/priority, mid-dialogue save/repeat safety, persistent Practice grants and authored removal, shop costs/counts/locking/Saturday reset and the refresh control. Broader suite, visual layout and deployment results are recorded after final verification.


Final validation: all 318 tests pass and analysis reports no issues. Phone-size visual review passes, including the shop refresh row. Evidence: build/clarified-final-tests.log and build/clarified-final-render.log. Device installation details follow after the final profile APK finishes.


Deployment: code commit 7e1884e, profile APK 385414826 bytes, installed successfully on Nord 7c2c1cc8 and cold-launched successfully (1102 ms). Existing saves/account data were not cleared. Local APK SHA-256: ad9f3cacd643dcdfca89c7de1eec9dd1c47c293a5dfb35dcbfb11ef712f66b0b. Both Retry Year scripts were regenerated; no manual pack push was used.
