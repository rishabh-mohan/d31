# d30mode: learn the project and explain it in interviews

Prepared October 26, 2026, for a Purdue CS freshman whose strongest language is
Java, with competitive programming experience around USACO Gold and coursework
through roughly half of CS182. This is a layered study guide, not a claim that
you already know everything in it.

Your stated contribution: you directed Codex and Claude Code, tested the app,
and chose mechanics before delegating more comparison and documentation work.
The agents generated the implementation. That is the starting point for the
resume and interview language below.

## How to use this guide

1. Read sections 1–4 for the overview and vocabulary.
2. Work through sections 5–11 with the source open. Trace actual values instead
   of memorizing descriptions.
3. Use sections 12–15 to prepare for interviews and choose a role-specific story.
4. Complete at least two exercises in section 16 before presenting the project
   as technical experience you can defend in detail.

Links point to files in this repository. The code is the implementation source
of truth. [CURRENT-STATE.md](CURRENT-STATE.md) records dated validation; older
research documents may describe behavior that later decisions superseded.

## 1. The project in one minute

d30mode is an unofficial Flutter recreation of parts of *Korean Student
Simulator*, centered on 31-Day Mode and Retry Year. The player manages a student
over a limited calendar: study, work, exercise, sleep, travel, make story choices,
take an exam, apply to universities, and enroll. An account layer retains
collections and run history across playthroughs.

The interesting software is a **data-driven simulation engine**. JSON content
packs describe locations, events, characters, items, traits, rules, and special
abilities. Dart code interprets those definitions and changes the current run.
Flutter displays the results and handles player interaction.

The project also involved **reverse engineering (RE)**: investigating an existing
program to infer its behavior. Extracted assets, event graphs, native-code
analysis, screenshots, recordings, and playtests supplied different kinds of
evidence. Some rules were recoverable; others remain approximations or explicit
user choices.

An accurate opening you can adapt:

> I directed an AI-assisted recreation of a mobile simulation game using Flutter
> and Dart. My work centered on requirements, mechanics decisions, and hands-on
> testing. Codex and Claude Code generated the implementation. The technical
> core is a JSON-driven engine for actions, branching events, and persistent
> progression, supported by Python tools that transform recovered game data.

After studying, add a specific system you can actually trace. Your strongest
initial angle is likely **QA plus requirements and behavior reconstruction**.

## 2. What the program actually does

There are three different lifetimes to understand:

| Layer | Examples | Lifetime |
|---|---|---|
| Content pack | Event definitions, item catalogs, tuning rules | Shared definitions for a campaign |
| Run | Student stats, date, stamina, inventory, story switches | One playthrough, including its saves |
| Account | Cookies, refresh tokens, owned traits, enrolled schools, history | Across playthroughs |

This explains several otherwise confusing requirements:

- Stationery starts fresh on a new run, but survives saving and resuming that run.
- Setup badges and traits are gated by account ownership; characters remain
  unlocked under the current scope decision.
- Cookies and refresh tokens can use the shared account wallet instead of
  independent balances in each run.
- History stores a record of a completed run. It should not quietly substitute
  today's equipment or catalog values for missing historical details.

The main path is approximately:

```text
Home → select campaign and student → opening events → daily preparation
     → choose actions / move / play events → evening → next day
     → exam → applications → results → enrollment → endings → History
```

Events can interrupt this path. Some are scheduled, some depend on state, and
some occur after actions. The exact original event dispatcher is not fully
recovered, so an implemented ordering policy is not automatically original parity.

## 3. What was used

These are repository-backed technologies and research artifacts, not a list of
skills you should automatically put on your resume.

| Technology or artifact | Job in this project | Java-oriented translation |
|---|---|---|
| Dart | Engine and app programming language | Class-based language with generics, null safety, functions, and async operations |
| Flutter | Screens, layouts, gestures, animations, rendering | A UI toolkit; screens are composed from widget objects |
| JSON content packs | Campaign definitions and editable mechanics | Structured configuration parsed into objects/maps |
| Python scripts | Data import, normalization, catalogs, audits, asset handling | Offline transformation programs, separate from the game runtime |
| Flutter test framework | Engine tests, widget tests, simulations | Similar purpose to JUnit, plus UI-specific testing tools |
| Flutter analyzer / lints | Static checks | Compiler/static-analysis feedback before runtime |
| Android SDK and ADB | Package installation, device launch, logs | Tools for interacting with an Android device |
| Profile APK and hardware rendering | Normal phone validation and performance investigation | A build suitable for measuring behavior closer to normal execution |
| Git and retained worktrees | Version history, branches, integration and recovery | Multiple checkouts of the same repository; not separate products |
| Codex and Claude Code | Implementation and investigation agents you directed | Development tools, not app runtime dependencies |
| AOTopsy export | Existing recovered pseudocode from a Korean native build | Approximate source-like output, not the original source code |
| blutter object/string dumps | Names and objects used to interpret compiled Dart | Clues connecting compiled instructions to meaningful identifiers |
| Capstone | Documented ARM64 disassembly work for native mechanics | Turns machine-code bytes into assembly instructions |
| Screenshots and recordings | Original UI and interaction references | Observable acceptance criteria and test evidence |

