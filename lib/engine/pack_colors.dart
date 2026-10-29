/// Pack-owned UI colors. Pure Dart so the editor and game validate identically.
class PackColorScheme {
  static const roles = <String, String>{
    'accent': 'Accent',
    'accentDark': 'Dark accent',
    'onAccent': 'Text on accent',
    'page': 'Page background',
    'panel': 'Panel background',
    'panelBorder': 'Panel borders',
    'ink': 'Main text',
    'inkSoft': 'Secondary text',
    'iconBackground': 'Pack icon background',
    'iconForeground': 'Pack icon text',
  };

  static const presetNames = <String, String>{
    'peach': 'Peach',
    'ocean': 'Ocean',
    'forest': 'Forest',
    'lavender': 'Lavender',
    'rose': 'Rose',
    'slate': 'Slate',
  };

  // accent, dark accent, page, panel, border, ink, secondary text.
  static const _presets = <String, List<int>>{
    'peach': [
      0xFFFF8B55,
      0xFFE2761F,
      0xFFFFF3E2,
      0xFFFFF9E9,
      0xFFF3C58E,
      0xFF4A3B2E,
      0xFF8A7765,
    ],
    'ocean': [
      0xFF367EB3,
      0xFF235778,
      0xFFEDF5FB,
      0xFFF8FCFF,
      0xFFABCBE0,
      0xFF203E50,
      0xFF527080,
    ],
    'forest': [
      0xFF3D815A,
      0xFF285B3D,
      0xFFF0F6EC,
      0xFFFAFCF6,
      0xFFB6CFA7,
      0xFF2D422D,
      0xFF5D7358,
    ],
    'lavender': [
      0xFF8661B1,
      0xFF60417F,
      0xFFF5F0FA,
      0xFFFDF9FF,
      0xFFD4BDE9,
      0xFF463650,
      0xFF786387,
    ],
    'rose': [
      0xFFAD5574,
      0xFF7F3650,
      0xFFFFF0F4,
      0xFFFFF8FA,
      0xFFE8B8C9,
      0xFF51333D,
      0xFF84616E,
    ],
    'slate': [
      0xFF5A7287,
      0xFF3E5265,
      0xFFF0F3F6,
      0xFFFAFCFE,
      0xFFB8C6D2,
      0xFF2B3946,
      0xFF647482,
    ],
  };

  final String preset;
  final Map<String, int> overrides;

  const PackColorScheme({this.preset = 'peach', this.overrides = const {}});

  factory PackColorScheme.fromJson(Object? value) {
    if (value == null) return const PackColorScheme();
    if (value is! Map) {
      throw const FormatException('colorScheme must be an object');
    }
    final preset = value['preset'] ?? 'peach';
    if (preset is! String || !_presets.containsKey(preset)) {
      throw FormatException(
        'colorScheme.preset must be one of ${presetNames.keys.join(', ')}',
      );
    }
    final colors = value['colors'] ?? const {};
    if (colors is! Map) {
      throw const FormatException('colorScheme.colors must be an object');
    }
    final overrides = <String, int>{};
    for (final key in roles.keys) {
      if (!colors.containsKey(key)) continue;
      final color = colors[key];
      if (color is! String || !isHex(color)) {
        throw FormatException(
          'colorScheme.colors.$key must be a color such as #367EB3',
        );
      }
      overrides[key] = 0xFF000000 | int.parse(color.substring(1), radix: 16);
    }
    return PackColorScheme(
      preset: preset,
      overrides: Map.unmodifiable(overrides),
    );
  }

  static bool isHex(String value) =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value);
  static String hex(int color) =>
      '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  int color(String role) {
    final override = overrides[role];
    if (override != null) return override;
    final base = _presets[preset]!;
    return switch (role) {
      'accent' => base[0],
      'accentDark' => base[1],
      'onAccent' => 0xFFFFFFFF,
      'page' => base[2],
      'panel' => base[3],
      'panelBorder' => base[4],
      'ink' => base[5],
      'inkSoft' => base[6],
      'iconBackground' => color('accent'),
      'iconForeground' => color('onAccent'),
      _ => throw ArgumentError.value(role, 'role', 'Unknown pack color'),
    };
  }
}
