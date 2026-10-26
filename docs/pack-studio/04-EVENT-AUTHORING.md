# Event authoring

How d30mode reads and runs event graphs, and what that means for an editor.
Facts are from code as of 2026-10-25 (citations are `file:line` in d30mode).
Where this disagrees with [../PACK-FORMAT.md](../PACK-FORMAT.md), this file
reflects the code; PACK-FORMAT's line saying an `event` target counts firings
is stale (it is a 0/1/2 state, see §6).

## 1. Files

| File | Shape | Notes |
|---|---|---|
| `events/events.json` (required) | `{events:[], nodes:[], speakers:[{id,name}]}` | One global node table for the whole pack (`pack.dart:1027-1043`). |
| `events/switches.json` | `{switches:[{name, value, korName?}]}` | Declared switches and their start values (`pack.dart:1044-1059`). |
| `events/sets.json` | `{eventSets:[{id, name, rank, weight}]}` | Storyline sets; rank `A` sets are "careers", one chosen per run. |
| `events/system.json` | `{bindings:{exhaustion, exerciseLevelUp, partTimeLevelUp: eventId}, events, nodes}` | Host-triggered sequences, not random events. Node lookup falls back here (`event_engine.dart:174`). |
| `events/events_female.json` | same as events.json | **Replaces** events.json wholesale for a female protagonist (`pack.dart:934-943`); must be complete. |

**Node IDs must be unique pack-wide.** Convention: `eventId * 1000 + n`
(tests assume `node.id ~/ 1000 == eventId`, `engine_test.dart:81`). Use it.

**Options link by `nextNodeId` only.** `boxId` and `nextBoxId` are carried
from the original's data but not read (the box fallback was removed on
2026-10-26). An option without a valid `nextNodeId` ends the event.

A missing numeric `id` on an event or node throws a raw `TypeError`, not a
friendly format error (`pack.dart:1030,1034`); a null `speakers[].name`
throws too. Validate before export.

## 2. Event record

| Field | Default | Meaning |
|---|---|---|
| `id` | required | Event ID; also the `EVENT_<id>` state key. |
| `name` | `''` | Title bar and log heading. |
| `rootNodeId` | -1 | Entry node. Missing/negative → never eligible. |
| `conditionSet` | null (true) | Eligibility gate (§4). |
| `isRandomDate` | false | `false` = scheduled ("pinned"): fires as soon as eligible. `true` = enters the weighted random draw. |
| `priority` | `middle` | Order among pinned events: `rules.events.priorityOrder`, default `[veryHigh, high, middle, low]`. |
| `rank` | `C` | Random-draw weight key into `rules.events.rankWeights`. |
| `section` | `none` | `none` or `one`..`six`: the sixth of the calendar it may fire in (`floor(dayIndex/totalDays*6)`). |
| `eventSetId` | null | Set membership; only rank-A sets gate (inactive unless chosen this run). |
| `isFake` | false | Hidden housekeeping event, auto-played without UI (§5). Must not need a choice. |
| `characterIdList` | `[]` | Non-empty = character event, eligible only for those characters, doesn't spend the daily cap. |

Carried but unused: `customPriority`, `description`, `showFullSize`, `text`.

**There is no built-in once-only rule.** Every shipped event gates itself with
`EVENT_<id> equal 0`. The editor should add that condition by default to new
events (with a visible "repeatable" toggle that removes it).

## 3. Nodes

Walk order per node (`event_engine.dart:157-313`): step cap check (2000 per
run) → missing node ends the event with a log note → evaluate the node's
`conditionSet` → if true: update portrait, apply `changer`, record endings and
acquired items → apply `backgroundImg` (always) → type dispatch.

| `type` | Behavior |
|---|---|
| `text` | Shows `text`. Gate false → shows `elseText` if present, otherwise skipped (changer skipped too). Blank text is skipped. Next: `nextNodeId`. |
| `option` | Gate false → skip to `nextNodeId`. Otherwise shows `optionText` (heading, default "What should I do?") + `text` (question) and the `options` whose own `conditionSet` passes. None left → falls through to `nextNodeId`. |
| `ifElse` | Tests its own `conditionSet` → `nextNodeIdIfTrue` / `nextNodeIdIfFalse`. Its changer runs only when true. Never shows text. |
| `last` | Ends the event, showing `text` (or `elseText` when the gate is false; silent if neither). |
| anything else | Presentation (`standing`, `background`, `eventBGM`, `soundEffect`, `loopSoundEffect`, `mainBGM`, `mainBGMMute`, `allMute`): applies effects/portrait, follows `nextNodeId`. Audio is currently ignored. |

