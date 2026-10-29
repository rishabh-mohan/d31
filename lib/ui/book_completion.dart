import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/book_rewards.dart';
import '../engine/game.dart';
import '../engine/pack.dart';
import 'pack_image.dart';
import 'pack_menus.dart';
import 'theme.dart';

/// Resumable presentation: workbook -> roulette -> acquisition -> unlock.
Future<void> showBookCompletions(
  BuildContext context,
  Game game, {
  required Future<void> Function() checkpoint,
  required VoidCallback refresh,
}) async {
  while (context.mounted && game.state.pendingBookRewards.isNotEmpty) {
    final pending = game.state.pendingBookRewards.first;
    await checkpoint();
    if (!context.mounted) return;
    while (pending.stage == 'before' && pending.beforeItems.isNotEmpty) {
      final id = pending.beforeItems.first;
      final item = game.pack.items[id];
      if (item != null) {
        await showItemAcquired(
          context,
          item,
          onUse: () {
            game.useItem(id);
            refresh();
            return game.takeItemOutcome();
          },
        );
      }
      pending.beforeItems.removeAt(0);
      await checkpoint();
      if (!context.mounted) return;
    }
    if (pending.stage == 'before') pending.stage = 'roulette';
    if (pending.stage == 'roulette') {
      await _showRewardDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => BookCompletionDialog(
          game: game,
          pending: pending,
          onReveal: checkpoint,
        ),
      );
      if (!context.mounted) return;
      game.awardBookReward(pending);
      refresh();
      await checkpoint();
      if (!context.mounted) return;
    }
    if (pending.stage == 'receipt') {
      final reward = pending.selected;
      if (reward.type == 'item') {
        await showItemAcquired(
          context,
          game.pack.items[reward.id]!,
          onUse: () {
            game.useItem(reward.id!);
            refresh();
            return game.takeItemOutcome();
          },
        );
      } else if (reward.type == 'trait') {
        final trait = game.pack.traits[reward.id]!;
        var description = trait.description;
        for (final effect in trait.effects) {
          if (effect['type'] == 'plusStat') {
            description = description.replaceAll(
              RegExp(r'STAT_\d+'),
              '${game.traits.statValue(effect, description: trait.description)}',
            );
            break;
          }
        }
        await _confirmPanel(
          context,
          pending.traitGranted ? 'Obtained trait' : 'Trait unavailable',
          [
            _candidate(game, reward),
            const SizedBox(height: 18),
            Text(
              pending.traitGranted
                  ? description
                  : 'This trait could not be obtained.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        );
      }
      if (!context.mounted) return;
      pending.stage = 'unlock';
      await checkpoint();
    }
    if (!context.mounted) return;
    final next = game.pack.books[pending.unlockedBookId];
    if (next != null) {
      await _confirmPanel(context, 'Unlock Book', [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          next.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21),
        ),
        const SizedBox(height: 16),
        _bookTags(next),
        const SizedBox(height: 16),
        const Divider(),
      ]);
    }
    if (!context.mounted) return;
    game.state.pendingBookRewards.removeAt(0);
    await checkpoint();
    refresh();
  }
}

Future<void> _confirmPanel(
  BuildContext context,
  String title,
  List<Widget> body,
) => _showRewardDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => PopScope(
    canPop: false,
    child: _Frame(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25),
        ),
        const SizedBox(height: 22),
        ...body,
        const SizedBox(height: 24),
        SizedBox(
          width: 144,
          child: D30RaisedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Confirm', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    ),
  ),
);

/// A popped modal's exit transition must finish before advancing the block.
Future<void> _showRewardDialog({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) async {
  final route = DialogRoute<void>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
  );
  await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
}

class BookCompletionDialog extends StatefulWidget {
  final Game game;
  final PendingBookReward pending;
  final Future<void> Function() onReveal;
  const BookCompletionDialog({
    super.key,
    required this.game,
    required this.pending,
    required this.onReveal,
  });
  @override
  State<BookCompletionDialog> createState() => _BookCompletionDialogState();
}

