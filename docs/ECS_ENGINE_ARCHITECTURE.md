# Node ECS engine architecture

Node is a Lua-first, Bevy-inspired ECS application framework hosted by Dart.
Dart owns deterministic scheduling, data storage and performance-critical
plugins. Lua owns game composition, components, prefabs, systems and rules.

## Core application

`GameApp` owns one `EngineContext` and the standard lifecycle schedules:

1. `startup` (once)
2. `first`
3. `preUpdate`
4. `fixedFirst`
5. `fixedPreUpdate`
6. `fixedUpdate`
7. `fixedPostUpdate`
8. `fixedLast`
9. `update`
10. `postUpdate`
11. `last`

Fixed schedules consume accumulated time deterministically. Systems can carry a
stable label, declare `before` and `after` constraints, and have a run
condition. Invalid dependencies and cycles fail before gameplay proceeds.

`EngineRuntime` is the compatibility host used by the existing games. Its old
`fixedSystems` and `frameSystems` lists are adapters installed in `GameApp`, so
new plugins and old systems execute against the same world and resources.

## ECS concepts

- `World`: flat entities and typed Dart components.
- `Resources`: type-indexed singleton data.
- `Commands`: structural changes deferred to schedule boundaries.
- `EventBus`: typed immediate application events. Buffered event readers are a
  future extension.
- `GamePlugin`: idempotent installation of systems, resources and other
  plugins.
- `StateMachine<T>`: deferred typed state changes with transition events.
- `SceneTree`: optional stable paths over flat ECS entities for Lua and tools.

The current storage is sparse type maps. It is deliberately behind `World` so
an archetype/table backend can replace it later without changing game scripts.

## Lua-first authoring

LuaLike hosts receive all Dart functions as `List<Object?>`; the bridge never
registers scalar-argument Dart closures.

Lua currently supports:

```lua
Component.define("velocity", { x = 0, y = 0, z = 0 })
Resource.insert("difficulty", { multiplier = 1.5 })

App.add_system("movement", "fixed_update", {
  with = { "transform", "velocity" },
  without = { "paused" },
}, function(entities, delta)
  for _, entity in ipairs(entities) do
    local velocity = World.get(entity, "velocity")
    entity_set_position(
      entity,
      entity_get_x(entity) + velocity.x * delta,
      entity_get_y(entity) + velocity.y * delta,
      entity_get_z(entity) + velocity.z * delta
    )
  end
end)
```

The Lua surface includes `App`, `System`, `World`, `Commands`, `Component`,
`Resource`, `Node`, `SceneTree` and `Prefab`. Existing `ready`, `update` and
`fixed_update` callbacks remain compatible and run alongside registered
systems.

## Plugin boundary

`DefaultPlugins` is the reusable baseline and currently installs:

- `TimePlugin`: separate render-frame and deterministic fixed-step clocks;
- `InputPlugin`: platform-neutral button transitions and named action maps;
- `TransformPlugin`: local/global transforms plus parent/children propagation.

Platform adapters feed stable button codes into `ButtonInput<String>` before
`GameApp.update`. Game code consumes named actions through `ActionInput`, so
keyboard, controller and touch mappings do not leak into gameplay systems.

Hierarchy is represented by `Parent` and `Children`, while
`TransformPropagationSystem` computes `GlobalTransform` from `LocalTransform`.
Cycles and references to dead parents fail loudly rather than producing corrupt
render transforms.

`SceneRenderPlugin` performs a distinct extraction stage in the `last`
schedule. It copies gameplay-side mesh, material, light, camera, asset,
particle and environment components into an immutable `ExtractedScene`. The
`FlutterSceneAdapter` realizes that snapshot with cached Flutter Scene geometry
and light components. This separation keeps GPU objects out of the ECS world
and makes an alternate renderer or headless server possible.

Game-specific rules must move out of the host application. The intended plugin
layers are:

- core: time, schedules, state, events and hierarchy;
- platform: input, persistence, window and lifecycle;
- scene: render extraction and Flutter Scene realization;
- assets: handles, loading, caching and hot reload;
- physics: generic colliders plus optional optimized backends;
- audio: buses, spatial sources and music;
- scripting: Lua VMs, schemas, systems and script reload;
- UI: Lua-authored HUD and menus;
- game packages: Pac-Man, Moonfall and Brasscap rules only.

Native Dart systems and Lua systems share component data. A game can replace a
Lua system with an identically-labelled native plugin after profiling without
rewriting its scenes or entities.
