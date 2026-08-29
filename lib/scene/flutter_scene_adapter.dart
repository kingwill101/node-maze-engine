import 'package:flutter/widgets.dart' hide Matrix4;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../engine/entity.dart';
import 'render_components.dart';
import 'render_plugin.dart';

typedef SceneMaterialResolver = Material Function(
  SceneMaterial3d? material,
  SceneMesh3d mesh,
);

/// Flutter Scene realization backend for extracted ECS scene components.
///
/// Geometry objects are cached once per adapter. Construct this only after
/// Flutter GPU has been enabled and the Flutter binding has initialized.
class FlutterSceneAdapter {
  FlutterSceneAdapter({required this.materialResolver});

  final SceneMaterialResolver materialResolver;
  final CuboidGeometry _box = CuboidGeometry(Vector3.all(1));
  final SphereGeometry _sphere = SphereGeometry(radius: .5);
  final IcosphereGeometry _icosphere = IcosphereGeometry(radius: .5);
  final PlaneGeometry _plane = PlaneGeometry();
  final CylinderGeometry _cylinder = CylinderGeometry();
  final CapsuleGeometry _capsule = CapsuleGeometry(radius: .25, height: .5);
  final TorusGeometry _torus = TorusGeometry();
  final DiscGeometry _disc = DiscGeometry();
  final RingGeometry _ring = RingGeometry();
  final WedgeGeometry _wedge = WedgeGeometry(Vector3.all(1));
  final Map<Entity, ({int signature, ParticleEmitterComponent component})>
  _particleEmitters = {};

  Widget mesh({
    required Entity entity,
    required SceneMesh3d mesh,
    required SceneMaterial3d? material,
    Vector3? position,
    Matrix4? transform,
  }) => SceneMesh(
    key: ValueKey<String>('ecs-scene-mesh-${entity.id}'),
    name: 'ecs-scene-mesh-${entity.id}',
    geometry: geometry(mesh.primitive),
    material: materialResolver(material, mesh),
    position: position,
    transform: transform,
    scale: Vector3(mesh.width, mesh.height, mesh.depth),
    visible: mesh.visible,
  );

  Widget light({
    required Entity entity,
    required SceneLight3d light,
    Vector3? position,
    Matrix4? transform,
  }) => SceneNode(
    key: ValueKey<String>('ecs-scene-light-${entity.id}'),
    name: 'ecs-scene-light-${entity.id}',
    position: position,
    transform: transform,
    components: [_lightComponent(light)],
  );

  List<Widget> entity(ExtractedSceneEntity entity) => [
    if (entity.light case final sceneLight?)
      light(
        entity: entity.entity,
        light: sceneLight,
        transform: entity.transform,
      ),
    if (entity.mesh case final sceneMesh?)
      mesh(
        entity: entity.entity,
        mesh: sceneMesh,
        material: entity.material,
        transform: entity.transform,
      ),
    if (entity.asset case final asset?)
      SceneModel(
        asset.path,
        key: ValueKey<String>('ecs-scene-model-${entity.entity.id}'),
        name: 'ecs-scene-model-${entity.entity.id}',
        variant: asset.subtree,
        animations: [
          if (asset.animation case final animation?)
            SceneAnimationSpec(animation, playing: asset.autoPlay),
        ],
        transform: entity.transform,
      ),
    if (entity.particle case final particle?)
      SceneNode(
        key: ValueKey<String>('ecs-scene-particles-${entity.entity.id}'),
        name: 'ecs-scene-particles-${entity.entity.id}',
        transform: entity.transform,
        components: [_particle(entity.entity, particle)],
      ),
  ];

  PerspectiveCamera? camera(ExtractedScene scene) {
    final cameraEntity = scene.activeCamera;
    if (cameraEntity == null) return null;
    final extracted = scene.entities
        .where((item) => item.entity == cameraEntity)
        .firstOrNull;
    final spec = extracted?.camera;
    if (extracted == null || spec == null) return null;
    final position = extracted.transform.getTranslation();
    final rotation = extracted.transform.getRotation();
    final forward = rotation.transform(Vector3(0, 0, 1));
    return PerspectiveCamera(
      position: position,
      target: position + forward,
      up: rotation.transform(Vector3(0, 1, 0)),
      fovRadiansY: spec.fovRadians,
      fovNear: spec.near,
      fovFar: spec.far,
    );
  }