Option record: `{text (default "..."), nextNodeId, conditionSet}`.

Other node fields read: `speakerId` (name chip only; ≤0 → "Me"; unknown →
"???"), `isHideSpeakerName`, `standingId` (who is drawn), `standingOff`,
`standingExpression` / `standingClothes` (default `defaults`),
`otherLayerList`, `backgroundImg` (key into `presentation.backgrounds`; never
used as a raw path), `continueTargetSwitch` (set to 1 when the scene closes on
this node).

**Portrait state:** the actor persists across lines until changed.
`standingOff` hides; `standingId > 0` sets a new actor; otherwise a non-default
expression/clothes restyles the current actor. `speakerId` never changes who
is drawn (`event_engine.dart:68-99`). With `rules.setup.genderSelection`,
`rules.setup.genderPairs` swaps NPC IDs by protagonist gender.

Carried, never read by the runner: `boxId`, option `nextBoxId`,
`actionChanger`, `eventSound`, `imgPath`, `isEmpty`, `index`, `nextLinkedBoxId`, `nextBoxIdIfTrue/False`, `isNullNode`,
`isCloseAndOpenPopupWhenContinue`, `rightNow`, `stopLocalLoop`,
`stopLocalMusic`, `pauseExceptLocal`, `startMain`.

**Quiz options:** if `optionText` + option labels contain `{문제}`, `{정답}`,
`{오답}`, `{MATH_…}` or `{ENGLISH_…}`, a question is drawn from `quizzes.json`,
blank options dropped and choices shuffled (`quiz.dart`).

## 4. Conditions

One recursive shape, used by events, nodes, options and `changes` entries:

```json
{ "operator": "and",
  "left":  { "conditions": [] },
  "right": { "conditions": [
    { "type": "defaults", "target": "EVENT_501", "targetType": "event",
      "compareType": "equal", "value": 0 } ] } }
```

`conditions` are ANDed; `left`/`right` combine with `operator` (`and`/`or`);
an empty side has no opinion; a null set is true. The `type` field is ignored.
`value` must be numeric. Unknown targets evaluate **false** (fail closed) and
are reported in the dev panel.

`compareType`: `equal` (also when absent), `notEqual`, `bigger`/`greater`,
`equalOrBigger`/`greaterEqual`, `smaller`/`less`, `equalOrSmaller`/`lessEqual`.

| `targetType` | `target` | Value |
|---|---|---|
| `event` | `EVENT_<id>` | 0 unseen, 1 playing, 2 finished |
| `eventSwitch` | switch name | its value; engine switches `TICK`, `DATE_PROGRESS`, `DATE_DAY`, `DATE_MONTH`, `DATE_WEEK`, `WEEKCODE` (Mon=1), `DATE_INT`, `MONEY` are read-only |
| `date` | `DATE_YYYYMMDDTT` | 1 on that day (and tick, if TT ≠ 00) |
| `location` | `LOCATION_<id>` | 1 if the player **is at** that location now (not "unlocked") |
| `func` | `FUNC_…` + `args` | pack predicate first (`mechanics.predicates`), then the built-in list below |

**Inline expression escape hatch:** a condition set with none of the keys
`conditions/operator/left/right` is evaluated as a mechanics expression (e.g.
`{"eq":[{"field":"characterId"},70]}`). Errors fail closed.

Built-in `FUNC_` predicates (`conditions.dart:183-315`, 48 handlers):

