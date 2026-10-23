# D30 Mode — knowledge brief & handoff

A clean-context starting point for a fresh chat. Covers the goal, the system, and
every skill / concept / tool needed to (a) understand Korean Student Simulator's
"one-month (D-31)" mode well enough to inform a clean-room build, and (b) build
that mode from scratch in Flutter.

---

## 1. What this project is

- **Goal:** build an original "D-31 / one-month" stat-raiser **from scratch in
  Flutter/Dart** (`projects/d30mode/`), using Korean Student Simulator (KSS) as a
  design reference. Personal use; intended eventually as a proof-of-concept to
  pitch the KSS devs for collaboration.
- **Why Flutter:** KSS itself is Flutter (verified — see §3), so its data schema
  and assets are a 1:1 reference and can be used as local stand-ins while
  prototyping.
- **Two legitimate workstreams:**
  1. **Build** — the `d30mode` Flutter app (`lib/main.dart` v0 exists: title →
     Start → 31-day loop → outcome).
  2. **Understand** — reverse-engineer KSS's *own* data/logic (it's unprotected)
     to learn how its D-31 mode, events, and items work, and port those *ideas*
     (not assets/code) into the clean-room build.

## 2. Scope & boundaries (read this)

- **In scope / legitimate:** the KSS **Korean build** (`com.yeopcha.studentmaker`,
  Flutter) has **no anti-tamper protection** — translating it in place and
  studying its data/logic are fine. The clean-room Flutter build is your own code.
- **OUT of scope — do not pursue:** a separate sister title (Job Seeker Simulator,
  `com.basakansoft.jobmaker`, Unity/IL2CPP) is protected by **PairIP**, the devs
  declined both a clean build and the translation, and that line is **parked**.
  Defeating that protection is off the table. This brief is only about the
  unprotected KSS work and the from-scratch Flutter build.

## 3. The target system (measured)

KSS Korean build = **Flutter / Dart AOT**:
- `config.arm64_v8a.apk` → `lib/arm64-v8a/libflutter.so` (engine) + `libapp.so`
  (Dart AOT snapshot, obfuscated).
- `base.apk` → `assets/flutter_assets/…` — standard Flutter bundle:
  `AssetManifest.bin`, `FontManifest.json`, and `assets/…` holding PNG, MP3, WAV,
  and JSON. Audio e.g. `assets/audio/minigame/flappy_bird/*.mp3`.
- Campaign/content is **data-driven JSON** (events, nodes, choices, conditions,
  items) that the engine interprets — this is the key fact: you can learn and
  reproduce behavior from data, not just binary.

## 4. Skills needed

### A. Flutter / Dart app development (for the build)
- Dart language; Flutter widgets, `StatefulWidget`/`setState`, `Navigator`.
- `pubspec.yaml` assets/deps; `dart:convert` for JSON.
- Likely packages as it grows: `audioplayers` (sound), `provider`/`riverpod`
  (state), `shared_preferences` (saves), `jenny` (Yarn Spinner port, branching
  dialogue), `flame` (only if a real-time minigame is added).
- Build/deploy: `flutter create`, `flutter run` to the rooted Nord N30 over adb.

### B. Flutter AOT reverse engineering (to understand KSS)
- **AOT snapshot model:** Dart compiled into `libapp.so`; strings/objects live in
  an object pool, loaded via ADRP/ADD + LDR instruction pairs.
- **Tools already run and stored** (in `korstu4CLAUDE/private-build/korean-base/
  analysis/`): **blutter** (annotated ARM64 disasm: `asm/`, `pp.txt`, `objs.txt`)
  and **AOTopsy** (`export-dart` pseudocode in `decompiled/app/app.dart`, plus
  call graph / function table / string xrefs in `aotopsy/`).
- **Reading pseudocode:** obfuscated names (`sub_xxxx`), recovered control flow,
  `try/catch`, typed locals. Enough to trace a feature's logic.

### C. Game-data RE (the high-value, low-risk layer)
- **Event/node schema** (shared across KSS and the sister game): top-level
  `{"events":[…], "nodes":[…]}`; events have `rootNodeId`, `conditionSet`,
  `eventSetId`; nodes have `text`, `elseText`, `optionText`, `conditionText`,
  `translatedText*`, plus identifier fields (`standingExpression`,
  `standingClothes`, `firebaseId`) that are **NOT** display text.
- **The guard concept:** display text vs. internal identifiers. Translating a
  lookup key that happens to be Korean breaks the game (cost 154 broken audio IDs
  once). See `tools/text_rules.py` in either repo.
