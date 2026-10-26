/// Saved runs on disk.
///
/// The original restricts saving to the end of a day ("You may save once the
/// day is over", UIR-30). Its run list is Select Game (MM-26): a new-game tile
/// over one card per unfinished run, with no visible limit, so every run gets
/// its own file as it starts and keeps it until it finishes. A finished run
/// leaves this list for History (see record_store.dart).
///
/// A save file is `slot_<id>.json`, `{version, savedAt, summary, state}`. The
/// summary is duplicated out of the state so Select Game can list runs without
/// loading a ContentPack; the state itself is `GameState.toJson()`, which is
/// already round-tripped by the engine tests.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'pack.dart';
import 'state.dart';

/// What a Select Game card shows without reading a pack.
class SaveSummary {
  final int slot;
  final String name;
  final int daysRemaining;
  final DateTime savedAt;
  final Map<String, num> stats;
  final String packId;

  /// Pack-relative portrait path, drawn as the card's bust.
  final String portrait;

  /// The campaign's title, e.g. "31-Day Mode".
  final String modeTitle;

  const SaveSummary({
    required this.slot,
    required this.name,
    required this.daysRemaining,
    required this.savedAt,
    required this.stats,
    required this.packId,
    this.portrait = '',
    this.modeTitle = '',
  });

  /// The card's small number: the five study stats summed, so five 50s read
  /// 250 (MM-26, user-confirmed).
  int get statTotal => stats.values.fold<num>(0, (a, b) => a + b).round();

  Map<String, dynamic> toJson() => {
    'name': name,
    'daysRemaining': daysRemaining,
    'stats': stats,
    'packId': packId,
    'portrait': portrait,
    'modeTitle': modeTitle,
  };

  static SaveSummary? fromJson(int slot, Map<String, dynamic>? j, DateTime at) {
    if (j == null) return null;
    return SaveSummary(
      slot: slot,
      packId: j['packId'] as String,
      name: j['name'] as String? ?? '',
      daysRemaining: (j['daysRemaining'] as num?)?.toInt() ?? 0,
      savedAt: at,
      stats: ((j['stats'] as Map?) ?? const {}).map(
        (k, v) => MapEntry('$k', (v as num?) ?? 0),
      ),
      portrait: j['portrait'] as String? ?? '',
      modeTitle: j['modeTitle'] as String? ?? '',
    );
  }
}

class SaveStore {
  SaveStore._();

  static const _version = 1;

  static final _slotFile = RegExp(r'^slot_(\d+)\.json$');

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

  static Future<List<int>> _ids(Directory? dir) async {
    if (dir == null || !await dir.exists()) return const [];
    final ids = <int>[];
    await for (final entry in dir.list()) {
      final match = _slotFile.firstMatch(entry.uri.pathSegments.last);
      if (entry is File && match != null) ids.add(int.parse(match[1]!));
    }
    return ids;
  }

  /// Every readable save, most recently played first. A corrupt file is left
  /// out rather than taking the list down with it.
  static Future<List<SaveSummary>> list() async {
    final dir = await _directory();
    final saves = <SaveSummary>[];
    for (final id in await _ids(dir)) {
      final save = await summary(id, dir);
      if (save != null) saves.add(save);
    }
    saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return saves;
  }

  /// An id no save uses yet, for a run that is just starting.
  static Future<int> nextSlot() async {
    final ids = await _ids(await _directory());
    return ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b) + 1;
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
      // A corrupt or half-written save reads as missing.
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
        packId: state.pack.manifest.id,
        portrait: state.portrait,
        modeTitle: state.modeTitle,
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
      if (state['packId'] != pack.manifest.id) return null;
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
