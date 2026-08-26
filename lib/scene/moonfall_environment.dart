import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

double moonfallParallaxOffset(double playerX, double movement) =>
    playerX * (1 - movement);

class MoonfallEnvironmentResources {
  final CuboidGeometry box = CuboidGeometry(vm.Vector3.all(1));
  final SphereGeometry sphere = SphereGeometry(radius: 1);
  final TorusGeometry ring = TorusGeometry(radius: .72, tubeRadius: .12);

  late final UnlitMaterial sky = _material('#080b2d');
  late final UnlitMaterial distantSky = _material('#17134b');
  late final UnlitMaterial moon = _material('#80eaff');
  late final UnlitMaterial moonCore = _material('#d8fbff');
  late final UnlitMaterial farStone = _material('#181c4b');
  late final UnlitMaterial middleStone = _material('#242653');
  late final UnlitMaterial moss = _material('#14585f');
  late final UnlitMaterial rune = _material('#9b47d1');
  late final UnlitMaterial lantern = _material('#ffb53f');
  late final UnlitMaterial star = _material('#d5efff');
  late final UnlitMaterial mist = _material('#7b3ec7', alpha: .2);
  late final UnlitMaterial wind = _material('#3edcff', alpha: .34);
  late final UnlitMaterial foreground = _material('#090a22');

  static UnlitMaterial _material(String source, {double alpha = 1}) {
    final value = int.parse(source.substring(1), radix: 16);
    return UnlitMaterial()
      ..baseColorFactor = vm.Vector4(
        ((value >> 16) & 0xff) / 255,
        ((value >> 8) & 0xff) / 255,
        (value & 0xff) / 255,
        alpha,
      )
      ..alphaMode = alpha < 1 ? AlphaMode.blend : AlphaMode.opaque
      ..vertexColorWeight = 0;
  }
}

class MoonfallEnvironment extends StatelessWidget {
  const MoonfallEnvironment({
    super.key,
    required this.resources,
    required this.playerX,
    required this.time,
  });

  final MoonfallEnvironmentResources resources;
  final double playerX;
  final double time;

  @override
  Widget build(BuildContext context) => SceneNode(
    name: 'moonfall_environment',
    children: [
      _skyLayer(),
      _moonLayer(),
      _farIslandsLayer(),
      _ruinsLayer(),
      _atmosphereLayer(),
      _foregroundLayer(),
    ],
  );

  Widget _skyLayer() => SceneNode(
    name: 'sky_layer',
    position: vm.Vector3(_anchor(.02), 0, -25),
    children: [
      SceneMesh(
        name: 'indigo_sky',
        geometry: resources.box,
        material: resources.sky,
        position: vm.Vector3(0, 5, 0),
        scale: vm.Vector3(46, 22, .5),
      ),
      SceneMesh(
        name: 'plum_horizon',
        geometry: resources.box,
        material: resources.distantSky,
        position: vm.Vector3(0, -2, .3),
        scale: vm.Vector3(46, 8, .25),
      ),
      for (var index = 0; index < 30; index++)
        SceneMesh(
          name: 'star_$index',
          geometry: resources.sphere,
          material: resources.star,
          position: vm.Vector3(
            -20 + ((index * 47) % 400) / 10,
            1.5 + ((index * 83) % 105) / 10,
            .7,
          ),
          scale: vm.Vector3.all(.018 + (index % 4) * .009),
        ),
    ],
  );