Direct runtime dependencies in [pubspec.yaml](../pubspec.yaml) include Flutter,
`cupertino_icons`, `path_provider`, `gal`, and `image_picker`. Respectively these
support the UI framework/icons, finding storage directories, gallery export, and
image selection. Development dependencies include `flutter_test` and
`flutter_lints`. `pubspec.lock` records resolved package versions; version ranges
in the manifest are not necessarily the exact installed versions.

The declared Dart SDK constraint is `^3.13.5`. That describes this checkout's
requirement, not a statement about the latest public SDK.

There is no implemented production backend for purchases, ad delivery, mail,
or leaderboards. Firebase appears in **original-app recovery evidence**, including
wallpaper downloads through its existing client; that does not make d30mode a
Firebase-backed service.

The engine's own code and project-authored examples use the repository's MIT
license. Original game art, text, and data are a separate category and are kept
out of the tracked public content. A local APK can contain local reference assets;
that is different from what a fresh repository clone contains.

## 4. The architecture map

```text
LOCAL ORIGINAL REFERENCES
  extracted catalogs + event graphs + native evidence + UI captures
                │
                ▼
PYTHON TOOLS + TRACKED OVERLAYS
  tools/build_pack.py, catalog builders, content/kss/*
                │
                ▼
CONTENT PACK FILES
  pack.json, rules.json, mechanics.json, events, catalogs, images
                │
                ▼
LOADING / VALIDATION
  ContentSource → ContentPack → parsed catalogs and indexes
                │
                ▼
ENGINE
  Game ↔ GameState
   ├─ ConditionEvaluator: is a condition true?
   ├─ EffectEngine: apply a change / callback
   ├─ EventEngine / EventRun: select and walk events
   ├─ TraitEngine: eligible modifiers and abilities
   └─ exam, admissions, goals, calendar helpers
                │
                ▼
FLUTTER UI
  screens render state and call engine operations
                │
                ▼
STORAGE EDGES
  save files / account / completed-run records
```

This is an architectural sketch, not an exact call graph: storage also feeds
startup and resume, and UI code coordinates asynchronous presentation.

Most engine logic is plain Dart. Loading and storage edges import Flutter or
platform helpers. That makes it possible to simulate runs without displaying a
phone screen. The engine still uses mutable state; it is not a collection of
pure mathematical functions.

### Source files worth recognizing

| File | Question it answers |
|---|---|
| [main.dart](../lib/main.dart) | How does Flutter start, choose a theme, and log slow frames? |
| [home_screen.dart](../lib/ui/home_screen.dart) | How are packs/accounts loaded and runs created or resumed? |
| [game_screen.dart](../lib/ui/game_screen.dart) | How are outcomes turned into scenes, dialogs, transitions, and saves? |
| [game.dart](../lib/engine/game.dart) | What happens when the player acts? |
| [state.dart](../lib/engine/state.dart) | What data represents the current run? |
| [pack.dart](../lib/engine/pack.dart) | How are pack files modeled and indexed? |
| [content_source.dart](../lib/engine/content_source.dart) | Where are packs found and how are bundled updates handled? |
| [event_engine.dart](../lib/engine/event_engine.dart) | How are events selected and graph nodes executed? |
| [conditions.dart](../lib/engine/conditions.dart) | How are recursive conditions interpreted? |
| [effects.dart](../lib/engine/effects.dart) | What do effect verbs and callbacks change? |
| [traits.dart](../lib/engine/traits.dart) | How do traits, badges, and character effects contribute? |
| [pack_mechanics.dart](../lib/engine/pack_mechanics.dart) | How does the custom mechanics language validate and execute? |
| [save_store.dart](../lib/engine/save_store.dart) | How are unfinished runs written and resumed? |
| [account_store.dart](../lib/engine/account_store.dart) | What survives across runs? |
| [record_store.dart](../lib/engine/record_store.dart) | What is retained after a run finishes? |

Read narrow paths through these files. Reading every line in alphabetical order
is a poor first pass.

## 5. Dart and Flutter through a Java lens

### Familiar language pieces

| Dart | Java comparison / important difference |
|---|---|
| `class Game` | Ordinary class, with fields and methods |
| `final ContentPack pack` | Reference assigned once, like Java `final`; the referenced object need not be deeply immutable |
| `String?` | Explicitly nullable string; the type system asks you to handle absence |
| `x ?? fallback` | Use fallback if x is null |
| `x?.method()` | Call only if x is non-null |
| `Map<int, int>` | Comparable to `Map<Integer, Integer>` |
| `List<T>` / `Set<T>` | Familiar generic collections |
| `{required this.pack}` | Named constructor parameter; call with `Game(pack: p, state: s)` |
| `factory Game.newRun(...)` | Named factory constructor, similar in purpose to a static factory method |
| `_hand` | Leading underscore makes it private to the Dart library, not Java-style private to one class |
| `Future<T>` / `async` / `await` | Asynchronous result and continuation, conceptually related to `CompletableFuture` |
| `late final` | Assigned after declaration, expected before use; misuse can fail at runtime |
| `const` | Compile-time constant construction where supported; stronger than merely `final` |

