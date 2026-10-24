import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/event_text.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

/// TODO 37: the quiz choices showed {문제}/{정답}/{오답} instead of a question
/// and answers, so the prize was never knowingly won.
void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  EventRun toQuiz(Game game) {
    final run = game.events.begin(pack.events[32]!, game.state);
    while (run.current!.choices.isEmpty) {
      run.advance();
    }
    return run;
  }

  test('the Riddle Expert asks a real question with shuffled answers', () {
    expect(pack.quizzes, hasLength(68));
    final firsts = <String>{};
    for (var seed = 0; seed < 12; seed++) {
      final game = Game.newRun(pack, random: Random(seed));
      final run = toQuiz(game);
      final quiz = game.state.quiz!;
      final heading = expandEventText(run.current!.node.optionText!, game.state);
      expect(heading, quiz.problem.text);
      final texts = run.current!.choices.map((c) => c.text).toList();
      expect(texts.any((t) => t.contains('{')), isFalse);
      expect(texts.where((t) => t == quiz.problem.answerText), hasLength(1));
      expect(texts.toSet(), hasLength(texts.length), reason: 'no repeats');
      expect(texts.length, quiz.problem.options.length);
      firsts.add(texts.first == quiz.problem.answerText ? 'answer' : 'wrong');
    }
    expect(firsts, containsAll(['answer', 'wrong']));
  });

  test('the right answer wins a prize and a wrong one does not', () {
    for (final right in [true, false]) {
      final game = Game.newRun(pack, random: Random(4));
      final run = toQuiz(game);
      final answer = game.state.quiz!.problem.answerText;
      run.choose(
        run.current!.choices.firstWhere((c) => (c.text == answer) == right),
      );
      while (!run.current!.isEnd) {
        run.advance();
      }
      expect(run.acquiredItems.isNotEmpty, right);
    }
  });
}
