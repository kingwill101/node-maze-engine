import 'events.dart';
import 'world.dart';

abstract interface class EngineSystem {
  void update(EngineContext context, double deltaSeconds);
}

class EngineContext {
  EngineContext({World? world, EventBus? events})
    : world = world ?? World(),
      events = events ?? EventBus();

  final World world;
  final EventBus events;
}

/// Advances gameplay at a deterministic rate while rendering at any rate.
class EngineRuntime {
  EngineRuntime({this.fixedDelta = 1 / 60, this.maxFrameDelta = 0.25});

  final double fixedDelta;
  final double maxFrameDelta;
  final EngineContext context = EngineContext();
  final List<EngineSystem> fixedSystems = [];
  final List<EngineSystem> frameSystems = [];
  double _accumulator = 0;

  double get interpolationAlpha => _accumulator / fixedDelta;

  void advance(double frameDelta) {
    _accumulator += frameDelta.clamp(0, maxFrameDelta);
    // The tolerance prevents values such as 0.3 - 0.1 - 0.1 from dropping an
    // otherwise exact simulation tick because of binary floating-point drift.
    while (_accumulator + 1e-12 >= fixedDelta) {
      for (final system in fixedSystems) {
        system.update(context, fixedDelta);
      }
      context.world.flush();
      _accumulator -= fixedDelta;
      if (_accumulator.abs() < 1e-12) _accumulator = 0;
    }
    for (final system in frameSystems) {
      system.update(context, frameDelta);
    }
    context.world.flush();
  }
}
