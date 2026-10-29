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
import 'package:flutter/services.dart';

import 'engine/base_content.dart';
import 'ui/home_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logJankyFrames();
  // kss16's events, traits and items, merged under every pack (docs below).
  await BaseContent.loadFromAssets();
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
    return ValueListenableBuilder(
      valueListenable: PackThemes.current,
      builder: (context, scheme, child) => MaterialApp(
        title: '30 Days',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: buildPackTheme(scheme),
        home: const HomeScreen(),
      ),
    );
  }
}
