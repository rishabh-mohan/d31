/// TODO 84 M01: Home's captured account destinations render at the
/// reference phone size, and their working controls work.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/account_menus.dart';
import 'package:d30mode/ui/home_screen.dart';

void main() {
  late ContentPack pack;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  setUp(() => AccountStore.current = Account(cookies: 53, refreshTokens: 7));

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1080 / 390;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Home has the mail, profile, Charging and Store entries', (
    tester,
  ) async {
    await pumpPhone(tester, const HomeScreen());
    for (final key in [
      'home-mail',
      'home-charging',
      'home-store',
      'home-settings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Notices'), findsNothing);
    expect(find.text('Rank'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-mail')));
    await settle(tester);
    expect(find.text('Mail Box is empty.'), findsOneWidget);
  });

  testWidgets('Settings: toggles persist on the account; paid music and '
      'Chinese give the notice; universities still switch', (tester) async {
    await pumpPhone(
      tester,
      SettingsSheet(campaigns: const [], onReload: () async {}),
    );
    expect(find.text('Type of Music'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-bgm')));
    await tester.pump();
    expect(AccountStore.current.bgm, isFalse);

    await tester.tap(find.byKey(const ValueKey('settings-music-orchestral')));
    await tester.pump();
    expect(AccountStore.current.music, MusicType.regular);
    expect(find.text(unavailableText), findsOneWidget);

    final advanced = find.text('Game settings');
    await tester.scrollUntilVisible(advanced, 200);
    await tester.tap(advanced);
    await settle(tester);
    final us = find.byKey(const ValueKey('settings-universities-us'));
    await tester.scrollUntilVisible(us, 200);
    await tester.tap(us);
    await tester.pump();
    expect(AccountStore.current.universities, UniversitySet.us);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mail Box switches between its two empty lists', (tester) async {
    await pumpPhone(tester, const MailBoxSheet());
    expect(find.text('Mail Box is empty.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mail-tab-1')));
    await tester.pump();
    expect(find.text('Shows up to 10 pieces of claimed mail.'), findsOneWidget);
  });

  testWidgets('Profile first rename is free; Cancel keeps the name', (
    tester,
  ) async {
    await pumpPhone(tester, const ProfileSheet());
    expect(find.text('53'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text(Account.defaultUsername), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-rename')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('rename-field')), 'G');
    await tester.tap(find.byKey(const ValueKey('rename-change')));
    await tester.pump();
    expect(find.text('Use 2-16 characters.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rename-cancel')));
    await settle(tester);
    expect(AccountStore.current.username, Account.defaultUsername);

    await tester.tap(find.byKey(const ValueKey('profile-rename')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('rename-field')), 'Greg');
    await tester.tap(find.byKey(const ValueKey('rename-change')));
    await settle(tester);
    expect(AccountStore.current.username, 'Greg');
    expect(AccountStore.current.cookies, 53);
    expect(find.text('Greg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invite-copy')));
    await tester.pump();
    expect(find.text(unavailableText), findsOneWidget);
  });

  testWidgets('Charging shows the seven packages and charges nothing', (
    tester,
  ) async {
    await pumpPhone(tester, const ChargingSheet());
    expect(find.text('Cookies Owned : 53'), findsOneWidget);
    for (final o in CookieOffer.all) {
      expect(find.text(o.price), findsOneWidget, reason: o.price);
    }
    await tester.tap(find.byKey(const ValueKey('offer-17')));
    await tester.pump();
    expect(find.text(unavailableText), findsOneWidget);
    expect(AccountStore.current.cookies, 53);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Store: four tabs; trait packs open Manage Traits', (
    tester,
  ) async {
    await pumpPhone(tester, StoreSheet(pack: pack));
    expect(find.byKey(const ValueKey('store-premium')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store-restore')));
    await tester.pump();
    expect(find.text(unavailableText), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('store-tab-1')));
    await settle(tester);
    expect(find.text('Focus Pack'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store-tab-2')));
    await settle(tester);
    expect(find.text('Endless Winter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('store-tab-3')));
    await settle(tester);
    expect(find.text('Cookie Charging Station'), findsOneWidget);
    final packs = find.byKey(const ValueKey('store-trait-packs'));
    await tester.scrollUntilVisible(packs, 300);
    await tester.tap(packs);
    await settle(tester);
    expect(find.text('Manage Traits'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
