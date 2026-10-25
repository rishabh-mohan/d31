# Current implementation checkpoint — 25 October 2026

Read this checkpoint before dated historical notes. [TODO.md](../TODO.md) tracks per-item status; [the branch integration report](BRANCH-INTEGRATION-2026-10-25.md) records the original assignments and remaining blockers. Code/tests are the implementation source of truth; original-game references establish targets, not proof that a feature exists.

## School names and History recreation

Eighty Global/Taiwan school labels are corrected in account and badge catalogs
through a tracked shared overlay; IDs/effects/ranks/colors are unchanged.
See [UNIVERSITY-NAMES.md](UNIVERSITY-NAMES.md) for sources and explicit identity
inferences. Both campaign badge files and the account catalog were regenerated.

History cards open the reference-style Info / Score Card / University Apps
panel. Newly completed runs retain compact, detached snapshots of EXP, Gold,
traits, equipped stationery, college display data and application outcomes.
Legacy records remain readable without inventing missing details. The confirmed
first-university enrollment reward now pays two cookies once per school and
survives account reloads; setup collections remain unlocked. Further details and
limits: [HISTORY-DETAILS.md](HISTORY-DETAILS.md).

Validation: 333 tests pass; the final UI adjustment also passed six focused
tests and three rendered tabs at reference size, with layout checks at 320,
390 and 430 logical pixels. Analysis is clean. Profile deployment is in progress;
the artifact record below still describes the preceding modular build.

## Modular pack mechanics

Custom trait/character abilities, special blocks, callbacks, predicates, text
macros and progression hooks now live in optional pack `mechanics.json`.
KSS definitions are tracked in `content/kss/mechanics.json` and exported by
the generator; custom pack IDs and blocks need no campaign-specific engine
branches. The standalone `examples/packs/workshop` demonstrates authoring and
same-ID isolation. Independent editable packs are discovered on desktop and
Android. See [MODULAR-PACKS.md](MODULAR-PACKS.md) for the format and limits.

Validation: both campaigns regenerate; analysis clean; 323-test full suite
(including 200 seeded complete runs) plus four additional custom regressions,
covering 327 unique tests. Logs are listed in the authoring guide.
Profile APK built and installed with data-preserving replacement on Nord N30
`7c2c1cc8`; cold launch returned Status: ok and the app process remained alive.
Sampled app logs contain no fatal, Flutter or pack-format errors. Hardware
Impeller rendering initialized. Visual confirmation remains pending: the phone
was asleep, so its screenshot was black. Automatic approval review rejected
dismissing the lock screen; no unlock or security change was performed.
TODO 39 includes shop refresh notification, reroll previews and their screenshots
as reminder-only work alongside book-completion item gacha.

## Integrated on main

- Home and captured Settings/Mail Box/Profile/Charging/Store destinations are connected. Username and preferences persist; first rename is free, subsequent changes cost nine cookies. Real purchases, ads, invitations and mail delivery remain unavailable. Notices and the seasonal destination still lack references.
- Cookies and refresh tokens share the account wallet in both generated packs. Starting balances are one-time grants; legacy saves migrate through the shared-wallet plumbing. Debug → State → Wallet edits these balances with direct entry or quick steps, saving account changes. Fresh stationery per run remains an intentional, separate policy.
- All five original branch tips were already merged. Remaining recoverable drafts have now been completed on main. Original worktrees are retained as recovery copies; do not reapply their entire older files over current Home/wallet changes.
- Evening scenes hold date, stamina reset and trait aging until they close; the following morning event is delivered. Exhaustion checks eligible events on each skipped action tick in both campaigns; dialogue pauses the fill. Lost slots grant no action rewards. The ordinary evening slot runs before rollover.
- Walking Enthusiast uses a serialized once-per-tick movement guard (prototype anti-farming rule). Multitasker's authored STAT_1 pays three stat points to a deterministic random subject on Study and previews the bonus. Street Performer pays 600 Gold on scoped Karaoke singing. Earlier trait and item fixes remain; unspecified proc/discount rates are configurable reconstructions.
- Day-menu Score Card displays the retained CSAT result. New History records store per-subject scores and open the same card. Legacy total-only records are not backfilled; current mock-exam callbacks do not generate per-subject score cards.
- Stationery cards reserve an inset, clip inner fills and paint the outline last. Empty hub slots use the same border approach. Draw and combination results use rainbow/gold/blue/gray confetti, ignore touches and honor reduced motion. The original name-fit cache remains intact.
- My Info/Home fades, full-page Achievements, full-width account headers and aspect-preserving image decoding are integrated. TODO 95 records the squished save portraits; the likely shared decoding cause is fixed, pending confirmation of those specific thumbnails during playtesting.

