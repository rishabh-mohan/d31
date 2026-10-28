/// TODO 84 M04: a run's cookies (and, when switched on, refresh tickets)
/// spend the account wallet, with a one-time grant.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  test('defaults: cookies and refresh tickets shared', () {
    final state = Game.newRun(pack, random: Random(1)).state;
    expect(state.sharesWallet('cookies'), isTrue);
    expect(state.sharesWallet('refresh'), isTrue);
    // Unattached (engine-only) runs keep the old per-run counters.
    expect(state.cookies, pack.rules.number('cookies', 'initial', 0));
    expect(state.rerolls, pack.rules.number('refresh', 'initial', 0));
  });

  test('a new run spends the account; the grant is paid once', () {
    final account = Account(cookies: 5);
    final game = Game.newRun(pack, random: Random(1));
    game.state.attachWallet(account);
    final initial = pack.rules.number('cookies', 'initial', 0).toInt();
    expect(account.cookies, 5 + initial);
    expect(game.state.cookies, account.cookies);
    expect(account.walletGrants, contains('cookies'));
    // Refresh tickets receive their one-time account grant too.
    expect(game.state.rerolls, 50);
    expect(account.refreshTokens, 50);

    // Spending goes through to the account.
    game.state.date = GameDate(DateTime(2023, 10, 19), 0);
    expect(game.beginWeeklyStationeryDraw(), isTrue);
    expect(game.redrawStationery(), isTrue); // free
    final before = account.cookies;
    expect(game.redrawStationery(), isTrue); // one cookie
    expect(account.cookies, before - 1);

    // Dev-panel style edits land on the account too.
    game.state.cookies = 77;
    expect(account.cookies, 77);

    account.refreshTokens = 7;
    // A second run gets no second grant.
    final next = Game.newRun(pack, random: Random(2)).state;
    next.attachWallet(account);
    expect(next.rerolls, 7);
    expect(account.refreshTokens, 7);
    expect(account.cookies, 77);
  });

  test('a shared save keeps no balance of its own and resumes on the '
      'account', () {
    final account = Account(cookies: 30);
    final state = Game.newRun(pack, random: Random(1)).state
      ..attachWallet(account);
    final json = state.toJson();
    expect(json['cookies'], 0);
    account.cookies = 12;
    final resumed = GameState.fromJson(pack, json)..attachWallet(account);
    expect(account.cookies, 12);
    expect(resumed.cookies, 12);
  });

  test('refresh tickets can be per-run by the rules switch', () async {
    final p = pack;
    final account = Account();
    final game = Game.newRun(p, random: Random(1));
    game.state.attachWallet(account);
    expect(account.refreshTokens, 50);
    expect(game.refreshHand(), isTrue);
    expect(account.refreshTokens, 49);
    expect(game.state.toJson()['rerolls'], 0);
  });

  test('the account round-trips its grants, username and settings', () {
    final a = Account(
      walletGrants: {'cookies'},
      username: 'Greg',
      bgm: false,
      music: MusicType.carol,
    );
    final b = Account.fromJson(a.toJson());
    expect(b.walletGrants, {'cookies'});
    expect(b.username, 'Greg');
    expect(b.bgm, isFalse);
    expect(b.sfx, isTrue);
    expect(b.music, MusicType.carol);
    expect(Account.fromJson({}).username, Account.defaultUsername);
  });

  test('First rename is free; later renames cost nine and check length', () {
    final a = Account(cookies: 10);
    expect(a.rename('G'), isFalse);
    expect(a.rename('x' * 17), isFalse);
    expect(a.rename(Account.defaultUsername), isFalse);
    expect(a.rename(' Greg '), isTrue);
    expect(a.username, 'Greg');
    expect(a.cookies, 10);
    expect(a.rename('Gregory'), isTrue);
    expect(a.cookies, 1);
    final restored = Account.fromJson(a.toJson());
    expect(restored.renameCost, 9);
    expect(a.renameProblem('Gregory2'), 'Not enough cookies.');
    expect(a.rename('Gregory2'), isFalse);
  });
}
