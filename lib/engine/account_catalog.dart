/// What Home's account pages list: endings, puzzles, universities by
/// region (assets/account/catalog.json, built by
/// tools/build_account_catalog.py), and the trait packs.
///
/// Trait pack odds are recovered: the original's published "Trait Pack
/// Probability Information" gives each pack's per-card rank rates, and the
/// card counts follow from its "at least one" rates (Standard 1.02% S over
/// 0.34% per card is three cards; Jumbo 1.69% is five). Prices and mileage
/// are recovered only for Standard (15 cookies, 10 mileage) and Jumbo (20,
/// 20), from MM-14/15; the rest are placeholders marked `priceRecovered:
/// false`.
library;

import 'dart:convert';

class EndingInfo {
  final int code;
  final String name;

  /// Cookies for reaching it the first time (Endings List, MM-06).
  final int cookies;

  const EndingInfo(this.code, this.name, this.cookies);

  /// The campaign an ending code belongs to: 30003 is Amnesia (3), 200004
  /// Retry Year (20).
  int get storyId => code ~/ 10000;
}

class PuzzlePiece {
  /// fixed, ending, gameCount, purchaseStory, friendInvite or eventPackage.
  final String type;
  final int? endingCode;

  /// The piece's share of the Complete Now price: Ihyeon's Break's four
  /// pieces are 28 + 19 + 19 + 33 = the 99 the collection shows.
  final int cookies;

  const PuzzlePiece(this.type, {this.endingCode, this.cookies = 0});
}

class Puzzle {
  final String id;
  final String name;
  final String description;
  final int storyId;
  final List<PuzzlePiece> pieces;

  /// The pack that owns this puzzle, or null for the app's own event-limited
  /// ones. A `gameCount` piece counts finished runs of this pack.
  final String? packId;
  final String? packName;

  /// Where a pack puzzle's art lives (`<id>_thumbnail.png`, `<id>.png`):
  /// the pack's `images/puzzles` folder. Null for the app's own art.
  final String? artDir;

  /// Whether full-screen art is bundled. The original ships only the
  /// Amnesia desk and downloads the rest from Firebase Storage `wallpapers/`
  /// (sub_aa702c); tools/import_wallpapers.py bundles the ones captured
  /// from a real install's cache.
  final bool hasFullImage;

  const Puzzle({
    required this.id,
    required this.name,
    required this.description,
    required this.storyId,
    required this.pieces,
    this.packId,
    this.packName,
    this.artDir,
    this.hasFullImage = false,
  });

  /// One puzzle from a catalog or pack `puzzles.json` entry.
  factory Puzzle.fromJson(
    Map w, {
    int storyId = 0,
    String? packId,
    String? packName,
    String? artDir,
  }) => Puzzle(
    id: w['id'] as String,
    name: w['name'] as String? ?? '',
    description: w['description'] as String? ?? '',
    storyId: storyId,
    packId: packId,
    packName: packName,
    artDir: artDir,
    pieces: [
      for (final p in (w['pieces'] as List? ?? const []).cast<Map>())
        PuzzlePiece(
          p['type'] as String? ?? 'fixed',
          endingCode: (p['endingCode'] as num?)?.toInt(),
          cookies: (p['cookieCount'] as num?)?.toInt() ?? 0,
        ),
    ],
    hasFullImage: w['fullImage'] == true,
  );

  String get thumbnail => artDir == null
      ? 'kss/images/wallpaper_thumbnail/$id.png'
      : '$artDir/${id}_thumbnail.png';

  /// Full-screen art, where there is any.
  String? get fullImage => artDir != null
      ? (hasFullImage ? '$artDir/$id.png' : null)
      : hasFullImage
      ? 'kss/images/wallpaper_image/$id.png'
      : null;

  /// What Home draws when this is the background: the full-screen art, or
  /// failing that the square thumbnail, cropped to fill the screen.
  String get wallpaper => fullImage ?? thumbnail;

  int get totalCookies => pieces.fold(0, (sum, p) => sum + p.cookies);
}

/// One pack's puzzles and the icon its tile shows in the Puzzles menu.
class PuzzleShelf {
  final String packId;
  final String name;

  /// Absolute path of the pack's icon, or null to show the name.
  final String? icon;
  final List<Puzzle> puzzles;

  const PuzzleShelf(this.packId, this.name, this.icon, this.puzzles);
}

class CatalogUniversity {
  final int id;
  final String name;
  final String rank;
  final String? colorCode;

