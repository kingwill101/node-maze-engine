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
