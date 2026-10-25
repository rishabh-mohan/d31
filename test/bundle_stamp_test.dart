import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';

/// TODO 73: an editable pack copy is re-seeded when the bundled pack changes,
/// so an APK update reaches the phone. The stamp is what detects the change.
void main() {
  test('the bundle stamp is stable and notices a changed rule', () {
    final files = {
      'pack.json': '{"id": "kss20"}',
      'rules.json': '{"setup": {"genderSelection": false}}',
      'events/events.json': 'x' * 200000,
    };
    final stamp = ContentSource.bundleStamp(files);
    expect(ContentSource.bundleStamp(Map.of(files)), stamp);
    final changed = {
      ...files,
      'rules.json': '{"setup": {"genderSelection": true}}',
    };
    expect(ContentSource.bundleStamp(changed), isNot(stamp));
    final grown = {...files, 'quizzes.json': '{}'};
    expect(ContentSource.bundleStamp(grown), isNot(stamp));
  });
}
