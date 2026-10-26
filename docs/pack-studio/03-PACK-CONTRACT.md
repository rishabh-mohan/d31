# Pack contract

What the d30mode engine reads from each pack file, extracted from code on
2026-10-25 (`lib/engine/pack.dart`, `pack_mechanics.dart`, `content_source.dart`,
`admissions.dart`, `quiz.dart`, `setup.dart`, `state.dart`, `traits.dart`).
Line references are approximate. Events, conditions and changers are detailed
in [04-EVENT-AUTHORING.md](04-EVENT-AUTHORING.md); art in [05-ASSETS.md](05-ASSETS.md).

"REQ" means a missing value throws. Otherwise the listed default applies.
"Inert" means the engine never reads the field: the editor must preserve it
but needn't edit it.

## 0. Global rules

- **Files read** (`ContentPack.allFiles`): required `pack.json`, `rules.json`,
  `locations.json`, `events/events.json`; optional `mechanics.json`,
  `presentation.json`, `items.json`, `traits.json`, `books.json`,
  `levels.json`, `commerce.json`, `characters.json`, `badges.json`,
  `colleges.json`, `colleges_<set>.json` overlays,
  `quizzes.json`, `events/switches.json`, `events/sets.json`,
  `events/system.json`, `events/events_female.json`. Art from `images/**`.
  Anything else is ignored.
- **Missing required file** → `PackFormatException(file, "missing from the pack")`.
  Missing optional file → that system is empty.
- **Top level** must be a JSON object (`PackFormatException` otherwise). A
  list key that is absent/null reads as empty; a non-list throws; non-object
  list entries are silently dropped.
- **Field casts are mostly unchecked.** A missing record `id` or wrong-typed
  field throws a raw Dart `TypeError`, not a friendly error. Only
  `mechanics.json` is fully validated.
- **Duplicate IDs: the last record wins silently.** Nothing checks uniqueness.
- **Cross-references are not validated at load.** Dangling IDs become runtime
  no-ops, hidden records, log notes, or occasionally crashes.
- **All-or-nothing:** Home loads every discovered pack; one failing pack breaks
  Home (07-INSTALL-AND-TEST.md §5).
- **IDs** are JSON numbers everywhere except: pack ID (string, = folder name),
  mechanics block IDs (non-empty strings), switch names, and
  `traitAbilities`/`characterAbilities`/`presentation` keys (numeric strings).
  IDs may overlap with other packs.
- **Practical minimum to start a run:** `characters.json` with at least one
  `isDefault: true` character. `RunSetup.commit` throws
  `StateError('Invalid setup selection')` without a valid character.

## 1. pack.json (required)

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | string | `"pack"` | Must equal the folder name (not enforced). Saves are refused if their `packId` differs. |
| `name`, `description` | string | `"Untitled"`, `""` | Shown on Select Game Mode. |
| `storyId` | int | null | Traits whose `storyId` differs can't be granted or selected. |
| `calendar.startDate`, `calendar.endDate` | `DATE_YYYYMMDDTT` | **REQ** | Bad/missing → `PackFormatException`. Exam day is `date >= endDate`. |
| `calendar.ticksPerDay` | int | 15 | Authoritative (`rules.day.ticksPerDay` is inert). |
| `start.locationId` | int | 1000 | Must exist in locations (not checked). Always unlocked. |
| `start.firstName`, `start.lastName` | string | `"Player"`, `""` | |
| `subjects` | string[] | `[korean, english, math, science, society]` | **Order is load-bearing**: index-based changers (`INCREASE_STAT[i,n]`), positions 3–4 are the "electives". Don't allow empty. |
| `specialDays` | object[] | `[]` | Only `gameDate.dateCode` / `dateCode` read (eve-of-exam check). |

Inert: `formatVersion`, `source`, `portStatus`, `dialogueLanguage`,
`calendar.birthDate`, `todos`.

## 2. rules.json (required)

Any object; every key has a default, wrong types fall back silently. Sections
are open-ended (mechanics `{"rule":[section,key,fallback]}` can read any key).
**Engine defaults differ from kss16's values** (e.g. `study.studyWeight` 10 vs 3)
— an editor should show the effective value and where it came from.

