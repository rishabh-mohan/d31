# Current implementation checkpoint — 25 October 2026

Read this checkpoint before dated historical notes. [TODO.md](../TODO.md) tracks per-item status; [the branch integration report](BRANCH-INTEGRATION-2026-10-25.md) records the original assignments and remaining blockers. Code/tests are the implementation source of truth; original-game references establish targets, not proof that a feature exists.

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

Earlier branch integration: `bc9e5a7`; Home/account/debug checkpoint: `77a0660`. Later clarified mechanics are recorded in CLARIFIED-MECHANICS-2026-10-25.md. Full suite: **318 passing tests**; Flutter analysis: **no issues**. Five Nord-size branch/shop renders passed; the expanded stationery grid was visually checked at 393×873. The original corner complaint and specific saved-character thumbnails still merit user device confirmation.

The final profile APK was installed with data-preserving replacement on Nord N30 serial `7c2c1cc8` and cold-launched successfully. No fatal/Flutter application errors appeared in the sampled startup log; unrelated Android wakelock permission messages were present. Hardware rendering is required for normal play; never leave software rendering enabled after a temporary diagnostic.

Local installed-artifact source: `build/app/outputs/flutter-apk/app-profile.apk`, 385414826 bytes. Local SHA-256: `0a22f2cbf4eea2bbde09b2effd82fdac30acef7e687dd82452b13033a98e19d0`. This records the local APK used for installation, not a separately pulled device checksum.

Build/test first, then install the profile APK with `adb install -r`. Use the absolute Windows Android SDK path and PowerShell for adb. **Do not adb-push packs**: the app seeds/reseeds editable JSON when the APK's bundle stamp changes. Manual pushes create shell-owned files that can shadow future updates. Preserve saves/account data; do not clear the app or delete pack/image overrides as a routine update step. See CLAUDE.md's current Device notes for exceptions and recovery.

Latest validation logs: `build/clarified-final-tests.log`, `build/clarified-final-build.log`, `build/clarified-final-render.log`; earlier integration logs remain under build/; review images: `build/branch-review/`. Generated packs, reference captures and imported art remain local-only under existing ignore rules.
