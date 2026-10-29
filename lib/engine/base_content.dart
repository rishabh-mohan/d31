/// kss16's items and traits as general content for every campaign, plus the
/// one book-completion reward table every pack shares.
///
/// The files are a local-only asset layer (`assets/base/`, gitignored like
/// `assets/account/`) generated from the kss16 pack by
/// `d30mode-kss/tools/build_base_content.py`, so the app carries them without
/// the pack being installed and the KSS text never enters the repo. Every
/// [ContentPack] gets the items and traits merged beneath its own:
///
///   * a pack's own item or trait with the same id always wins;
///   * traits lose their story scope, so any campaign can grant them.
///
/// Events are not part of the layer: a pack author picks kss16 events in Pack
/// Studio, which copies them into the pack.
///
/// With no layer loaded (a fresh clone, or a test that never loads one) packs
/// load exactly as their files say.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pack.dart';

class BaseContent {
  static const fileNames = ['items.json', 'traits.json', 'book_rewards.json'];

  static const _assetDir = 'assets/base';

  static Map<String, String> _text = const {};
  static BaseLayer? _layer;

  /// The parsed layer, or null when none is loaded.
  static BaseLayer? get layer =>
      _text.isEmpty ? null : (_layer ??= BaseLayer.parse(_text));

  /// The completion-reward table every pack uses, or null when none is loaded.
  static Map<String, dynamic>? get bookRewards {
    final text = _text['book_rewards.json'];
    return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
  }

  /// Reads the bundled layer. A missing file leaves that part out.
  static Future<void> loadFromAssets([AssetBundle? bundle]) async {
    final from = bundle ?? rootBundle;
    final text = <String, String>{};
    for (final name in fileNames) {
      try {
        text[name] = await from.loadString('$_assetDir/$name');
      } catch (_) {
        /* The layer is optional. */
      }
    }
    use(text);
  }

  /// Replaces the layer; an empty map removes it.
  @visibleForTesting
  static void use(Map<String, String> text) {
    _text = Map.unmodifiable(text);
    _layer = null;
  }
}

/// The layer's content, parsed once and shared by every pack load.
class BaseLayer {
  final Map<int, GameItem> items;
  final Map<int, GameTrait> traits;

  BaseLayer._({required this.items, required this.traits});

  static List<Map<String, dynamic>> _list(String? text, String key) => text ==
          null
      ? const []
      : ((jsonDecode(text) as Map<String, dynamic>)[key] as List? ?? const [])
            .cast<Map<String, dynamic>>();

  factory BaseLayer.parse(Map<String, String> text) => BaseLayer._(
    items: {
      for (final j in _list(text['items.json'], 'items'))
        (j['id'] as num).toInt(): GameItem.fromJson(j),
    },
    traits: {
      for (final j in _list(text['traits.json'], 'traits'))
        // General content: no story scope, so every campaign can grant it.
        (j['id'] as num).toInt(): GameTrait.fromJson({...j}..remove('storyId')),
    },
  );
}
