import '../engine/entity.dart';
import '../engine/runtime.dart';
import '../engine/scene_tree.dart';
import '../scripting/lua_behavior_scheduler.dart';
import '../scripting/lua_behavior_runtime.dart';
import 'components.dart';
import 'level.dart';
import 'maze.dart';

class MazeGame {
  MazeGame({Maze? maze, LevelDefinition? level})
    : level = level ?? LevelDefinition.defaultFor(maze ?? Maze.demo) {
    runtime.context.events.on<LuaSignal>(scripts.emitSignal);
    runtime.fixedSystems.add(_MovementSystem(this.maze));
    runtime.fixedSystems.add(_DungeonInteractionSystem(sceneTree));
    runtime.fixedSystems.add(_PortalSystem());
    runtime.fixedSystems.add(_PelletSystem(this.level.tuning));
    runtime.fixedSystems.add(_SpellSystem());
    runtime.fixedSystems.add(_ScriptProjectileSystem(this.maze, sceneTree));
    runtime.fixedSystems.add(_BonusFruitSystem(this.level));
    runtime.fixedSystems.add(_LevelEventSystem(this.level));
    runtime.fixedSystems.add(_ScriptSceneStateSystem(this.level));
    runtime.fixedSystems.add(_GhostCollisionSystem());
    _buildWorld();
    if (this.level.cameraMode == CameraMode.firstPerson) {
      _initializeFirstPersonFacing();
    }
  }

  final LevelDefinition level;
  Maze get maze => level.maze;
  final EngineRuntime runtime = EngineRuntime();
  final SceneTree sceneTree = SceneTree();
  late final Entity session;
  late final Entity player;
  final List<Entity> ghosts = [];
  final LuaBehaviorScheduler scripts = LuaBehaviorScheduler();
  MoveDirection firstPersonFacing = MoveDirection.up;

  GameState get state => runtime.context.world.get<GameState>(session);
  int get score => state.score;
  int get lives => state.lives;
  GamePhase get phase => state.phase;
  Entity get ghost => ghosts.first;

  void _buildWorld() {
    final portalPositions = <(double, double)>[];
    session = runtime.context.world.create([
      GameState(),
      ScriptProperties({'scene_name': level.name}),
      ScriptGroups(['autoload', 'scene']),
    ]);
    sceneTree.register('/root', session);
    for (var y = 0; y < maze.height; y++) {
      for (var x = 0; x < maze.width; x++) {
        switch (maze.rows[y][x]) {
          case '#':
            break;
          case '.':
            runtime.context.world.create([
              Transform3(x.toDouble(), .35, y.toDouble()),
              const PelletTag(),
            ]);
            state.pelletsRemaining++;
          case 'o':
            runtime.context.world.create([
              Transform3(x.toDouble(), .35, y.toDouble()),
              const PelletTag(power: true),
            ]);
            state.pelletsRemaining++;
          case 's':
            runtime.context.world.create([
              Transform3(x.toDouble(), .4, y.toDouble()),
              const SpellPickupTag(),
            ]);
          case 'K':
            final key = runtime.context.world.create([
              Transform3(x.toDouble(), .35, y.toDouble()),
              const KeyPickupTag(),
              ScriptGroups(['keys', 'interactables']),
            ]);
            sceneTree.register('/root/keys/${key.id}', key);
          case '|':
            final door = runtime.context.world.create([
              Transform3(x.toDouble(), 0, y.toDouble()),
              DoorTag(),
              ScriptProperties({'open': false}),
              ScriptGroups(['doors', 'interactables']),
            ]);
            sceneTree.register('/root/doors/${door.id}', door);
          case '^':
            final trap = runtime.context.world.create([
              Transform3(x.toDouble(), .01, y.toDouble()),
              TrapTag(),
              ScriptProperties({'active': true}),
              ScriptGroups(['traps', 'interactables']),
            ]);
            sceneTree.register('/root/traps/${trap.id}', trap);
          case 'T':
            portalPositions.add((x.toDouble(), y.toDouble()));
          case 'P':
            player = runtime.context.world.create([
              Transform3(x.toDouble(), .45, y.toDouble()),
              SpawnPoint(x.toDouble(), y.toDouble()),
              GridMover(speed: level.tuning.playerSpeed),
              const PlayerTag(),
              ScriptProperties({'spell': 'none'}),
              ScriptGroups(['player', 'actors']),
            ]);
            sceneTree.register('/root/player', player);
          case 'A' || 'B' || 'C' || 'D':
            final profiles = <String, (String, String)>{
              'A': ('Ruby', 'chaser'),
              'B': ('Saffron', 'ambusher'),
              'C': ('Iris', 'shy'),
              'D': ('Mint', 'patrol'),
            };
            final profile = profiles[maze.rows[y][x]]!;
            ghosts.add(
              runtime.context.world.create([
                Transform3(x.toDouble(), .45, y.toDouble()),
                SpawnPoint(x.toDouble(), y.toDouble()),
                GridMover(speed: level.tuning.ghostSpeed),
                const GhostTag(),
                GhostProfile(name: profile.$1, personality: profile.$2),
                ScriptProperties({
                  'display_name': profile.$1,
                  'personality': profile.$2,
                  'state': 'spawning',
                  'aggression': switch (profile.$2) {
                    'chaser' => 1.0,
                    'ambusher' => .8,
                    'shy' => .45,
                    _ => .6,
                  },
                }),
                ScriptGroups(['enemies', 'ghosts', profile.$2]),
              ]),
            );
            sceneTree.register('/root/enemies/${profile.$1}', ghosts.last);
        }
      }
    }
    if (portalPositions.length == 2) {
      for (var index = 0; index < 2; index++) {
        final source = portalPositions[index];
        final destination = portalPositions[1 - index];
        final portal = runtime.context.world.create([
          Transform3(source.$1, .02, source.$2),
          PortalTag(destination.$1, destination.$2),
        ]);
        sceneTree.register('/root/portals/${index + 1}', portal);
      }
    }
    _buildWallRuns();
    state.pelletsTotal = state.pelletsRemaining;
  }

