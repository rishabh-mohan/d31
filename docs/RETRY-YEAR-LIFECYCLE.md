# Retry Year opening and day lifecycle

## Evidence

The English story-20 event graph is in the existing asset tree. The Korean
native pseudocode is in `korstu4CLAUDE/private-build/korean-base/analysis/`.
`tools/extract_retry_lifecycle_evidence.py` records source hashes, the original
graphs and the relevant native function bodies under ignored references/recovery.
Do not publish that generated file or the recovered images.

- Event **1**, node **1006**, calls `SHOW_ENDING` with continuation **START**.
  The native handler `Bwl -> sub_be91d0` presents the ending and writes its
  second argument through `sub_adcb58` with tagged integer 2 (Dart integer 1).
  It is a continuation, not a request to terminate this new run.
- Event **169** requires START=1 and contains the mother scene. Event **2**
  requires event 169 finished and contains the academy welcome and scripted
  placement test. Event **3** is pinned to October 14 and establishes Suin and
  the Reflection Room. These reconstruct the opening order **1,169,2,3**.
- Node **3017** calls `SET_DOK_BANG(1)`; **3018** adds task 5 due at
  **2024.10.14.14**. `xwl -> sub_be99c0` writes DOK_BANG_ON and switches
  availability between location 20007 and 1000/2000/20002/20003/20004.
- Event **4** releases the player at tick 14 once the confinement task expires;
  its final nodes call `SET_DOK_BANG(0)`. October 15's event **211** introduces
  the class. It unlocks **6**, which unlocks **7**. These gates do not establish
  when the original dispatcher runs the next scene; same-tick timing is unverified.
- Hidden events **5** and **12** reset EVENT_4 and EVENT_11. They contain dummy
  presentation text and must execute without showing a dialogue panel.

The manifest's generic `startLocationId` is 1000. It does not describe the
playable first day established by the opening. The pack therefore overrides
the initial playable location to 20007, disables first-day lessons and declares
the opening event sequence. This is an explicit reconstruction from the graphs,
native confinement handler and the user's observed original behavior.

## Implementation

The prologue plays automatically before preparation or action spending. It
bypasses the random-event daily cap, retains tick zero and saves after each
completed scene. Its progress and task deadlines survive saves. Old first-day
saves can recover START without repeating the opening ending or its rewards;
already advanced saves do not replay the first-day prologue automatically.

While confined, movement is locked and school lessons are suppressed. Task 5
expires at its authored evening slot. Evening events finish while the clock
still reads tick 14; only then does the calendar roll over. New-day scheduled
dialogue is checked before the first action, with immediately eligible follow-up
beats chained at the same tick. Scheduled events bypass the random-event cap.

Hidden housekeeping events execute once per eligible state. Content writes to
EVENT_n update the real tri-state event map, rather than an unused switch. The
ordinary random-event cap still applies. These lifecycle options are enabled
for Retry Year in rules.json; the Standard campaign keeps its existing policy.

Mum, Headmaster Kim, Suin, the Dorm Master, the Lower Class teacher and Taeyang
now have their recovered portrait layers. Reproduce with
`python tools/presentation_assets.py --story 20 --fetch-opening`.

## Limits

The user reports that event ordering remains incorrect. The overall scheduler
has not been recovered. See `RETRY-YEAR-EVENT-ORDER.md` for the old-project
review and the distinction between eligibility and placement. Same-tick chaining
below is implemented behavior, not verified original chronology.

The opening placement test is the authored narrative, not an invented question
minigame. The original SHOW_ENDING reward/gallery popup is not reproduced; its
continuation switch is implemented. Promotion/graduation exam and admissions flows are now implemented; their
fitted scoring and remaining special callbacks are described in RETRY-YEAR.md.

The confinement task's exact timestamp and expiration are recovered. FUNC_ROUGH_TODO_DAY is now recovered as a same-day boolean check, not a day
count; see RETRY-FOLLOWUP.md. Partial-day FUNC_TODO_DAY rounding remains
provisional. Tests cover first-day release and later demerit confinement,
without establishing every early-release branch.

## Verification

`test/retry_year_test.dart` checks every opening beat, the mother and placement
test lines, no time/refresh cost, confinement and action gating, saved opening
continuation, legacy START recovery, first evening release, delayed rollover,
next-morning chained introductions, hidden event resets and portrait files.
A widget regression checks that the opening appears before any action tap.
Local rendered review files cover Mum, Headmaster Kim and Reflection Room play.
