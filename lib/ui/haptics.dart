import 'package:flutter/services.dart';

import '../engine/account_store.dart';

/// Rumble (F03). Every haptic goes through here so the persisted Settings
/// Rumble toggle gates them in one place. The trigger points are
/// reconstructed: there is no original evidence of which moments rumble.
class Haptics {
  Haptics._();

  /// Heavy: exhaustion / collapse.
  static void collapse() => _fire(HapticFeedback.heavyImpact);

  /// Medium: a level-up scene opening.
  static void levelUp() => _fire(HapticFeedback.mediumImpact);

  /// Light: an envelope opening onto its result card.
  static void reveal() => _fire(HapticFeedback.lightImpact);

  /// Selection click: a stationery draw or trait-pack roulette stopping.
  static void stop() => _fire(HapticFeedback.selectionClick);

  static void _fire(Future<void> Function() haptic) {
    if (!AccountStore.current.rumble) return;
    haptic();
  }
}