`await` lets other work proceed while an asynchronous operation is pending. It
does not automatically put expensive CPU calculations on another thread.

### Flutter's main conceptual jump

A widget describes what should be on screen. Flutter calls `build()` to obtain
that description, potentially many times. A `StatefulWidget` has an associated
`State` object that can retain changing UI data. `setState()` tells Flutter that
the description may need rebuilding; it is not a disk save.

For this project, think:

```text
button tap → engine changes GameState → UI schedules rebuild → widgets display values
```

Do not put gameplay rewards or fresh random draws in a frequently called
`build()` method. Merely redrawing the screen should not change the game.

After an `await`, the screen might have been closed. The repeated `mounted`
checks in UI code ask whether its State object is still attached before using
that screen's context or updating it.

### What this is not

There is no need to describe this as using Redux, BLoC, or Riverpod. The inspected
code directly coordinates mutable engine objects with Flutter state and
`setState()`. The separation of responsibilities is more important than attaching
a framework name to it.

## 6. Trace one player action end to end

Use [game.dart](../lib/engine/game.dart) and search for `hand`, `preview`, `act`,
`_studyGain`, `_study`, `_tick`, and `_endDay`.

### Step A: decide what actions are available

The pack lists location actions. The engine filters for current gates, location,
progression, and special-block state. A capped exercise level, for example, can
remove further exercise blocks. A special action may require a pack predicate.

The available pool is different from the displayed hand. The engine uses a
weighted draw to deal the hand. It caches that hand so a UI rebuild doesn't
silently redeal it. Changes such as advancing time or refreshing invalidate it.

### Step B: draw with replacement

For weights `[2, 3, 5]`, total weight is 10. Draw a uniform real value in
`[0, 10)` and choose its interval:

```text
[0,2) → action A      [2,5) → B      [5,10) → C
```

The implementation subtracts weights until the remainder is nonpositive.
It repeats for each slot **without removing the selected action**, so duplicate
blocks are possible. Original reference hands showing duplicate books/workouts
provided evidence for replacement.

For `k` slots and `n` available actions, this straightforward implementation costs
O(kn) time and O(n + k) additional storage for weights and results. For a tiny
action pool, a more complex sampling structure would offer little practical gain.
The implementation gives nonpositive weights a small positive fallback, so don't
claim zero weight necessarily excludes an action; eligibility filtering matters.

This is an easy bridge from competitive programming to product code: the right
algorithm is the one appropriate to the input size and behavior requirements.

### Step C: show an honest preview

`ActionPreview` describes the title, stamina cost, gain, money, and progress.
Shared helpers calculate both the displayed values and actual action outcomes.

The study formula currently begins with:

```text
gain = book power × rules.studyWeight × study-level weight
gain += level flat bonus + item passive bonuses + trait bonuses + stationery
if repeating the subject: apply the bounded combo multiplier
```

Under the documented unbuffed baseline, a power-5 starter book with weight 3
and level weight 1 gives 15 before other bonuses. This is the implemented model,
not proof that every arithmetic detail matches the original game.

### Step D: resolve the action

`Game.act()` delegates to `_act()` and attaches receipts. `_act()` rejects states
such as a finished run, unfinished opening/evening, or pending exhaustion. It
then resolves study/work/exercise/lesson/sleep/special behavior, applies the
action's changer, executes pack hooks, settles goals, and handles progression.

Exhaustion and the final slot of a day need different treatment. Reaching zero
stamina on the final action follows normal day end; collapsing earlier can lose
remaining slots. Lost slots still need event checks without granting action
rewards.

The result is an `ActionOutcome`: summary, events, flags, item receipts, and
reports. This keeps UI presentation concerns out of the numeric action helper.

### Step E: present and advance

`GameScreen` coordinates reward dialogs, events, day transitions, and saving.
The engine can defer rollover while an evening scene is open. Date advance,
stamina reset, and temporary-trait aging must wait for the correct boundary.

Interview insight: much of the complexity is **ordering**, not arithmetic.
“Subtract HP and increment time” misses scenes, one-time rewards, saved guards,
and next-morning delivery.

## 7. Events are a graph interpreter

An event is not just a string of dialogue. It is a directed graph whose nodes
can show dialogue, change a portrait/background, evaluate a condition, mutate
state, offer choices, or end the event.

```text
start → check item held? ── yes → grant reward → dialogue → end
                         └ no → choices → branch A or branch B → end
```

The actual imported format has node IDs, `nextNodeId`, true/false targets,
and option/box references. `ContentPack` builds indexes including node lookup
and nodes grouped by box. In Java terms, imagine `Map<Integer, EventNode>`
instead of searching the entire list for each transition.