- Items: `ITEM_HAVE(id)`, `ITEM_COUNT(id)`, `ITEM_HAVE_LIST(ids…)`, `EXIST_ITEM_LIST(ids…)` (any), `ITEM_USE_COUNT(id)`, `IS_NO_ITEM_IN_POCKET`
- Traits: `TRAIT_HAVE(id)`, `IS_TRAIT_LIST(ids…)`, `TRAIT_HAVE_LIST(ids…)`
- Location: `IS_LOCATION_TYPE(type)`, `IS_LOCATION_LIST(ids…)`, `MOVE_LOCATION_EXCEPT(ids…)`, `BEFORE_/AFTER_MOVE_LOCATION`, `START_LOCATION_COUNT` (current location id)
- Random: `RANDOM_TRUE(pct=50)`, `RANDOM_VALUE(lo=0, hi=100)`
- Player/calendar: `IS_MALE`, `IS_FEMALE`, `IS_WEEKEND`, `GET_EXERCISE_LEVEL`, `GET_PART_TIME_JOB_LEVEL`, `GET_STUDY_LEVEL`, `GET_PLUS_STAT`, `GET_LOW_STAT`/`GET_HIGH_STAT` (subject index)
- Tasks/time: `TODO_HAVE(id)`, `TODO_DAY(id)`, `ROUGH_TODO_DAY(id)`, `AFTER_DAY_V2`, `AFTER_DAY("yyyy.MM.dd")`, `COMPARE_SWITCH(name)`
- Counters: `GET_GAME_COUNT` (1), `STUDY_COUNT`, `GET_SUCCESS_LENGTH`, `GOOD_DRAW_VALUE`
- Exam/enrollment: `GET_CURRENT_EXAM_GRADE(subjIdx)`, `IS_ENTER_UNIV(id)`, `IS_ENTER_UNIV_WITH_DEPART(u,d)`, `IS_ENTER_DEPART_LIST(ids…)`, `IS_ENTER_UNIV_THAT_RATE(pct)`, `IS_IN_CHARACTER_LIST(ids…)`
- Stubs returning 0: `GET_PREMIUM_LEVEL`, `IS_PLAYED_JP`, `IS_ENTER_UNIV_WITH_DEPART_TYPE`

(All prefixed `FUNC_`.) The editor's condition builder should offer these
with typed argument pickers, plus the pack's own predicates.

## 5. Changers

```json
"changer": { "funcCode": "INCREASE_STAT", "args": [1, 150],
             "changes": [ { "type": "set", "target": "ROUTE", "value": 2,
                            "conditionSet": null } ] }
```

`changes` run first (`add` adds; anything else sets; each may be gated). Then
`funcCode` dispatches: a `mechanics.callbacks` entry of that name wins, then
the built-in handler; unknown codes do nothing and are reported. Writing
`EVENT_<n>` sets that event's state; `mechanics.switchGuards` can pin a switch
to 0.

Built-in verbs (`effects.dart:342-611`):

- Stats: `INCREASE_STAT[subjIdx,n]`, `DECREASE_STAT[subjIdx,n]` (index into manifest `subjects`, clamped), `INCREASE_STAT_ALL[n]`, `DECREASE_STAT_ALL[n]`, `INCREASE_RANDOM_STAT[n]`, `INCREASE_LOW_STAT[n]`, `INCREASE_/DECREASE_TAMGOO_STAT[n]`, `DECREASE_TAMGOO_HIGH_STAT[n]` (subjects 3 and 4), `SET_RANDOM_SUBJECT`
- HP/money/exp: `INCREASE_HP`, `DECREASE_HP`, `INCREASE_MONEY`, `DECREASE_MONEY`, `INCREASE_EXERCISE_EXP`, `INCREASE_PART_TIME_JOB_EXP`
- Items: `ACQUIRE_ITEM[id,count=1]`, `ACQUIRE_ITEM_RANDOM[ids…]`, `REMOVE_ITEM[id,count]`, `REMOVE_ITEM_LIST`, `REMOVE_ITEM_RANDOM`, `REMOVE_ITEM_ONCE`
- Traits: `ACQUIRE_TRAIT[id]`, `ACQUIRE_TRAIT_RANDOM[ids…]`, `REMOVE_TRAIT[id]`, `REMOVE_BAD_TRAIT_RANDOM`
- Locations: `UNLOCK_LOCATION[id]`, `UNLOCK_LOCATION_ALL`, `LOCK_LOCATION[id]`, `LOCK_LOCATION_EXCEPT[ids]`, `MOVE_LOCATION[id]`, `LOCK_/UNLOCK_MOVE_LOCATION`
- Switches/blocks: `SET_RANDOM_SWITCH[name,lo,hi]`, `SET_VALUE_TARGET[dest,"+="|"-="|"=",src]`, `SET_DRAW_VALUE`, `DO_DRAW`, `ADD_CHALLENGE_VALUE[name,n]`, `ENABLE_BLOCK[id]`, `DISABLE_BLOCK[id]`
- Tasks (with `rules.tasks.enabled`): `ADD_TODO[id,title,date]`, `ADD_TODO_2[id,title,days,tick?]`, `REMOVE_TODO[id]`
- Run control: `END_GAME[code,label]`, `SHOW_ENDING[title,continuationSwitch]`, `START_SAT`
- No-ops: `SIREN`, `GO_WEB_BROWSER`, `HACKING_LESSON`, `ALIVE_ART`, `SLEEP`, `PART_TIME_JOB`, `EXERCISE`, `STUDY`, `START_LOCATION_COUNT`, `DEFAULT_FAIL_EVENT`

