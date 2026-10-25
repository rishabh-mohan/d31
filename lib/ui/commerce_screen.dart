import 'press_feedback.dart';

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'pack_image.dart';
import 'theme.dart';
import 'transitions.dart';
import 'stationery_card.dart';
import 'pack_menus.dart';

enum PackMenu { books, items, shop, stationery }

/// Store and owned stationery share the reference's cream/orange chrome.
class CommerceScreen extends StatefulWidget {
  final Game game;
  final bool stationery;
  final PackMenu initialMenu;
  const CommerceScreen({
    super.key,
    required this.game,
    this.stationery = false,
    this.initialMenu = PackMenu.shop,
  });

  static Route<void> route(Game game, {PackMenu menu = PackMenu.shop}) =>
      flyUpRoute<void>((_) => CommerceScreen(game: game, initialMenu: menu));
  @override
  State<CommerceScreen> createState() => _CommerceScreenState();
}

class _CommerceScreenState extends State<CommerceScreen> {
  Game get game => widget.game;
  late PackMenu selectedMenu = widget.stationery
      ? PackMenu.stationery
      : widget.initialMenu;
  bool get stationery => selectedMenu == PackMenu.stationery;
  String filter = 'all';
  final List<int> materials = [];
  bool combining = false;
  bool priceAscending = true;
  List<Map<String, dynamic>> get offers => game.pack.shop.values.toList()
    ..sort(
      (a, b) => priceAscending
          ? (a['price'] as num).compareTo(b['price'] as num)
          : (b['price'] as num).compareTo(a['price'] as num),
    );
  ButtonStyle get orangeButton => FilledButton.styleFrom(
    backgroundColor: D30Colors.accent,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  void message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );

