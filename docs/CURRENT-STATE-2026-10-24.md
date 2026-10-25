# Current review checkpoint — 2026-10-24

This checkpoint includes the newer work in the shared tree. Older milestone
notes describe their state at the time; use this page and RETRY-YEAR.md for
current coverage. Code and tests remain the source of truth.

## Included in this update

- Retry Year male/female protagonist selection, the corresponding shipped
  English script, and restoring that script when continuing a save.
- Calendar arithmetic across daylight-saving changes; November date-gated
  events can match on a US-timezone phone.
- Recovered friend-route/action gates, singing and mock-exam predicates,
  promotion proficiency notes, and a persistent Promotion Exam Kit display.
- Imported global character events, filtered to the selected character;
  broader character parity remains incomplete.
- Graduation Exam before the CSAT, applications, enrolment and ending scenes
  in both campaigns. The admissions catalog is imported; scoring and admission
  probabilities remain a fitted prototype model, not recovered formulas.
- Working quiz question/answer macros and prize paths using 68 English school
  exam questions. The dedicated Quizmaster bank is still unrecovered; this is
  the shared-bank fallback, not a claim that the requested original was found.
- Trait-gated dialogue is skipped when its condition fails unless it has an
  authored alternate line. Fast-forward stops on the last line for the player
  to close. The stamina outline paints over its fill. Raised button faces use
  the painted face bounds so pressing does not expose a band above the face.
- Raised event portraits, corrected El Niño/La Niña labels, imported NPC art,
  and the dev panel's character/expression showcase.

The prior fixes remain: a 100 stamina cap, event-driven level-up scenes,
unknown-speaker nameplates, tick-12 first dorm return followed by later roll
calls, smooth stamina animation, and a provisional 5% stationery upgrade chance.

## Remaining limits

The overall event dispatcher/priority ordering, exact CSAT scoring and admission
odds, dedicated Quizmaster bank, some crafting/item callbacks and the formal
ending gallery/rewards are not fully recovered. Passing simulations establish
that the implemented flows run, not complete parity with the original game.

See RETRY-YEAR.md for native addresses and distinctions between recovered rules
and fitted values; RETRY-FOLLOWUP.md records the dorm/task-date evidence.

## Deployment

Build and test the current tree, then install the APK with `adb install -r`.
Update both editable packs, including new `admissions.json`, `quizzes.json`,
`events/events_female.json`, and the existing events/items/rules/presentation
files. Replacing only rules.json would leave old phone content active.

Keep existing saves and pack image overrides. Do not clear application data or
delete the editable packs. The imported placeholder art is bundled in the APK;
generated packs/art remain local-only and gitignored.

Validation: Flutter analysis reports no issues. The full Flutter suite passes
all 214 tests, including 200 seeded complete runs. All 35 generated pack JSON
files parse (17 in story 16, 18 in Retry Year). The old fixed switch count in
the catalog test was updated from 225 to 235 after verifying the newly merged
global character switches.

Latest installation on Nord N30 (`7c2c1cc8`): **profile APK, hardware Skia**
(Impeller disabled; software rendering is not enabled). Installed SHA-256
matches the local artifact: `bb4421f40f525874ed9f5c167da934f422c2790054e91aef8dc04f497bfe383e`.
APK size: 373907866 bytes. Both editable packs were updated in the
preceding deployment; this follow-up also verifies the corrected Retry Year
rules file. Existing saves and image overrides were retained.

Retry Year's unverified studyWeight=9 override has been removed: unbuffed
power-5 starter books again preview and grant +15 in both campaigns. The
22-test campaign suite, including this new regression, passes; analysis is
clean. The 214-test full-suite result above is the previous combined baseline.
Recovered exam thresholds are unchanged; progression tuning remains open.

The whole-game FPS regression came from leaving a screenshot session's software
renderer enabled. Hardware rendering has been restored and a profile build
installed. The user confirms the whole game is much smoother; see
[PERFORMANCE-REGRESSION.md](PERFORMANCE-REGRESSION.md). The original stationery
name-fit cache and image-provider caching remain intact.

Installation report: build/nord-profile-deployment-verification.json.
Previous editable packs: build/nord-packs-before-*.

## Study efficiency follow-up (2026-10-24)

The user confirmed efficiency must add one stat per unit. The trait reader
previously chose the alternate scaled extraStat (Genius of the Century: 9)
instead of storyStat (3). It now prefers nonzero storyStat and retains explicit
extraStat when no story value is present. Setup effect labels use the same
reader. Passive-item NORMAL_STAT units no longer receive the separate x3
conversion; consumable stat grants are unchanged.

Both campaigns now preview and grant +18 for a power-5 starter book with
Genius of the Century, compared with +15 without it. All 114 selected
engine/campaign/setup tests pass, including 200 seeded runs; analysis is clean.
The updated profile APK and both editable items.json files are installed on
the Nord and their SHA-256 hashes match local artifacts. Hardware Skia cold
launch succeeded (993ms). Saves and existing accumulated stats were retained.
Evidence: build/efficiency-tests.log, build/efficiency-analysis.log and
build/efficiency-profile-build.log.
