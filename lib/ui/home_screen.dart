/// Home (MM-01): the desk scene behind a right-edge menu, the first screen.
///
/// Laid out on the original's 390 x 844 design canvas (its wallpaper block
/// SVGs are drawn at that size) and scaled to the screen width, so positions
/// read straight off the reference. The original's Rank (leaderboard) is
/// left out on purpose, as are mail, the seasonal badge, Charging, Store and
/// Notices, whose destinations were never captured.
///
/// Home also owns pack loading, which used to sit behind the old title
/// screen's slot list: the campaigns load here, and Start, Records and
/// Settings work from them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/account_catalog.dart';
import '../engine/account_store.dart';
import '../engine/content_source.dart';
import '../engine/game.dart';
import '../engine/pack.dart';
import '../engine/save_store.dart';
import '../engine/setup.dart';
import 'day_transition.dart';
import 'game_screen.dart';
import 'account_widgets.dart';
import 'achievements_page.dart';
import 'daily_quest.dart';
import 'home_pages.dart';
import 'puzzles_page.dart';
import 'traits_page.dart';
import 'pack_image.dart';
import 'setup_screen.dart';

/// Home's palette, read off MM-01 and the wallpaper block SVGs.
class HomeColors {
  static const paper = Color(0xFFFFFAE9);
  static const rule = Color(0xFFFFEEDB);
  static const orange = Color(0xFFF0915F);
  static const outline = Color(0xFFF5B08A);
  static const face = Color(0xFFFFF7E8);
  static const ink = Color(0xFF4C2A08);
  static const muted = Color(0xFF9A8F86);
  static const cardFill = Color(0xFFFCEFE0);
  static const trash = Color(0xFFE85A50);
}

