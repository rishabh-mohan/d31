# d30mode project guide

Read these project documents before changing behavior:

1. `docs/CURRENT-STATE.md` — latest integrated behavior, test/deployment evidence and limits.
2. `TODO.md` — task IDs, checked implementations, partial work and evidence blockers.
3. `CLAUDE.md` — durable operational notes, user scope decisions and paid-for traps.
4. `docs/BRANCH-INTEGRATION-2026-10-25.md` — original interrupted assignments and their outcomes.

Use the relevant reference before a feature change: `docs/MAIN-MENU-REFERENCE.md`
and `docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md` for Home/account; `docs/STATIONERY.md`
for stationery; `docs/RETRY-YEAR.md` for campaign mechanics; `docs/IMPLEMENTATION-EVIDENCE-REQUESTS.md`
for unresolved rules. Original screenshots/data, recovered native behavior and
prototype choices are distinct evidence categories.

After implementing work, update the relevant TODO entry and feature documentation.
Refresh CURRENT-STATE when integrated behavior or validation changes. Preserve
historical evidence with clear dates and superseding links. Mark partial work
1R/2R/3R and state what remains; DONE requires implementation and verification.
Do not infer completion from a screenshot, branch merge or passing unrelated tests.

All original branch tips are merged. Their retained worktrees contain older
recovery drafts; do not copy whole older files over main. Keep unrelated pending
research/code edits intact. A14 Practice Block insertion and I03 Hiking Gloves'
extra yield remain evidence-blocked; consult the current report before guessing.

Use hardware-rendered profile builds for normal phone play/performance checks.
Run appropriate Flutter analysis/tests, build the APK, then install with `adb install -r`
using PowerShell/absolute Windows SDK paths. Do not routinely adb-push packs or
clear app data; the APK bundle-stamp mechanism refreshes editable pack JSON.
Preserve saves, account data, same-run stationery and the stationery name-fit cache.

User scope decisions: fresh stationery each new run, currently unlocked prototype
setup collections, no leaderboard, no inventory-XP level-up scene, Elite/other ports
deferred, book-completion item gacha reminder-only (39).
