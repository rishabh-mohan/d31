import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/book_rewards.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/ui/book_completion.dart';
import 'package:d30mode/ui/game_screen.dart';
import 'package:d30mode/engine/content_source.dart';

import 'support/book_fixture.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('RENDER_REVIEW')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('book-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/book-reward-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'game screen resumes the saved reward before advancing the block',
    (tester) async {
      final game = Game.newRun(rewardPack());
      game.state.bookReadCounts[1] = 1;
      game.act(
        game.pack.locations[1]!.actions.first,
        book: game.pack.books[1],
        deferBookCompletion: true,
      );
      game.state.pendingBookRewards
        ..clear()
        ..add(
          PendingBookReward(
            bookId: 1,
            candidates: [
              const BookReward('stat', subject: 'logic', amount: 40),
            ],
            selectedIndex: 0,
            stage: 'roulette',
            revealed: true,
            unlockedBookId: 2,
          ),
        );
      final before = game.state.stats['logic']!;
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            game: game,
            packLocation: PackLocation('books', null),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Reading Complete'),
        ),
        findsOneWidget,
      );
      expect(game.state.date.tick, 0);
      expect(find.text('Nothing available here right now.'), findsNothing);
      expect(game.hand(), isNotEmpty);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.state.stats['logic'], before + 40);
      expect(find.text('Unlock Book'), findsOneWidget);
      expect(game.state.date.tick, 0);
      expect(game.hand(), isNotEmpty);
      expect(find.text('Nothing available here right now.'), findsNothing);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        game.state.date.tick,
        0,
        reason: 'wait for final popup exit transition',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.state.date.tick, 1);
      expect(game.bookCompletionPending, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'workbook precedes immediate reveal, trait receipt and next-book unlock',
    (tester) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (const bool.fromEnvironment('RENDER_REVIEW')) {
        await tester.runAsync(() async {
          final data = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
          await (FontLoader(
            'Roboto',
          )..addFont(Future.value(data.buffer.asByteData()))).load();
        });
      }
      final game = Game.newRun(rewardPack());
      game.state.bookReadCounts[1] = 1;
      game.act(
        game.pack.locations[1]!.actions.first,
        book: game.pack.books[1],
        deferBookCompletion: true,
      );
      final old = game.state.pendingBookRewards.removeAt(0);
      final pending = PendingBookReward(
        bookId: 1,
        candidates: [
          const BookReward('stat', subject: 'logic', amount: 40),
          const BookReward('trait', id: 200),
        ],
        selectedIndex: 1,
        beforeItems: old.beforeItems,
        unlockedBookId: old.unlockedBookId,
      );
      game.state.pendingBookRewards.add(pending);
      var checkpoints = 0;
      var finished = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('book-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      await showBookCompletions(
                        context,
                        game,
                        checkpoint: () async {
                          checkpoints++;
                        },
                        refresh: () {},
                      );
                      finished = true;
                    },
                    child: const Text('Complete book'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Complete book'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Got a Item 101!'), findsOneWidget);
      expect(find.text('Reading Complete'), findsNothing);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Reading Complete'), findsOneWidget);
      expect(pending.revealed, isFalse);
      await capture(tester, '01-rolling');
      await tester.tap(find.byKey(const ValueKey('book-reveal')));
      await tester.pump();
      expect(pending.revealed, isTrue);
      expect(find.text('Trait 200'), findsOneWidget);
      expect(pending.awarded, isFalse);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump(const Duration(milliseconds: 750));
      await capture(tester, '02-revealed');
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Obtained trait'), findsOneWidget);
      expect(game.state.traits, contains(200));
      await capture(tester, '03-trait-receipt');
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Unlock Book'), findsOneWidget);
      expect(find.text('Book D'), findsOneWidget);
      await capture(tester, '04-unlock');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(checkpoints, greaterThanOrEqualTo(5));
      expect(game.state.pendingBookRewards, isEmpty);
      game.finishBookCompletionAction();
      expect(game.state.date.tick, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopened revealed roll stays fixed with reduced motion', (
    tester,
  ) async {
    final game = Game.newRun(rewardPack());
    final pending = PendingBookReward(
      bookId: 1,
      candidates: [
        const BookReward('stat', subject: 'logic', amount: 40),
        const BookReward('trait', id: 200),
      ],
      selectedIndex: 1,
      revealed: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: BookCompletionDialog(
              game: game,
              pending: pending,
              onReveal: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Trait 200'), findsOneWidget);
    expect(find.text('Tap to obtain rewards!!'), findsNothing);
    expect(find.text('Confirm'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
