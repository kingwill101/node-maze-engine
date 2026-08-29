import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/app.dart';
import 'package:node/engine/core_plugins.dart';
import 'package:node/scene/render_components.dart';
import 'package:node/scene/render_plugin.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test(
    'scene plugin extracts an immutable backend-neutral render snapshot',
    () {
      final app = GameApp()..addPlugin(const SceneRenderPlugin());
      final camera = app.context.world.create([
        LocalTransform(translation: Vector3(1, 2, 3)),
        SceneCamera3d(active: true, fovRadians: .9),
        SceneEnvironment3d(fog: true, temporalAntiAliasing: true),
      ]);
      final actor = app.context.world.create([
        LocalTransform(translation: Vector3(4, 5, 6)),
        SceneMesh3d(primitive: ScenePrimitive.capsule, height: 2),
        SceneMaterial3d(color: '#44ccff', metallic: .8),
        SceneLight3d(kind: SceneLightKind.point, intensity: 3),
        SceneParticle3d(rate: 20, modules: ['gravity', 'trails']),
      ]);

      app.update(1 / 60);

      final scene = app.context.resources.get<ExtractedScene>();
      expect(scene.activeCamera, camera);
      expect(scene.revision, 1);
      expect(scene.entities, hasLength(2));
      final extracted = scene.entities.singleWhere(
        (item) => item.entity == actor,
      );
      expect(extracted.transform.getTranslation(), Vector3(4, 5, 6));
      expect(extracted.mesh?.primitive, ScenePrimitive.capsule);
      expect(extracted.material?.metallic, .8);
      expect(extracted.light?.intensity, 3);
      expect(extracted.particle?.modules, ['gravity', 'trails']);

      app.context.world.get<SceneMesh3d>(actor).height = 99;
      app.context.world.get<SceneParticle3d>(actor).modules.add('noise');
      expect(extracted.mesh?.height, 2);
      expect(extracted.particle?.modules, ['gravity', 'trails']);
    },
  );

  test('scene plugin installs transform propagation dependency', () {
    final app = GameApp()..addPlugin(const SceneRenderPlugin());
    expect(app.plugins, contains('node.transform'));
    expect(app.context.resources.contains<ExtractedScene>(), isTrue);
  });
}