  void _buildWallRuns() {
    const maxRunLength = 8;
    for (var y = 0; y < maze.height; y++) {
      var x = 0;
      while (x < maze.width) {
        if (!maze.isWall(x, y)) {
          x++;
          continue;
        }
        final start = x;
        while (x + 1 < maze.width &&
            maze.isWall(x + 1, y) &&
            x - start + 1 < maxRunLength) {
          x++;
        }
        final length = x - start + 1;
        runtime.context.world.create([
          Transform3(start + (length - 1) / 2, 0, y.toDouble()),
          WallRun(length),
        ]);
        x++;
      }
    }
  }

  void requestMove(MoveDirection direction) {
    if (phase != GamePhase.playing) return;
    runtime.context.world.get<GridMover>(player).requested = direction;
  }

  void turnFirstPerson(int quarterTurns) {
    const compass = [
      MoveDirection.up,
      MoveDirection.right,
      MoveDirection.down,
      MoveDirection.left,
    ];
    final current = compass.indexOf(firstPersonFacing);
    firstPersonFacing = compass[(current + quarterTurns) % compass.length];
    if (level.autoRun) moveFirstPerson();
  }

  void moveFirstPerson({bool backward = false}) {
    final direction = backward
        ? _opposite(firstPersonFacing)
        : firstPersonFacing;
    requestMove(direction);
  }

  void enterFirstPerson() {
    final mover = runtime.context.world.get<GridMover>(player);
    if (mover.direction != MoveDirection.none &&
        canEntityMove(player, mover.direction)) {
      firstPersonFacing = mover.direction;
    } else {
      _initializeFirstPersonFacing();
    }
  }

  void stopPlayer() {
    if (level.autoRun) return;
    final mover = runtime.context.world.get<GridMover>(player);
    mover
      ..direction = MoveDirection.none
      ..requested = MoveDirection.none;
  }

  void castPulseSpell() {
    if (phase != GamePhase.playing || state.spellCharges == 0) return;
    state.spellCharges--;
    state
      ..powerSeconds = level.tuning.powerSeconds * .65
      ..spellPulseSeconds = .8
      ..ghostCombo = 0
      ..announcement = 'STAR PULSE — THE HUNTERS RECOIL'
      ..announcementSeconds = 2.5;
    runtime.context.events.emit(const SpellCast());
    scripts.emitSignal(
      LuaSignal(name: 'player_cast_spell', source: player.id, payload: 'pulse'),
    );
  }

