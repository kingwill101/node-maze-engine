import 'plugin.dart';
import 'runtime.dart';
import 'schedule.dart';
import 'state.dart';

/// Bevy-inspired application host over the Dart ECS world.
class GameApp {
  GameApp({
    this.fixedDelta = 1 / 60,
    this.maxFrameDelta = .25,
    EngineContext? context,
  }) : context = context ?? EngineContext();

  final double fixedDelta;
  final double maxFrameDelta;
  final EngineContext context;
  final Map<ScheduleLabel, EngineSchedule> schedules = {
    for (final label in ScheduleLabel.values) label: EngineSchedule(),
  };
  final Set<String> _plugins = <String>{};
  bool _started = false;
  double _accumulator = 0;

  double get interpolationAlpha => _accumulator / fixedDelta;
  Set<String> get plugins => Set.unmodifiable(_plugins);

  GameApp addPlugin(GamePlugin plugin) {
    if (!_plugins.add(plugin.name)) return this;
    plugin.build(this);
    return this;
  }

  GameApp addSystem(
    ScheduleLabel schedule,
    EngineSystem system, {
    String? label,
    Set<String> before = const <String>{},
    Set<String> after = const <String>{},
    RunCondition? runIf,
  }) {
    schedules[schedule]!.add(
      SystemConfig(
        system: system,
        label: label,
        before: before,
        after: after,
        runIf: runIf,
      ),
    );
    return this;
  }

  GameApp insertResource<T extends Object>(T resource) {
    context.resources.insert<T>(resource);
    return this;
  }

  GameApp initState<T extends Object>(T initial) =>
      insertResource(StateMachine<T>(initial));

  void update(double frameDelta) {
    if (!_started) {
      _started = true;
      _run(ScheduleLabel.startup, 0);
    }
    final delta = frameDelta.clamp(0.0, maxFrameDelta).toDouble();
    _run(ScheduleLabel.first, delta);
    _run(ScheduleLabel.preUpdate, delta);
    _accumulator += delta;
    while (_accumulator + 1e-12 >= fixedDelta) {
      _run(ScheduleLabel.fixedFirst, fixedDelta);
      _run(ScheduleLabel.fixedPreUpdate, fixedDelta);
      _run(ScheduleLabel.fixedUpdate, fixedDelta);
      _run(ScheduleLabel.fixedPostUpdate, fixedDelta);
      _run(ScheduleLabel.fixedLast, fixedDelta);
      _accumulator -= fixedDelta;
      if (_accumulator.abs() < 1e-12) _accumulator = 0;
    }
    _run(ScheduleLabel.update, delta);
    _run(ScheduleLabel.postUpdate, delta);
    _run(ScheduleLabel.last, delta);
  }

  void applyState<T extends Object>() {
    final transition = context.resources.get<StateMachine<T>>().apply();
    if (transition != null) {
      context.events.emit(StateTransition<T>(transition.$1, transition.$2));
    }
  }

  void _run(ScheduleLabel label, double delta) {
    schedules[label]!.run(context, delta);
    context.world.flush();
  }
}