| Key | Default |
|---|---|
| `stats.initial` (subject→num), `stats.max` | 0 each, 999999 |
| `hp.initial` / `max` / `min`, `hp.exhaustedPenaltyStat` | 100 / 100 / 0, −5 |
| `money.initial` / `min` | 0 / 0 |
| `refresh.initial`, `refresh.shared` | 0, false |
| `cookies.initial`, `cookies.shared` | 0, **true** |
| `day.blocksPerTick`, `day.actionTicksPerDay` | 4, 14 (clamped to ticksPerDay) |
| `day.sleepRestoresHp`, `day.sleepLocationBonusHp` | 60, 10 |
| `staminaCost.base` / `perWeight` / `lesson` | 9.5 / 6.25 / =base (cost = base + perWeight × hpWeight − exercise level) |
| `study.studyWeight`, `expPerStudy`, `comboBonusPercent`, `comboMaxStacks` | 10, 25, 0.05, 5 |
| `partTimeJob.baseMoney`, `expPerShift` | 1000, 60 |
| `exercise.expPerSession` | 80 |
| `events.randomEventChancePerTick`, `maxEventsPerDay` | 0.12, 3 |
| `events.rankWeights`, `priorityOrder` | `{}` (1 each), `[veryHigh, high, middle, low]` |
| `events.openingEventIds` | `[]` (missing ID → `StateError` at run start) |
| `events.careersPerRun` | 1 (0 = off; rank-A sets) |
| `events.scheduledBypassDailyCap`, `checkAtDayStart`, `chainScheduledEvents`, `executeFakeEvents`, `deferEveningRollover` | false |
| `school.lessonsEnabled`, `lessonsOnFirstDay`, `classTicks`, `locationId` | false, true, 6, start location |
| `school.lessonRankCap`, `lessonRankPerWeek`, `lessonSpread`, `lessonFactor`, `suppressedBySwitch` | 3, 1, 0.45, 1, none |
| `goals.weeklyStep`, `perStudyBlock`, `rewardRatio` | 348, 12, 0.74 |
| `stationery.drawWeights`, `redrawCookies`, `combineUpgradeChance` | `{S:1,A:9,B:30,C:60}`, 1, 0.05 |
| `traits.enabled`, `traits.chances` | true, none (keys: trait ID, or `-<characterId>`) |
| `traits.<name>` | free overrides named by abilities' `factorRule`/`pointsRule` |
| `setup.genderSelection`, `setup.genderPairs` | false, `[]` (`{forMale, forFemale}`) |
| `exam.enabled`, `curve`, `applications`, `admissionSpread`, `subjectLabels`, `gradExam` | true, built-in, 3, 2.0, none, none |
| `tasks.enabled`, `tasks.initial` | false, `[]` (`{id, title, date.dateCode}`) |

Inert in kss16: `_note`, `day.ticksPerDay`, `hp.exhaustedForcedSleep`,
`*.hpCostMultiplier`, `exercise.hpMaxPerLevel`, `tasks.initial[].minVersion`.

## 3. locations.json (required) — `{locations: [...]}`

Location: `id` int **REQ**; `name` `"Location"`; `description`; `type`
`"none"` (`sleep` adds the sleep bonus; types are also matched by trait/item
scopes and `FUNC_IS_LOCATION_TYPE`); `isDefaultLocked` false (true = starts
locked); `image` (backdrop path); `actions` `[]`. Inert: `funcCode`,
`isDefault`, `imgPath`.

Action: `locationActionType` `"none"` (`study`, `partTimeJob`, `exercise`,
`sleep` run built-in payouts; anything else, e.g. `special`, spends stamina
and runs its changer); `text` (empty = label from type); `weight` 1 (draw
weight); `hpWeight` 0 (stamina weight); `changer`; `conditionFuncCode` (must
name a mechanics predicate **or a declared switch**, else the action is hidden
and flagged); `conditionSet`; `blockDuplicated` false (once per day) with
`duplicatedKey` (default `"<type>:<text>"`). Inert: `failEventId`, `userBook`.

## 4. events/* — see [04-EVENT-AUTHORING.md](04-EVENT-AUTHORING.md)

## 5. items.json — `{items: [...]}`