  void firePlayerBolt({bool useFirstPersonFacing = false}) {
    if (phase != GamePhase.playing) return;
    final transform = runtime.context.world.get<Transform3>(player);
    final mover = runtime.context.world.get<GridMover>(player);
    final direction = useFirstPersonFacing
        ? firstPersonFacing
        : (mover.direction == MoveDirection.none
              ? firstPersonFacing
              : mover.direction);
    final bolt = runtime.context.world.create([
      Transform3(transform.x, .3, transform.z),
      ScriptVelocity(
        direction.dx * 7,
        0,
        direction.dy * 7,
        remainingSeconds: 2.5,
      ),
      const ScriptProjectileTag(hurtsPlayer: false),
      ScriptGroups(['player_projectiles', 'script_spawned']),
      ScriptDrawings(),
      ScriptParticleEmitters(),
    ]);
    runtime.context.world.get<ScriptDrawings>(bolt).values['bolt'] =
        ScriptDrawing(
            name: 'bolt',
            shape: ScriptPrimitiveShape.sphere,
            x: 0,
            y: 0,
            z: 0,
            scaleX: .14,
            scaleY: .14,
            scaleZ: .14,
            color: '#31e7ff',
          )
          ..animation = 'pulse'
          ..animationSpeed = 12
          ..animationAmount = .3;
    runtime.context.world
        .get<ScriptParticleEmitters>(bolt)
        .values['trail'] = ScriptParticleEmitter(
      name: 'trail',
      count: 10,
      radius: .65,
      speed: 4,
      size: .045,
      color: '#31e7ff',
      pattern: 'trail',
    );
    sceneTree.register('/root/projectiles/player_${bolt.id}', bolt);
    scripts.emitSignal(
      LuaSignal(name: 'player_fired', source: player.id, payload: bolt.id),
    );
  }

  void _initializeFirstPersonFacing() {
    const preferred = [
      MoveDirection.up,
      MoveDirection.right,
      MoveDirection.down,
      MoveDirection.left,
    ];
    firstPersonFacing = preferred.firstWhere(
      (direction) => canEntityMove(player, direction),
      orElse: () => MoveDirection.up,
    );
    if (level.autoRun) moveFirstPerson();
  }

  Future<void> loadGhostBehaviors(String source) async {
    scripts.clear();
    for (final ghost in ghosts) {
      final script = _createGhostRuntime();
      await scripts.attach(
        entity: ghost,
        runtime: script,
        source: source,
        scriptPath: 'assets/lua/ghost.lua',
      );
    }
  }

  Future<void> loadGameScripts({
    required String autoloadSource,
    required String ghostSource,
  }) async {
    scripts.clear();
    await scripts.attach(
      entity: session,
      runtime: _createScriptRuntime(),
      source: autoloadSource,
      scriptPath: 'assets/lua/autoload.lua',
    );
    for (final ghost in ghosts) {
      await scripts.attach(
        entity: ghost,
        runtime: _createGhostRuntime(),
        source: ghostSource,
        scriptPath: 'assets/lua/ghost.lua',
      );
    }
  }

  LuaBehaviorRuntime _createScriptRuntime() => LuaBehaviorRuntime(
    runtime.context,
    canMove: canEntityMove,
    player: player,
    isPowerActive: () => state.powerSeconds > 0,
    emitSignal: scripts.emitSignal,
    sceneTree: sceneTree,
  );

  Future<void> loadGhostBehavior(String source) async {
    final script = _createGhostRuntime();
    scripts.clear();
    await scripts.attach(
      entity: ghost,
      runtime: script,
      source: source,
      scriptPath: 'assets/lua/ghost.lua',
    );
  }

  LuaBehaviorRuntime _createGhostRuntime() => LuaBehaviorRuntime(
    runtime.context,
    canMove: canEntityMove,
    player: player,
    personality: (entity) =>
        runtime.context.world.get<GhostProfile>(entity).personality,
    chooseDirection: chooseDirection,
    isPowerActive: () => state.powerSeconds > 0,
    emitSignal: scripts.emitSignal,
    sceneTree: sceneTree,
  );

  bool canEntityMove(Entity entity, MoveDirection direction) {
    final transform = runtime.context.world.get<Transform3>(entity);
    final x = transform.x.round() + direction.dx;
    final z = transform.z.round() + direction.dy;
    if (maze.isWall(x, z)) return false;
    return !runtime.context.world.query2<Transform3, DoorTag>().any(
      (entry) =>
          !entry.$3.open && entry.$2.x.round() == x && entry.$2.z.round() == z,
    );
  }

