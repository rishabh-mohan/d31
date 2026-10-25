/// Saving a rendered widget (the Student ID card) to the device gallery.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

/// Tests replace this to avoid the platform channel.
@visibleForTesting
Future<bool> Function(Uint8List png, String name)? gallerySaveOverride;

/// Renders the [RepaintBoundary] that [key] is attached to as a PNG and saves
/// it to the gallery as [name]. Returns false (never throws) when the widget
/// is not on screen, access is refused or the platform cannot save.
Future<bool> saveWidgetImage(GlobalKey key, String name) async {
  try {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return false;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return false;
    final bytes = data.buffer.asUint8List();
    final override = gallerySaveOverride;
    if (override != null) return await override(bytes, name);
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) return false;
    await Gal.putImageBytes(bytes, name: name);
    return true;
  } catch (_) {
    return false;
  }
}
