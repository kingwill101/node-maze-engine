import 'package:flutter_scene/physics.dart' as physics;
import 'package:flutter_test/flutter_test.dart';
import 'package:node/node_engine.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test(
    'physics plugin registers colliders and maps scene query hits',
    () async {
      final app = GameApp()..addPlugin(PhysicsPlugin());
      final near = app.context.world.create([
        LocalTransform(translation: Vector3(0, 0, 2)),
        PhysicsCollider3d.box(Vector3.all(.5), layer: 1 << 2),
      ]);
      app.context.world.create([
        LocalTransform(translation: Vector3(0, 0, 5)),
        PhysicsCollider3d.sphere(.5, layer: 1 << 3),
      ]);

      app.update(1 / 60);
      final runtime = app.context.resources.get<PhysicsRuntime>();

      expect(runtime.backendName, 'basic');
      expect(
        runtime
            .raycast(Vector3.zero(), Vector3(0, 0, 1), layerMask: 1 << 2)
            ?.entity,
        near,
      );
      expect(runtime.overlapSphere(Vector3(0, 0, 2), 1, layerMask: 1 << 2), [
        near,
      ]);
      await app.dispose();
    },
  );

  test('trigger lifecycle is emitted as typed ECS events', () async {
    final app = GameApp()..addPlugin(PhysicsPlugin());
    final solid = app.context.world.create([
      LocalTransform(),
      PhysicsCollider3d.box(Vector3.all(1)),
    ]);
    final trigger = app.context.world.create([
      LocalTransform(),
      PhysicsBody3d(kind: physics.BodyType.kinematic),
      PhysicsCollider3d.sphere(1, isTrigger: true),
    ]);
    final events = <PhysicsContactEvent>[];
    app.context.events.on<PhysicsContactEvent>(events.add);

    app.update(1 / 60);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.phase, PhysicsContactPhase.triggerEntered);
    expect({events.single.entityA, events.single.entityB}, {solid, trigger});

    app.context.world.get<LocalTransform>(trigger).translation.x = 10;
    app.update(1 / 60);
    await Future<void>.delayed(Duration.zero);

    expect(events.last.phase, PhysicsContactPhase.triggerExited);
    await app.dispose();
  });

  test('removing collider cleans its backend registration', () async {
    final app = GameApp()..addPlugin(PhysicsPlugin());
    final entity = app.context.world.create([
      LocalTransform(translation: Vector3(0, 0, 2)),
      PhysicsCollider3d.sphere(1),
    ]);
    app.update(1 / 60);
    expect(
      app.context.resources.get<PhysicsRuntime>().raycast(
        Vector3.zero(),
        Vector3(0, 0, 1),
      ),
      isNotNull,
    );

    app.context.world.remove<PhysicsCollider3d>(entity);
    app.update(1 / 60);

    expect(
      app.context.resources.get<PhysicsRuntime>().raycast(
        Vector3.zero(),
        Vector3(0, 0, 1),
      ),
      isNull,
    );
    await app.dispose();
  });

  test('default backend clearly rejects unsupported dynamic bodies', () {
    final app = GameApp()..addPlugin(PhysicsPlugin());
    app.context.world.create([
      LocalTransform(),
      PhysicsBody3d(kind: physics.BodyType.dynamic_),
      PhysicsCollider3d.sphere(1),
    ]);

    expect(() => app.update(1 / 60), throwsUnsupportedError);
  });
}
