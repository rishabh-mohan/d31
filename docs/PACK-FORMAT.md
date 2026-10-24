# Content pack format

A pack is a directory of JSON that holds the entire game. The engine ships no
content of its own, so changing the pack changes everything: the calendar,
the places you can go, what you can do there, every event, every item and
trait, the level tables, and every number the loop multiplies.

```
packs/kss16/
  pack.json           manifest: calendar, subjects, where you start
  rules.json          every tuning number
  locations.json      places and the actions available at each
  items.json          items, with structured effects
  traits.json         traits, with the original's own effectList
  levels.json         study / elite / exercise / part-time tables
  books.json          study material (subject, power, stamina cost)
  events/
    events.json       events and their node graphs
    switches.json     event switches and their defaults
    sets.json         event set metadata
```

`pack.json`, `rules.json`, `locations.json` and `events/events.json` are
required. The rest are optional — leave one out and that system is simply
empty.

## Where the pack lives, and how to edit it

The pack is bundled read-only in the app, and copied to a writable directory
on first run. The app then loads the copy, so edits survive and need no
rebuild.

| Platform | Editable copy |
|---|---|
| Windows desktop | `packs/<id>/` in the repo, loaded directly |
| Android | `/sdcard/Android/data/dev.d30mode.d30mode/files/packs/<id>/` |

On the phone, push an edited file and reload:

```bash
# PowerShell, not Git Bash -- MSYS2 rewrites /sdcard/... into a Windows path
# and adb push then reports success while nothing lands.
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s <serial> push rules.json `
  /sdcard/Android/data/dev.d30mode.d30mode/files/packs/kss16/rules.json
```

Then open the dev panel (the slider icon) → **Pack** → **Reload from disk**,
and start a new run. A run in progress keeps the rules it began with.

The dev panel's **Rules** tab edits `rules.json` in place and writes it back,
which is the quickest way to tune without leaving the app. **Reset to
bundled** restores the whole directory from the copy inside the app.

## Rebuilding the pack from source

`packs/kss16` is generated, not hand-written:

```bash
python tools/build_pack.py          # writes packs/kss16
```

It reads the Korean Student Simulator reference data already extracted in this
workspace — the 31-Day Mode campaign (`campaign-localized-v2/story-16`, 97.3%
English) and the English build's global catalogs. Re-running overwrites the
pack, so copy a tuned `rules.json` aside first.

---

## pack.json

```json
{
  "id": "kss16",
  "name": "31-Day Mode",
  "description": "See how far you can go!",
  "calendar": {
    "startDate": "DATE_2023101600",
    "endDate": "DATE_2023111600",
    "ticksPerDay": 15
  },
  "start": { "locationId": 1000, "firstName": "Basakan", "lastName": "Kim" },
  "subjects": ["korean", "english", "math", "science", "society"]
}
```

Dates are `DATE_YYYYMMDDTT`. The last two digits are a **tick** — the action
slot within the day, not an hour. The original's story 16 references ticks
00–14, so a day defaults to 15 slots.

`subjects` drives everything subject-shaped, and **its order is
load-bearing**. The engine addresses subjects both by name and, where the
original did, by **position** — `INCREASE_STAT
[1, 150]` means "the second subject in this list". Reorder the list and that
content follows; shorten it and index references clamp to the last entry.

The order above is not a guess: it is recovered from the Dart enum ordinals
in the AOT object dump (`analysis/objs.txt`), which carry
`korean=0, math=1, english=2, tamgoo1=3, tamgoo2=4` — `tamgoo1`/`tamgoo2`
being the two elective slots, which story 16 fills with science and society.
A second enum in the same dump agrees on 0–2. Reordering these without
reason silently redirects every `INCREASE_STAT`/`DECREASE_STAT` in the
content.

Changing `startDate`/`endDate` changes the length of the run, and the six
`section` buckets events are filed under rescale with it.

## rules.json

Every number the loop uses. **These are not recovered from the original** —
its formulas live in compiled Dart, in no JSON file. They are this project's
model, fitted to the data that *is* observable: action `weight` and
`hpWeight`, book `power`, and the level tables' `weight` multipliers. Tune
freely; that is the file's whole purpose.

The formulas the engine applies:

```
study gain   = book.power × study.studyWeight × studyLevel.weight
               + studyLevel.plusStat + Σ studyEfficiency bonuses
               × (1 + combo stacks × study.comboBonusPercent)

