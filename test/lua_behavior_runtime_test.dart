import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/runtime.dart';
import 'package:node/engine/scene_tree.dart';
import 'package:node/game/components.dart';
import 'package:node/scripting/lua_behavior_runtime.dart';

void main() {
  test(
    'Lua behavior can mutate an entity through the restricted bridge',
    () async {
      final engine = EngineContext();
      final entity = engine.world.create([Transform3(1, 0, 2)]);
      final lua = LuaBehaviorRuntime(engine);
      await lua.load('''
      function fixed_update(entity, delta)
        entity_set_position(entity, entity_get_x(entity) + delta, 0, entity_get_z(entity))
      end
    ''');

      await lua.fixedUpdate(entity, .5);

      expect(engine.world.get<Transform3>(entity).x, 1.5);
    },
  );

  test('Lua behavior owns exported properties, groups, and timers', () async {
    final engine = EngineContext();
    final entity = engine.world.create([
      Transform3(1, 0, 2),
      ScriptProperties({'mood': 'asleep'}),
      ScriptGroups(['enemies']),
    ]);
    final signals = <LuaSignal>[];
    final lua = LuaBehaviorRuntime(engine, emitSignal: signals.add);
    await lua.load('''
      function ready(entity)
        entity_set_property(entity, 'mood', 'awake')
        entity_add_to_group(entity, 'flying')
        set_timer('howl', 0.1, false)
      end

      function timeout(entity, name)
        entity_set_property(entity, 'last_timer', name)
        emit_signal(entity, 'howled', entity_get_property(entity, 'mood'))
      end
    ''');

    await lua.ready(entity);
    await lua.fixedUpdate(entity, .2);

    final properties = engine.world.get<ScriptProperties>(entity).values;
    expect(properties['mood'], 'awake');
    expect(properties['last_timer'], 'howl');
    expect(engine.world.get<ScriptGroups>(entity).values, contains('flying'));
    expect(signals.single.name, 'howled');
    expect(signals.single.payload, 'awake');
  });

  test('Lua can inspect components and query entity groups', () async {
    final engine = EngineContext();
    final entity = engine.world.create([
      Transform3(1, 0, 2),
      ScriptProperties(),
      ScriptGroups(['enemies']),
    ]);
    engine.world.create([
      Transform3(4, 0, 2),
      ScriptGroups(['enemies']),
    ]);
    final lua = LuaBehaviorRuntime(engine);
    await lua.load('''
      function ready(entity)
        entity_set_property(entity, 'enemy_count', group_count('enemies'))
        entity_set_property(entity, 'has_transform', entity_has_component(entity, 'transform'))
        entity_set_property(entity, 'nearest', group_nearest('enemies', 0, 2))
      end
    ''');

    await lua.ready(entity);

    final properties = engine.world.get<ScriptProperties>(entity).values;
    expect(properties['enemy_count'], 2);
    expect(properties['has_transform'], isTrue);
    expect(properties['nearest'], entity.id);
  });

  test('Lua creates and animates procedural drawing components', () async {
    final engine = EngineContext();
    final entity = engine.world.create([Transform3(0, 0, 0)]);
    final lua = LuaBehaviorRuntime(engine);
    await lua.load('''
      function ready(entity)
        entity_add_component(entity, 'drawings')
        draw_sphere(entity, 'aura', 0, 0.2, 0, 0.5, '#31e7ff')
        drawing_set_animation(entity, 'aura', 'pulse', 4, 0.2)
        draw_box(entity, 'rune', 0, 0.8, 0, 0.1, 0.3, 0.1, '#b35cff')
      end
    ''');

    await lua.ready(entity);

    final drawings = engine.world.get<ScriptDrawings>(entity).values;
    expect(drawings.keys, containsAll(['aura', 'rune']));
    expect(drawings['aura']!.shape, ScriptPrimitiveShape.sphere);
    expect(drawings['aura']!.animation, 'pulse');
    expect(drawings['aura']!.animationSpeed, 4);
    expect(drawings['rune']!.shape, ScriptPrimitiveShape.box);
  });

  test('Lua creates, updates, and removes HUD components', () async {
    final engine = EngineContext();
    final root = engine.world.create();
    final lua = LuaBehaviorRuntime(engine);
    await lua.load('''
      function ready(root)
        entity_add_component(root, 'hud')
        hud_label(root, 'score', 'SCORE 00100', 'top_right', 20, 20, '#ffffff', 14)
        hud_bar(root, 'power', 3, 7, 'top_right', 20, 60, '#b35cff', 220, 8)
      end
    ''');

    await lua.ready(root);

    final hud = engine.world.get<ScriptHud>(root);
    expect(hud.elements['score']!.text, 'SCORE 00100');
    expect(hud.elements['score']!.anchor, 'top_right');
    expect(hud.elements['power']!.value, 3);
    expect(hud.elements['power']!.maximum, 7);
    expect(hud.elements['power']!.width, 220);
  });

  test('Lua instantiates prefabs into the scene tree at runtime', () async {
    final engine = EngineContext();
    final root = engine.world.create([ScriptProperties()]);
    final tree = SceneTree()..register('/root', root);
    final lua = LuaBehaviorRuntime(engine, sceneTree: tree);
    await lua.load('''
      Prefab.define('wisp', function(entity)
        draw_sphere(entity, 'core', 0, 0.28, 0, 0.16, '#31e7ff')
        Node.add_component(entity, 'guide', { role = 'pathfinder' })
      end)
      Prefab.define('bolt', function(entity)
        Node.add_component(entity, 'projectile', { damage = 2, hurts_player = true })
      end)

      function ready(root)
        local wisp = instantiate('wisp', '/root/effects/guide', 3, 0.2, 7)
        local bolt = instantiate('bolt', '/root/projectiles/test', 2, 0.2, 2)
        entity_set_velocity(bolt, 1, 0, -2, 4)
        entity_set_property(wisp, 'purpose', 'guide')
        entity_set_property(root, 'spawned', #get_nodes_in_group('script_spawned'))
        entity_set_property(root, 'wisp', get_node('/root/effects/guide'))
      end
    ''');

    await lua.ready(root);

    final wisp = tree.getNode('/root/effects/guide')!;
    expect(engine.world.get<Transform3>(wisp).x, 3);
    expect(engine.world.get<Transform3>(wisp).z, 7);
    expect(engine.world.get<ScriptProperties>(wisp).values['purpose'], 'guide');
    expect(engine.world.get<ScriptDrawings>(wisp).values, contains('core'));
    expect(
      engine.world.get<ScriptGroups>(wisp).values,
      contains('script_spawned'),
    );
    expect(engine.world.get<ScriptProperties>(root).values['spawned'], 2);
    expect(engine.world.get<ScriptProperties>(root).values['wisp'], wisp.id);
    final bolt = tree.getNode('/root/projectiles/test')!;
    expect(
      engine.world.get<ScriptComponents>(bolt).values['projectile']?['damage'],
      2,
    );
    expect(engine.world.get<ScriptVelocity>(bolt).z, -2);
    expect(engine.world.get<ScriptVelocity>(bolt).remainingSeconds, 4);
  });

  test('Godot-like Lua API creates and queries game components', () async {
    final engine = EngineContext();
    final root = engine.world.create([ScriptProperties()]);
    final lua = LuaBehaviorRuntime(engine);
    await lua.load('''
      function ready(root)
        Node.add_component(root, 'dialogue', { speaker = 'Oracle', line = 3 })
        Node.set_value(root, 'dialogue', 'mood', 'ominous')
        entity_set_property(root, 'found', #SceneTree.get_nodes_with_component('dialogue'))
        entity_set_property(root, 'speaker', Node.get_value(root, 'dialogue', 'speaker'))
      end
    ''');

    await lua.ready(root);

    final component = engine.world
        .get<ScriptComponents>(root)
        .values['dialogue']!;
    expect(component, containsPair('mood', 'ominous'));
    expect(engine.world.get<ScriptProperties>(root).values['found'], 1);
    expect(
      engine.world.get<ScriptProperties>(root).values['speaker'],
      'Oracle',
    );
  });

  test('Lua controls door and trap components', () async {
    final engine = EngineContext();
    final root = engine.world.create([ScriptProperties()]);
    final door = engine.world.create([DoorTag(), ScriptProperties()]);
    final trap = engine.world.create([TrapTag(), ScriptProperties()]);
    final lua = LuaBehaviorRuntime(engine);
    await lua.load('''
      function ready(root)
        door_set_open(${door.id}, true)
        trap_set_active(${trap.id}, false)
        entity_set_property(root, 'door_open', door_is_open(${door.id}))
      end
    ''');

    await lua.ready(root);

    expect(engine.world.get<DoorTag>(door).open, isTrue);
    expect(engine.world.get<TrapTag>(trap).active, isFalse);
    expect(
      engine.world.get<ScriptProperties>(root).values['door_open'],
      isTrue,
    );
  });

  test('Lua creates, updates, and clears particle emitters', () async {
    final engine = EngineContext();
    final entity = engine.world.create();
    final lua = LuaBehaviorRuntime(engine);
    await lua.load('''
      function ready(entity)
        particle_emitter(entity, 'aura', 24, 1.2, 2.5, 0.05, '#31e7ff', 'orbit')
        particle_emitter(entity, 'too_many', 999, 2, 1, 0.1, '#ffffff', 'burst')
        particle_emitter(entity, 'flash', 8, 1, 3, 0.05, '#ffffff', 'burst', 0.4)
        particle_remove(entity, 'too_many')
      end
    ''');

    await lua.ready(entity);

    final particles = engine.world.get<ScriptParticleEmitters>(entity).values;
    expect(particles, hasLength(2));
    expect(particles['aura']!.count, 24);
    expect(particles['aura']!.radius, 1.2);
    expect(particles['aura']!.speed, 2.5);
    expect(particles['aura']!.pattern, 'orbit');
    expect(particles['flash']!.remainingSeconds, 0.4);
  });
}