A changer has one `funcCode`. To do two things in one beat, chain nodes, or
define a pack callback (a step list; see MODULAR-PACKS.md) and call it.

## 6. Event state and selection

`EVENT_<id>`: 0 never seen, 1 while playing (set at start), 2 finished (every
exit path). Content can read and write it like a switch.

When the game looks for an event (after each action tick, the evening slot,
the next morning, exhausted ticks; exam day and endings use a pinned-only path):

1. **Automatic fake events:** eligible `isFake` events are auto-played (character fakes always; others if `rules.events.executeFakeEvents`).
2. **Character events:** lowest-ID eligible event whose `characterIdList` has the selected character. Doesn't use the daily cap.
3. **`pick`:** if `eventsFiredToday >= rules.events.maxEventsPerDay` (default 3) and scheduled events don't bypass the cap → nothing. Pinned eligible events (`isRandomDate:false`) sorted by priority then ID → first wins. Otherwise roll `rules.events.randomEventChancePerTick` (default 0.12); on success, weighted pick among eligible random events by `rankWeights[rank]` (default 1).

Eligible = not fake, character match, set active, root node exists, section
matches, `conditionSet` true (`event_engine.dart:405-420`).

Opening: `rules.events.openingEventIds` play in order at run start. **A new
pack needs at least one opening event** to introduce anything; the Workshop
template leaves its graph empty.

## 7. Text

Applied to `text`, `elseText`, option labels, `optionText`: `{token}`
substitution, then a small markup renderer.

Tokens, in resolution order: `mechanics.textMacros[name]`; quiz answers;
`이벤트스위치(SW)` (switch value), `과목(i)` (subject name), `NAME_TRAITS_IN_LIST(…)`,
`GET_ITEM_OF_SWITCH(SW)`; `ENTERED_UNIV_NAME`, `ENTERED_DEPART_NAME`;
`FIRST_NAME`/`이름`, `LAST_NAME`/`성`, `PLAYER_NAME`/`성이름`, `EXERCISE_LEVEL`,
`PART_TIME_JOB_LEVEL`, `STUDY_LEVEL`. Unknown tokens stay literal.
Substituted values are escaped.

Markup: `<b> <strong> <i> <em> <bi> <u> <br> <p>` and entities
`&amp; &lt; &gt; &quot; &apos; &nbsp; &#N; &#xH;`. No colors, links or images.
Unknown tags render literally. See [../EVENT-PRESENTATION.md](../EVENT-PRESENTATION.md).

## 8. Editor implications

- **Canvas model:** one card per visible beat (`text`, `option`, `last`), a
  diamond for `ifElse`, presentation nodes folded into the next card as badges
  (portrait/background/sound). Edges: `nextNodeId`, one per option, true/false.
- **New event defaults:** `EVENT_<id> equal 0` gate, `rootNodeId` = first
  node, node IDs `id*1000+n`, `isRandomDate:true`, `rank:"C"`,
  `section:"none"`, terminated by a `last` node.
- **Branch hygiene warnings:** text node with a gate and no `elseText` (silently
  skipped); option node where every option can be gated off; `ifElse` with a
  changer (runs only on true); unreachable nodes; dangling `nextNodeId`;
  cycles (allowed, but warn: 2000-node cap).
- **Fake events** must be choice-free; validate.
- **Preview:** render text with tokens resolved against a sample state and
  the markup above; show the speaker chip and composited portrait.
- **Switch hygiene:** read-only engine switches can't be written; declare
  every switch the pack uses (required for action gates, recommended always).
