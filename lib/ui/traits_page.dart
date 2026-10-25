/// Manage Traits (MM-14..27): the account's trait packs, collection,
/// catalog and combining.
///
/// Recovered: each pack's per-card rank odds and card count (Chances Info),
/// Standard/Jumbo prices and mileage, the 1000-mileage S guarantee, three
/// cards per combine, S only with S, and combine-locking per copy. Not
/// recovered, so provisional and labelled as such: the other packs' prices,
/// and combine results (the original's Combine Rates was a web page).
///
/// The account collection does not yet gate setup's trait picks, which stay
/// all-owned (setup.dart's prototype policy).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/account_catalog.dart';
import '../engine/account_store.dart';
import '../engine/pack.dart';
import 'account_widgets.dart';
import 'home_screen.dart';
import 'haptics.dart';
import 'pack_image.dart';

class ManageTraitsSheet extends StatefulWidget {
  /// Supplies the trait catalog (every campaign's traits).
  final ContentPack pack;
  const ManageTraitsSheet({super.key, required this.pack});

  @override
  State<ManageTraitsSheet> createState() => _ManageTraitsSheetState();
}

class _ManageTraitsSheetState extends State<ManageTraitsSheet> {
  String _campaign = 'standard';
  final _pages = PageController(viewportFraction: .5);
  int _index = 0;

  Account get account => AccountStore.current;

