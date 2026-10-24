/// Who is on screen during an event.
///
/// `standingId` is the actor; `speakerId` only names the chip. Five NPCs in
/// the campaign answer to some form of "Friend", so confusing the two swaps
/// the art mid-conversation.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:d30mode/engine/content_source.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/engine/pack.dart';

void main() {
  late ContentPack pack;
  setUpAll(() async {
    pack = await ContentSource.loadFromDirectory(Directory('packs/kss16'));
  });

  test('a line without a standing keeps the actor it was given', () {
    final game = Game.newRun(pack);
    // Master of Massages opens with standingId 8 on a line spoken by
    // speaker 1 — a different NPC who is also called "Friend".
    final event = pack.events[55]!;
    final run = game.events.begin(event, game.state);

    expect(run.current!.speakerName, 'Friend');
    expect(run.portraitId, 8, reason: 'the standing on the opening line');

    run.advance();
    expect(run.current!.text, contains('massage'));
    expect(
      run.portraitId,
      8,
      reason: 'this line carries no standing, so the actor must not change',
    );

    // And on through the player's line and the untagged ones after it.
    run.advance();
    expect(run.current!.speakerName, 'Me');
    expect(run.portraitId, 8);
    run.advance();
    expect(run.portraitId, 8);
  });
}
