import 'package:lualike/library_builder.dart';

typedef NodeLuaCallback = Object? Function(List<Object?> arguments);

abstract class NodeEngineDocumentedLibrary extends Library {}

/// Documented native API installed into every Node Engine Lua VM.
///
/// It populates globals for compatibility. The higher-level `World`, `Scene`,
/// `HUD`, and `App` Lua tables are built on these documented primitives.
class NodeEngineLuaLibrary extends NodeEngineDocumentedLibrary {
  NodeEngineLuaLibrary(this.bindings);

  final Map<String, NodeLuaCallback> bindings;

  @override
  String get name => '';

  @override
  void registerFunctions(LibraryRegistrationContext context) {
    final builder = BuiltinFunctionBuilder(context);
    for (final entry in bindings.entries) {
      context.define(
        entry.key,
        builder.create((arguments) {
          final result = entry.value(arguments);
          // BuiltinFunction treats a Dart List as multiple Lua return values.
          // Engine collections instead represent one Lua table, matching the
          // behavior of LuaLike.expose used by older engine versions.
          if (result is List || result is Map) {
            return Value.wrap(result);
          }
          return result;
        }),
      );
      context.describe(entry.key, docs[entry.key] ?? _fallback(entry.key));
    }
    for (final table in tables) {
      context.describeTable(table.name, table);
    }
  }

  static FunctionDoc _fallback(String name) => FunctionDoc(
    summary: 'Node Engine native function `$name`.',
    params: const [DocParam('...', 'any', 'Native function arguments.')],
    returns: 'The operation result, or nil.',
    returnType: 'any',
    category: 'engine-native',
  );

