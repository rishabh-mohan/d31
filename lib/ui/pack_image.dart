/// Resolves a pack-relative art path ("backgrounds/park.png") to something
/// Flutter can draw, decoded at the size it is actually drawn at.
///
/// A pack directory may ship its own `images/` folder; if it does, that file
/// wins. Otherwise the bundled placeholder under `assets/images/` is used.
/// This is what lets a future pack replace the art without touching code.
///
/// Both halves of this file exist for performance, and the reasons are worth
/// keeping:
///
///   * **Decode at display size.** The placeholder art is full-resolution —
///     the character portrait is 1488x1786, which is 10.1 MB once decoded to
///     RGBA, and the item icons are 1024x1024 (4 MB each) while being drawn
///     as ~40px thumbnails. Handing those straight to `Image` makes Flutter
///     decode and cache them at full size, and a screen with a dozen icons
///     has to push tens of megabytes through the raster thread. `ResizeImage`
///     decodes to the laid-out size instead, which is the single biggest win
///     available here.
///   * **Resolve once.** `resolve` used to `existsSync()` on every build. That
///     is a filesystem stat per image per frame, on the UI thread, at 60fps.
///     The result is cached and cleared on a pack reload.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/content_source.dart';

class PackImages {
  /// Pack directory to check first. Set once when the pack loads.
  static Directory? packDirectory;

  /// Cached path -> provider. Cleared whenever the pack location changes, so
  /// a reload still picks up newly-added overrides.
  static final Map<String, ImageProvider> _resolved = {};

  static void use(PackLocation location) {
    if (packDirectory?.path != location.directory?.path) {
      _resolved.clear();
    }
    packDirectory = location.directory;
  }

  /// Drops the resolution cache. Call after writing art into the pack.
  static void invalidate() => _resolved.clear();

  static ImageProvider? resolve(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final cached = _resolved[relativePath];
    if (cached != null) return cached;

    ImageProvider provider;
    final dir = packDirectory;
    final override = dir == null || kIsWeb
        ? null
        : File('${dir.path}/images/$relativePath');
    if (override != null && override.existsSync()) {
      provider = FileImage(override);
    } else {
      provider = AssetImage('assets/images/$relativePath');
    }
    _resolved[relativePath] = provider;
    return provider;
  }
}

/// The stand-in student drawn when a character's own portrait is not on disk.
const genericPortrait = 'character/portrait.png';

/// Draws pack art, falling back to a neutral block if the file is missing --
/// a pack referencing art it does not ship should look wrong, not crash.
class PackImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;

  /// Upper bound on the decoded size, in logical pixels. Leave null to take
  /// it from the layout, which is right almost everywhere; set it when the
  /// widget sits in an unbounded box and would otherwise decode full-size.
  final double? decodeWidth;
  final double? decodeHeight;

  const PackImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.decodeWidth,
    this.decodeHeight,
  });

  @override
  Widget build(BuildContext context) {
    final base = PackImages.resolve(path);
    if (base == null) return placeholder ?? const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);

        double? logicalW = decodeWidth;
        double? logicalH = decodeHeight;
        if (logicalW == null && constraints.maxWidth.isFinite) {
          logicalW = constraints.maxWidth;
        }
        if (logicalH == null && constraints.maxHeight.isFinite) {
          logicalH = constraints.maxHeight;
        }

        int? cacheW = _px(logicalW, dpr);
        int? cacheH = _px(logicalH, dpr);

        final provider = (cacheW == null && cacheH == null)
            ? base
            : ResizeImage(
                base,
                width: cacheW,
                height: cacheH,
                // Preserve the source aspect ratio before painting/cropping.
                policy: ResizeImagePolicy.fit,
                allowUpscaling: false,
              );

        return Image(
          image: provider,
          fit: fit,
          alignment: alignment,
          // The art never animates; skipping the fade avoids a rebuild storm
          // when a grid of icons scrolls into view.
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stack) =>
              placeholder ??
              ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
        );
      },
    );
  }

  static int? _px(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    // Clamped so a pathological constraint cannot ask for a huge decode.
    return (logical * dpr).round().clamp(1, 2048);
  }
}