  List<TraitPackKind> get _kinds => [
    for (final k in TraitPackKind.all)
      if (k.campaign == _campaign) k,
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _buy(TraitPackKind kind) async {
    if (!account.buyPack(kind)) {
      _say('Not enough cookies.');
      return;
    }
    unawaited(AccountStore.save());
    setState(() {});
  }

  Future<void> _open(TraitPackKind kind) async {
    var current = kind;
    while (mounted && (account.packs[current.id] ?? 0) > 0) {
      final drawn = account.openPack(current, widget.pack);
      if (drawn == null) break;
      unawaited(AccountStore.save());
      if (!mounted) return;
      final again = await Navigator.of(context).push<bool>(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, _, _) => PackReveal(
            kind: current,
            drawn: drawn,
            pool: Account.poolFor(widget.pack, current.campaign),
            remaining: account.packs[current.id] ?? 0,
          ),
        ),
      );
      if (again != true) break;
    }
    if (mounted) setState(() {});
  }

  void _say(String text) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final kinds = _kinds;
    final kind = kinds[_index.clamp(0, kinds.length - 1)];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AccountSheet(
        title: 'Manage Traits',
        leading: Builder(
          builder: (context) {
            final u = MediaQuery.sizeOf(context).width / 390;
            return GestureDetector(
              key: const ValueKey('chances-info'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _ChancesInfo(campaign: _campaign),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 3 * u,
                  vertical: 7 * u,
                ),
                decoration: BoxDecoration(
                  color: HomeColors.paper,
                  borderRadius: BorderRadius.circular(8 * u),
                ),
                child: Text(
                  'Chances Info',
                  style: TextStyle(fontSize: 10 * u, color: HomeColors.orange),
                ),
              ),
            );
          },
        ),
        body: (context, u) => Column(
          children: [
            _mileage(u),
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(12 * u, 12 * u, 12 * u, 10 * u),
                color: HomeColors.cardFill,
                child: Column(
                  children: [
                    SizedBox(height: 12 * u),
                    GraySegments<String>(
                      u: u,
                      options: TraitPackKind.campaigns,
                      selected: _campaign,
                      onChanged: (c) => setState(() {
                        _campaign = c;
                        _index = 0;
                        if (_pages.hasClients) _pages.jumpToPage(0);
                      }),
                    ),
                    SizedBox(
                      height: 230 * u,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: kinds.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * u,
                            vertical: i == _index ? 4 * u : 30 * u,
                          ),
                          child: GestureDetector(
                            onTap: () => _pages.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                            child: PackImage(
                              path: kinds[i].image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      color: const Color(0xFF4A2B10),
                      indent: 8 * u,
                      endIndent: 8 * u,
                      thickness: 1.2 * u,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            kind.name,
                            style: TextStyle(
                              fontSize: 16 * u,
                              color: HomeColors.orange,
                            ),
                          ),
                          SizedBox(width: 6 * u),
                          CookieAmount(u: u, amount: kind.price, size: 15),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _mBadge(u, 16),
                        SizedBox(width: 5 * u),
                        Text(
                          'Mileage Gained : ${kind.mileage}',
                          style: TextStyle(
                            fontSize: 14 * u,
                            color: HomeColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      color: const Color(0xFF4A2B10),
                      indent: 8 * u,
                      endIndent: 8 * u,
                      thickness: 1.2 * u,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18 * u),
                        child: Text(
                          kind.description +
                              (kind.priceRecovered
                                  ? ''
                                  : '\n(price and mileage are placeholders)'),
                          style: TextStyle(
                            fontSize: 13.5 * u,
                            color: HomeColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14 * u, 0, 8 * u, 12 * u),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Owned : ${account.packs[kind.id] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 14 * u,
                                    color: (account.packs[kind.id] ?? 0) == 0
                                        ? const Color(0xFFE05050)
                                        : HomeColors.ink,
                                  ),
                                ),
                                SizedBox(height: 4 * u),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: 20 * u,
                                      child: const PackImage(
                                        path: 'kss/images/cookie.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    SizedBox(width: 5 * u),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Cookies Owned : ${account.cookies}',
                                          style: TextStyle(
                                            fontSize: 14 * u,
                                            color: HomeColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 84 * u,
                            child: FaceButton(
                              key: const ValueKey('pack-open'),
                              u: u,
                              label: 'Open',
                              height: 32,
                              fontSize: 16,
                              onTap: (account.packs[kind.id] ?? 0) > 0
                                  ? () => _open(kind)
                                  : null,
                            ),
                          ),
                          SizedBox(width: 9 * u),
                          SizedBox(
                            width: 84 * u,
                            child: FaceButton(
                              key: const ValueKey('pack-buy'),
                              u: u,
                              label: 'Buy',
                              height: 32,
                              fontSize: 16,
                              onTap: () => _buy(kind),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14 * u, 0, 14 * u, 10 * u),
              child: Row(
                children: [
                  for (final (label, icon, page) in [
                    ('My Traits', Icons.face, 0),
                    ('Traits Database', Icons.menu_book, 1),
                    ('Combine', Icons.add, 2),
                  ]) ...[
                    if (page > 0) SizedBox(width: 12 * u),
                    Expanded(
                      child: _NavTile(
                        key: ValueKey('traits-$label'),
                        u: u,
                        label: label,
                        icon: icon,
                        onTap: () async {
                          await pushOverlay<void>(context, switch (page) {
                            0 => _MyTraits(pack: widget.pack),
                            1 => _Database(pack: widget.pack),
                            _ => _Combine(pack: widget.pack),
                          });
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  Widget _mileage(double u) => Container(
    margin: EdgeInsets.fromLTRB(12 * u, 6 * u, 12 * u, 0),
    padding: EdgeInsets.fromLTRB(8 * u, 8 * u, 8 * u, 10 * u),
    decoration: BoxDecoration(
      color: HomeColors.cardFill,
      borderRadius: BorderRadius.circular(9 * u),
      boxShadow: [
        BoxShadow(
          color: const Color(0x334A2B10),
          blurRadius: 4 * u,
          offset: Offset(0, 2.5 * u),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            _mBadge(u, 18),
            SizedBox(width: 8 * u),
            Expanded(
              child: Container(
                height: 8 * u,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5 * u),
                  border: Border.all(
                    color: const Color(0xFF4A2B10),
                    width: 1.2 * u,
                  ),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (account.mileage / mileageMax).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5 * u),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE07A7A), Color(0xFF8A6AE0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8 * u),
            Text(
              '${account.mileage}/$mileageMax',
              style: TextStyle(fontSize: 14 * u, color: HomeColors.ink),
            ),
          ],
        ),
        SizedBox(height: 4 * u),
        Text(
          'Opening a Trait Pack with full mileage guarantees an S-Tier Trait.\n'
          '(mileage resets if S-Tier Trait is obtained prior to guarantee)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9 * u, height: 1.4, color: HomeColors.ink),
        ),
      ],
    ),
  );

  Widget _mBadge(double u, double size) => Container(
    width: size * u,
    height: size * u,
    decoration: const BoxDecoration(
      color: Colors.black,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      'M',
      style: TextStyle(
        fontSize: size * .6 * u,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _NavTile extends StatelessWidget {
  final double u;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavTile({
    super.key,
    required this.u,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: HomeColors.orange,
    borderRadius: BorderRadius.circular(9 * u),
    elevation: 2,
    child: InkWell(
      borderRadius: BorderRadius.circular(9 * u),
      onTap: onTap,
      child: SizedBox(
        height: 70 * u,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30 * u),
            SizedBox(height: 2 * u),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 14 * u, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChancesInfo extends StatelessWidget {
  final String campaign;
  const _ChancesInfo({required this.campaign});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chances Info'),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Probability by rank, per card.'),
          const SizedBox(height: 8),
          for (final k in TraitPackKind.all)
            if (k.campaign == campaign)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${k.name} (×${k.cards})\n'
                  '${k.odds.entries.map((e) => '${e.key} ${e.value}%').join('  ·  ')}',
                ),
              ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Confirm'),
      ),
    ],
  );
}

/// Tall child panel with a centred title, a scrolling body and a fixed
/// footer (My Traits, Traits Database, Combine Traits).
class _TallPanel extends StatelessWidget {
  final String title;
  final Widget Function(double u) body;
  final Widget Function(double u) footer;
  final Widget Function(double u)? topLeft;

  const _TallPanel({
    required this.title,
    required this.body,
    required this.footer,
    this.topLeft,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final u = box.maxWidth / 390;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          5 * u,
          MediaQuery.paddingOf(context).top + 40 * u,
          5 * u,
          MediaQuery.paddingOf(context).bottom + 8 * u,
        ),
        child: ChildPanel(
          u: u,
          child: Column(
            children: [
              SizedBox(height: 14 * u),
              if (topLeft != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20 * u),
                    child: topLeft!(u),
                  ),
                ),
              Text(
                title,
                style: TextStyle(fontSize: 23 * u, color: HomeColors.ink),
              ),
              SizedBox(height: 8 * u),
              Expanded(child: body(u)),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 10 * u, 0, 18 * u),
                child: footer(u),
              ),
            ],
          ),
        ),
      );
    },
  );
}

SliverGridDelegate _cardGrid(double u) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 10 * u,
      crossAxisSpacing: 10 * u,
      childAspectRatio: 100 / 88,
    );

class _MyTraits extends StatelessWidget {
  final ContentPack pack;
  const _MyTraits({required this.pack});

  @override
  Widget build(BuildContext context) {
    final owned = [
      for (final t in AccountStore.current.traits)
        if (pack.traits[t.traitId] case final trait?) (t, trait),
    ]..sort((a, b) => _rankIndex(a.$2.rank).compareTo(_rankIndex(b.$2.rank)));
    return _TallPanel(
      title: 'My Traits',
      body: (u) => owned.isEmpty
          ? Center(
              child: Text(
                'No traits yet. Open a Trait Pack.',
                style: TextStyle(fontSize: 14 * u, color: HomeColors.muted),
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: 30 * u,
                vertical: 6 * u,
              ),
              gridDelegate: _cardGrid(u),
              itemCount: owned.length,
              itemBuilder: (_, i) => TraitCard(
                trait: owned[i].$2,
                u: u,
                lock: owned[i].$1.locked ? LockMark.small : LockMark.none,
              ),
            ),
      footer: (u) => SizedBox(
        width: 150 * u,
        child: FaceButton(
          key: const ValueKey('panel-confirm'),
          u: u,
          label: 'Confirm',
          height: 38,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

int _rankIndex(String rank) => const ['S', 'A', 'B', 'C'].indexOf(rank);

class _Database extends StatelessWidget {
  final ContentPack pack;
  const _Database({required this.pack});

  @override
  Widget build(BuildContext context) {
    final ownedIds = {for (final t in AccountStore.current.traits) t.traitId};
    final catalog = [
      for (final t in pack.traits.values)
        if (t.setupEligible && _rankIndex(t.rank) >= 0) t,
    ];
    return _TallPanel(
      title: 'Traits Database',
      body: (u) => CustomScrollView(
        slivers: [
          for (final rank in const ['S', 'A', 'B', 'C']) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(30 * u, 14 * u, 30 * u, 6 * u),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          rank,
                          style: TextStyle(
                            fontSize: 22 * u,
                            color: rank == 'S'
                                ? HomeColors.ink
                                : rankColor(rank),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${catalog.where((t) => t.rank == rank && ownedIds.contains(t.id)).length}'
                          '/${catalog.where((t) => t.rank == rank).length}',
                          style: TextStyle(
                            fontSize: 15 * u,
                            color: HomeColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: const Color(0xFF4A2B10), thickness: 1.2 * u),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 30 * u),
              sliver: SliverGrid.builder(
                gridDelegate: _cardGrid(u),
                itemCount: catalog.where((t) => t.rank == rank).length,
                itemBuilder: (_, i) {
                  final t = catalog.where((t) => t.rank == rank).elementAt(i);
                  return TraitCard(
                    trait: t,
                    u: u,
                    dimmed: !ownedIds.contains(t.id),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      footer: (u) => SizedBox(
        width: 150 * u,
        child: FaceButton(
          key: const ValueKey('panel-confirm'),
          u: u,
          label: 'Confirm',
          height: 38,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _Combine extends StatefulWidget {
  final ContentPack pack;
  const _Combine({required this.pack});

  @override
  State<_Combine> createState() => _CombineState();
}

class _CombineState extends State<_Combine> {
  String _campaign = 'standard';
  final List<OwnedTrait> _picked = [];
  bool _locking = false;

  Account get account => AccountStore.current;

  List<(OwnedTrait, GameTrait)> get _cards {
    final story = TraitPackKind.storyOf(_campaign);
    return [
      for (final t in account.traits)
        if (widget.pack.traits[t.traitId] case final trait?)
          if (trait.storyId == story) (t, trait),
    ]..sort((a, b) => _rankIndex(a.$2.rank).compareTo(_rankIndex(b.$2.rank)));
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );

  Future<void> _tap(OwnedTrait copy) async {
    if (_locking) {
      if (_picked.contains(copy)) {
        _say('Trait cards selected for combinations cannot be Combine-locked.');
        return;
      }
      setState(() => copy.locked = !copy.locked);
      unawaited(AccountStore.save());
      return;
    }
    if (copy.locked) {
      _say('Combine-locked cards cannot be selected.');
      return;
    }
    setState(() {
      if (!_picked.remove(copy) && _picked.length < 3) _picked.add(copy);
    });
  }

  Future<void> _combine() async {
    if (_locking) {
      _say('You cannot combine in the Combine lock settings window.');
      return;
    }
    final problem = account.combineProblem(_picked, widget.pack);
    if (problem != null) {
      _say(problem);
      return;
    }
    final result = account.combine(_picked, widget.pack, _campaign);
    if (result == null) return;
    _picked.clear();
    unawaited(AccountStore.save());
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder(pageBuilder: (_, _, _) => CombineReveal(result: result)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return _TallPanel(
      title: 'Combine Traits',
      topLeft: (u) => GestureDetector(
        key: const ValueKey('combine-rates'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Combine Rates'),
            content: Text(
              'Three traits make one. S-Ranks can only be combined with other '
              'S-Ranks.\n\nThe original\'s rates were not recovered. Here the '
              'result takes the highest rank among the three, with a '
              '${(Account.combineUpgradeChance * 100).round()}% chance of one '
              'rank higher (provisional).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * u, vertical: 5 * u),
          decoration: BoxDecoration(
            color: HomeColors.orange,
            borderRadius: BorderRadius.circular(5 * u),
          ),
          child: Text(
            'Combine Rates',
            style: TextStyle(fontSize: 13 * u, color: Colors.white),
          ),
        ),
      ),
      body: (u) => Column(
        children: [
          GraySegments<String>(
            u: u,
            options: TraitPackKind.campaigns,
            selected: _campaign,
            onChanged: (c) => setState(() {
              _campaign = c;
              _picked.clear();
            }),
          ),
          if (!_locking) ...[
            SizedBox(height: 22 * u),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: 14 * u),
                  SizedBox(
                    width: 90 * u,
                    child: Column(
                      children: [
                        Container(
                          height: 80 * u,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8 * u),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x22000000),
                                blurRadius: 4 * u,
                              ),
                            ],
                          ),
                          child: i < _picked.length
                              ? TraitCard(
                                  trait:
                                      widget.pack.traits[_picked[i].traitId]!,
                                  u: u * .9,
                                )
                              : null,
                        ),
                        SizedBox(height: 7 * u),
                        FaceButton(
                          key: ValueKey('slot-remove-$i'),
                          u: u,
                          label: '',
                          height: 28,
                          color: const Color(0xFFD65A55),
                          onTap: i < _picked.length
                              ? () => setState(() => _picked.removeAt(i))
                              : () {},
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24 * u,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: _locking ? 50 * u : 24 * u),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22 * u),
            child: Row(
              children: [
                Expanded(
                  child: FaceButton(
                    key: const ValueKey('combine-go'),
                    u: u,
                    label: 'Combine',
                    height: 44,
                    fontSize: 24,
                    color: _locking
                        ? const Color(0xFFFCE6D2)
                        : HomeColors.orange,
                    onTap: _combine,
                    child: _locking
                        ? Text(
                            'Combine',
                            style: TextStyle(
                              fontSize: 24 * u,
                              color: HomeColors.orange,
                            ),
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 14 * u),
                SizedBox(
                  width: 50 * u,
                  child: FaceButton(
                    key: const ValueKey('combine-lock'),
                    u: u,
                    label: '',
                    height: 44,
                    color: _locking
                        ? const Color(0xFFB4501E)
                        : HomeColors.orange,
                    onTap: () => setState(() => _locking = !_locking),
                    child: Icon(
                      Icons.lock,
                      color: const Color(0xFFFFF6E6),
                      size: 26 * u,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12 * u),
          Divider(
            color: const Color(0xFF4A2B10),
            indent: 22 * u,
            endIndent: 22 * u,
            thickness: 1.2 * u,
          ),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      'No traits from this campaign.',
                      style: TextStyle(
                        fontSize: 14 * u,
                        color: HomeColors.muted,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 30 * u,
                      vertical: 6 * u,
                    ),
                    gridDelegate: _cardGrid(u),
                    itemCount: cards.length,
                    itemBuilder: (_, i) {
                      final (copy, trait) = cards[i];
                      return TraitCard(
                        key: ValueKey('combine-card-${copy.uid}'),
                        trait: trait,
                        u: u,
                        selected: _picked.contains(copy),
                        dimmed: copy.locked,
                        lock: copy.locked
                            ? (_locking ? LockMark.large : LockMark.small)
                            : LockMark.none,
                        onTap: () => _tap(copy),
                      );
                    },
                  ),
          ),
          Divider(
            color: const Color(0xFF4A2B10),
            indent: 22 * u,
            endIndent: 22 * u,
            thickness: 1.2 * u,
          ),
        ],
      ),
      footer: (u) => SizedBox(
        width: 160 * u,
        child: FaceButton(
          key: const ValueKey('panel-close-red'),
          u: u,
          label: 'Close',
          height: 42,
          fontSize: 22,
          color: const Color(0xFFE8504A),
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// MM-16..18: the wrapper, a single-card roulette that stops on tap, then
/// the results with arrows, an index, confetti, Exit and Draw More.
class PackReveal extends StatefulWidget {
  final TraitPackKind kind;
  final List<GameTrait> drawn;
  final List<GameTrait> pool;

  /// Packs of this kind still owned: Draw More appears while any are left.
  final int remaining;

  const PackReveal({
    super.key,
    required this.kind,
    required this.drawn,
    required this.pool,
    required this.remaining,
  });

  @override
  State<PackReveal> createState() => _PackRevealState();
}

enum _Stage { wrapper, rolling, results }

class _PackRevealState extends State<PackReveal> {
  _Stage _stage = _Stage.wrapper;
  Timer? _spin;
  GameTrait? _face;
  int _index = 0;
  final _rng = Random();

  @override
  void dispose() {
    _spin?.cancel();
    super.dispose();
  }

  void _tap() {
    switch (_stage) {
      case _Stage.wrapper:
        setState(() => _stage = _Stage.rolling);
        _spin = Timer.periodic(const Duration(milliseconds: 70), (_) {
          if (widget.pool.isEmpty) return;
          setState(() => _face = widget.pool[_rng.nextInt(widget.pool.length)]);
        });
      case _Stage.rolling:
        Haptics.stop();
        _spin?.cancel();
        setState(() => _stage = _Stage.results);
      case _Stage.results:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        key: const ValueKey('reveal-stage'),
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: RevealStage(
          child: LayoutBuilder(
            builder: (context, box) {
              final u = box.maxWidth / 390;
              return Stack(
                children: [
                  if (_stage == _Stage.results)
                    const Positioned.fill(
                      child: ConfettiLayer(colors: ConfettiLayer.packColors),
                    ),
                  Center(
                    child: switch (_stage) {
                      _Stage.wrapper => SizedBox(
                        width: 160 * u,
                        child: PackImage(
                          path: widget.kind.image,
                          fit: BoxFit.contain,
                        ),
                      ),
                      _Stage.rolling => SizedBox(
                        width: 132 * u,
                        height: 116 * u,
                        child: _face == null
                            ? null
                            : TraitCard(trait: _face!, u: u * 1.3),
                      ),
                      _Stage.results => _results(u),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _results(double u) {
    final drawn = widget.drawn;
    if (drawn.isEmpty) return const SizedBox.shrink();
    final trait = drawn[_index];
    Widget arrow(IconData icon, int step) => IconButton(
      key: ValueKey('reveal-arrow-$step'),
      onPressed: () => setState(
        () => _index = (_index + step + drawn.length) % drawn.length,
      ),
      icon: Icon(icon, color: const Color(0xFFFFF6E6), size: 40 * u),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            arrow(Icons.arrow_left, -1),
            SizedBox(
              width: 132 * u,
              height: 116 * u,
              child: TraitCard(trait: trait, u: u * 1.3),
            ),
            arrow(Icons.arrow_right, 1),
          ],
        ),
        SizedBox(height: 50 * u),
        Text(
          '${_index + 1} / ${drawn.length}',
          style: TextStyle(fontSize: 30 * u, color: Colors.white),
        ),
        SizedBox(height: 26 * u),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 130 * u,
              child: FaceButton(
                key: const ValueKey('reveal-exit'),
                u: u,
                label: 'Exit',
                height: 50,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            if (widget.remaining > 0) ...[
              SizedBox(width: 20 * u),
              SizedBox(
                width: 150 * u,
                child: FaceButton(
                  key: const ValueKey('reveal-more'),
                  u: u,
                  label: 'Draw More (${widget.remaining})',
                  height: 50,
                  fontSize: 17,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// MM-24/25: one card, confetti in its tier's colour, Confirm fading in
/// after half a second.
class CombineReveal extends StatefulWidget {
  final GameTrait result;
  const CombineReveal({super.key, required this.result});

  @override
  State<CombineReveal> createState() => _CombineRevealState();
}

class _CombineRevealState extends State<CombineReveal> {
  bool _confirm = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _confirm = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RevealStage(
      child: LayoutBuilder(
        builder: (context, box) {
          final u = box.maxWidth / 390;
          return Stack(
            children: [
              Positioned.fill(
                child: ConfettiLayer(colors: [rankColor(widget.result.rank)]),
              ),
              Center(
                child: SizedBox(
                  width: 132 * u,
                  height: 116 * u,
                  child: TraitCard(trait: widget.result, u: u * 1.3),
                ),
              ),
              Positioned(
                left: 58 * u,
                right: 58 * u,
                top: box.maxHeight * .76,
                child: AnimatedOpacity(
                  opacity: _confirm ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_confirm,
                    child: FaceButton(
                      key: const ValueKey('combine-confirm'),
                      u: u,
                      label: 'Confirm',
                      height: 50,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
