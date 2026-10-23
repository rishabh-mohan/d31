import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'pack_image.dart';
import 'theme.dart';

class BooksMenu extends StatefulWidget {
  final Game game;
  const BooksMenu({super.key, required this.game});
  @override
  State<BooksMenu> createState() => _BooksMenuState();
}

class _BooksMenuState extends State<BooksMenu> {
  late String selected = widget.game.pack.manifest.subjects.first;
  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final books = game.menuBooks(selected);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              for (final subject in game.pack.manifest.subjects)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: InkWell(
                      key: ValueKey('book-subject-$subject'),
                      onTap: () => setState(() => selected = subject),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: D30Colors.subject(subject),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    subjectLabel(subject),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '${game.state.stats[subject]?.round() ?? 0}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: selected == subject
                                  ? D30Colors.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(indent: 20, endIndent: 20),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(height: 22),
            itemBuilder: (_, i) {
              final book = books[i];
              final rank = book.tier;
              final count = game.readCount(book);
              final unlocked = i == 0 || game.isBookComplete(books[i - 1]);
              final rankColor = switch (rank) {
                'E' => const Color(0xFFBFBFBF),
                'D' => const Color(0xFF927D78),
                _ => D30Colors.accent,
              };
              return Container(
                key: ValueKey('book-menu-${book.id}'),
                constraints: const BoxConstraints(minHeight: 140),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEDB),
                  border: Border.all(color: rankColor, width: 2),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        color: rankColor,
                        alignment: Alignment.center,
                        child: Text(
                          rank,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: unlocked
                              ? Column(
                                  children: [
                                    Text(
                                      book.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const Divider(),
                                    Text(
                                      '${subjectLabel(selected)} +${(book.power * game.pack.rules.studyWeight).round()}',
                                      style: const TextStyle(fontSize: 23),
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: book.doneCount > 0
                                          ? (count / book.doneCount).clamp(0, 1)
                                          : 1,
                                      backgroundColor: D30Colors.panelBorder,
                                      color: D30Colors.accent,
                                    ),
                                    Text(
                                      '$count / ${book.doneCount}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    const Icon(Icons.lock, size: 50),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Unlocked when you complete reading ${books[i - 1].name}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BagsMenu extends StatefulWidget {
  final Game game;
  const BagsMenu({super.key, required this.game});
  @override
  State<BagsMenu> createState() => _BagsMenuState();
}

class _BagsMenuState extends State<BagsMenu> {
  bool consumables = true;
  bool newestFirst = true;

  Widget filterButton(String label, bool selected, VoidCallback onTap) =>
      SizedBox(
        width: 135,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: D30Colors.ink,
            side: const BorderSide(color: D30Colors.accent, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? D30Colors.accent : Colors.transparent,
                  border: Border.all(color: D30Colors.accent),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final entries = game.state.inventory.entries
        .where(
          (e) =>
              e.value > 0 &&
              game.pack.items[e.key]?.isConsumable == consumables,
        )
        .toList();
    if (newestFirst) entries.setAll(0, entries.reversed.toList());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 10,
            children: [
              filterButton(
                'Consumables',
                consumables,
                () => setState(() => consumables = true),
              ),
              filterButton(
                'Other Items',
                !consumables,
                () => setState(() => consumables = false),
              ),
            ],
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 26),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: D30Colors.accent,
                foregroundColor: D30Colors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: () => setState(() => newestFirst = !newestFirst),
              icon: Icon(
                newestFirst ? Icons.arrow_upward : Icons.arrow_downward,
              ),
              label: const Text('Sort by recency'),
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'No items obtained yet.',
                    style: TextStyle(fontSize: 20),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    final item = game.pack.items[entry.key]!;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEDB),
                        border: Border.all(color: D30Colors.accent, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: PackImage(
                                  path: 'items/${item.id}.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${item.name} ×${entry.value}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text(item.effectText, textAlign: TextAlign.center),
                          if (item.isConsumable)
                            TextButton(
                              onPressed: () => setState(() {
                                game.useItem(item.id);
                              }),
                              child: const Text('Use'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