  /// korea, special, global or taiwan: the Achievements region bar.
  final String region;

  const CatalogUniversity({
    required this.id,
    required this.name,
    required this.rank,
    required this.colorCode,
    required this.region,
  });

  static const _ranks = [
    'none', 'one', 'two', 'three', 'four', 'five', //
    'six', 'seven', 'eight', 'nine', 'ten',
  ];

  /// Rank ten is five stars and nine four and a half (MM-03).
  double get stars => _ranks.indexOf(rank).clamp(0, 10) / 2;

  String get crest => 'kss/images/university/$id.png';
}

/// One kind of trait pack.
class TraitPackKind {
  final String id;
  final String name;

  /// standard, winter or retry: the Manage Traits campaign selector.
  final String campaign;
  final String image;
  final int cards;

  /// Per-card rank rates in percent (S, A, B, C).
  final Map<String, double> odds;

  /// S draws only from the campaign's own S traits (Snow Maiden: S (5)).
  final bool storySOnly;
  final int price;
  final int mileage;
  final bool priceRecovered;

  const TraitPackKind({
    required this.id,
    required this.name,
    required this.campaign,
    required this.image,
    required this.cards,
    required this.odds,
    required this.price,
    required this.mileage,
    this.storySOnly = false,
    this.priceRecovered = false,
  });

  /// "Obtain 3 or more C-and-above Traits" (MM-14).
  String get description {
    final floor = odds.containsKey('C') ? 'C' : 'B';
    return 'Obtain $cards or more $floor-and-above Traits';
  }

  static const _c = {'S': 0.34, 'A': 4.66, 'B': 15.0, 'C': 80.0};
  static const _b105 = {'S': 1.05, 'A': 10.0, 'B': 88.95};
  static const _b126 = {'S': 1.26, 'A': 10.0, 'B': 88.74};
  static const _b147 = {'S': 1.47, 'A': 10.0, 'B': 88.53};

  static const all = [
    TraitPackKind(
      id: 'standard',
      name: 'Standard Trait Pack',
      campaign: 'standard',
      image: 'kss/images/trait_pack/normal.png',
      cards: 3,
      odds: _c,
      price: 15,
      mileage: 10,
      priceRecovered: true,
    ),
    TraitPackKind(
      id: 'jumbo',
      name: 'Jumbo Trait Pack',
      campaign: 'standard',
      image: 'kss/images/trait_pack/jumbo.png',
      cards: 5,
      odds: _c,
      price: 20,
      mileage: 20,
      priceRecovered: true,
    ),
    TraitPackKind(
      id: 'royal',
      name: 'Royal Trait Pack',
      campaign: 'standard',
      image: 'kss/images/trait_pack/royal.png',
      cards: 3,
      odds: _b105,
      price: 30,
      mileage: 30,
    ),
    TraitPackKind(
      id: 'ultra',
      name: 'Ultra Trait Pack',
      campaign: 'standard',
      image: 'kss/images/trait_pack/ultra.png',
      cards: 5,
      odds: _b105,
      price: 50,
      mileage: 50,
    ),
    TraitPackKind(
      id: 'rudolph',
      name: 'Rudolph Trait Pack',
      campaign: 'winter',
      image: 'kss/images/trait_pack/rudolph.png',
      cards: 3,
      odds: _c,
      price: 15,
      mileage: 10,
    ),
    TraitPackKind(
      id: 'snowman',
      name: 'Snowman Trait Pack',
      campaign: 'winter',
      image: 'kss/images/trait_pack/snowman.png',
      cards: 3,
      odds: _b105,
      price: 30,
      mileage: 30,
    ),
    TraitPackKind(
      id: 'santa',
      name: 'Santa Trait Pack',
      campaign: 'winter',
      image: 'kss/images/trait_pack/santa.png',
      cards: 5,
      odds: _b126,
      price: 40,
      mileage: 40,
    ),
    TraitPackKind(
      id: 'snow_maiden',
      name: 'Snow Maiden Trait Pack',
      campaign: 'winter',
      image: 'kss/images/trait_pack/seolnyeo.png',
      cards: 5,
      odds: _b147,
      storySOnly: true,
      price: 50,
      mileage: 50,
    ),
    TraitPackKind(
      id: 'third_try',
      name: 'Third Try Trait Pack',
      campaign: 'retry',
      image: 'kss/images/trait_pack/samsoo.png',
      cards: 3,
      odds: _c,
      price: 15,
      mileage: 10,
    ),
    TraitPackKind(
      id: 'retry',
      name: 'Retry Trait Pack',
      campaign: 'retry',
      image: 'kss/images/trait_pack/jaesoo.png',
      cards: 3,
      odds: _b105,
      price: 30,
      mileage: 30,
    ),
    TraitPackKind(
      id: 'first_try',
      name: 'First Try Trait Pack',
      campaign: 'retry',
      image: 'kss/images/trait_pack/hyunyeok.png',
      cards: 5,
      odds: _b126,
      price: 40,
      mileage: 40,
    ),
    TraitPackKind(
      id: 'advanced',
      name: 'Advanced Class Trait Pack',
      campaign: 'retry',
      image: 'kss/images/trait_pack/sanggeubban.png',
      cards: 5,
      odds: _b147,
      storySOnly: true,
      price: 50,
      mileage: 50,
    ),
  ];