part-time    = partTimeJob.baseMoney × partTimeLevel.weight
               + Σ partTimeEarnings   (then × percent bonuses)

exercise exp = exercise.expPerSession
               + Σ exerciseEfficiency  (then × percent)
               × levels.exercise.locationEfficiency[here]

stamina cost = action.hpWeight + Σ hpCost effects   (clamped at 0)

study gain does NOT include action.weight -- see locations.json.

sleep        = day.sleepRestoresHp
               + day.sleepLocationBonusHp if the location's type is "sleep"
               + Σ sleepEfficiency
```

Sections: `stats`, `hp`, `money`, `refresh`, `cookies`, `satiety`, `day`,
`study`, `partTimeJob`, `exercise`, `goals`, `specialTracks`, `events`,
`exam`.

`day.blocksPerTick` is how many action blocks are dealt each tick (compiled in
the original; 4 here). Note that most locations have only 2–5 *ungated*
actions, so until a character unlocks the special blocks the hand is usually
the whole pool and the weights do not bite.

`refresh.initial` is the stock of Refresh Tickets, which redeal the hand.
`goals.*` feeds the placeholder goal strips (lib/engine/goals.dart). A missing key falls back to a built-in
default rather than failing, so a half-edited file still loads.

`events.randomEventChancePerTick` and `events.maxEventsPerDay` control how
busy a run feels; `events.rankWeights` biases the draw toward A/B/C-rank
content.

## locations.json

```json
{ "locations": [ {
  "id": 1000, "name": "School", "type": "school", "funcCode": "SCHOOL",
  "description": "Part-time and exercise efficiency slightly increased",
  "isDefault": true, "isDefaultLocked": false,
  "actions": [ {
    "locationActionType": "study",
    "text": "", "weight": 6, "hpWeight": 1,
    "changer": { "funcCode": "SLEEP", "args": null, "changes": [] },
    "blockDuplicated": false,
    "conditionFuncCode": null,
    "duplicatedKey": null
  } ]
} ] }
```

- `isDefaultLocked: true` means the location starts locked; content unlocks it
  with `UNLOCK_LOCATION`.
- `locationActionType` picks the built-in behaviour: `study`, `partTimeJob`,
  `exercise`, `sleep`, or `special` (which does nothing but spend stamina and
  run its `changer`).
- `text` empty means "name it from the action type".
- `weight` is the **draw weight**, not a payout multiplier: each tick the
  player is dealt a hand of `rules.day.blocksPerTick` blocks drawn from the
  location'"'"'s list without replacement, weighted by this. That is why the
  Reading Room carries study 12 / sleep 0.3 — you go there to be *offered*
  study, not to be paid more for it. Payout comes from the level tables and
  the location efficiency lists.
- `hpWeight` is the stamina cost.
- `image` is a pack-relative art path for the location backdrop
  ("backgrounds/park.png"); see **Art** below.
- `conditionFuncCode` names an event switch that must be non-zero for the
  action to appear — this is how the original hides the special tracks until
  their story unlocks them.
- `blockDuplicated` with `duplicatedKey` limits an action to once per day.

## events/events.json

```json
{ "events": [ { "id": 159, "name": "Orthostatic Hypotension",
                "rootNodeId": 159000, "priority": "middle", "rank": "C",
                "section": "four", "isRandomDate": true,
                "eventSetId": null, "conditionSet": { ... } } ],
  "nodes":  [ { "id": 159000, "boxId": 0, "type": "text",
                "text": "Whoaah-aaaaah...!!!!!", "nextNodeId": 159001,
                "changer": null, "conditionSet": null } ] }
