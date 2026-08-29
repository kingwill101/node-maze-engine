import 'package:lualike/docs.dart';
import 'package:lualike/lualike.dart';

import '../engine/entity.dart';
import '../engine/runtime.dart';
import '../engine/scene_tree.dart';
import '../game/components.dart';
import '../platformer/platformer_components.dart';
import '../platformer/platformer_system.dart';
import '../scene/render_components.dart';
import 'node_engine_lua_library.dart';

/// LuaLike bridge for Godot-style behavior callbacks.
///
/// A host owns one Lua VM so script globals are isolated. Mutating functions
/// are deliberately narrow; structural operations are deferred by [World].
class LuaBehaviorRuntime {
  LuaBehaviorRuntime(
    this.engine, {
    this.canMove,
    this.player,
    this.personality,
    this.chooseDirection,
    this.isPowerActive,
    this.emitSignal,
    this.sceneTree,
  }) {
    _registerApi();
    _lua.register(NodeEngineLuaLibrary(_bindings));
    _registerFacadeLibraries();
  }

  final EngineContext engine;
  final bool Function(Entity entity, MoveDirection direction)? canMove;
  final Entity? player;
  final String Function(Entity entity)? personality;
  final MoveDirection Function(
    Entity entity,
    double targetX,
    double targetZ,
    bool flee,
  )?
  chooseDirection;
  final bool Function()? isPowerActive;
  final void Function(LuaSignal signal)? emitSignal;
  final SceneTree? sceneTree;
  final LuaLike _lua = LuaLike();
  final Map<String, NodeLuaCallback> _bindings = {};
  final Map<String, _ScriptTimer> _timers = {};

  bool isEntityAlive(Entity entity) => engine.world.isAlive(entity);

