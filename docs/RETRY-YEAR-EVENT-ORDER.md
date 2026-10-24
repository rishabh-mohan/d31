# Retry Year event ordering: unresolved

Rechecked the old projects on 2026-10-24 after the user reported that events
still play out of order. This remains open; the earlier lifecycle tests do
not establish fidelity to the original scheduler.

## Evidence reviewed

- `../korstu4/mod-decoded/assets/assets/stories/20/event/events.json`:
  older English event graph, including conditions and effect links.
- `../korstu4CLAUDE/EXPANSIONS.md`, sections 9b and 10, and
  `event-sets-report.json`: the extra-campaign pipeline selects weighted event
  sets (picker address `0x74b4dc`). These establish availability, not a
  scene-by-scene placement rule for Retry Year. Synthetic fixes for campaigns
  42/45 must not be treated as story-20 evidence.
- `../korstu4/private-build/ENGLISH_DLC_LOCALIZATION.md`: prerequisite repairs
  concern detective campaigns 42/45, not Retry Year. They are not reusable
  placement rules.
- `../korstu4CLAUDE/private-build/korean-base/analysis/aotopsy/string_refs.jsonl`:
  `isRandomDate` and `customPriority` references identify serialization/model
  fields, without establishing when eligible scenes are dispatched.
- The Korean native opening/confinement callbacks and graph extracts already
  recorded by `tools/extract_retry_lifecycle_evidence.py` establish individual
  effects and prerequisites; they do not recover the whole scheduler.

## Known gaps in the rebuild

- `EventEngine.pick` classifies every non-random-date event as scheduled, then
  sorts by priority and numeric ID. Numeric ID is not verified placement.
- `tools/build_pack.py` removes source `index`; the engine does not use source
  `customPriority`. Their original scheduling semantics remain unresolved.
- Retry Year's same-tick chaining and daily-cap bypass are reconstruction
  choices. A prerequisite becoming true does not prove the next event should
  immediately play at the same tick. In particular, 211 -> 6 -> 7 establishes
  eligibility dependencies, not recovered timing between those scenes.
- Passing tests currently show that the implemented reconstruction runs;
  they cannot prove correct original chronology.

No authoritative general placement rule was found in the reviewed material.
Per the user's instruction, log this and move to other TODOs. No new ordering
patch or guessed event-by-event placement was applied in this follow-up.
To resume, recover the native dispatch/comparator and lifecycle call sites,
or obtain an original playthrough with dated/ticked scene transitions.
