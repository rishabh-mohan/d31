/// Puzzles (MM-10..13): category banners, each campaign's collection, and
/// the detail panel with its pieces and Complete Now.
///
/// Pieces come from the account: an ending piece once that ending is
/// reached, a story piece when the campaign is installed, a game-count
/// piece per finished run (provisional), and every piece once bought.
/// Progress and price are weighted by each piece's cookies, as the
/// original's 2/4-yet-52% shows. A finished puzzle becomes the Home
/// background from its green tag or the detail panel (TODO 102). Only the
/// Amnesia desk ships full-screen art; the others fill the screen from
/// their square thumbnails. The Insta-draw tile is not built.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/account_catalog.dart';
import '../engine/account_store.dart';
import 'account_widgets.dart';
import 'home_pages.dart';
import 'home_screen.dart';
import 'pack_image.dart';

/// Event Limited is the app's own category; every other tile is a pack.
const _eventIcon = 'kss/images/event_banner_background_img.png';

class PuzzlesPage extends StatefulWidget {
  const PuzzlesPage({super.key});

  @override
  State<PuzzlesPage> createState() => _PuzzlesPageState();
}

class _PuzzlesPageState extends State<PuzzlesPage> {
  Future<void> _open(String title, List<Puzzle> puzzles) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleCollectionPage(title: title, puzzles: puzzles),
      ),
    );
    // The page is drawn over the background just chosen.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AccountStore.catalog;
    final tiles = [
      for (final s in catalog.shelves)
        (key: s.packId, name: s.name, icon: s.icon, puzzles: s.puzzles),
      (
        key: 'event',
        name: 'Event Limited',
        icon: _eventIcon,
        // Only puzzles with full-screen art; the rest wait until their art
        // is captured (TODO 102, user decision 2026-10-25).
        puzzles: [
          for (final p in catalog.puzzles)
            if (p.fullImage != null) p,
        ],
      ),
    ];
    return MenuPage(
      title: 'Puzzles',
      body: (context, u) => ListView(
        padding: EdgeInsets.fromLTRB(12 * u, 18 * u, 12 * u, 24 * u),
        children: [
          Text(
            'Collect pieces to finish puzzles\n'
            'Use finished puzzles as background images\n'
            'Each installed campaign brings its own puzzles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5 * u,
              height: 1.45,
              color: HomeColors.ink,
            ),
          ),
          SizedBox(height: 22 * u),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 22 * u,
            runSpacing: 22 * u,
            children: [
              for (final t in tiles)
                _Tile(
                  key: ValueKey('puzzle-category-${t.key}'),
                  u: u,
                  name: t.name,
                  icon: t.icon,
                  onTap: () => _open(t.name, t.puzzles),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pack's icon over its name: tap to open its puzzles.
class _Tile extends StatelessWidget {
  final double u;
  final String name;
  final String? icon;
  final VoidCallback onTap;

  const _Tile({
    super.key,
    required this.u,
    required this.name,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22 * u);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150 * u,
        child: Column(
          children: [
            Container(
              height: 150 * u,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: const Color(0xFFFFF4DE),
                  width: 3 * u,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x334A2B10),
                    blurRadius: 5 * u,
                    offset: Offset(0, 3 * u),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: PackImage(
                  path: icon,
                  placeholder: ColoredBox(color: HomeColors.cardFill),
                ),
              ),
            ),
            SizedBox(height: 8 * u),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15 * u, color: HomeColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class PuzzleCollectionPage extends StatefulWidget {
  final String title;
  final List<Puzzle> puzzles;

  const PuzzleCollectionPage({
    super.key,
    required this.title,
    required this.puzzles,
  });

  @override
  State<PuzzleCollectionPage> createState() => _PuzzleCollectionPageState();
}

class _PuzzleCollectionPageState extends State<PuzzleCollectionPage> {
  @override
  Widget build(BuildContext context) {
    final account = AccountStore.current;
    final puzzles = widget.puzzles;
    return MenuPage(
      title: widget.title,
      body: (context, u) {
        if (puzzles.isEmpty) {
          return Center(
            child: Text(
              'No puzzles here.',
              style: TextStyle(fontSize: 15 * u, color: HomeColors.muted),
            ),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(32 * u, 22 * u, 32 * u, 30 * u),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 22 * u,
            mainAxisSpacing: 14 * u,
            childAspectRatio: 150 / 216,
          ),
          itemCount: puzzles.length,
          itemBuilder: (context, i) {
            final puzzle = puzzles[i];
            final held = account.piecesOf(puzzle);
            final complete = held.every((h) => h);
            final price = account.completeNowPrice(puzzle);
            final progress = account.puzzleProgress(puzzle);
            Future<void> open() async {
              await pushOverlay<void>(context, PuzzleDetail(puzzle: puzzle));
              if (mounted) setState(() {});
            }

            return Column(
              key: ValueKey('puzzle-${puzzle.id}'),
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    onTap: open,
                    child: _PuzzleArt(
                      u: u,
                      puzzle: puzzle,
                      held: held,
                      magnifier: true,
                    ),
                  ),
                ),
                SizedBox(height: 8 * u),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    puzzle.name,
                    style: TextStyle(fontSize: 14.5 * u, color: HomeColors.ink),
                  ),
                ),
                SizedBox(height: 6 * u),
                if (complete)
                  _OwnedTag(
                    key: ValueKey('puzzle-use-${puzzle.id}'),
                    u: u,
                    equipped: account.background == puzzle.id,
                    onTap: () {
                      account.useAsBackground(puzzle);
                      unawaited(AccountStore.save());
                      setState(() {});
                    },
                  )
                else if (price != null)
                  _BuyTag(
                    u: u,
                    price: price,
                    discount: (progress * 100).round(),
                    onTap: open,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The artwork with missing pieces darkened and white seams between them.
class _PuzzleArt extends StatelessWidget {
  final double u;
  final Puzzle puzzle;
  final List<bool> held;
  final bool magnifier;

  const _PuzzleArt({
    required this.u,
    required this.puzzle,
    required this.held,
    this.magnifier = false,
  });

  @override
  Widget build(BuildContext context) {
    final side = held.length <= 4 ? 2 : 4;
    final radius = BorderRadius.circular(14 * u);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: magnifier ? HomeColors.orange : const Color(0xFF7A5634),
          width: 3 * u,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11 * u),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PackImage(path: puzzle.thumbnail),
            if (held.any((h) => !h))
              LayoutBuilder(
                builder: (context, box) {
                  final cell = box.maxWidth / side;
                  return Stack(
                    children: [
                      for (var i = 0; i < held.length && i < side * side; i++)
                        if (!held[i])
                          Positioned(
                            left: (i % side) * cell,
                            top: (i ~/ side) * cell,
                            width: cell,
                            height: cell,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0x99000000),
                                border: Border.all(
                                  color: const Color(0xCCFFFFFF),
                                  width: .8,
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            if (magnifier)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 38 * u,
                  height: 38 * u,
                  decoration: BoxDecoration(
                    color: HomeColors.orange,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10 * u),
                    ),
                  ),
                  child: Icon(Icons.search, color: Colors.white, size: 26 * u),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A finished puzzle's tag: a check when it is the background, a double
/// check otherwise. Tapping it makes it the background.
class _OwnedTag extends StatelessWidget {
  final double u;
  final bool equipped;
  final VoidCallback onTap;
  const _OwnedTag({
    super.key,
    required this.u,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: equipped ? 'Current background' : 'Use as background',
    child: GestureDetector(
      onTap: equipped ? null : onTap,
      child: Container(
        width: 64 * u,
        height: 21 * u,
        decoration: BoxDecoration(
          color: const Color(0xFF4CB848),
          borderRadius: BorderRadius.circular(4 * u),
        ),
        child: Icon(
          equipped ? Icons.check : Icons.done_all,
          color: Colors.white,
          size: 18 * u,
        ),
      ),
    ),
  );
}

class _BuyTag extends StatelessWidget {
  final double u;
  final int price;
  final int discount;
  final VoidCallback onTap;

  const _BuyTag({
    required this.u,
    required this.price,
    required this.discount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 24 * u,
      decoration: BoxDecoration(
        color: HomeColors.orange,
        borderRadius: BorderRadius.circular(5 * u),
      ),
      padding: EdgeInsets.all(2 * u),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * u),
            child: Text(
              'Buy',
              style: TextStyle(fontSize: 13 * u, color: Colors.white),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4 * u),
            decoration: BoxDecoration(
              color: HomeColors.paper,
              borderRadius: BorderRadius.circular(4 * u),
            ),
            child: Row(
              children: [
                CookieAmount(u: u, amount: price, size: 12),
                if (discount > 0) ...[
                  SizedBox(width: 4 * u),
                  _Discount(u: u, percent: discount, size: 11),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Discount extends StatelessWidget {
  final double u;
  final int percent;
  final double size;
  const _Discount({required this.u, required this.percent, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 5 * u),
    decoration: BoxDecoration(
      color: const Color(0xFFE85A5A),
      borderRadius: BorderRadius.circular(4 * u),
    ),
    child: Text(
      '$percent%↓',
      style: TextStyle(fontSize: size * u, color: Colors.white),
    ),
  );
}

/// MM-12/13: the picture, each piece's condition, and Complete Now.
class PuzzleDetail extends StatefulWidget {
  final Puzzle puzzle;
  const PuzzleDetail({super.key, required this.puzzle});

  @override
  State<PuzzleDetail> createState() => _PuzzleDetailState();
}

class _PuzzleDetailState extends State<PuzzleDetail> {
  String _condition(PuzzlePiece p) {
    final catalog = AccountStore.catalog;
    return switch (p.type) {
      'ending' => 'Watch ${catalog.endings[p.endingCode]?.name ?? 'an ending'}',
      'gameCount' =>
        'Finish runs of ${widget.puzzle.packName ?? 'this campaign'}',
      'purchaseStory' => 'Own ${widget.puzzle.packName ?? 'the expansion'}',
      'friendInvite' => 'Invite a friend',
      'eventPackage' => 'Event package',
      _ => 'Owned',
    };
  }

  Future<void> _completeNow() async {
    final account = AccountStore.current;
    if (!account.completeNow(widget.puzzle)) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Not enough cookies.')));
      return;
    }
    unawaited(AccountStore.save());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountStore.current;
    final puzzle = widget.puzzle;
    final held = account.piecesOf(puzzle);
    final count = held.where((h) => h).length;
    final progress = account.puzzleProgress(puzzle);
    final price = account.completeNowPrice(puzzle);
    final percent = (progress * 100).round();
    return LayoutBuilder(
      builder: (context, box) {
        final u = box.maxWidth / 390;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            30 * u,
            MediaQuery.paddingOf(context).top + 30 * u,
            30 * u,
            24 * u,
          ),
          child: ChildPanel(
            u: u,
            cornerClose: true,
            child: Column(
              children: [
                SizedBox(height: 18 * u),
                SizedBox.square(
                  dimension: 230 * u,
                  child: _PuzzleArt(u: u, puzzle: puzzle, held: held),
                ),
                SizedBox(height: 14 * u),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * u),
                  child: Text(
                    puzzle.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20 * u,
                      fontWeight: FontWeight.bold,
                      color: HomeColors.ink,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * u),
                  child: Text(
                    puzzle.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * u,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8A6A4A),
                    ),
                  ),
                ),
                Text(
                  '($count/${held.length})',
                  style: TextStyle(fontSize: 13 * u, color: HomeColors.muted),
                ),
                SizedBox(height: 8 * u),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 26 * u),
                    decoration: BoxDecoration(
                      color: HomeColors.cardFill,
                      borderRadius: BorderRadius.circular(10 * u),
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * u,
                        vertical: 6 * u,
                      ),
                      itemCount: held.length,
                      separatorBuilder: (_, _) => Divider(
                        color: const Color(0xFF4A2B10),
                        height: 1,
                        thickness: 1 * u,
                      ),
                      itemBuilder: (context, i) => _PieceRow(
                        u: u,
                        name: '<${puzzle.name}> Piece ${i + 1}',
                        held: held[i],
                        condition: _condition(puzzle.pieces[i]),
                      ),
                    ),
                  ),
                ),
                if (count == held.length) ...[
                  SizedBox(height: 10 * u),
                  _BackgroundButton(
                    u: u,
                    current: account.background == puzzle.id,
                    onTap: () {
                      account.useAsBackground(puzzle);
                      unawaited(AccountStore.save());
                      setState(() {});
                    },
                  ),
                ],
                SizedBox(height: 8 * u),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22 * u),
                  child: Text(
                    'Obtain Pieces by meeting conditions and complete Puzzles.\n'
                    'Use the Complete Now function to immediately complete a Puzzle.\n'
                    '(Cookie costs diminish when more Pieces are collected.)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5 * u,
                      height: 1.4,
                      color: HomeColors.muted,
                    ),
                  ),
                ),
                SizedBox(height: 8 * u),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30 * u),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10 * u),
                    border: Border.all(color: HomeColors.orange, width: 2 * u),
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: HomeColors.orange,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(8 * u),
                        ),
                        child: InkWell(
                          key: const ValueKey('complete-now'),
                          onTap: price != null && price > 0
                              ? _completeNow
                              : null,
                          child: Padding(
                            padding: EdgeInsets.all(3 * u),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      price == 0 ? 'Completed' : 'Complete Now',
                                      style: TextStyle(
                                        fontSize: 16 * u,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8 * u,
                                    vertical: 4 * u,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HomeColors.paper,
                                    borderRadius: BorderRadius.circular(6 * u),
                                  ),
                                  child: Row(
                                    children: [
                                      if (price == null)
                                        Text(
                                          'Event only',
                                          style: TextStyle(
                                            fontSize: 12 * u,
                                            color: HomeColors.muted,
                                          ),
                                        )
                                      else
                                        CookieAmount(
                                          u: u,
                                          amount: price,
                                          size: 15,
                                        ),
                                      if (percent > 0 && percent < 100) ...[
                                        SizedBox(width: 6 * u),
                                        _Discount(
                                          u: u,
                                          percent: percent,
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * u,
                          vertical: 7 * u,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 9 * u,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5 * u),
                                  border: Border.all(
                                    color: const Color(0xFF4A2B10),
                                    width: 1 * u,
                                  ),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A2B10),
                                      borderRadius: BorderRadius.circular(
                                        5 * u,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4 * u),
                            Text(
                              '($percent% Completed)',
                              style: TextStyle(
                                fontSize: 10 * u,
                                color: HomeColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16 * u),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A finished puzzle's Use as Background control. The original's equip
/// interaction is not captured (E19), so this is the project's own.
class _BackgroundButton extends StatelessWidget {
  final double u;
  final bool current;
  final VoidCallback onTap;

  const _BackgroundButton({
    required this.u,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 30 * u),
    child: Material(
      color: current ? const Color(0xFF4CB848) : HomeColors.orange,
      borderRadius: BorderRadius.circular(10 * u),
      child: InkWell(
        key: const ValueKey('use-as-background'),
        borderRadius: BorderRadius.circular(10 * u),
        onTap: current ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 7 * u),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                current ? Icons.check : Icons.wallpaper,
                color: Colors.white,
                size: 18 * u,
              ),
              SizedBox(width: 6 * u),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    current ? 'Current Background' : 'Use as Background',
                    style: TextStyle(fontSize: 16 * u, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PieceRow extends StatelessWidget {
  final double u;
  final String name;
  final bool held;
  final String condition;

  const _PieceRow({
    required this.u,
    required this.name,
    required this.held,
    required this.condition,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4CA846);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * u),
      child: Row(
        children: [
          Icon(
            Icons.extension,
            size: 32 * u,
            color: held ? HomeColors.orange : HomeColors.muted,
          ),
          SizedBox(width: 10 * u),
          Expanded(
            child: held
                ? Row(
                    children: [
                      DoneCheck(size: 15 * u),
                      SizedBox(width: 6 * u),
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(fontSize: 13 * u, color: green),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 10.5 * u,
                          color: HomeColors.ink,
                        ),
                      ),
                      SizedBox(height: 3 * u),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3 * u,
                              vertical: 1 * u,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA08A72),
                              borderRadius: BorderRadius.circular(4 * u),
                            ),
                            child: Text(
                              'Obtainment\nCondition',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8 * u,
                                height: 1.05,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 5 * u),
                          Expanded(
                            child: Text(
                              condition,
                              style: TextStyle(
                                fontSize: 12 * u,
                                color: HomeColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
