/// d30mode -- a data-driven rebuild of Korean Student Simulator's 31-Day Mode.
///
/// The engine holds no content. Everything -- the calendar, locations,
/// actions, events, items, traits, level tables, and every tuning number --
/// comes from a content pack on disk that can be edited and reloaded without
/// rebuilding the app. See docs/PACK-FORMAT.md and the in-app dev panel.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'engine/content_source.dart';
import 'engine/game.dart';
import 'engine/pack.dart';
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
  runApp(const D30App());
}

class D30App extends StatelessWidget {
  const D30App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D30',
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
        dividerTheme: const DividerThemeData(color: D30Colors.ink, thickness: 1.5),
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
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _setup = RunSetup(pack);
        _location = location;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _stack = st;
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    final pack = _pack;
    final location = _location;
    if (pack == null || location == null) return;
    PackImages.use(location);
    final game = await Navigator.of(context).push<Game>(
      MaterialPageRoute(
        builder: (_) =>
            SetupScreen(pack: pack, draft: _setup ??= RunSetup(pack)),
      ),
    );
    if (game == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: game,
          packLocation: location,
          onPackReloaded: (p, l) => setState(() {
            _pack = p;
            _location = l;
          }),
        ),
      ),
    );
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
                  FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                    child: const Text('Start'),
                  ),
                  const SizedBox(height: 28),
                  _PackSummary(pack: _pack!, location: _location!),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reload pack'),
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
              child: FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