  MoveDirection chooseDirection(
    Entity entity,
    double targetX,
    double targetZ,
    bool flee,
  ) {
    final transform = runtime.context.world.get<Transform3>(entity);
    final mover = runtime.context.world.get<GridMover>(entity);
    var valid = MoveDirection.values
        .where(
          (direction) =>
              direction != MoveDirection.none &&
              canEntityMove(entity, direction),
        )
        .toList();
    final reverse = _opposite(mover.direction);
    if (valid.length > 1) {
      valid = valid.where((direction) => direction != reverse).toList();
    }
    if (valid.isEmpty) return reverse;
    double distance(MoveDirection direction) {
      final x = transform.x.round() + direction.dx;
      final z = transform.z.round() + direction.dy;
      return (x - targetX).abs() + (z - targetZ).abs();
    }

    valid.sort((a, b) => distance(a).compareTo(distance(b)));
    return flee ? valid.last : valid.first;
  }

  MoveDirection _opposite(MoveDirection direction) => switch (direction) {
    MoveDirection.left => MoveDirection.right,
    MoveDirection.right => MoveDirection.left,
    MoveDirection.up => MoveDirection.down,
    MoveDirection.down => MoveDirection.up,
    MoveDirection.none => MoveDirection.none,
  };

  void advance(double deltaSeconds) {
    runtime.advance(deltaSeconds);
    scripts.fixedUpdate(deltaSeconds);
  }
}

class _LevelEventSystem implements EngineSystem {
  _LevelEventSystem(this.level);
  final LevelDefinition level;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    if (states.isEmpty || states.first.$2.phase != GamePhase.playing) return;
    final state = states.first.$2;
    state.elapsedSeconds += deltaSeconds;
    state.announcementSeconds = (state.announcementSeconds - deltaSeconds)
        .clamp(0, double.infinity);
    for (var index = 0; index < level.events.length; index++) {
      if (state.firedLevelEvents.contains(index)) continue;
      final event = level.events[index];
      final byTime =
          event.afterSeconds != null &&
          state.elapsedSeconds >= event.afterSeconds!;
      final ratio = state.pelletsTotal == 0
          ? 1.0
          : state.pelletsRemaining / state.pelletsTotal;
      final byPellets =
          event.pelletsRemainingRatio != null &&
          ratio <= event.pelletsRemainingRatio!;
      if (!byTime && !byPellets) continue;
      state.firedLevelEvents.add(index);
      state
        ..announcement = event.message
        ..announcementSeconds = 5
        ..score += event.scoreBonus;
      if (event.scoreBonus != 0) {
        context.events.emit(ScoreChanged(state.score));
      }
    }
  }
}

class _ScriptSceneStateSystem implements EngineSystem {
  _ScriptSceneStateSystem(this.level);
  final LevelDefinition level;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    final roots = context.world
        .query2<ScriptProperties, ScriptGroups>()
        .where((entry) => entry.$3.values.contains('scene'))
        .toList();
    if (states.isEmpty || roots.isEmpty) return;
    final state = states.first.$2;
    roots.first.$2.values.addAll({
      'score': state.score,
      'lives': state.lives,
      'spell_charges': state.spellCharges,
      'keys': state.keys,
      'power_seconds': state.powerSeconds,
      'power_max': level.tuning.powerSeconds,
      'pellets_remaining': state.pelletsRemaining,
      'pellets_total': state.pelletsTotal,
    });
  }
}

class _PortalSystem implements EngineSystem {
  final Map<Entity, double> _cooldowns = {};

  @override
  void update(EngineContext context, double deltaSeconds) {
    for (final entry in _cooldowns.entries.toList()) {
      final remaining = entry.value - deltaSeconds;
      if (remaining <= 0) {
        _cooldowns.remove(entry.key);
      } else {
        _cooldowns[entry.key] = remaining;
      }
    }
    final portals = context.world.query2<Transform3, PortalTag>().toList();
    for (final (entity, transform, _)
        in context.world.query2<Transform3, GridMover>()) {
      // The player is orchestrated by the scene autoload. This native fallback
      // remains for unscripted moving actors such as ghosts.
      if (context.world.has<PlayerTag>(entity)) continue;
      if (_cooldowns.containsKey(entity)) continue;
      for (final (_, portal, tag) in portals) {
        if ((transform.x - portal.x).abs() > .25 ||
            (transform.z - portal.z).abs() > .25) {
          continue;
        }
        transform
          ..x = tag.destinationX
          ..z = tag.destinationZ;
        _cooldowns[entity] = .75;
        context.events.emit(
          LuaSignal(name: 'portal_entered', source: entity.id),
        );
        break;
      }
    }
  }
}

