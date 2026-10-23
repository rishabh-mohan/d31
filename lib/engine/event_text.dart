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
  return source.replaceAllMapped(
    RegExp(r'\{([^{}]+)\}'),
    (match) => variables[match[1]] ?? match[0]!,
  );
}