  static TraitPackKind? byId(String id) {
    for (final kind in all) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  static const campaigns = {
    'standard': 'Standard',
    'winter': 'Endless Winter',
    'retry': 'The Year I Retook',
  };

  /// The story whose own traits join a campaign's pool.
  static int? storyOf(String campaign) => switch (campaign) {
    'winter' => 18,
    'retry' => 20,
    _ => null,
  };
}

class AccountCatalog {
  final Map<int, EndingInfo> endings;

  /// The app's own (event-limited) puzzles; each pack's are in [shelves].
  final List<Puzzle> puzzles;
  final List<PuzzleShelf> shelves;
  final Map<int, String> stories;
  final List<CatalogUniversity> universities;
  final int firstUniversityEnrollmentCookies;

  /// Setup offers only account-owned badges and traits (account-rules.json
  /// `setupRequiresOwnership`, default on; see SetupOwnership.fromAccount).
  final bool setupRequiresOwnership;

  const AccountCatalog({
    this.endings = const {},
    this.puzzles = const [],
    this.shelves = const [],
    this.stories = const {},
    this.universities = const [],
    this.firstUniversityEnrollmentCookies = 0,
    this.setupRequiresOwnership = true,
  });

  static const empty = AccountCatalog();

  factory AccountCatalog.fromJson(Map<String, dynamic> j) => AccountCatalog(
    firstUniversityEnrollmentCookies:
        ((j['rewards'] as Map?)?['firstUniversityEnrollmentCookies'] as num?)
            ?.toInt()
            .clamp(0, 1000000) ??
        0,
    setupRequiresOwnership:
        (j['rewards'] as Map?)?['setupRequiresOwnership'] as bool? ?? true,
    endings: {
      for (final e in (j['endings'] as List? ?? const []).cast<Map>())
        (e['code'] as num).toInt(): EndingInfo(
          (e['code'] as num).toInt(),
          e['name'] as String? ?? '',
          (e['cookies'] as num?)?.toInt() ?? 0,
        ),
    },
    puzzles: [
      for (final w in (j['wallpapers'] as List? ?? const []).cast<Map>())
        Puzzle.fromJson(w),
    ],
    stories: {
      for (final e in ((j['stories'] as Map?) ?? const {}).entries)
        int.parse('${e.key}'): '${e.value}',
    },
    universities: [
      for (final u in (j['universities'] as List? ?? const []).cast<Map>())
        CatalogUniversity(
          id: (u['id'] as num).toInt(),
          name: u['name'] as String? ?? '',
          rank: u['rank'] as String? ?? 'none',
          colorCode: u['colorCode'] as String?,
          region: u['region'] as String? ?? 'korea',
        ),
    ],
  );

  /// This catalog with the installed packs' puzzles listed.
  AccountCatalog withShelves(List<PuzzleShelf> shelves) => AccountCatalog(
    endings: endings,
    puzzles: puzzles,
    shelves: shelves,
    stories: stories,
    universities: universities,
    firstUniversityEnrollmentCookies: firstUniversityEnrollmentCookies,
    setupRequiresOwnership: setupRequiresOwnership,
  );

  List<Puzzle> get allPuzzles => [
    ...puzzles,
    for (final s in shelves) ...s.puzzles,
  ];

  factory AccountCatalog.parse(String text) =>
      AccountCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);

  List<EndingInfo> endingsOf(int storyId) =>
      endings.values.where((e) => e.storyId == storyId).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
}
