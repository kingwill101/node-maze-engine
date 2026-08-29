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
    final entity = reserve();
    materialize(entity, components);
    return entity;
  }

  Entity reserve() => Entity(_nextEntity++);

  void materialize(Entity entity, [Iterable<Object> components = const []]) {
    if (isAlive(entity)) throw StateError('Entity $entity is already alive');
    _entities.add(entity);
    for (final component in components) {
      addObject(entity, component);
    }
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

  bool hasType(Entity entity, Type type) =>
      _stores[type]?.containsKey(entity) ?? false;

  Object? maybeGetType(Entity entity, Type type) => _stores[type]?[entity];

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

  Iterable<(Entity, A, B, C)>
  query3<A extends Object, B extends Object, C extends Object>() sync* {
    for (final (entity, a, b) in query2<A, B>()) {
      final c = maybeGet<C>(entity);
      if (c != null) yield (entity, a, b, c);
    }
  }

  Iterable<Entity> queryTypes({
    Iterable<Type> withTypes = const <Type>[],
    Iterable<Type> withoutTypes = const <Type>[],
  }) sync* {
    final required = withTypes.toList(growable: false);
    final excluded = withoutTypes.toList(growable: false);
    for (final entity in List<Entity>.of(_entities)) {
      if (required.every((type) => hasType(entity, type)) &&
          excluded.every((type) => !hasType(entity, type))) {
        yield entity;
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