`EventRun._walkFrom()` follows nodes until it reaches something visible or an
ending. Presentation-only nodes can update state without needing a separate
dialogue screen. `advance()` follows the ordinary edge; `choose()` follows the
chosen branch. Portrait state persists across appropriate dialogue nodes, so
the character on screen is not inferred solely from who is speaking.

The runner caps traversal at 2,000 steps and logs missing-node issues. The graph
need not be acyclic: a traversal budget protects against a hand-edited loop
freezing the UI. The budget can also stop an unusually long valid traversal;
it is a bounded-runtime tradeoff, not a proof of graph correctness.

### Conditions: a recursive expression tree

Conditions combine AND/OR nodes with leaf checks such as item count, date,
trait ownership, location, switches, or named predicates.

```text
AND
├── location == mountain
└── OR
    ├── has gloves
    └── has relevant trait
```

This is a direct CS182 connection: propositional logic becomes executable tree
evaluation. With `m` visited condition nodes, evaluation is O(m); recursive stack
space depends on tree depth. Empty conditions and unknown functions have explicit
semantics. Unknown predicate targets are collected for diagnostics, and a leaf
whose value cannot be resolved fails its check.

### Effects: interpret commands

A condition asks, “May this happen?” An effect says, “Change this.” A changer's
`funcCode` names a callback or built-in verb. The effect system can adjust money,
stats, inventory, switches, progression, and other state.

Together, the graph runner, conditions, and effects form a small interpreter.
There is no need to claim the project builds a full compiler or executes arbitrary
user code. It reads structured data and dispatches a supported vocabulary.

## 8. Modularity: why mechanics belong in data

The required design boundary is:

> Campaign identity belongs in the pack; reusable behavior belongs in the engine.

A brittle design would put `if (traitId == 69) ...` in generic engine code and
assume that number always means the same character ability. A different pack
could use 69 for something unrelated. Current mechanics definitions associate
IDs with abilities inside that pack.

[MODULAR-PACKS.md](MODULAR-PACKS.md) documents the optional `mechanics.json`:

| Section | Purpose |
|---|---|
| `predicates` | Named read-only conditions |
| `callbacks` | Named sequences of mutation operations |
| `traitAbilities`, `characterAbilities` | Abilities associated with this pack's IDs |
| `blocks` | Special actions and their gates/unlocks |
| `hooks` | Attach callbacks to moments such as action or book completion |
| `switchGuards`, `bindings`, `textMacros` | Additional pack-owned integration points |

### The Workshop example is the best learning specimen

Open [Workshop mechanics](../examples/packs/workshop/mechanics.json) and
[custom_pack_test.dart](../test/custom_pack_test.dart).

1. Character 70 satisfies `CAN_CRAFT`.
2. A crafting block is gated behind an unlock. `ENABLE_BLOCK` accepts its alias
   `bench` as well as the canonical ID.
3. `CRAFT` adds 5 craft stat and increments `CRAFT_COUNT`.
4. Trait 69 contributes 3 money to that callback; character 70 contributes 7.
5. With both providers, the tested callback gives 10 money.
6. The unlock survives a JSON state round trip, until explicitly disabled.
7. Removing `mechanics.json` removes these abilities even with the same catalog IDs.

That last test establishes a meaningful design property: identities alone
don't leak campaign behavior into the generic engine.

The validator rejects unsupported operations, bad chances, incomplete blocks,
and predicate cycles. Callback depth/call limits bound runtime recursion.
Arbitrary dynamic callback cycles are not all rejected statically. The language
doesn't provide arbitrary scripts or external I/O, but that does not establish a
complete security audit for every possible untrusted pack.

### Tradeoffs you should be able to explain

- Data-driven definitions make content easier to edit and reuse across campaigns.
- The cost is building and maintaining a parser, validator, interpreter, and
  diagnostics. String-based names can fail at runtime if validation misses them.
- A new combination of existing primitives can be authored in JSON. A fundamentally
  new kind of behavior still requires engine code and tests.
- The mechanics boundary is modular; the whole app has not been proved free of
  every campaign-specific UI or account assumption.

The companion pack editor described in the sibling `../pack-studio/` project is planning and
contract groundwork. Do not list it as a shipped editor or claim the proposed
standalone `d30_engine` package has already been extracted.

## 9. Reverse engineering: the evidence pipeline

### Why extracting assets is not enough

An Android package can contain structured assets, images, and native libraries.
The original Flutter game's content graphs expose many rules directly, but
compiled logic is in native code such as `libapp.so`.

Contrast this with familiar Java: decompiling JVM bytecode can often recover
source-like structure. An optimized, ahead-of-time compiled Dart ARM64 binary
has lost or transformed much of that structure. Some names and strings survive;
many calls and closures remain unresolved. Decompiled pseudocode is an
interpretation, not restored developer source.

### Keep evidence categories separate

