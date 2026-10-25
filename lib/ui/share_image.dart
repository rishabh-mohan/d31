/// Saving a widget as a picture in the phone's gallery (score card download,
/// and the enrollment certificate's save icon).
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';

/// Renders the [RepaintBoundary] behind [key] to a PNG at about 3x and saves
/// it to the gallery as [name] (no extension). Returns false on any failure
/// (no boundary yet, permission refused, no gallery on this platform).
///
/// Never throws: callers show a success or failure toast from the result.
Future<bool> saveWidgetImage(GlobalKey key, String name) async {
  try {
    final bytes = await renderWidgetPng(key);
    if (bytes == null) return false;
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) return false;
    }
    await Gal.putImageBytes(bytes, name: name);
    return true;
  } catch (error) {
    debugPrint('saveWidgetImage failed: $error');
    return false;
  }
}

/// The PNG bytes of the [RepaintBoundary] behind [key], or null if it is not
/// laid out yet.
Future<Uint8List?> renderWidgetPng(
  GlobalKey key, {
  double pixelRatio = 3,
}) async {
  final object = key.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
