# d30mode

A data-driven game engine, written in Flutter, that recreates the
**31-Day Mode** of *Korean Student Simulator* (KSS) and is built to be
modded. The engine holds no content: the calendar, places, actions, events,
items, traits, characters, colleges and every tuning number come from a
**content pack** of JSON files. Change the pack and you change the game.

> **Unofficial fan project.** d30mode is not affiliated with, endorsed by, or
> connected to the developers or publishers of Korean Student Simulator. The
> engine code in this repository is original. **No game data, text, art or
> audio from KSS is included**, and none should be committed or distributed.

## Status

Playable prototype, under active development.

What works:

- **The day loop.** A calendar measured in action ticks. Each tick deals a
  weighted hand of action blocks for your location: study, part-time work,
  exercise, sleep and pack-defined special actions. Stamina, money, levels,
  study books and combos, weekly goals and refresh tickets.
- **The event engine.** Node-graph events with dialogue, choices, branching,
  layered character portraits and backgrounds. A recursive condition
  language covers switches, dates, locations, items, traits and computed
  predicates, and changers carry around 60 effect verbs. Events can be
  scheduled, random, character-specific or story-set gated.
- **Run setup.** Pick a mode, a character, up to seven university badges and
  five traits, and enter a name. Badges and traits come from what your account
  has earned.
- **Items, traits and badges** with structured effects. Trait and character
  abilities and special blocks are defined in pack data (`mechanics.json`),
  not hard-coded.
- **Exam day.** The final exam, the CSAT, university applications with
  acceptance odds, results, enrollment and endings.
- **Account layer.** History of past runs with score cards, achievements,
  trait packs and combining, puzzles and backgrounds, saves in three slots,
  and settings.
- **A developer panel** to edit the live run (stats, clock, switches, items,
  traits, locations), fire any event, tune `rules.json` in place, reload the
  pack from disk, and list any effect or condition the engine didn't
  recognize.

Not done yet: audio, some original rules that couldn't be recovered (exam
scoring and admission odds are fitted approximations, and some trait rates
are configurable stand-ins), sudden missions, and parts of the original
event dispatcher. [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md) is the
detailed checkpoint.

## Content packs

A pack is a folder:

```
my-pack/
  pack.json           manifest: name, calendar, subjects, start location
  rules.json          every tuning number (all optional, with defaults)
  locations.json      places and the actions available at each
  events/events.json  events and their node graphs
  characters.json     playable characters (at least one with "isDefault": true)
  items.json, traits.json, books.json, levels.json, mechanics.json, ...
  images/             the pack's own art, at the paths its JSON uses
```

- **[examples/packs/workshop](examples/packs/workshop/)** is a small,
  self-contained pack made for this project. It has custom subjects, a
  location, a crafting block, a trait and a character. Start new packs from
  it.
- **[docs/PACK-FORMAT.md](docs/PACK-FORMAT.md)** describes every file.
- **[docs/MODULAR-PACKS.md](docs/MODULAR-PACKS.md)** covers `mechanics.json`:
  predicates, callbacks, abilities, persistent blocks and hooks.
- **[docs/pack-studio/](docs/pack-studio/README.md)** is a field-level
  contract with the engine, event-authoring and art guides, validation rules
  and starter JSON Schemas. It is groundwork for a planned companion pack
  editor.

Installed packs are discovered from a `packs/` folder: next to the app on
desktop, or the app's external files folder on Android. The folder name is
the pack ID. Edit the JSON, then use the developer panel's **Pack → Reload
from disk** and start a new run.

## Building

Requirements: the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart 3.13 or later), plus the Android SDK for Android builds.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows        # desktop, the fastest loop
flutter build apk --profile   # Android
```

**A fresh clone doesn't build yet.** `pubspec.yaml` bundles two packs
(`packs/kss16`, `packs/kss20`) and placeholder art (`assets/images/`). These
are generated locally from reference data that is not in the repository, and
are gitignored. Making a clean clone build and run with only the Workshop
pack is open work. Until then, a self-built pack has to be placed at those
paths, or the bundled pack list in `pubspec.yaml` and the default pack ID in
`lib/engine/content_source.dart` have to be changed.

The `tools/` scripts (Python 3.12) generate those packs from locally held
reference data. They are kept for transparency, and they need inputs this
repository does not provide.

## Repository layout

```
lib/engine/        the engine, almost entirely plain Dart
  pack.dart          pack models and loader
  pack_mechanics.dart  mechanics.json validator and runtime
  game.dart          the day loop
  event_engine.dart  event graph runner and event selection
  conditions.dart    condition language and FUNC_ predicates
  effects.dart       effect verbs and item effects
  traits.dart        trait, badge and character effects
  admissions.dart, dday.dart   exam, applications and admissions
  state.dart         a run in progress
  content_source.dart, save_store.dart, account_store.dart   storage
lib/ui/            Flutter screens: home, setup, gameplay, events, menus, dev panel
examples/packs/    standalone example packs
content/kss/       tracked inputs to the pack generator
tools/             pack generators and audit scripts
test/              engine, pack and widget tests, including seeded full-run simulations
docs/              format docs, design notes, research and reference specs
```

## Tests

`flutter test` runs about 490 tests. They include 200 seeded complete runs
that must all reach the end of the calendar. Static checks confirm the engine
implements every effect verb and condition the bundled packs use, and pack
tests check the Workshop example and the `mechanics.json` validator. Several
tests read the generated packs, so they need those packs present.

## Documentation

| | |
|---|---|
| [docs/CURRENT-STATE.md](docs/CURRENT-STATE.md) | What is implemented and verified right now |
| [docs/PACK-FORMAT.md](docs/PACK-FORMAT.md), [docs/MODULAR-PACKS.md](docs/MODULAR-PACKS.md) | Content pack format |
| [docs/pack-studio/](docs/pack-studio/README.md) | Engine contract and pack-editor groundwork |
| [docs/EFFECTS-REFERENCE.md](docs/EFFECTS-REFERENCE.md) | How item, trait and event effects are applied, including provisional values |
| [docs/EVENT-PRESENTATION.md](docs/EVENT-PRESENTATION.md) | Dialogue tokens, markup and portraits |
| [docs/D30-MODE-SPEC.md](docs/D30-MODE-SPEC.md) | Design spec for the recreated mode |

Research notes keep three kinds of evidence apart: what was observed in the
original, what was recovered from its data, and what this project chose as a
stand-in. Values the project chose are labeled provisional.

## License

The engine code and project-authored content (including the Workshop example
pack) are released under the [MIT License](LICENSE). The license covers this
repository's own work only. Korean Student Simulator and its content belong to
their respective owners and are not licensed here.
