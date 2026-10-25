import 'pack_mechanics.dart';
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
    if (state.pack.mechanics.section('textMacros').containsKey(name)) {
      return literal(
        '${MechanicRuntime(state).value(state.pack.mechanics.section('textMacros')[name]) ?? ''}',
      );
    }
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
      case 'ENTERED_UNIV_NAME' || 'ENTERED_DEPART_NAME':
        final department =
            state.pack.admissions.departments[state.enrolledDepartment];
        if (department == null) return '';
        return literal(
          name == 'ENTERED_DEPART_NAME'
              ? department.name
              : state
                        .pack
                        .admissions
                        .universities[department.universityId]
                        ?.name ??
                    '',
        );
    }
    return variables[name] ?? match[0]!;
  });
}

String _subjectAt(GameState state, int index) {
  final subjects = state.pack.manifest.subjects;
  if (index < 0 || index >= subjects.length) return '';
  final s = subjects[index];
  final labels =
      state.pack.mechanics.section('bindings')['subjectLabels'] as Map? ??
      const {};
  return labels[s]?.toString() ?? s;
}