The earlier Retry Year gender scripts, DST-safe dates, native friend/roll-call gates, proficiency kit, calendar, dialogue/portraits, CSAT/applications/endings and quiz fallback remain. See [the historical checkpoint](CURRENT-STATE-2026-10-24.md) and [Retry Year](RETRY-YEAR.md) for their evidence.

## Latest clarified mechanics

[The current rule/evidence record](CLARIFIED-MECHANICS-2026-10-25.md) supersedes
older A14/I03 blocker notes. Practice Block availability persists until authored
removal. Hiking Gloves may duplicate the exact scavenged herb at 20%, excluding
a Ginseng Digger reward on that gather. Both gender scripts are regenerated.
The in-run shop now exposes a saved, one-cookie Refresh action before purchases;
its first reroll removes one offer, later rerolls keep the count, and Saturday
restores the initial configured stock/count. The original offer pool is still
provisional. Unknown trait proc rates remain provisional after local review.

## Remaining work and evidence boundaries

- A14/I03 are now implemented under [the user clarifications](CLARIFIED-MECHANICS-2026-10-25.md). The gloves rule is explicitly provisional and overrides the imported graph; native parity is not claimed.
- The in-run shop now has Saturday-boundary restock and saved one-cookie pre-purchase rerolls. First reroll removes one offer; later rerolls retain that count. Its original offer pool/weights/full prices remain unrecovered.
- Unassigned parity backlog remains in TODO.md: hidden event dispatcher, exact scoring/admission odds, dedicated Quizmaster bank, missions, audio/haptics, crafting/character abilities, broader History/reference recreation and unrecovered collection rules.
- Inventory XP must not trigger a level-up scene (A13 withdrawn). Elite and other campaign ports remain deferred. Book-completion item gacha (39) is reminder-only; Master of Notes' workbook is a separate reward source.
- Passing tests establish implemented behavior, not complete parity or recovered probabilities. Keep screenshot observations, native findings and prototype rules distinct.

## Verification and deployment

Earlier branch integration: `bc9e5a7`; Home/account/debug checkpoint: `77a0660`. Later clarified mechanics are recorded in CLARIFIED-MECHANICS-2026-10-25.md. That earlier checkpoint passed 318 tests and clean analysis; latest modular validation is recorded above. Five Nord-size branch/shop renders passed; the expanded stationery grid was visually checked at 393×873. The original corner complaint and specific saved-character thumbnails still merit user device confirmation.

The final profile APK was installed with data-preserving replacement on Nord N30 serial `7c2c1cc8` and cold-launched successfully. No fatal/Flutter application errors appeared in the sampled startup log; unrelated Android wakelock permission messages were present. Hardware rendering is required for normal play; never leave software rendering enabled after a temporary diagnostic.

Local installed-artifact source: `build/app/outputs/flutter-apk/app-profile.apk`, 385546086 bytes. Local SHA-256: `cd8343b2b8c20354951e25b222130880e1dde1be415ad4dbe568a41602784060`. This is the local APK installed, not a separately pulled device checksum. Mechanics source commit: `fb231c9`. Both bundled mechanics files were verified inside the APK (22 KSS16 / 23 KSS20 pack callbacks). Data-preserving install and cold launch succeeded; on-device visual verification remains pending while the phone is asleep.

Build/test first, then install the profile APK with `adb install -r`. Use the absolute Windows Android SDK path and PowerShell for adb. **Do not adb-push packs**: the app seeds/reseeds editable JSON when the APK's bundle stamp changes. Manual pushes create shell-owned files that can shadow future updates. Preserve saves/account data; do not clear the app or delete pack/image overrides as a routine update step. See CLAUDE.md's current Device notes for exceptions and recovery.

Latest validation logs: `build/modular-final-tests.log`, `build/modular-custom-tests.log`, `build/modular-gates-tests.log`, `build/modular-analysis-final.log`, `build/modular-profile-retry.log`, `build/modular-install.log`, `build/modular-launch.log`, `build/modular-startup-final.log`; earlier integration logs remain under build/; review images: `build/branch-review/`. Generated packs, reference captures and imported art remain local-only under existing ignore rules.
