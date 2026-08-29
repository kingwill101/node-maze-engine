# Node Game Center

A Flutter-native 3D game engine and game center containing Node Maze, the 2.5D
action-platformer Moonfall Courier, the independently packaged Lua game Signal
Garden, and the bright classic-style 2.5D platformer Brasscap Run.

Play the web build at **https://kingwill101.github.io/node-maze-engine/**.

## Stack

- Flutter Scene for realtime 3D rendering, assets, materials, and animation.
- A small renderer-independent ECS in `lib/engine`.
- LuaLike for isolated, data-driven Godot-style behavior scripts.
- A deterministic 60 Hz gameplay simulation with render interpolation support.
- ImageGen character direction with checked-in modeling references and HUD art.

## Run

```sh
fvm flutter pub get
fvm flutter run -d macos --enable-flutter-gpu
```

Move with arrow keys or WASD. Press F to fire, Q to cast Star Pulse, V/Tab to
switch camera, I for the live scene inspector, M for map select, and P/Escape
to pause.

**Moonfall Courier** is a three-chapter Lua-authored platformer campaign. Move
with A/D or Left/Right, jump with Space/W/Up, and fire a Star Bolt with F.
Collect every crystal, activate checkpoint lanterns, avoid moon thorns, defeat
patrolling Thorn Runners, and reach each gate. Chapters advance with Enter.
Its chapters span 76, 106, and 136 world units; Lua expands compact height
patterns into 14, 20, and 26 reachable platform sections with paced encounters.
Completed chapters unlock the next destination and are saved across launches on
web and native. The Game Center accessibility menu persists reduced-motion and
high-contrast preferences in the same versioned save.

Moonfall includes an original procedural soundscape: a looping lunar ambience
and synthesized cues for jumps, Star Bolts, crystals, damage, checkpoint
lanterns, and the ending. Run `fvm dart tool/generate_audio.dart` to regenerate
the deterministic PCM assets. Audio can be disabled from the accessibility
menu and the choice persists with campaign progress.

**Brasscap Run** is an original genre homage rather than a copy of Nintendo
assets or layouts. Its three Lua-authored chapters use a manifest-selected
bright 3D environment and scripted player renderer. The package generates
grass-and-brick routes, brass gear pickups, stompable tick-beetles, springs,
moving lifts, checkpoints, and finish bells without a game-ID branch in Dart.
Its source lives under `assets/games/brasscap_run/`.

Flutter Scene uses Flutter GPU on native platforms, so native `flutter run`
commands may include `--enable-flutter-gpu`. The app manifests also enable it
for macOS, iOS, and Android, so debug/profile/release builds work when launched
without the flag. The web backend uses WebGL2 and does not need it.

## Architecture

The engine kernel owns storage, deterministic simulation, collision, input,
Flutter Scene rendering, and GPU resources. Lua is the game-authoring layer:
scripts define prefabs, attach arbitrary named components, coordinate scenes,
draw procedural objects and HUDs, and implement behavior. The public Lua API
uses familiar `Node`, `SceneTree`, and `Prefab` concepts while the ECS remains
an internal, renderer-independent implementation detail. Structural changes
are command-buffered until the end of a system tick, making queries safe for
Dart and Lua behaviors.

The first vertical slice includes typed components, one- and two-component queries, fixed and
frame systems, an event bus, Godot-style behavior lifecycle contracts, a restricted Lua-to-ECS
bridge, a maze, movement, joined wall geometry, pellets, scoring, and a procedural Flutter Scene
presentation.

`PhysicsPlugin` binds ECS entities to Flutter Scene's pluggable
`PhysicsSimulation` contract. `PhysicsBody3d` and `PhysicsCollider3d` support
fixed, kinematic, and solver-backed dynamic bodies; every Flutter Scene shape
(including compound, convex-hull, triangle-mesh, and height-field shapes) can
be supplied directly. The ECS-facing runtime maps ray casts, shape casts,
overlaps, collision/trigger events, filters, forces, and impulses back to
entities. The pure-Dart `BasicSimulation` is the deterministic default for
queries and triggers; inject a solver implementation into `PhysicsPlugin` for
dynamic rigid bodies. Plugin resources implement `DisposableResource`, so
`await app.dispose()` releases subscriptions and backend/native state.

The current game loop also includes ECS-owned session state, power pellets,
frightened ghost scoring, lives and respawning, win/game-over phases, restart
controls, a Lua-driven ghost, and a composed 3D heroine based on the checked-in
ImageGen character direction.

Four ghosts now run independent Lua VMs. Their ECS `GhostProfile` components
select chaser, ambusher, shy, and patrol targeting strategies; the scripting
surface exposes player sensing, power mode, and safe maze-target requests. Each
profile also has a distinct composed 3D character and frightened-state visual.

A timed 3D bonus fruit appears when half the pellets remain, awards 1,000
points, and expires after ten seconds. Consecutive frightened-ghost captures
escalate through 200, 400, 800, and 1,600 points until power mode ends.

## Authoring

`assets/lua/level.lua` owns the level name, maze layout, and gameplay tuning.

The native Lua surface is registered with LuaLike's `LibraryBuilder`, so the
runtime definitions also produce editor metadata. Regenerate the committed
LuaLS annotations and JSON API manifest after changing the bridge:

```sh
fvm dart run tool/generate_lua_api_docs.dart
```

