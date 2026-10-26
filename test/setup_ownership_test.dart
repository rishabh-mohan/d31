/// Setup offers only account-owned badges and traits (user request,
/// 2026-10-25): badges unlocked by a first enrollment, trait copies from
/// packs/combining. account-rules.json `setupRequiresOwnership` gates it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_catalog.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/engine/record_store.dart';
import 'package:d30mode/engine/setup.dart';
import 'package:d30mode/engine/state.dart';
import 'package:d30mode/ui/setup_screen.dart';
import 'package:d30mode/ui/setup_widgets.dart';

void main() {
  late ContentPack pack;
  late List<UniversityBadge> badges;
  late List<GameTrait> eligible;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    badges = pack.badges.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    eligible = pack.traits.values
        .where((t) => RunSetup.eligible(t, pack))
        .toList();
  });

  tearDown(() => SetupOwnership.debugRequireOwnership = null);

  /// An account that enrolled at [schools] and holds [copies] trait copies.
  Account account({
    Iterable<int> schools = const [],
    Iterable<int> copies = const [],
  }) {
    final a = Account(enrollments: {for (final s in schools) s: 1});
    for (final id in copies) {
      a.traits.add(OwnedTrait(a.nextTraitUid++, id));
    }
    return a;
  }

  group('engine', () {
    test('account rule parses and defaults on', () {
      expect(AccountCatalog.empty.setupRequiresOwnership, isTrue);
      expect(AccountCatalog.fromJson({}).setupRequiresOwnership, isTrue);
      expect(
        AccountCatalog.fromJson({
          'rewards': {'setupRequiresOwnership': false},
        }).setupRequiresOwnership,
        isFalse,
      );
    });

    test('gating on: only enrolled schools and held traits, with counts', () {
      final a = account(
        schools: [badges[0].universityId],
        copies: [eligible[0].id, eligible[0].id, eligible[1].id],
      )..enrollments[badges[1].universityId] = 0;
      final owned = SetupOwnership.fromAccount(a, AccountCatalog.empty);
      expect(owned.restricted, isTrue);
      final draft = RunSetup(pack)..useOwnership(owned, pack);
      expect(draft.badgeChoices(pack).map((b) => b.universityId), [
        badges[0].universityId,
      ]);
      expect(draft.traitChoices(pack).map((t) => t.id).toSet(), {
        eligible[0].id,
        eligible[1].id,
      });
      expect(owned.traitCount(eligible[0].id), 2);
      expect(owned.traitCount(eligible[2].id), 0);
    });

    test('gating off by rule or debug override offers everything', () {
      final a = account();
      final off = SetupOwnership.fromAccount(
        a,
        const AccountCatalog(setupRequiresOwnership: false),
      );
      expect(off.restricted, isFalse);
      final draft = RunSetup(pack)..useOwnership(off, pack);
      expect(draft.badgeChoices(pack), hasLength(pack.badges.length));
      expect(draft.traitChoices(pack), hasLength(eligible.length));

      SetupOwnership.debugRequireOwnership = false;
      expect(
        SetupOwnership.fromAccount(a, AccountCatalog.empty).restricted,
        isFalse,
      );
      SetupOwnership.debugRequireOwnership = true;
      expect(
        SetupOwnership.fromAccount(
          a,
          const AccountCatalog(setupRequiresOwnership: false),
        ).restricted,
        isTrue,
      );
    });

    test('a first enrollment unlocks that school for the next setup', () {
      final a = account();
      final school = badges[3].universityId;
      expect(
        SetupOwnership.fromAccount(a, AccountCatalog.empty).ownsBadge(school),
        isFalse,
      );
      a.recordRun(
        RunRecord(
          id: 1,
          name: 'Greg',
          portrait: '',
          packId: 'kss16',
          modeTitle: '31-Day Mode',
          ending: 'x',
          finishedAt: DateTime(2026, 10, 25),
          stats: const {},
          enrolledUniversityId: school,
        ),
        AccountCatalog.empty,
      );
      expect(
        SetupOwnership.fromAccount(a, AccountCatalog.empty).ownsBadge(school),
        isTrue,
      );
    });

    test('commit grants only owned picks and consumes nothing', () {
      final a = account(
        schools: [badges[0].universityId],
        copies: [eligible[0].id],
      );
      final draft = RunSetup(pack)
        ..useOwnership(
          SetupOwnership.fromAccount(a, AccountCatalog.empty),
          pack,
        );
      draft.badges.add(badges[1].universityId);
      expect(() => draft.commit(pack), throwsStateError);
      draft.badges
        ..clear()
        ..add(badges[0].universityId);
      draft.traits.add(eligible[1].id);
      expect(() => draft.commit(pack), throwsStateError);
      draft.traits
        ..clear()
        ..add(eligible[0].id);
      final state = draft.commit(pack).state;
      expect(state.badgeIds, [badges[0].universityId]);
      expect(state.initialTraitIds, [eligible[0].id]);
      expect(state.traits, contains(eligible[0].id));
      // No consumption: the copy is still held and can be picked again.
      expect(a.traits.map((t) => t.traitId), [eligible[0].id]);
      expect(draft.commit(pack).state.initialTraitIds, [eligible[0].id]);
    });

    test('limits still apply when more is owned', () {
      final a = account(
        schools: badges.take(8).map((b) => b.universityId),
        copies: eligible.take(6).map((t) => t.id),
      );
      final draft = RunSetup(pack)
        ..useOwnership(
          SetupOwnership.fromAccount(a, AccountCatalog.empty),
          pack,
        );
      draft.badges.addAll(badges.take(8).map((b) => b.universityId));
      expect(() => draft.commit(pack), throwsStateError);
      draft.badges.remove(badges.first.universityId);
      draft.traits.addAll(eligible.take(6).map((t) => t.id));
      expect(() => draft.commit(pack), throwsStateError);
      draft.traits.remove(eligible.first.id);
      expect(draft.commit(pack).state.badgeIds, hasLength(7));
    });

    test('a kept draft drops picks the account no longer owns', () {
      final draft = RunSetup(pack)
        ..badges.addAll([badges[0].universityId, badges[1].universityId])
        ..traits.addAll([eligible[0].id, eligible[1].id]);
      final a = account(
        schools: [badges[1].universityId],
        copies: [eligible[1].id],
      );
      draft.useOwnership(
        SetupOwnership.fromAccount(a, AccountCatalog.empty),
        pack,
      );
      expect(draft.badges, {badges[1].universityId});
      expect(draft.traits, {eligible[1].id});
      expect(draft.commit(pack), isNotNull);
    });

    test('old runs with now-unowned picks still load unchanged', () {
      final old =
          (RunSetup(pack)
                ..badges.add(badges[0].universityId)
                ..traits.add(eligible[0].id))
              .commit(pack)
              .state;
      // The account owns nothing, but loading never consults ownership.
      final restored = GameState.fromJson(pack, old.toJson());
      expect(restored.badgeIds, [badges[0].universityId]);
      expect(restored.initialTraitIds, [eligible[0].id]);
      expect(restored.stats, old.stats);
    });
  });

  group('widgets at 393x873', () {
    /// Scrolls the lazily built trait grid until [card] exists and shows.
    Future<void> reveal(WidgetTester tester, Finder card) async {
      final grid = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(grid).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(card, 120, scrollable: grid);
      await tester.pumpAndSettle();
    }

    Future<void> openStep(WidgetTester tester, RunSetup draft, int step) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(pack: pack, draft: draft),
        ),
      );
      await tester.tap(find.text('Standard Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      if (step == 3) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    }

    testWidgets('badge step lists only owned badges', (tester) async {
      final owned = [badges[0], badges[2]];
      final draft = RunSetup(pack)
        ..useOwnership(
          SetupOwnership.fromAccount(
            account(schools: owned.map((b) => b.universityId)),
            AccountCatalog.empty,
          ),
          pack,
        );
      await openStep(tester, draft, 2);
      for (final b in owned) {
        expect(find.byKey(ValueKey('badge-${b.universityId}')), findsOneWidget);
      }
      expect(
        find.byKey(ValueKey('badge-${badges[1].universityId}')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('setup-badges-empty')), findsNothing);
      await tester.tap(find.byKey(ValueKey('badge-${badges[2].universityId}')));
      await tester.pumpAndSettle();
      expect(draft.badges, {badges[2].universityId});
      expect(tester.takeException(), isNull);
    });

    testWidgets('badge and trait steps pass when nothing is owned', (
      tester,
    ) async {
      final draft = RunSetup(pack)
        ..useOwnership(
          SetupOwnership.fromAccount(account(), AccountCatalog.empty),
          pack,
        );
      await openStep(tester, draft, 2);
      expect(find.byKey(const ValueKey('setup-badges-empty')), findsOneWidget);
      expect(find.text('No university badges yet'), findsOneWidget);
      expect(
        find.byType(InkWell).evaluate().where((e) {
          final key = e.widget.key;
          return key is ValueKey && '${key.value}'.startsWith('badge-');
        }),
        isEmpty,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-traits-empty')), findsOneWidget);
      expect(find.text('No traits yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Start Game'), findsOneWidget);
      final game = draft.commit(pack);
      expect(game.state.badgeIds, isEmpty);
      expect(game.state.initialTraitIds, isEmpty);
    });

    testWidgets('trait step shows owned traits with counts and the limit', (
      tester,
    ) async {
      final owned = eligible.take(6).toList();
      final draft = RunSetup(pack)
        ..useOwnership(
          SetupOwnership.fromAccount(
            account(copies: [...owned.map((t) => t.id), owned[0].id]),
            AccountCatalog.empty,
          ),
          pack,
        );
      await openStep(tester, draft, 3);
      expect(find.byKey(const ValueKey('setup-traits-empty')), findsNothing);
      expect(
        find.byKey(ValueKey('setup-trait-${eligible[6].id}')),
        findsNothing,
      );
      final doubled = find.byKey(ValueKey('setup-trait-${owned[0].id}'));
      await reveal(tester, doubled);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: doubled, matching: find.text('×2')),
        findsOneWidget,
      );
      for (final t in owned) {
        final card = find.byKey(ValueKey('setup-trait-${t.id}'));
        await reveal(tester, card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
      }
      expect(draft.traits, hasLength(5));
      expect(draft.traits, isNot(contains(owned.last.id)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('gating off keeps the full catalog', (tester) async {
      final draft = RunSetup(pack)
        ..useOwnership(
          SetupOwnership.fromAccount(
            account(),
            const AccountCatalog(setupRequiresOwnership: false),
          ),
          pack,
        );
      await openStep(tester, draft, 2);
      expect(
        find.byKey(ValueKey('badge-${badges.first.universityId}')),
        findsOneWidget,
      );
      expect(find.byType(SetupEmptyNote), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(SetupEmptyNote), findsNothing);
      expect(find.text('×1'), findsWidgets);
    });
  });
}
