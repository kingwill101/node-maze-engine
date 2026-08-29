import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/components.dart';
import 'package:node/game/maze_game.dart';
import 'package:node/scripting/lua_game_package_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog discovers independently packaged Lua games', () async {
    final catalog = await const LuaGamePackageLoader().load(rootBundle);

    expect(catalog.games.map((game) => game.id), [
      'node_maze',
      'moonfall_courier',
      'signal_garden',
    ]);
    final garden = catalog.games.last;
    expect(garden.autoloadPath, 'assets/games/signal_garden/autoload.lua');
    expect(garden.behaviorPath, 'assets/games/signal_garden/sentinel.lua');
    expect(garden.prefabPath, 'assets/games/signal_garden/prefabs.lua');
  });

  test(
    'third game boots its own Lua package without engine branches',
    () async {
      final catalog = await const LuaGamePackageLoader().load(rootBundle);
      final garden = catalog.games.last;
      final game = MazeGame(level: garden.campaign.levels.single);
      await game.loadGameScripts(
        autoloadSource: await rootBundle.loadString(garden.autoloadPath),
        ghostSource: await rootBundle.loadString(garden.behaviorPath!),
        prefabSource: await rootBundle.loadString(garden.prefabPath),
      );

      expect(
        game.runtime.context.world
            .get<ScriptProperties>(game.session)
            .values['package_id'],
        'signal_garden',
      );
      expect(
        game.runtime.context.world
            .get<ScriptHud>(game.session)
            .elements['package']
            ?.text,
        'SIGNAL GARDEN · LUA PACKAGE',
      );
      expect(game.sceneTree.getNode('/root/signal_flower')?.id, greaterThan(0));

      for (final path in [
        'lib/main.dart',
        'lib/game/maze_game.dart',
        'lib/scripting/lua_behavior_runtime.dart',
      ]) {
        expect(
          await File(path).readAsString(),
          isNot(contains('signal_garden')),
        );
      }
    },
  );
}
