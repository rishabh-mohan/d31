# Current implementation checkpoint — 25 October 2026

Read this checkpoint before dated historical notes. [TODO.md](../TODO.md) tracks per-item status; [the branch integration report](BRANCH-INTEGRATION-2026-10-25.md) records the original assignments and remaining blockers. Code/tests are the implementation source of truth; original-game references establish targets, not proof that a feature exists.

## Items, traits, acceptance, badges and setup ownership — 25 October 2026

Four parallel branches (feat/setup, feat/acceptance, feat/items, feat/traits)
are merged on main. Details and evidence labels: EFFECTS-REFERENCE.md
("Item effects" and "Pack-owned trait abilities, second pass"), DDAY-FLOW.md,
START-GAME-INITIALIZATION.md ("Ownership checkpoint").

- **Setup ownership (user request):** badge step lists only colleges the
  account has enrolled in; trait step lists only owned trait copies (xN shown,
  not consumed). Account rule `setupRequiresOwnership` (default on); dev-panel
  Traits switch. Empty steps stay passable; characters remain unlocked.
- **Acceptance (user decision):** traits 47 (x1.08), 74 (+3), 89 (+1), 40
  (+1 provisional) and held items 3004/3007/3011 modify the final acceptance
  chance (multiply, add points, clamp). The standard-score conversion is gone;
  displayed, stored and rolled rates agree.
- **Badges:** a data-driven test exercises all 136 badges per campaign. Fixed
  `firstPlusStat` tamgoos granting every subject (4 badges).
