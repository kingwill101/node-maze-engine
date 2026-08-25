import 'entity.dart';

typedef WorldCommand = void Function(World world);

/// Minimal type-safe entity component store.
class World {
  int _nextEntity = 1;
  final Set<Entity> _entities = <Entity>{};
  final Map<Type, Map<Entity, Object>> _stores = <Type, Map<Entity, Object>>{};
  final List<WorldCommand> _commands = <WorldCommand>[];

  Iterable<Entity> get entities => _entities;
  int get entityCount => _entities.length;

  Entity create([Iterable<Object> components = const []]) {
    final entity = Entity(_nextEntity++);
    _entities.add(entity);
    for (final component in components) {
      addObject(entity, component);
    }
    return entity;
  }

  bool isAlive(Entity entity) => _entities.contains(entity);

  void destroy(Entity entity) {
    if (!_entities.remove(entity)) return;
    for (final store in _stores.values) {
      store.remove(entity);
    }
  }

  void add<T extends Object>(Entity entity, T component) {
    _requireAlive(entity);
    (_stores[T] ??= <Entity, Object>{})[entity] = component;
  }

  void addObject(Entity entity, Object component) {
    _requireAlive(entity);
    (_stores[component.runtimeType] ??= <Entity, Object>{})[entity] = component;
  }

  T? maybeGet<T extends Object>(Entity entity) => _stores[T]?[entity] as T?;

  T get<T extends Object>(Entity entity) =>
      maybeGet<T>(entity) ??
      (throw StateError('Entity $entity does not have component $T'));

  bool has<T extends Object>(Entity entity) =>
      _stores[T]?.containsKey(entity) ?? false;

  T? remove<T extends Object>(Entity entity) =>
      _stores[T]?.remove(entity) as T?;

  Iterable<(Entity, T)> query<T extends Object>() sync* {
    final store = _stores[T];
    if (store == null) return;
    for (final entry in List<MapEntry<Entity, Object>>.of(store.entries)) {
      if (isAlive(entry.key)) yield (entry.key, entry.value as T);
    }
  }

  Iterable<(Entity, A, B)> query2<A extends Object, B extends Object>() sync* {
    final aStore = _stores[A];
    final bStore = _stores[B];
    if (aStore == null || bStore == null) return;
    final source = aStore.length <= bStore.length ? aStore : bStore;
    for (final entity in List<Entity>.of(source.keys)) {
      final a = aStore[entity];
      final b = bStore[entity];
      if (a != null && b != null && isAlive(entity)) {
        yield (entity, a as A, b as B);
      }
    }
  }

  void defer(WorldCommand command) => _commands.add(command);

  void flush() {
    while (_commands.isNotEmpty) {
      final commands = List<WorldCommand>.of(_commands);
      _commands.clear();
      for (final command in commands) {
        command(this);
      }
    }
  }

  void _requireAlive(Entity entity) {
    if (!isAlive(entity)) throw StateError('Entity $entity is not alive');
  }
}
