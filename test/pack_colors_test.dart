import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/theme.dart';

void main() {
  test(
    'manifest palette defaults, overrides and invalid hex are validated',
    () {
      final manifest = <String, dynamic>{
        'calendar': {
          'startDate': 'DATE_2023101600',
          'endDate': 'DATE_2023111600',
        },
      };
      expect(
        PackManifest.fromJson(manifest).colorScheme.color('accent'),
        0xFFFF8B55,
      );
      final scheme = PackColorScheme.fromJson({
        'preset': 'ocean',
        'colors': {'accent': '#123abc', 'ink': '#223344'},
      });
      expect(scheme.color('accent'), 0xFF123ABC);
      expect(scheme.color('iconBackground'), 0xFF123ABC);
      expect(scheme.color('ink'), 0xFF223344);
      expect(PackColorScheme.hex(scheme.color('accent')), '#123ABC');
      for (final bad in [
        42,
        {'preset': 'missing'},
        {'colors': []},
        {
          'colors': {'accent': '#123'},
        },
        {
          'colors': {'ink': 123},
        },
      ]) {
        expect(
          () => PackManifest.fromJson({...manifest, 'colorScheme': bad}),
          throwsA(isA<PackFormatException>()),
        );
      }
      for (final preset in PackColorScheme.presetNames.keys) {
        final palette = PackColorScheme.fromJson({'preset': preset});
        for (final role in PackColorScheme.roles.keys) {
          expect(
            PackColorScheme.isHex(PackColorScheme.hex(palette.color(role))),
            isTrue,
          );
        }
      }
    },
  );

  testWidgets(
    'changing the active pack recolors mounted panels without losing input',
    (tester) async {
      addTearDown(() => PackThemes.use(const PackColorScheme()));
      PackThemes.use(const PackColorScheme(preset: 'ocean'));
      final input = TextEditingController(text: 'Keep this draft');
      addTearDown(input.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: PackThemes.current,
          builder: (context, scheme, child) => MaterialApp(
            theme: buildPackTheme(scheme),
            home: Scaffold(
              body: D30Panel(
                child: Column(
                  children: [
                    TextField(controller: input),
                    D30RaisedButton(
                      onPressed: () {},
                      child: const Text('Study'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      Color panelColor() =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byType(D30Panel),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
      expect(
        panelColor(),
        Color(const PackColorScheme(preset: 'ocean').color('panel')),
      );
      PackThemes.use(const PackColorScheme(preset: 'forest'));
      await tester.pumpAndSettle();
      expect(
        panelColor(),
        Color(const PackColorScheme(preset: 'forest').color('panel')),
      );
      expect(find.text('Keep this draft'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style!.backgroundColor!.resolve({}),
        Color(const PackColorScheme(preset: 'forest').color('accent')),
      );
    },
  );
}
