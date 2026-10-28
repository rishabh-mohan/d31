import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/setup.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/setup_screen.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  test(
    'setup grants initial effects once and round trips identity and selections',
    () {
      final draft = RunSetup(pack)
        ..firstName = '민수'
        ..lastName = 'Kim';
      final t = pack.traits.values.firstWhere(
        (t) =>
            RunSetup.eligible(t, pack) &&
            t.effects.any((e) => e['type'] == 'firstPlusStat'),
      );
      draft.traits.add(t.id);
      final baseline = GameState.newRun(pack);
      final state = draft.commit(pack).state;
      expect(state.totalStat, greaterThan(baseline.totalStat));
      expect(state.initialTraitIds, [t.id]);
      expect(state.date, baseline.date);
      expect(state.hp, state.hpMax);
      final restored = GameState.fromJson(pack, state.toJson());
      expect(restored.stats, state.stats);
      expect(restored.initialTraitIds, state.initialTraitIds);
      expect(restored.fullName, '민수 Kim');
      expect(restored.characterId, state.characterId);
    },
  );

  test(
    'rejects event-only traits, excess badges and unsupported difficulty',
    () {
      final draft = RunSetup(pack);
      draft.traits.add(
        pack.traits.values.firstWhere((t) => !t.setupEligible).id,
      );
      expect(() => draft.commit(pack), throwsStateError);
      draft.traits.clear();
      draft.badges.addAll(pack.badges.keys.take(8));
      expect(() => draft.commit(pack), throwsStateError);
      draft.badges.clear();
      draft.difficulty = 'elite';
      expect(() => draft.commit(pack), throwsStateError);
    },
  );

  test('badge study bonus persists without reapplying starting stats', () {
    final badge = pack.badges.values.firstWhere(
      (b) => b.effects.length == 1 && b.effects.single['type'] == 'plusStat',
    );
    final draft = RunSetup(pack)..badges.add(badge.universityId);
    final game = draft.commit(pack);
    final effect = badge.effects.single;
    expect(
      game.traits.studyBonus(
        game.state,
        subject: effect['subjectType'] as String?,
      ),
      game.traits.statValue(effect),
    );
    expect(GameState.fromJson(pack, game.state.toJson()).badgeIds, [
      badge.universityId,
    ]);
  });

  testWidgets('five steps fit a narrow phone and back preserves name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = RunSetup(pack);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(pack: pack, draft: draft),
      ),
    );
    // The difficulty step has no footer button: its two mode cards are the
    // forward choice, as the reference shows.
    for (var i = 0; i < 4; i++) {
      await tester.tap(
        find.text(switch (i) {
          0 => 'Standard Mode',
          1 => 'Select',
          _ => 'Next',
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(find.byType(TextField).first, 'Unicode 민수');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(draft.firstName, 'Unicode 민수');
    expect(find.text('Unicode 민수'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
