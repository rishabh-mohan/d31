# Modular packs — 2026-10-25

User requirement: packs must own their custom traits, blocks, characters and
story callbacks. Do not add campaign-specific IDs or special-block handlers
to the engine. Add generic primitives only when the existing vocabulary cannot
express a behavior.

## Implementation

Optional `mechanics.json`, version 1, contains these sections:

- `predicates`: named read-only expressions, usable by action gates and event
  function conditions.
- `callbacks`: named lists of operations, invoked by a changer's `funcCode`.
- `traitAbilities` / `characterAbilities`: catalog ID strings mapped to ability
  lists. IDs alone imply no ability. Existing structured catalog effects remain
  supported.
- `blocks`: persistent named action definitions, with `locations`, `action`,
  optional `aliases`, `when`, `defaultEnabled` and `enabledSwitch`. Enable or
  remove through generic `ENABLE_BLOCK` / `DISABLE_BLOCK` callbacks with the
  block ID as argument. Unlocks persist across saves until removed.
- `hooks`, `switchGuards`, `textMacros`, `bindings`: pack-owned extension points
  for exercise level-up, guarded switches, dialogue labels and subject/lock
  bindings.

Abilities currently include stamina-free actions, exhaustion survival, price
and item HP factors, movement HP, random study-stat bonuses, and callback
effects. Callback operations cover switches, money, stats, items, traits,
conditional steps, callback calls, block enablement and calendar shifts.
Expressions include arguments, state fields, switches, traits/items, arithmetic,
comparisons, predicates, rules, lookups and deterministic rolls. Mutable random
draws are restricted to callbacks. The evaluator has nesting/operation limits;
no executable scripts or external IO are accepted.

`examples/packs/workshop` is a standalone authoring example with custom subjects,
location, crafting block, trait and character. Copy the `workshop` directory into
an editable `packs` root and select it. Editable roots include desktop `packs`,
app documents `packs`, and Android app external-storage `packs`. A unique pack
ID loads without a bundled counterpart. This is separate from updating bundled
KSS content: normal phone deployment still uses APK bundle-stamp reseeding.

KSS identities and aliases now live in `content/kss/mechanics.json`.
`tools/export_pack_mechanics.py` exports that data and reflection-room rules;
`tools/build_pack.py` calls it for both campaigns. Generated pack folders are
ignored, so preserve changes in the tracked content/generator files.

## Authoring reference

Start by copying `examples/packs/workshop` under a new directory/manifest ID.
Keep IDs unique inside each catalog; IDs may overlap another pack's catalog.
Add records to `items.json`, `books.json`, `traits.json`, `characters.json` and
`locations.json` using [PACK-FORMAT.md](PACK-FORMAT.md). Use existing structured
effects for ordinary bonuses, and mechanics abilities for triggered behavior.
Descriptions are display text; they do not execute effects.

For example, a character-only block can use:

```json
{
  "version": 1,
  "predicates": {"IS_ARTISAN": {"eq": [{"field": "characterId"}, 70]}},
  "blocks": [{
    "id": "crafting", "locations": [801],
    "when": {"predicate": "IS_ARTISAN"},
    "action": {"locationActionType": "special", "text": "Craft",
      "changer": {"funcCode": "CRAFT"}}
  }],
  "callbacks": {"CRAFT": [{"op": "addStat", "subject": "craft", "value": 5}]},
  "characterAbilities": {"70": [{"type": "callback", "callback": "CRAFT",
    "steps": [{"op": "addMoney", "value": 7}]}]}
}
```

Grant the block from any event with
`{"funcCode":"ENABLE_BLOCK","args":["crafting"]}`. Remove it through
`DISABLE_BLOCK`. Use `defaultEnabled:true` when the block needs no event unlock.
`enabledSwitch` instead uses a declared switch as the persistent unlock, useful
when imported graphs already write that switch. `catalogOnly:true` registers
an unlock alias for an action already defined in `locations.json`; it does not
insert another copy of the action.