class _SpellSystem implements EngineSystem {
  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    if (states.isEmpty || states.first.$2.phase != GamePhase.playing) return;
    final state = states.first.$2;
    state.spellPulseSeconds = (state.spellPulseSeconds - deltaSeconds).clamp(
      0,
      double.infinity,
    );
    final players = context.world.query2<Transform3, PlayerTag>().toList();
    if (players.isEmpty) return;
    final player = players.first.$2;
    for (final (entity, pickup, _)
        in context.world.query2<Transform3, SpellPickupTag>()) {
      if ((player.x - pickup.x).abs() > .35 ||
          (player.z - pickup.z).abs() > .35) {
        continue;
      }
      state.spellCharges++;
      state
        ..announcement = 'STAR PULSE ACQUIRED — PRESS Q'
        ..announcementSeconds = 3;
      context.world.defer((world) => world.destroy(entity));
    }
  }
}

class _DungeonInteractionSystem implements EngineSystem {
  _DungeonInteractionSystem(this.sceneTree);
  final SceneTree sceneTree;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final players = context.world.query2<Transform3, PlayerTag>().toList();
    final states = context.world.query<GameState>().toList();
    if (players.isEmpty || states.isEmpty) return;
    final player = players.first.$2;
    final state = states.first.$2;
    if (state.phase != GamePhase.playing) return;

    for (final (entity, transform, _)
        in context.world.query2<Transform3, KeyPickupTag>()) {
      if ((player.x - transform.x).abs() >= .32 ||
          (player.z - transform.z).abs() >= .32) {
        continue;
      }
      state.keys++;
      state
        ..announcement = 'STAR KEY ACQUIRED — A LOCK RELEASES'
        ..announcementSeconds = 3;
      context.events.emit(
        LuaSignal(
          name: 'key_collected',
          source: entity.id,
          payload: state.keys,
        ),
      );
      sceneTree.unregister(entity);
      context.world.defer((world) => world.destroy(entity));
    }

    for (final (entity, transform, trap)
        in context.world.query2<Transform3, TrapTag>()) {
      trap.cooldown = (trap.cooldown - deltaSeconds).clamp(0, double.infinity);
      if (!trap.active || trap.cooldown > 0) continue;
      if ((player.x - transform.x).abs() >= .34 ||
          (player.z - transform.z).abs() >= .34) {
        continue;
      }
      state.lives = (state.lives - 1).clamp(0, 999);
      state
        ..announcement = 'RIFT TRAP — THE FLOOR BITES'
        ..announcementSeconds = 2.5;
      trap.cooldown = 2;
      context.events.emit(LivesChanged(state.lives));
      context.events.emit(
        LuaSignal(
          name: 'trap_triggered',
          source: entity.id,
          payload: state.lives,
        ),
      );
      if (state.lives == 0) state.phase = GamePhase.gameOver;
    }
  }
}

class _ScriptProjectileSystem implements EngineSystem {
  _ScriptProjectileSystem(this.maze, this.sceneTree);
  final Maze maze;
  final SceneTree sceneTree;
  double playerInvulnerability = 0;