```

**Selection.** An event fires when its `conditionSet` holds. Events with
`isRandomDate: false` are scheduled content and fire as soon as they are
eligible, in `priority` order. The rest are a weighted random draw, gated by
`rules.events`. `section` (`one`..`six`, or `none` for any time) restricts an
event to one sixth of the calendar.

**Node types.** `text` shows a line. `option` offers choices. `ifElse`
branches on its own `conditionSet` via `nextNodeIdIfTrue` /
`nextNodeIdIfFalse`. `last` ends the event. Everything else — `standing`,
`background`, `eventBGM`, `soundEffect`, `loopSoundEffect`, `mainBGM`,
`allMute`, `mainBGMMute` — is presentation: the engine applies its side
effects and walks straight through, so the player only ever sees a beat with
something in it.

**Choices** are inline on the `option` node:

```json
"options": [
  { "text": "Thank you!",        "nextNodeId": 263012, "nextBoxId": 1 },
  { "text": "Whatever, you know?", "nextNodeId": 263019, "nextBoxId": 2,
    "conditionSet": { ... } }
]
```

A branch with a `conditionSet` that fails is hidden. If every branch is
hidden the engine falls through to `nextNodeId` rather than deadlocking.

`elseText` is what a node shows when its own `conditionSet` is false — the
original's way of writing a one-node branch.

A graph that loops is cut off after 2000 nodes with a note in the log, so a
mistake while authoring cannot hang the app.

## Conditions

One recursive shape gates events, nodes, choices and individual changes:

```json
{ "operator": "and",
  "left":  { "conditions": [] },
  "right": { "conditions": [
    { "type": "defaults", "target": "EVENT_159", "targetType": "event",
      "compareType": "equal", "value": 0 } ] } }
