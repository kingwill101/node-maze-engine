import 'package:lualike/lualike.dart';

import '../engine/entity.dart';
import '../engine/runtime.dart';
import '../engine/scene_tree.dart';
import '../game/components.dart';

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
  final Map<String, _ScriptTimer> _timers = {};

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
    _expose('instantiate', (args) {
      final prefab = _string(args, 0);
      final path = _string(args, 1);
      final entity = engine.world.create([
        Transform3(_number(args, 2), _number(args, 3), _number(args, 4)),
        ScriptProperties({'prefab': prefab}),
        ScriptGroups(['script_spawned', prefab]),
        ScriptDrawings(),
      ]);
      sceneTree?.register(path, entity);
      _applyPrefab(entity, prefab);
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
      return switch (_string(args, 1)) {
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
        _ => false,
      };
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
    _expose('door_set_open', (args) {
      final entity = _entity(args);
      final open = _scalar(args, 1) == true;
      engine.world.get<DoorTag>(entity).open = open;
      _properties(entity).values['open'] = open;
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
  ) => _lua.expose(name, callback);

  Object? _argument(List<Object?> arguments, int index) {
    if (index >= arguments.length) return null;
    final value = arguments[index];
    return value is Value ? value.unwrap() : value;
  }

  Entity _entity(List<Object?> arguments, [int index = 0]) =>
      Entity((_argument(arguments, index) as num).toInt());

  double _number(List<Object?> arguments, int index) =>
      (_argument(arguments, index) as num).toDouble();

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
$source

function __node_dispatch(callback, entity, delta)
  local handler = _G[callback]
  if handler ~= nil then
    return handler(entity, delta)
  end
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

  Future<Object?> ready(Entity entity) => _dispatch('ready', entity, 0);
  Future<Object?> update(Entity entity, double delta) =>
      _dispatch('update', entity, delta);
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
    return _dispatch('fixed_update', entity, delta);
  }

  Future<Object?> signalReceived(Entity entity, LuaSignal signal) => _lua.call(
    '__node_signal',
    [entity.id, signal.name, signal.source, signal.payload],
  );

  Future<Object?> _dispatch(String callback, Entity entity, double delta) =>
      _lua.call('__node_dispatch', [callback, entity.id, delta]);

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

  void _applyPrefab(Entity entity, String prefab) {
    final drawings = _drawings(entity).values;
    switch (prefab) {
      case 'wisp':
        drawings['core'] =
            ScriptDrawing(
                name: 'core',
                shape: ScriptPrimitiveShape.sphere,
                x: 0,
                y: .28,
                z: 0,
                scaleX: .16,
                scaleY: .16,
                scaleZ: .16,
                color: '#31e7ff',
              )
              ..animation = 'float'
              ..animationSpeed = 2.4
              ..animationAmount = .18;
      case 'rune':
        drawings['glyph'] =
            ScriptDrawing(
                name: 'glyph',
                shape: ScriptPrimitiveShape.box,
                x: 0,
                y: .32,
                z: 0,
                scaleX: .08,
                scaleY: .32,
                scaleZ: .08,
                color: '#b35cff',
              )
              ..animation = 'spin'
              ..animationSpeed = 1.8;
      case 'orb':
        drawings['orb'] =
            ScriptDrawing(
                name: 'orb',
                shape: ScriptPrimitiveShape.sphere,
                x: 0,
                y: .3,
                z: 0,
                scaleX: .24,
                scaleY: .24,
                scaleZ: .24,
                color: '#ffd45c',
              )
              ..animation = 'pulse'
              ..animationSpeed = 3
              ..animationAmount = .22;
      case 'bolt':
        engine.world.add(entity, const ScriptProjectileTag());
        _particles(entity).values['trail'] = ScriptParticleEmitter(
          name: 'trail',
          count: 10,
          radius: .65,
          speed: 3.5,
          size: .045,
          color: '#ff3970',
          pattern: 'trail',
        );
        drawings['bolt'] =
            ScriptDrawing(
                name: 'bolt',
                shape: ScriptPrimitiveShape.sphere,
                x: 0,
                y: .25,
                z: 0,
                scaleX: .13,
                scaleY: .13,
                scaleZ: .13,
                color: '#ff3970',
              )
              ..animation = 'pulse'
              ..animationSpeed = 10
              ..animationAmount = .3;
      case 'boss':
        engine.world.add(entity, const BossTag());
        _particles(entity).values['void_crown'] = ScriptParticleEmitter(
          name: 'void_crown',
          count: 24,
          radius: 1.1,
          speed: 1.4,
          size: .055,
          color: '#b35cff',
          pattern: 'orbit',
        );
        drawings['body'] =
            ScriptDrawing(
                name: 'body',
                shape: ScriptPrimitiveShape.sphere,
                x: 0,
                y: .55,
                z: 0,
                scaleX: .72,
                scaleY: .72,
                scaleZ: .72,
                color: '#b35cff',
              )
              ..animation = 'float'
              ..animationSpeed = 1.6
              ..animationAmount = .16;
        drawings['crown'] =
            ScriptDrawing(
                name: 'crown',
                shape: ScriptPrimitiveShape.box,
                x: 0,
                y: 1.35,
                z: 0,
                scaleX: .48,
                scaleY: .08,
                scaleZ: .48,
                color: '#ffd45c',
              )
              ..animation = 'spin'
              ..animationSpeed = 1.2;
      case 'empty':
        break;
      default:
        throw ArgumentError.value(prefab, 'prefab', 'Unknown Lua prefab');
    }
  }
}

class _ScriptTimer {
  _ScriptTimer(this.duration, this.repeating) : remaining = duration;

  final double duration;
  final bool repeating;
  double remaining;
}
