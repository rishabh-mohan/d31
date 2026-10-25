import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/account_store.dart';
import 'package:d30mode/ui/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('haptics fire only when Rumble is on', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => AccountStore.current = Account());

    AccountStore.current = Account()..rumble = false;
    Haptics.collapse();
    Haptics.levelUp();
    Haptics.reveal();
    Haptics.stop();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    AccountStore.current = Account()..rumble = true;
    Haptics.collapse();
    Haptics.levelUp();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
  });
}
