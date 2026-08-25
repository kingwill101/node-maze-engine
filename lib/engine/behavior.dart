import 'entity.dart';
import 'runtime.dart';

/// Godot-like lifecycle surface shared by Dart and future Lua behaviors.
abstract class Behavior {
  void ready(BehaviorContext context) {}
  void update(BehaviorContext context, double deltaSeconds) {}
  void fixedUpdate(BehaviorContext context, double deltaSeconds) {}
  void exit(BehaviorContext context) {}
}

class BehaviorComponent {
  BehaviorComponent(this.behavior);
  final Behavior behavior;
  bool ready = false;
}

class BehaviorContext {
  const BehaviorContext(this.engine, this.entity);
  final EngineContext engine;
  final Entity entity;
}

class BehaviorSystem implements EngineSystem {
  BehaviorSystem({required this.fixed});
  final bool fixed;

  @override
  void update(EngineContext context, double deltaSeconds) {
    for (final (entity, component)
        in context.world.query<BehaviorComponent>()) {
      final behaviorContext = BehaviorContext(context, entity);
      if (!component.ready) {
        component.ready = true;
        component.behavior.ready(behaviorContext);
      }
      if (fixed) {
        component.behavior.fixedUpdate(behaviorContext, deltaSeconds);
      } else {
        component.behavior.update(behaviorContext, deltaSeconds);
      }
    }
  }
}
