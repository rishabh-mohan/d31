/// Quiz questions for the `{문제}` / `{정답}` / `{오답}` choice macros.
///
/// The bank is the global `school_exam_problems.json` (68 English questions,
/// one answer each). Story 16's Riddle Expert and Retry Year's Banjang's Quiz
/// ask "Here's your question!" over a choice whose options are literally
/// `{정답}` (answer) and three `{오답}` (wrong answers): the question is
/// drawn when the choice appears and the options are shuffled, or the answer
/// would always be the first button.
///
/// Retry Year's `{MATH_*}` and `{ENGLISH_*}` macros are filled from the same
/// bank's maths and English questions. The native builds those with code that
/// was not recovered, so that part is a stand-in.
library;

import 'dart:math';

class QuizProblem {
  final int id;
  final String subject;
  final String text;
  final List<String> options;
  final int answer;

  const QuizProblem({
    required this.id,
    required this.subject,
    required this.text,
    required this.options,
    required this.answer,
  });

  factory QuizProblem.fromJson(Map<String, dynamic> j) => QuizProblem(
    id: (j['id'] as num).toInt(),
    subject: j['subject'] as String? ?? '',
    text: j['text'] as String? ?? '',
    options: (j['options'] as List? ?? const []).map((o) => '$o').toList(),
    answer: (j['answer'] as num?)?.toInt() ?? 0,
  );

  String get answerText => options[answer];
}

/// The question on screen and the wrong answers not yet handed out.
class QuizDraw {
  final QuizProblem problem;
  final List<String> _wrong;
  int _next = 0;

  QuizDraw(this.problem, Random random)
    : _wrong = [
        for (var i = 0; i < problem.options.length; i++)
          if (i != problem.answer) problem.options[i],
      ]..shuffle(random);

  /// Each `{오답}` in a choice is a different wrong answer; once they run out
  /// (a three-option question asked over four buttons) it is empty, and the
  /// engine drops that button.
  String nextWrong() => _next < _wrong.length ? _wrong[_next++] : '';

  void rewind() => _next = 0;

  /// The macro family a text uses, if any: `general`, `math` or `english`.
  static String? kindOf(String text) {
    if (text.contains('{문제}') ||
        text.contains('{정답}') ||
        text.contains('{오답}')) {
      return 'general';
    }
    if (text.contains('{MATH_')) return 'math';
    if (text.contains('{ENGLISH_')) return 'english';
    return null;
  }

  static QuizDraw? draw(List<QuizProblem> bank, String kind, Random random) {
    final pool = switch (kind) {
      'math' => bank.where((p) => p.subject == 'math').toList(),
      'english' => bank.where((p) => p.subject == 'english').toList(),
      _ => bank,
    };
    final from = pool.isEmpty ? bank : pool;
    if (from.isEmpty) return null;
    return QuizDraw(from[random.nextInt(from.length)], random);
  }
}