  void _registerFacadeLibraries() {
    NodeLuaCallback native(String name) =>
        (arguments) => _bindings[name]!(arguments);
    FunctionDoc doc(
      String summary,
      List<DocParam> params, {
      String? returns,
      String? returnType,
    }) => FunctionDoc(
      summary: summary,
      params: params,
      returns: returns,
      returnType: returnType,
      category: 'scripting',
      nodiscard: returnType != null,
    );

    _lua.register(
      NodeEngineFacadeLibrary(
        namespace: 'World',
        summary: 'Dynamic ECS world access for Lua systems and behaviors.',
        functions: {
          'query': (
            callback: (args) =>
                _bindings['query_components']!([args, const []]),
            doc: doc(
              'Returns entities containing every requested component.',
              [DocParam('...', 'string', 'Required component names.')],
              returns: 'Matching entity identifiers.',
              returnType: 'integer[]',
            ),
          ),
          'query_filtered': (
            callback: native('query_components'),
            doc: doc(
              'Returns entities matching include and exclude component lists.',
              [
                DocParam('with_components', 'string[]', 'Required components.'),
                DocParam(
                  'without_components',
                  'string[]',
                  'Excluded components.',
                ),
              ],
              returns: 'Matching entity identifiers.',
              returnType: 'integer[]',
            ),
          ),
          'get': (
            callback: native('get_component'),
            doc: doc(
              'Returns a component table for an entity.',
              [
                DocParam('entity', 'integer', 'Entity identifier.'),
                DocParam('component', 'string', 'Component name.'),
              ],
              returns: 'Live component data, or nil.',
              returnType: 'table|nil',
            ),
          ),
          'has': (
            callback: native('entity_has_component'),
            doc: doc(
              'Tests whether an entity contains a component.',
              [
                DocParam('entity', 'integer', 'Entity identifier.'),
                DocParam('component', 'string', 'Component name.'),
              ],
              returns: 'True when the component exists.',
              returnType: 'boolean',
            ),
          ),
        },
      ),
    );
    _lua.register(
      NodeEngineFacadeLibrary(
        namespace: 'Scene',
        summary: 'Backend-neutral Flutter Scene authoring API.',
        functions: {
          'mesh': (
            callback: native('scene_set_mesh'),
            doc: doc('Creates or updates an entity mesh.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('options', 'SceneMeshOptions', 'Mesh definition.'),
            ]),
          ),
          'material': (
            callback: native('scene_set_material'),
            doc: doc('Creates or updates an entity material.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam(
                'options',
                'SceneMaterialOptions',
                'Material definition.',
              ),
            ]),
          ),
          'light': (
            callback: native('scene_set_light'),
            doc: doc('Creates or updates an entity light.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('options', 'SceneLightOptions', 'Light definition.'),
            ]),
          ),
          'remove_mesh': (
            callback: native('scene_remove_mesh'),
            doc: doc('Removes an entity mesh.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
            ]),
          ),
          'remove_light': (
            callback: native('scene_remove_light'),
            doc: doc('Removes an entity light.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
            ]),
          ),
          'camera': (
            callback: native('scene_set_camera'),
            doc: doc('Creates or updates an entity camera.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('options', 'table', 'Perspective camera definition.'),
            ]),
          ),
          'model': (
            callback: native('scene_set_asset'),
            doc: doc('Loads an animated 3D model on an entity.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam(
                'options',
                'table',
                'Model asset and animation settings.',
              ),
            ]),
          ),
          'particles': (
            callback: native('scene_set_particles'),
            doc: doc('Creates or updates a Flutter Scene particle emitter.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('options', 'table', 'Emitter and module settings.'),
            ]),
          ),
          'environment': (
            callback: native('scene_set_environment'),
            doc: doc('Configures scene lighting and post-processing.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('options', 'table', 'Environment effect settings.'),
            ]),
          ),
        },
      ),
    );
    _lua.register(
      NodeEngineFacadeLibrary(
        namespace: 'Node',
        summary: 'Godot-style entity and scene-tree operations.',
        functions: {
          'get': (
            callback: native('get_node'),
            doc: doc('Finds an entity by path.', [
              DocParam('path', 'string', 'Scene-tree path.'),
            ], returnType: 'integer'),
          ),
          'has': (
            callback: native('has_node'),
            doc: doc('Tests whether a path exists.', [
              DocParam('path', 'string', 'Scene-tree path.'),
            ], returnType: 'boolean'),
          ),
          'path': (
            callback: native('get_node_path'),
            doc: doc('Returns an entity scene path.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
            ], returnType: 'string'),
          ),
          'queue_free': (
            callback: native('entity_destroy'),
            doc: doc('Queues an entity for destruction.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
            ]),
          ),
          'add_to_group': (
            callback: native('entity_add_to_group'),
            doc: doc('Adds an entity to a group.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('group', 'string', 'Group name.'),
            ]),
          ),
          'remove_from_group': (
            callback: native('entity_remove_from_group'),
            doc: doc('Removes an entity from a group.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('group', 'string', 'Group name.'),
            ]),
          ),
          'is_in_group': (
            callback: native('entity_is_in_group'),
            doc: doc('Tests entity group membership.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('group', 'string', 'Group name.'),
            ], returnType: 'boolean'),
          ),
          'remove_component': (
            callback: native('remove_component'),
            doc: doc('Removes a dynamic component.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('component', 'string', 'Component name.'),
            ]),
          ),
          'has_component': (
            callback: native('entity_has_component'),
            doc: doc('Tests component membership.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('component', 'string', 'Component name.'),
            ], returnType: 'boolean'),
          ),
          'get_component': (
            callback: native('get_component'),
            doc: doc('Returns component data.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('component', 'string', 'Component name.'),
            ], returnType: 'table|nil'),
          ),
          'get_value': (
            callback: native('get_component_value'),
            doc: doc('Reads a component field.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('component', 'string', 'Component name.'),
              DocParam('key', 'string', 'Field name.'),
            ], returnType: 'any'),
          ),
          'set_value': (
            callback: native('set_component_value'),
            doc: doc('Writes a component field.', [
              DocParam('entity', 'integer', 'Entity identifier.'),
              DocParam('component', 'string', 'Component name.'),
              DocParam('key', 'string', 'Field name.'),
              DocParam('value', 'any', 'New value.'),
            ]),
          ),
        },
      ),
    );
    _lua.register(
      NodeEngineFacadeLibrary(
        namespace: 'SceneTree',
        summary: 'Queries over paths, groups, and dynamic components.',
        functions: {
          'get_nodes_in_group': (
            callback: native('get_nodes_in_group'),
            doc: doc('Returns entities in a group.', [
              DocParam('group', 'string', 'Group name.'),
            ], returnType: 'integer[]'),
          ),
          'get_nodes_with_component': (
            callback: native('get_nodes_with_component'),
            doc: doc('Returns entities with a component.', [
              DocParam('component', 'string', 'Component name.'),
            ], returnType: 'integer[]'),
          ),
          'node_count': (
            callback: (_) => sceneTree?.paths.length ?? 0,
            doc: doc(
              'Returns registered scene node count.',
              const [],
              returnType: 'integer',
            ),
          ),
        },
      ),
    );
  }

  void _registerApi() {
    _expose('get_node', (args) {
      final entity = sceneTree?.getNode(_string(args, 0));
      return entity?.id ?? 0;
    });
    _expose(
      'has_node',
      (args) => sceneTree?.hasNode(_string(args, 0)) ?? false,
    );
    _expose('get_node_path', (args) => sceneTree?.pathOf(_entity(args)) ?? '');
    _expose('get_scene_paths', (args) => sceneTree?.paths.toList() ?? const []);
    _expose('get_nodes_in_group', (args) {
      final name = _string(args, 0);
      return [
        for (final entity in engine.world.entities)
          if (engine.world
                  .maybeGet<ScriptGroups>(entity)
                  ?.values
                  .contains(name) ??
              false)
            entity.id,
      ];
    });
    _expose('_engine_instantiate_empty', (args) {
      final prefab = _string(args, 0);
      final path = _string(args, 1);
      final entity = engine.world.create([
        Transform3(_number(args, 2), _number(args, 3), _number(args, 4)),
        ScriptProperties({'prefab': prefab}),
        ScriptGroups(['script_spawned', prefab]),
        ScriptComponents(),
        ScriptDrawings(),
      ]);
      sceneTree?.register(path, entity);
      return entity.id;
    });
    _expose('entity_set_path', (args) {
      sceneTree?.register(_string(args, 1), _entity(args));
      return null;
    });
    _expose('entity_set_velocity', (args) {
      final entity = _entity(args);
      if (engine.world.has<ScriptVelocity>(entity)) {
        engine.world.remove<ScriptVelocity>(entity);
      }
      engine.world.add(
        entity,
        ScriptVelocity(
          _number(args, 1),
          _number(args, 2),
          _number(args, 3),
          remainingSeconds: _number(args, 4),
        ),
      );
      return null;
    });
    _expose('entity_is_alive', (args) => engine.world.isAlive(_entity(args)));
    _expose('entity_has_component', (args) {
      final entity = _entity(args);
      final name = _string(args, 1);
      return switch (name) {
        'transform' => engine.world.has<Transform3>(entity),
        'mover' => engine.world.has<GridMover>(entity),
        'player' => engine.world.has<PlayerTag>(entity),
        'ghost' => engine.world.has<GhostTag>(entity),
        'properties' => engine.world.has<ScriptProperties>(entity),
        'groups' => engine.world.has<ScriptGroups>(entity),
        'drawings' => engine.world.has<ScriptDrawings>(entity),
        'particles' => engine.world.has<ScriptParticleEmitters>(entity),
        'hud' => engine.world.has<ScriptHud>(entity),
        'velocity' => engine.world.has<ScriptVelocity>(entity),
        'projectile' => engine.world.has<ScriptProjectileTag>(entity),
        'boss' => engine.world.has<BossTag>(entity),
        'door' => engine.world.has<DoorTag>(entity),
        'key' => engine.world.has<KeyPickupTag>(entity),
        'trap' => engine.world.has<TrapTag>(entity),
        _ => _scriptComponents(entity).values.containsKey(name),
      };
    });
    _expose('add_component', (args) {
      final entity = _entity(args);
      final type = _string(args, 1);
      final data = args.length > 2
          ? _stringObjectMap(_argument(args, 2))
          : <String, Object?>{};
      _scriptComponents(entity).values[type] = data;
      return entity.id;
    });
    _expose('remove_component', (args) {
      engine.world
          .maybeGet<ScriptComponents>(_entity(args))
          ?.values
          .remove(_string(args, 1));
      return null;
    });
    _expose(
      'has_component',
      (args) =>
          engine.world
              .maybeGet<ScriptComponents>(_entity(args))
              ?.values
              .containsKey(_string(args, 1)) ??
          false,
    );
    _expose(
      'get_component',
      (args) => engine.world
          .maybeGet<ScriptComponents>(_entity(args))
          ?.values[_string(args, 1)],
    );
    _expose('get_component_value', (args) {
      final data = _scriptComponents(_entity(args)).values[_string(args, 1)];
      return data?[_string(args, 2)];
    });
    _expose('set_component_value', (args) {
      final data = _scriptComponents(_entity(args)).values
          .putIfAbsent(_string(args, 1), () => {});
      data[_string(args, 2)] = _deepUnwrap(_argument(args, 3));
      return null;
    });
    _expose('get_nodes_with_component', (args) {
      final type = _string(args, 0);
      return [
        for (final entity in engine.world.entities)
          if (engine.world
                  .maybeGet<ScriptComponents>(entity)
                  ?.values
                  .containsKey(type) ??
              false)
            entity.id,
      ];
    });
    _expose('query_components', (args) {
      final withComponents = _stringList(_argument(args, 0));
      final withoutComponents = args.length > 1
          ? _stringList(_argument(args, 1))
          : const <String>[];
      return [
        for (final entity in engine.world.entities)
          if (_matchesScriptQuery(entity, withComponents, withoutComponents))
            entity.id,
      ];
    });
    _expose('scene_set_mesh', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneMesh3d(
          primitive: _scenePrimitive(data['primitive']?.toString()),
          material: data['material']?.toString() ?? 'default',
          width: _mapNumber(data, 'width', 1),
          height: _mapNumber(data, 'height', 1),
          depth: _mapNumber(data, 'depth', 1),
          visible: data['visible'] != false,
          replacesDefault: data['replaces_default'] != false,
          castShadows: data['cast_shadows'] != false,
          receiveShadows: data['receive_shadows'] != false,
          renderLayer: _mapNumber(data, 'render_layer', 1).toInt(),
        ),
      );
      return entity.id;
    });
    _expose('scene_set_material', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneMaterial3d(
          kind: _sceneMaterialKind(data['kind']?.toString()),
          color: data['color']?.toString() ?? '#ffffff',
          asset: data['asset']?.toString(),
          metallic: _mapNumber(data, 'metallic', 0),
          roughness: _mapNumber(data, 'roughness', 1),
          emissive: _mapNumber(data, 'emissive', 0),
          opacity: _mapNumber(data, 'opacity', 1),
          parameters: _stringObjectMap(data['parameters']),
        ),
      );
      return entity.id;
    });
    _expose('scene_remove_mesh', (args) {
      engine.world.remove<SceneMesh3d>(_entity(args));
      return null;
    });
    _expose('scene_set_light', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneLight3d(
          kind: _sceneLightKind(data['kind']?.toString()),
          color: data['color']?.toString() ?? '#ffffff',
          intensity: _mapNumber(data, 'intensity', 1),
          range: _mapNumber(data, 'range', 10),
          innerAngle: _mapNumber(data, 'inner_angle', .35),
          outerAngle: _mapNumber(data, 'outer_angle', .65),
          castShadows: data['cast_shadows'] == true,
          width: _mapNumber(data, 'width', 1),
          height: _mapNumber(data, 'height', 1),
        ),
      );
      return entity.id;
    });
    _expose('scene_remove_light', (args) {
      engine.world.remove<SceneLight3d>(_entity(args));
      return null;
    });
    _expose('scene_set_camera', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneCamera3d(
          active: data['active'] == true,
          fovRadians: _mapNumber(data, 'fov', 1),
          near: _mapNumber(data, 'near', .05),
          far: _mapNumber(data, 'far', 500),
        ),
      );
      return entity.id;
    });
    _expose('scene_set_asset', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneAsset3d(
          data['path']?.toString() ?? '',
          subtree: data['variant']?.toString() ?? data['subtree']?.toString(),
          animation: data['animation']?.toString(),
          autoPlay: data['auto_play'] != false,
        ),
      );
      return entity.id;
    });
    _expose('scene_set_particles', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneParticle3d(
          maxParticles: _mapNumber(data, 'max_particles', 128).toInt(),
          rate: _mapNumber(data, 'rate', 10),
          lifetime: _mapNumber(data, 'lifetime', 1),
          shape: data['shape']?.toString() ?? 'point',
          color: data['color']?.toString() ?? '#ffffff',
          size: _mapNumber(data, 'size', .1),
          modules: _stringList(data['modules']),
        ),
      );
      return entity.id;
    });
    _expose('scene_set_environment', (args) {
      final entity = _entity(args);
      final data = _stringObjectMap(_argument(args, 1));
      _replaceComponent(
        entity,
        SceneEnvironment3d(
          environmentAsset: data['environment_asset']?.toString(),
          skyAsset: data['sky_asset']?.toString(),
          fog: data['fog'] == true,
          ambientOcclusion: data['ambient_occlusion'] == true,
          globalIllumination: data['global_illumination'] == true,
          screenSpaceReflections: data['screen_space_reflections'] == true,
          godRays: data['god_rays'] == true,
          depthOfField: data['depth_of_field'] == true,
          autoExposure: data['auto_exposure'] == true,
          temporalAntiAliasing: data['temporal_anti_aliasing'] == true,
          exposure: _mapNumber(data, 'exposure', 1),
          environmentIntensity: _mapNumber(data, 'environment_intensity', 1),
          bloom: data['bloom'] == true,
          bloomIntensity: _mapNumber(data, 'bloom_intensity', .15),
          lensFlare: data['lens_flare'] == true,
          vignette: data['vignette'] == true,
          chromaticAberration: data['chromatic_aberration'] == true,
          filmGrain: data['film_grain'] == true,
        ),
      );
      return entity.id;
    });
    _expose('entity_add_component', (args) {
      final entity = _entity(args);
      switch (_string(args, 1)) {
        case 'properties':
          _properties(entity);
        case 'groups':
          _groups(entity);
        case 'drawings':
          _drawings(entity);
        case 'particles':
          _particles(entity);
        case 'hud':
          _hud(entity);
      }
      return null;
    });
    _expose('entity_remove_component', (args) {
      final entity = _entity(args);
      switch (_string(args, 1)) {
        case 'properties':
          engine.world.remove<ScriptProperties>(entity);
        case 'groups':
          engine.world.remove<ScriptGroups>(entity);
        case 'drawings':
          engine.world.remove<ScriptDrawings>(entity);
        case 'particles':
          engine.world.remove<ScriptParticleEmitters>(entity);
        case 'hud':
          engine.world.remove<ScriptHud>(entity);
      }
      return null;
    });
    _expose(
      'entity_get_x',
      (args) => engine.world.get<Transform3>(_entity(args)).x,
    );
    _expose(
      'entity_get_y',
      (args) => engine.world.get<Transform3>(_entity(args)).y,
    );
    _expose(
      'entity_get_z',
      (args) => engine.world.get<Transform3>(_entity(args)).z,
    );
    _expose('entity_set_position', (args) {
      final transform = engine.world.get<Transform3>(_entity(args));
      transform
        ..x = _number(args, 1)
        ..y = _number(args, 2)
        ..z = _number(args, 3);
      return null;
    });
    _expose('game_add_score', (args) {
      final states = engine.world.query<GameState>().toList();
      if (states.isEmpty) return 0;
      final state = states.first.$2;
      state.score += _number(args, 0).toInt();
      engine.events.emit(ScoreChanged(state.score));
      return state.score;
    });
    _expose('game_damage_player', (args) {
      final states = engine.world.query<GameState>().toList();
      if (states.isEmpty) return 0;
      final state = states.first.$2;
      final damage = args.isEmpty ? 1 : _number(args, 0).toInt();
      state.lives = (state.lives - damage).clamp(0, 999);
      state
        ..announcement = args.length > 1 ? _string(args, 1) : 'THE VOID BITES'
        ..announcementSeconds = 2;
      engine.events.emit(LivesChanged(state.lives));
      if (state.lives == 0) state.phase = GamePhase.gameOver;
      return state.lives;
    });
    _expose('game_get_lives', (args) {
      final states = engine.world.query<GameState>().toList();
      return states.isEmpty ? 0 : states.first.$2.lives;
    });
    _expose('platformer_set_checkpoint', (args) {
      final entity = _entity(args);
      final body = engine.world.maybeGet<PlatformerBody>(entity);
      if (body == null) return false;
      body
        ..checkpointX = _number(args, 1)
        ..checkpointY = _number(args, 2);
      return true;
    });
    _expose('platformer_launch', (args) {
      final body = engine.world.maybeGet<PlatformerBody>(_entity(args));
      if (body == null) return false;
      body
        ..velocityY = _number(args, 1)
        ..grounded = false;
      return true;
    });
    _expose('game_complete_level', (args) {
      final states = engine.world.query<GameState>().toList();
      if (states.isEmpty) return false;
      final state = states.first.$2;
      if (state.phase != GamePhase.playing) return false;
      state
        ..phase = GamePhase.won
        ..announcement = args.isEmpty ? 'LEVEL COMPLETE' : _string(args, 0)
        ..announcementSeconds = 4;
      engine.events.emit(const LevelCompleted());
      return true;
    });
    _expose('door_set_open', (args) {
      final entity = _entity(args);
      final open = _scalar(args, 1) == true;
      engine.world.get<DoorTag>(entity).open = open;
      _properties(entity).values['open'] = open;
      return null;
    });
    _expose('platformer_move_platform', (args) {
      final platform = _entity(args);
      movePlatformAndRiders(
        engine,
        platform,
        _number(args, 1),
        _number(args, 2),
        _number(args, 3),
      );
      return null;
    });
    _expose(
      'door_is_open',
      (args) => engine.world.get<DoorTag>(_entity(args)).open,
    );
    _expose('trap_set_active', (args) {
      final entity = _entity(args);
      final active = _scalar(args, 1) == true;
      engine.world.get<TrapTag>(entity).active = active;
      _properties(entity).values['active'] = active;
      return null;
    });
    _expose('entity_destroy', (args) {
      final entity = _entity(args);
      engine.world.defer((world) {
        sceneTree?.unregister(entity);
        world.destroy(entity);
      });
      return null;
    });
    _expose('draw_sphere', (args) {
      final entity = _entity(args);
      final name = _string(args, 1);
      final radius = _number(args, 5);
      _drawings(entity).values[name] = ScriptDrawing(
        name: name,
        shape: ScriptPrimitiveShape.sphere,
        x: _number(args, 2),
        y: _number(args, 3),
        z: _number(args, 4),
        scaleX: radius,
        scaleY: radius,
        scaleZ: radius,
        color: _string(args, 6),
      );
      return null;
    });
    _expose('draw_box', (args) {
      final entity = _entity(args);
      final name = _string(args, 1);
      _drawings(entity).values[name] = ScriptDrawing(
        name: name,
        shape: ScriptPrimitiveShape.box,
        x: _number(args, 2),
        y: _number(args, 3),
        z: _number(args, 4),
        scaleX: _number(args, 5),
        scaleY: _number(args, 6),
        scaleZ: _number(args, 7),
        color: _string(args, 8),
      );
      return null;
    });
    _expose('drawing_set_animation', (args) {
      final drawing = _drawings(_entity(args)).values[_string(args, 1)];
      if (drawing != null) {
        drawing
          ..animation = _string(args, 2)
          ..animationSpeed = _number(args, 3)
          ..animationAmount = _number(args, 4);
      }
      return null;
    });
    _expose('drawing_remove', (args) {
      _drawings(_entity(args)).values.remove(_string(args, 1));
      return null;
    });
    _expose('drawing_clear', (args) {
      _drawings(_entity(args)).values.clear();
      return null;
    });
    _expose('particle_emitter', (args) {
      final entity = _entity(args);
      final name = _string(args, 1);
      _particles(entity).values[name] = ScriptParticleEmitter(
        name: name,
        count: _number(args, 2).round().clamp(1, 64),
        radius: _number(args, 3),
        speed: _number(args, 4),
        size: _number(args, 5),
        color: _string(args, 6),
        pattern: _string(args, 7),
        remainingSeconds: _optionalNumber(args, 8),
      );
      return null;
    });
    _expose('particle_remove', (args) {
      _particles(_entity(args)).values.remove(_string(args, 1));
      return null;
    });
    _expose('particle_clear', (args) {
      _particles(_entity(args)).values.clear();
      return null;
    });
    _expose('hud_label', (args) {
      final hud = _hud(_entity(args));
      final name = _string(args, 1);
      hud.elements[name] = ScriptHudElement(
        name: name,
        type: ScriptHudElementType.label,
        text: _string(args, 2),
        anchor: _string(args, 3),
        x: _number(args, 4),
        y: _number(args, 5),
        color: _string(args, 6),
        fontSize: _number(args, 7),
      );
      return null;
    });
    _expose('hud_bar', (args) {
      final hud = _hud(_entity(args));
      final name = _string(args, 1);
      hud.elements[name] = ScriptHudElement(
        name: name,
        type: ScriptHudElementType.bar,
        value: _number(args, 2),
        maximum: _number(args, 3),
        anchor: _string(args, 4),
        x: _number(args, 5),
        y: _number(args, 6),
        color: _string(args, 7),
        width: _number(args, 8),
        height: _number(args, 9),
      );
      return null;
    });
    _expose('hud_remove', (args) {
      _hud(_entity(args)).elements.remove(_string(args, 1));
      return null;
    });
    _expose('hud_clear', (args) {
      _hud(_entity(args)).elements.clear();
      return null;
    });
    _expose(
      'entity_get_property',
      (args) => _properties(_entity(args)).values[_string(args, 1)],
    );
    _expose('entity_set_property', (args) {
      _properties(_entity(args)).values[_string(args, 1)] = _scalar(args, 2);
      return null;
    });
    _expose('entity_add_to_group', (args) {
      _groups(_entity(args)).values.add(_string(args, 1));
      return null;
    });
    _expose('entity_remove_from_group', (args) {
      _groups(_entity(args)).values.remove(_string(args, 1));
      return null;
    });
    _expose(
      'entity_is_in_group',
      (args) => _groups(_entity(args)).values.contains(_string(args, 1)),
    );
    _expose('group_count', (args) {
      final name = _string(args, 0);
      return engine.world.entities
          .where(
            (entity) =>
                engine.world
                    .maybeGet<ScriptGroups>(entity)
                    ?.values
                    .contains(name) ??
                false,
          )
          .length;
    });
    _expose('group_nearest', (args) {
      final name = _string(args, 0);
      final x = _number(args, 1);
      final z = _number(args, 2);
      Entity? nearest;
      var bestDistance = double.infinity;
      for (final entity in engine.world.entities) {
        final groups = engine.world.maybeGet<ScriptGroups>(entity);
        if (groups == null || !groups.values.contains(name)) continue;
        final transform = engine.world.maybeGet<Transform3>(entity);
        if (transform == null) continue;
        final distance = (transform.x - x).abs() + (transform.z - z).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          nearest = entity;
        }
      }
      return nearest?.id ?? 0;
    });
    _expose('emit_signal', (args) {
      emitSignal?.call(
        LuaSignal(
          name: _string(args, 1),
          source: _entity(args).id,
          payload: args.length > 2 ? _scalar(args, 2) : null,
        ),
      );
      return null;
    });
    _expose('set_timer', (args) {
      final name = _string(args, 0);
      _timers[name] = _ScriptTimer(
        _number(args, 1),
        args.length > 2 && _scalar(args, 2) == true,
      );
      return null;
    });
    _expose('cancel_timer', (args) {
      if (args.isNotEmpty) _timers.remove(_string(args, 0));
      return null;
    });
    _expose('entity_request_move', (args) {
      engine.world.get<GridMover>(_entity(args)).requested = _direction(
        _string(args, 1),
      );
      return null;
    });
    _expose('entity_can_move', (args) {
      final entity = _entity(args);
      return canMove?.call(entity, _direction(_string(args, 1))) ?? false;
    });
    _expose(
      'ghost_personality',
      (args) => personality?.call(_entity(args)) ?? 'chaser',
    );
    _expose('player_get_x', (args) => _playerTransform.x);
    _expose('player_get_z', (args) => _playerTransform.z);
    _expose('player_get_dx', (args) => _playerMover.direction.dx);
    _expose('player_get_dz', (args) => _playerMover.direction.dy);
    _expose('power_active', (args) => isPowerActive?.call() ?? false);
    _expose('entity_request_target', (args) {
      final entity = _entity(args);
      final direction = chooseDirection?.call(
        entity,
        _number(args, 1),
        _number(args, 2),
        _string(args, 3) == 'flee',
      );
      if (direction != null) {
        engine.world.get<GridMover>(entity).requested = direction;
      }
      return null;
    });
  }

  void _expose(
    String name,
    Object? Function(List<Object?> arguments) callback,
  ) => _bindings[name] = callback;

  /// LuaLS annotations for the exact API installed in this runtime.
  String renderLuaLanguageServerAnnotations() =>
      renderLuaLsAnnotations(_engineLibraries, packageName: 'node_engine');

  /// Machine-readable API metadata for editor integrations.
  String renderLuaApiJson() =>
      renderDocsJson(_engineLibraries, packageName: 'node_engine');

  List<Library> get _engineLibraries =>
      documentedLibrariesForRuntime(_lua.vm)
          .whereType<NodeEngineDocumentedLibrary>()
          .toList(growable: false);

  Object? _argument(List<Object?> arguments, int index) {
    if (index >= arguments.length) return null;
    final value = arguments[index];
    return value is Value ? value.unwrap() : value;
  }

  Entity _entity(List<Object?> arguments, [int index = 0]) =>
      Entity((_argument(arguments, index) as num).toInt());

  double _number(List<Object?> arguments, int index) =>
      (_argument(arguments, index) as num).toDouble();

  double? _optionalNumber(List<Object?> arguments, int index) {
    final value = _argument(arguments, index);
    return value is num ? value.toDouble() : null;
  }

  String _string(List<Object?> arguments, int index) =>
      _argument(arguments, index).toString();

  Object? _scalar(List<Object?> arguments, int index) =>
      _unwrapScalar(_argument(arguments, index));

  Transform3 get _playerTransform {
    final entity = player;
    if (entity == null) return Transform3(0, 0, 0);
    return engine.world.get<Transform3>(entity);
  }

  GridMover get _playerMover {
    final entity = player;
    if (entity == null) return GridMover(speed: 0);
    return engine.world.get<GridMover>(entity);
  }

  Future<void> load(String source, {String? scriptPath}) async {
    await _lua.execute('''
local __node_prefabs = {}
local __node_component_schemas = {}
local __node_resources = {}
local __node_systems = {
  startup = {}, pre_update = {}, fixed_update = {}, update = {}, post_update = {}
}

local function __node_copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = __node_copy(item) end
  return result
end

local function __node_merge(defaults, values)
  local result = __node_copy(defaults or {})
  for key, value in pairs(values or {}) do result[key] = __node_copy(value) end
  return result
end

Component = {}
function Component.define(name, defaults)
  __node_component_schemas[name] = __node_copy(defaults or {})
end
function Component.has(name) return __node_component_schemas[name] ~= nil end
function Component.new(name, values)
  return __node_merge(__node_component_schemas[name], values)
end

Resource = {}
function Resource.insert(name, value) __node_resources[name] = value end
function Resource.has(name) return __node_resources[name] ~= nil end
function Resource.get(name) return __node_resources[name] end
function Resource.remove(name)
  local value = __node_resources[name]
  __node_resources[name] = nil
  return value
end

Commands = {}
function Commands.despawn(entity) return entity_destroy(entity) end
function Commands.add(entity, component, values)
  return add_component(entity, component, Component.new(component, values))
end
function Commands.remove(entity, component) return remove_component(entity, component) end

System = {}
function System.add(name, schedule, query, handler)
  if handler == nil then handler, query = query, nil end
  local systems = __node_systems[schedule]
  if systems == nil then error("Unknown schedule: " .. tostring(schedule)) end
  for _, system in ipairs(systems) do
    if system.name == name then error("Duplicate system: " .. tostring(name)) end
  end
  table.insert(systems, { name = name, query = query, handler = handler })
end

local function __node_run_systems(schedule, entity, delta)
  for _, system in ipairs(__node_systems[schedule] or {}) do
    if system.query == nil then
      system.handler(entity, delta)
    else
      system.handler(World.query_filtered(system.query.with or {}, system.query.without or {}), delta)
    end
  end
end

App = { api_version = 1 }
function App.add_system(name, schedule, query, handler)
  return System.add(name, schedule, query, handler)
end

function Node.add_component(entity, component, data)
  return add_component(entity, component, Component.new(component, data))
end

Prefab = {}
function Prefab.define(name, factory) __node_prefabs[name] = factory end
function Prefab.has(name) return __node_prefabs[name] ~= nil end
function Prefab.instantiate(name, path, x, y, z)
  local factory = __node_prefabs[name]
  if factory == nil then error("Unknown Lua prefab: " .. tostring(name)) end
  local entity = _engine_instantiate_empty(name, path, x or 0, y or 0, z or 0)
  factory(entity)
  return entity
end
function instantiate(name, path, x, y, z)
  return Prefab.instantiate(name, path, x, y, z)
end

$source

function __node_dispatch(callback, entity, delta)
  local handler = _G[callback]
  if handler ~= nil then
    return handler(entity, delta)
  end
end

function __node_ready(entity)
  __node_run_systems("startup", entity, 0)
  return __node_dispatch("ready", entity, 0)
end

function __node_tick(schedule, entity, delta)
  if schedule == "update" then __node_run_systems("pre_update", entity, delta) end
  __node_run_systems(schedule, entity, delta)
  local result = __node_dispatch(schedule, entity, delta)
  if schedule == "update" then __node_run_systems("post_update", entity, delta) end
  return result
end

function __node_signal(entity, name, source, payload)
  if signal_received ~= nil then
    return signal_received(entity, name, source, payload)
  end
end

function __node_timeout(entity, name)
  if timeout ~= nil then return timeout(entity, name) end
end
''', scriptPath: scriptPath);
  }

  Future<Object?> ready(Entity entity) =>
      _lua.call('__node_ready', [entity.id]);
  Future<Object?> update(Entity entity, double delta) =>
      _lua.call('__node_tick', ['update', entity.id, delta]);
  Future<Object?> fixedUpdate(Entity entity, double delta) async {
    final expired = <String>[];
    for (final entry in _timers.entries.toList()) {
      entry.value.remaining -= delta;
      if (entry.value.remaining > 0) continue;
      expired.add(entry.key);
      if (entry.value.repeating) {
        entry.value.remaining += entry.value.duration;
      } else {
        _timers.remove(entry.key);
      }
    }
    for (final name in expired) {
      await _lua.call('__node_timeout', [entity.id, name]);
    }
    return _lua.call('__node_tick', ['fixed_update', entity.id, delta]);
  }

  Future<Object?> signalReceived(Entity entity, LuaSignal signal) => _lua.call(
    '__node_signal',
    [entity.id, signal.name, signal.source, signal.payload],
  );

  MoveDirection _direction(String value) => switch (value) {
    'left' => MoveDirection.left,
    'right' => MoveDirection.right,
    'up' => MoveDirection.up,
    'down' => MoveDirection.down,
    _ => MoveDirection.none,
  };

  Object? _unwrapScalar(Object? value) {
    final raw = value is Value ? value.unwrap() : value;
    return raw is num || raw is String || raw is bool || raw == null
        ? raw
        : raw.toString();
  }

  Object? _deepUnwrap(Object? value) {
    final raw = value is Value ? value.unwrap() : value;
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          entry.key.toString(): _deepUnwrap(entry.value),
      };
    }
    if (raw is List) return raw.map(_deepUnwrap).toList();
    return raw;
  }

  Map<String, Object?> _stringObjectMap(Object? value) {
    final raw = _deepUnwrap(value);
    if (raw == null) return {};
    if (raw is! Map) {
      throw ArgumentError.value(
        value,
        'data',
        'Component data must be a table',
      );
    }
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }

  List<String> _stringList(Object? value) {
    final raw = _deepUnwrap(value);
    if (raw == null) return const <String>[];
    if (raw is List) return raw.map((item) => item.toString()).toList();
    if (raw is Map) {
      final entries = raw.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString()) ?? 0;
          final bi = int.tryParse(b.key.toString()) ?? 0;
          return ai.compareTo(bi);
        });
      return entries.map((entry) => entry.value.toString()).toList();
    }
    return <String>[raw.toString()];
  }

  bool _matchesScriptQuery(
    Entity entity,
    List<String> withComponents,
    List<String> withoutComponents,
  ) {
    bool has(String name) {
      if (name == 'transform') return engine.world.has<Transform3>(entity);
      if (name == 'properties') {
        return engine.world.has<ScriptProperties>(entity);
      }
      if (name == 'groups') return engine.world.has<ScriptGroups>(entity);
      return engine.world
              .maybeGet<ScriptComponents>(entity)
              ?.values
              .containsKey(name) ??
          false;
    }

    return withComponents.every(has) && !withoutComponents.any(has);
  }

  double _mapNumber(Map<String, Object?> values, String key, double fallback) =>
      switch (values[key]) {
        final num value => value.toDouble(),
        _ => fallback,
      };

  ScenePrimitive _scenePrimitive(String? value) => switch (value) {
    'sphere' => ScenePrimitive.sphere,
    'icosphere' => ScenePrimitive.icosphere,
    'plane' => ScenePrimitive.plane,
    'cylinder' => ScenePrimitive.cylinder,
    'capsule' => ScenePrimitive.capsule,
    'torus' => ScenePrimitive.torus,
    'disc' => ScenePrimitive.disc,
    'ring' => ScenePrimitive.ring,
    'wedge' => ScenePrimitive.wedge,
    _ => ScenePrimitive.box,
  };

  SceneMaterialKind _sceneMaterialKind(String? value) => switch (value) {
    'pbr' || 'physically_based' => SceneMaterialKind.physicallyBased,
    'sprite' => SceneMaterialKind.sprite,
    'shader' => SceneMaterialKind.shader,
    'fmat' => SceneMaterialKind.fmat,
    _ => SceneMaterialKind.unlit,
  };

  SceneLightKind _sceneLightKind(String? value) => switch (value) {
    'directional' => SceneLightKind.directional,
    'spot' => SceneLightKind.spot,
    'area' || 'rect_area' => SceneLightKind.area,
    _ => SceneLightKind.point,
  };

  void _replaceComponent<T extends Object>(Entity entity, T component) {
    if (engine.world.has<T>(entity)) engine.world.remove<T>(entity);
    engine.world.add<T>(entity, component);
  }

  ScriptProperties _properties(Entity entity) {
    final existing = engine.world.maybeGet<ScriptProperties>(entity);
    if (existing != null) return existing;
    final created = ScriptProperties();
    engine.world.add(entity, created);
    return created;
  }

  ScriptGroups _groups(Entity entity) {
    final existing = engine.world.maybeGet<ScriptGroups>(entity);
    if (existing != null) return existing;
    final created = ScriptGroups();
    engine.world.add(entity, created);
    return created;
  }

  ScriptDrawings _drawings(Entity entity) {
    final existing = engine.world.maybeGet<ScriptDrawings>(entity);
    if (existing != null) return existing;
    final created = ScriptDrawings();
    engine.world.add(entity, created);
    return created;
  }

  ScriptHud _hud(Entity entity) {
    final existing = engine.world.maybeGet<ScriptHud>(entity);
    if (existing != null) return existing;
    final created = ScriptHud();
    engine.world.add(entity, created);
    return created;
  }

  ScriptParticleEmitters _particles(Entity entity) {
    final existing = engine.world.maybeGet<ScriptParticleEmitters>(entity);
    if (existing != null) return existing;
    final created = ScriptParticleEmitters();
    engine.world.add(entity, created);
    return created;
  }

  ScriptComponents _scriptComponents(Entity entity) {
    final existing = engine.world.maybeGet<ScriptComponents>(entity);
    if (existing != null) return existing;
    final created = ScriptComponents();
    engine.world.add(entity, created);
    return created;
  }
}

class _ScriptTimer {
  _ScriptTimer(this.duration, this.repeating) : remaining = duration;

  final double duration;
  final bool repeating;
  double remaining;
}
