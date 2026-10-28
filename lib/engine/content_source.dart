/// Where a pack is read from.
///
/// The app ships no content. Packs are directories (made with the sister
/// app) found under these roots, loaded straight from disk, and reloadable
/// from the dev panel without rebuilding:
///
///   desktop             packs/ beside the app (or its parent)
///   Android             app external-storage packs/ or documents packs/
///
/// See docs/MODULAR-PACKS.md.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'pack.dart';

class PackLocation {
  final String id;
  final Directory? directory; // null only for packs built in memory
  PackLocation(this.id, this.directory);

  String get describe => directory?.path ?? 'in-memory pack';
}

class ContentSource {
  /// Pack roots to search instead of the platform defaults.
  @visibleForTesting
  static List<Directory>? rootsOverride;

  static final _validId = RegExp(r'^[A-Za-z0-9_-]+$');

  static Future<List<Directory>> _packRoots() async {
    if (rootsOverride != null) return rootsOverride!;
    final roots = <Directory>[];
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      roots.addAll([Directory('packs'), Directory('../packs')]);
    }
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          roots.add(Directory('${dir.path}/packs'));
          // Pack Studio writes here: Android/media is reachable by an app with
          // "All files access", unlike Android/data.
          roots.add(
            Directory(
              dir.path
                  .replaceFirst('/Android/data/', '/Android/media/')
                  .replaceFirst(RegExp(r'/files$'), '/packs'),
            ),
          );
        }
      }
    } catch (_) {
      /* Optional platform storage. */
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      roots.add(Directory('${dir.path}/packs'));
    } catch (_) {
      /* No documents directory on this host. */
    }
    return roots;
  }

  /// Pack IDs found on disk, sorted by name.
  static Future<List<String>> availablePackIds() async {
    final ids = <String>{};
    for (final root in await _packRoots()) {
      if (!await root.exists()) continue;
      await for (final entry in root.list(followLinks: false)) {
        if (entry is Directory &&
            await File('${entry.path}/pack.json').exists()) {
          final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
          if (_validId.hasMatch(id)) ids.add(id);
        }
      }
    }
    return ids.toList()..sort();
  }

  /// Loads a pack from the first root that holds it; the first available
  /// pack when [packId] is null.
  static Future<(ContentPack, PackLocation)> load({String? packId}) async {
    if (packId == null) {
      final ids = await availablePackIds();
      if (ids.isEmpty) throw const FormatException('No content packs found');
      packId = ids.first;
    }
    if (!_validId.hasMatch(packId)) {
      throw const FormatException('Invalid pack ID');
    }
    for (final root in await _packRoots()) {
      final dir = Directory('${root.path}/$packId');
      if (await File('${dir.path}/pack.json').exists()) {
        return (await loadFromDirectory(dir), PackLocation(packId, dir));
      }
    }
    throw FormatException('Pack "$packId" not found');
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
}
