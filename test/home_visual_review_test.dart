import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/account_catalog.dart';
import 'package:d30mode/ui/account_menus.dart';
import 'package:d30mode/ui/home_screen.dart';
import 'package:d30mode/ui/puzzles_page.dart';

void main() {
  if (!const bool.fromEnvironment("RENDER_REVIEW")) return;
  setUpAll(() async {
    final font = FontLoader('ReviewFont')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
          ),
        ),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'C:/Users/stewc/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    await icons.load();
    AccountStore.catalog = AccountCatalog.parse(
      File('assets/account/catalog.json').readAsStringSync(),
    );
  });
  testWidgets('Home reference review', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1080 / 390;
    addTearDown(tester.view.reset);
    final pack = await tester.runAsync(
      () => ContentSource.loadFromDirectory(Directory('packs/kss16')),
    );
    final screens = <String, Widget>{
      'home': const HomeScreen(),
      'settings': SettingsSheet(campaigns: const [], onReload: () async {}),
      'profile': ProfileSheet(pack: pack),
      'charging': const ChargingSheet(),
      'mail': const MailBoxSheet(),
      'store': StoreSheet(pack: pack),
      'puzzles': const PuzzlesPage(installedStories: {16, 20}),
    };
    for (final entry in screens.entries) {
      AccountStore.current = Account(cookies: 53, refreshTokens: 522);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'ReviewFont'),
          home: RepaintBoundary(
            key: const ValueKey('review'),
            child: entry.value,
          ),
        ),
      );
      for (var i = 0; i < (entry.key == "home" ? 20 : 5); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull, reason: entry.key);
      await expectLater(
        find.byKey(const ValueKey('review')),
        matchesGoldenFile('../build/home-review/${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
