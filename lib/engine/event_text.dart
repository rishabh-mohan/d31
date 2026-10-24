import 'state.dart';

/// The English content retains Korean name macros. Substitute when displaying
/// a beat, including alternate text, choices and the final line.
String expandEventText(String source, GameState state) {
  String literal(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  final variables = <String, String>{
    '이름': literal(state.firstName),
    '성': literal(state.lastName),
    '성이름': literal(state.fullName),
    'FIRST_NAME': literal(state.firstName),
    'LAST_NAME': literal(state.lastName),
    'PLAYER_NAME': literal(state.fullName),
    'EXERCISE_LEVEL': '${state.exerciseLevel.level}',
    'PART_TIME_JOB_LEVEL': '${state.partTimeLevel.level}',
    'STUDY_LEVEL': '${state.studyLevel.level}',
  };
  final quiz = state.quiz;
  if (quiz != null) {
    for (final key in ['문제', 'MATH_PROBLEM', 'ENGLISH_WORD']) {
      variables[key] = literal(quiz.problem.text);
    }
    for (final key in ['정답', 'MATH_ANSWER', 'ENGLISH_ANSWER']) {
      variables[key] = literal(quiz.problem.answerText);
    }
  }
  return source.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
    final name = match[1]!;
    if (quiz != null &&
        (name == '오답' || name == 'MATH_WRONG' || name == 'ENGLISH_WRONG')) {
      return literal(quiz.nextWrong());
    }
    final call = RegExp(r'^([^()]+)\(([^()]*)\)$').firstMatch(name);
    if (call != null) {
      final arg = call[2]!.trim();
      switch (call[1]) {
        case '이벤트스위치':
          return '${state.switchValue(arg)}';
        case '과목':
          return _subjectAt(state, int.tryParse(arg) ?? 0);
        case 'NAME_TRAITS_IN_LIST':
          return literal(
            arg
                .split(',')
                .map((id) => int.tryParse(id.trim()))
                .where(state.traits.contains)
                .map((id) => state.pack.traits[id]?.name ?? '')
                .where((n) => n.isNotEmpty)
                .join(', '),
          );
        case 'GET_ITEM_OF_SWITCH':
          return literal(
            state.pack.items[state.switchValue(arg)]?.name ?? 'something',
          );
      }
    }
    switch (name) {
      case 'GOLD_SUBJECT':
        return _subjectAt(state, state.switchValue('GOLD_SUN_SUBJECT'));
      case 'ENTERED_UNIV_NAME' || 'ENTERED_DEPART_NAME':
        final department =
            state.pack.admissions.departments[state.enrolledDepartment];
        if (department == null) return '';
        return literal(
          name == 'ENTERED_DEPART_NAME'
              ? department.name
              : state.pack.admissions.universities[department.universityId]
                        ?.name ??
                    '',
        );
      // A remedy already brewed is marked in the recipe choice.
      case 'IS_ALREADY_RED' || 'IS_ALREADY_GREEN' || 'IS_ALREADY_BLUE':
        return state.switchValue(name.substring(3)) == 1 ? '(Done)' : '';
      // With the Scouter in the bag, the sing-off choice shows its forecast.
      case 'IS_SING_WIN':
        if (state.itemCount(90021) == 0) return '';
        return state.switchValue('SING_COUNT') >=
                state.switchValue('SING_TARGET')
            ? '(Scouter: you will win)'
            : '(Scouter: you will lose)';
      // Not recoverable from the data; drop the marker rather than show it.
      case 'IS_OK_RED' || 'IS_OK_GREEN' || 'IS_OK_BLUE':
        return '';
    }
    return variables[name] ?? match[0]!;
  });
}

const _subjectNames = {
  'korean': 'Korean',
  'math': 'Maths',
  'english': 'English',
  'science': 'Science',
  'society': 'Humanities',
};

String _subjectAt(GameState state, int index) {
  final subjects = state.pack.manifest.subjects;
  if (index < 0 || index >= subjects.length) return '';
  final s = subjects[index];
  return _subjectNames[s] ?? s;
}
