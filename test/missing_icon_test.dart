import 'dart:io';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/missing_icon.dart';
import 'package:d30mode/ui/pack_image.dart';
import 'package:d30mode/ui/portrait.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _frame(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 120, height: 200, child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentPack pack;
  setUp(() async {
    pack = await ContentSource.loadFromDirectory(
      Directory('examples/packs/workshop'),
    );
  });

  testWidgets('a character with no portrait shows a question mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(Portrait(pack: pack, id: 70, character: true, fallback: '')),
    );
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('a portrait file that cannot be read shows a question mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        Portrait(
          pack: pack,
          id: 70,
          character: true,
          fallback: 'characters/does_not_exist.png',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('MissingIcon fills a PackImage placeholder slot', (tester) async {
    await tester.pumpWidget(
      _frame(const PackImage(path: null, placeholder: MissingIcon())),
    );
    expect(find.text('?'), findsOneWidget);
  });
}
