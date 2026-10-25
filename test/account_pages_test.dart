/// Home's account pages render at the reference phone size without
/// overflow, and their main controls work.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_catalog.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/pack.dart';
import 'package:d30mode/ui/achievements_page.dart';
import 'package:d30mode/ui/daily_quest.dart';
import 'package:d30mode/ui/puzzles_page.dart';
import 'package:d30mode/ui/traits_page.dart';

void main() {
  late ContentPack pack;
  late ContentPack retry;

  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
    retry = await ContentSource.loadFromDirectory(Directory('packs/kss20'));
    AccountStore.catalog = AccountCatalog.parse(
      File('assets/account/catalog.json').readAsStringSync(),
    );
  });

  setUp(() => AccountStore.current = Account(cookies: 500));

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

  testWidgets('Achievements: tabs, filter, regions and endings', (
    tester,
  ) async {
    AccountStore.current.endings.add(200004);
    AccountStore.current.enrollments[2] = 1;
    await pumpPhone(tester, AchievementsPage(campaigns: [pack, retry]));
    // A full page with the Home menus' back chevron, not a sheet (TODO 94).
    expect(find.byKey(const ValueKey('menu-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-close')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('menu-back'))).dy,
      lessThan(60),
    );
    expect(find.text('Korea'), findsOneWidget);
    expect(find.textContaining('# Enrollments 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('region-taiwan')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('ach-filter')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('ach-filter-complete')));
    await settle(tester);
    expect(find.textContaining('# Enrollments'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ach-tab-Campaign')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('ach-filter')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('ach-filter-all')));
    await settle(tester);
    expect(find.text('The Year I Retook'), findsOneWidget);
    expect(find.text('1/13'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('campaign-20')));
    await settle(tester);
    expect(find.text('Endings List'), findsOneWidget);
    expect(find.text('True Ending'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('panel-close')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('ach-tab-Other')));
    await settle(tester);
    expect(find.text('Story Addict'), findsOneWidget);
    expect(find.text('Reach Campaign Ending 1/5'), findsOneWidget);
  });

  testWidgets('Achievements filter: the arrow cell spans the pill height', (
    tester,
  ) async {
    await pumpPhone(tester, AchievementsPage(campaigns: [pack, retry]));
    final pill = tester.getRect(find.byKey(const ValueKey('ach-filter')));
    final cell = tester.getRect(
      find
          .ancestor(
            of: find.byIcon(Icons.arrow_drop_down),
            matching: find.byType(Container),
          )
          .first,
    );
    // Inside the 2-unit border on both sides, not just the icon's height.
    expect(cell.height, greaterThan(pill.height * 0.85));
    expect(cell.top - pill.top, lessThan(pill.height * 0.08));
    expect(pill.bottom - cell.bottom, lessThan(pill.height * 0.08));
  });

  testWidgets('Daily Quests names a department and stays incomplete', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      DailyQuestPanel(catalog: pack.admissions, now: DateTime(2026, 10, 24)),
    );
    expect(find.text('Enroll in the following major'), findsOneWidget);
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.textContaining('10/25/2026'), findsOneWidget);
  });

  testWidgets('Puzzles: categories, collection and detail', (tester) async {
    await pumpPhone(tester, const PuzzlesPage(installedStories: {16, 20}));
    expect(find.byKey(const ValueKey('puzzle-category-3')), findsOneWidget);
    // Every banner's art is bundled and decodes: the category name only
    // appears as text when its title image fails to load (TODO 93).
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
    }
    for (final name in [
      'Amnesia',
      'Endless Winter',
      'The Year I Retook',
      'Event Limited',
    ]) {
      expect(find.text(name), findsNothing, reason: '$name banner art');
    }
    await tester.tap(find.byKey(const ValueKey('puzzle-category-3')));
    await settle(tester);
    expect(find.text('Ihyeon’s Break (F)'), findsOneWidget);
    await tester.tap(find.text('Ihyeon’s Break (F)'));
    await tester.tap(find.byKey(const ValueKey('puzzle-wallpaper1')).first);
    await settle(tester);
    expect(find.text('(0/4)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('complete-now')));
    await settle(tester);
    expect(find.text('(4/4)'), findsOneWidget);
    expect(AccountStore.current.cookies, 500 - 99);
  });

  testWidgets('Manage Traits: buy, open, results, collection and combine', (
    tester,
  ) async {
    await pumpPhone(tester, ManageTraitsSheet(pack: pack));
    expect(find.text('Standard Trait Pack'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pack-buy')));
    await settle(tester);
    expect(find.text('Owned : 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pack-open')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('reveal-stage')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('reveal-stage')));
    await settle(tester);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reveal-arrow-1')));
    await settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reveal-exit')));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(AccountStore.current.traits, hasLength(3));

    await tester.tap(find.byKey(const ValueKey('traits-My Traits')));
    await settle(tester);
    expect(find.text('My Traits'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('panel-confirm')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('traits-Traits Database')));
    await settle(tester);
    expect(find.text('Traits Database'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('panel-confirm')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('traits-Combine')));
    await settle(tester);
    expect(find.text('Combine Traits'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('combine-lock')));
    await settle(tester);
    expect(find.byKey(const ValueKey('slot-remove-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('combine-lock')));
    await settle(tester);
    for (final copy in List.of(AccountStore.current.traits)) {
      await tester.tap(find.byKey(ValueKey('combine-card-${copy.uid}')));
      await tester.pump();
    }
    final hasS = AccountStore.current.traits.any(
      (t) => pack.traits[t.traitId]!.rank == 'S',
    );
    await tester.tap(find.byKey(const ValueKey('combine-go')));
    await settle(tester);
    if (!hasS) {
      expect(find.byKey(const ValueKey('combine-confirm')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey('combine-confirm')));
      await settle(tester);
      expect(AccountStore.current.traits, hasLength(1));
    }
    await tester.pump(const Duration(seconds: 3));
  });
}
