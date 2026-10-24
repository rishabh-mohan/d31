# Event presentation

## Host-triggered workout event

The global English catalog supplies event `10000002`, **Exercise Level Up**:

1. A sudden burst of energy rushes in me…!
2. GYAAAAAAAH...!
3. Exercise Level became Level `{EXERCISE_LEVEL}`!!!

`tools/build_pack.py` copies its reachable graph into `events/system.json`
with binding `exerciseLevelUp`. A workout crossing a level threshold queues
it in `ActionOutcome.beforeEvents`. `GameScreen` plays these before exhaustion,
the ordinary event, or a day-end summary. An ordinary workout without a level
increase does not trigger it. Global dialogue does not spend the daily random
event allowance. The final changer clears `EXERCISE_LEVEL_UP`.

The final `REMOVE_TRAIT_FROM_EXERCISE` callback is an explicit no-op while trait
effects are parked. It does not grant extra EXP, duplicate level benefits, or
change the existing one-point-per-level stamina discount.

## Player identity and text

Runs save `firstName` and `lastName`; legacy saves and new runs default to
`pack.json.start`. My Info and event variables share this identity. The English
catalog still uses these Korean placeholders:

| Token | Substitution |
|---|---|
| `{이름}` / `{FIRST_NAME}` | First name |
| `{성}` / `{LAST_NAME}` | Last name |
| `{성이름}` / `{PLAYER_NAME}` | First name, space, last name |
| `{EXERCISE_LEVEL}` | Current exercise level |
| `{PART_TIME_JOB_LEVEL}` | Current part-time level |
| `{STUDY_LEVEL}` | Current study level |

`engine/event_text.dart` expands text, `elseText`, choice labels, and final
messages when the runner reaches them. Unknown variables remain visible for
future implementation. Names are escaped before markup parsing so a name
containing angle brackets or ampersands remains literal text.

`ui/event_text.dart` renders the catalog's `<bi>` (bold and italic) and `<b>`
tags as styled spans. It also supports nested `strong`, `i`, `em`, `u`, line
breaks, paragraphs, and named/numeric text entities. This is a limited inline
text renderer, not a general HTML browser. Unknown tags remain literal. The
same widget handles dialogue, both choice layouts, and log entries; formatting
is preserved and control tags are not displayed. Existing 100ms fast-forward
and mandatory choice stops remain unchanged.

## To-do: character selection screen

- Add first-name and last-name inputs at the reference's step 5/5 and save
  them into the run identity. The current title-to-game flow still uses pack
  defaults; adding a name selection screen is deliberately deferred.
- Preserve the fixed Korean-name token substitutions when wiring that screen.
- Reference: `references/screenshots/07-setup-05-player-name-005149.jpg`.

`test/event_presentation_test.dart` checks name expansion across all text paths,
legacy/new save behavior, nested styles and literal names, repeated workout
level-ups, same-action exhaustion, and formatted dialogue/choices/log rendering.


## Choice questions and layered NPCs

The choice window renders the node's `optionText` heading and the current
expanded dialogue/question above its buttons. Long content scrolls within the
window. Do not cover the only copy of the question with a generic title.

`presentation.json` supplies NPC skeleton/expression/clothing paths and event
background mappings. EventRun retains NPC appearance while the player speaks;
positive speaker/standing IDs update it, and standingOff hides it. The same
Portrait widget composites player layers in setup, gameplay and My Info.
See `TODO-FOLLOWUP.md` for source recovery, fallbacks and regression checks.
