import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/components.dart';
import 'package:node/game/level.dart';
import 'package:node/game/maze.dart';
import 'package:node/game/maze_game.dart';
import 'package:node/scripting/lua_level_loader.dart';

void main() {
  test('Lua projectile simulation damages the player and expires', () {
    final game = MazeGame();
    final player = game.runtime.context.world.get<Transform3>(game.player);
    final bolt = game.runtime.context.world.create([
      Transform3(player.x, .25, player.z),
      ScriptVelocity(0, 0, 0, remainingSeconds: 1),
      const ScriptProjectileTag(),
    ]);

    game.advance(.05);

    expect(game.lives, 2);
    expect(game.state.announcement, contains('WARDEN'));
    expect(game.runtime.context.world.isAlive(bolt), isFalse);
  });

  test('Dreamseed autoload spawns a phased boss and aimed bolts', () async {
    final game = MazeGame(
      level: LevelDefinition(
        name: 'Dreamseed 7331',
        maze: Maze(const [
          '#######',
          '#.....#',
          '#.P.A.#',
          '#.....#',
          '#######',
        ]),
      ),
    );
    await game.loadGameScripts(
      autoloadSource: await File('assets/lua/autoload.lua').readAsString(),
      ghostSource: '',
      prefabSource: await File('assets/lua/prefabs.lua').readAsString(),
    );

    final bosses = game.runtime.context.world
        .query<ScriptComponents>()
        .where((entry) => entry.$2.values.containsKey('boss'))
        .toList();
    expect(bosses, hasLength(1));
    expect(
      game.runtime.context.world
          .get<ScriptProperties>(bosses.single.$1)
          .values['state'],
      'awakening',
    );

    for (var frame = 0; frame < 10; frame++) {
      game.advance(.25);
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      game.runtime.context.world.query<ScriptComponents>().where(
        (entry) => entry.$2.values.containsKey('projectile'),
      ),
      isNotEmpty,
    );
  });

  test(
    'Lua-authored platformer builds platforms and simulates a jump',
    () async {
      final campaign = await LuaLevelLoader().loadCampaign(
        await File('assets/lua/level.lua').readAsString(),
      );
      final game = MazeGame(level: campaign.levels[4]);
      await game.loadGameScripts(
        autoloadSource: await File('assets/lua/autoload.lua').readAsString(),
        ghostSource: await File('assets/lua/ghost.lua').readAsString(),
        prefabSource: await File('assets/lua/prefabs.lua').readAsString(),
      );

      expect(game.level.cameraMode, CameraMode.platformer);
      expect(
        game.runtime.context.world.query<ScriptComponents>().where(
          (entry) => entry.$2.values.containsKey('platform'),
        ),
        hasLength(4),
      );
      expect(
        game.runtime.context.world.get<ScriptComponents>(game.player).values,
        contains('platformer_player'),
      );
      expect(
        game.runtime.context.world.get<ScriptComponents>(game.player).values,
        contains('character_animation'),
      );
      expect(game.scripts.length, 1);

      for (var frame = 0; frame < 8; frame++) {
        game.advance(.05);
        await Future<void>.delayed(Duration.zero);
      }
      final player = game.runtime.context.world.get<Transform3>(game.player);
      final groundedY = player.y;
      game.setPlatformerAxis(1);
      game.requestPlatformerJump();
      for (var frame = 0; frame < 16; frame++) {
        game.advance(.05);
        await Future<void>.delayed(Duration.zero);
      }

      expect(player.x, greaterThan(2));
      expect(player.y, greaterThan(groundedY));
      expect(game.runtime.context.world.query<BonusFruitTag>(), isEmpty);
      expect(game.score, greaterThanOrEqualTo(250));
      expect(
        game.runtime.context.world
            .get<ScriptComponents>(game.player)
            .values['character_animation']?['state'],
        isIn(['run', 'jump', 'fall']),
      );
    },
  );

  test('Lua opens a blocking door when the player collects a key', () async {
    final game = MazeGame(maze: Maze(const ['#######', '#PK|A.#', '#######']));
    await game.loadGameScripts(
      autoloadSource: await File('assets/lua/autoload.lua').readAsString(),
      ghostSource: '',
      prefabSource: await File('assets/lua/prefabs.lua').readAsString(),
    );
    final door = game.runtime.context.world.query<DoorTag>().single.$2;
    expect(door.open, isFalse);

    game.requestMove(MoveDirection.right);
    game.advance(.25);
    await Future<void>.delayed(Duration.zero);
    game.advance(1 / 60);
    await Future<void>.delayed(Duration.zero);

    expect(game.state.keys, 1);
    expect(door.open, isTrue);
  });

  test('rift traps damage the player and enter cooldown', () {
    final game = MazeGame(maze: Maze(const ['#######', '#P^..A#', '#######']));
    game.runtime.context.world.get<Transform3>(game.player).x = 2;

    game.advance(1 / 60);

    expect(game.lives, 2);
    expect(
      game.runtime.context.world.query<TrapTag>().single.$2.cooldown,
      greaterThan(0),
    );
  });

  test('player bolts reset ghosts and award points', () {
    final game = MazeGame(
      maze: Maze(const ['#######', '#..A..#', '#..P..#', '#######']),
    );
    game.firePlayerBolt();
    for (var frame = 0; frame < 12; frame++) {
      game.advance(1 / 60);
    }

    expect(game.score, 150);
    expect(game.runtime.context.world.query<ScriptProjectileTag>(), isEmpty);
  });

  test('player moves through open maze tiles', () {
    final game = MazeGame();
    final start = game.runtime.context.world.get<Transform3>(game.player).x;
    game.requestMove(MoveDirection.left);
    for (var i = 0; i < 15; i++) {
      game.advance(1 / 60);
    }
    expect(
      game.runtime.context.world.get<Transform3>(game.player).x,
      lessThan(start),
    );
  });

  test('player cannot move into a wall', () {
    final game = MazeGame();
    final start = game.runtime.context.world.get<Transform3>(game.player).z;
    game.requestMove(MoveDirection.down);
    for (var i = 0; i < 15; i++) {
      game.advance(1 / 60);
    }
    expect(game.runtime.context.world.get<Transform3>(game.player).z, start);
  });

  test('Lua ghost behavior requests maze-safe movement', () async {
    final game = MazeGame();
    final start = game.runtime.context.world.get<Transform3>(game.ghost).x;
    await game.loadGhostBehavior('''
      function fixed_update(entity, delta)
        entity_request_move(entity, 'right')
      end
    ''');

    for (var i = 0; i < 20; i++) {
      game.advance(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      game.runtime.context.world.get<Transform3>(game.ghost).x,
      greaterThan(start),
    );
  });

  test('ghost contact costs a life and respawns both actors', () {
    final game = MazeGame();
    final player = game.runtime.context.world.get<Transform3>(game.player);
    final ghost = game.runtime.context.world.get<Transform3>(game.ghost)
      ..x = player.x
      ..z = player.z;

    game.advance(1 / 60);

    expect(game.lives, 2);
    expect(player.x, 6);
    expect(player.z, 5);
    expect(ghost.x, 1);
    expect(ghost.z, 3);
  });

  test('power pellet starts frightened mode and awards bonus points', () {
    final game = MazeGame();
    final pelletsBefore = game.state.pelletsRemaining;
    final player = game.runtime.context.world.get<Transform3>(game.player)
      ..x = 1
      ..z = 1;

    game.advance(1 / 60);

    expect(game.score, 50);
    expect(game.state.powerSeconds, greaterThan(6));
    expect(game.state.pelletsRemaining, pelletsBefore - 1);
    expect(player.x, 1);
  });

  test('frightened ghost awards points instead of costing a life', () {
    final game = MazeGame();
    final player = game.runtime.context.world.get<Transform3>(game.player);
    final ghost = game.runtime.context.world.get<Transform3>(game.ghost)
      ..x = player.x
      ..z = player.z;
    game.state.powerSeconds = 2;

    game.advance(1 / 60);

    expect(game.lives, 3);
    expect(game.score, 200);
    expect(ghost.x, 1);
    expect(ghost.z, 3);
  });

  test('collecting the final pellet completes the maze', () {
    final game = MazeGame();
    game.state.pelletsRemaining = 1;
    game.runtime.context.world.get<Transform3>(game.player)
      ..x = 1
      ..z = 1;

    game.advance(1 / 60);

    expect(game.phase, GamePhase.won);
    expect(game.state.pelletsRemaining, 0);
  });

  test('world spawns four data-driven ghost personalities', () {
    final game = MazeGame();
    final profiles = game.runtime.context.world
        .query<GhostProfile>()
        .map((entry) => entry.$2.personality)
        .toSet();

    expect(game.ghosts, hasLength(4));
    expect(profiles, {'chaser', 'ambusher', 'shy', 'patrol'});
  });

  test('production Lua script drives every ghost runtime', () async {
    final game = MazeGame();
    final source = await File('assets/lua/ghost.lua').readAsString();
    await game.loadGhostBehaviors(source);

    for (var i = 0; i < 8; i++) {
      game.advance(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }

    for (final ghost in game.ghosts) {
      expect(
        game.runtime.context.world.get<GridMover>(ghost).requested,
        isNot(MoveDirection.none),
      );
    }
  });

  test('autoload bootstraps the default scene and stable node paths', () async {
    final game = MazeGame();
    final autoload = await File('assets/lua/autoload.lua').readAsString();
    final ghosts = await File('assets/lua/ghost.lua').readAsString();

    await game.loadGameScripts(
      autoloadSource: autoload,
      ghostSource: ghosts,
      prefabSource: await File('assets/lua/prefabs.lua').readAsString(),
    );

    expect(game.sceneTree.getNode('/root'), game.session);
    expect(game.sceneTree.getNode('player'), game.player);
    expect(game.sceneTree.getNode('/root/enemies/Ruby'), game.ghosts.first);
    expect(game.scripts.length, 5);
    expect(
      game.runtime.context.world
          .get<ScriptProperties>(game.session)
          .values['bootstrapped'],
      isTrue,
    );
    expect(
      game.runtime.context.world
          .get<ScriptProperties>(game.player)
          .values['scene_ready'],
      isTrue,
    );
    expect(
      game.runtime.context.world
          .get<ScriptHud>(game.session)
          .elements['status']!
          .text,
      'LUA HUD INITIALIZING',
    );

    game.advance(1 / 60);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      game.runtime.context.world
          .get<ScriptHud>(game.session)
          .elements['status']!
          .text,
      contains('LIVES 3'),
    );
  });

  test('bonus fruit spawns halfway through the pellet count and expires', () {
    final game = MazeGame();
    game.state.pelletsRemaining = game.state.pelletsTotal ~/ 2;

    game.advance(1 / 60);

    expect(game.state.bonusSpawned, isTrue);
    expect(game.state.bonusSeconds, 10);
    expect(game.runtime.context.world.query<BonusFruitTag>(), hasLength(1));

    for (var i = 0; i < 41; i++) {
      game.advance(.25);
    }

    expect(game.state.bonusSeconds, 0);
    expect(game.runtime.context.world.query<BonusFruitTag>(), isEmpty);
  });

  test('collecting the bonus fruit awards its score', () {
    final game = MazeGame();
    game.state.pelletsRemaining = game.state.pelletsTotal ~/ 2;
    game.advance(1 / 60);
    final fruit = game.runtime.context.world
        .query2<Transform3, BonusFruitTag>()
        .first
        .$2;
    game.runtime.context.world.get<Transform3>(game.player)
      ..x = fruit.x
      ..z = fruit.z;

    game.advance(1 / 60);

    expect(game.score, greaterThanOrEqualTo(1000));
    expect(game.state.bonusSeconds, 0);
    expect(game.runtime.context.world.query<BonusFruitTag>(), isEmpty);
  });

  test('frightened ghost captures escalate the combo score', () {
    final game = MazeGame();
    final player = game.runtime.context.world.get<Transform3>(game.player);
    final first = game.runtime.context.world.get<Transform3>(game.ghosts[0])
      ..x = player.x
      ..z = player.z;
    game.state.powerSeconds = 5;
    game.advance(1 / 60);
    expect(first.x, 1);

    game.advance(.25);
    game.advance(.25);
    game.runtime.context.world.get<Transform3>(game.ghosts[1])
      ..x = player.x
      ..z = player.z;
    game.advance(1 / 60);

    expect(game.score, 600);
    expect(game.state.ghostCombo, 2);
  });

  test('scripted story events react to elapsed time', () {
    final level = LevelDefinition(
      name: 'Event test',
      maze: Maze.demo,
      events: const [
        LevelEventDefinition(
          message: 'The gate opens',
          afterSeconds: .1,
          scoreBonus: 75,
        ),
      ],
    );
    final game = MazeGame(level: level);

    game.advance(.2);

    expect(game.state.announcement, 'The gate opens');
    expect(game.state.announcementSeconds, greaterThan(0));
    expect(game.score, 75);
    expect(game.state.firedLevelEvents, {0});
  });

  test('large worlds split wall geometry into streamable runs', () {
    final game = MazeGame(
      maze: Maze([
        '####################',
        '#P.A...............#',
        '####################',
      ]),
    );
    final runs = game.runtime.context.world.query<WallRun>().map(
      (entry) => entry.$2.length,
    );

    expect(runs.every((length) => length <= 8), isTrue);
    expect(runs.where((length) => length == 8), isNotEmpty);
  });

  test('first-person controls rotate facing independently of movement', () {
    final game = MazeGame();

    game.turnFirstPerson(1);
    expect(game.firstPersonFacing, MoveDirection.right);
    game.moveFirstPerson();
    expect(
      game.runtime.context.world.get<GridMover>(game.player).requested,
      MoveDirection.right,
    );

    game.turnFirstPerson(-1);
    expect(game.firstPersonFacing, MoveDirection.up);
    game.moveFirstPerson(backward: true);
    expect(
      game.runtime.context.world.get<GridMover>(game.player).requested,
      MoveDirection.down,
    );
  });

  test('first-person auto-run starts toward an open spawn exit', () {
    final game = MazeGame(
      level: LevelDefinition(
        name: 'Runner',
        cameraMode: CameraMode.firstPerson,
        autoRun: true,
        maze: Maze(const ['#####', '#P.A#', '#####']),
      ),
    );
    final start = game.runtime.context.world.get<Transform3>(game.player).x;

    expect(game.firstPersonFacing, MoveDirection.right);
    game.advance(.2);

    expect(
      game.runtime.context.world.get<Transform3>(game.player).x,
      greaterThan(start),
    );
  });

  test(
    'paired Lua portal tiles teleport the player through autoload',
    () async {
      final game = MazeGame(
        maze: Maze(const ['#######', '#PT..A#', '#..sT.#', '#######']),
      );
      final player = game.runtime.context.world.get<Transform3>(game.player)
        ..x = 2
        ..z = 1;
      await game.loadGameScripts(
        autoloadSource: await File('assets/lua/autoload.lua').readAsString(),
        ghostSource: '',
        prefabSource: await File('assets/lua/prefabs.lua').readAsString(),
      );

      game.advance(1 / 60);
      await Future<void>.delayed(Duration.zero);

      expect(player.x, 4);
      expect(player.z, 2);
    },
  );

  test('Star Pulse pickups grant a consumable frightened spell', () {
    final game = MazeGame(
      maze: Maze(const ['#######', '#P...A#', '#..s..#', '#######']),
    );
    game.runtime.context.world.get<Transform3>(game.player)
      ..x = 3
      ..z = 2;

    game.advance(1 / 60);
    expect(game.state.spellCharges, 1);

    game.castPulseSpell();
    expect(game.state.spellCharges, 0);
    expect(game.state.powerSeconds, greaterThan(0));
    expect(game.state.spellPulseSeconds, greaterThan(0));
  });
}
