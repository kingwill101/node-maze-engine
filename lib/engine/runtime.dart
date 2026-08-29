import 'app.dart';
import 'commands.dart';
import 'events.dart';
import 'resources.dart';
import 'schedule.dart';
import 'world.dart';

abstract interface class EngineSystem {
  void update(EngineContext context, double deltaSeconds);
}

class EngineContext {
  EngineContext({World? world, EventBus? events})
    : world = world ?? World(),
      events = events ?? EventBus(),
      resources = Resources() {
    commands = Commands(this.world);
  }

  final World world;
  final EventBus events;
  final Resources resources;
  late final Commands commands;
}

/// Advances gameplay at a deterministic rate while rendering at any rate.
class EngineRuntime {
  EngineRuntime({this.fixedDelta = 1 / 60, this.maxFrameDelta = 0.25}) {
    app =
        GameApp(
            fixedDelta: fixedDelta,
            maxFrameDelta: maxFrameDelta,
            context: context,
          )
          ..addSystem(
            ScheduleLabel.fixedUpdate,
            _SystemList(fixedSystems),
            label: 'legacy.fixed_systems',
          )
          ..addSystem(
            ScheduleLabel.update,
            _SystemList(frameSystems),
            label: 'legacy.frame_systems',
          );
  }

  final double fixedDelta;
  final double maxFrameDelta;
  final EngineContext context = EngineContext();
  final List<EngineSystem> fixedSystems = [];
  final List<EngineSystem> frameSystems = [];
  late final GameApp app;

  double get interpolationAlpha => app.interpolationAlpha;

  void advance(double frameDelta) => app.update(frameDelta);
}

class _SystemList implements EngineSystem {
  const _SystemList(this.systems);

  final List<EngineSystem> systems;

  @override
  void update(EngineContext context, double deltaSeconds) {
    for (final system in List<EngineSystem>.of(systems)) {
      system.update(context, deltaSeconds);
    }
  }
}
