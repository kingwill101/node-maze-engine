# Lua gameplay scripting

Each scripted entity owns an isolated Lua VM and receives Godot-style lifecycle
callbacks. Structural ECS changes are deferred and cross-entity signals are
queued until the next safe scripting tick.

## Scene tree and autoload

`assets/lua/autoload.lua` is attached to `/root` before enemy scripts for every
level. It is the default scene coordinator and receives the same lifecycle,
timer, and signal callbacks as entity behaviors.

```lua
local player = get_node('/root/player')
local ruby = get_node('/root/enemies/Ruby')
local first_portal = get_node('/root/portals/1')

if has_node('/root/player') then
  entity_set_property(player, 'scene_ready', true)
end

local path = get_node_path(player)
local paths = get_scene_paths()
```

Lua can define and instantiate prefabs at runtime and immediately address them
through the scene tree. The demo definitions live in `assets/lua/prefabs.lua`;
they are ordinary scripts rather than hard-coded Dart recipes:

```lua
Prefab.define('wisp', function(entity)
  draw_sphere(entity, 'core', 0, 0.28, 0, 0.16, '#31e7ff')
  Node.add_component(entity, 'guide', { role = 'pathfinder' })
end)

local wisp = Prefab.instantiate('wisp', '/root/effects/guide', 4, 0.2, 7)
local spawned = SceneTree.get_nodes_in_group('script_spawned')
Node.queue_free(wisp)
```

Built-in visual recipes are `wisp`, `rune`, `orb`, `bolt`, `boss`, and `empty`. The demo
autoload creates two guide wisps and a rotating spawn rune on every map.
`entity_set_velocity(entity, vx, vy, vz, lifetime)` turns a spawned entity into
a simulated moving object. The `bolt` recipe attaches a Lua `projectile`
component whose damage settings are consumed by the native collision kernel.
Dreamseed 7331 uses these APIs for a three-phase Dream Warden boss that aims and
fires entirely from the Lua autoload.

Node paths are stable aliases over flat ECS entities; they do not introduce a
second ownership model. Current default paths include `/root`, `/root/player`,
`/root/enemies/<name>`, and `/root/portals/<index>`.

Player portal traversal is implemented in the autoload itself: `fixed_update`
resolves the paired portal NodePaths, checks proximity, teleports through the
transform API, maintains a Lua cooldown, and emits `portal_entered`. The Dart
portal system is now only a native fallback for unscripted moving actors.

## Lifecycle

```lua
function ready(entity) end
function update(entity, delta) end
function fixed_update(entity, delta) end
function timeout(entity, timer_name) end
function signal_received(entity, signal_name, source, payload) end
```

## Node, SceneTree, and component API

The preferred surface resembles Godot scripting while keeping entity ids as
lightweight node handles:

```lua
local player = Node.get('/root/player')
Node.add_to_group(player, 'heroes')
Node.add_component(player, 'inventory', { keys = 0, spell = 'none' })
Node.set_value(player, 'inventory', 'keys', 1)

if Node.has_component(player, 'inventory') then
  local inventory = Node.get_component(player, 'inventory')
end

local inventories = SceneTree.get_nodes_with_component('inventory')
local enemies = SceneTree.get_nodes_in_group('enemies')
```

Named Lua components can contain tables, lists, strings, booleans, and numbers.
They let games introduce dialogue, quests, health, loot, or AI state without
declaring matching Dart types. Native names such as `transform`, `mover`, and
`ghost` remain introspectable through `Node.has_component`.

The lower-level compatibility functions remain available:

```lua
entity_is_alive(entity)
entity_has_component(entity, 'transform')
entity_get_x(entity)
entity_get_z(entity)
entity_set_position(entity, x, y, z)
entity_request_move(entity, 'left')
entity_can_move(entity, 'up')
entity_destroy(entity) -- deferred
door_set_open(door, true)
door_is_open(door)
trap_set_active(trap, false)
```

Native component names include `transform`, `mover`, `player`, `ghost`,
`properties`, `groups`, and `drawings`. Scripts may dynamically add or remove
the `properties`, `groups`, and `drawings` bridge components:

```lua
entity_add_component(entity, 'drawings')
entity_remove_component(entity, 'drawings')
```

Native operations remain the capability boundary; game-defined named
components are deliberately open-ended data.

## Dungeon interactions and combat

Level tables accept `K` for Star Keys, `|` for locked doors, and `^` for rift
traps. They are registered in the `keys`, `doors`, and `traps` groups. Native
collision emits `key_collected` and `trap_triggered`; the production autoload
responds to `key_collected` by opening door entities with `door_set_open`.
Pressing F creates a player projectile and emits `player_fired`. Player bolts
reset ghosts and award points, while hostile Lua `bolt` prefabs damage the
player.

