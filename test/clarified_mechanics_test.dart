import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/game_date.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/ui/commerce_screen.dart';

void main() {
  late ContentPack standard, retry;
  setUpAll(() async {
    standard = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
  });
  for (final male in [true, false]) {
    test(
      'gloves repeat the exact herb at 20%, ${male ? 'male' : 'female'} script',
      () {
        final p = retry.forPlayer(isMale: male);
        final game = Game.newRun(p, random: Random(42));
        final s = game.state..locationId = 20001;
        s.grantTrait(155); // The imported stray branch must not award ginseng.
        var doubles = 0;
        for (var i = 0; i < 700; i++) {
          s.inventory.clear();
          s.addItem(90009);
          s.date = GameDate(
            GameDate.addDays(DateTime(2023, 10, 18), i ~/ 14),
            i % 14,
          );
          final run = game.events.begin(p.events[23]!, s);
          while (!(run.current?.isEnd ?? true)) {
            run.advance();
          }
          final herbs = [
            for (final id in [80003, 80004, 80005, 80006, 80007])
              if (s.itemCount(id) > 0) id,
          ];
          expect(
            herbs,
            hasLength(1),
            reason: 'a gloves bonus must duplicate, not reroll',
          );
          final count = s.itemCount(herbs.single);
          expect(count, anyOf(1, 2));
          if (count == 2) doubles++;
          expect(s.itemCount(80040), 0);
        }
        expect(doubles / 700, inInclusiveRange(.15, .25));
      },
    );
  }
  test('ginseng and double herbs are exclusive, with ginseng winning simultaneous rolls', () {
    final game = Game.newRun(retry, random: Random(7));
    final s = game.state..locationId = 20001;
    s.grantTrait(200);
    var ginseng = 0, doubles = 0, bothRolls = 0;
    for (var i = 0; i < 700; i++) {
      s.inventory.clear();
      s.addItem(90009);
      s.date = GameDate(
        GameDate.addDays(DateTime(2023, 10, 18), i ~/ 14),
        i % 14,
      );
      final both =
          Random(s.date.asInt * 31 + 200 * 101).nextDouble() < .2 &&
          Random(s.date.asInt * 31 + 90009 * 101).nextDouble() < .2;
      final run = game.events.begin(retry.events[23]!, s);
      while (!(run.current?.isEnd ?? true)) {
        run.advance();
      }
      final herbs = [
        80003,
        80004,
        80005,
        80006,
        80007,
      ].fold<int>(0, (n, id) => n + s.itemCount(id));
      expect(herbs, anyOf(1, 2));
      if (s.itemCount(80040) > 0) {
        ginseng++;
        expect(herbs, 1);
      }
      if (herbs == 2) {
        doubles++;
        expect(s.itemCount(80040), 0);
      }
      if (both) {
        bothRolls++;
        expect(s.itemCount(80040), 1);
        expect(herbs, 1);
      }
    }
    expect(ginseng, greaterThan(0));
    expect(doubles, greaterThan(0));
    expect(bothRolls, greaterThan(0));
  });
  test('scavenging decision and exact duplicate survive a mid-scene save', () {
    final game = Game.newRun(retry);
    final s = game.state..locationId = 20001;
    s.addItem(90009);
    for (var i = 0; i < 100; i++) {
      s.date = GameDate(DateTime(2023, 10, 18), i);
      game.effects.applyChanger({
        'funcCode': 'SCAVENGE_ITEM',
        'args': [80003, 80004],
      }, s);
      if (s.switchValue('GATHER_DOUBLE') == 1) break;
    }
    expect(s.switchValue('GATHER_DOUBLE'), 1);
    final restored = Game(
      pack: retry,
      state: GameState.fromJson(retry, jsonDecode(jsonEncode(s.toJson()))),
    );
    final id = restored.state.switchValue('GATHER_ITEM');
    final before = restored.state.itemCount(id);
    restored.effects.applyChanger({
      'funcCode': 'DUPLICATE_SCAVENGED_ITEM',
    }, restored.state);
    expect(restored.state.itemCount(id), before + 1);
    restored.effects.applyChanger({
      'funcCode': 'DUPLICATE_SCAVENGED_ITEM',
    }, restored.state);
    expect(restored.state.itemCount(id), before + 1);
  });
  test('Practice Block stays enabled across use, new day and save until authored removal', () {
    final files = {...standard.sourceFiles};
    final rules = jsonDecode(files['rules.json']!) as Map<String, dynamic>;
    (rules['events'] as Map<String, dynamic>)['maxEventsPerDay'] = 0;
    files['rules.json'] = jsonEncode(rules);
    final p = ContentPack.fromFiles(files);
    final game = Game.newRun(p);
    final s = game.state..openingComplete = true;
    s.date = GameDate(DateTime(2023, 10, 18), 7);
    bool available(Game g) =>
        g.availableActions().any((a) => a.funcCode == 'IDOL_ACTION');
    expect(available(game), isFalse);
    game.effects.applyChanger(p.nodes[48012]!.changer, s);
    expect(s.switchValue('IDOL_BLOCK'), 1);
    expect(s.switchValue('IDOL'), 1);
    expect(available(game), isTrue);
    game.act(
      game.availableActions().firstWhere((a) => a.funcCode == 'IDOL_ACTION'),
    );
    expect(s.switchValue('IDOL_BLOCK'), 1);
    s.date = GameDate(s.date.day, 13);
    final out = game.act(
      LocationAction.fromJson({'locationActionType': 'sleep'}),
    );
    if (s.dayEndPending) {
      game.finishPendingDay();
    }
    expect(out.dayEnded, isTrue);
    expect(available(game), isTrue);
    final restored = Game(pack: p, state: GameState.fromJson(p, s.toJson()));
    expect(available(restored), isTrue);
    restored.effects.applyChanger(p.nodes[51001]!.changer, restored.state);
    expect(available(restored), isFalse);
  });
  test('shop rerolls cost one cookie, lose only one offer, persist, and reset Saturday', () {
    final game = Game.newRun(standard, random: Random(7));
    final account = Account(cookies: 10, walletGrants: {'cookies', 'refresh'});
    game.state.attachWallet(account);
    final count = game.shopOffers.length;
    expect(game.refreshShop(), isNull);
    expect(game.shopOffers.length, count - 1);
    expect(account.cookies, 9);
    expect(game.refreshShop(), isNull);
    expect(game.shopOffers.length, count - 1);
    expect(account.cookies, 8);
    final restored = Game(
      pack: standard,
      state: GameState.fromJson(standard, game.state.toJson())
        ..attachWallet(account),
    );
    expect(restored.state.shopOfferIds, game.state.shopOfferIds);
    expect(restored.refreshShop(), isNull);
    expect(restored.shopOffers.length, count - 1);
    expect(account.cookies, 7);
    final excluded = standard.shop.keys.firstWhere(
      (id) => !restored.state.shopOfferIds.contains(id),
    );
    expect(restored.purchase(excluded), isNotNull);
    restored.state.money = 100000;
    expect(restored.purchase(restored.state.shopOfferIds.first), isNull);
    expect(restored.refreshShop(), isNotNull);
    expect(account.cookies, 7);
    restored.state.date = GameDate(DateTime(2023, 10, 20), 14);
    expect(restored.shopOffers.length, count - 1);
    restored.state.date = GameDate(DateTime(2023, 10, 21), 0);
    expect(restored.shopOffers.length, count);
    expect(restored.state.shopRerolls, 0);
    expect(restored.refreshShop(), isNull);
    expect(account.cookies, 6);
  });
  testWidgets('shop refresh button updates offers and cookie count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = Game.newRun(standard)..state.cookies = 3;
    final count = game.shopOffers.length;
    await tester.pumpWidget(MaterialApp(home: CommerceScreen(game: game)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refresh-shop')));
    await tester.pumpAndSettle();
    expect(game.state.cookies, 2);
    expect(game.shopOffers.length, count - 1);
    expect(find.text('Cookies: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
