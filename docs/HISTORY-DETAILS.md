# History detail recreation — 2026-10-25

References: ORIGINAL-GAME-FUNCTIONS.md sections 3/13/15,
ORIGINAL-GAME-FOLLOWUP-2026-10-24.md F17/F18, MAIN-MENU-REFERENCE.md MM-09 and
the D-Day recording handoff. These describe original behavior, not proof of
complete parity. The user's reference named ORIGINAL_GAME_LAYOUT.md was clarified
to mean ORIGINAL-GAME-FUNCTIONS.md and its companion original-game documents.

History cards now open `RecordDetails` instead of a generic text dialog. The
near-full-height cream/orange panel starts below the History header, with a red
corner close, centered title and brown divider. Its orange bottom bar expands
the selected University Apps / Info / Score Card label. Switching tabs preserves
the record and scroll state and performs no game/wallet transaction.

Info centers a peach card with proportion-preserving portrait, name, study
level/EXP, Gold, retained deviation and exercise/work level progress. Colored
subject chips sit above a split region: scrollable polarity-colored traits and
the four equipped stationery cards in a two-column grid. The shared stationery
widget and name-fit cache are reused. These are the completed run's equipment,
not equipment carried into a new run.

University Apps shows the retained enrollment certificate (school-colored
header/border, crest watermark, portrait, president/seal footer) and individual
Accepted/Rejected application cards. Score Card reuses the retained result;
it never recalculates scores from current stats or admission tuning.

New records capture a compact, detached `details` snapshot: money, study EXP and
next threshold, exercise/work progress, trait display data, equipped stationery
data and application outcomes/college display data. No entire content pack is
embedded. JSON round-trip retains the snapshot, independent of later catalog
edits or live-run changes. Every record carries the snapshot; a record file
without one (or without `packId`) fails to parse and is skipped (no
backwards compatibility, 2026-10-26).

Limits: photo upload/sharing remains F05; the source student-number generation
rule is unknown and no fabricated number is shown. Acceptance-rate percentages
were not retained, so application cards show an unavailable value rather than
reconstructing historical odds. Exact original score-card typography and missing
mock-exam per-subject snapshots remain outside this pass.

M05 follow-up: first enrollment at each school now pays the user-confirmed two
cookies, configured in `content/kss/account-rules.json` and exported to the account
catalog's `rewards`. Existing saved enrollment counts prevent repeat payment
after restart. No retroactive award is invented for previously counted schools.
Counts already supply earned achievement ownership; the current unlock-all setup
prototype is preserved. An optional ownership-gated setup remains future work.
Superseded 2026-10-25: setup now offers only enrolled schools' badges and owned
traits (`setupRequiresOwnership`, see START-GAME-INITIALIZATION.md).

Validation logs: `build/history-focused-final.log`, `build/history-render-final.log`,
`build/history-full-tests.log`, `build/history-analysis-final.log`. Renders:
`build/history-review/tab-0.png`, `tab-1.png`, `tab-2.png`.
