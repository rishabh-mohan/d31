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

class CsatScreen {
  CsatScreen._();

  /// Runs the rest of the sitting; returns once the student has enrolled (or
  /// chosen to retake the year).
  static Future<void> show(BuildContext context, Game game) async {
    // Any card still untaken (headless or resumed oddly) is taken silently.
    game.completeExamCards();
    if (game.ddayStage == DDayStage.scoreAnnouncement) {
      await showScoreAnnouncement(context, game);
      if (!context.mounted) return;
    }
    if (game.ddayStage == DDayStage.drafting) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => SubmitPage(game: game)),
      );
      if (!context.mounted) return;
    }
    if (game.ddayStage == DDayStage.results ||
        game.ddayStage == DDayStage.finalDecision) {
      await pushResults(context, game);
    }
  }

  /// Pushes the results flow; it pops itself via `onFinished`.
  static Future<void> pushResults(BuildContext context, Game game) {
    final navigator = Navigator.of(context);
    return navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            DdayResultsFlow(game: game, onFinished: () => navigator.pop()),
      ),
    );
  }
}