| Evidence | Can establish | Does not establish alone |
|---|---|---|
| Original screenshot | Visible text, layout, duplicate action cards | Hidden probabilities or every interaction |
| Recording / playtest | A sequence and outcome in a particular state | All possible states or exact random odds |
| Extracted JSON | Values, IDs, graph links, authored conditions | All execution timing or compiled arithmetic |
| Native disassembly / pseudocode | Specific implemented checks when their bodies are recovered | Complete behavior of unresolved calls |
| Registry or string name | A named capability exists in that artifact | Its full semantics or availability in another version |
| User decision | Desired behavior for this recreation | Historical behavior in the original |
| Passing recreation test | Implemented behavior remains consistent with assertions | Original-game parity |

### Versions are part of the fact

The local AOTopsy export is from the **Korean 1.61.0** native, not an English
1.27.4 export. English assets, later captures, and older mod trees are distinct
sources. Shared identifiers can suggest related architecture, but they do not
prove every formula matches across regions and versions.

[extract_initialization_evidence.py](../tools/extract_initialization_evidence.py)
preserves function excerpts, original line locations, version metadata, and
SHA-256 fingerprints. It explicitly does not manufacture a Global pseudocode
export. A SHA-256 fingerprint identifies exact bytes; it does not certify that
an interpretation of those bytes is correct.

### Native-analysis vocabulary

- **Disassembly:** machine code represented as assembly instructions.
- **Decompilation:** an attempt to express compiled behavior in a higher-level form.
- **Obfuscation:** reduced or altered meaningful names, making interpretation harder.
- **Closure:** a function object that may retain surrounding values.
- **Object pool:** stored objects/constants accessed by compiled code; named strings
  can help connect anonymous instructions to game concepts.
- **Cross-reference:** a location where a string/function/object is used.
- **Tagged integer / Smi:** a runtime representation where raw bits include type
  information. The documented native work notes cases where encoded 2 means
  integer 1; do not read every immediate as a literal game value.
- **Remote configuration:** a value supplied outside the binary. Its key can be
  recoverable even when its actual value isn't.

### Concrete example: Retry Year

[RETRY-YEAR.md](RETRY-YEAR.md) documents Capstone disassembly correlated with
object-pool loads. Recoverable examples include a singing win gate at 15 points,
mock-exam raw-stat thresholds, and temporary action switches. The karaoke money
callback refers to remote configuration, so its exact payout wasn't established
just by finding the callback body.

This is a better explanation than “the agents decompiled the game and got all
the formulas.” Different parts had different evidence quality.

### Concrete example: the gloves correction

The imported English graph already contained a Hiking Gloves extra-yield branch.
An earlier audit incorrectly treated the passive as missing. Later inspection
found a random second herb draw with different source conditions. You then chose
a provisional 20% exact-herb duplicate and ginseng exclusivity for this recreation.

The generator applies an explicit overlay for that choice. It should not be
described as recovering a native 20% duplicate formula. See
[CLARIFIED-MECHANICS-2026-10-25.md](CLARIFIED-MECHANICS-2026-10-25.md).

This is a strong requirements/QA example: recheck the evidence, correct the audit,
make the desired rule explicit, and test the resulting behavior.

## 10. The Python data pipeline: the data-engineering connection

[build_pack.py](../tools/build_pack.py) reads locally extracted catalogs and
campaign graphs, normalizes them, combines sources, applies overlays, and writes
runtime pack JSON. Related tools build item/account catalogs, export mechanics,
import images, and produce audits.

Think **ETL**:

```text
Extract: read source catalogs and graphs
Transform: normalize fields, merge catalogs, apply scoped corrections
Load: write the content files the game consumes
```

There is no need to claim a warehouse, distributed processing, Airflow, Kafka,
or a live streaming pipeline. This is a local batch transformation pipeline.

### Two details worth learning deeply

**Missing and null are different.** The builder removes irrelevant plumbing
fields, but preserves load-bearing nulls such as `nextNodeId`. If a graph schema
distinguishes “this field is missing” from “the event ends here,” indiscriminately
dropping nulls changes meaning. This is schema semantics, not cosmetic cleanup.

**Generated output is not the durable authoring source.** KSS generated packs
are ignored. Durable changes belong in tracked generators or overlays such as
`content/kss/mechanics.json`, not only in a local generated file that the next
build overwrites.

### Data quality questions this project raises

- Are IDs unique in their intended scope, and do references resolve?
- Are translation and regional overlays changing labels without corrupting IDs?
- Can we identify the exact input files/version behind an output?
- Which changes are source recovery versus intentional normalization?
- Are unparsed item effects visible as unresolved data rather than silently lost?
- Will regeneration preserve a fix?

These are useful data-engineering talking points. The honest limitation is
reproducibility: the current README says a fresh clone cannot build unaided
because required generated packs and local assets are absent. Tooling that is
reproducible given private local inputs is different from a self-contained
public build.

## 11. Persistence, randomness, and performance

### Saves and history

`GameState.toJson()` serializes run fields; `fromJson()` reconstructs them with
compatibility defaults. JSON object keys are strings, so integer-keyed maps such
as inventory need conversion. Serialization stores data, not arbitrary live
objects, UI widgets, or open file handles.

