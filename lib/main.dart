/// d30mode -- a data-driven rebuild of Korean Student Simulator's 31-Day Mode.
///
/// The engine holds no content. Everything -- the calendar, locations,
/// actions, events, items, traits, level tables, and every tuning number --
/// comes from a content pack on disk that can be edited and reloaded without
/// rebuilding the app. See docs/PACK-FORMAT.md and the in-app dev panel.
library;

import 'package:flutter/foundation.dart';

import 'ui/press_feedback.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'engine/content_source.dart';
import 'engine/game.dart';
import 'engine/pack.dart';
import 'engine/save_store.dart';
import 'ui/day_transition.dart';
import 'ui/game_screen.dart';
import 'ui/setup_screen.dart';
import 'ui/pack_image.dart';
import 'engine/setup.dart';
import 'ui/theme.dart';

/// Logs any frame that misses the 16ms budget, with the build and raster
/// times split out. Off in release.
///
/// Which half is slow decides the fix: a long **build** is Dart work in
/// `build()` (recompute it less), a long **raster** is the GPU being asked to
/// draw too much (blur, overdraw, oversized images). Guessing between the two
/// wastes a lot of time — this is how to tell.
void _logJankyFrames() {
  if (kReleaseMode) return;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds / 1000.0;
      final raster = t.rasterDuration.inMicroseconds / 1000.0;
      final total = t.totalSpan.inMicroseconds / 1000.0;
      if (total > 16.0) {
        debugPrint(
          'JANK total=${total.toStringAsFixed(1)}ms '
          'build=${build.toStringAsFixed(1)}ms '
          'raster=${raster.toStringAsFixed(1)}ms',
        );
      }
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _logJankyFrames();
  // Every screen is laid out against the 1080x2340 portrait reference, and
  // several of them fit a fixed canvas to the viewport; there is no landscape
  // form to rotate into. The Android manifest locks this too.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const D30App());
}

class D30App extends StatelessWidget {
  const D30App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '30 Days',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: D30Colors.accent,
          surface: D30Colors.panel,
          primary: D30Colors.accentDark,
          onSurface: D30Colors.ink,
        ),
        scaffoldBackgroundColor: D30Colors.page,
        dividerTheme: const DividerThemeData(
          color: D30Colors.ink,
          thickness: 1.5,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: D30Colors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: D30Colors.accent, width: 3),
          ),
        ),
        useMaterial3: true,
      ),
      home: const TitleScreen(),
    );
  }
}

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  ContentPack? _pack;
  PackLocation? _location;
  Object? _error;
  StackTrace? _stack;
  bool _loading = true;
  RunSetup? _setup;
  final Map<String, (ContentPack, PackLocation)> _campaigns = {};

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
      await _loadSaves();
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stack = st;
        _loading = false;
      });
    }
  }

  /// Slot summaries for the title list; rebuilt whenever a run returns here.
  List<SaveSummary?> _saves = const [];

  Future<void> _loadSaves() async {
    final saves = await SaveStore.list();
    if (mounted) setState(() => _saves = saves);
  }

  Future<void> _deleteSlot(int slot) async {
    await SaveStore.delete(slot);
    await _loadSaves();
  }

  /// Opens a saved run. A slot that cannot be read is reported rather than
  /// silently starting a new game over the top of it.
  Future<void> _continue(int slot) async {
    final id = _saves[slot]?.packId ?? ContentSource.defaultPackId;
    final campaign = _campaigns[id];
    if (campaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The saved campaign "$id" is unavailable.')),
      );
      return;
    }
    final (pack, location) = campaign;
    PackImages.use(location);
    final state = await SaveStore.read(slot, pack);
    if (!mounted) return;
    if (state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save slot ${slot + 1} could not be read.')),
      );
      await _loadSaves();
      return;
    }
    state.saveSlot = slot;
    await _play(Game(pack: pack, state: state), location);
  }

  Future<void> _start(int slot) async {
    final pack = _pack;
    final location = _location;
    if (pack == null || location == null) return;
    PackImages.use(location);
    final game = await Navigator.of(context).push<Game>(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          pack: pack,
          draft: _setup ??= RunSetup(pack),
          campaigns: _campaigns.values.map((entry) => entry.$1).toList(),
        ),
      ),
    );
    if (game == null || !mounted) return;
    game.state.saveSlot = slot;
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

  /// Runs the game, then refreshes the slot list: whatever the run saved is
  /// what the title screen should show when it comes back.
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
    await _loadSaves();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _pack == null ? 'D-31' : 'D-${_pack!.manifest.totalDays - 1}',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pack?.manifest.name ?? 'one month mode',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 40),
                if (_loading)
                  const CircularProgressIndicator()
                else if (_error != null)
                  _ErrorCard(error: _error!, stack: _stack, onRetry: _load)
                else ...[
                  for (var slot = 0; slot < SaveStore.slots; slot++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SlotCard(
                        slot: slot,
                        summary: _saves.length > slot ? _saves[slot] : null,
                        onStart: () => _start(slot),
                        onContinue: () => _continue(slot),
                        onDelete: () => _deleteSlot(slot),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _PackSummary(pack: _pack!, location: _location!),
                  PressFeedback(
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reload pack'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackSummary extends StatelessWidget {
  final ContentPack pack;
  final PackLocation location;
  const _PackSummary({required this.pack, required this.location});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final m = pack.manifest;
    return Column(
      children: [
        Text(
          '${m.totalDays} days  ·  ${pack.locations.length} locations  ·  '
          '${pack.events.length} events  ·  ${pack.items.length} items  ·  '
          '${pack.traits.length} traits',
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: 6),
        Text(
          location.editable
              ? 'Editable pack: ${location.describe}'
              : location.describe,
          textAlign: TextAlign.center,
          style: style?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, this.stack, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The pack did not load',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PressFeedback(
                child: FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the title screen's slot list.
///
/// There is no reference capture of the original's slot list, so this stays in
/// the project's own plain style rather than guessing at one.
class _SlotCard extends StatelessWidget {
  final int slot;
  final SaveSummary? summary;
  final VoidCallback onStart;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  const _SlotCard({
    required this.slot,
    required this.summary,
    required this.onStart,
    required this.onContinue,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final save = summary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: D30Colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: D30Colors.panelBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot ${slot + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: D30Colors.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  save == null
                      ? 'Empty'
                      : '${save.name.isEmpty ? 'Unnamed' : save.name} · '
                            'D-${save.daysRemaining}',
                  style: const TextStyle(fontSize: 17, color: D30Colors.ink),
                ),
                if (save != null)
                  Text(
                    'Saved ${_when(save.savedAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: D30Colors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          if (save == null)
            PressFeedback(
              child: FilledButton(
                key: ValueKey('new-run-$slot'),
                onPressed: onStart,
                child: const Text('New run'),
              ),
            )
          else ...[
            PressFeedback(
              child: FilledButton(
                key: ValueKey('continue-$slot'),
                onPressed: onContinue,
                child: const Text('Continue'),
              ),
            ),
            PressFeedback(
              child: IconButton(
                tooltip: 'Delete slot ${slot + 1}',
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete slot ${slot + 1}?'),
        content: const Text('The saved run is removed for good.'),
        actions: [
          PressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
          ),
          PressFeedback(
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
    if (yes == true) onDelete();
  }

  static String _when(DateTime at) {
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
