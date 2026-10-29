/// Pack-owned completion lottery configuration and serializable pending awards.
library;

class BookRewardRules {
  final Map<String, dynamic> raw;
  const BookRewardRules([this.raw = const {}]);
  bool get enabled => raw['enabled'] == true;
  int get itemDraws => (raw['itemDraws'] as num?)?.toInt() ?? 5;
  int? get fallbackItemId => (raw['fallbackItemId'] as num?)?.toInt();
  List<Map<String, dynamic>> get items =>
      (raw['items'] as List? ?? const []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? tier(String letter) =>
      (raw['tiers'] as Map?)?[letter] as Map<String, dynamic>?;

  void validate(Set<int> itemIds) {
    Never fail(String reason) =>
        throw FormatException('book_rewards.json: $reason');
    int count(dynamic value, String name) {
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value != value.round() ||
          value > 100000) {
        fail('$name must be a nonnegative integer (at most 100000)');
      }
      return value.toInt();
    }

    if (raw['enabled'] != null && raw['enabled'] is! bool) {
      fail('enabled must be true or false');
    }
    if (count(raw['itemDraws'] ?? 5, 'itemDraws') > 100) {
      fail('at most 100 item draws');
    }
    final ids = <int>{};
    for (final row in items) {
      final id = count(row['id'], 'item ID');
      if (!itemIds.contains(id)) fail('unknown item $id');
      if (!ids.add(id)) fail('duplicate item $id');
      if (!['low', 'middle', 'high'].contains(row['bucket'])) {
        fail('invalid bucket for item $id');
      }
      if (!['any', 'male', 'female'].contains(row['gender'] ?? 'any')) {
        fail('invalid gender for item $id');
      }
      if (row['enabled'] != null && row['enabled'] is! bool) {
        fail('item $id enabled must be true or false');
      }
    }
    if (raw['fallbackItemId'] != null &&
        !itemIds.contains(count(raw['fallbackItemId'], 'fallbackItemId'))) {
      fail('fallbackItemId must identify an item in this pack');
    }
    final tiers = raw['tiers'];
    if (tiers != null && tiers is! Map) fail('tiers must be an object');
    for (final entry in (tiers as Map? ?? const {}).entries) {
      if (!['E', 'D', 'C', 'B', 'A', 'S'].contains(entry.key) ||
          entry.value is! Map) {
        fail('invalid tier ${entry.key}');
      }
      final row = entry.value as Map;
      count(row['stat'] ?? 0, '${entry.key} stat');
      for (final section in ['items', 'traits']) {
        final table = row[section];
        if (table != null && table is! Map) {
          fail('${entry.key} $section must be an object');
        }
        final keys = section == 'items'
            ? ['low', 'middle', 'high']
            : ['C', 'B', 'A'];
        for (final e in (table as Map? ?? const {}).entries) {
          if (!keys.contains(e.key)) fail('invalid $section key ${e.key}');
          if (count(e.value, '${entry.key} ${e.key}') > 100 &&
              section == 'traits') {
            fail('at most 100 traits per grade');
          }
        }
      }
    }
    if (enabled &&
        !['E', 'D', 'C', 'B', 'A', 'S'].every((t) => tier(t) != null)) {
      fail('enabled rewards need all E–S tiers');
    }
  }
}

class BookReward {
  final String type; // item | trait | stat
  final int? id;
  final String? subject;
  final int amount;
  const BookReward(this.type, {this.id, this.subject, this.amount = 0});
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'subject': subject,
    'amount': amount,
  };
  factory BookReward.fromJson(Map<String, dynamic> j) => BookReward(
    j['type'] as String,
    id: j['id'] as int?,
    subject: j['subject'] as String?,
    amount: j['amount'] as int,
  );
}

class PendingBookReward {
  final int bookId;
  final List<BookReward> candidates;
  final int selectedIndex;
  final List<int> beforeItems;
  final int? unlockedBookId;
  String stage; // before | roulette | receipt | unlock
  bool revealed;
  bool awarded;
  bool traitGranted;
  PendingBookReward({
    required this.bookId,
    required this.candidates,
    required this.selectedIndex,
    this.unlockedBookId,
    List<int>? beforeItems,
    this.stage = 'before',
    this.revealed = false,
    this.awarded = false,
    this.traitGranted = false,
  }) : beforeItems = beforeItems ?? [];
  BookReward get selected => candidates[selectedIndex];
  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'candidates': candidates.map((r) => r.toJson()).toList(),
    'selectedIndex': selectedIndex,
    'beforeItems': beforeItems,
    'unlockedBookId': unlockedBookId,
    'stage': stage,
    'revealed': revealed,
    'awarded': awarded,
    'traitGranted': traitGranted,
  };
  factory PendingBookReward.fromJson(Map<String, dynamic> j) =>
      PendingBookReward(
        bookId: j['bookId'] as int,
        candidates: (j['candidates'] as List)
            .map((r) => BookReward.fromJson((r as Map).cast<String, dynamic>()))
            .toList(),
        selectedIndex: j['selectedIndex'] as int,
        beforeItems: (j['beforeItems'] as List).cast<int>(),
        unlockedBookId: j['unlockedBookId'] as int?,
        stage: j['stage'] as String,
        revealed: j['revealed'] as bool,
        awarded: j['awarded'] as bool,
        traitGranted: j['traitGranted'] as bool,
      );
}