- **Items:** use is refused for items with nothing to apply. Prevention items
  are graph-handled (tests added). New Predicted Grades (Mock Exam Paper),
  Abilities (Bizarre Author's Note), Recipes (80011, I02) views and a Scouter
  check; Strawberry Milk provisional +50. 15 story-16 items stay unobtainable
  (Korean-only events, TODO 121); Focus/Modified Potion await timed effects
  (TODO 122).
- **Traits:** new generic hooks/ability types in pack mechanics implement
  Master of Notes, Bully, Talented Singer, Exam Dreams, Latecomer, Salt and
  Light, Scrooge, Stocks Manager, Lactose Intolerant, Sunstroke/Heat Stroke and
  Customer's Lover/Curse. Unrecovered rates are configurable provisional
  defaults. Jailbreaker/Delinquent/Cooking Master/Favourite Student are
  graph-handled.

Validation: both packs regenerated on main; analysis clean; 490 tests pass
(build/merge-analyze.log, build/merge-tests.log).

**Backwards-compatibility sweep (2026-10-26, user decision).** Removed every
migration and fallback kept for older saves, History records, account files,
pack builds and internal APIs: eventCounts→eventStates, openingComplete/task/
D-Day stage inference, the legacy shared-wallet move (and `sharedWallet`),
`rewardFinal`, `walkRolledAt`, packId→kss16 defaults, History records without
snapshots and `csatStandardScore`, `renameCount` inference,
`countByDepartment`, `admissions.json`, the meanTotal/sdTotal curve, the
flat specialDays date, `nextBoxId`/`nodesByBox`, `openingContinuationSwitches`,
the category-from-storyOnly guess, `InventoryScreen`, and dead rules keys.
Old files that no longer parse are skipped by the save/record stores.
Analysis clean; 485 tests pass (build/sweep-tests.log).

## Trait combination probabilities

The supplied probability PDF replaces the provisional 25% upgrade rule with
seven published rank distributions. User clarification supplies the omitted
mixes: AAC uses ABB, ABC uses BBB, ACC uses BBC. Draws and the Combine Rates
dialog share the same table; input order is irrelevant. Existing S-only,
combine-lock and campaign-pool rules remain. See
[TRAIT-COMBINATION-RATES.md](TRAIT-COMBINATION-RATES.md) for the complete table
and provenance distinctions. The 22 focused tests pass, including 3,300
deterministic combines across all campaigns; analysis is clean.
Profile APK SHA-256 `6f638fb3…` was installed on Nord N30 `7c2c1cc8` with
data preserved. Startup and hardware Impeller succeeded; the complete rates
panel was visually checked on the phone with no clipping or sampled app
layout/asset/fatal errors. No owned traits were consumed by this check.

## Puzzle backgrounds (TODO 102)

A finished puzzle becomes the Home background, from its green tag in a
collection or the Use as Background button in its detail panel. Home, the
account pages and MM-02's scene-only view (which now shows the selected
puzzle's name) all draw the selection, which is saved in the account.
Event-limited puzzles (story 0: Cookie Parade levels, the Full Focus Package)
count as held, because nothing here can earn their pieces.

Full-screen art: the original ships only the Amnesia desk and downloads the
rest on first display from Firebase Storage `wallpapers/<id>.png`
(`sub_aa702c`), caching it as `app_flutter/assets_images_wallpaper_image_<id>.png`
with a `wallpaper_version_<id>` preference. The device log shows the Firebase
Storage SDK at work (`StorageTask`, App Check placeholder token) but the SDK
logs no paths. On 2026-10-25 the user opened every wallpaper their account
owns in KSS 1.29.3 on the rooted Nord, and 11 were pulled from that cache:
180–183, 200–204, 1014 and 1015, all 2629×4776 except 202/203 (1124×2048
pixel art). `tools/import_wallpapers.py` bundles them from
`references/recovery/wallpapers-1.29.3/` (local only), and
`build_account_catalog.py` now reads the 1.29.3 catalog there, which adds
event puzzles 1013–1015, and flags each puzzle that has bundled art. The
remaining eleven (wallpaper1–6, 1003, 1010–1013) were subsequently recovered
on the same date with the user's explicit authorization, through the phone
app's existing signed-in Firebase Storage client. A temporary runtime probe
captured a real request for `wallpapers/wallpaper181.png` in bucket
`student-maker-en.firebasestorage.app`; unsigned HTTP requests returned 403.
All eleven missing PNGs were downloaded without exporting credentials,
validated, and bundled. All 23 catalog entries now have full-screen art;
Event Limited's existing full-art filter therefore admits all seven event
puzzles. This supersedes the earlier thumbnail fallback/server-request scope.
Recovery results, hashes, dimensions and a contact sheet are retained locally
in `references/recovery/wallpapers-1.29.3/`. The temporary diagnostic service
was stopped and removed; original app saves were preserved. BlueStacks'
older modded build hit a missing-wallpaper6800 catalog error; its temporary
catalog edit was restored. The equip interaction itself is the project's own;
E19 (how the original shows equipped versus owned) is still uncaptured.

Prior deployment validation: 405 tests pass and analysis is clean. The profile APK
(SHA-256 `7c12f1ad…`, matched on the device) is installed with data
preserved on Nord N30 `7c2c1cc8`.

Recovery validation: all 23 image files and catalog flags verified; the
eleven new PNGs passed decode, dimension and SHA-256 copy checks. The 17
focused account/puzzle tests pass and Flutter analysis is clean. The new
profile APK (SHA-256 `72135ebff6dac981a076bc77952fab67c86179c5659aa09539985993d688c9c5`)
was inspected for all 23 images and the catalog, then installed on the Nord
with `adb install -r` and data preserved. Cold launch returned Status: ok,
hardware Impeller initialized, and sampled app logs showed no missing-asset
or Flutter fatal errors. Home, Amnesia collection and puzzle categories were
visually checked; the recovered Karaoke wallpaper1013 also appeared as the
background. Local screenshots are with the recovery evidence.

## School names and History recreation

Eighty Global/Taiwan school labels are corrected in account and badge catalogs
through a tracked shared overlay; IDs/effects/ranks/colors are unchanged.
See [UNIVERSITY-NAMES.md](UNIVERSITY-NAMES.md) for sources and explicit identity
inferences. Both campaign badge files and the account catalog were regenerated.

History cards open the reference-style Info / Score Card / University Apps
panel. Newly completed runs retain compact, detached snapshots of EXP, Gold,
traits, equipped stationery, college display data and application outcomes.
Records without a snapshot are no longer read (no backwards compatibility, 2026-10-26). The confirmed
first-university enrollment reward now pays two cookies once per school and
survives account reloads; setup collections are now ownership-gated (see above). Further details and
limits: [HISTORY-DETAILS.md](HISTORY-DETAILS.md).

Validation: 333 tests pass; the final UI adjustment also passed six focused
tests and three rendered tabs at reference size, with layout checks at 320,
390 and 430 logical pixels. Analysis is clean. The profile APK was installed
with data preserved on Nord N30 `7c2c1cc8` and cold-launched successfully.
Home, History and all three legacy-record detail tabs were visually checked on
the awake phone; populated new snapshots were verified in rendered tests.
Sampled app logs show no fatal/Flutter/pack-format errors. Source: `16a8f87`.

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
Impeller rendering initialized. That initial deployment's visual check was
limited by the sleeping phone; automatic approval review rejected lock-screen
dismissal, and no unlock/security change was performed. The user subsequently
reported checking the build; the later History update was checked on an already
awake phone.
TODO 39 includes shop refresh notification, reroll previews and their screenshots
as reminder-only work alongside book-completion item gacha.

## Integrated on main

- Home and captured Settings/Mail Box/Profile/Charging/Store destinations are connected. Username and preferences persist; first rename is free, subsequent changes cost nine cookies. Real purchases, ads, invitations and mail delivery remain unavailable. Notices and the seasonal destination still lack references.
- Cookies and refresh tokens share the account wallet in both generated packs. Starting balances are one-time grants. Debug → State → Wallet edits these balances with direct entry or quick steps, saving account changes. Fresh stationery per run remains an intentional, separate policy.
- All five original branch tips were already merged. Remaining recoverable drafts have now been completed on main. Original worktrees are retained as recovery copies; do not reapply their entire older files over current Home/wallet changes.
- Evening scenes hold date, stamina reset and trait aging until they close; the following morning event is delivered. Exhaustion checks eligible events on each skipped action tick in both campaigns; dialogue pauses the fill. Lost slots grant no action rewards. The ordinary evening slot runs before rollover.
- Walking Enthusiast uses a serialized once-per-tick movement guard (prototype anti-farming rule). Multitasker's authored STAT_1 pays three stat points to a deterministic random subject on Study and previews the bonus. Street Performer pays 600 Gold on scoped Karaoke singing. Earlier trait and item fixes remain; unspecified proc/discount rates are configurable reconstructions.
- Day-menu Score Card displays the retained CSAT result. New History records store per-subject scores and open the same card. Current mock-exam callbacks do not generate per-subject score cards.
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

Local installed-artifact source: `build/app/outputs/flutter-apk/app-profile.apk`, 385677158 bytes. Local SHA-256: `dee0ce3b0e884b139e7043f21c74d9d6836896361721d13fc3f9ca21ef0d7f12`. This is the local APK installed, not a separately pulled device checksum. Source commit: `16a8f87`. APK inspection verified all 80 corrected labels in the account and both badge catalogs, plus the configured two-cookie first-enrollment reward. Data-preserving installation, cold launch and legacy History tab checks succeeded.

Build/test first, then install the profile APK with `adb install -r`. Use the absolute Windows Android SDK path and PowerShell for adb. **Packs are not bundled**: stage and `mv` them into the app packs folder (see CLAUDE.md Device notes). Preserve saves/account data; do not clear the app or delete pack/image overrides as a routine update step. See CLAUDE.md's current Device notes for exceptions and recovery.

Latest validation logs: `build/history-full-tests.log`, `build/history-focused-final.log`, `build/history-render-final.log`, `build/history-analysis-final.log`, `build/history-profile-build.log`, `build/history-install.log`, `build/history-launch.log`, `build/history-startup.log`; rendered snapshots: `build/history-review/`; phone checks: `build/history-phone*.png`. Earlier logs remain under build/. Generated packs, reference captures and imported art remain local-only under existing ignore rules.