| Ability type | Parameters |
|---|---|
| `staminaFree` | Optional `chance`, `period` (`tick` or `day`) |
| `surviveExhaustion` | Optional `chance`, `period` |
| `priceFactor`, `itemHpFactor` | `factor`, optional `itemTag`, `factorRule` |
| `moveHp` | `value`, optional `chance`, `oncePerTick` (default true) |
| `studyRandomStat` | `value`, optional `chance`; deterministic subject per tick |
| `acceptanceFactor` | `factor`; multiplies the final acceptance chance |
| `acceptancePoints` | `points` (optional `pointsRule` name under `rules.traits`); adds percentage points to the final acceptance chance |
| `callback` | `callback` name, `steps`, optional `chance` |
| `hpCost` | `value` added to block stamina cost, optional `actionType`, `chance` |
| `priceOverride` | `maxPrice`, `price`: fixed Store price for listings at or below `maxPrice` |
| `blockItemUse` | `itemTag`: items carrying that detail tag cannot be used |
| `blockNegativeTrait` | Turns away the next obtained `bad` trait; used up unless `consume:false` |

All abilities can have a read-only `when` expression. `traitAbilities` and
`characterAbilities` use the same shape. Held traits respect enablement,
story/location scope and expiry. Existing catalog `effectList` / character
`plusEffect` also apply. Chances are fractions from zero to one; `rules.traits.chances`
can override trait-ID chances. `factorRule` names a value under `rules.traits`.

An expression is a scalar or an object with one operator. Examples:
`{"arg":0}`, `{"switch":"CRAFT_COUNT"}`, `{"field":"characterId"}`,
`{"all":[true,{"gte":[{"itemCount":501},1]}]}`.
Use `{"literal":...}` for an object that should be data rather than an expression.
Arithmetic/comparison operators take two operands; `if` takes condition,
true value, false value. `lookup` takes a literal table, key and optional
fallback. `rule` takes section, key and optional numeric fallback. `roll` takes
`chance`, `seed` and optional `period`; it is deterministic for previews.
`randomInt:[min,max]` is inclusive and allowed only in callbacks. `trait` checks
an active held trait; `characterCode` compares the character's pack-owned role
tag. Subject indexes follow the manifest's `subjects` order.

| Operation | Required parameters |
|---|---|
| `setSwitch`, `addSwitch` | `name`, `value` |
| `addMoney`, `addHp` | `value` |
| `addStat` | `subject`, `value` |
| `grantItem` | `id`, optional `count` |
| `grantTrait`, `removeTrait` | `id` |
| `pulse` | `name`; reset after the action's event check |
| `drawItem` | `pool` list, optional `store` switch for selected ID |
| `if` | `when`, `then` operation list, optional `else` list |
| `call` | `name`, optional `args` list; can invoke generic engine callbacks |
| `enableBlock`, `disableBlock` | `id` |
| `shiftCalendar` | `monthSwitch`, `daySwitch`, `days` |
| `setField` | `name:"movementLocked"`, `value` |
| `note` | `text`: a log line and an on-screen report after the block |

`hooks` binds engine moments to callback names: `exerciseLevelUp`,
`actionCompleted` (`[actionType]`), `bookCompleted` (`[bookId]`), `sleep`,
`dayStarted`, `arriveAtSchool`, `exhausted` and `traitAcquired` (`[id, type]`).
Trait/character `callback` abilities attach to the bound callback. An ability's
`when` is evaluated without callback arguments; test arguments inside an `if`
step. `addStat` accepts a subject key or index; `concat` joins values to text.

Named callback definitions can override an imported callback name for that
pack. Unknown generic callback names are reported in the debug diagnostics.
New mechanics combinations should use these data definitions. An entirely new
kind of behavior may require adding a generic primitive and documenting/tests
for it; do not implement it as an engine check for a particular content ID.

## Verification and limits

Both campaigns regenerate successfully from tracked source. Analysis is clean.
The full suite passed 323 tests, including 200 seeded complete runs. Four
additional custom-pack regressions were added to the nine-test custom suite:
normal action resolution/text macros, stable study preview/payout, and a zero
chance withholding only its provider's callback reward, and direct expression
gates failing closed. This covers 327 unique
tests across those runs. Logs: `build/modular-final-tests.log`,
`build/modular-custom-tests.log`, `build/modular-analysis-final.log`,
`build/modular-pack16.log`, `build/modular-pack20.log`.
The final condition-gate change is additionally covered by
`build/modular-gates-tests.log` (custom pack, engine and Retry Year suites).

Schema validation rejects unsupported versions/operations/expressions, invalid
ability chances, incomplete blocks and predicate cycles. Callback recursion has
runtime depth/call limits, including calls from abilities; arbitrary dynamic
callback cycles are not statically rejected. This is a bounded content language,
not a general scripting runtime. New engine primitives remain code work.
Generic account/UI assumptions outside this mechanics refactor have not been
audited as fully campaign-neutral. Phone deployment evidence is recorded in
[CURRENT-STATE.md](CURRENT-STATE.md).