  @override
  void update(EngineContext context, double deltaSeconds) {
    playerInvulnerability = (playerInvulnerability - deltaSeconds).clamp(
      0,
      double.infinity,
    );
    final players = context.world.query2<Transform3, PlayerTag>().toList();
    final states = context.world.query<GameState>().toList();
    if (players.isEmpty || states.isEmpty) return;
    final player = players.first.$2;
    final state = states.first.$2;
    for (final (entity, transform, velocity)
        in context.world.query2<Transform3, ScriptVelocity>()) {
      transform
        ..x += velocity.x * deltaSeconds
        ..y += velocity.y * deltaSeconds
        ..z += velocity.z * deltaSeconds;
      velocity.remainingSeconds -= deltaSeconds;
      final expired = velocity.remainingSeconds <= 0;
      final hitWall = maze.isWall(transform.x.round(), transform.z.round());
      final projectile = context.world.maybeGet<ScriptProjectileTag>(entity);
      final hitPlayer =
          projectile != null &&
          projectile.hurtsPlayer &&
          playerInvulnerability <= 0 &&
          (player.x - transform.x).abs() < .42 &&
          (player.z - transform.z).abs() < .42;
      if (hitPlayer) {
        state.lives = (state.lives - projectile.damage).clamp(0, 999);
        state
          ..announcement = 'THE DREAM WARDEN STRIKES'
          ..announcementSeconds = 2;
        context.events.emit(LivesChanged(state.lives));
        context.events.emit(
          LuaSignal(name: 'player_hit_by_projectile', source: entity.id),
        );
        if (state.lives == 0) state.phase = GamePhase.gameOver;
        playerInvulnerability = 1;
      }
      var hitEnemy = false;
      if (projectile != null && !projectile.hurtsPlayer) {
        for (final (enemy, enemyTransform, _)
            in context.world.query2<Transform3, GhostTag>()) {
          if ((enemyTransform.x - transform.x).abs() >= .45 ||
              (enemyTransform.z - transform.z).abs() >= .45) {
            continue;
          }
          final spawn = context.world.maybeGet<SpawnPoint>(enemy);
          if (spawn != null) {
            enemyTransform
              ..x = spawn.x
              ..z = spawn.z;
          }
          state.score += 150;
          context.events.emit(ScoreChanged(state.score));
          context.events.emit(
            LuaSignal(name: 'enemy_hit_by_projectile', source: enemy.id),
          );
          hitEnemy = true;
          break;
        }
      }
      if (expired || hitWall || hitPlayer || hitEnemy) {
        sceneTree.unregister(entity);
        context.world.defer((world) => world.destroy(entity));
      }
    }
  }
}

class _MovementSystem implements EngineSystem {
  _MovementSystem(this.maze);
  final Maze maze;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    if (states.isNotEmpty && states.first.$2.phase != GamePhase.playing) return;
    for (final (_, transform, mover)
        in context.world.query2<Transform3, GridMover>()) {
      final tileX = transform.x.round();
      final tileY = transform.z.round();
      final atCenter =
          (transform.x - tileX).abs() < .03 &&
          (transform.z - tileY).abs() < .03;
      if (atCenter) {
        transform.x = tileX.toDouble();
        transform.z = tileY.toDouble();
        if (_canMove(context, tileX, tileY, mover.requested)) {
          mover.direction = mover.requested;
        }
        if (!_canMove(context, tileX, tileY, mover.direction)) {
          mover.direction = MoveDirection.none;
        }
      }
      final distance = mover.speed * deltaSeconds;
      transform.x += mover.direction.dx * distance;
      transform.z += mover.direction.dy * distance;
    }
  }

  bool _canMove(EngineContext context, int x, int y, MoveDirection direction) {
    if (direction == MoveDirection.none ||
        maze.isWall(x + direction.dx, y + direction.dy)) {
      return false;
    }
    final targetX = x + direction.dx;
    final targetZ = y + direction.dy;
    return !context.world.query2<Transform3, DoorTag>().any(
      (entry) =>
          !entry.$3.open &&
          entry.$2.x.round() == targetX &&
          entry.$2.z.round() == targetZ,
    );
  }
}

class _PelletSystem implements EngineSystem {
  _PelletSystem(this.tuning);
  final LevelTuning tuning;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    if (states.isEmpty || states.first.$2.phase != GamePhase.playing) return;
    final state = states.first.$2;
    final players = context.world.query2<Transform3, PlayerTag>().toList();
    if (players.isEmpty) return;
    final player = players.first.$2;
    for (final (entity, pellet, pelletTag)
        in context.world.query2<Transform3, PelletTag>()) {
      if ((player.x - pellet.x).abs() < .3 &&
          (player.z - pellet.z).abs() < .3) {
        state.score += pelletTag.power ? 50 : 10;
        state.pelletsRemaining--;
        if (pelletTag.power) {
          state.powerSeconds = tuning.powerSeconds;
          state.ghostCombo = 0;
          context.events.emit(PowerModeChanged(state.powerSeconds));
        }
        context.world.defer((world) => world.destroy(entity));
        context.events.emit(ScoreChanged(state.score));
        if (state.pelletsRemaining == 0) {
          state.phase = GamePhase.won;
          context.events.emit(const LevelCompleted());
        }
      }
    }
  }
}

