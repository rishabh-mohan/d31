import 'package:flutter/material.dart';

import '../engine/pack.dart';
import 'pack_image.dart';

/// All source layers share a canvas; fitting each into the same bounds keeps
/// the expression and clothing aligned with the body.
class Portrait extends StatelessWidget {
  final ContentPack pack;
  final int? id;
  final bool character;
  final String expression;
  final String clothes;
  final List<String> otherLayers;
  final String? fallback;
  const Portrait({
    super.key,
    required this.pack,
    required this.id,
    this.character = false,
    this.expression = 'defaults',
    this.clothes = 'defaults',
    this.otherLayers = const [],
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final catalog =
        pack.presentation[character ? 'characters' : 'npcs'] as Map?;
    final actor = catalog?['$id'] as Map?;
    String? layer(String group, String key) {
      final options = actor?[group] as Map?;
      return (options?[key] ?? options?['defaults']) as String?;
    }

    final paths = <String?>[
      actor?['skeleton'] as String?,
      layer('expressions', expression),
      layer('clothes', clothes),
      for (final name in otherLayers)
        (actor?['otherLayers'] as Map?)?[name] as String?,
    ].whereType<String>().toList();
    if (paths.isEmpty) {
      return PackImage(
        path: fallback,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        placeholder: const SizedBox.shrink(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final path in paths)
          PackImage(
            path: path,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            placeholder: const SizedBox.shrink(),
          ),
      ],
    );
  }
}