  static const docs = <String, FunctionDoc>{
    'get_node': FunctionDoc(
      summary: 'Finds an entity by its scene-tree path.',
      params: [DocParam('path', 'string', 'Scene-tree path.')],
      returns: 'Entity identifier, or 0 when absent.',
      returnType: 'integer',
      category: 'scene-tree',
      nodiscard: true,
    ),
    'query_components': FunctionDoc(
      summary: 'Queries entities using component and group filters.',
      params: [DocParam('filter', 'QueryFilter', 'Query selection rules.')],
      returns: 'Matching entity identifiers.',
      returnType: 'integer[]',
      category: 'ecs',
      nodiscard: true,
    ),
    'entity_add_component': FunctionDoc(
      summary: 'Adds or replaces a script-defined component.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('component', 'string', 'Registered component name.'),
        DocParam('data', 'table', 'Component fields.', optional: true),
      ],
      category: 'ecs',
    ),
    'entity_remove_component': FunctionDoc(
      summary: 'Removes a script-defined component.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('component', 'string', 'Registered component name.'),
      ],
      category: 'ecs',
    ),
    'get_component_value': FunctionDoc(
      summary: 'Reads a script-defined component field.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('component', 'string', 'Component name.'),
        DocParam('field', 'string', 'Field name.'),
      ],
      returns: 'Stored value, or nil.',
      returnType: 'any',
      category: 'ecs',
      nodiscard: true,
    ),
    'set_component_value': FunctionDoc(
      summary: 'Writes a script-defined component field.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('component', 'string', 'Component name.'),
        DocParam('field', 'string', 'Field name.'),
        DocParam('value', 'any', 'New value.'),
      ],
      category: 'ecs',
    ),
    'entity_set_position': FunctionDoc(
      summary: 'Sets an entity world position.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('x', 'number', 'World X coordinate.'),
        DocParam('y', 'number', 'World Y coordinate.'),
        DocParam('z', 'number', 'World Z coordinate.'),
      ],
      category: 'transform',
    ),
    'scene_set_mesh': FunctionDoc(
      summary: 'Creates or updates a backend-neutral 3D mesh.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('options', 'SceneMeshOptions', 'Primitive dimensions.'),
      ],
      category: 'rendering',
    ),
    'scene_set_material': FunctionDoc(
      summary: 'Creates or updates a backend-neutral material.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('options', 'SceneMaterialOptions', 'Material properties.'),
      ],
      category: 'rendering',
    ),
    'scene_set_light': FunctionDoc(
      summary: 'Creates or updates a backend-neutral scene light.',
      params: [
        DocParam('entity', 'integer', 'Entity identifier.'),
        DocParam('options', 'SceneLightOptions', 'Light properties.'),
      ],
      category: 'rendering',
    ),
    'scene_remove_mesh': FunctionDoc(
      summary: 'Removes the mesh from an entity.',
      params: [DocParam('entity', 'integer', 'Entity identifier.')],
      category: 'rendering',
    ),
    'scene_remove_light': FunctionDoc(
      summary: 'Removes the light from an entity.',
      params: [DocParam('entity', 'integer', 'Entity identifier.')],
      category: 'rendering',
    ),
    'set_timer': FunctionDoc(
      summary: 'Schedules a Lua callback after a delay.',
      params: [
        DocParam('seconds', 'number', 'Delay in seconds.'),
        DocParam('callback', 'fun()', 'Function to invoke.'),
      ],
      returns: 'Timer identifier.',
      returnType: 'integer',
      category: 'time',
      nodiscard: true,
    ),
    'emit_signal': FunctionDoc(
      summary: 'Emits an engine signal with an optional payload.',
      params: [
        DocParam('name', 'string', 'Signal name.'),
        DocParam('payload', 'any', 'Signal payload.', optional: true),
      ],
      category: 'events',
    ),
  };

  static const tables = <TableDoc>[
    TableDoc(
      name: 'QueryFilter',
      description: 'Dynamic ECS query filters used by World.query.',
      fields: [
        FieldDoc(
          key: 'all',
          type: 'string[]',
          description: 'Components that must all be present.',
        ),
        FieldDoc(
          key: 'any',
          type: 'string[]',
          description: 'At least one component must be present.',
        ),
        FieldDoc(
          key: 'none',
          type: 'string[]',
          description: 'Components that must be absent.',
        ),
        FieldDoc(
          key: 'groups',
          type: 'string[]',
          description: 'Required scene groups.',
        ),
      ],
    ),
    TableDoc(
      name: 'SceneMeshOptions',
      description: 'Backend-neutral primitive mesh definition.',
      fields: [
        FieldDoc(
          key: 'primitive',
          type: '"box"|"sphere"|"plane"|"cylinder"|"capsule"',
          description: 'Primitive shape.',
        ),
        FieldDoc(
          key: 'width',
          type: 'number',
          description: 'Width in world units.',
        ),
        FieldDoc(
          key: 'height',
          type: 'number',
          description: 'Height in world units.',
        ),
        FieldDoc(
          key: 'depth',
          type: 'number',
          description: 'Depth in world units.',
        ),
        FieldDoc(
          key: 'radius',
          type: 'number',
          description: 'Radius for rounded primitives.',
        ),
      ],
    ),
    TableDoc(
      name: 'SceneMaterialOptions',
      description: 'Portable material values realized by the renderer.',
      fields: [
        FieldDoc(
          key: 'kind',
          type: '"unlit"|"standard"',
          description: 'Shading model.',
        ),
        FieldDoc(
          key: 'color',
          type: 'integer',
          description: 'ARGB color value.',
        ),
        FieldDoc(
          key: 'metallic',
          type: 'number',
          description: 'Metallic response from 0 to 1.',
        ),
        FieldDoc(
          key: 'roughness',
          type: 'number',
          description: 'Surface roughness from 0 to 1.',
        ),
        FieldDoc(
          key: 'emissive',
          type: 'number',
          description: 'Emission strength.',
        ),
      ],
    ),
    TableDoc(
      name: 'SceneLightOptions',
      description: 'Portable light definition realized by Flutter Scene.',
      fields: [
        FieldDoc(
          key: 'kind',
          type: '"directional"|"point"|"spot"|"area"',
          description: 'Light shape.',
        ),
        FieldDoc(
          key: 'color',
          type: 'integer',
          description: 'ARGB light color.',
        ),
        FieldDoc(
          key: 'intensity',
          type: 'number',
          description: 'Light intensity.',
        ),
        FieldDoc(
          key: 'range',
          type: 'number',
          description: 'Maximum influence distance.',
        ),
        FieldDoc(
          key: 'inner_angle',
          type: 'number',
          description: 'Spot inner angle in radians.',
        ),
        FieldDoc(
          key: 'outer_angle',
          type: 'number',
          description: 'Spot outer angle in radians.',
        ),
      ],
    ),
  ];
}

/// A documented, namespaced Lua API assembled over native engine bindings.
class NodeEngineFacadeLibrary extends NodeEngineDocumentedLibrary {
  NodeEngineFacadeLibrary({
    required this.namespace,
    required this.summary,
    required this.functions,
  });

  final String namespace;
  final String summary;
  final Map<String, ({NodeLuaCallback callback, FunctionDoc doc})> functions;

  @override
  String get name => namespace;

  @override
  String get description => summary;

  @override
  void registerFunctions(LibraryRegistrationContext context) {
    final builder = BuiltinFunctionBuilder(context);
    for (final entry in functions.entries) {
      context.define(
        entry.key,
        builder.create(
          (arguments) => _tableResult(entry.value.callback(arguments)),
        ),
      );
      context.describe(entry.key, entry.value.doc);
    }
  }

  static Object? _tableResult(Object? result) =>
      result is List || result is Map ? Value.wrap(result) : result;
}
