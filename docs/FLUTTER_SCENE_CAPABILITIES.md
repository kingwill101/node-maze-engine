# Flutter Scene capability map

This inventory is based on the public exports installed with
`flutter_scene 0.23.0`. It is the target surface for the scene plugin and Lua
bindings; it is not a claim that every capability is integrated yet.

## Scene and assets

- declarative `SceneView`, `SceneNode` and `SceneMesh` widgets;
- imperative `Scene`, `Node`, `Mesh`, `Sprite` and render views;
- generated `.fsceneb` assets, source scene loading and runtime GLB loading;
- scene registry, subtree loading, cache release and reload callbacks;
- selection/pointer support, semantics and embedded Flutter widgets.

## Geometry

- box, wedge, plane, sphere/icosphere, cylinder/cone, capsule, disc, ring and
  torus primitives;
- billboard, polyline/dashes, line segments, ribbon, tube and extrusion;
- custom `MeshGeometry` from arrays/builders and explicit vertex layouts;
- skinned, morphed and combined skinned+morphed geometry;
- Gaussian splats and splat cropping.

## Materials and shaders

- unlit, physically based, sprite and shadow-catcher materials;
- custom shader materials and instance attributes;
- preprocessed FMAT materials/skies, runtime parameters and material variants;
- textures, texture transforms, alpha modes, HDR/EXR/equirectangular decoding
  and environment maps.

## Lighting and environment

- directional, point, spot and rectangular area lights;
- cascaded/contact shadows, channel masks and shadow filters;
- image-based lights, reflection probes, planar reflectors and render textures;
- irradiance volumes, global illumination and environment volumes;
- fog, ambient occlusion, screen-space reflections and god rays;
- auto exposure, depth of field and temporal anti-aliasing.

## Animation and scale

- animation clips, players, blending, skins and morph targets;
- instanced meshes, instance attributes, LOD components and render layers;
- node pools and volume/Poisson-disc spawning utilities;
- particles, mesh particles, bursts, curves, gradients, turbulence, flipbooks
  and trails.

## Cameras and gameplay kit

- perspective cameras plus fly, follow and orbit controllers;
- spring arms, camera shake and bounds framing;
- third-person controller and steering behavior utilities;
- day/night cycle, water surfaces, floating motion and debug drawing;
- performance overlays and virtual joystick support.

## Optional physics and audio contracts

- rigid bodies, colliders, triggers, collision events and scene queries;
- box, sphere, capsule, cylinder, convex, compound, height-field and triangle
  mesh shapes;
- fixed, generic, prismatic, revolute and spherical joints;
- kinematic character controller and pluggable simulation backends;
- spatial audio engines, listeners, sources, clips, voices, buses and
  attenuation, with pluggable backends.

## Integration rule

Flutter Scene objects remain in the rendering/backend plugin. Gameplay Lua
uses serializable ECS descriptions and opaque asset handles. This keeps tests
headless, permits native render extraction, and prevents Flutter widgets or GPU
objects from leaking into gameplay state.