- **Items:** map to **effect families** already in the engine's item registry;
  new items = new combinations/params of existing effects.

### D. Dynamic analysis (rooted Nord N30 + pseudocode together)
- **Frida** on the rooted phone to hook functions at runtime and watch real
  control flow — the way to turn static pseudocode guesses into observed facts.
- Especially for D-31's never-completing resource sync (see §6): hook the
  orchestrator and the file-list checker, log which branch/condition loops.
- Starter reference: `korstu4CLAUDE/private-build/korean-base/analysis/
  blutter_frida.js`.

### E. Android / tooling basics
- APK = ZIP (splits: base, config.arm64_v8a, asset_pack). `adb` push/pull,
  `pm install`, verify by SHA-256 not "Success".
- Python 3.12 with: `UnityPy`, `androguard`, `capstone`, `pyelftools`
  (installed). `blutter` built in `korstu4/tools/blutter`; AOTopsy binary.

## 5. Key concepts to internalize

- **Data-driven engine:** most content is JSON the engine plays; authoring new
  events/blocks = writing data in the schema, not patching the binary.
- **AOT object pool & single-instruction patches:** behavior can be changed by
  flipping one instruction (e.g., skip a branch) — used for legit fixes in KSS.
- **Verify-by-hash; fix the bundled asset, not the runtime copy** (runtime copies
  get overwritten on startup).
- **D-31 "sync completion" gate:** the mode won't start until a resource-sync
  check reports done; understanding that check is the crux (§6).

## 6. What's specifically known about D-31 (a.k.a. story 16)

From `korstu4CLAUDE/private-build/korean-base/STORY16.md` (full detail there):
- The mode hangs during resource sync — never records completion; no crash, no
  log. Pre-existing; a new game on it has never worked on this build.
- Pseudocode map: orchestrator **`sub_af073c`** has a `try/catch` whose handler
  ends in `continue` — the mechanical shape of the silent-retry hang. It calls a
  **file-list checker `sub_af6b78`** and a version gate `sub_af634c`.
- Many causes were tried and ruled out (missing data files, missing media, a
  0-byte manifest, version markers). One untested hypothesis: the `inGameImgs`
  zip extracts to a **nested** path while everything else is flat, so completion
  is never recorded.
- **Best next attack (needs the rooted phone):** Frida-trace `sub_af073c` /
  `sub_af6b78` live to see the exact failing condition, then either satisfy it
  with data or patch the checker to pass. For the clean-room build this is
  reference only — you implement your own sync/day-start logic.

## 7. Learning path

`korstu4CLAUDE/LEARNING-PATH.md` — 8 ordered modules (easy→hard) that teach each
RE skill above using the existing code as the textbook, with a "reproduce it
yourself, no AI" task per module so the skill becomes genuinely yours.

## 8. Repo / doc map

- `projects/d30mode/` — the clean-room Flutter build. `lib/main.dart` (v0),
  `README.md` (run steps + roadmap), this brief.
- `korstu4CLAUDE/` — KSS Korean-build translation + all RE artifacts.
  - `CLAUDE.md` — durable rules/traps for that project.
  - `private-build/korean-base/analysis/` — blutter + AOTopsy output.
  - `private-build/korean-base/STORY16.md` — the D-31 investigation.
  - `private-build/korean-base/tools`/scripts — guard, patch scripts, pipelines.
- (Parked, out of scope) `jobseekersimulator-en/` — the PairIP title; `STATUS.md`
  marks it closed. Ignore for this work.

## 9. Environment

- Windows 11; Git Bash + PowerShell. Python at
  `C:\Users\stewc\AppData\Local\Programs\Python\Python312\python.exe` (use
  `PYTHONIOENCODING=utf-8` for Korean).
- adb at `%LOCALAPPDATA%\Android\Sdk\platform-tools`.
- **Physical Nord N30 (CPH2513, arm64, Android 14), rooted** — connect with plain
  `adb -s <serial>` (it enumerates on the default adb server).
- **Flutter SDK is NOT yet installed** — install it before building the d30mode
  app (`flutter doctor`). Android toolchain comes from Android Studio.

## 10. Immediate next steps

1. Install Flutter SDK; `flutter run` the d30mode v0 on the Nord N30 to confirm
   the toolchain end-to-end.
2. Move the inline event in `lib/main.dart` into `assets/events.json` in KSS's
   node/choice schema, parsed with `dart:convert` — makes "new events" authorable
   as data.
3. Add an item/effect registry (stat deltas first).
4. (Optional, reference) Frida-trace KSS's D-31 sync to understand the original
   mechanic before reimplementing your own.
