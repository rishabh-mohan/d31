/// What belongs to the player rather than to one run: Home's wallet and the
/// settings.
///
/// Home's balance pill shows cookies and refresh tokens (MM-01, 53 / 522 in
/// the capture). Nothing in d30mode earns or spends them yet, and the
/// original's charging and store rules were not recovered, so both start at
/// zero rather than at an invented allowance.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Which admissions catalog a run applies to (TODO 41).
enum UniversitySet {
  korean('Korean universities'),
  us('US universities');

  final String label;
  const UniversitySet(this.label);
}

class Account {
  int cookies;
  int refreshTokens;
  UniversitySet universities;

  Account({
    this.cookies = 0,
    this.refreshTokens = 0,
    this.universities = UniversitySet.korean,
  });

  Map<String, dynamic> toJson() => {
    'cookies': cookies,
    'refreshTokens': refreshTokens,
    'universities': universities.name,
  };

  static Account fromJson(Map<String, dynamic> j) => Account(
    cookies: (j['cookies'] as num?)?.toInt() ?? 0,
    refreshTokens: (j['refreshTokens'] as num?)?.toInt() ?? 0,
    universities: UniversitySet.values.firstWhere(
      (u) => u.name == j['universities'],
      orElse: () => UniversitySet.korean,
    ),
  );
}

class AccountStore {
  AccountStore._();

  /// The loaded account. Defaults until [load] has run, and stays at the
  /// defaults on a host with no documents directory.
  static Account current = Account();

  @visibleForTesting
  static File? fileOverride;

  static Future<File?> _file() async {
    final override = fileOverride;
    if (override != null) return override;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return File('${docs.path}/account.json');
    } catch (_) {
      return null;
    }
  }

  static Future<Account> load() async {
    final file = await _file();
    try {
      if (file != null && await file.exists()) {
        current = Account.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // An unreadable account file keeps the defaults.
    }
    return current;
  }

  static Future<bool> save() async {
    final file = await _file();
    if (file == null) return false;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(current.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }
}
