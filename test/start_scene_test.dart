import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/level.dart';
import 'package:node/game/maze.dart';
import 'package:node/main.dart';

void main() {
  final campaign = LevelCampaign(
    name: 'Test Realms',
    levels: [
      LevelDefinition(
        name: 'First Realm',
        story: 'The first story.',
        maze: Maze(const ['#####', '#PA.#', '#####']),
      ),
      LevelDefinition(
        name: 'Second Realm',
        story: 'The second story.',
        objective: 'Find the test beacon',
        cameraMode: CameraMode.firstPerson,
        events: const [LevelEventDefinition(message: 'A test event')],
        maze: Maze(const ['#####', '#P.A#', '#####']),
      ),
    ],
  );

  testWidgets('start scene selects and launches a campaign map', (
    tester,
  ) async {
    int? launched;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: StartScene(
          campaign: campaign,
          onStart: (index) => launched = index,
        ),
      ),
    );

    expect(find.text('FIRST REALM'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('SECOND REALM'), findsWidgets);
    expect(find.text('CORRIDOR START'), findsOneWidget);
    expect(find.text('1 STORY EVENTS'), findsOneWidget);

    await tester.tap(find.text('ENTER THE MAZE'));
    expect(launched, 1);
  });
}
