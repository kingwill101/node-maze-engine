import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/components.dart';
import 'package:node/game/maze_game.dart';
import 'package:node/platformer/platformer_components.dart';
import 'package:node/scripting/lua_game_package_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog discovers independently packaged Lua games', () async {
    final catalog = await const LuaGamePackageLoader().load(rootBundle);

    expect(catalog.games.map((game) => game.id), [
      'node_maze',
      'moonfall_courier',
      'signal_garden',
      'brasscap_run',
    ]);
    final garden = catalog.games[2];
    expect(garden.autoloadPath, 'assets/games/signal_garden/autoload.lua');
    expect(garden.behaviorPath, 'assets/games/signal_garden/sentinel.lua');
    expect(garden.prefabPath, 'assets/games/signal_garden/prefabs.lua');
  });

  test(
    'third game boots its own Lua package without engine branches',
    () async {
      final catalog = await const LuaGamePackageLoader().load(rootBundle);
      final garden = catalog.games[2];
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

  test('independent 2.5D package builds gameplay entirely from Lua', () async {
    final catalog = await const LuaGamePackageLoader().load(rootBundle);
    final brasscap = catalog.games.singleWhere(
      (game) => game.id == 'brasscap_run',
    );
    final game = MazeGame(level: brasscap.campaign.levels.first);
    await game.loadGameScripts(
      autoloadSource: await rootBundle.loadString(brasscap.autoloadPath),
      ghostSource: '',
      prefabSource: await rootBundle.loadString(brasscap.prefabPath),
    );

    final world = game.runtime.context.world;
    expect(brasscap.playerRenderer, 'script');
    expect(brasscap.platformEnvironment, 'bright');
    expect(
      world.query<ScriptComponents>().where(
        (entry) => entry.$2.values.containsKey('platform'),
      ),
      hasLength(16),
    );
    expect(
      world.query<ScriptComponents>().where(
        (entry) => entry.$2.values.containsKey('gear_coin'),
      ),
      hasLength(14),
    );
    final playerDrawings = world.get<ScriptDrawings>(game.player).values;
    expect(playerDrawings.keys, contains('cap'));
    final boot = playerDrawings['boot_left']!;
    final body = world.get<PlatformerBody>(game.player);
    expect(boot.y - boot.scaleY, closeTo(-body.halfHeight, .0001));

    game.setPlatformerAxis(1);
    for (var frame = 0; frame < 12; frame++) {
      game.advance(.05);
      await Future<void>.delayed(Duration.zero);
    }
    expect(world.get<Transform3>(game.player).x, greaterThan(3));

    for (final path in [
      'lib/main.dart',
      'lib/game/maze_game.dart',
      'lib/scripting/lua_behavior_runtime.dart',
    ]) {
      expect(await File(path).readAsString(), isNot(contains('brasscap_run')));
    }
  });
}
