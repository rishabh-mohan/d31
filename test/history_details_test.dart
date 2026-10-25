import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/admissions.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/account_catalog.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/record_store.dart';
import 'package:d30mode/ui/record_details.dart';
import 'package:d30mode/ui/home_pages.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    if (const bool.fromEnvironment('RENDER_REVIEW')) {
      final font = FontLoader('ReviewFont')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
            ),
          ),
        );
      await font.load();
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
      await icons.load();
    }
  });

  RunRecord fixture() {
    final game = Game.newRun(pack);
    final state = game.state;
    state.firstName = 'Greg';
    state.lastName = 'Fiasco';
    state.characterId = pack.characters.keys.first;
    state.money = 3400;
    state.studyExp = 113400;
    state.exerciseExp = 900;
    state.grantTrait(69);
    state.grantTrait(41);
    for (final s in pack.manifest.subjects) {
      state.stats[s] = 12000;
    }
    state.csat = CsatResult(
      standardScore: 59.6,
      subjectScores: {for (final s in pack.manifest.subjects) s: 59.6},
      grades: {for (final s in pack.manifest.subjects) s: 3},
    );
    final departments = pack.admissions.departments.keys.take(2).toList();
    state.applications.addAll(departments);
    state.admittedDepartments.add(departments.first);
    state.enrolledDepartment = departments.first;
    for (final type in ['pencil', 'eraser', 'note', 'markingPen']) {
      final item = pack.stationery.entries.firstWhere(
        (e) => e.value['type'] == type,
      );
      state.equippedStationery[type] = item.key;
    }
    return RunRecord.of(1, state, ending: 'True Ending');
  }

  test(
    'finished record freezes details and survives JSON without a live pack',
    () {
      final game = Game.newRun(pack);
      game.state.money = 321;
      game.state.grantTrait(69);
      final record = RunRecord.of(1, game.state, ending: 'Done');
      game.state.money = 999;
      game.state.removeTrait(69);
      final restored = RunRecord.fromJson(
        1,
        jsonDecode(jsonEncode(record.toJson())),
      );
      expect(restored.details!['money'], 321);
      expect((restored.details!['traits'] as List).single['id'], 69);
      expect(restored.details!['applications'], isEmpty);
    },
  );

  test('first university enrollment pays configured reward once across account reloads', () {
    final catalog = AccountCatalog.fromJson({
      'rewards': {'firstUniversityEnrollmentCookies': 2},
    });
    final record = fixture();
    final account = Account();
    account.recordRun(record, catalog);
    expect(account.cookies, 2);
    final restored = Account.fromJson(jsonDecode(jsonEncode(account.toJson())));
    restored.recordRun(record, catalog);
    expect(restored.cookies, 2);
    expect(restored.enrollments[record.enrolledUniversityId], 2);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('History tabs retain one snapshot and fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width * 2340 / 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final record = fixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: const bool.fromEnvironment('RENDER_REVIEW')
                ? 'ReviewFont'
                : null,
          ),
          home: RepaintBoundary(
            key: const ValueKey('history-render'),
            child: MenuPage(
              title: 'History',
              body: (context, u) => Center(
                child: TextButton(
                  onPressed: () => RecordDetails.show(context, record),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record-info')), findsOneWidget);
      expect(find.text('3400 Gold'), findsOneWidget);
      expect(find.textContaining('113400'), findsOneWidget);
      for (final tab in [0, 2, 1]) {
        await tester.tap(find.byKey(ValueKey('record-tab-$tab')));
        await tester.pumpAndSettle();
        if (tab == 0) {
          expect(
            find.byKey(const ValueKey('record-certificate')),
            findsOneWidget,
          );
          expect(find.text('Accepted'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Rejected'),
            160,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('record-applications')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Rejected'), findsOneWidget);
          await tester.drag(
            find.byKey(const ValueKey('record-applications')),
            const Offset(0, 700),
          );
          await tester.pumpAndSettle();
        }
        if (tab == 2) {
          expect(find.text('Graduation Exam Score Card'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        if (width == 390 && const bool.fromEnvironment('RENDER_REVIEW')) {
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 200)),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../build/history-review/tab-$tab.png'),
          );
        }
      }
      await tester.tap(find.byKey(const ValueKey('record-close')));
      await tester.pumpAndSettle();
      expect(find.byType(RecordDetails), findsNothing);
    });
  }

  testWidgets(
    'legacy History stays readable without fabricating missing scores',
    (tester) async {
      final old = RunRecord.fromJson(1, {
        'name': 'Old run',
        'stats': {'math': 100},
        'csatStandardScore': 52.0,
        'enrolled': 'Known school — Major',
      });
      await tester.pumpWidget(MaterialApp(home: RecordDetails(record: old)));
      expect(
        find.textContaining('older record did not retain traits'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('record-tab-2')));
      await tester.pump();
      expect(
        find.textContaining('did not retain subject scores'),
        findsOneWidget,
      );
      expect(find.text('Graduation Exam Score Card'), findsNothing);
    },
  );
}
