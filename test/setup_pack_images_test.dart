import 'dart:convert';
import 'dart:io';

import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/setup.dart';
import 'package:d30mode/ui/pack_image.dart';
import 'package:d30mode/ui/portrait.dart';
import 'package:d30mode/ui/setup_screen.dart';
import 'package:d30mode/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> files;
  setUpAll(() async {
    files = (await ContentSource.loadFromDirectory(
      Directory('examples/packs/workshop'),
    )).sourceFiles;
  });

  testWidgets(
    'choosing another pack resolves character-selection pictures from that pack',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tmp = Directory.systemTemp.createTempSync('setup_pack_images');
      final firstDir = Directory('${tmp.path}/first')..createSync();
      final customDir = Directory('${tmp.path}/custom')..createSync();
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      );
      for (final dir in [firstDir, customDir]) {
        final picture = File('${dir.path}/images/characters/hero.png');
        picture.parent.createSync(recursive: true);
        picture.writeAsBytesSync(png);
      }
      ContentPack makePack(String id, String name) {
        final manifest = jsonDecode(files['pack.json']!) as Map;
        final characters = jsonDecode(files['characters.json']!) as Map;
        (characters['characters'] as List).first['portrait'] =
            'characters/hero.png';
        return ContentPack.fromFiles({
          ...files,
          'pack.json': jsonEncode({...manifest, 'id': id, 'name': name}),
          'characters.json': jsonEncode(characters),
        });
      }

      final first = makePack('first', 'First pack');
      final custom = makePack('custom', 'Custom photo pack');
      PackImages.use(PackLocation('first', firstDir));
      // Warm the cache using an identical relative name in the old pack.
      expect(
        (PackImages.resolve('characters/hero.png') as FileImage).file.path,
        contains('/first/'),
      );
      addTearDown(() {
        PackImages.use(PackLocation('none', null));
        PackThemes.use(const PackColorScheme());
        try {
          tmp.deleteSync(recursive: true);
        } on FileSystemException {
          /* in-flight decoder */
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPackTheme(const PackColorScheme()),
          home: SetupScreen(
            pack: first,
            draft: RunSetup(first),
            campaigns: [first, custom],
            campaignLocations: {
              'first': PackLocation('first', firstDir),
              'custom': PackLocation('custom', customDir),
            },
          ),
        ),
      );
      await tester.tap(find.text('Custom photo pack'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(PackImages.packDirectory!.path, customDir.path);
      expect(
        (PackImages.resolve('characters/hero.png') as FileImage).file.path,
        '${customDir.path}/images/characters/hero.png',
      );
      final portrait = tester.widget<Portrait>(find.byType(Portrait));
      expect(portrait.pack.manifest.id, 'custom');
      expect(portrait.fallback, 'characters/hero.png');
      expect(tester.takeException(), isNull);
    },
  );
}