| Field | Default | Notes |
|---|---|---|
| `id` | **REQ** | Icon is always `items/<id>.png`. |
| `name`, `description`, `effectText` | `"Item"`, `""`, `""` | `effectText` is display text; it doesn't execute. |
| `kind` | `consume` | `normal` = held, read passively. |
| `effects` | `[]` | See below. |
| `maxCount` | null | Inventory cap. |
| `detailTypes` | `[]` | Tags matched by abilities' `itemTag` (e.g. `milk`). |

Inert: `imgPath`, `scope`, `graphEvents`, `effectNote`, `locationIdList`, `flavour`.

**Usable** only if consumable (or an effect has `keepItem:true`) and it has an
on-use effect of a supported type; `ui` needs a known `action`. Effect types:

- On use: `stat` (`subject`: key/`all`/`random`/`chosen`/`elective`/`elective1`/`elective2`/`lesson`; `value` or `range:[lo,hi]`), `hp`, `money`, `exerciseExp`, `partTimeExp` (`value`/`range`), `hpMultiply` (`factor`), `hpSet`, `readCount` (`subject`, `value`), `acquireItem` (`itemId`, `count`), `acquireItemRandom` (`count`), `unlockLocation` (`locationId`), `switchAdd` (`switch`, `value`), `report` (`text` expression, or `switch`+`label`+`suffix`), `removeTraits` (`traitType`, default `bad`), `cureTrait` (`trait` name), `ui` (`action`: `predictedGrades`/`checkAbilities`/`recipes` + view data).
- Passive while held: `studyEfficiency` (`value`, `subject`), `exerciseEfficiency`, `partTimeEarnings` (`value`|`percent`), `sleepEfficiency`, `hpCost` (`value`), `goalReward`, `acceptanceRate` (`percent`). Optional `scope` `{locationId}`/`{locationType}`.
- `trigger: "onSleep"` runs on Sleep; any other trigger never applies.
- Optional `conditions` (targets `EXERCISE_LEVEL`, `PART_TIME_JOB_LEVEL`, `STUDY_LEVEL`, `LOCATION_ID`, `TICK`, `DATE_INT`; unknown targets pass).
- Inert: `preventEvent` (documentation of graph behavior), `surviveExhaustion`, `duration`.

## 6. traits.json — `{traits: [...]}`

`id` **REQ**; `name`; `description` (a `STAT_<n>` placeholder changes stat
scaling); `type` `good` (`bad` matters for removal/blocking, `normal`
neutral); `rank` `C` (S/A/B/C/none); `gachable` false (true = selectable in
setup); `storyId`; `locationIdList` / `locationType` (whole-trait scope);
`initialLifeTime` (days; null = permanent); `effectList`. Inert: `isDefault`,
`goalPowerType`, `notRefactor`.

Effect types: `plusStat` (`plusStatType` all/detail/tamgoos/lowSubject,
`subjectType`, `storyStat` preferred over `extraStat`, `excludeSchoolStudy`),
`schoolStudyPlusStat`, `hpCost` (`cost`, `locationActionType`,
`actionFuncCode`), `partTimeJobMoney` (`intPlusMoney`, `percentPlusMoney`
factor), `partTimeJobExp` / `exerciseExp` (`intPlusExp`, `percentPlusExp`),
`plusSleepHp` (`plusValue`), `goalReward` (`percentPlusReward`); run start
only: `firstPlusStat` (`stat`, `plusStatType`, `subjectType`),
`firstPlusMoney` (`money`), `firstExerciseLevel` / `firstPlusPartTimeJobLevel`
(`level`).

Effect `conditions` (ANDed; **a different vocabulary from events**): targets
`LOCATION_TYPE` (`strValue`), `IS_HAVE_ITEM`, `IS_HAVE_TRAIT`,
`IS_TODAY_IN_DATE_LIST` (`args`), `TICK_RANDOM` (`percent` 0..1),
`LOCATION_ID`, `TICK`, `WEEKCODE`, `DATE_WEEK`, `DATE_INT`, `COMBO_STUDY`,
`PREV_STUDY_SUBJECT`, `IS_BEFORE_SAT_EXAM`, `EXERCISE_LEVEL`,
`PART_TIME_JOB_LEVEL`, `STUDY_LEVEL`; `intValue`; `compareType` `equal`,
`notEqual`, `greater`, `greaterEqual`, `less`, `lessEqual`. Unsupported →
the effect fails closed.

