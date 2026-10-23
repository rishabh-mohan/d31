/// Resolves a pack-relative art path ("backgrounds/park.png") to something
/// Flutter can draw.
///
/// A pack directory may ship its own `images/` folder; if it does, that file
/// wins. Otherwise the bundled placeholder under `assets/images/` is used.
/// This is what lets a future pack replace the art without touching code.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/content_source.dart';

class PackImages {
  /// Pack directory to check first. Set once when the pack loads.
  static Directory? packDirectory;

  static void use(PackLocation location) =>
      packDirectory = location.directory;

  static ImageProvider? resolve(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;

    final dir = packDirectory;
    if (dir != null && !kIsWeb) {
      final override = File('${dir.path}/images/$relativePath');
      // existsSync is a stat on a path we already hold; cheap enough to do
      // per build, and it keeps overrides live after a pack reload.
      if (override.existsSync()) return FileImage(override);
    }
    return AssetImage('assets/images/$relativePath');
  }
}

/// Draws pack art, falling back to a neutral block if the file is missing --
/// a pack referencing art it does not ship should look wrong, not crash.
class PackImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;

  const PackImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final provider = PackImages.resolve(path);
    if (provider == null) return placeholder ?? const SizedBox.shrink();
    return Image(
      image: provider,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stack) =>
          placeholder ??
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
    );
  }
}
