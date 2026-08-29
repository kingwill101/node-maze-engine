import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/app.dart';
import 'package:node/engine/core_plugins.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('default plugins install deterministic frame and fixed clocks', () {
    final app = GameApp(fixedDelta: .1)..addPlugin(const DefaultPlugins());

    app.update(.25);

    final frame = app.context.resources.get<FrameTime>();
    final fixed = app.context.resources.get<FixedTime>();
    expect(frame.delta, .25);
    expect(frame.elapsed, .25);
    expect(frame.frame, 1);
    expect(fixed.tick, 2);
    expect(fixed.elapsed, closeTo(.2, 1e-10));
  });

  test('input actions preserve transitions for one application frame', () {
    final app = GameApp()..addPlugin(const InputPlugin());
    final buttons = app.context.resources.get<ButtonInput<String>>();
    final actions = app.context.resources.get<ActionInput>()
      ..bind('move_left', ['KeyA', 'ArrowLeft']);

    buttons.press('KeyA');
    expect(actions.pressed('move_left'), isTrue);
    expect(actions.justPressed('move_left'), isTrue);
    app.update(1 / 60);
    expect(actions.pressed('move_left'), isTrue);
    expect(actions.justPressed('move_left'), isFalse);

    buttons.release('KeyA');
    expect(actions.justReleased('move_left'), isTrue);
    app.update(1 / 60);
    expect(actions.justReleased('move_left'), isFalse);
  });

  test('transform plugin propagates arbitrary-depth hierarchy', () {
    final app = GameApp()..addPlugin(const TransformPlugin());
    final root = app.context.world.create([
      LocalTransform(translation: Vector3(10, 0, 0)),
    ]);
    final child = app.context.world.create([
      LocalTransform(translation: Vector3(0, 3, 0)),
    ]);
    final grandchild = app.context.world.create([
      LocalTransform(translation: Vector3(0, 0, 2)),
    ]);
    setParent(app.context, child, root);
    setParent(app.context, grandchild, child);

    app.update(1 / 60);

    final position = app.context.world
        .get<GlobalTransform>(grandchild)
        .matrix
        .getTranslation();
    expect(position.x, closeTo(10, 1e-6));
    expect(position.y, closeTo(3, 1e-6));
    expect(position.z, closeTo(2, 1e-6));
    expect(app.context.world.get<Children>(root).values, contains(child));
  });

  test('transform propagation rejects hierarchy cycles', () {
    final app = GameApp()..addPlugin(const TransformPlugin());
    final a = app.context.world.create([LocalTransform()]);
    final b = app.context.world.create([LocalTransform()]);
    setParent(app.context, b, a);
    setParent(app.context, a, b);

    expect(() => app.update(1 / 60), throwsStateError);
  });
}