Anything beyond `effectList` comes only from `mechanics.traitAbilities["<id>"]`.

## 7. characters.json — `{characters: [...]}` (needed in practice)

`id` **REQ**; `name`; `gender` `male` (anything but `female` = male); `rank`
`one`; `stars` 1; `isDefault` false (first default preselected; at least one
needed); `effectDescription` (display); `portrait` (path); `plusEffect` (one
trait-style effect); `specialFuncCode` (read by `characterCode` expressions;
setup shows "special ability coming soon"). Behavior beyond `plusEffect`:
`mechanics.characterAbilities["<id>"]`.

## 8. badges.json — `{badges: [...]}` keyed by `universityId`

`universityId` **REQ**; `name`; `rank` `none`; `colorCode` (hex, no `#`);
`crest`; `effects` (trait-effect vocabulary). Up to 7 worn. Should match
`colleges.json` university IDs (unchecked). Setup offers only badges of
colleges the account has enrolled in (account rule `setupRequiresOwnership`).

## 9. books.json — `{books: [...]}`

`id` **REQ**; `name`; `description`; `subject` (must be in `subjects`);
`power` 1 (main study input); `doneCount` 1 (reads to finish; drives progress
and next-tier unlock); `bookRank` "1" ("1".."6" display E..S). One book per
(subject, rank) is offered; tiers unlock in order. Inert: `hpWeight`,
`condition`, `extraDoneCount`.

## 10. levels.json

Keys `study`, `exercise`, `partTimeJob`, each a tier list or
`{levels:[…], locationEfficiency:[{locationId, weight}]}` (efficiency applies
to exercise and part-time only). Tier: `level`, `name`, `exp` (cumulative
threshold), `weight` (payout multiplier), `plusStat`. Also
`partTimeJob.textByLocation: [{locationId, textList}]`. Inert: `elite`.

## 11. commerce.json

`offers[]`: `id`, `price` **REQ**, `itemId` **REQ** at purchase (must exist),
`stock` 1 (weekly). `stationery[]`: `id`, `rank` S/A/B/C, `type` (slot),
`name`, `studyStats:[{isAll, subjectType, stat}]`; icon `stationery/<id>.png`.
`sets[]`: `id`, `name`, `equipmentItemIds`, `studyStats`.

## 12. quizzes.json — `{problems: [...]}`

`id` **REQ**; `subject` (`math`/`english` feed the quiz macros); `text`;
`options`; `answer` (zero-based; out of range crashes when drawn — validate).

## 13. colleges.json (and `colleges_<set>.json` overlays)

University: `id` **REQ**; `name`; `rank`; `colorCode`; `crest` (default
`kss/images/university/<id>.png`); `category`
korea/special/global/taiwan/retake; `stars`; `storyOnly`; `available`.
Department: `id`, `universityId`, `deviation` (CSAT cutoff) **REQ**; `name`;
`condition`; `requires.items`. University/department 0 is the retake
fallback. No catalog → borrows the default pack's; exam needs
`rules.exam.enabled` and at least one department. Overlay `{universities:
[{id, name?, colorCode?, crest?}], departments?}` renames matching IDs (also in
badges) and appends departments. Inert: `availableStories`.

## 14. presentation.json — see [05-ASSETS.md](05-ASSETS.md) §3

## 15. mechanics.json

Optional; `{}`/missing = no mechanics. Fully validated at load: any error →
`PackFormatException('mechanics.json', …)` and the pack fails.
Prose reference: [../MODULAR-PACKS.md](../MODULAR-PACKS.md). Validator facts:

- `version` must be exactly `1`. Sections: `predicates`, `callbacks`,
  `traitAbilities`, `characterAbilities`, `hooks`, `switchGuards`,
  `textMacros`, `bindings` (objects), `blocks` (list). Unknown top-level keys
  ignored. Limits: nesting 32, 20000 nodes.