class _BookCompletionDialogState extends State<BookCompletionDialog> {
  Timer? _timer, _readyTimer;
  int _index = 0;
  bool _ready = false;
  bool _reduced = false;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (widget.pending.revealed) {
      _index = widget.pending.selectedIndex;
      _ready = true;
    } else if (!_reduced) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) {
          setState(
            () => _index = (_index + 1) % widget.pending.candidates.length,
          );
        }
      });
    }
  }

  Future<void> _reveal() async {
    if (widget.pending.revealed) return;
    _timer?.cancel();
    setState(() {
      widget.pending.revealed = true;
      _index = widget.pending.selectedIndex;
    });
    await widget.onReveal();
    if (!mounted) return;
    _readyTimer = Timer(Duration(milliseconds: _reduced ? 0 : 300), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _readyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.game.pack.books[widget.pending.bookId]!;
    return PopScope(
      canPop: false,
      child: _Frame(
        children: [
          const Text('Reading Complete', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: context.packColors.ink),
          const SizedBox(height: 16),
          Text(
            book.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          _bookTags(book),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: context.packColors.ink),
          const SizedBox(height: 12),
          const Text('Reward', style: TextStyle(fontSize: 21)),
          Semantics(
            button: !widget.pending.revealed,
            label: 'Reveal book reward',
            child: GestureDetector(
              key: const ValueKey('book-reveal'),
              behavior: HitTestBehavior.opaque,
              onTap: _reveal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 114,
                    width: double.infinity,
                    child: Center(
                      child: _candidate(
                        widget.game,
                        widget.pending.candidates[_index],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: Center(
                      child: !widget.pending.revealed
                          ? Text(
                              'Tap to obtain rewards!!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.packColors.inkSoft,
                                fontSize: 16,
                              ),
                            )
                          : AnimatedOpacity(
                              opacity: _ready ? 1 : 0,
                              duration: Duration(
                                milliseconds: _reduced ? 0 : 700,
                              ),
                              child: IgnorePointer(
                                ignoring: !_ready,
                                child: SizedBox(
                                  width: 144,
                                  child: D30RaisedButton(
                                    depth: 3,
                                    onPressed: _ready
                                        ? () => Navigator.pop(context)
                                        : null,
                                    child: const Text(
                                      'Confirm',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _bookTags(GameBook book) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    D30Chip(
      text: subjectLabel(book.subject),
      color: D30Colors.subject(book.subject),
      fontSize: 15,
      weight: FontWeight.w400,
    ),
    const SizedBox(width: 8),
    CircleAvatar(
      radius: 12,
      backgroundColor: switch (book.tier) {
        'D' => const Color(0xFF927D78),
        _ => const Color(0xFFBFBFBF),
      },
      child: Text(
        book.tier,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    ),
  ],
);

Widget _candidate(Game game, BookReward reward) => switch (reward.type) {
  'item' => Tooltip(
    message: game.pack.items[reward.id]!.name,
    child: SizedBox(
      width: 64,
      height: 64,
      child: PackImage(
        path: itemArtPath(game.pack.items[reward.id]!),
        fit: BoxFit.contain,
        placeholder: Text(
          game.pack.items[reward.id]!.name,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  ),
  'trait' => D30Chip(
    text: game.pack.traits[reward.id]!.name,
    color: traitColor(game.pack.traits[reward.id]!.type),
    textColor: Colors.white,
    fontSize: 16,
    weight: FontWeight.w400,
  ),
  _ => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: BoxDecoration(
      color: D30Colors.subject(reward.subject!),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      '${subjectLabel(reward.subject!)} + ${reward.amount}',
      style: const TextStyle(fontSize: 17),
    ),
  ),
};

class _Frame extends StatelessWidget {
  final List<Widget> children;
  const _Frame({required this.children});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.packColors.panel,
    insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: context.packColors.accent, width: 4),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    ),
  );
}
