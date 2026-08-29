import 'package:vector_math/vector_math.dart';

import '../engine/app.dart';
import '../engine/core_plugins.dart';
import '../engine/entity.dart';
import '../engine/plugin.dart';
import '../engine/runtime.dart';
import '../engine/schedule.dart';
import 'render_components.dart';

/// Immutable render-side view of one ECS entity.
class ExtractedSceneEntity {
  const ExtractedSceneEntity({
    required this.entity,
    required this.transform,
    this.mesh,
    this.material,
    this.light,
    this.camera,
    this.asset,
    this.particle,
    this.environment,
  });

  final Entity entity;
  final Matrix4 transform;
  final SceneMesh3d? mesh;
  final SceneMaterial3d? material;
  final SceneLight3d? light;
  final SceneCamera3d? camera;
  final SceneAsset3d? asset;
  final SceneParticle3d? particle;
  final SceneEnvironment3d? environment;
}

/// Double-buffer friendly render snapshot produced after gameplay updates.
class ExtractedScene {
  List<ExtractedSceneEntity> entities = const [];
  Entity? activeCamera;
  int revision = 0;
}

/// Extracts backend-neutral scene components from the gameplay world.
class SceneRenderPlugin implements GamePlugin {
  const SceneRenderPlugin();

  @override
  String get name => 'node.scene_render';

  @override
  void build(GameApp app) {
    if (!app.plugins.contains('node.transform')) {
      app.addPlugin(const TransformPlugin());
    }
    app
      ..insertResource(ExtractedScene())
      ..addSystem(
        ScheduleLabel.last,
        const ExtractSceneSystem(),
        label: 'scene.extract',
      );
  }
}

class ExtractSceneSystem implements EngineSystem {
  const ExtractSceneSystem();

  @override
  void update(EngineContext context, double deltaSeconds) {
    final extracted = <ExtractedSceneEntity>[];
    Entity? activeCamera;
    for (final entity in context.world.entities.toList()..sort()) {
      final mesh = context.world.maybeGet<SceneMesh3d>(entity);
      final material = context.world.maybeGet<SceneMaterial3d>(entity);
      final light = context.world.maybeGet<SceneLight3d>(entity);
      final camera = context.world.maybeGet<SceneCamera3d>(entity);
      final asset = context.world.maybeGet<SceneAsset3d>(entity);
      final particle = context.world.maybeGet<SceneParticle3d>(entity);
      final environment = context.world.maybeGet<SceneEnvironment3d>(entity);
      if (mesh == null &&
          material == null &&
          light == null &&
          camera == null &&
          asset == null &&
          particle == null &&
          environment == null) {
        continue;
      }
      if (camera?.active ?? false) activeCamera ??= entity;
      final global = context.world.maybeGet<GlobalTransform>(entity)?.matrix;
      final local = context.world.maybeGet<LocalTransform>(entity)?.matrix();
      extracted.add(
        ExtractedSceneEntity(
          entity: entity,
          transform: Matrix4.copy(global ?? local ?? Matrix4.identity()),
          mesh: mesh == null ? null : _mesh(mesh),
          material: material == null ? null : _material(material),
          light: light == null ? null : _light(light),
          camera: camera == null ? null : _camera(camera),
          asset: asset == null ? null : _asset(asset),
          particle: particle == null ? null : _particle(particle),
          environment: environment == null ? null : _environment(environment),
        ),
      );
    }
    final scene = context.resources.get<ExtractedScene>();
    scene
      ..entities = List.unmodifiable(extracted)
      ..activeCamera = activeCamera;
    scene.revision++;
  }

  static SceneMesh3d _mesh(SceneMesh3d value) => SceneMesh3d(
    primitive: value.primitive,
    material: value.material,
    width: value.width,
    height: value.height,
    depth: value.depth,
    visible: value.visible,
    replacesDefault: value.replacesDefault,
    castShadows: value.castShadows,
    receiveShadows: value.receiveShadows,
    renderLayer: value.renderLayer,
  );

  static SceneMaterial3d _material(SceneMaterial3d value) => SceneMaterial3d(
    kind: value.kind,
    color: value.color,
    asset: value.asset,
    metallic: value.metallic,
    roughness: value.roughness,
    emissive: value.emissive,
    opacity: value.opacity,
    parameters: Map.of(value.parameters),
  );

  static SceneLight3d _light(SceneLight3d value) => SceneLight3d(
    kind: value.kind,
    color: value.color,
    intensity: value.intensity,
    range: value.range,
    innerAngle: value.innerAngle,
    outerAngle: value.outerAngle,
    castShadows: value.castShadows,
    width: value.width,
    height: value.height,
  );

  static SceneCamera3d _camera(SceneCamera3d value) => SceneCamera3d(
    active: value.active,
    fovRadians: value.fovRadians,
    near: value.near,
    far: value.far,
  );

  static SceneAsset3d _asset(SceneAsset3d value) => SceneAsset3d(
    value.path,
    subtree: value.subtree,
    animation: value.animation,
    autoPlay: value.autoPlay,
  );

  static SceneParticle3d _particle(SceneParticle3d value) => SceneParticle3d(
    maxParticles: value.maxParticles,
    rate: value.rate,
    lifetime: value.lifetime,
    shape: value.shape,
    color: value.color,
    size: value.size,
    modules: List.of(value.modules),
  );

  static SceneEnvironment3d _environment(SceneEnvironment3d value) =>
      SceneEnvironment3d(
        environmentAsset: value.environmentAsset,
        skyAsset: value.skyAsset,
        fog: value.fog,
        ambientOcclusion: value.ambientOcclusion,
        globalIllumination: value.globalIllumination,
        screenSpaceReflections: value.screenSpaceReflections,
        godRays: value.godRays,
        depthOfField: value.depthOfField,
        autoExposure: value.autoExposure,
        temporalAntiAliasing: value.temporalAntiAliasing,
      );
}
