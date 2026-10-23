/// Where a pack is read from, and how it becomes editable.
///
/// The bundled pack ships read-only inside the app. On first run it is copied
/// to a writable directory and loaded from there instead, so the JSON can be
/// edited and reloaded without rebuilding:
///
///   desktop             (the repo's own packs/ dir)
///   Android
///             reachable with `adb push`, then "Reload pack" in the dev panel
///
/// Reload is live: the dev panel re-reads the directory and rebuilds the
/// ContentPack, so a JSON edit is one button away from being in the run.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'pack.dart';

class PackLocation {
  final String id;
  final Directory? directory; // null when loaded straight from assets
  final bool editable;
  PackLocation(this.id, this.directory, this.editable);

  String get describe =>
      directory == null ? 'bundled assets (read-only)' : directory!.path;
}

class ContentSource {
  static const defaultPackId = 'kss16';

  /// Where an editable copy lives. Checked in order; the first that exists
  /// and holds a pack.json wins.
  static Future<Directory?> _findWritableDir(String packId) async {
    final candidates = <Directory>[];

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Running from the repo: edit packs/ in the project and restart or reload.
      candidates.add(Directory('packs/$packId'));
      candidates.add(Directory('../packs/$packId'));
    }

    try {
      final ext = !kIsWeb && Platform.isAndroid
          ? await getExternalStorageDirectory()
          : null;
      if (ext != null) candidates.add(Directory('${ext.path}/packs/$packId'));
    } catch (_) {
      // getExternalStorageDirectory is Android-only and may be unavailable.
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      candidates.add(Directory('${docs.path}/packs/$packId'));
    } catch (_) {
      // No documents dir (some test hosts); fall through to assets.
    }

    for (final dir in candidates) {
      if (await File('${dir.path}/pack.json').exists()) return dir;
    }
    return null;
  }

  /// Preferred destination for the editable copy.
  static Future<Directory?> _writableTarget(String packId) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) return Directory('${ext.path}/packs/$packId');
      }
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/packs/$packId');
    } catch (_) {
      return null;
    }
  }

  /// Loads a pack, preferring an editable on-disk copy and seeding one from
  /// the bundled assets if none exists yet.
  static Future<(ContentPack, PackLocation)> load({
    String packId = defaultPackId,
    bool seedIfMissing = true,
  }) async {
    final existing = await _findWritableDir(packId);
    if (existing != null) {
      return (
        await loadFromDirectory(existing),
        PackLocation(packId, existing, true),
      );
    }

    final files = await _readAssets(packId);

    if (seedIfMissing) {
      final target = await _writableTarget(packId);
      if (target != null) {
        try {
          await _writeFiles(target, files);
          return (
            ContentPack.fromFiles(files),
            PackLocation(packId, target, true),
          );
        } catch (_) {
          // Read-only filesystem: fall back to the bundled copy.
        }
      }
    }

    return (ContentPack.fromFiles(files), PackLocation(packId, null, false));
  }

  static Future<ContentPack> loadFromDirectory(Directory dir) async {
    final files = <String, String>{};
    for (final name in ContentPack.allFiles) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        files[name] = await file.readAsString();
      }
    }
    return ContentPack.fromFiles(files);
  }

  static Future<Map<String, String>> _readAssets(String packId) async {
    final files = <String, String>{};
    for (final name in ContentPack.allFiles) {
      try {
        files[name] = await rootBundle.loadString('packs/$packId/$name');
      } on FlutterError {
        // Optional files legitimately absent.
        if (ContentPack.requiredFiles.contains(name)) rethrow;
      }
    }
    return files;
  }

  static Future<void> _writeFiles(
    Directory dir,
    Map<String, String> files,
  ) async {
    for (final entry in files.entries) {
      final file = File('${dir.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }

  /// Rewrites one pack file in place. Used by the dev panel's rules editor.
  static Future<void> writeFile(
    Directory dir,
    String name,
    Map<String, dynamic> content,
  ) async {
    final file = File('${dir.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent(' ').convert(content),
    );
  }

  /// Restores a pack directory from the bundled assets, discarding edits.
  static Future<void> resetToBundled(Directory dir, String packId) async {
    final files = await _readAssets(packId);
    await _writeFiles(dir, files);
  }
}