The included `.luarc.json` makes Lua Language Server index `docs/lua`.
Edit the ASCII maze to build another level: `#` is a wall, `.` a pellet, `o` a
power pellet, `P` the player spawn, `A` through `D` are ghost spawns, `K` is a
Star Key, `|` a locked door, and `^` a rift trap. The
loader validates row widths, tiles, and required spawns before creating the ECS
world.

The same script returns a multi-game catalog and separate campaigns. Chapters author
story text, objectives, timed/progress-triggered events, render distance, and
camera mode. The final large-world chapter uses a close first-person camera;
future Lua chapters can opt into it with `camera = 'first_person'`.

`assets/lua/ghost.lua` demonstrates entity behavior scripts with `ready` and
`fixed_update` callbacks. `LuaBehaviorScheduler` can attach the same lifecycle
to other entity types without adding script-specific logic to the game loop.
The expanded API includes exported properties, groups, component introspection,
simulation timers, and queued cross-VM signals. See
`docs/LUA_SCRIPTING.md` for the complete callable surface and examples.
The default `assets/lua/autoload.lua` behavior is attached at `/root` before
enemy scripts and can resolve stable scene paths with `get_node`, mirroring a
small Godot SceneTree/autoload surface over the ECS.

`assets/lua/prefabs.lua` defines the demo's wisps, runes, orbs, hostile bolts,
and Dream Warden entirely in Lua. A new game can replace these recipes without
adding Dart component classes or editing the engine. Generic gameplay data is
attached with `Node.add_component`, changed with `Node.set_value`, and queried
through `SceneTree.get_nodes_with_component`.

Moonfall demonstrates a different genre on the same kernel. Lua creates each
chapter's platforms, crystals, hazards, checkpoint lanterns, enemies, exit gate,
effects, HUD, scoring, damage, and victory rules. A reusable native platformer
system provides deterministic movement, gravity, one-way landing, jumping, and
checkpoint respawning; Lua consumes those states and authors the game rules.
Its Nix character is generated from `assets/characters/nix.character.json` as a
34-part procedural Dart hierarchy rendered directly by Flutter Scene. The Thorn
Runner and Star Eater use the same JSON-to-Dart rig pipeline, with Lua retaining
ownership of movement, health, particles, and boss rules while Dart poses the
generated named joints. See
`docs/GAME_CENTER_ARCHITECTURE.md` for the asset pipeline and regeneration
command.

Moonfall also replaces the maze floor with a procedural, multi-depth Flutter
Scene environment: fractured moon geometry, stars, floating observatories,
ruined arches, debris, translucent void fog, wind trails, and foreground
crystals all move at separate parallax rates. The checked-in environment image
is modeling direction only; the running game renders the background as live 3D
geometry.

Walls are merged into horizontal runs instead of rendered as one cube per tile.
Their neon rails use `assets/materials/neon_wall.fmat`, whose `pulse` parameter
is driven each frame. This is also the extension pattern for future animated
Flutter Scene materials.

Wall runs are capped to streamable segments and presentation entities outside
the current level's render distance are culled. The camera follows the player,
so maps can grow beyond a single screen without rendering the entire world.
Each wall is a layered Flutter Scene assembly: dark architectural mass, top and
side energy conduits, rotating runes, and floating pulse motes.

Characters are built as composed 3D meshes and animated on the render side:
the heroine turns, bobs, chomps, and swings her gloves; ghosts bob and wobble
with individual phase offsets; the bonus fruit spins and floats. Gameplay
positions remain deterministic in the ECS while presentation animation stays
independent of the fixed simulation.

## Verify

```sh
fvm flutter analyze
fvm flutter test
fvm flutter build macos --debug
```

The build command compiles Flutter Scene material sources. Launch the resulting
app—or use the run command above—with Flutter GPU enabled.

## GitHub Pages deployment

Pushes to `main` run `.github/workflows/deploy-pages.yml`. The workflow installs
Flutter master, runs the full test suite, builds with the repository-specific
`/node-maze-engine/` base path, uploads `build/web`, and deploys it through the
protected `github-pages` environment. It can also be started manually from the
Actions tab with **Run workflow**.

In first-person chapters, W/Up moves forward, S/Down moves backward, A/Left and
D/Right turn in 90-degree steps, and Space stops. The animated camera uses a
wider field of view and movement bob. The live map overlay reads walls,
remaining sparks, ghosts, player position, and facing directly from ECS state.
Lua levels can enable `auto_run`; the engine chooses an open spawn exit and
starts moving immediately, while turns steer the runner at maze intersections.
Power mode now throws the wall material into a rapid magenta reality storm, and
the floor uses a second compiled `.fmat` shader with slow rift surges and rare
energy flashes.

Levels may also generate their `maze` table algorithmically inside Lua. The
fourth chapter uses a seeded recursive-backtracker (`generate_maze`) to carve a
31×21 connected dream maze, place valid player/ghost spawns, and scatter power
objectives. A fixed seed makes runs reproducible; changing the seed produces a
different validated world without recompiling Dart.

Press V or Tab at any time to switch the same live ECS world between tactical
top-down and 3D corridor views. Corridor view raises the procedural wall
assemblies above eye level, widens the camera field of view, hides the external
heroine mesh, and enables first-person steering. Switching back restores the
overhead planning camera without resetting entities, score, or Lua behaviors.
Press P, Escape, or the hardware Pause key to suspend/resume the simulation.
Pause freezes ECS systems, Lua ticks, movement, encounters, and gameplay timers
while allowing low-level Flutter Scene shader ambience to continue rendering.