## Runtime inspector

Press I during play to open the live scene/ECS inspector. It shows every stable
NodePath, entity id, attached gameplay components, Lua groups, and exported
properties. Nodes created with `instantiate` appear immediately, making it
possible to debug autoloads, boss phases, projectiles, doors, and signals while
the Flutter Scene simulation continues running.

## Flutter HUD drawing

Lua can compose named Flutter HUD labels and progress bars. Reusing a name
updates the element on the next frame.

```lua
entity_add_component(root, 'hud')
hud_label(root, 'score', 'SCORE 00100', 'top_right', 20, 20, '#ffffff', 14)
hud_bar(root, 'power', 3, 7, 'top_right', 20, 62, '#b35cff', 220, 8)
hud_remove(root, 'power')
hud_clear(root)
```

Anchors currently support `top_left`, `top_right`, `bottom_left`, and
`bottom_right`. Lua owns composition and live values; Flutter renders accessible
text and native progress indicators rather than exposing widget or GPU objects
to the VM. The production score/lives/spell panel and power meter are authored
by `autoload.lua`.

## Procedural drawing

Lua can author named Flutter Scene primitives attached to its entity in real
time. Reusing a name updates that primitive.

```lua
draw_sphere(entity, 'aura', 0, 0.2, 0, 0.5, '#31e7ff')
draw_box(entity, 'rune', 0, 0.8, 0, 0.1, 0.3, 0.1, '#b35cff')
drawing_set_animation(entity, 'aura', 'pulse', 4, 0.2)
drawing_remove(entity, 'rune')
drawing_clear(entity)
```

Animations are `none`, `pulse`, `orbit`, `float`, and `spin`. Drawing data is
stored as an ECS component; Flutter Scene remains responsible for geometry and
materials, so Lua never receives unsafe GPU objects.

## Particle emitters

Lua can attach deterministic, renderer-side particle fields without owning GPU
resources. Emitters update by name and are safe to create during signals:

```lua
particle_emitter(entity, 'aura', 24, 1.2, 2.0, 0.05, '#31e7ff', 'orbit')
particle_emitter(entity, 'impact', 32, 1.5, 4.0, 0.06, '#ff3970', 'burst')
particle_remove(entity, 'impact')
particle_clear(entity)
```

Patterns are `orbit`, `fountain`, `burst`, and velocity-aware `trail`. Counts
are capped at 64 per emitter. The production Lua scripts use them for ghost
ectoplasm, spawn fountains, spell shards, boss rage, and projectile trails.
Arcane meshes use the compiled `arcane_energy.fmat` heartbeat/interference
shader; its phase and power intensity are updated every Flutter Scene frame.

## Exported properties

`ScriptProperties` is analogous to Godot exported script variables: Dart can
author defaults, Lua can mutate them, and rendering or systems can inspect them.

```lua
local aggression = entity_get_property(entity, 'aggression')
entity_set_property(entity, 'state', 'frightened')
```

Values crossing this bridge are deliberately limited to numbers, strings,
booleans, and nil.

## Groups

```lua
entity_add_to_group(entity, 'flying')
entity_remove_from_group(entity, 'flying')
entity_is_in_group(entity, 'enemies')
group_count('enemies')
local nearest = group_nearest('enemies', x, z)
```

## Signals and timers

```lua
set_timer('attack', 1.5, true)
cancel_timer('attack')
emit_signal(entity, 'attack_started', 'laser')

function timeout(entity, name)
  if name == 'attack' then
    emit_signal(entity, 'attack_started', 'laser')
  end
end

function signal_received(entity, name, source, payload)
  if name == 'attack_started' then
    entity_set_property(entity, 'alerted_by', source)
  end
end
```

Signals are broadcast to attached behaviors without sharing Lua globals. Timers
advance on fixed simulation time, so pausing the game pauses script timers too.

## Game-specific sensing

The current maze game additionally exposes `player_get_x`, `player_get_z`,
`player_get_dx`, `player_get_dz`, `power_active`, `ghost_personality`, and
`entity_request_target`. These are domain capabilities layered over the generic
entity scripting surface.

## Demo mechanics

Lua level tiles may include a paired `T` portal and `s` Star Pulse pickup. The
pickup grants a charge shown in the HUD; pressing Q broadcasts
`player_cast_spell` to isolated enemy VMs and briefly activates frightened
mode. The production ghost script responds by creating a spinning white shock
rune and removes it from a Lua timer callback.
