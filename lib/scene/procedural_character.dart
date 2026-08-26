import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'character_spec.dart';

class CharacterPartPose {
  const CharacterPartPose({
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.rotationX = 0,
    this.rotationY = 0,
    this.rotationZ = 0,
    this.scale = 1,
  });

  final double x;
  final double y;
  final double z;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double scale;
}

class CharacterPose {
  const CharacterPose([this.parts = const {}]);

  final Map<String, CharacterPartPose> parts;

  CharacterPartPose operator [](String name) =>
      parts[name] ?? const CharacterPartPose();
}

class ProceduralCharacterResources {
  ProceduralCharacterResources(CharacterSpec spec)
    : materials = {
        for (final material in spec.materials)
          material.name: _material(material.color),
      };

  final SphereGeometry sphere = SphereGeometry(radius: 1);
  final CuboidGeometry box = CuboidGeometry(vm.Vector3.all(1));
  final TorusGeometry torus = TorusGeometry(radius: .72, tubeRadius: .22);
  final Map<String, UnlitMaterial> materials;

  Geometry geometry(CharacterPrimitive primitive) => switch (primitive) {
    CharacterPrimitive.sphere => sphere,
    CharacterPrimitive.box => box,
    CharacterPrimitive.torus => torus,
  };

  static UnlitMaterial _material(String source) {
    final value = int.parse(source.substring(1), radix: 16);
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(
        ((value >> 16) & 0xff) / 255,
        ((value >> 8) & 0xff) / 255,
        (value & 0xff) / 255,
        1,
      )
      ..vertexColorWeight = 0;
  }
}

class ProceduralCharacter extends StatelessWidget {
  const ProceduralCharacter({
    super.key,
    required this.spec,
    required this.resources,
    this.pose = const CharacterPose(),
  });

  final CharacterSpec spec;
  final ProceduralCharacterResources resources;
  final CharacterPose pose;

  @override
  Widget build(BuildContext context) {
    final children = <String?, List<CharacterPartSpec>>{};
    for (final part in spec.parts) {
      children.putIfAbsent(part.parent, () => []).add(part);
    }
    Widget buildPart(CharacterPartSpec part) {
      final animated = pose[part.name];
      final rotation = _rotation(
        part.rotation[0] + animated.rotationX,
        part.rotation[1] + animated.rotationY,
        part.rotation[2] + animated.rotationZ,
      );
      return SceneNode(
        name: part.name,
        position: vm.Vector3(
          part.position[0] + animated.x,
          part.position[1] + animated.y,
          part.position[2] + animated.z,
        ),
        rotation: rotation,
        scale: vm.Vector3.all(animated.scale),
        children: [
          SceneMesh(
            name: '${part.name}_mesh',
            geometry: resources.geometry(part.primitive),
            material: resources.materials[part.material]!,
            scale: vm.Vector3(part.scale[0], part.scale[1], part.scale[2]),
          ),
          for (final child in children[part.name] ?? const []) buildPart(child),
        ],
      );
    }

    return SceneNode(
      name: spec.name,
      children: [
        for (final root in children[null] ?? const []) buildPart(root),
      ],
    );
  }

  vm.Quaternion _rotation(double x, double y, double z) =>
      vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), x) *
      vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), y) *
      vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), z);
}