  Widget _moonLayer() {
    final pulse = 1 + math.sin(time * .7) * .018;
    return SceneNode(
      name: 'moon_layer',
      position: vm.Vector3(_anchor(.06) - 4.5, 7.2, -21),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), time * .008),
      children: [
        SceneMesh(
          name: 'moon_core',
          geometry: resources.sphere,
          material: resources.moonCore,
          scale: vm.Vector3(3.4 * pulse, 3.15 * pulse, .55),
        ),
        SceneMesh(
          name: 'moon_broken_face',
          geometry: resources.sphere,
          material: resources.moon,
          position: vm.Vector3(-.45, .12, .45),
          scale: vm.Vector3(2.75, 2.9, .42),
        ),
        for (var index = 0; index < 11; index++)
          SceneMesh(
            name: 'moon_shard_$index',
            geometry: resources.box,
            material: index.isEven ? resources.moon : resources.moonCore,
            position: vm.Vector3(
              3.2 + (index % 4) * 1.08,
              -2.1 + ((index * 7) % 6) * .82,
              .2 + (index % 3) * .08,
            ),
            rotation: vm.Quaternion.axisAngle(
              vm.Vector3(0, 0, 1),
              index * .57 + time * (.025 + index * .001),
            ),
            scale: vm.Vector3(.22 + (index % 3) * .14, .48, .2),
          ),
      ],
    );
  }

  Widget _farIslandsLayer() => SceneNode(
    name: 'far_islands_layer',
    position: vm.Vector3(_anchor(.14), 0, -15),
    children: [
      for (var index = 0; index < 8; index++)
        SceneNode(
          name: 'far_island_$index',
          position: vm.Vector3(
            -17 + index * 5.1,
            1.3 + (index % 3) * 1.65 + math.sin(time * .18 + index) * .08,
            (index % 2) * .4,
          ),
          children: [
            SceneMesh(
              geometry: resources.sphere,
              material: resources.farStone,
              scale: vm.Vector3(1.65, .42, .55),
            ),
            SceneMesh(
              geometry: resources.box,
              material: resources.farStone,
              position: vm.Vector3(0, .55, 0),
              scale: vm.Vector3(.18, .72 + (index % 2) * .45, .2),
            ),
            if (index % 2 == 0)
              SceneMesh(
                geometry: resources.ring,
                material: resources.rune,
                position: vm.Vector3(0, 1.35, 0),
                scale: vm.Vector3.all(.5),
              ),
          ],
        ),
    ],
  );

  Widget _ruinsLayer() => SceneNode(
    name: 'middle_ruins_layer',
    position: vm.Vector3(_anchor(.34), -.2, -7),
    children: [
      for (var index = 0; index < 6; index++)
        _ruinArch(-14 + index * 5.7, .4 + (index % 2) * .75, index),
      for (var index = 0; index < 12; index++)
        SceneMesh(
          name: 'floating_debris_$index',
          geometry: resources.box,
          material: resources.middleStone,
          position: vm.Vector3(
            -16 + index * 2.9,
            -1.2 + (index % 4) * .43 + math.sin(time * .35 + index) * .12,
            .5,
          ),
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            time * .05 + index,
          ),
          scale: vm.Vector3(.13 + (index % 3) * .09, .22, .18),
        ),
    ],
  );

  Widget _ruinArch(double x, double y, int index) => SceneNode(
    name: 'ruin_arch_$index',
    position: vm.Vector3(x, y, 0),
    children: [
      for (final side in const [-1.0, 1.0])
        SceneMesh(
          geometry: resources.box,
          material: resources.middleStone,
          position: vm.Vector3(side * 1.05, 1.1, 0),
          scale: vm.Vector3(.27, 1.35, .35),
        ),
      SceneMesh(
        geometry: resources.box,
        material: resources.middleStone,
        position: vm.Vector3(0, 2.25, 0),
        scale: vm.Vector3(1.32, .25, .38),
      ),
      SceneMesh(
        geometry: resources.box,
        material: resources.moss,
        position: vm.Vector3(0, 2.53, .03),
        scale: vm.Vector3(1.38, .07, .4),
      ),
      if (index.isEven)
        SceneMesh(
          geometry: resources.sphere,
          material: resources.lantern,
          position: vm.Vector3(0, 2.72, .25),
          scale: vm.Vector3.all(.1 + math.sin(time * 4 + index) * .012),
        ),
    ],
  );

  Widget _atmosphereLayer() => SceneNode(
    name: 'atmosphere_layer',
    position: vm.Vector3(_anchor(.58), 0, -2.2),
    children: [
      for (var index = 0; index < 7; index++)
        SceneMesh(
          name: 'mist_bank_$index',
          geometry: resources.sphere,
          material: resources.mist,
          position: vm.Vector3(
            -14 + index * 4.8 + math.sin(time * .16 + index) * .6,
            -2.25 + (index % 2) * .24,
            0,
          ),
          scale: vm.Vector3(3.8, .9, .35),
        ),
      for (var index = 0; index < 9; index++)
        SceneMesh(
          name: 'wind_trail_$index',
          geometry: resources.box,
          material: resources.wind,
          position: vm.Vector3(
            -18 + ((time * (.35 + index * .015) + index * 4.7) % 40),
            .2 + (index % 5) * 1.15,
            .3,
          ),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), .08),
          scale: vm.Vector3(.75 + (index % 3) * .35, .018, .03),
        ),
    ],
  );

  Widget _foregroundLayer() => SceneNode(
    name: 'foreground_layer',
    position: vm.Vector3(_anchor(1.08), -2.4, 5.2),
    children: [
      for (var index = 0; index < 10; index++)
        SceneMesh(
          name: 'foreground_crystal_$index',
          geometry: resources.box,
          material: resources.foreground,
          position: vm.Vector3(-17 + index * 3.8, -.2, 0),
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            -.35 + (index % 3) * .31,
          ),
          scale: vm.Vector3(
            .3 + (index % 2) * .16,
            1.2 + (index % 4) * .35,
            .3,
          ),
        ),
    ],
  );

  double _anchor(double movement) => moonfallParallaxOffset(playerX, movement);
}