```

`conditions` are ANDed. `left`/`right` combine with `operator` (`and`/`or`).
An empty side is "no opinion", which is why the single-condition case is
written as an empty `left`.

`compareType`: `equal`, `notEqual`, `bigger`, `equalOrBigger`, `smaller`,
`equalOrSmaller`.

| `targetType` | `target` | reads |
|---|---|---|
| `event` | `EVENT_<id>` | how many times that event has fired |
| `eventSwitch` | a switch name | its current value |
| `date` | `DATE_...` | 1 on that day (and tick, when the code names one) |
| `location` | `LOCATION_<id>` | 1 if the player **is at** that location |
| `func` | `FUNC_...` | a computed value — see below |

**A location condition asks where the player *is*, not what they have
unlocked — 70 story-16 events are gated this way, and the content makes it
plain (#314 "Eating Shrimp Crackers in Secret" is `LOCATION_1000` and opens
with "this class is so boring"; #116 "Library Volunteering" is the Library;
#256 "Motherlode" is the Gold Mine).

**`FUNC_` targets** are a registry in `lib/engine/conditions.dart`. All 37
that story 16 uses are implemented, covering items (`FUNC_ITEM_HAVE`,
`FUNC_ITEM_COUNT`, `FUNC_ITEM_USE_COUNT`), traits, randomness
(`FUNC_RANDOM_TRUE`, `FUNC_RANDOM_VALUE`), levels, stat extremes
(`FUNC_GET_LOW_STAT` / `HIGH_STAT`, which return a subject *index*), the
calendar (`FUNC_TODO_DAY`, `FUNC_IS_WEEKEND`), and location checks.

Exam-time predicates (`FUNC_IS_ENTER_UNIV_*`, `FUNC_GET_CURRENT_EXAM_GRADE`)
return 0 — the exam milestone is not built yet. Store and regional predicates
(`FUNC_GET_PREMIUM_LEVEL`, `FUNC_IS_PLAYED_JP`) return 0 deliberately.

To add a verb, pass `funcs:` to `ConditionEvaluator` or add to
`defaultFuncs`. A target with no handler evaluates false and is listed in the
dev panel's **Pack** tab, so it is visible rather than silent.

## Changers (effects)

```json
"changer": {
  "funcCode": "INCREASE_STAT",
  "args": [1, 150],
  "changes": [ { "type": "set", "target": "ENDING_SW", "value": 9 },
               { "type": "add", "target": "FRIENDSTEP", "value": 2 } ]
}
```

`changes` always runs — it is the switch bookkeeping (`set` assigns, `add`
increments, and each entry may carry its own `conditionSet`). `funcCode` is
the gameplay verb, with positional `args`.

All 55 verbs story 16 uses are implemented in `lib/engine/effects.dart`:
stats (`INCREASE_STAT`, `INCREASE_STAT_ALL`, `INCREASE_LOW_STAT`,
`INCREASE_RANDOM_STAT`, …), stamina and money, exp, items (`ACQUIRE_ITEM`,
`ACQUIRE_ITEM_RANDOM`, `REMOVE_ITEM_LIST`, …), traits, locations
(`UNLOCK_LOCATION`, `LOCK_LOCATION_EXCEPT`, `MOVE_LOCATION`, …), switches
(`SET_RANDOM_SWITCH`, `SET_VALUE_TARGET`), and `END_GAME`.

A `funcCode` with no handler does nothing and is reported in the dev panel.
`test/engine_test.dart` fails if the pack uses a verb the engine lacks, so
this cannot drift unnoticed.

## items.json

```json
{ "items": [ {
  "id": 1, "name": "Coffee", "kind": "consume", "scope": "global",
  "description": "All your fatigue melts down.",
  "effectText": "Stamina +25",
  "effects": [ { "type": "hp", "value": 25 } ]
} ] }
```

**`effects` is derived, not recovered.** The original keeps item effects in
compiled code, keyed by item id — they are in no JSON file. `tools/
item_effects.py` parses them out of `effectText`, the one machine-readable
description that does ship, which turns out to be written in a small
consistent sublanguage. All 177 items come out with structured effects or are
marked `"flavour": true` (18 of them describe no mechanic at all).

Treat `effects` as a good first pass, not gospel: `effectText` is shown
beside the parsed effects in the inventory screen precisely so a mismatch is
visible. Edit `effects` directly to correct one.

Effect shapes:

| `type` | fields | applies |
|---|---|---|
| `stat` | `subject`, `value` or `range` | on use |
| `hp`, `money`, `exerciseExp`, `partTimeExp` | `value` or `range` | on use |
| `hpMultiply` | `factor` | on use |
| `hpSet` | `range` | on use |
| `readCount` | `subject`, `value` | on use |
| `acquireItem` | `itemId`, `count` | on use |
| `acquireItemRandom` | `count` | on use |
| `unlockLocation` | `locationId` | on use |
| `cureTrait` / `removeTraits` | `trait` / `traitType` | on use |
| `studyEfficiency` | `subject`, `value`, `scope` | passive while held |
| `exerciseEfficiency`, `partTimeEarnings` | `value` or `percent`, `scope` | passive |
| `sleepEfficiency`, `hpCost` | `value`, `scope` | passive |
| `goalReward`, `acceptanceRate`, `surviveExhaustion` | `percent` / `chance` | not yet read by the loop |

`subject` may be a subject name, or `all`, `random`, `chosen`, `elective1`,
`elective2`, `lesson`.

`scope` restricts a passive to a place: `{"locationId": 2000}` or
`{"locationType": "study"}`.

`range: [lo, hi]` rolls uniformly. `duration` (`day`/`week`) and
`conditions` are carried on the effect but not yet enforced by the loop.

`kind` is `consume` (used from the inventory, then spent) or `normal` (held,
and read passively). `maxCount` caps how many you can hold.

## traits.json

`effectList` here **is** the original's own data — unlike items, traits ship
their effects as JSON. 11 effect types across 244 traits: `plusStat`,
`firstPlusStat`, `hpCost`, `partTimeJobMoney`, `exerciseExp`, `plusSleepHp`,
`firstPlusMoney`, `firstExerciseLevel`, `schoolStudyPlusStat`, `goalReward`,
`firstPlusPartTimeJobLevel`.

`first*` effects apply once at the start of a run. The rest feed
`GameState.passiveSum`. Several carry `conditions` on targets like
`LOCATION_ID`, `TICK`, `PREV_STUDY_SUBJECT` — the engine honours
`EXERCISE_LEVEL`, `PART_TIME_JOB_LEVEL`, `STUDY_LEVEL`, `LOCATION_ID`,
`TICK` and `DATE_INT`, and treats an unrecognised gate as open rather than
blocking the effect.

## levels.json

```json
{ "study":   [ { "level": 1, "name": "Student", "exp": 0, "plusStat": 0 } ],
  "exercise": { "levels": [ { "level": 0, "name": "3대 0", "exp": 0,
                              "weight": 1.0 } ],
                "locationEfficiency": [ { "locationId": 1000,
                                          "weight": 1.0 } ] },
  "partTimeJob": { "levels": [ ... ], "textByLocation": [ ... ] },
  "elite": [ ... ] }
