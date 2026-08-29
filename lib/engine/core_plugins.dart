import 'package:vector_math/vector_math.dart';

import 'app.dart';
import 'entity.dart';
import 'plugin.dart';
import 'runtime.dart';
import 'schedule.dart';

/// Per-render-frame timing information.
class FrameTime {
  double delta = 0;
  double elapsed = 0;
  int frame = 0;
}

/// Deterministic fixed-step timing information.
class FixedTime {
  FixedTime(this.step);

  final double step;
  double elapsed = 0;
  int tick = 0;
}

class TimePlugin implements GamePlugin {
  const TimePlugin();

  @override
  String get name => 'node.time';

  @override
  void build(GameApp app) {
    app
      ..insertResource(FrameTime())
      ..insertResource(FixedTime(app.fixedDelta))
      ..addSystem(
        ScheduleLabel.first,
        const _FrameTimeSystem(),
        label: 'time.frame',
      )
      ..addSystem(
        ScheduleLabel.fixedFirst,
        const _FixedTimeSystem(),
        label: 'time.fixed',
      );
  }
}

class _FrameTimeSystem implements EngineSystem {
  const _FrameTimeSystem();

  @override
  void update(EngineContext context, double deltaSeconds) {
    final time = context.resources.get<FrameTime>();
    time
      ..delta = deltaSeconds
      ..elapsed += deltaSeconds;
    time.frame++;
  }
}

class _FixedTimeSystem implements EngineSystem {
  const _FixedTimeSystem();

  @override
  void update(EngineContext context, double deltaSeconds) {
    final time = context.resources.get<FixedTime>();
    time.elapsed += deltaSeconds;
    time.tick++;
  }
}

/// Generic button state. Platform adapters feed values before [GameApp.update].
class ButtonInput<T extends Object> {
  final Set<T> _pressed = <T>{};
  final Set<T> _justPressed = <T>{};
  final Set<T> _justReleased = <T>{};

  Set<T> get pressedValues => Set.unmodifiable(_pressed);
  bool pressed(T button) => _pressed.contains(button);
  bool justPressed(T button) => _justPressed.contains(button);
  bool justReleased(T button) => _justReleased.contains(button);

  void press(T button) {
    if (_pressed.add(button)) _justPressed.add(button);
  }

  void release(T button) {
    if (_pressed.remove(button)) _justReleased.add(button);
  }

  void releaseAll() {
    _justReleased.addAll(_pressed);
    _pressed.clear();
  }

  void clearTransitions() {
    _justPressed.clear();
    _justReleased.clear();
  }
}

/// Named gameplay actions decoupled from physical keyboard/gamepad codes.
class ActionInput {
  final Map<String, Set<String>> _bindings = <String, Set<String>>{};
  ButtonInput<String>? _buttons;

  void bind(String action, Iterable<String> buttons) =>
      _bindings[action] = buttons.toSet();

  bool pressed(String action) =>
      _bindings[action]?.any(_buttons!.pressed) ?? false;
  bool justPressed(String action) =>
      _bindings[action]?.any(_buttons!.justPressed) ?? false;
  bool justReleased(String action) =>
      _bindings[action]?.any(_buttons!.justReleased) ?? false;

  double axis(String negative, String positive) =>
      (pressed(positive) ? 1.0 : 0.0) - (pressed(negative) ? 1.0 : 0.0);
}

class InputPlugin implements GamePlugin {
  const InputPlugin();

  @override
  String get name => 'node.input';

  @override
  void build(GameApp app) {
    final buttons = ButtonInput<String>();
    final actions = ActionInput().._buttons = buttons;
    app
      ..insertResource(buttons)
      ..insertResource(actions)
      ..addSystem(
        ScheduleLabel.last,
        const _ClearInputTransitions(),
        label: 'input.clear_transitions',
      );
  }
}

class _ClearInputTransitions implements EngineSystem {
  const _ClearInputTransitions();

