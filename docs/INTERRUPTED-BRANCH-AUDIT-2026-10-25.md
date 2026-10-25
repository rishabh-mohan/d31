# Interrupted branch audit — 2026-10-25

All five branch tips are ancestors of main (71c0b34); no committed branch work is missing. However, merging branch tips did not include the following uncommitted work. These drafts remain in their original worktrees; they have not been incorporated into the phone build.

| Worktree | Uncommitted work | Assessment |
| --- | --- | --- |
| a-engine | Untracked assets only | No pending tracked source edits. |
| b-flow | game.dart, game_screen.dart, engine_test.dart | A11 evening-scene rollover deferral and morning-event handling; not integrated or verified. |
| c-traits | game.dart, state.dart, compiled_traits_test.dart | Walking Enthusiast stamina reward and serialized once-per-tick guard; not integrated or verified. |
| d-ui | day_menu.dart, untracked zz_probe_test.dart | Stationery empty-slot border refactor is incomplete: references `_EmptyStationerySlot` with no definition. Do not merge as-is. |
| e-account | state.dart (formatting), home_pages.dart, home_screen.dart, untracked account_menus.dart and account_menus_test.dart | M01 Settings/Mail/Profile/Charging/Store draft; not integrated or verified. Existing paid rename remains; free first rename was not implemented. |

Untracked assets are present across worktrees and were left untouched.

## Merged work versus TODO status

Merged commits cover A01–A09, A12, L01/L02/L04, stamina-free Time Jumper/Energizer, hold-on effects (Stubborn/I will not falter/Pet Rock), store discounts (Limited Offer/Solitary Gourmet), Developer coffee effects, shared-wallet plumbing, and UI 79/91/93/94. This is a commit inventory, not a claim of complete original-game parity. TODO.md still lists many of these as unchecked and its difficulty index predates the merges.

A11 and Walking Enthusiast are draft-only. TODO 92 (events during exhaustion progression), other unimplemented traits/items, and the remaining account/evidence backlog must not be inferred complete from the merges. TODO 93's merged commit only stretches the submenu header; it does not prove all banner art problems are fixed.

## Deployment validation

Static analysis passed. Initial suite: 292 passed, four wallet tests failed because they still assumed per-run refresh tickets. Claude had changed both generated packs to shared refresh tickets immediately before interruption. Wallet assertions now reflect the shared default and retain coverage for switching refresh back to per-run. No draft branch source was silently included.

Deployment completed: profile APK built successfully (366.8 MB), installed with `adb install -r` on Nord serial 7c2c1cc8, and cold-launched successfully. No fatal/Flutter errors appeared in the sampled startup log. App data was not cleared. All seven wallet tests pass after assertion updates; the remaining 292 tests passed in the full-suite run. Draft branch changes remain untouched.

## Home takeover — 2026-10-25

Supersedes the e-account draft-only and free-first-rename statements above: the Home account-menu drafts have now been integrated into main's working tree, preserving the merged Home fade/full-page header changes. Settings, mailbox, profile/rename, Charging and Store routes are connected. First rename is free and persisted. Shared overlay headers and aspect-preserving image decoding were corrected after phone-size rendering. The original e-account worktree remains untouched as a recovery source. Other branch drafts remain unintegrated. See TODO.md's Home follow-up for remaining limitations.

Validation for this Home takeover: 302/302 regression tests pass; `flutter analyze` reports no issues. Seven reference-size renders are in build/home-review (Home, Settings, Profile, Charging, Mail, Store, Puzzles). Visual checks identified and fixed full-width orange title bars and confirmed undistorted category banners. The Home test render may show pack-loading state; on-device startup is checked separately.

On-device validation: updated 367.3 MB profile APK installed successfully with data-preserving replacement, cold-started on Nord 7c2c1cc8, and Home fully loaded with the existing 21-cookie/41-refresh wallet. Captured build/home-review/nord-home.png confirms the connected buttons, username and reference-style layout. No fatal/Flutter errors appeared in sampled startup logs. TODO 95 remains for user confirmation of specific saved-character thumbnails after the shared aspect-ratio fix.

## Main integration completed — 2026-10-25

See [the final branch report](BRANCH-INTEGRATION-2026-10-25.md), which supersedes the earlier draft-only assessments. Remaining recoverable b-flow/c-traits/d-ui changes are completed in main, with 311 passing tests and clean static analysis. A14 Practice Block insertion and I03 Hiking Gloves' extra yield remain explicitly evidence-blocked; no original worktrees were discarded.
