/// An event that ends on a scene with no text (as Pack Studio's generated events do)
/// closes after its last message instead of showing an empty dialogue window.
library;

import 'dart:convert';

import 'package:d30mode/engine/event_engine.dart';
import 'package:d30mode/engine/game.dart';
import 'package:d30mode/ui/event_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stamina_defaults_test.dart' show action, gameWith;

Game gameWithEvents(List<Map<String, dynamic>> events, List<Map<String, dynamic>> nodes) => gameWith(
  [action('study')],
  extraFiles: {'events/events.json': jsonEncode({'events': events, 'nodes': nodes})},
);

Map<String, dynamic> event(int id, int root) => {
  'id': id,
  'name': 'E$id',
  'rootNodeId': root,
  'isRandomDate': true,
  'priority': 'middle',
  'rank': 'C',
  'section': 'none',
};

Future<void> open(WidgetTester tester, EventRun run) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => EventScreen.show(context, run), child: const Text('open')),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a message then a textless ending closes after one tap, with no blank beat', (tester) async {
    final game = gameWithEvents(
      [event(1, 1001)],
      [
        {'id': 1001, 'type': 'text', 'speakerId': 0, 'text': 'You lost 10 stamina.', 'nextNodeId': 1002},
        {'id': 1002, 'type': 'last'},
      ],
    );
    final run = game.events.begin(game.pack.events[1]!, game.state);
    await open(tester, run);
    expect(find.text('You lost 10 stamina.'), findsOneWidget);
    expect(find.byType(EventScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(EventScreen), findsNothing); // closed, not an empty window
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a choice whose answer ends in a message then a textless ending also closes', (tester) async {
    final game = gameWithEvents(
      [event(2, 2001)],
      [
        {
          'id': 2001,
          'type': 'option',
          'text': 'Follow him?',
          'nextNodeId': 2003,
          'options': [
            {'text': 'Follow', 'nextNodeId': 2002},
          ],
        },
        {'id': 2002, 'type': 'text', 'speakerId': 0, 'text': 'You lost 10 stamina.', 'nextNodeId': 2003},
        {'id': 2003, 'type': 'last'},
      ],
    );
    final run = game.events.begin(game.pack.events[2]!, game.state);
    await open(tester, run);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(find.text('You lost 10 stamina.'), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(EventScreen), findsNothing);
  });

  testWidgets('an ending that has text is still shown', (tester) async {
    final game = gameWithEvents(
      [event(3, 3001)],
      [
        {'id': 3001, 'type': 'text', 'speakerId': 0, 'text': 'First.', 'nextNodeId': 3002},
        {'id': 3002, 'type': 'last', 'text': 'The end.'},
      ],
    );
    final run = game.events.begin(game.pack.events[3]!, game.state);
    await open(tester, run);
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('The end.'), findsOneWidget);
    expect(find.byType(EventScreen), findsOneWidget);
  });
}
