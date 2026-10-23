/// d30mode -- a data-driven rebuild of Korean Student Simulator's 31-Day Mode.
///
/// The engine holds no content. Everything -- the calendar, locations,
/// actions, events, items, traits, level tables, and every tuning number --
/// comes from a content pack on disk that can be edited and reloaded without
/// rebuilding the app. See docs/PACK-FORMAT.md and the in-app dev panel.
library;

import 'package:flutter/material.dart';

import 'engine/content_source.dart';
import 'engine/game.dart';
import 'engine/pack.dart';
import 'ui/game_screen.dart';

void main() => runApp(const D30App());

class D30App extends StatelessWidget {
  const D30App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D30',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCF6679)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCF6679),
          brightness: Brightness.dark,
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

  void _start() {
    final pack = _pack;
    final location = _location;
    if (pack == null || location == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          game: Game.newRun(pack),
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
                  _pack == null
                      ? 'D-31'
                      : 'D-${_pack!.manifest.totalDays - 1}',
                  style: const TextStyle(
                      fontSize: 56, fontWeight: FontWeight.bold),
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
                          horizontal: 48, vertical: 16),
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
            Text('The pack did not load',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onErrorContainer)),
            const SizedBox(height: 8),
            Text('$error',
                style: TextStyle(
                    color: scheme.onErrorContainer, fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                  onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
