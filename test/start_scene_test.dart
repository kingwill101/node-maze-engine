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

    await tester.tap(find.text('START CHAPTER'));
    expect(launched, 1);
  });

  testWidgets('game center selects Moonfall as a separate game', (
    tester,
  ) async {
    final catalog = GameCatalog(
      name: 'Node Game Center',
      games: [
        GameDefinition(
          id: 'node_maze',
          name: 'Node Maze',
          tagline: 'Maze game',
          campaign: campaign,
        ),
        GameDefinition(
          id: 'moonfall_courier',
          name: 'Moonfall Courier',
          tagline: 'Platformer',
          campaign: LevelCampaign(
            name: 'The Shattered Moon',
            levels: [
              LevelDefinition(
                gameId: 'moonfall_courier',
                name: 'Causeway',
                cameraMode: CameraMode.platformer,
                maze: Maze(const ['#####', '#PA.#', '#####']),
              ),
            ],
          ),
        ),
      ],
    );
    int? selectedGame;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: GameCenterScene(
          catalog: catalog,
          onSelect: (index) => selectedGame = index,
        ),
      ),
    );

    expect(find.text('NODE MAZE'), findsOneWidget);
    expect(find.text('MOONFALL COURIER'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN GAME'));

    expect(selectedGame, 1);
  });
}
