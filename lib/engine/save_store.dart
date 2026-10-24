/// Saved runs on disk.
///
/// The original restricts saving to the end of a day ("You may save once the
/// day is over", UIR-30), and that is the only part of its save system the
/// captures establish: there is **no reference screenshot of the slot list**,
/// so the shape here is the project's own. What it deliberately does not do is
/// invent account progression — a slot holds one run and nothing else.
///
/// A slot file is `{version, savedAt, summary, state}`. The summary is
/// duplicated out of the state so the title screen can list slots without
/// loading a ContentPack; the state itself is `GameState.toJson()`, which is
/// already round-tripped by the engine tests.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'pack.dart';
import 'state.dart';

/// What the slot list shows without reading a pack.
class SaveSummary {
  final int slot;
  final String name;
  final int daysRemaining;
  final DateTime savedAt;
  final Map<String, num> stats;

  const SaveSummary({
    required this.slot,
    required this.name,
    required this.daysRemaining,
    required this.savedAt,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'daysRemaining': daysRemaining,
    'stats': stats,
  };

  static SaveSummary? fromJson(int slot, Map<String, dynamic>? j, DateTime at) {
    if (j == null) return null;
    return SaveSummary(
      slot: slot,
      name: j['name'] as String? ?? '',
      daysRemaining: (j['daysRemaining'] as num?)?.toInt() ?? 0,
      savedAt: at,
      stats: ((j['stats'] as Map?) ?? const {}).map(
        (k, v) => MapEntry('$k', (v as num?) ?? 0),
      ),
    );
  }
}

class SaveStore {
  SaveStore._();

  /// Three, as the original's slot wording implies a small fixed set. Raising
  /// this is safe; the files are independent.
  static const slots = 3;

  static const _version = 1;

  /// Overridden by tests, which must not touch the real documents directory.
  @visibleForTesting
  static Directory? directoryOverride;

  static Future<Directory?> _directory() async {
    final override = directoryOverride;
    if (override != null) return override;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/saves');
    } catch (_) {
      // No documents directory on this host; saving is simply unavailable.
      return null;
    }
  }

  static File? _file(Directory? dir, int slot) =>
      dir == null ? null : File('${dir.path}/slot_$slot.json');

  /// Every slot, lowest first; `null` where a slot is empty or unreadable.
  static Future<List<SaveSummary?>> list() async {
    final dir = await _directory();
    return [for (var i = 0; i < slots; i++) await summary(i, dir)];
  }

  static Future<SaveSummary?> summary(int slot, [Directory? known]) async {
    final file = _file(known ?? await _directory(), slot);
    if (file == null || !await file.exists()) return null;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SaveSummary.fromJson(
        slot,
        (j['summary'] as Map?)?.cast<String, dynamic>(),
        DateTime.tryParse(j['savedAt'] as String? ?? '') ??
            await file.lastModified(),
      );
    } catch (_) {
      // A corrupt or half-written slot reads as empty rather than taking the
      // title screen down with it.
      return null;
    }
  }

  static Future<bool> write(int slot, GameState state) async {
    final file = _file(await _directory(), slot);
    if (file == null) return false;
    try {
      await file.parent.create(recursive: true);
      final summary = SaveSummary(
        slot: slot,
        name: state.fullName,
        daysRemaining: state.daysRemaining,
        savedAt: DateTime.now(),
        stats: Map<String, num>.from(state.stats),
      );
      // Written to a neighbour first: a kill mid-write must not destroy the
      // save that was already there.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({
          'version': _version,
          'savedAt': summary.savedAt.toIso8601String(),
          'summary': summary.toJson(),
          'state': state.toJson(),
        }),
      );
      await temp.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<GameState?> read(int slot, ContentPack pack) async {
    final file = _file(await _directory(), slot);
    if (file == null || !await file.exists()) return null;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final state = (j['state'] as Map?)?.cast<String, dynamic>();
      if (state == null) return null;
      return GameState.fromJson(pack, state);
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(int slot) async {
    final file = _file(await _directory(), slot);
    if (file != null && await file.exists()) await file.delete();
  }
}