class _BonusFruitSystem implements EngineSystem {
  _BonusFruitSystem(this.level);
  final LevelDefinition level;
  Maze get maze => level.maze;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    if (states.isEmpty || states.first.$2.phase != GamePhase.playing) return;
    final state = states.first.$2;
    if (!state.bonusSpawned &&
        state.pelletsRemaining <= state.pelletsTotal ~/ 2) {
      state
        ..bonusSpawned = true
        ..bonusSeconds = level.tuning.bonusSeconds;
      context.world.defer(
        (world) => world.create([
          Transform3((maze.width - 1) / 2, .38, (maze.height - 1) / 2),
          BonusFruitTag(points: level.tuning.bonusPoints),
        ]),
      );
      context.events.emit(const BonusSpawned());
    }

    final fruits = context.world.query2<Transform3, BonusFruitTag>().toList();
    if (fruits.isEmpty) return;
    state.bonusSeconds = (state.bonusSeconds - deltaSeconds).clamp(
      0,
      double.infinity,
    );
    final players = context.world.query2<Transform3, PlayerTag>().toList();
    if (players.isEmpty) return;
    final player = players.first.$2;
    for (final (entity, fruit, tag) in fruits) {
      final collected =
          (player.x - fruit.x).abs() < .4 && (player.z - fruit.z).abs() < .4;
      if (collected) {
        state
          ..score += tag.points
          ..bonusSeconds = 0;
        context.events.emit(ScoreChanged(state.score));
        context.events.emit(BonusCollected(tag.points));
        context.world.defer((world) => world.destroy(entity));
      } else if (state.bonusSeconds == 0) {
        context.world.defer((world) => world.destroy(entity));
      }
    }
  }
}

class _GhostCollisionSystem implements EngineSystem {
  double invulnerability = 0;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final states = context.world.query<GameState>().toList();
    if (states.isEmpty) return;
    final state = states.first.$2;
    if (state.phase != GamePhase.playing) return;
    final wasPowered = state.powerSeconds > 0;
    state.powerSeconds = (state.powerSeconds - deltaSeconds).clamp(
      0,
      double.infinity,
    );
    if (wasPowered && state.powerSeconds == 0) state.ghostCombo = 0;
    invulnerability = (invulnerability - deltaSeconds).clamp(
      0,
      double.infinity,
    );
    if (invulnerability > 0) return;
    final players = context.world.query2<Transform3, PlayerTag>().toList();
    final ghosts = context.world.query2<Transform3, GhostTag>().toList();
    if (players.isEmpty || ghosts.isEmpty) return;
    final player = players.first.$2;
    (Entity, Transform3, GhostTag)? collision;
    for (final candidate in ghosts) {
      if ((player.x - candidate.$2.x).abs() <= .55 &&
          (player.z - candidate.$2.z).abs() <= .55) {
        collision = candidate;
        break;
      }
    }
    if (collision == null) return;

    if (state.powerSeconds > 0) {
      final comboIndex = state.ghostCombo > 3 ? 3 : state.ghostCombo;
      final comboPoints = 200 << comboIndex;
      state.score += comboPoints;
      state.ghostCombo++;
      context.events.emit(ScoreChanged(state.score));
      _respawn(context, collision.$1);
      invulnerability = .35;
      return;
    }

    state.lives--;
    context.events.emit(LivesChanged(state.lives));
    if (state.lives == 0) {
      state.phase = GamePhase.gameOver;
      return;
    }
    for (final (entity, transform, mover)
        in context.world.query2<Transform3, GridMover>()) {
      _applySpawn(context, entity, transform, mover);
    }
    invulnerability = 1;
  }

  void _respawn(EngineContext context, Entity entity) {
    _applySpawn(
      context,
      entity,
      context.world.get<Transform3>(entity),
      context.world.get<GridMover>(entity),
    );
  }

  void _applySpawn(
    EngineContext context,
    Entity entity,
    Transform3 transform,
    GridMover mover,
  ) {
    final spawn = context.world.maybeGet<SpawnPoint>(entity);
    if (spawn == null) return;
    transform
      ..x = spawn.x
      ..z = spawn.z;
    mover
      ..direction = MoveDirection.none
      ..requested = MoveDirection.none;
  }
}