  EnvironmentSettings? environment(ExtractedScene scene) {
    final spec = scene.entities
        .map((entity) => entity.environment)
        .whereType<SceneEnvironment3d>()
        .firstOrNull;
    if (spec == null) return null;
    return EnvironmentSettings(
      environmentIntensity: spec.environmentIntensity,
      exposure: spec.exposure,
      bloomEnabled: spec.bloom,
      bloomIntensity: spec.bloomIntensity,
      lensFlareEnabled: spec.lensFlare,
      vignetteEnabled: spec.vignette,
      chromaticAberrationEnabled: spec.chromaticAberration,
      filmGrainEnabled: spec.filmGrain,
      ambientOcclusionEnabled: spec.ambientOcclusion,
      screenSpaceReflectionsEnabled: spec.screenSpaceReflections,
      globalIlluminationEnabled: spec.globalIllumination,
      fogEnabled: spec.fog,
      godRaysEnabled: spec.godRays,
      depthOfFieldEnabled: spec.depthOfField,
      autoExposureEnabled: spec.autoExposure,
    );
  }

  void configureScene(Scene scene, ExtractedScene extracted) {
    final settings = environment(extracted);
    if (settings != null) scene.environmentSettings = settings;
    final taa = extracted.entities.any(
      (entity) => entity.environment?.temporalAntiAliasing ?? false,
    );
    scene.antiAliasingMode = taa ? AntiAliasingMode.taa : AntiAliasingMode.msaa;
  }

  Geometry geometry(ScenePrimitive primitive) => switch (primitive) {
    ScenePrimitive.box => _box,
    ScenePrimitive.sphere => _sphere,
    ScenePrimitive.icosphere => _icosphere,
    ScenePrimitive.plane => _plane,
    ScenePrimitive.cylinder => _cylinder,
    ScenePrimitive.capsule => _capsule,
    ScenePrimitive.torus => _torus,
    ScenePrimitive.disc => _disc,
    ScenePrimitive.ring => _ring,
    ScenePrimitive.wedge => _wedge,
  };

  Component _lightComponent(SceneLight3d light) {
    final color = _linearColor(light.color);
    return switch (light.kind) {
      SceneLightKind.directional => DirectionalLightComponent.aimed(
        DirectionalLight(
          color: color,
          intensity: light.intensity,
          castsShadow: light.castShadows,
        ),
        Vector3(0, 0, 1),
      ),
      SceneLightKind.point => PointLightComponent(
        PointLight(
          color: color,
          intensity: light.intensity,
          range: light.range,
        ),
      ),
      SceneLightKind.spot => SpotLightComponent(
        SpotLight(
          color: color,
          intensity: light.intensity,
          range: light.range,
          innerConeAngle: light.innerAngle,
          outerConeAngle: light.outerAngle,
          castsShadow: light.castShadows,
        ),
      ),
      SceneLightKind.area => RectAreaLightComponent(
        RectAreaLight(
          color: color,
          intensity: light.intensity,
          range: light.range,
          width: light.width,
          height: light.height,
        ),
      ),
    };
  }

  ParticleEmitterComponent _particle(Entity entity, SceneParticle3d spec) {
    final signature = Object.hash(
      spec.maxParticles,
      spec.rate,
      spec.lifetime,
      spec.shape,
      spec.color,
      spec.size,
      Object.hashAll(spec.modules),
    );
    final cached = _particleEmitters[entity];
    if (cached != null && cached.signature == signature) {
      return cached.component;
    }
    final system = ParticleSystem(
      maxParticles: spec.maxParticles,
      shape: switch (spec.shape) {
        'sphere' => const SphereEmitterShape(radius: .5),
        'box' => BoxEmitterShape(halfExtents: Vector3.all(.5)),
        'cone' => const ConeEmitterShape(angle: .5, radius: .1),
        _ => PointEmitterShape(),
      },
      spawner: Spawner(rate: spec.rate),
      lifetime: ConstantFloat(spec.lifetime),
      startSpeed: const ConstantFloat(1),
      startSize: ConstantFloat(spec.size),
      startColor: ConstantColor(_linearColor4(spec.color)),
      gravity: spec.modules.contains('gravity') ? Vector3(0, -9.8, 0) : null,
      modules: [
        if (spec.modules.contains('turbulence')) TurbulenceModule(),
        if (spec.modules.contains('rotation')) const RotationModule(),
        if (spec.modules.contains('drag')) LinearDragModule(1),
      ],
      seed: entity.id,
    );
    final component = ParticleEmitterComponent(system: system);
    _particleEmitters[entity] = (signature: signature, component: component);
    return component;
  }

  static Vector3 _linearColor(String source) {
    final normalized = source.replaceFirst('#', '');
    final rgb =
        int.tryParse(
          normalized.length == 8 ? normalized.substring(2) : normalized,
          radix: 16,
        ) ??
        0xffffff;
    return Vector3(
      ((rgb >> 16) & 0xff) / 255,
      ((rgb >> 8) & 0xff) / 255,
      (rgb & 0xff) / 255,
    );
  }

  static Vector4 _linearColor4(String source) {
    final color = _linearColor(source);
    final normalized = source.replaceFirst('#', '');
    final alpha = normalized.length == 8
        ? (int.tryParse(normalized.substring(0, 2), radix: 16) ?? 255) / 255
        : 1.0;
    return Vector4(color.x, color.y, color.z, alpha);
  }
}
