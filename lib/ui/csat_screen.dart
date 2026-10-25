/// Exam day after the Graduation Exam cards: the orchestrator that walks the
/// recreated D-Day screens in order, resuming at the stage the saved run is
/// in (`Game.ddayStage`, see docs/DDAY-FLOW.md):
///
///   score announcement (dialog) -> Submit route -> results flow.
///
/// The exam cards themselves live in the game screen's hand area
/// (`game_screen.dart`); this runs once they are all taken. The results and
/// enrollment screens are `DdayResultsFlow` (dday_results.dart).
library;

import 'package:flutter/material.dart';

import '../engine/game.dart';
import 'dday_results.dart';
import 'score_announcement.dart';
import 'submit_page.dart';

/// Plays what follows enrollment while the Student ID / share scene is still
/// the page behind it (the authored ending events). It owns leaving the
/// results route: when it returns the flow is expected to be gone.
typedef EndingsOverScene = Future<void> Function();

class CsatScreen {
  CsatScreen._();

  /// Runs the rest of the sitting; returns once the student has enrolled (or
  /// chosen to retake the year). With [endings], the scene stays on screen
  /// behind the ending events instead of closing first (DDAY-C03).
  static Future<void> show(
    BuildContext context,
    Game game, {
    EndingsOverScene? endings,
  }) async {
    // Any card still untaken (headless or resumed oddly) is taken silently.
    game.completeExamCards();
    if (game.ddayStage == DDayStage.scoreAnnouncement) {
      await showScoreAnnouncement(context, game);
      if (!context.mounted) return;
    }
    if (game.ddayStage == DDayStage.drafting) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SubmitPage(game: game, endings: endings),
        ),
      );
      if (!context.mounted) return;
    }
    if (game.ddayStage == DDayStage.results ||
        game.ddayStage == DDayStage.finalDecision) {
      await pushResults(context, game, endings: endings);
    }
  }

  /// Pushes the results flow; it pops itself via `onFinished`, unless
  /// [endings] takes over leaving it.
  static Future<void> pushResults(
    BuildContext context,
    Game game, {
    EndingsOverScene? endings,
  }) {
    final navigator = Navigator.of(context);
    return navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => DdayResultsFlow(
          game: game,
          onFinished: () {
            if (endings == null) {
              navigator.pop();
            } else {
              endings();
            }
          },
        ),
      ),
    );
  }
}
