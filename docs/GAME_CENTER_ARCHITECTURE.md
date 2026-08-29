# Game Center architecture

The repository is evolving from one maze game into a small Game Center powered
by a reusable Flutter Scene, ECS, and Lua engine.

## Product structure

```text
Game Center shell
├── shared engine kernel
│   ├── ECS world, queries, events, and fixed timestep
│   ├── Lua Node / SceneTree / Prefab scripting surface
│   ├── input actions, cameras, audio, saves, and asset loading
│   └── Flutter Scene rendering, materials, animation, and physics adapters
├── Maze adventure
│   └── grid movement, ghosts, pellets, doors, procedural mazes
└── Moonfall side-scroller
    └── continuous movement, platform collision, jumping, combat, checkpoints
```

Games should depend on engine contracts. The shared engine must not import a
game package or know about concepts such as pellets, ghosts, moon crystals, or
specific characters.

## Lua-first game packages

The first package-loader milestone is live. `assets/games/catalog.lua` is the
startup registry. It lists Lua manifest paths, which the engine loads and
merges without knowing their game IDs. Each manifest declares its own autoload,
behavior, prefab library, campaign metadata, and levels.

Each game owns a manifest, autoloads, scenes, prefabs, behaviors, and assets:

```text
assets/games/<game_id>/
├── game.lua
├── autoload/
├── scenes/
├── prefabs/
├── behaviors/
├── levels/
└── models/
```

The current compact package layout is:

```text
assets/games/catalog.lua
assets/games/<game_id>/game.lua
assets/games/<game_id>/autoload.lua
assets/games/<game_id>/prefabs.lua
assets/games/<game_id>/<behavior>.lua
```

Signal Garden is the conformance package. It is discovered, displayed, and
booted without adding its ID to `main.dart`, `maze_game.dart`, or the Lua
bridge. An automated test guards that boundary. Node Maze and Moonfall are also
loaded through the index while their combined legacy manifest is gradually
split into individual package directories.

Brasscap Run extends that conformance boundary to 2.5D platformers. Its
manifest selects a scripted player renderer and the reusable bright platform
environment. Lua owns its character assembly, route generation, collectibles,
enemy patrols and stomping, springs, moving platforms, checkpoints, HUD, and
completion rules. The only new native scripting primitive is the generic
`platformer_launch(entity, velocity)` capability.

Minimal manifest metadata:

```lua
return {
  games = {{
    id = 'my_game',
    name = 'My Game',
    tagline = 'A Lua-authored experiment',
    campaign = 'My Campaign',
    autoload = 'assets/games/my_game/autoload.lua',
    behavior = 'assets/games/my_game/enemy.lua', -- or false
    prefabs = 'assets/games/my_game/prefabs.lua',
  }},
  levels = {
    -- ordinary Lua level tables tagged with game = 'my_game'
  },
}
```

Adding a game currently requires its assets, one manifest entry in
`catalog.lua`, and matching `pubspec.yaml` asset inclusion. It does not require
a Dart registration branch. New simulation capabilities still belong in the
engine as generic components and systems rather than game-ID checks.

The manifest declares the initial scene, supported input actions, save schema,
and optional engine capabilities. Lua composes gameplay from generic components
and calls narrow kernel services. Native Dart adapters are reserved for hot or
privileged work such as collision broad phases, GPU resources, persistence, and
platform services.

## Side-scroller rendering

The second game is mechanically 2D but visually 3D: simulation constrains
actors to an X/Y plane while Flutter Scene renders dimensional characters,
platforms, particles, lighting, and parallax layers. This keeps collision and
level design predictable without reducing the presentation to sprites.

Recommended side-scroller engine modules:

- named input actions instead of game-specific key handling;
- continuous body, velocity, gravity, and grounded components;
- collider shapes, layers, masks, triggers, and one-way platforms;
- camera bounds, look-ahead, damping, and parallax layers;
- animation state machines driven by component state;
- checkpoints, damage, knockback, moving platforms, and scene transitions;
- pooled particles, projectiles, enemies, and collectibles.

## Character asset pipeline

1. Generate an original orthographic turnaround and expression sheet.
2. Lock proportions, palette, costume regions, and identity details.
3. Build a reconstruction specification and low-poly blockout.
4. Produce a rigged GLB with named bones and animation clips.
5. Validate silhouette and materials from gameplay camera distance.
6. Optimize textures, mesh count, skin weights, and animation clips for web.
7. Preprocess and load the glTF asset through Flutter Scene.

`img2threejs` may assist steps 3 and 4 as an offline experiment. Its direct
output is a procedural TypeScript `THREE.Group`, not a Flutter Scene asset. A
conversion path must bake compatible geometry and PBR materials to GLB, convert
animations into glTF clips, and replace Three.js-only shaders. Its component
specification and hierarchy may alternatively be translated into our Lua
prefabs and Flutter Scene primitives.

The initial Nix turnaround is stored at
`art/concepts/nix-turnaround-v1.png`.

## Procedural Dart character generation

Nix proves the renderer-native path:

```text
assets/characters/nix.character.json
        ↓ tool/generate_character.dart
lib/generated/nix_character.g.dart
        ↓ ProceduralCharacter
Flutter Scene SceneNode / SceneMesh hierarchy
        ↓
Flutter GPU or WebGL2 backend
```

Regenerate the factory after editing the neutral specification:

```sh
fvm dart run tool/generate_character.dart \
  assets/characters/nix.character.json \
  lib/generated/nix_character.g.dart
fvm dart format lib/generated/nix_character.g.dart
```

Generated files contain immutable, reviewable character data rather than GPU
objects. `ProceduralCharacterResources` creates each unit geometry and material
once; the reusable renderer builds the named hierarchy from those cached
resources. This avoids allocating meshes or materials during animation frames.

Lua writes `character_animation.state` and `character_animation.facing` on the
player. Dart translates those gameplay states into rotations for generated
joints such as `left_upper_arm`, `right_thigh`, and `cloak`. Future animation
graphs can preserve this contract whether a character is procedural Dart or a
skinned glTF model.

## Moonfall environment layers

`MoonfallEnvironment` rebuilds the environment concept as live Flutter Scene
geometry. No concept-art bitmap ships in the game. Cached sphere, cuboid, and
torus geometry is composed into six scene groups:

1. indigo sky, plum horizon, and deterministic stars;
2. pulsing fractured moon with independently rotating shards;
3. floating islands and distant rune observatories;
4. mossy middle-distance arches and drifting debris;
5. alpha-blended violet mist and animated cyan wind trails;
6. fast foreground crystal silhouettes.

Each group receives a distinct camera-relative X offset. Far layers move only
slightly while foreground silhouettes move faster than the camera, producing
real depth from the same side-on gameplay projection. Platformer mode removes
the maze floor so the violet void and Lua-authored platforms remain readable.

The implementation lives in `lib/scene/moonfall_environment.dart`. Its
materials and geometry are persistent resources; only transforms change during
animation frames.