/// The desk wallpaper every account page is drawn over.
const homeWallpaper = 'kss/images/wallpaper_image/wallpaper0.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ContentPack? _pack;
  PackLocation? _location;
  Object? _error;
  bool _loading = true;
  RunSetup? _setup;
  final Map<String, (ContentPack, PackLocation)> _campaigns = {};

  /// MM-02: the four-arrow button hides the menu; a tap anywhere returns it.
  bool _sceneOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AccountStore.load();
      try {
        AccountStore.catalog = AccountCatalog.parse(
          await rootBundle.loadString('assets/account/catalog.json'),
        );
      } catch (_) {
        // No catalog built: the account pages show empty lists.
      }
      final (pack, location) = await ContentSource.load();
      _campaigns[pack.manifest.id] = (pack, location);
      for (final id in await ContentSource.availablePackIds()) {
        if (id != pack.manifest.id) {
          _campaigns[id] = await ContentSource.load(packId: id);
        }
      }
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _setup = RunSetup(pack);
        _location = location;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Opens a saved run. A save that cannot be read is reported rather than
  /// silently starting a new game in its place.
  Future<void> _continue(SaveSummary save) async {
    final campaign = _campaigns[save.packId];
    if (campaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The saved campaign "${save.packId}" is unavailable.'),
        ),
      );
      return;
    }
    final (pack, location) = campaign;
    PackImages.use(location);
    final state = await SaveStore.read(save.slot, pack);
    if (!mounted) return;
    if (state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That save could not be read.')),
      );
      return;
    }
    state.saveSlot = save.slot;
    await _play(Game(pack: state.pack, state: state), location);
  }

  /// The plus tile: setup, then a run with a save of its own from the start.
  Future<void> _newGame() async {
    final base = _pack;
    final location = _location;
    if (base == null || location == null) return;
    PackImages.use(location);
    // The Settings university set applies from setup on (badge names) and
    // stays with the run.
    final colleges = AccountStore.current.universities.name;
    final pack = base.withColleges(colleges);
    final game = await Navigator.of(context).push<Game>(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          pack: pack,
          draft: _setup ??= RunSetup(pack),
          campaigns: [
            for (final (campaign, _) in _campaigns.values)
              campaign.withColleges(colleges),
          ],
        ),
      ),
    );
    if (game == null || !mounted) return;
    game.state.saveSlot = await SaveStore.nextSlot();
    if (!mounted) return;
    // The reference hands off from setup through the navy D-31 screen, with a
    // dash where the goal goes; the objective is announced over the hub after
    // it. See docs/ui-reference UIR-08 and UIR-09.
    if (!game.openingPending) {
      await DayTransition.show(
        context,
        game: game,
        before: DayTransition.snapshot(game.state),
        initial: true,
      );
    }
    if (!mounted) return;
    final selectedLocation = _campaigns[game.pack.manifest.id]?.$2 ?? location;
    PackImages.use(selectedLocation);
    await _play(game, selectedLocation);
  }

  Future<void> _play(Game game, PackLocation location) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: game,
          packLocation: location,
          onPackReloaded: (p, l) => setState(() {
            _campaigns[p.manifest.id] = (p, l);
            if (_pack?.manifest.id == p.manifest.id) {
              _pack = p;
              _location = l;
              _setup = RunSetup(p);
            }
          }),
        ),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// The campaigns as the account pages show them, in the Settings set.
  List<ContentPack> get _campaignPacks => [
    for (final (pack, _) in _campaigns.values)
      pack.withColleges(AccountStore.current.universities.name),
  ];

  Future<void> _openMenu(String label) async {
    final pack = _pack;
    if (pack == null) return;
    final campaigns = _campaignPacks;
    final installed = {for (final p in campaigns) ?p.manifest.storyId};
    switch (label) {
      case 'Records':
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HistoryPage()));
      case 'Puzzles':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PuzzlesPage(installedStories: installed),
          ),
        );
      case 'Missions':
        await pushOverlay<void>(
          context,
          DailyQuestPanel(catalog: campaigns.first.admissions),
        );
      case 'Achievements':
        await pushOverlay<void>(
          context,
          AchievementsSheet(campaigns: campaigns),
        );
      case 'Traits':
        await pushOverlay<void>(context, ManageTraitsSheet(pack: pack));
    }
    unawaited(AccountStore.save());
    if (mounted) setState(() {});
  }

  void _openStart() => _open(
    SelectGamePage(
      onNewGame: _newGame,
      onContinue: _continue,
      ready: _pack != null,
    ),
  );

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          campaigns: [for (final c in _campaigns.values) c],
          onReload: _load,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_sceneOnly) {
      return GestureDetector(
        key: const ValueKey('home-scene-only'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _sceneOnly = false),
        child: const SizedBox.expand(child: PackImage(path: homeWallpaper)),
      );
    }
    return Scaffold(
      backgroundColor: HomeColors.paper,
      body: LayoutBuilder(
        builder: (context, box) {
          final u = box.maxWidth / 390;
          // The canvas is the whole screen, status bar included, as in the
          // capture: the status bar sits over the top paper strip.
          double y(double v) => v * u;
          final ready = !_loading && _error == null;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // The wallpaper fills the screen and the paper blocks lie over
              // it (the original's wallpaper_block_right/bottom).
              const Positioned.fill(child: PackImage(path: homeWallpaper)),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 32 * u,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomeColors.paper,
                    border: Border(
                      bottom: BorderSide(
                        color: HomeColors.outline,
                        width: 4 * u,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 297 * u,
                right: 0,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomeColors.paper,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x30000000),
                        blurRadius: 8 * u,
                        offset: Offset(-2 * u, 0),
                      ),
                    ],
                  ),
                  child: const CustomPaint(painter: _RuledPaper()),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 600 * u,
                bottom: 0,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: HomeColors.outline, width: 2 * u),
                    ),
                  ),
                  child: const CustomPaint(painter: _RuledPaper()),
                ),
              ),
              Positioned(
                left: 6 * u,
                top: y(46),
                child: _SquareButton(
                  key: const ValueKey('home-settings'),
                  u: u,
                  icon: Icons.settings,
                  tooltip: 'Settings',
                  onTap: _openSettings,
                ),
              ),
              Positioned(
                right: 40 * u,
                top: y(46),
                child: _BalancePill(u: u, account: AccountStore.current),
              ),
              for (final (i, entry) in [
                ('Traits', _MenuIcon.icon(Icons.style)),
                ('Puzzles', _MenuIcon.art('kss/images/puzzle.png')),
                ('Records', _MenuIcon.icon(Icons.history)),
                ('Missions', _MenuIcon.icon(Icons.receipt_long)),
                ('Achievements', _MenuIcon.icon(Icons.workspace_premium)),
              ].indexed)
                Positioned(
                  right: -4 * u,
                  top: y(275 + 59.3 * i),
                  child: _MenuButton(
                    key: ValueKey('home-${entry.$1.toLowerCase()}'),
                    u: u,
                    label: entry.$1,
                    icon: entry.$2,
                    onTap: ready ? () => _openMenu(entry.$1) : null,
                  ),
                ),
              Positioned(
                right: -4 * u,
                top: y(577),
                child: _MenuButton(
                  key: const ValueKey('home-start'),
                  u: u,
                  label: 'Start',
                  icon: _MenuIcon.icon(Icons.edit_outlined),
                  filled: true,
                  onTap: ready ? _openStart : null,
                ),
              ),
              Positioned(
                left: 6 * u,
                top: y(537),
                child: _SquareButton(
                  key: const ValueKey('home-scene'),
                  u: u,
                  icon: Icons.zoom_out_map,
                  tooltip: 'Show the background',
                  onTap: () => setState(() => _sceneOnly = true),
                ),
              ),
              Positioned(
                left: 20 * u,
                right: 140 * u,
                top: y(612),
                child: _loading
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                    ? _LoadError(error: _error!, onRetry: _load)
                    : Text(
                        _pack?.manifest.name ?? '',
                        style: TextStyle(
                          fontSize: 19.5 * u,
                          color: HomeColors.ink,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The cream paper with its faint rules, every 20 units as in the SVGs.
class _RuledPaper extends CustomPainter {
  const _RuledPaper();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 390;
    canvas.drawRect(Offset.zero & size, Paint()..color = HomeColors.paper);
    final line = Paint()
      ..color = HomeColors.rule
      ..strokeWidth = 2 * u;
    for (var y = 24 * u; y < size.height; y += 20 * u) {
      canvas.drawLine(Offset(12 * u, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_RuledPaper old) => false;
}

class _MenuIcon {
  final IconData? icon;
  final String? art;
  const _MenuIcon.icon(IconData this.icon) : art = null;
  const _MenuIcon.art(String this.art) : icon = null;

  Widget build(double size, Color color) => art != null
      ? SizedBox.square(
          dimension: size,
          child: PackImage(path: art, fit: BoxFit.contain),
        )
      : Icon(icon, size: size, color: color);
}

/// A right-edge button: width follows its label, the right side runs off
/// the screen edge.
class _MenuButton extends StatelessWidget {
  final double u;
  final String label;
  final _MenuIcon icon;
  final bool filled;
  final VoidCallback? onTap;

  const _MenuButton({
    super.key,
    required this.u,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : HomeColors.orange;
    final height = (filled ? 63 : 46) * u;
    final radius = BorderRadius.circular(9 * u);
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: filled ? HomeColors.orange : HomeColors.face,
          borderRadius: radius,
          border: Border.all(color: HomeColors.outline, width: 1.6 * u),
          boxShadow: [
            BoxShadow(
              color: const Color(0x334A2B10),
              blurRadius: 4 * u,
              offset: Offset(0, 2.5 * u),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                (filled ? 22 : 18) * u,
                0,
                19 * u,
                0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon.build((filled ? 26 : 21) * u, fg),
                  SizedBox(width: (filled ? 18 : 13) * u),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: (filled ? 25 : 18.5) * u,
                      color: fg,
                      height: 1,
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
}

/// Gear and four-arrow squares.
class _SquareButton extends StatelessWidget {
  final double u;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareButton({
    super.key,
    required this.u,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9 * u);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 46 * u,
        height: 46 * u,
        decoration: BoxDecoration(
          color: HomeColors.face,
          borderRadius: radius,
          border: Border.all(color: HomeColors.outline, width: 1.6 * u),
          boxShadow: [
            BoxShadow(
              color: const Color(0x334A2B10),
              blurRadius: 4 * u,
              offset: Offset(0, 2.5 * u),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Icon(icon, size: 30 * u, color: HomeColors.orange),
          ),
        ),
      ),
    );
  }
}

/// Cookies / refresh tokens (MM-01's 53 / 522).
class _BalancePill extends StatelessWidget {
  final double u;
  final Account account;
  const _BalancePill({required this.u, required this.account});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 18 * u, color: HomeColors.ink);
    return Container(
      key: const ValueKey('home-balance'),
      height: 46 * u,
      padding: EdgeInsets.symmetric(horizontal: 10 * u),
      decoration: BoxDecoration(
        color: HomeColors.face,
        borderRadius: BorderRadius.circular(9 * u),
        border: Border.all(color: HomeColors.outline, width: 1.6 * u),
        boxShadow: [
          BoxShadow(
            color: const Color(0x334A2B10),
            blurRadius: 4 * u,
            offset: Offset(0, 2.5 * u),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 22 * u,
            child: const PackImage(
              path: 'kss/images/cookie.png',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 5 * u),
          Text('${account.cookies} / ', style: style),
          Container(
            width: 20 * u,
            height: 20 * u,
            decoration: const BoxDecoration(
              color: Color(0xFF7A7470),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(3 * u),
            child: const PackImage(
              path: 'kss/images/reroll.png',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 5 * u),
          Text('${account.refreshTokens}', style: style),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The pack did not load',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
