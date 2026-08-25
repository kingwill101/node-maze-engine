import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/runtime.dart';
import 'package:node/engine/world.dart';

class Position {
  Position(this.x);
  double x;
}

class Velocity {
  Velocity(this.x);
  double x;
}

class MovementSystem implements EngineSystem {
  @override
  void update(EngineContext context, double deltaSeconds) {
    for (final (_, position, velocity)
        in context.world.query2<Position, Velocity>()) {
      position.x += velocity.x * deltaSeconds;
    }
  }
}

void main() {
  test('stores and queries typed components', () {
    final world = World();
    final moving = world.create([Position(1), Velocity(2)]);
    world.create([Position(10)]);
    expect(world.get<Position>(moving).x, 1);
    expect(world.query2<Position, Velocity>().length, 1);
  });

  test('defers structural changes until flush', () {
    final world = World();
    final entity = world.create([Position(1)]);
    world.defer((world) => world.destroy(entity));
    expect(world.isAlive(entity), isTrue);
    world.flush();
    expect(world.isAlive(entity), isFalse);
  });

  test('fixed timestep is deterministic', () {
    final runtime = EngineRuntime(fixedDelta: .1, maxFrameDelta: .5);
    final entity = runtime.context.world.create([Position(0), Velocity(10)]);
    runtime.fixedSystems.add(MovementSystem());
    runtime.advance(.35);
    expect(runtime.context.world.get<Position>(entity).x, closeTo(3, 1e-9));
    expect(runtime.interpolationAlpha, closeTo(.5, 1e-9));
  });
}
