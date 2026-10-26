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

/// What a badge or trait step shows when the account owns none: a message,
/// with Next still available, so setup is never a dead end.
class SetupEmptyNote extends StatelessWidget {
  final String title;
  final String body;
  const SetupEmptyNote({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 44,
            color: setupInk.withValues(alpha: .55),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: setupInk),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.brown),
          ),
        ],
      ),
    ),
  );
}

/// Select Character (2 / 5), second half: the protagonist's gender, for packs
/// that turn `rules.setup.genderSelection` on (TODO 65/66). The character's
/// own gender is recommended and its card is the bright one; tapping a card
/// chooses it and moves on. Layout from the user's reference capture.
class GenderSelectPage extends StatelessWidget {
  final bool recommendedMale;
  final ValueChanged<bool> onSelect;
  const GenderSelectPage({
    super.key,
    required this.recommendedMale,
    required this.onSelect,
  });

  static const _pink = Color(0xFFE5508A);
  static const _blue = Color(0xFF4F6FC4);

  @override
  Widget build(BuildContext context) {
    final word = recommendedMale ? 'Male' : 'Female';
    final colour = recommendedMale ? _blue : _pink;
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Select Gender',
          style: TextStyle(fontSize: 34, color: Color(0xFF4A2E12)),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 16, color: Color(0xFF4A2E12)),
            children: [
              const TextSpan(text: 'The selected character’s gender is '),
              TextSpan(
                text: word,
                style: TextStyle(color: colour),
              ),
              const TextSpan(text: '.\nWe recommend you to select '),
              TextSpan(
                text: word,
                style: TextStyle(color: colour),
              ),
              const TextSpan(text: '!'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        for (final male in [true, false]) ...[
          _GenderCard(
            key: ValueKey('gender-${male ? 'Male' : 'Female'}'),
            male: male,
            recommended: male == recommendedMale,
            onTap: () => onSelect(male),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  final bool male;
  final bool recommended;
  final VoidCallback onTap;
  const _GenderCard({
    super.key,
    required this.male,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final face = male ? const Color(0xFF919AB3) : const Color(0xFFF0959A);
    final edge = male ? const Color(0xFF6E7898) : const Color(0xFFE9636C);
    // The recommended card reads in cream; the other is muted.
    final ink = recommended ? const Color(0xFFFFF6E6) : const Color(0xFFC9C3B2);
    return PressFeedback(
      travel: 6,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 250,
          height: 168,
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: edge, width: 1.5),
            boxShadow: [
              BoxShadow(color: edge, offset: const Offset(0, 6)),
              const BoxShadow(
                color: Color(0x264A2B10),
                blurRadius: 8,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            child: Column(
              children: [
                Icon(male ? Icons.male : Icons.female, size: 96, color: ink),
                const SizedBox(height: 6),
                Text(
                  male ? 'Play as male' : 'Play as female',
                  style: TextStyle(fontSize: 28, color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  /// Only owned badges are listed; the original's captures show no locked
  /// entries in this list.
  final SetupOwnership ownership;
  const SetupBadgeList({
    super.key,
    required this.pack,
    required this.selected,
    required this.onToggle,
    required this.describe,
    this.ownership = SetupOwnership.unrestricted,
  });
  @override
  Widget build(BuildContext context) {
    final badges = [
      for (final b in pack.badges.values)
        if (ownership.ownsBadge(b.universityId)) b,
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (badges.isEmpty) {
      return Column(
        children: [
          setupTitle('Select University Badges'),
          const Text('(up to 7 Badges)', style: TextStyle(fontSize: 17)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: UniversityBadgeSlots(
              pack: pack,
              ids: const [],
              onRemove: onToggle,
            ),
          ),
          const Expanded(
            child: SetupEmptyNote(
              key: ValueKey('setup-badges-empty'),
              title: 'No university badges yet',
              body:
                  'Enroll in a university at the end of a run to unlock its '
                  'badge. You can start without badges.',
            ),
          ),
        ],
      );
    }
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
    // Owned, setup-eligible traits only, like the original's inventory list
    // with its ×n counts; no locked cards are shown.
    final traits = draft.traitChoices(pack)
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
                if (traits.isEmpty)
                  const Expanded(
                    child: SetupEmptyNote(
                      key: ValueKey('setup-traits-empty'),
                      title: 'No traits yet',
                      body:
                          'Get traits from trait packs on the Traits page. '
                          'You can start without traits.',
                    ),
                  )
                else
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
                                              Text(
                                                '×${draft.ownership.traitCount(t.id)}',
                                                style: const TextStyle(
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