- **Expressions:** a scalar, or an object with exactly one key from `literal
  arg args switch itemCount trait characterCode field rule predicate all any
  not if eq ne gt gte lt lte add sub mul div round lookup grade subjectStat
  subjectName randomInt roll dateAfter concat`. Binary ops take 2 operands,
  `if` 3, `lookup` 2–3, `rule` 2–3, `all/any/concat` a list. `field` ∈
  `storyId characterId locationId tick dateInt totalStat subjectCount
  exerciseLevel exerciseMaxed studyLevel money`. `predicate` must exist; cycles
  rejected. `randomInt` only inside callback/ability steps. `roll` needs
  `chance` (+ `seed`, optional `period:"day"`); `dateAfter` needs `month`,
  `day`. Wrap data objects in `{"literal":…}`.
- **Operations** (`op`; required keys): `setSwitch`/`addSwitch` (`name`,
  `value`), `addMoney`/`addHp` (`value`), `addStat` (`subject`, `value`),
  `grantItem` (`id`, opt `count`), `grantTrait`/`removeTrait` (`id`), `pulse`
  (`name`), `drawItem` (`pool`, opt `store`), `if` (`when`, `then`, opt
  `else`), `call` (`name`, opt `args`), `enableBlock`/`disableBlock` (`id`),
  `shiftCalendar` (`monthSwitch`, `daySwitch`, `days`), `setField` (`name:
  "movementLocked"`, `value`), `note` (`text`). Any map with an `op` key
  anywhere must name a known op.
- **Blocks:** `id` (unique non-empty string), `locations` (non-empty int
  list), `action` (LocationAction shape) unless `catalogOnly:true`; optional
  `aliases`, `when`, `defaultEnabled`, `enabledSwitch`.
- **Abilities** (`traitAbilities`/`characterAbilities`: numeric-string key →
  list): `type` ∈ `staminaFree surviveExhaustion priceFactor itemHpFactor
  moveHp studyRandomStat acceptanceFactor acceptancePoints callback hpCost
  priceOverride blockItemUse blockNegativeTrait`; common `when`, `chance`
  (0..1), `period` (`tick`/`day`). Required per type: `callback` → `callback`
  name + `steps`; `hpCost` → numeric `value`; `priceOverride` → `maxPrice`,
  `price`; `blockItemUse` → `itemTag`.
- **Hooks** (unvalidated names → callback): `exerciseLevelUp`,
  `actionCompleted`, `bookCompleted`, `sleep`, `dayStarted`, `arriveAtSchool`,
  `exhausted`, `traitAcquired`.
- `bindings`: `movementLockSwitch`, `subjectLabels`.
- Cross-references (block locations, item/trait IDs in steps, ability keys)
  are **not** checked.

## 16. Save state that references pack IDs

Renaming or deleting IDs breaks resume of saved runs or silently drops state
(`state.dart` toJson/fromJson): `packId`, `characterId`, `badgeIds`,
`initialTraitIds`, `traits`, `traitDaysLeft`, `locationId`,
`unlockedLocations`, `stats` (by subject), `inventory`, `itemUseCounts`,
`bookReadCounts`, `bookChoices`, `eventCounts`, `eventStates`, `switches`,
`taskDeadlines`, `blockOverrides`, `shopOfferIds`, `shopPurchases`,
`stationery*`, `careerSets`, `applications`, `admittedDepartments`,
`enrolledDepartment`. The editor should warn when an edit renumbers or removes
an ID in a pack that has been played.

## 17. Corrections to PACK-FORMAT.md found during extraction

- `books.doneCount` **is** read (only `hpWeight` isn't).
- `rules.json` sections also include `school`, `tasks`, `staminaCost`,
  `setup`, `traits`, `stats.max` and many `events.*` flags (table above).
- An `event` condition target reads a 0/1/2 state, not a fire count.

## 18. Engine bug found by the starter schemas (2026-10-26)

`changes[].type: "sub"` occurs 7 times in Retry Year (`EAT_COUNT`,
`LEE_LOVE_COUNT`, `SING_POINT`). `EffectEngine.applyChanger` handles only
`add` and treats every other type as `set`, so these subtractions assign the
value instead (e.g. `SING_POINT` −3 becomes `SING_POINT = 3`). Not fixed yet;
see 08-OPEN-QUESTIONS.md.
