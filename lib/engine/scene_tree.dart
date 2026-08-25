import 'entity.dart';

/// Stable script-facing paths over an ECS world.
///
/// Paths are scene aliases rather than ownership: entities remain flat ECS
/// identifiers while Lua gets familiar Godot-style `get_node` lookup.
class SceneTree {
  final Map<String, Entity> _nodes = {};
  final Map<Entity, String> _paths = {};

  void register(String path, Entity entity) {
    final normalized = normalize(path);
    final previous = _nodes[normalized];
    if (previous != null) _paths.remove(previous);
    _nodes[normalized] = entity;
    _paths[entity] = normalized;
  }

  Entity? getNode(String path) => _nodes[normalize(path)];
  bool hasNode(String path) => getNode(path) != null;
  String? pathOf(Entity entity) => _paths[entity];

  void unregister(Entity entity) {
    final path = _paths.remove(entity);
    if (path != null) _nodes.remove(path);
  }

  Iterable<String> get paths => _nodes.keys;

  static String normalize(String path) {
    var result = path.trim();
    if (!result.startsWith('/')) result = '/root/$result';
    result = result.replaceAll(RegExp('/+'), '/');
    return result.length > 1 && result.endsWith('/')
        ? result.substring(0, result.length - 1)
        : result;
  }
}
