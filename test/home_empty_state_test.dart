/// NO-PACK-121: with no packs Home shows friendly guidance naming the pack
/// roots, a broken pack shows its whole error, and Charging/Store stay clear.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/ui/account_menus.dart';
import 'package:d30mode/ui/home_screen.dart';

void main() {
  late Directory empty, broken, good;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await rootBundle.loadString('assets/account/catalog.json');
    final tmp = Directory.systemTemp.createTempSync('d30_home_');
    empty = Directory('${tmp.path}/empty')..createSync();
    broken = Directory('${tmp.path}/broken')..createSync();
    Directory('${broken.path}/badpack').createSync();
    File('${broken.path}/badpack/pack.json').writeAsStringSync('{"nope":');
    good = Directory('${tmp.path}/good')..createSync();
    final src = Directory('packs/kss16');
    final dst = Directory('${good.path}/kss16')..createSync();
    for (final f in src.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(src.path.length);
      File('${dst.path}$rel')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(f.readAsBytesSync());
    }
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {
        /* Windows may still hold a handle; the OS temp dir is cleaned later. */
      }
    });
  });
  setUp(() => AccountStore.fileOverride = File('${empty.path}/account.json'));
  tearDown(() => ContentSource.rootsOverride = null);

  final loading = find.byType(CircularProgressIndicator);

  Future<void> pump(WidgetTester tester, Directory root, Size size) async {
    ContentSource.rootsOverride = [root];
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    for (var i = 0; i < 600 && loading.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets('no packs: guidance names the roots; Charging/Store clear '
        '@${size.width.toInt()}', (tester) async {
      await pump(tester, empty, size);
      expect(find.text('No packs installed yet'), findsOneWidget);
      expect(find.text(empty.absolute.path), findsOneWidget);
      final card = tester.getRect(
        find.byKey(const ValueKey('home-load-error')),
      );
      for (final (k, sheet) in [
        ('home-charging', find.byType(ChargingSheet)),
        ('home-store', find.byType(StoreSheet)),
      ]) {
        final r = tester.getRect(find.byKey(ValueKey(k)));
        expect(card.overlaps(r), isFalse, reason: k);
        expect(r.bottom, lessThanOrEqualTo(size.height), reason: k);
        await tester.tap(find.byKey(ValueKey(k)), warnIfMissed: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(sheet, findsOneWidget, reason: k);
        Navigator.of(tester.element(sheet)).pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('malformed pack: the full FormatException text is shown', (
    tester,
  ) async {
    await pump(tester, broken, const Size(360, 640));
    expect(find.text('A pack could not be read'), findsOneWidget);
    final shown = tester.widget<Text>(find.textContaining('FormatException'));
    expect(shown.maxLines, isNull);
    expect(shown.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text('No packs installed yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a normal pack loads with no card', (tester) async {
    await pump(tester, good, const Size(390, 844));
    expect(loading, findsNothing);
    expect(find.byKey(const ValueKey('home-load-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
