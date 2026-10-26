# Installing and testing a pack in d30mode

Facts from `lib/engine/content_source.dart`, `lib/ui/home_screen.dart` and
`lib/ui/dev_panel.dart` as of 2026-10-25.

## 1. Where d30mode looks for packs

Editable pack roots, in order (`content_source.dart:49-70`):

| Platform | Roots |
|---|---|
| Windows/macOS/Linux | `packs/` and `../packs/` **relative to the process working directory** (launched from the repo: the repo's `packs/`), then `<Documents>/packs/` |
| Android | `<external files>/packs/` = `/sdcard/Android/data/dev.d30mode.d30mode/files/packs/`, then the app documents dir `packs/` |

A pack is discovered when `<root>/<dir>/pack.json` exists and the directory
name matches `^[A-Za-z0-9_-]+$`. **The pack ID is the directory name**; keep
`pack.json` `id` identical. Bundled packs (`kss16`, `kss20`) come from the
APK's asset manifest.

The loader reads only its known file list (`ContentPack.allFiles`,
`pack.dart:1217`) plus `images/**` for art. **Other files and folders are
ignored**, so editor sidecars (e.g. `.studio/`) are safe inside a pack.

## 2. ID rules

- Don't reuse a bundled ID (`kss16`, `kss20`). On Android a bundled ID's
  editable copy is overwritten from the APK whenever the bundled content
  changes (bundle-stamp reseeding), so edits would be lost.
- An unbundled ID loads straight from its directory: no seeding, no stamp.
- Catalog IDs (items, traits, characters…) may overlap with other packs; IDs
  carry no behavior across packs.

## 3. Install

**Desktop (fastest loop):** write the pack to `d30mode/packs/<id>/` (that
directory is gitignored) and start or restart d30mode from the repo.

**Android:** copy the folder to
`/sdcard/Android/data/dev.d30mode.d30mode/files/packs/<id>/`. Use PowerShell
for adb (Git Bash rewrites `/sdcard/...` paths):

```powershell
$adb = 'C:/Users/stewc/AppData/Local/Android/Sdk/platform-tools/adb.exe'
& $adb -s <serial> push .\mypack /sdcard/Android/data/dev.d30mode.d30mode/files/packs/mypack
```

Caveat: files pushed by adb are owned by `shell`, and the app can't overwrite
them. That's fine for a third-party pack the app never reseeds, but the dev
panel's Rules tab can't save `rules.json` there. (The "never adb-push" rule in
CLAUDE.md is about the bundled KSS packs.)

Then restart d30mode. Pack IDs are discovered when Home loads; nothing
re-scans at runtime. The pack appears as a card on **Select Game Mode** using
`pack.json` `name` and `description`.

## 4. Iterate

- Dev panel (slider icon) → **Pack** → **Reload from disk** re-reads the JSON;
  start a new run to use it (a run in progress keeps its pack). Reload doesn't
  clear image caches and doesn't re-apply the borrowed college catalog.
- **Events** tab: list/filter events, "eligible now", play any event.
- **Rules** tab: edit `rules.json` in place.
- **Engine gaps seen this run:** unknown funcCodes, unknown condition targets,
  bad inline expressions, undeclared block gates. Empty only means the run
  hasn't hit a problem yet.

A pack without `colleges.json` borrows the default pack's catalog so it still
ends on the CSAT; set `rules.exam.enabled: false` to skip the exam.

## 5. Known hazards for third-party packs (engine follow-ups)

1. **One bad pack breaks Home.** All packs load in a single try/catch
   (`home_screen.dart:103-111`), so a malformed third-party pack shows the
   error state instead of skipping that pack. Fixing this in d30mode (load
   each pack independently, list failures) is a prerequisite for comfortable
   iteration. Until then, the editor's validation is the safety net.
2. **Desktop discovery depends on the working directory.** An explicit roots
   setting or command-line flag would make it predictable.
3. **Image cache** isn't invalidated on reload (05-ASSETS.md §1).
4. **Raw TypeErrors** for missing IDs (04 §1) instead of a `PackFormatException`
   naming the file.

## 6. Automated checks to mirror

d30mode's tests show what "loads and plays" means. See
[06-VALIDATION.md](06-VALIDATION.md) for the list. The strongest is the seeded
simulation in `test/engine_test.dart` (~line 1550): 200 complete runs, taking
random actions, auto-advancing events and picking the first choice, which
assert termination and no unknown condition targets. With the shared engine
package (02-ARCHITECTURE.md), the editor can run the same harness on the open
pack.