`SaveStore` writes an envelope containing version, timestamp, summary, and state.
The summary duplicates enough display data to list saves without loading a pack.
A neighboring temporary file is written before rename, reducing the chance that
an interrupted write destroys the previous save. That isn't a claim of guaranteed
durability against every OS/filesystem failure.

The reader rejects a run whose pack ID differs from the supplied pack. Bad or
unreadable save files can be skipped rather than taking down the whole list.
The current implementation discovers `slot_<id>.json` files and allocates new
IDs; don't repeat the older README bullet describing a fixed three-slot limit.

Account data has its own store. `SharedWallet` is an interface allowing a run
to access account balances without loading account files in core engine logic.
In Java terms, the run depends on an interface rather than implementing account
storage itself.

Completed-run records retain detached snapshots of relevant details. A shallow
reference to mutable current inventory would let later changes rewrite the past;
the snapshot is intended to avoid that. Legacy records retain honest fallbacks
instead of invented details.

Multiple files are not a database transaction. Do not claim atomic account/save/
History commits; cross-file crash consistency is a reasonable future concern.

### Updating editable packs

Nothing is bundled. `ContentSource` finds pack directories on disk and loads
them directly, so an installed pack is never replaced by an APK update. This
is separate from clearing saves, account data, or run stationery.

### Deterministic does not mean everything is replayable

There are two randomness patterns:

1. Mutable `state.random` draws, used for things such as weighted hands.
2. Derived seeded rolls, keyed to a date/tick and an ability identity, used where
   preview and resolution must agree.

If a trait randomly removes stamina cost, rolling once for display and again
for payment could show zero cost but charge stamina. The derived roll returns
the same answer in that context without consuming a fresh shared RNG draw.

Tests can inject `Random(seed)` to reproduce a simulation under the same
conditions. However, the inspected `GameState.toJson()` does not serialize the
internal state of Dart's `Random`. Do not claim identical future randomness after
every save/reload. Persisted one-time guards and results solve narrower problems,
such as avoiding repeated movement/exhaustion checks or rerolling saved offers.
Derived rolls are also not cryptographically secure randomness.

### The real performance story

[PERFORMANCE-REGRESSION.md](PERFORMANCE-REGRESSION.md) distinguishes two costs:

- **Build time:** Dart work constructing/updating UI descriptions.
- **Raster time:** rendering work drawing the frame.

A stationery text-fit cache addressed repeated layout work. A separate major
regression came from leaving software rendering enabled after a diagnostic
deployment. Logs showed roughly 498–594 ms raster durations on affected samples.
Hardware restarts produced much lower startup samples and the user reported
smoother play. These are dated observations, not a controlled sustained-FPS
benchmark or a universally valid speedup ratio.

`main.dart` logs over-budget frames with separate build and raster durations.
At 60 Hz the nominal frame interval is about 16.7 ms; the logger uses a 16 ms
threshold. Slow-frame-only startup logs cannot establish average gameplay FPS.

The transferable lesson: measure which subsystem is slow before changing it.
Use hardware-rendered profile builds for normal device checks, and preserve
existing caches and user data during deployment.

## 12. Testing: connect this to your QA experience

Your prior UX/UI testing experience gives you a natural way into this project:
turn visible behavior and user expectations into explicit, reproducible checks.

| Test layer | Example here | What it catches |
|---|---|---|
| Focused engine regression | Acceptance modifiers, shop rules, exhaustion | Wrong formulas, ordering, state guards |
| Pack/contract validation | Unsupported mechanics, missing references | Bad data before or during execution |
| Seeded simulation | 200 complete runs in the documented suite | Dead ends and failures across many execution paths |
| Persistence test | Save/load round trip, shared wallet | Missing fields and incorrect lifetime |
| Widget/render test | Dialogs and layouts at phone widths | Overflow, interaction, visual structure |
| Device smoke test | Install, cold launch, inspect logs and UI | Packaging/platform problems a headless test misses |
| Original-reference comparison | Captures and user playtests | Differences from the intended original experience |

The latest checkpoint reviewed reports clean analysis and 490 passing tests.
That is historical project evidence, **not a new test run performed to write
this guide**. Other documents quote older counts. Counts alone don't measure
coverage, and 200 runs don't prove every event or branch executes.

### The test-oracle problem

A test oracle tells you what the right answer should be. Here it might come from
a recovered graph, native check, explicit user decision, or original screenshot.
If the agents invent a formula and then write a test for it, the test preserves
that formula; it doesn't prove the formula matches the original.

Keep these questions separate:

1. Did we correctly implement the selected rule?
2. Is the selected rule supported by original-game evidence?

That distinction is one of the project's strongest interview topics.

### A concrete QA case: evening rollover

Scenario: complete the last action while an evening event is eligible.

- The evening scene should open while the date still belongs to that day.
- Date, stamina reset, and temporary-trait aging wait until it closes.
- The following morning's event must be presented rather than constructed and lost.
- Related saved guards must not allow unintended duplicate checks/rewards.