  @override
  void update(EngineContext context, double deltaSeconds) =>
      context.resources.get<ButtonInput<String>>().clearTransitions();
}

/// Local translation, rotation and scale relative to [Parent].
class LocalTransform {
  LocalTransform({Vector3? translation, Quaternion? rotation, Vector3? scale})
    : translation = translation ?? Vector3.zero(),
      rotation = rotation ?? Quaternion.identity(),
      scale = scale ?? Vector3.all(1);

  final Vector3 translation;
  final Quaternion rotation;
  final Vector3 scale;

  Matrix4 matrix() => Matrix4.compose(translation, rotation, scale);
}

/// Computed world transform. It is updated by [TransformPlugin].
class GlobalTransform {
  GlobalTransform([Matrix4? matrix]) : matrix = matrix ?? Matrix4.identity();

  final Matrix4 matrix;
}

class Parent {
  const Parent(this.entity);
  final Entity entity;
}

class Children {
  Children([Iterable<Entity> values = const []]) : values = values.toList();
  final List<Entity> values;
}

class TransformPlugin implements GamePlugin {
  const TransformPlugin();

  @override
  String get name => 'node.transform';

  @override
  void build(GameApp app) {
    app.addSystem(
      ScheduleLabel.postUpdate,
      const TransformPropagationSystem(),
      label: 'transform.propagate',
    );
  }
}

/// Maintains the bidirectional hierarchy components used by transform systems.
void setParent(EngineContext context, Entity child, Entity? parent) {
  final previous = context.world.maybeGet<Parent>(child)?.entity;
  if (previous == parent) return;
  if (previous != null && context.world.isAlive(previous)) {
    context.world.maybeGet<Children>(previous)?.values.remove(child);
  }
  if (parent == null) {
    context.world.remove<Parent>(child);
    return;
  }
  if (!context.world.isAlive(parent)) {
    throw StateError('Parent $parent is not alive');
  }
  context.world.add(child, Parent(parent));
  final children = context.world.maybeGet<Children>(parent) ?? Children();
  if (!context.world.has<Children>(parent)) context.world.add(parent, children);
  if (!children.values.contains(child)) children.values.add(child);
}

class TransformPropagationSystem implements EngineSystem {
  const TransformPropagationSystem();

  @override
  void update(EngineContext context, double deltaSeconds) {
    final visiting = <Entity>{};
    final complete = <Entity>{};

    void propagate(Entity entity) {
      if (complete.contains(entity)) return;
      if (!visiting.add(entity)) {
        throw StateError('Transform hierarchy contains a cycle at $entity');
      }
      final local = context.world.maybeGet<LocalTransform>(entity);
      if (local == null) {
        visiting.remove(entity);
        complete.add(entity);
        return;
      }
      final parent = context.world.maybeGet<Parent>(entity)?.entity;
      final worldMatrix = local.matrix();
      if (parent != null) {
        if (!context.world.isAlive(parent)) {
          throw StateError('Entity $entity references dead parent $parent');
        }
        propagate(parent);
        final parentGlobal = context.world.maybeGet<GlobalTransform>(parent);
        if (parentGlobal != null) {
          worldMatrix.setFrom(parentGlobal.matrix * worldMatrix);
        }
      }
      final global = context.world.maybeGet<GlobalTransform>(entity);
      if (global == null) {
        context.world.add(entity, GlobalTransform(worldMatrix));
      } else {
        global.matrix.setFrom(worldMatrix);
      }
      visiting.remove(entity);
      complete.add(entity);
    }

    for (final (entity, _) in context.world.query<LocalTransform>()) {
      propagate(entity);
    }
  }
}

class DefaultPlugins extends PluginGroup {
  const DefaultPlugins()
    : super('node.default_plugins', const [
        TimePlugin(),
        InputPlugin(),
        TransformPlugin(),
      ]);
}
