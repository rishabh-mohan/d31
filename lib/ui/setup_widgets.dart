import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/pack.dart';
import '../engine/setup.dart';
import 'portrait.dart';
import 'theme.dart';
import 'university_badge.dart';

const setupOrange = Color(0xFFFF8B55);
const setupInk = Color(0xFF502B0B);

Widget setupTitle(String text, {double size = 26}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 14),
  child: Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: size, color: setupInk),
  ),
);

Widget setupPanel(Widget child, {Color color = const Color(0xFFFFEEDB)}) =>
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: setupInk),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );

class CharacterCarousel extends StatefulWidget {
  final ContentPack pack;
  final RunSetup draft;
  final VoidCallback onChanged;
  const CharacterCarousel({
    super.key,
    required this.pack,
    required this.draft,
    required this.onChanged,
  });
  @override
  State<CharacterCarousel> createState() => _CharacterCarouselState();
}

class _CharacterCarouselState extends State<CharacterCarousel> {
  late final characters = widget.pack.characters.values.toList();
  late int selected = characters
      .indexWhere((c) => c.id == widget.draft.characterId)
      .clamp(0, characters.length - 1);
  late final pages = PageController(
    initialPage: selected,
    viewportFraction: .8,
  );
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 110,
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7974), Color(0xFFFFD5A3)],
          ),
        ),
        child: Center(
          child: Text(
            '${widget.pack.manifest.name}\nChoose your character',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      setupTitle('My Character'),
      Text(
        'Character Collection 100% (${characters.length}/${characters.length})',
        style: const TextStyle(color: Colors.brown),
      ),
      Expanded(
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: pages,
              itemCount: characters.length,
              onPageChanged: (i) {
                setState(() => selected = i);
                widget.draft.characterId = characters[i].id;
                widget.onChanged();
              },
              itemBuilder: (_, i) {
                final c = characters[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 15,
                  ),
                  child: Container(
                    key: ValueKey('character-${c.id}'),
                    decoration: BoxDecoration(
                      color: D30Colors.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFB08E79),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          color: const Color(0xFFF6C4BC),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${'★' * c.stars}  Student ID Card',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Portrait(
                              pack: widget.pack,
                              id: c.id,
                              character: true,
                              fallback: c.portrait,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              c.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '${c.effectDescription}${c.specialFuncCode != null || (!c.isDefault && c.effects.isEmpty) ? '\nSpecial ability coming soon.' : ''}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            for (final forward in [false, true])
              Align(
                alignment: forward
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: PressFeedback(
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: setupOrange),
                    tooltip: forward ? 'Next character' : 'Previous character',
                    icon: Icon(
                      forward
                          ? Icons.keyboard_double_arrow_right
                          : Icons.keyboard_double_arrow_left,
                    ),
                    onPressed: () => pages.animateToPage(
                      (selected + (forward ? 1 : -1)).clamp(
                        0,
                        characters.length - 1,
                      ),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class SetupBadgeList extends StatelessWidget {
  final ContentPack pack;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final String Function(Map<String, dynamic>) describe;
  const SetupBadgeList({
    super.key,
    required this.pack,
    required this.selected,
    required this.onToggle,
    required this.describe,
  });
  @override
  Widget build(BuildContext context) {
    final badges = pack.badges.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      children: [
        setupTitle('Select University Badges'),
        const Text('(up to 7 Badges)', style: TextStyle(fontSize: 17)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: UniversityBadgeSlots(
            pack: pack,
            ids: selected.toList(),
            onRemove: onToggle,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('(Alphabetical order)'),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: badges.length,
            itemBuilder: (_, i) {
              final b = badges[i];
              final chosen = selected.contains(b.universityId);
              final color = badgeColor(b);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: PressFeedback(
                  child: Material(
                    color: Color.lerp(Colors.white, color, .09),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      key: ValueKey('badge-${b.universityId}'),
                      onTap: () => onToggle(b.universityId),
                      child: Container(
                        height: 96,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: color,
                            width: chosen ? 4 : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 84,
                              child: UniversityBadgeView(
                                pack: pack,
                                id: b.universityId,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.effects.map(describe).join('\n'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: color),
                              ),
                            ),
                            if (chosen)
                              Icon(Icons.check_circle, color: color, size: 18),
                          ],
                        ),
                      ),
                    ),
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

class SetupTraitList extends StatelessWidget {
  final ContentPack pack;
  final RunSetup draft;
  final ValueChanged<int> onToggle;
  const SetupTraitList({
    super.key,
    required this.pack,
    required this.draft,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) {
    final traits =
        pack.traits.values.where((t) => RunSetup.eligible(t, pack)).toList()
          ..sort((a, b) {
            final rank = 'SABCDEF'
                .indexOf(a.rank)
                .compareTo('SABCDEF'.indexOf(b.rank));
            return rank == 0 ? a.name.compareTo(b.name) : rank;
          });
    final selected = draft.traits.toList();
    return Column(
      children: [
        setupTitle('Add Your Character’s Traits'),
        SizedBox(
          height: 205,
          child: setupPanel(
            Row(
              children: [
                Expanded(
                  child: Portrait(
                    pack: pack,
                    id: draft.characterId,
                    character: true,
                    fallback: pack.characters[draft.characterId]?.portrait,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: PressFeedback(
                              child: InkWell(
                                onTap: i < selected.length
                                    ? () => onToggle(selected[i])
                                    : null,
                                child: Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: i < selected.length
                                        ? const Color(0xFF3CB52F)
                                        : D30Colors.panel,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: setupOrange),
                                  ),
                                  child: Text(
                                    i < selected.length
                                        ? pack.traits[selected[i]]!.name
                                        : '—',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: i < selected.length
                                          ? Colors.white
                                          : setupOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            color: D30Colors.panel,
          ),
        ),
        Expanded(
          child: setupPanel(
            Column(
              children: [
                setupTitle('Traits List', size: 23),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(6),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 170,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: traits.length,
                    itemBuilder: (_, i) {
                      final t = traits[i];
                      final chosen = draft.traits.contains(t.id);
                      final tier = t.rank == 'S'
                          ? Colors.black87
                          : t.rank == 'A'
                          ? const Color(0xFFBDB44D)
                          : const Color(0xFF9B9B9B);
                      return PressFeedback(
                        child: InkWell(
                          key: ValueKey('setup-trait-${t.id}'),
                          onTap: () => onToggle(t.id),
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: D30Colors.panel,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: setupInk,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        color: tier,
                                        padding: const EdgeInsets.all(4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              ' ${t.rank}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Text(
                                              '×1',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              children: [
                                                Text(
                                                  t.name,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  t.description,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.brown,
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
                              ),
                              Icon(
                                chosen
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: setupOrange,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