  Widget card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEDB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: D30Colors.accent, width: 2),
    ),
    child: child,
  );

  Future<void> buy(int id) async {
    final error = game.purchase(id);
    setState(() {});
    if (error != null) {
      message(error);
      return;
    }
    final offer = game.pack.shop[id]!;
    final item = game.pack.items[(offer['itemId'] as num).toInt()]!;
    // The reference's acquisition popup, shared with event rewards.
    await showItemAcquired(
      context,
      item,
      onUse: () {
        game.useItem(item.id);
        setState(() {});
        return game.takeItemReports();
      },
    );
  }

  Widget equipment(int id, {bool owned = true}) => StationeryCard(
    key: ValueKey('stationery-$id'),
    id: id,
    item: game.pack.stationery[id]!,
    equipped: game.state.equippedStationery.values.contains(id),
    selected: materials.contains(id),
    count: owned ? game.state.stationeryInventory[id] : null,
    onTap: !owned
        ? null
        : () => setState(() {
            if (!combining) {
              game.equipStationery(id);
            } else if (materials.length < 4 &&
                materials.where((m) => m == id).length <
                    game.availableStationeryCopies(id)) {
              materials.add(id);
            } else {
              message(
                'No unused copies available. Remove a selected card with its × button.',
              );
            }
          }),
  );

  Future<void> combine() async {
    final result = game.combineStationery(materials);
    if (result == null) {
      message('Select two, three, or four available stationery copies.');
      return;
    }
    setState(() => materials.clear());
    // The reveal is its own dark, glowing stage — no commerce chrome, no red
    // Close, just the card and a wide Confirm well below it.
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Stationery result',
      barrierColor: Colors.black.withValues(alpha: .88),
      pageBuilder: (context, _, _) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                radius: .7,
                colors: [Color(0x55FFFFFF), Color(0x00000000)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 180,
                    height: 265,
                    child: StationeryCard(
                      id: result,
                      item: game.pack.stationery[result]!,
                    ),
                  ),
                  const SizedBox(height: 56),
                  SizedBox(
                    width: 260,
                    height: 52,
                    child: PressFeedback(
                      child: FilledButton(
                        style: orangeButton,
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontSize: 19),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget store() => Column(
    children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'New items arrive every Saturday.',
          style: TextStyle(color: D30Colors.alert),
        ),
      ),
      const Divider(indent: 25, endIndent: 25),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        // Wallet in an outlined cream pill, sort in a filled orange one.
        child: Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: D30Colors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: D30Colors.accent, width: 2),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Owned : ${game.state.money.round()} Gold',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PressFeedback(
              child: Material(
                color: D30Colors.accent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => priceAscending = !priceAscending),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_list,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Sort by price',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                        Icon(
                          priceAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 15,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            for (final offer in offers)
              Builder(
                builder: (_) {
                  final id = (offer['id'] as num).toInt();
                  final item =
                      game.pack.items[(offer['itemId'] as num).toInt()];
                  if (item == null) return const SizedBox.shrink();
                  final stock = game.shopStock(id);
                  final capped = game.shopItemAtCap(id);
                  return card(
                    Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 65,
                              height: 65,
                              child: PackImage(
                                path: 'items/${item.id}.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  // The reference prints the bag category
                                  // under the title, not as a separate pill.
                                  Text(
                                    item.isConsumable
                                        ? 'Consumables'
                                        : 'Others',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: D30Colors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Text(item.effectText, textAlign: TextAlign.center),
                        const Divider(),
                        Text(item.description, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        PressFeedback(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: D30Colors.alert,
                              side: const BorderSide(
                                color: D30Colors.alert,
                                width: 2,
                              ),
                            ),
                            key: ValueKey('buy-$id'),
                            onPressed: stock > 0 && !capped
                                ? () => buy(id)
                                : null,
                            child: Text(
                              capped
                                  ? 'Owned (max)'
                                  : stock == 0
                                  ? 'Sold out'
                                  : '${offer['price']} Gold ($stock/${offer['stock']})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ],
  );

  Widget stationeryMenu() => LayoutBuilder(
    builder: (_, constraints) => FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight < 520 ? 520 : constraints.maxHeight,
        child: _stationeryMenu(),
      ),
    ),
  );

  Widget _stationeryMenu() {
    final owned =
        game.state.stationeryInventory.entries
            .where(
              (e) => e.value > 0 && game.pack.stationery.containsKey(e.key),
            )
            .map((e) => e.key)
            .where(
              (id) =>
                  filter == 'all' ||
                  game.pack.stationery[id]!['type'] == filter,
            )
            .toList()
          ..sort((a, b) {
            final rank = Game.stationeryRanks
                .indexOf(game.pack.stationery[a]!['rank'] as String)
                .compareTo(
                  Game.stationeryRanks.indexOf(
                    game.pack.stationery[b]!['rank'] as String,
                  ),
                );
            return rank != 0 ? rank : a.compareTo(b);
          });
    final sets = game.state.activeStationerySets;
    return Column(
      children: [
        if (combining) ...[
          SizedBox(
            height: 160,
            child: Row(
              children: [
                for (var slot = 0; slot < 4; slot++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Expanded(
                            child: slot < materials.length
                                ? equipment(materials[slot], owned: false)
                                : Container(
                                    key: ValueKey('combine-slot-$slot'),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9D9D9),
                                      border: Border.all(
                                        color: Colors.black87,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 28,
                            child: PressFeedback(
                              child: FilledButton(
                                key: ValueKey('remove-material-$slot'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: D30Colors.alert,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  if (slot < materials.length) {
                                    setState(() => materials.removeAt(slot));
                                  }
                                },
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: PressFeedback(
                child: FilledButton(
                  style: orangeButton,
                  onPressed: combine,
                  child: const Text('Combine', style: TextStyle(fontSize: 23)),
                ),
              ),
            ),
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Equipped · tap an owned card to equip'),
          ),
          SizedBox(
            height: 130,
            child: Row(
              children: [
                for (final type in ['pencil', 'eraser', 'note', 'markingPen'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: game.state.equippedStationery[type] == null
                          ? Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9D9D9),
                                border: Border.all(
                                  color: Colors.black87,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    stationeryTypeLabel(type),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                Positioned.fill(
                                  child: equipment(
                                    game.state.equippedStationery[type]!,
                                    owned: false,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: PressFeedback(
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => game.state.equippedStationery
                                            .remove(type),
                                      ),
                                      child: const Icon(
                                        Icons.cancel,
                                        color: D30Colors.alert,
                                        size: 22,
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
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEDB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: sets.isEmpty
                ? const Text(
                    'Equip stationery with matching names for Set Effects!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 70),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final set in sets)
                            Text(
                              '${set['name']} · ${_setBonusText(set)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
        const Divider(indent: 16, endIndent: 16, height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final type in [
                'all',
                'pencil',
                'eraser',
                'note',
                'markingPen',
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    // The active category is marked by the small filled
                    // toggle inside the pill, not by tinting the whole pill.
                    child: PressFeedback(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: D30Colors.ink,
                          side: const BorderSide(
                            color: D30Colors.accent,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                        onPressed: () => setState(() => filter = type),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                type == 'all'
                                    ? 'All'
                                    : stationeryTypeLabel(type),
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: filter == type
                                      ? D30Colors.accent
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: D30Colors.accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: owned.isEmpty
              ? const Center(child: Text('No stationery obtained yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: owned.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: 140,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (_, index) => equipment(owned[index]),
                ),
        ),
        const Divider(indent: 16, endIndent: 16),
        if (combining)
          PressFeedback(
            child: OutlinedButton(
              onPressed: () => setState(() {
                combining = false;
                materials.clear();
              }),
              child: const Text('Back to Stationery'),
            ),
          )
        else ...[
          const Text(
            'New stationery arrives every Thursday.',
            style: TextStyle(fontSize: 12),
          ),
          PressFeedback(
            child: FilledButton(
              style: orangeButton,
              onPressed: () => setState(() => combining = true),
              child: const Text('Combine'),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  String _setBonusText(
    Map<String, dynamic> set,
  ) => (set['studyStats'] as List? ?? const [])
      .whereType<Map>()
      .map(
        (row) =>
            '${row['isAll'] == true ? 'All subjects' : subjectLabel(row['subjectType'] as String? ?? '')} +${row['stat']}',
      )
      .join(', ');
  void closeMenu() {
    if (combining) {
      setState(() {
        combining = false;
        materials.clear();
      });
    } else {
      Navigator.pop(context);
    }
  }

  Widget get menuBody => switch (selectedMenu) {
    PackMenu.books => BooksMenu(game: game),
    PackMenu.items => BagsMenu(game: game),
    PackMenu.shop => store(),
    PackMenu.stationery => stationeryMenu(),
  };

  @override
  Widget build(BuildContext context) {
    final title = combining
        ? 'Combine Stationery'
        : switch (selectedMenu) {
            PackMenu.books => 'Books',
            PackMenu.items => 'Bags',
            PackMenu.shop => 'Store',
            PackMenu.stationery => 'Stationery',
          };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 38, 6, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                decoration: BoxDecoration(
                  color: D30Colors.panel,
                  border: Border.all(color: D30Colors.accent, width: 3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 70,
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                color: D30Colors.ink,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: PressFeedback(
                              child: IconButton.filled(
                                tooltip: 'Close',
                                onPressed: closeMenu,
                                style: IconButton.styleFrom(
                                  backgroundColor: D30Colors.accent,
                                  foregroundColor: D30Colors.panel,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: D30Colors.ink),
                        child: menuBody,
                      ),
                    ),
                    if (!combining) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: PressFeedback(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: D30Colors.alert,
                                foregroundColor: D30Colors.panel,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: closeMenu,
                              child: const Text(
                                'Close',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        color: D30Colors.accent,
                        height: 54,
                        child: Row(
                          children: [
                            for (final tab in PackMenu.values)
                              Expanded(
                                flex: selectedMenu == tab ? 2 : 1,
                                child: PressFeedback(
                                  child: InkWell(
                                    key: ValueKey('menu-tab-${tab.name}'),
                                    onTap: () => setState(() {
                                      selectedMenu = tab;
                                      combining = false;
                                      materials.clear();
                                    }),
                                    child: SizedBox.expand(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            switch (tab) {
                                              PackMenu.books => Icons.book,
                                              PackMenu.items =>
                                                Icons.card_giftcard,
                                              PackMenu.shop => Icons.storefront,
                                              PackMenu.stationery => Icons.edit,
                                            },
                                            color: D30Colors.panel,
                                            size: 25,
                                          ),
                                          if (selectedMenu == tab) ...[
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  switch (tab) {
                                                    PackMenu.books => 'Books',
                                                    PackMenu.items => 'Items',
                                                    PackMenu.shop => 'Store',
                                                    PackMenu.stationery =>
                                                      'Stationery',
                                                  },
                                                  style: const TextStyle(
                                                    color: D30Colors.panel,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
