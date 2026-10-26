# Dialogue, stamina, workout XP and roll call

## Unknown speakers and Jian Lee

A positive speaker ID with `isHideSpeakerName` now displays `???` on a dark
gray nameplate, in dialogue and the log. Hidden narration with no person ID
keeps its unnamed presentation. A later ordinary line shows the authored name.
Missing/empty names for person IDs also use `???` rather than an internal ID.

Jian Lee has two authored actor IDs, 9 and 27. Both variants' body, expression
and outfit assets have been recovered (16 files) from their source URLs.
Reproduce with `presentation_assets.py --story 20 --fetch-npc 9 --fetch-npc 27`.

## Stamina and workout notifications

The user confirmed that stamina caps at 100. The old maximum-stamina formula
added four per workout level; that interpretation was wrong. Maximum stamina
now uses the pack's base cap (100 in both campaigns). Direct writes, dev edits,
recovery, new states and loaded saves all clamp to that cap, preventing
hidden extra stamina before the first action. Workout's existing action-cost
discount remains in effect.

EffectEngine compares workout and part-time levels before/after authored
changers and item effects, setting their existing notification switches when
XP crosses a level. After a story scene closes, GameScreen drains the pending
global level-up scenes without spending another action or using the random
event budget. The original closing node clears each switch. Action-generated
beforeEvents still play once, without duplicating another prebuilt level-up.

## Tick-12 dorm events: recovered gate correction

Original event 10, Hurry!, requires tick 12, no confinement, and being outside
the dorm. It moves the player to location 2000. Original event 11, Roll Call!,
requires event 10 complete, tick 12, being outside the dorm, no confinement,
and its other authored route/date/switch gates. These prerequisites are retained.
The first trip back is compulsory; the choice belongs to later eligible nights.
Thursday retains its authored prepare-for-tomorrow return option.

The blocker was `FUNC_ROUGH_TODO_DAY(10000) == 0`. The prototype incorrectly
returned days until the CSAT (for example 29), preventing ordinary roll calls.
The original native implementation is a boolean same-calendar-day predicate:

- Korean object pool `pp+0x30bb8` binds the function to `dtl` at `0xae1a2c`.
- Its target `0xae1a74` looks up the task, returns 0 for a missing task, compares
  normalized dates, checks the task's active flag, and returns integer 1 or 0.
- The normalization helper at `0x63637c` uses the pool strings `yyyyMMdd`,
  `DATE_`, and `00`; it discards the tick for this comparison.
- The old English assembly lists `Wrj` at `0xb74f7c`, but omits its body.

Local-only `references/recovery/RETRY-ROLL-CALL-NATIVE.md` records the Korean
binary hash and the disassembled predicate/helpers. For task-enabled packs,
the condition now returns 1 for an active task on today's date and 0 otherwise.
`FUNC_TODO_DAY` remains a day count; its partial-day rounding is still provisional.

Roll Call's node 11002 rearms fake reset event 12; the next morning resets
EVENT_11. Staying adds the authored negative point. A second missed roll call
uses SET_DOK_BANG and node 11024's ADD_TODO_2(5, title, 1, 14): the relative task
now supplies the next day's tick-14 confinement deadline, matching the adjacent
dialogue. It no longer silently omits the release task.

This repairs this specific gate and flow, not the unresolved overall scheduler.

## Verification

`test/retry_followup_test.dart` covers hidden/revealed names, dark nameplate,
all Jian layers, stamina at every level and loaded-save overflow, event XP and
one-time global notification, its actual GameScreen presentation, first Hurry
versus later Roll Call, both choices and the next-day reset, Thursday's option,
and second-miss confinement/deadline/release.