You can discuss how you'd reproduce, isolate, and retest that boundary even if
an agent wrote the code. Attribute the testing you personally performed, and
label any further source understanding as something you learned afterward.

## 13. Interview stories and follow-up answers

These are preparation models. Don't present a repository's documented incident
as something you personally diagnosed unless you did.

### “Walk me through the architecture.”

> Content packs define the campaign, a mostly plain-Dart engine interprets them,
> Flutter presents the resulting state and events, and separate stores persist
> account data, unfinished runs, and completed history. This separation makes it
> possible to test gameplay without driving the phone UI.

Follow-up to prepare: trace one tap through `preview`, `act`, `ActionOutcome`,
`GameScreen`, and saving.

### “What was the hardest part?”

An evidence-based answer is ambiguity and event ordering: assets can show a graph
without revealing the original scheduler or compiled formula. Explain one example,
such as gloves, deferred evening rollover, or unknown shop weights. Describe your
actual decision/testing role rather than borrowing the agent's investigation.

### “What does data-driven mean?”

> Adding an ordinary item, callback combination, or special block can be a pack
> change using supported primitives. It shouldn't require an engine branch for
> that campaign's ID. New primitives still require implementation work.

Demonstrate with Workshop rather than claiming arbitrary game genres are supported.

### “Why Flutter?”

You can say what it provides: a shared Dart UI framework, custom layouts and
animations, and Android/desktop development support. The original game's Flutter
artifacts also shaped the investigation. If you did not personally choose Flutter
after comparing alternatives, say that it was the project's established stack;
don't invent a framework-selection study.

### “What would you improve?”

Choose one you understand:

- Make a fresh clone runnable with original example content alone.
- Add structured diagnostics so malformed packs produce actionable reports.
- Improve crash consistency across account, save, and History writes.
- Recover or explicitly document remaining scoring, scheduling, and probability gaps.
- Measure sustained gameplay performance with a repeatable interaction sequence.

Explain the problem and your proposed validation. These are future directions,
not work already completed.

### “What did the AI do, and what did you do?”

> Codex and Claude Code generated the code and much of the investigation and
> documentation. I directed the work, tested the app, and chose mechanics when
> the original behavior was unclear. I'm studying the implementation so I can
> explain its architecture and verify changes more independently.

As your experience grows, replace the last sentence with specific work you have
actually completed. Understanding source now doesn't retroactively mean you
hand-wrote it then, but it can become real engineering knowledge.

## 14. Resume language and role-specific emphasis

Project heading: **d30mode — AI-assisted mobile simulation recreation**

Possible bullets based on your stated role:

- Directed Codex and Claude Code in developing a Flutter/Dart simulation
  recreation, translating playtest feedback into mechanics and UI requirements.
- Performed hands-on gameplay and UX/UI testing, using original-game references
  to identify differences and guide iterative fixes.
- Defined prototype mechanics where original behavior was unresolved and directed
  agents to compare behavior and document evidence and limitations.

Use only bullets that match your actual work. Add outcomes or counts only when
you can explain their measurement. The suite's test count is a project property;
it doesn't mean you personally wrote those tests.

After completing practical exercises, you could add a narrower technical bullet
about your own change: “Implemented and regression-tested [specific behavior]
in a JSON-driven event engine.” Don't use that wording before doing the work.

| Role | Best project angle | What to be ready to demonstrate |
|---|---|---|
| General SWE internship | Engine boundaries, debugging, state transitions | Trace an action and explain a design tradeoff |
| QA / test engineering | Requirements, test oracles, edge cases, device checks | Turn one reported mismatch into a test matrix |
| Data engineering | Batch transformation, schema semantics, provenance | Trace one field from source through generator to runtime |
| Mobile development | Flutter lifecycle, async screens, persistence, profiling | Explain rebuilds, `mounted`, and build/raster timing |
| Tooling / developer experience | Pack validation, diagnostics, editable content | Author and test a Workshop extension |

Do not claim “production-scale,” “full original parity,” “secure sandbox,”
“fully deterministic replay,” or “built entirely by hand.” Also avoid
“clean-room reverse engineering” as an unqualified process claim: this project
used extracted content and native-code evidence, and the guide has not
established a formal clean-room process.

## 15. Questions you should answer without notes

1. What are the differences among a pack, a run, and an account?
2. Why does rebuilding a Flutter widget have to leave game rewards unchanged?
3. Why is action sampling with replacement? What is its complexity?
4. How do preview and payout avoid disagreeing?
5. What are a predicate, callback, hook, and graph node?
6. Why is a traversal step limit useful even if the pack loaded successfully?
7. Why can two packs reuse the same numeric character/trait ID?
8. Which original data was English, and which native evidence was Korean?
9. Why doesn't finding a function name recover its probability?
10. How does a generated pack differ from the tracked source of its changes?
11. What survives a new run versus save/resume?
12. Which random decisions are stable, and what isn't serialized?
13. What did performance logs measure, and what couldn't they establish?
14. How can every test pass while original-game behavior is still wrong?
15. What did you personally contribute, and what did the agents do?

