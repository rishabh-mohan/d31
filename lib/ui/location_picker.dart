/// "Class is over. Where do I go?"
///
/// Shown when the school day ends, and reachable from the menu. A card per
/// unlocked location: its backdrop, a badge naming what it is specialised in,
/// its name and description, and how many effects the player currently holds
/// that apply there.
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/pack.dart';
import 'pack_image.dart';
import 'theme.dart';

class LocationPicker extends StatelessWidget {
  final Game game;
  final String title;

  const LocationPicker({
    super.key,
    required this.game,
    this.title = 'Where do I go?',
  });

  /// Opens the picker and returns the chosen location id, if any.
  static Future<int?> show(
    BuildContext context, {
    required Game game,
    String title = 'Where do I go?',
    bool dismissible = true,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(
        canPop: dismissible,
        child: LocationPicker(game: game, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = game.pack.locations.values
        .where((l) => game.state.unlockedLocations.contains(l.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: D30Colors.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: D30Colors.ink,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, i) => _LocationCard(
                      location: options[i],
                      current: options[i].id == game.state.locationId,
                      relatedEffects: _relatedEffects(options[i]),
                      onTap: () => Navigator.of(context).pop(options[i].id),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Held passive effects whose scope names this location, either by id or by
  /// the location's type.
  int _relatedEffects(GameLocation location) {
    var count = 0;
    for (final entry in game.state.inventory.entries) {
      final item = game.pack.items[entry.key];
      if (item == null || item.isConsumable) continue;
      for (final e in item.effects) {
        final scope = e['scope'];
        if (scope is! Map) continue;
        final id = scope['locationId'];
        final type = scope['locationType'];
        if (id is num && id.toInt() == location.id) count++;
        if (type is String && type == location.type) count++;
      }
    }
    return count;
  }
}

class _LocationCard extends StatelessWidget {
  final GameLocation location;
  final bool current;
  final int relatedEffects;
  final VoidCallback onTap;

  const _LocationCard({
    required this.location,
    required this.current,
    required this.relatedEffects,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = locationTypeLabel(location.type);

    return Material(
      color: const Color(0xFFFFEFDC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: current ? D30Colors.accentDark : D30Colors.panelBorder,
              width: current ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: D30Colors.accent, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: PackImage(
                              path: location.image,
                              placeholder: const ColoredBox(
                                  color: Color(0xFFD9C7B4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: locationTypeColor(location.type),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                location.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: D30Colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: D30Colors.ink),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: D30Colors.accent, width: 1.5),
                ),
                child: Text(
                  '$relatedEffects Related Effect(s)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: D30Colors.accentDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
