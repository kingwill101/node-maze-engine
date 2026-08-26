import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/level.dart';
import 'package:node/scripting/lua_level_loader.dart';

void main() {
  test('loads the production level and tuning from Lua', () async {
    final source = await File('assets/lua/level.lua').readAsString();

    final level = await LuaLevelLoader().load(
      source,
      scriptPath: 'assets/lua/level.lua',
    );

    expect(level.name, 'Neon Junction');
    expect(level.maze.width, 13);
    expect(level.maze.height, 9);
    expect(level.tuning.playerSpeed, 4);
    expect(level.tuning.ghostSpeed, 2.5);
    expect(level.tuning.bonusPoints, 1000);
  });

  test('loads a multi-level story campaign and camera modes', () async {
    final source = await File('assets/lua/level.lua').readAsString();

    final campaign = await LuaLevelLoader().loadCampaign(source);

    expect(campaign.name, 'Neon Rift Tour');
    expect(campaign.levels, hasLength(7));
    expect(campaign.levels[1].maze.width, 25);
    expect(campaign.levels[2].maze.width, 35);
    expect(campaign.levels[2].cameraMode.name, 'firstPerson');
    expect(campaign.levels[2].autoRun, isTrue);
    expect(campaign.levels[2].events, hasLength(3));
    expect(campaign.levels[4].cameraMode, CameraMode.platformer);
  });

  test('loads Node Maze and Moonfall as separate games', () async {
    final source = await File('assets/lua/level.lua').readAsString();

    final catalog = await LuaLevelLoader().loadCatalog(source);

    expect(catalog.name, 'Node Game Center');
    expect(catalog.games.map((game) => game.id), [
      'node_maze',
      'moonfall_courier',
    ]);
    expect(catalog.games.first.campaign.levels, hasLength(4));
    expect(catalog.games.last.campaign.levels, hasLength(3));
    expect(
      catalog.games.last.campaign.levels.every(
        (level) => level.cameraMode == CameraMode.platformer,
      ),
      isTrue,
    );
    expect(
      catalog.games.last.campaign.levels.map((level) => level.maze.width),
      [76, 106, 136],
    );
  });

  test(
    'Lua generator is deterministic and produces a connected maze',
    () async {
      final source = await File('assets/lua/level.lua').readAsString();
      final loader = LuaLevelLoader();

      final first = (await loader.loadCampaign(source)).levels[3].maze;
      final second = (await loader.loadCampaign(source)).levels[3].maze;

      expect(first.rows, second.rows);
      expect(first.width, 31);
      expect(first.height, 21);

      (int, int)? start;
      var traversable = 0;
      for (var y = 0; y < first.height; y++) {
        for (var x = 0; x < first.width; x++) {
          if (!first.isWall(x, y)) traversable++;
          if (first.rows[y][x] == 'P') start = (x, y);
        }
      }
      final visited = <(int, int)>{start!};
      final pending = <(int, int)>[start];
      while (pending.isNotEmpty) {
        final current = pending.removeLast();
        for (final delta in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final next = (current.$1 + delta.$1, current.$2 + delta.$2);
          if (!first.isWall(next.$1, next.$2) && visited.add(next)) {
            pending.add(next);
          }
        }
      }

      expect(visited, hasLength(traversable));
    },
  );

  test('rejects malformed scripted levels before world creation', () async {
    const source = '''
      return {
        maze = { '###', '#P#', '##' },
      }
    ''';

    expect(
      () => LuaLevelLoader().load(source),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a spawn with no exit', () async {
    const source = '''
      return { maze = { '#####', '#A###', '##P##', '#####' } }
    ''';

    expect(
      () => LuaLevelLoader().load(source),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('open exit'),
        ),
      ),
    );
  });

  test('rejects unpaired portals', () async {
    const source = '''
      return { maze = { '#####', '#PAT#', '#...#', '#####' } }
    ''';

    expect(
      () => LuaLevelLoader().load(source),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('zero or two'),
        ),
      ),
    );
  });
}
