import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'commerce_screen.dart';

/// Compatibility entry point: backpack navigation shares the four tabs.
class InventoryScreen extends StatelessWidget {
  final Game game;
  const InventoryScreen({super.key, required this.game});
  @override
  Widget build(BuildContext context) =>
      CommerceScreen(game: game, initialMenu: PackMenu.items);
}
