/// Plays one event, laid out like the reference: a titled orange header, the
/// scene behind, and a dialogue box with the speaker tag and the controls.
library;

import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/event_engine.dart';
import 'pack_image.dart';
import 'theme.dart';
import 'event_text.dart';

class EventScreen extends StatefulWidget {
  final EventRun run;
  const EventScreen({super.key, required this.run});

  /// Plays the event as a panel over the game, with the screen behind it
  /// blurred and dimmed, rather than as a separate page.
  static Future<void> show(BuildContext context, EventRun run) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => EventScreen(run: run),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  EventRun get run => widget.run;

  /// Lines seen in this event, for the log button.
  final List<({String? speaker, String text})> _history = [];
  Timer? _fastForward;

  @override
  void dispose() {
    _fastForward?.cancel();
    super.dispose();
  }

  void _stopFastForward() {
    _fastForward?.cancel();
    _fastForward = null;
  }

  @override
  void initState() {
    super.initState();
    _record();
    // An event whose first beat is already the end (everything gated out)
    // should not trap the player on a blank screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final beat = run.current;
      if (beat != null && beat.isEnd && beat.text.trim().isEmpty) {
        if (mounted) Navigator.of(context).maybePop();
      }
    });
  }

  void _record() {
    final beat = run.current;
    final text = beat?.text.trim() ?? '';
    if (text.isNotEmpty) _history.add((speaker: beat?.speakerName, text: text));
  }

  void _advance() {
    final beat = run.current;
    if (beat == null || beat.isEnd) {
      _stopFastForward();
      Navigator.of(context).maybePop();
      return;
    }
    if (beat.choices.isNotEmpty) {
      _stopFastForward();
      return;
    }
    setState(() {
      run.advance();
      _record();
    });
    if (run.current?.choices.isNotEmpty == true) _stopFastForward();
  }

  /// Render every slide for 100ms; choices always require player input.
  void _skip() {
    if (_fastForward != null) {
      setState(_stopFastForward);
      return;
    }
    setState(() {
      _fastForward = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) {
          _stopFastForward();
          return;
        }
        _advance();
      });
    });
  }

  void _choose(EventChoice choice) {
    _stopFastForward();
    setState(() {
      run.choose(choice);
      _record();
    });
  }

  void _showLog() {
    setState(_stopFastForward);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      backgroundColor: D30Colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: D30Colors.accent, width: 3),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Log',
                      style: TextStyle(fontSize: 24, color: D30Colors.ink),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close log',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final line in _history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (line.speaker != null)
                            Text(
                              line.speaker!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: D30Colors.accent,
                              ),
                            ),
                          EventText(
                            line.text,
                            style: const TextStyle(
                              fontSize: 15,
                              color: D30Colors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beat = run.current;
    final hasChoices = beat != null && beat.choices.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 46,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: D30Colors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: D30Colors.accent, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Title bar
                      Container(
                        width: double.infinity,
                        color: D30Colors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          run.event.name.isEmpty
                              ? 'Event ${run.event.id}'
                              : run.event.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Scene + dialogue
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PackImage(
                                  path: _background(beat),
                                  placeholder: const ColoredBox(
                                    color: Color(0xFFBFD4E6),
                                  ),
                                ),
                                // Dim so the dialogue box always reads.
                                Container(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: _DialogueBox(
                                      text: beat?.text ?? '',
                                      speaker: beat?.speakerName,
                                      choices: const [],
                                      onChoose: _choose,
                                      onNext: _advance,
                                      onSkip: _skip,
                                      onLog: _showLog,
                                      showControls: !hasChoices,
                                      exhausted: run.exhausted,
                                    ),
                                  ),
                                ),
                                if (hasChoices) ...[
                                  Positioned.fill(
                                    child: ColoredBox(
                                      color: Colors.black.withValues(
                                        alpha: .55,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: D30Colors.panel,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: D30Colors.accent,
                                          width: 3,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  'Choose',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    color: D30Colors.ink,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Log',
                                                onPressed: _showLog,
                                                icon: const Icon(
                                                  Icons.format_list_bulleted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          for (final choice in beat.choices)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _choose(choice),
                                                  child: EventText(choice.text),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
        ),
      ),
    );
  }

  String? _background(EventBeat? beat) {
    final fromNode = beat?.backgroundImg;
    if (fromNode != null && fromNode.isNotEmpty) {
      // Campaign background paths are not in the pack's art set yet; fall
      // back to the location backdrop so the scene is never blank.
      return run.state.location?.image;
    }
    return run.state.location?.image;
  }
}

class _DialogueBox extends StatelessWidget {
  final String text;
  final String? speaker;
  final List<EventChoice> choices;
  final ValueChanged<EventChoice> onChoose;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onLog;
  final bool showControls;
  final bool exhausted;

  const _DialogueBox({
    required this.text,
    required this.speaker,
    required this.choices,
    required this.onChoose,
    required this.onNext,
    required this.onSkip,
    required this.onLog,
    required this.showControls,
    required this.exhausted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showControls ? onNext : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: D30Colors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: D30Colors.accent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker != null)
              D30Chip(
                text: speaker!,
                color: D30Colors.accent,
                textColor: Colors.white,
                fontSize: 12,
              ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72, maxHeight: 220),
              child: SingleChildScrollView(
                child: EventText(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: D30Colors.ink,
                  ),
                ),
              ),
            ),
            if (choices.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final c in choices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: D30Colors.ink,
                        side: const BorderSide(
                          color: D30Colors.accent,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => onChoose(c),
                      child: EventText(c.text, textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
            if (exhausted)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Cut off after 2000 nodes — this graph probably loops.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (showControls) ...[
                  _RoundButton(
                    icon: Icons.keyboard_double_arrow_right,
                    color: const Color(0xFFB03A3A),
                    onTap: onSkip,
                    tooltip: 'Fast-forward',
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.chevron_right,
                    color: const Color(0xFF3F9D44),
                    onTap: onNext,
                    tooltip: 'Next',
                  ),
                ],
                const Spacer(),
                _RoundButton(
                  icon: Icons.format_list_bulleted,
                  color: D30Colors.ink,
                  onTap: onLog,
                  filled: true,
                  tooltip: 'Log',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final String tooltip;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? color : Colors.white,
        shape: CircleBorder(side: BorderSide(color: color, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: filled ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}
