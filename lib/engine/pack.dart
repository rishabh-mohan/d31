/// Content pack: every piece of the game that is data rather than code.
///
/// A pack is a directory of JSON. The engine holds no content of its own, so
/// swapping the directory swaps the whole game -- that is what makes "every
/// feature modifiable" true rather than aspirational. See docs/PACK-FORMAT.md.
library;

import 'dart:convert';

import 'game_date.dart';

/// Thin wrapper so hand-edited JSON yields a useful message instead of a cast
/// error ten frames deep.
class PackFormatException implements Exception {
  final String file;
  final String message;
  PackFormatException(this.file, this.message);
  @override
  String toString() => 'pack file "$file": $message';
}

Map<String, dynamic> _obj(String file, String raw) {
  final dynamic v = jsonDecode(raw);
  if (v is! Map<String, dynamic>) {
    throw PackFormatException(file, 'expected a JSON object at the top level');
  }
  return v;
}

List<Map<String, dynamic>> _list(
  String file,
  Map<String, dynamic> o,
  String key,
) {
  final dynamic v = o[key];
  if (v == null) return const [];
  if (v is! List) throw PackFormatException(file, '"$key" must be a list');
  return v.whereType<Map<String, dynamic>>().toList(growable: false);
}

// ---------------------------------------------------------------------------
// Manifest
// ---------------------------------------------------------------------------

class PackManifest {
  final String id;
  final String name;
  final String description;
  final GameDate startDate;
  final GameDate endDate;
  final int ticksPerDay;
  final int startLocationId;
  final String firstName;
  final String lastName;
  final List<String> subjects;
  final List<Map<String, dynamic>> specialDays;

  /// Which KSS story this pack is. The trait catalog is global and carries
  /// traits scoped to other stories; this is what rejects them.
  final int? storyId;

  PackManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.ticksPerDay,
    required this.startLocationId,
    required this.firstName,
    required this.lastName,
    required this.subjects,
    required this.specialDays,
    required this.storyId,
  });

  int get totalDays => startDate.daysUntil(endDate) + 1;

  factory PackManifest.fromJson(Map<String, dynamic> j) {
    final cal = (j['calendar'] as Map?)?.cast<String, dynamic>() ?? const {};
    final start = (j['start'] as Map?)?.cast<String, dynamic>() ?? const {};
    final startDate = GameDate.tryParse(cal['startDate'] as String?);
    final endDate = GameDate.tryParse(cal['endDate'] as String?);
    if (startDate == null || endDate == null) {
      throw PackFormatException(
        'pack.json',
        'calendar.startDate / calendar.endDate must be DATE_ codes',
      );
    }
    return PackManifest(
      id: j['id'] as String? ?? 'pack',
      name: j['name'] as String? ?? 'Untitled',
      description: j['description'] as String? ?? '',
      startDate: startDate,
      endDate: endDate,
      ticksPerDay: (cal['ticksPerDay'] as num?)?.toInt() ?? 15,
      startLocationId: (start['locationId'] as num?)?.toInt() ?? 1000,
      storyId: (j['storyId'] as num?)?.toInt(),
      firstName: start['firstName'] as String? ?? 'Player',
      lastName: start['lastName'] as String? ?? '',
      subjects:
          (j['subjects'] as List?)?.cast<String>() ??
          const ['korean', 'english', 'math', 'science', 'society'],
      specialDays:
          (j['specialDays'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
    );
  }
}

// ---------------------------------------------------------------------------
// Rules -- the tuning file. Read through helpers so a missing key falls back
// to a sane default rather than throwing on a half-edited file.
// ---------------------------------------------------------------------------

class Rules {
  final Map<String, dynamic> raw;
  Rules(this.raw);

  Map<String, dynamic> section(String name) =>
      (raw[name] as Map?)?.cast<String, dynamic>() ?? const {};

  num number(String section, String key, num fallback) {
    final v = this.section(section)[key];
    return v is num ? v : fallback;
  }

  bool flag(String section, String key, bool fallback) {
    final v = this.section(section)[key];
    return v is bool ? v : fallback;
  }

  Map<String, num> numberMap(String section, String key) {
    final v = this.section(section)[key];
    if (v is! Map) return const {};
    return v.map((k, val) => MapEntry(k.toString(), val is num ? val : 0));
  }

  int get ticksPerDay => number('day', 'ticksPerDay', 15).toInt();
  num get hpInitial => number('hp', 'initial', 100);
  num get hpMax => number('hp', 'max', 100);
  num get hpMin => number('hp', 'min', 0);
  num get moneyInitial => number('money', 'initial', 0);
  num get moneyMin => number('money', 'min', 0);
  num get sleepRestoresHp => number('day', 'sleepRestoresHp', 60);
  num get sleepLocationBonusHp => number('day', 'sleepLocationBonusHp', 10);
  num get studyWeight => number('study', 'studyWeight', 10);
  num get studyExp => number('study', 'expPerStudy', 25);
  num get comboBonusPercent => number('study', 'comboBonusPercent', 0.05);
  int get comboMaxStacks => number('study', 'comboMaxStacks', 5).toInt();
  num get partTimeBaseMoney => number('partTimeJob', 'baseMoney', 1000);
  num get partTimeExp => number('partTimeJob', 'expPerShift', 60);
  num get exerciseExp => number('exercise', 'expPerSession', 80);
  num get randomEventChance =>
      number('events', 'randomEventChancePerTick', 0.12);
  int get maxEventsPerDay => number('events', 'maxEventsPerDay', 3).toInt();
  Map<String, num> get rankWeights => numberMap('events', 'rankWeights');
  num get exhaustedPenaltyStat => number('hp', 'exhaustedPenaltyStat', -5);
}

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

class LocationAction {
  final String actionType;
  final String text;
  final num weight;
  final num hpWeight;
  final String? funcCode;
  final String? conditionFuncCode;
  final int? failEventId;
  final bool blockDuplicated;
  final String? duplicatedKey;
  final Map<String, dynamic>? changer;

  LocationAction({
    required this.actionType,
    required this.text,
    required this.weight,
    required this.hpWeight,
    required this.funcCode,
    required this.conditionFuncCode,
    required this.failEventId,
    required this.blockDuplicated,
    required this.duplicatedKey,
    required this.changer,
  });

  factory LocationAction.fromJson(Map<String, dynamic> j) {
    final changer = (j['changer'] as Map?)?.cast<String, dynamic>();
    return LocationAction(
      actionType: j['locationActionType'] as String? ?? 'none',
      text: j['text'] as String? ?? '',
      weight: (j['weight'] as num?) ?? 1,
      hpWeight: (j['hpWeight'] as num?) ?? 0,
      funcCode: changer?['funcCode'] as String?,
      conditionFuncCode: j['conditionFuncCode'] as String?,
      failEventId: (j['failEventId'] as num?)?.toInt(),
      blockDuplicated: j['blockDuplicated'] as bool? ?? false,
      duplicatedKey: j['duplicatedKey'] as String?,
      changer: changer,
    );
  }

  /// Actions whose `text` is empty are the generic verbs; the UI names them
  /// from the action type instead.
  String label() {
    if (text.isNotEmpty) return text;
    switch (actionType) {
      case 'study':
        return 'Study';
      case 'partTimeJob':
        return 'Part-time job';
      case 'exercise':
        return 'Exercise';
      case 'sleep':
        return 'Sleep';
      default:
        return actionType;
    }
  }
}

class GameLocation {
  final int id;
  final String name;
  final String description;
  final String type;
  final String? funcCode;
  final bool isDefault;
  final bool isDefaultLocked;
  final String? imgPath;

  /// Pack-relative art path, e.g. "backgrounds/park.png". Resolved against
  /// the pack directory first, then the bundled assets.
  final String? image;
  final List<LocationAction> actions;

  GameLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.funcCode,
    required this.isDefault,
    required this.isDefaultLocked,
    required this.imgPath,
    required this.image,
    required this.actions,
  });

  factory GameLocation.fromJson(Map<String, dynamic> j) => GameLocation(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? 'Location',
    description: j['description'] as String? ?? '',
    type: j['type'] as String? ?? 'none',
    funcCode: j['funcCode'] as String?,
    isDefault: j['isDefault'] as bool? ?? false,
    isDefaultLocked: j['isDefaultLocked'] as bool? ?? false,
    imgPath: j['imgPath'] as String?,
    image: j['image'] as String?,
    actions: (j['actions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LocationAction.fromJson)
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

/// One branch of an `option` node. KSS inlines these in the node rather than
/// pointing at separate branch nodes: each carries its own label, its target,
/// and optionally a condition that hides it.
class EventOption {
  final String text;
  final int? nextNodeId;
  final int? nextBoxId;
  final Map<String, dynamic>? conditionSet;

  EventOption({
    required this.text,
    required this.nextNodeId,
    required this.nextBoxId,
    required this.conditionSet,
  });

  factory EventOption.fromJson(Map<String, dynamic> j) => EventOption(
    text: j['text'] as String? ?? '...',
    nextNodeId: (j['nextNodeId'] as num?)?.toInt(),
    nextBoxId: (j['nextBoxId'] as num?)?.toInt(),
    conditionSet: (j['conditionSet'] as Map?)?.cast<String, dynamic>(),
  );
}

class EventNode {
  final int? standingId;
  final bool standingOff;
  final String standingExpression;
  final String standingClothes;
  final List<String> otherLayers;
  final int id;
  final int boxId;
  final String type;
  final String? text;
  final String? elseText;
  final String? optionText;
  final int? nextNodeId;
  final int? nextNodeIdIfTrue;
  final int? nextNodeIdIfFalse;
  final List<EventOption> options;
  final int speakerId;
  final bool isHideSpeakerName;
  final String? backgroundImg;
  final String? imgPath;
  final Map<String, dynamic>? changer;
  final Map<String, dynamic>? actionChanger;
  final Map<String, dynamic>? conditionSet;
  final Map<String, dynamic>? eventSound;

  EventNode({
    this.standingId,
    this.standingOff = false,
    this.standingExpression = 'defaults',
    this.standingClothes = 'defaults',
    this.otherLayers = const [],
    required this.id,
    required this.boxId,
    required this.type,
    required this.text,
    required this.elseText,
    required this.optionText,
    required this.nextNodeId,
    required this.nextNodeIdIfTrue,
    required this.nextNodeIdIfFalse,
    required this.options,
    required this.speakerId,
    required this.isHideSpeakerName,
    required this.backgroundImg,
    required this.imgPath,
    required this.changer,
    required this.actionChanger,
    required this.conditionSet,
    required this.eventSound,
  });

  factory EventNode.fromJson(Map<String, dynamic> j) => EventNode(
    standingId: (j['standingId'] as num?)?.toInt(),
    standingOff: j['standingOff'] == true,
    standingExpression: j['standingExpression'] as String? ?? 'defaults',
    standingClothes: j['standingClothes'] as String? ?? 'defaults',
    otherLayers: (j['otherLayerList'] as List? ?? [])
        .whereType<String>()
        .toList(),
    id: (j['id'] as num).toInt(),
    boxId: (j['boxId'] as num?)?.toInt() ?? 0,
    type: j['type'] as String? ?? 'text',
    text: j['text'] as String?,
    elseText: j['elseText'] as String?,
    optionText: j['optionText'] as String?,
    nextNodeId: (j['nextNodeId'] as num?)?.toInt(),
    nextNodeIdIfTrue: (j['nextNodeIdIfTrue'] as num?)?.toInt(),
    nextNodeIdIfFalse: (j['nextNodeIdIfFalse'] as num?)?.toInt(),
    options: (j['options'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EventOption.fromJson)
        .toList(),
    speakerId: (j['speakerId'] as num?)?.toInt() ?? 0,
    isHideSpeakerName: j['isHideSpeakerName'] as bool? ?? false,
    backgroundImg: j['backgroundImg'] as String?,
    imgPath: j['imgPath'] as String?,
    changer: (j['changer'] as Map?)?.cast<String, dynamic>(),
    actionChanger: (j['actionChanger'] as Map?)?.cast<String, dynamic>(),
    conditionSet: (j['conditionSet'] as Map?)?.cast<String, dynamic>(),
    eventSound: (j['eventSound'] as Map?)?.cast<String, dynamic>(),
  );

  bool get isTerminal => type == 'last';
}

class GameEvent {
  final int id;
  final String name;
  final int rootNodeId;
  final String priority;
  final String rank;
  final String section;
  final int? eventSetId;
  final bool isRandomDate;
  final bool isFake;
  final Map<String, dynamic>? conditionSet;

  GameEvent({
    required this.id,
    required this.name,
    required this.rootNodeId,
    required this.priority,
    required this.rank,
    required this.section,
    required this.eventSetId,
    required this.isRandomDate,
    required this.isFake,
    required this.conditionSet,
  });

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? '',
    rootNodeId: (j['rootNodeId'] as num?)?.toInt() ?? -1,
    priority: j['priority'] as String? ?? 'middle',
    rank: j['rank'] as String? ?? 'C',
    section: j['section'] as String? ?? 'none',
    eventSetId: (j['eventSetId'] as num?)?.toInt(),
    isRandomDate: j['isRandomDate'] as bool? ?? false,
    isFake: j['isFake'] as bool? ?? false,
    conditionSet: (j['conditionSet'] as Map?)?.cast<String, dynamic>(),
  );
}

// ---------------------------------------------------------------------------
// Items, traits, levels, books
// ---------------------------------------------------------------------------

class GameItem {
  final int id;
  final String name;
  final String kind; // consume | normal
  final String description;
  final String effectText;
  final String? imgPath;
  final List<Map<String, dynamic>> effects;
  final bool flavour;
  final int? maxCount;

  GameItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.effectText,
    required this.imgPath,
    required this.effects,
    required this.flavour,
    required this.maxCount,
  });

  bool get isConsumable => kind == 'consume';

  factory GameItem.fromJson(Map<String, dynamic> j) => GameItem(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? 'Item',
    kind: j['kind'] as String? ?? 'consume',
    description: j['description'] as String? ?? '',
    effectText: j['effectText'] as String? ?? '',
    imgPath: j['imgPath'] as String?,
    effects: (j['effects'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(),
    flavour: j['flavour'] as bool? ?? false,
    maxCount: (j['maxCount'] as num?)?.toInt(),
  );
}

class GameTrait {
  final bool setupEligible;
  final int id;
  final String name;
  final String description;
  final String type; // good | bad
  final String rank;
  final List<Map<String, dynamic>> effects;

  /// Scope: the trait only counts at these locations, or at locations of
  /// this type. 39 traits carry one or the other.
  final List<int> locationIds;
  final String? locationType;

  /// The story this trait belongs to. 104 of 244 are story-scoped (3, 14,
  /// 16, 18, 20); a trait from another story must never be granted here.
  final int? storyId;

  /// Days the trait lasts once granted. Nine are temporary -- Flu 4, Fever
  /// Time 2, Hemorrhoids 5. Null is permanent.
  final int? lifeTimeDays;

  GameTrait({
    this.setupEligible = false,
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rank,
    required this.effects,
    required this.locationIds,
    required this.locationType,
    required this.storyId,
    required this.lifeTimeDays,
  });

  factory GameTrait.fromJson(Map<String, dynamic> j) => GameTrait(
    setupEligible: j['gachable'] == true,
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? 'Trait',
    description: j['description'] as String? ?? '',
    type: j['type'] as String? ?? 'good',
    rank: j['rank'] as String? ?? 'C',
    effects: (j['effectList'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(),
    locationIds: (j['locationIdList'] as List? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList(),
    locationType: j['locationType'] as String?,
    storyId: (j['storyId'] as num?)?.toInt(),
    lifeTimeDays: (j['initialLifeTime'] as num?)?.toInt(),
  );
}

/// One selectable character on the Student ID carousel.
///
/// `effectDescription` is the prose the card prints and **is not the
/// mechanic** — Siho Kang reads "+3" while `plusEffect` says `extraStat 6`.
/// The structured effect is what the engine applies.
class GameCharacter {
  final int id;
  final String name;
  final String gender;
  final String rank;
  final int stars;
  final bool isDefault;
  final String effectDescription;
  final String portrait;

  /// One structured effect, in the same vocabulary as a trait's.
  final Map<String, dynamic>? plusEffect;

  /// The two characters whose effect is compiled code rather than data
  /// (a crafting block each). Carried so the run knows, applied by nothing.
  final String? specialFuncCode;

  GameCharacter({
    required this.id,
    required this.name,
    required this.gender,
    required this.rank,
    required this.stars,
    required this.isDefault,
    required this.effectDescription,
    required this.portrait,
    required this.plusEffect,
    required this.specialFuncCode,
  });

  factory GameCharacter.fromJson(Map<String, dynamic> j) => GameCharacter(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? 'Character',
    gender: j['gender'] as String? ?? 'male',
    rank: j['rank'] as String? ?? 'one',
    stars: (j['stars'] as num?)?.toInt() ?? 1,
    isDefault: j['isDefault'] as bool? ?? false,
    effectDescription: j['effectDescription'] as String? ?? '',
    portrait: j['portrait'] as String? ?? '',
    plusEffect: (j['plusEffect'] as Map?)?.cast<String, dynamic>(),
    specialFuncCode: j['specialFuncCode'] as String?,
  );

  List<Map<String, dynamic>> get effects => [?plusEffect];

  bool get isMale => gender != 'female';
}

/// A university badge: up to seven are worn, and each applies once.
class UniversityBadge {
  final int universityId;
  final String name;
  final String rank;
  final String? colorCode;
  final List<Map<String, dynamic>> effects;

  UniversityBadge({
    required this.universityId,
    required this.name,
    required this.rank,
    required this.colorCode,
    required this.effects,
  });

  factory UniversityBadge.fromJson(Map<String, dynamic> j) => UniversityBadge(
    universityId: (j['universityId'] as num).toInt(),
    name: j['name'] as String? ?? 'University',
    rank: j['rank'] as String? ?? 'none',
    colorCode: j['colorCode'] as String?,
    effects: (j['effects'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(),
  );
}

class LevelTier {
  final int level;
  final String name;
  final num exp;
  final num weight;
  final num plusStat;

  LevelTier({
    required this.level,
    required this.name,
    required this.exp,
    required this.weight,
    required this.plusStat,
  });

  factory LevelTier.fromJson(Map<String, dynamic> j) => LevelTier(
    level: (j['level'] as num?)?.toInt() ?? 0,
    name: j['name'] as String? ?? '',
    exp: (j['exp'] as num?) ?? 0,
    weight: (j['weight'] as num?) ?? 1,
    plusStat: (j['plusStat'] as num?) ?? 0,
  );
}

class LevelTable {
  final List<LevelTier> tiers;
  final Map<int, num> locationEfficiency;

  LevelTable(this.tiers, this.locationEfficiency);

  /// Highest tier whose exp requirement is met. KSS's tables are cumulative
  /// for study/exercise/part-time but *per-level* for elite; the pack keeps
  /// them as authored, so this reads them cumulatively, which matches the
  /// three tables the loop actually uses.
  LevelTier tierFor(num exp) {
    LevelTier best = tiers.isEmpty
        ? LevelTier(level: 0, name: '', exp: 0, weight: 1, plusStat: 0)
        : tiers.first;
    for (final t in tiers) {
      if (exp >= t.exp) best = t;
    }
    return best;
  }

  num efficiencyAt(int locationId) => locationEfficiency[locationId] ?? 1;

  /// The top tier's level. Exercise tops out at 10 in story 16's table.
  int get maxLevel =>
      tiers.fold<int>(0, (best, t) => t.level > best ? t.level : best);

  /// The next tier's threshold, or null at the top. Drives the "0 / 495"
  /// progress line on the level box.
  num? nextThresholdAfter(num exp) {
    for (final t in tiers) {
      if (t.exp > exp) return t.exp;
    }
    return null;
  }
}

class GameBook {
  final int id;
  final String name;
  final String description;
  final String subject;
  final num power;
  final int doneCount;
  final num hpWeight;
  final String bookRank;

  GameBook({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.power,
    required this.doneCount,
    required this.hpWeight,
    required this.bookRank,
  });

  factory GameBook.fromJson(Map<String, dynamic> j) => GameBook(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? 'Book',
    description: j['description'] as String? ?? '',
    subject: j['subject'] as String? ?? 'korean',
    power: (j['power'] as num?) ?? 1,
    doneCount: (j['doneCount'] as num?)?.toInt() ?? 1,
    hpWeight: (j['hpWeight'] as num?) ?? 1,
    bookRank: j['bookRank']?.toString() ?? '1',
  );

  /// The tier as the game shows it. The shipped data numbers ranks "1".."6"
  /// but every surface in the original displays a letter — the grey circle on
  /// a study block and the coloured spine in the Books menu both read
  /// E/D/C/B/A/S, weakest to strongest. Anything unrecognised falls through
  /// unchanged rather than being hidden.
  String get tier =>
      const {
        '1': 'E',
        '2': 'D',
        '3': 'C',
        '4': 'B',
        '5': 'A',
        '6': 'S',
      }[bookRank] ??
      bookRank;
}

// ---------------------------------------------------------------------------
// The pack itself
// ---------------------------------------------------------------------------

class ContentPack {
  final Map<String, dynamic> presentation;
  final PackManifest manifest;
  final Rules rules;
  final Map<int, GameLocation> locations;
  final Map<int, GameEvent> events;
  final Map<int, EventNode> nodes;
  final Map<String, int> switchDefaults;
  final Map<String, String> switchLabels;
  final Map<int, GameItem> items;
  final Map<int, GameTrait> traits;
  final Map<int, GameBook> books;

  /// Character-select catalog, filtered to this story by the builder.
  final Map<int, GameCharacter> characters;

  /// University badges, keyed by `universityId` and already in the
  /// alphabetical order the badge screen lists them in.
  final Map<int, UniversityBadge> badges;
  final LevelTable studyLevels;
  final LevelTable exerciseLevels;
  final LevelTable partTimeLevels;

  /// The raw levels.json map, kept so UI-only extras (the per-location
  /// part-time job names) stay readable without a model for each one.
  final Map<String, dynamic> rawLevels;
  final Map<int, String> speakers;
  final Map<int, Map<String, dynamic>> shop;
  final Map<int, Map<String, dynamic>> stationery;
  final List<Map<String, dynamic>> stationerySets;
  final Map<int, GameEvent> systemEvents;
  final Map<int, EventNode> systemNodes;
  final Map<String, int> systemEventBindings;

  /// Nodes grouped by boxId: an `option` node's children are the nodes whose
  /// boxId is listed in its `options`, which is how KSS links choices.
  final Map<int, List<EventNode>> nodesByBox;

  ContentPack({
    this.presentation = const {},
    required this.manifest,
    required this.rules,
    required this.locations,
    required this.events,
    required this.nodes,
    required this.switchDefaults,
    required this.switchLabels,
    required this.items,
    required this.traits,
    required this.books,
    this.characters = const {},
    this.badges = const {},
    required this.studyLevels,
    required this.exerciseLevels,
    required this.partTimeLevels,
    required this.nodesByBox,
    this.rawLevels = const {},
    this.speakers = const {},
    this.shop = const {},
    this.stationery = const {},
    this.stationerySets = const [],
    this.systemEvents = const {},
    this.systemNodes = const {},
    this.systemEventBindings = const {},
  });

  /// Builds a pack from already-read file contents, keyed by the pack-relative
  /// path. Keeping IO out of here means the same loader serves bundled assets,
  /// a directory on disk, and tests.
  factory ContentPack.fromFiles(Map<String, String> files) {
    String need(String name) {
      final v = files[name];
      if (v == null) throw PackFormatException(name, 'missing from the pack');
      return v;
    }

    String? opt(String name) => files[name];

    final manifest = PackManifest.fromJson(
      _obj('pack.json', need('pack.json')),
    );
    final rules = Rules(_obj('rules.json', need('rules.json')));

    final locations = {
      for (final j in _list(
        'locations.json',
        _obj('locations.json', need('locations.json')),
        'locations',
      ))
        (j['id'] as num).toInt(): GameLocation.fromJson(j),
    };

    final evRaw = _obj('events/events.json', need('events/events.json'));
    final events = {
      for (final j in _list('events/events.json', evRaw, 'events'))
        (j['id'] as num).toInt(): GameEvent.fromJson(j),
    };
    final nodes = {
      for (final j in _list('events/events.json', evRaw, 'nodes'))
        (j['id'] as num).toInt(): EventNode.fromJson(j),
    };
    final nodesByBox = <int, List<EventNode>>{};
    for (final n in nodes.values) {
      nodesByBox.putIfAbsent(n.boxId, () => []).add(n);
    }
    for (final l in nodesByBox.values) {
      l.sort((a, b) => a.id.compareTo(b.id));
    }

    final switchDefaults = <String, int>{};
    final switchLabels = <String, String>{};
    final swRaw = opt('events/switches.json');
    if (swRaw != null) {
      for (final j in _list(
        'events/switches.json',
        _obj('events/switches.json', swRaw),
        'switches',
      )) {
        final name = j['name'] as String?;
        if (name == null) continue;
        switchDefaults[name] = (j['value'] as num?)?.toInt() ?? 0;
        final label = j['korName'] as String?;
        if (label != null && label.isNotEmpty) switchLabels[name] = label;
      }
    }

    Map<int, T> indexed<T>(
      String file,
      String key,
      T Function(Map<String, dynamic>) build,
    ) {
      final raw = opt(file);
      if (raw == null) return {};
      return {
        for (final j in _list(file, _obj(file, raw), key))
          (j['id'] as num).toInt(): build(j),
      };
    }

    final items = indexed('items.json', 'items', GameItem.fromJson);
    final traits = indexed('traits.json', 'traits', GameTrait.fromJson);
    final books = indexed('books.json', 'books', GameBook.fromJson);
    final system = opt('events/system.json');
    final systemBindings = system == null
        ? const <String, dynamic>{}
        : (_obj('events/system.json', system)['bindings'] as Map? ?? const {})
              .cast<String, dynamic>();

    LevelTable table(Map<String, dynamic> lv, String key, String listKey) {
      final sec = lv[key];
      final List listRaw;
      final eff = <int, num>{};
      if (sec is List) {
        listRaw = sec;
      } else if (sec is Map) {
        listRaw = (sec[listKey] as List?) ?? const [];
        for (final e in (sec['locationEfficiency'] as List? ?? const [])) {
          if (e is Map && e['locationId'] is num) {
            eff[(e['locationId'] as num).toInt()] = (e['weight'] as num?) ?? 1;
          }
        }
      } else {
        listRaw = const [];
      }
      return LevelTable(
        listRaw
            .whereType<Map<String, dynamic>>()
            .map(LevelTier.fromJson)
            .toList()
          ..sort((a, b) => a.exp.compareTo(b.exp)),
        eff,
      );
    }

    final lvRaw = opt('levels.json');
    final lv = lvRaw == null ? <String, dynamic>{} : _obj('levels.json', lvRaw);

    return ContentPack(
      presentation: opt('presentation.json') == null
          ? const {}
          : _obj('presentation.json', opt('presentation.json')!),
      manifest: manifest,
      rules: rules,
      locations: locations,
      events: events,
      nodes: nodes,
      switchDefaults: switchDefaults,
      switchLabels: switchLabels,
      items: items,
      traits: traits,
      books: books,
      studyLevels: table(lv, 'study', 'levels'),
      exerciseLevels: table(lv, 'exercise', 'levels'),
      partTimeLevels: table(lv, 'partTimeJob', 'levels'),
      nodesByBox: nodesByBox,
      rawLevels: lv,
      systemEvents: indexed('events/system.json', 'events', GameEvent.fromJson),
      systemNodes: indexed('events/system.json', 'nodes', EventNode.fromJson),
      systemEventBindings: {
        for (final e in systemBindings.entries) e.key: (e.value as num).toInt(),
      },
      speakers: {
        for (final n
            in (evRaw['speakers'] as List? ?? const []).whereType<Map>())
          (n['id'] as num).toInt(): n['name'] as String,
      },
      characters: indexed(
        'characters.json',
        'characters',
        GameCharacter.fromJson,
      ),
      badges: {
        for (final j
            in opt('badges.json') == null
                ? const <Map<String, dynamic>>[]
                : _list(
                    'badges.json',
                    _obj('badges.json', opt('badges.json')!),
                    'badges',
                  ))
          (j['universityId'] as num).toInt(): UniversityBadge.fromJson(j),
      },
      shop: indexed('commerce.json', 'offers', (j) => j),
      stationery: indexed('commerce.json', 'stationery', (j) => j),
      stationerySets: opt('commerce.json') == null
          ? const []
          : _list(
              'commerce.json',
              _obj('commerce.json', opt('commerce.json')!),
              'sets',
            ),
    );
  }

  /// Files a pack directory must contain, in load order.
  static const requiredFiles = [
    'pack.json',
    'rules.json',
    'locations.json',
    'events/events.json',
  ];
  static const optionalFiles = [
    'presentation.json',
    'events/switches.json',
    'events/sets.json',
    'events/system.json',
    'items.json',
    'traits.json',
    'books.json',
    'levels.json',
    'commerce.json',
    'characters.json',
    'badges.json',
  ];
  static List<String> get allFiles => [...requiredFiles, ...optionalFiles];

  /// Books of one subject, weakest first.
  ///
  /// Memoised: the pack is immutable once loaded, and this is called from the
  /// per-frame path (every study card resolves its book through
  /// `Game.studiableBooks`). Filtering and re-sorting all 54 books on each of
  /// those calls showed up as frame time.
  final Map<String, List<GameBook>> _booksBySubject = {};

  List<GameBook> booksFor(String subject) => _booksBySubject.putIfAbsent(
    subject,
    () => List<GameBook>.unmodifiable(
      books.values.where((b) => b.subject == subject).toList()
        ..sort((a, b) => a.power.compareTo(b.power)),
    ),
  );
}