If you can't answer a follow-up, say what you know and how you'd investigate.
That is a better engineering response than filling the gap with terminology.

## 16. A practical study plan

These are suggested sessions, not claims about how fast you must learn.

### Session 1: explain the product and state

Play one short sequence. Write down the before/after date, stamina, stats,
inventory, and account balances. Find the corresponding fields in `GameState`.
Explain aloud why each belongs to a run or the account.

Deliverable: a one-page architecture sketch from memory.

### Session 2: manually trace study

Read `preview`, `_studyGain`, `_study`, and `act`. Start with a power-5 book,
baseline weight 3, and no bonuses. Compute the preview; then follow the actual
stat change. Add a combo or stationery bonus and recompute in source order.

Deliverable: a table of expected and observed values with the relevant rule names.

### Session 3: understand the event interpreter

Choose a small local event and draw its node edges. Identify dialogue,
condition, effect, choice, and end nodes. Walk it with two different states.
Do not publish original dialogue as part of your public project materials.

Deliverable: your own abstract graph and two execution traces.

### Session 4: make a small original pack change

Use a copy of Workshop. Read its README first. Add a simple callback using existing
operations, predict its effects, and write a focused regression test. Choose a
rule with an independent expected outcome rather than simply asserting whatever
the implementation returns. Verify that another pack using the same IDs doesn't
inherit the new behavior.

Deliverable: a small diff you can explain line by line. This is a particularly
good first personally implemented technical contribution.

### Session 5: practice QA systematically

Build a matrix for shop refresh: before purchase, after purchase, first reroll,
later reroll, insufficient cookies, save/resume, Saturday boundary. Compare
observations with the clarified rule record.

Deliverable: a reproducible bug report or documented passing cases, with the
build/version and state prerequisites.

### Session 6: trace the data pipeline

Pick one generated field. Find its input, transformation, overlay if any, output,
and Dart consumer. Explain whether its value is recovered or provisional.

Deliverable: a source-to-runtime lineage diagram. This is the best exercise for
a data-engineering-oriented conversation.

### Session 7: persistence and randomness

Inspect an expendable test save, not your real account file. Find serialized
guards and offer IDs. Explain why the future RNG sequence isn't fully saved.
Sketch what a versioned serializable PRNG would require, without claiming to
have implemented one.

Deliverable: a short design note about exact replay versus preserving committed
outcomes and preventing duplicate rewards.

### Session 8: mock interview

Give a 60-second introduction, a three-minute architecture explanation, and a
five-minute walkthrough of one exercise. Have someone interrupt with “why?” and
“how do you know?” Record which answers require a source lookup.

Deliverable: your own revised explanation, using only claims you can support.

### Commands to recognize

These are study/validation commands, not actions performed by this guide:

```powershell
flutter analyze
flutter test test/custom_pack_test.dart
flutter test test/clarified_mechanics_test.dart
flutter test
flutter build apk --profile
```

Pack-dependent tests require the local generated packs. New phone deployments
follow the project's build/test/install process and preserve data. Don't clear
the app or manually push pack files as a routine update. Consult `CLAUDE.md` for
the established Windows/ADB procedure.

## 17. Further reading, in a useful order

1. [README](../README.md): scope, local build limitation, layout, license boundary.
2. [CURRENT-STATE](CURRENT-STATE.md): latest integrated behavior and dated evidence.
3. [Workshop README](../examples/packs/workshop/README.md) and
   [custom pack tests](../test/custom_pack_test.dart): smallest end-to-end specimen.
4. [MODULAR-PACKS](MODULAR-PACKS.md) and [PACK-FORMAT](PACK-FORMAT.md): authoring contract.
5. [Engine tests](../test/engine_test.dart): concrete expectations and simulations.
6. [Original-game functional reference](ORIGINAL-GAME-FUNCTIONS.md): evidence categories,
   source versions, recovered and unresolved systems.
7. [Retry Year](RETRY-YEAR.md) and
   [clarified mechanics](CLARIFIED-MECHANICS-2026-10-25.md): examples of recovered
   native behavior versus user-selected recreation rules.
8. [Performance regression](PERFORMANCE-REGRESSION.md): measured bottlenecks and limits.
9. [History details](HISTORY-DETAILS.md), [stationery](STATIONERY.md), and
   [effects reference](EFFECTS-REFERENCE.md): deeper feature studies.
10. [TODO](../TODO.md) and [evidence requests](IMPLEMENTATION-EVIDENCE-REQUESTS.md):
    remaining work and what would establish it.

### Scope and verification of this guide

Written from this local checkout's source, tests, manifests, generators, and
project evidence records on October 26, 2026. No app behavior changed, no phone
deployment was performed, and no new claim of a passing full suite is made.
The guide is an entry point, not an audit of every source line or local binary.
Personal ownership statements use your answers in this chat; technical examples
describe the repository unless explicitly attributed to you.