```

`exp` is the cumulative threshold; the engine takes the highest tier whose
threshold is met. `weight` is the payout multiplier, so these tables are the
main lever on pacing. `elite` is loaded but not yet read by the loop.

## books.json

`{ "id", "name", "subject", "power", "doneCount", "hpWeight", "bookRank" }`.
`power` is the main input to study gain. `doneCount` and `hpWeight` are
carried but not yet read.

---

## What the engine does not do yet

Honest list, so the pack's shape is not mistaken for completeness:

- **Exam and endings.** `rules.exam.enabled` is false. A run ends on exam day
  and reports its final stats; scoring against the 137 universities / 3,358
  departments and the 57-ending table is the next milestone. Events that call
  `END_GAME` directly *do* set an ending.
- **Event sets.** 274 of 321 events carry an `eventSetId`, which in the
  original ties them to specific action or location triggers. The engine
  currently selects on `conditionSet` + `section` only, so a seeded sweep of
  200 full runs reaches 118 of 321 distinct events. Wiring sets to triggers is
  the biggest single win available in event coverage.
- **Presentation.** Sprites, backgrounds, BGM and sound effects are parsed
  and walked but not rendered or played — no art or audio ships in the pack.
  Speaker names need `npcs.json`, which is not in the pack yet, so dialogue
  shows unattributed.
- **Weekly goals, todos and sudden missions.** `ADD_TODO`/`REMOVE_TODO` are
  accepted and do nothing; the todo list is in `pack.json` but unused.
- **Effect `duration` and `conditions`** are parsed and stored but the loop
  does not expire or gate on them yet.


## Art

Pack art is referenced by a path relative to the art root
(`"backgrounds/park.png"`, `"character/portrait.png"`, `"ui/cookie.png"`).
It resolves in two steps:

1. `<pack directory>/images/<path>` — if the pack ships its own art, it wins.
2. `assets/images/<path>` — the bundled placeholders.

So a pack can replace any image without touching code, and a pack that ships
no art inherits the placeholders.

The bundled set is **temporary placeholder art lifted from KSS** by
`tools/copy_assets.py` (9 backgrounds borrowed from story 14, one character
portrait, one currency icon, 135 item icons). It is gitignored and local-use
only. Locations carry their backdrop as `image` in locations.json, written by
that same script.

Optional `events/system.json` provides host-triggered global graphs and their
`bindings`: `exhaustion` (10000000) and `exerciseLevelUp` (10000002). Keep them
separate from random story events. Dialogue supports the name variables and
inline formatting described in [EVENT-PRESENTATION.md](EVENT-PRESENTATION.md).
Run saves include `firstName` and `lastName`, defaulting to `pack.json.start`
when absent; the name selection UI remains on the character-selection to-do.

Stationery catalogs and four-piece sets live in `commerce.json`. The
`rules.json.stationery` section controls `drawWeights` by S/A/B/C rank,
`redrawCookies`, and `combineWeights` (one output-weight map per input rank).
Draws pick a rank before an item. Combination adds the two to four input maps before
sampling. These probability values are provisional, not recovered original odds;
see [STATIONERY.md](STATIONERY.md). The weekly Thursday award is free.


## Optional presentation.json

Generated locally by `tools/presentation_assets.py`; loaded by ContentPack when
present. `characters` and `npcs` map string IDs to `skeleton`, named `expressions`,
named `clothes`, and named `otherLayers` paths. `backgrounds` maps original event
asset paths to pack-relative art paths, and `badges` maps university IDs to crests.
Paths resolve under pack `images/` first and bundled `assets/images/` second.
This catalog is independent of gameplay data. Event nodes retain `standingId`,
`standingOff`, `standingExpression`, `standingClothes` and `otherLayerList`.
The builder always writes a valid `image` for each location, preferring originals
and using explicitly documented fallbacks where original files are unavailable.
See `TODO-FOLLOWUP.md` for regeneration and deployment.
