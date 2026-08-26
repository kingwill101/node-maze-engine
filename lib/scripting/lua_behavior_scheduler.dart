import 'dart:async';

import '../engine/entity.dart';
import '../game/components.dart';
import 'lua_behavior_runtime.dart';

/// Reusable scheduler for entity-bound Lua behavior VMs.
///
/// Calls are serialized so an asynchronous Lua callback never overlaps its
/// next tick. Time accumulated while a callback runs is delivered on the next
/// dispatch instead of being dropped.
class LuaBehaviorScheduler {
  final Map<Entity, LuaBehaviorRuntime> _behaviors = {};
  bool _fixedBusy = false;
  double _fixedAccumulator = 0;
  final List<LuaSignal> _pendingSignals = [];

  int get length => _behaviors.length;

  Future<void> attach({
    required Entity entity,
    required LuaBehaviorRuntime runtime,
    required String source,
    String? scriptPath,
  }) async {
    await runtime.load(source, scriptPath: scriptPath);
    await runtime.ready(entity);
    _behaviors[entity] = runtime;
  }

  void clear() {
    _behaviors.clear();
    _fixedAccumulator = 0;
    _pendingSignals.clear();
  }

  void emitSignal(LuaSignal signal) => _pendingSignals.add(signal);

  void fixedUpdate(double deltaSeconds) {
    _fixedAccumulator += deltaSeconds;
    _behaviors.removeWhere((entity, runtime) => !runtime.isEntityAlive(entity));
    if (_fixedBusy || _behaviors.isEmpty) return;
    final delta = _fixedAccumulator;
    _fixedAccumulator = 0;
    final snapshot = _behaviors.entries.toList();
    final signals = List<LuaSignal>.of(_pendingSignals);
    _pendingSignals.clear();
    _fixedBusy = true;
    unawaited(
      Future.wait([
        for (final entry in snapshot)
          _runBehavior(entry.key, entry.value, signals, delta),
      ]).whenComplete(() => _fixedBusy = false),
    );
  }

  Future<void> _runBehavior(
    Entity entity,
    LuaBehaviorRuntime runtime,
    List<LuaSignal> signals,
    double delta,
  ) async {
    for (final signal in signals) {
      await runtime.signalReceived(entity, signal);
    }
    await runtime.fixedUpdate(entity, delta);
  }
}
