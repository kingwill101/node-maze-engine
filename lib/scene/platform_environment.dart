import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class BrightPlatformEnvironmentResources {
  final CuboidGeometry box = CuboidGeometry(vm.Vector3.all(1));
  final SphereGeometry sphere = SphereGeometry(radius: 1);
  final UnlitMaterial sky = _material('#67c9ff');
  final UnlitMaterial cloud = _material('#fff4cf');
  final UnlitMaterial hill = _material('#51b66d');
  final UnlitMaterial hillDark = _material('#237a58');
  final UnlitMaterial sun = _material('#ffe25b');

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

class BrightPlatformEnvironment extends StatelessWidget {
  const BrightPlatformEnvironment({
    super.key,
    required this.resources,
    required this.playerX,
    required this.time,
  });

  final BrightPlatformEnvironmentResources resources;
  final double playerX;
  final double time;

  @override
  Widget build(BuildContext context) => SceneNode(
    name: 'bright-platform-environment',
    children: [
      SceneMesh(
        geometry: resources.box,
        material: resources.sky,
        position: vm.Vector3(playerX, 4.5, -7),
        scale: vm.Vector3(36, 13, .2),
      ),
      SceneMesh(
        geometry: resources.sphere,
        material: resources.sun,
        position: vm.Vector3(playerX - 5, 6.2, -6.4),
        scale: vm.Vector3.all(1.15 + math.sin(time) * .03),
      ),
      for (var index = 0; index < 6; index++)
        SceneMesh(
          geometry: resources.sphere,
          material: index.isEven ? resources.hill : resources.hillDark,
          position: vm.Vector3(
            playerX * .72 - 12 + index * 5.2,
            -.7 + (index % 2) * .45,
            -5.4,
          ),
          scale: vm.Vector3(4.2, 2.7 + (index % 3) * .5, .7),
        ),
      for (var index = 0; index < 8; index++)
        SceneMesh(
          geometry: resources.sphere,
          material: resources.cloud,
          position: vm.Vector3(
            playerX * .42 - 14 + index * 4.4,
            3.8 + math.sin(index * 2.1 + time * .22) * .35,
            -5.8,
          ),
          scale: vm.Vector3(1.4, .48, .3),
        ),
    ],
  );
}
