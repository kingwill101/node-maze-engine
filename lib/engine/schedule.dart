import 'runtime.dart';

enum ScheduleLabel {
  startup,
  first,
  preUpdate,
  fixedFirst,
  fixedPreUpdate,
  fixedUpdate,
  fixedPostUpdate,
  fixedLast,
  update,
  postUpdate,
  last,
}

typedef RunCondition = bool Function(EngineContext context);

class SystemConfig {
  const SystemConfig({
    required this.system,
    this.label,
    this.before = const <String>{},
    this.after = const <String>{},
    this.runIf,
  });

  final EngineSystem system;
  final String? label;
  final Set<String> before;
  final Set<String> after;
  final RunCondition? runIf;
}

/// Ordered collection of systems with stable before/after constraints.
class EngineSchedule {
  final List<SystemConfig> _systems = <SystemConfig>[];
  List<SystemConfig>? _ordered;

  Iterable<SystemConfig> get systems => List.unmodifiable(_systems);

  void add(SystemConfig config) {
    if (config.label != null &&
        _systems.any((system) => system.label == config.label)) {
      throw StateError('System label ${config.label} is already registered');
    }
    _systems.add(config);
    _ordered = null;
  }

  void run(EngineContext context, double deltaSeconds) {
    for (final config in _ordered ??= _sort()) {
      if (config.runIf?.call(context) ?? true) {
        config.system.update(context, deltaSeconds);
      }
    }
  }

  List<SystemConfig> _sort() {
    final labels = <String, SystemConfig>{};
    for (final system in _systems) {
      final label = system.label;
      if (label != null) labels[label] = system;
    }
    final outgoing = <SystemConfig, Set<SystemConfig>>{
      for (final system in _systems) system: <SystemConfig>{},
    };
    final indegree = <SystemConfig, int>{
      for (final system in _systems) system: 0,
    };
    void edge(SystemConfig from, SystemConfig to) {
      if (outgoing[from]!.add(to)) indegree[to] = indegree[to]! + 1;
    }

    for (final system in _systems) {
      for (final label in system.after) {
        final dependency = labels[label];
        if (dependency == null) {
          throw StateError('Unknown system dependency "$label"');
        }
        edge(dependency, system);
      }
      for (final label in system.before) {
        final dependency = labels[label];
        if (dependency == null) {
          throw StateError('Unknown system dependency "$label"');
        }
        edge(system, dependency);
      }
    }

    final ready = <SystemConfig>[
      for (final system in _systems)
        if (indegree[system] == 0) system,
    ];
    final result = <SystemConfig>[];
    while (ready.isNotEmpty) {
      final system = ready.removeAt(0);
      result.add(system);
      for (final target in outgoing[system]!) {
        indegree[target] = indegree[target]! - 1;
        if (indegree[target] == 0) ready.add(target);
      }
    }
    if (result.length != _systems.length) {
      throw StateError('System ordering contains a dependency cycle');
    }
    return result;
  }
}
