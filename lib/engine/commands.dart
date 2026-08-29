import 'entity.dart';
import 'world.dart';

/// Deferred structural mutations safe to issue while systems are querying.
class Commands {
  Commands(this.world);

  final World world;

  /// Reserves an entity immediately so later commands may refer to it.
  Entity spawn([Iterable<Object> components = const []]) {
    final entity = world.reserve();
    world.defer((world) => world.materialize(entity, components));
    return entity;
  }

  void despawn(Entity entity) => world.defer((world) => world.destroy(entity));

  void add<T extends Object>(Entity entity, T component) =>
      world.defer((world) => world.add(entity, component));

  void addObject(Entity entity, Object component) =>
      world.defer((world) => world.addObject(entity, component));

  void remove<T extends Object>(Entity entity) =>
      world.defer((world) => world.remove<T>(entity));
}
