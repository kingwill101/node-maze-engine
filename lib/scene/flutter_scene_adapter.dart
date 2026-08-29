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
  ];

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
}
