---@meta _
---Generated LuaLS annotations for node_engine.
---Do not execute this file; add it to LuaLS as a library.
---Generator: lualike.docs
---Schema: 2

---@class QueryFilter
---Dynamic ECS query filters used by World.query.
---
---@field all? string[] # Components that must all be present.
---@field any? string[] # At least one component must be present.
---@field none? string[] # Components that must be absent.
---@field groups? string[] # Required scene groups.

---@class SceneMeshOptions
---Backend-neutral primitive mesh definition.
---
---@field primitive? "box"|"sphere"|"plane"|"cylinder"|"capsule" # Primitive shape.
---@field width? number # Width in world units.
---@field height? number # Height in world units.
---@field depth? number # Depth in world units.
---@field radius? number # Radius for rounded primitives.

---@class SceneMaterialOptions
---Portable material values realized by the renderer.
---
---@field kind? "unlit"|"standard" # Shading model.
---@field color? integer # ARGB color value.
---@field metallic? number # Metallic response from 0 to 1.
---@field roughness? number # Surface roughness from 0 to 1.
---@field emissive? number # Emission strength.

---@class SceneLightOptions
---Portable light definition realized by Flutter Scene.
---
---@field kind? "directional"|"point"|"spot"|"area" # Light shape.
---@field color? integer # ARGB light color.
---@field intensity? number # Light intensity.
---@field range? number # Maximum influence distance.
---@field inner_angle? number # Spot inner angle in radians.
---@field outer_angle? number # Spot outer angle in radians.

---@class Vec3
---Three-dimensional vector accepted by engine APIs.
---
---@field x? number # X component.
---@field y? number # Y component.
---@field z? number # Z component.

---@class PhysicsBodyOptions
---Rigid-body configuration consumed by Physics.body.
---
---@field kind? "fixed"|"kinematic"|"dynamic" # How the body moves. Dynamic requires a solver backend.
---@field mass? number # Additional mass.
---@field velocity? Vec3 # Initial linear velocity.
---@field angular_velocity? Vec3 # Initial angular velocity.
---@field linear_damping? number # Linear damping coefficient.
---@field angular_damping? number # Angular damping coefficient.
---@field gravity_scale? number # Multiplier applied to world gravity.
---@field ccd? boolean # Enables continuous collision detection.
---@field linear_axis_factor? Vec3 # Per-axis linear motion factors from 0 to 1.
---@field angular_axis_factor? Vec3 # Per-axis angular motion factors from 0 to 1.

---@class PhysicsColliderOptions
---Collider shape, material, trigger, and filter values.
---
---@field shape? "box"|"sphere"|"capsule"|"cylinder" # Primitive collision shape.
---@field half_extents? Vec3 # Box half-size on each axis.
---@field radius? number # Sphere, capsule, or cylinder radius.
---@field half_height? number # Capsule or cylinder half-height.
---@field offset? Vec3 # Local offset.
---@field trigger? boolean # Reports overlaps without solid contact.
---@field friction? number # Surface friction.
---@field restitution? number # Surface bounciness.
---@field density? number # Mass per unit volume.
---@field layer? integer # Collision membership bit mask.
---@field mask? integer # Layers this collider interacts with.

---@class PhysicsQueryOptions
---Shared filtering options for spatial queries.
---
---@field max_distance? number # Maximum ray distance.
---@field layer_mask? integer # Collider layers included by the query.
---@field include_triggers? boolean # Whether trigger volumes can be returned.

---@class PhysicsRayHit
---Entity-resolved scene-query result.
---
---@field entity? integer # Hit entity identifier.
---@field point? Vec3 # World hit point.
---@field normal? Vec3 # World surface normal.
---@field distance? number # Distance from query origin.

---@nodiscard
---Finds an entity by its scene-tree path.
---@param path string # Scene-tree path.
---@return integer # Entity identifier, or 0 when absent.
function get_node(path) end

---@private
---Internal Node Engine compatibility binding `has_node`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function has_node(...) end

---@private
---Internal Node Engine compatibility binding `get_node_path`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function get_node_path(...) end

---@private
---Internal Node Engine compatibility binding `get_scene_paths`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function get_scene_paths(...) end

---@private
---Internal Node Engine compatibility binding `get_nodes_in_group`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function get_nodes_in_group(...) end

---@private
---Internal Node Engine compatibility binding `_engine_instantiate_empty`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function _engine_instantiate_empty(...) end

---@private
---Internal Node Engine compatibility binding `entity_set_path`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_set_path(...) end

---@private
---Internal Node Engine compatibility binding `entity_set_velocity`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_set_velocity(...) end

---@private
---Internal Node Engine compatibility binding `entity_is_alive`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_is_alive(...) end

---@private
---Internal Node Engine compatibility binding `entity_has_component`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_has_component(...) end

---@private
---Internal Node Engine compatibility binding `add_component`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function add_component(...) end

---@private
---Internal Node Engine compatibility binding `remove_component`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function remove_component(...) end

---@private
---Internal Node Engine compatibility binding `has_component`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function has_component(...) end

---@private
---Internal Node Engine compatibility binding `get_component`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function get_component(...) end

---@nodiscard
---Reads a script-defined component field.
---@param entity integer # Entity identifier.
---@param component string # Component name.
---@param field string # Field name.
---@return any # Stored value, or nil.
function get_component_value(entity, component, field) end

---Writes a script-defined component field.
---@param entity integer # Entity identifier.
---@param component string # Component name.
---@param field string # Field name.
---@param value any # New value.
function set_component_value(entity, component, field, value) end

---@private
---Internal Node Engine compatibility binding `get_nodes_with_component`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function get_nodes_with_component(...) end

---@nodiscard
---Queries entities using component and group filters.
---@param filter QueryFilter # Query selection rules.
---@return integer[] # Matching entity identifiers.
function query_components(filter) end

---Creates or updates a backend-neutral 3D mesh.
---@param entity integer # Entity identifier.
---@param options SceneMeshOptions # Primitive dimensions.
function scene_set_mesh(entity, options) end

---Creates or updates a backend-neutral material.
---@param entity integer # Entity identifier.
---@param options SceneMaterialOptions # Material properties.
function scene_set_material(entity, options) end

---Removes the mesh from an entity.
---@param entity integer # Entity identifier.
function scene_remove_mesh(entity) end

---Creates or updates a backend-neutral scene light.
---@param entity integer # Entity identifier.
---@param options SceneLightOptions # Light properties.
function scene_set_light(entity, options) end

---Removes the light from an entity.
---@param entity integer # Entity identifier.
function scene_remove_light(entity) end

---@private
---Internal Node Engine compatibility binding `scene_set_camera`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function scene_set_camera(...) end

---@private
---Internal Node Engine compatibility binding `scene_set_asset`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function scene_set_asset(...) end

---@private
---Internal Node Engine compatibility binding `scene_set_particles`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function scene_set_particles(...) end

---@private
---Internal Node Engine compatibility binding `scene_set_environment`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function scene_set_environment(...) end

---@private
---Internal Node Engine compatibility binding `physics_set_body`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_set_body(...) end

---@private
---Internal Node Engine compatibility binding `physics_set_collider`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_set_collider(...) end

---@private
---Internal Node Engine compatibility binding `physics_remove`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_remove(...) end

---@private
---Internal Node Engine compatibility binding `physics_raycast`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_raycast(...) end

---@private
---Internal Node Engine compatibility binding `physics_overlap_sphere`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_overlap_sphere(...) end

---@private
---Internal Node Engine compatibility binding `physics_set_velocity`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_set_velocity(...) end

---@private
---Internal Node Engine compatibility binding `physics_apply_impulse`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function physics_apply_impulse(...) end

---Adds or replaces a script-defined component.
---@param entity integer # Entity identifier.
---@param component string # Registered component name.
---@param data? table # Component fields.
function entity_add_component(entity, component, data) end

---Removes a script-defined component.
---@param entity integer # Entity identifier.
---@param component string # Registered component name.
function entity_remove_component(entity, component) end

---@private
---Internal Node Engine compatibility binding `entity_get_x`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_get_x(...) end

---@private
---Internal Node Engine compatibility binding `entity_get_y`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_get_y(...) end

---@private
---Internal Node Engine compatibility binding `entity_get_z`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_get_z(...) end

---Sets an entity world position.
---@param entity integer # Entity identifier.
---@param x number # World X coordinate.
---@param y number # World Y coordinate.
---@param z number # World Z coordinate.
function entity_set_position(entity, x, y, z) end

---@private
---Internal Node Engine compatibility binding `game_add_score`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function game_add_score(...) end

---@private
---Internal Node Engine compatibility binding `game_damage_player`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function game_damage_player(...) end

---@private
---Internal Node Engine compatibility binding `game_get_lives`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function game_get_lives(...) end

---@private
---Internal Node Engine compatibility binding `platformer_set_checkpoint`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function platformer_set_checkpoint(...) end

---@private
---Internal Node Engine compatibility binding `platformer_launch`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function platformer_launch(...) end

---@private
---Internal Node Engine compatibility binding `game_complete_level`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function game_complete_level(...) end

---@private
---Internal Node Engine compatibility binding `door_set_open`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function door_set_open(...) end

---@private
---Internal Node Engine compatibility binding `platformer_move_platform`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function platformer_move_platform(...) end

---@private
---Internal Node Engine compatibility binding `door_is_open`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function door_is_open(...) end

---@private
---Internal Node Engine compatibility binding `trap_set_active`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function trap_set_active(...) end

---@private
---Internal Node Engine compatibility binding `entity_destroy`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_destroy(...) end

---@private
---Internal Node Engine compatibility binding `draw_sphere`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function draw_sphere(...) end

---@private
---Internal Node Engine compatibility binding `draw_box`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function draw_box(...) end

---@private
---Internal Node Engine compatibility binding `drawing_set_animation`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function drawing_set_animation(...) end

---@private
---Internal Node Engine compatibility binding `drawing_remove`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function drawing_remove(...) end

---@private
---Internal Node Engine compatibility binding `drawing_clear`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function drawing_clear(...) end

---@private
---Internal Node Engine compatibility binding `particle_emitter`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function particle_emitter(...) end

---@private
---Internal Node Engine compatibility binding `particle_remove`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function particle_remove(...) end

---@private
---Internal Node Engine compatibility binding `particle_clear`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function particle_clear(...) end

---@private
---Internal Node Engine compatibility binding `hud_label`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function hud_label(...) end

---@private
---Internal Node Engine compatibility binding `hud_bar`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function hud_bar(...) end

---@private
---Internal Node Engine compatibility binding `hud_remove`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function hud_remove(...) end

---@private
---Internal Node Engine compatibility binding `hud_clear`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function hud_clear(...) end

---@private
---Internal Node Engine compatibility binding `entity_get_property`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_get_property(...) end

---@private
---Internal Node Engine compatibility binding `entity_set_property`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_set_property(...) end

---@private
---Internal Node Engine compatibility binding `entity_add_to_group`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_add_to_group(...) end

---@private
---Internal Node Engine compatibility binding `entity_remove_from_group`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_remove_from_group(...) end

---@private
---Internal Node Engine compatibility binding `entity_is_in_group`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_is_in_group(...) end

---@private
---Internal Node Engine compatibility binding `group_count`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function group_count(...) end

---@private
---Internal Node Engine compatibility binding `group_nearest`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function group_nearest(...) end

---Emits an engine signal with an optional payload.
---@param name string # Signal name.
---@param payload? any # Signal payload.
function emit_signal(name, payload) end

---@nodiscard
---Schedules a Lua callback after a delay.
---@param seconds number # Delay in seconds.
---@param callback fun() # Function to invoke.
---@return integer # Timer identifier.
function set_timer(seconds, callback) end

---@private
---Internal Node Engine compatibility binding `cancel_timer`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function cancel_timer(...) end

---@private
---Internal Node Engine compatibility binding `entity_request_move`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_request_move(...) end

---@private
---Internal Node Engine compatibility binding `entity_can_move`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_can_move(...) end

---@private
---Internal Node Engine compatibility binding `ghost_personality`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function ghost_personality(...) end

---@private
---Internal Node Engine compatibility binding `player_get_x`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function player_get_x(...) end

---@private
---Internal Node Engine compatibility binding `player_get_z`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function player_get_z(...) end

---@private
---Internal Node Engine compatibility binding `player_get_dx`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function player_get_dx(...) end

---@private
---Internal Node Engine compatibility binding `player_get_dz`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function player_get_dz(...) end

---@private
---Internal Node Engine compatibility binding `power_active`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function power_active(...) end

---@private
---Internal Node Engine compatibility binding `entity_request_target`.
---@param ... any # Native function arguments.
---@return any # The operation result, or nil.
function entity_request_target(...) end

---@type table
World = World or {}

---@nodiscard
---Returns entities containing every requested component.
---@param ... string # Required component names.
---@return integer[] # Matching entity identifiers.
function World.query(...) end

---@nodiscard
---Returns entities matching include and exclude component lists.
---@param with_components string[] # Required components.
---@param without_components string[] # Excluded components.
---@return integer[] # Matching entity identifiers.
function World.query_filtered(with_components, without_components) end

---@nodiscard
---Returns a component table for an entity.
---@param entity integer # Entity identifier.
---@param component string # Component name.
---@return table|nil # Live component data, or nil.
function World.get(entity, component) end

---@nodiscard
---Tests whether an entity contains a component.
---@param entity integer # Entity identifier.
---@param component string # Component name.
---@return boolean # True when the component exists.
function World.has(entity, component) end

---@type table
Scene = Scene or {}

---Creates or updates an entity mesh.
---@param entity integer # Entity identifier.
---@param options SceneMeshOptions # Mesh definition.
function Scene.mesh(entity, options) end

---Creates or updates an entity material.
---@param entity integer # Entity identifier.
---@param options SceneMaterialOptions # Material definition.
function Scene.material(entity, options) end

---Creates or updates an entity light.
---@param entity integer # Entity identifier.
---@param options SceneLightOptions # Light definition.
function Scene.light(entity, options) end

---Removes an entity mesh.
---@param entity integer # Entity identifier.
function Scene.remove_mesh(entity) end

---Removes an entity light.
---@param entity integer # Entity identifier.
function Scene.remove_light(entity) end

---Creates or updates an entity camera.
---@param entity integer # Entity identifier.
---@param options table # Perspective camera definition.
function Scene.camera(entity, options) end

---Loads an animated 3D model on an entity.
---@param entity integer # Entity identifier.
---@param options table # Model asset and animation settings.
function Scene.model(entity, options) end

---Creates or updates a Flutter Scene particle emitter.
---@param entity integer # Entity identifier.
---@param options table # Emitter and module settings.
function Scene.particles(entity, options) end

---Configures scene lighting and post-processing.
---@param entity integer # Entity identifier.
---@param options table # Environment effect settings.
function Scene.environment(entity, options) end

---@type table
Node = Node or {}

---@nodiscard
---Finds an entity by path.
---@param path string # Scene-tree path.
function Node.get(path) end

---@nodiscard
---Tests whether a path exists.
---@param path string # Scene-tree path.
function Node.has(path) end

---@nodiscard
---Returns an entity scene path.
---@param entity integer # Entity identifier.
function Node.path(entity) end

---Queues an entity for destruction.
---@param entity integer # Entity identifier.
function Node.queue_free(entity) end

---Adds an entity to a group.
---@param entity integer # Entity identifier.
---@param group string # Group name.
function Node.add_to_group(entity, group) end

---Removes an entity from a group.
---@param entity integer # Entity identifier.
---@param group string # Group name.
function Node.remove_from_group(entity, group) end

---@nodiscard
---Tests entity group membership.
---@param entity integer # Entity identifier.
---@param group string # Group name.
function Node.is_in_group(entity, group) end

---Removes a dynamic component.
---@param entity integer # Entity identifier.
---@param component string # Component name.
function Node.remove_component(entity, component) end

---@nodiscard
---Tests component membership.
---@param entity integer # Entity identifier.
---@param component string # Component name.
function Node.has_component(entity, component) end

---@nodiscard
---Returns component data.
---@param entity integer # Entity identifier.
---@param component string # Component name.
function Node.get_component(entity, component) end

---@nodiscard
---Reads a component field.
---@param entity integer # Entity identifier.
---@param component string # Component name.
---@param key string # Field name.
function Node.get_value(entity, component, key) end

---Writes a component field.
---@param entity integer # Entity identifier.
---@param component string # Component name.
---@param key string # Field name.
---@param value any # New value.
function Node.set_value(entity, component, key, value) end

---@type table
SceneTree = SceneTree or {}

---@nodiscard
---Returns entities in a group.
---@param group string # Group name.
function SceneTree.get_nodes_in_group(group) end

---@nodiscard
---Returns entities with a component.
---@param component string # Component name.
function SceneTree.get_nodes_with_component(component) end

---@nodiscard
---Returns registered scene node count.
function SceneTree.node_count() end

---@type table
Physics = Physics or {}

---Creates or replaces an entity rigid body.
---@param entity integer # Entity identifier.
---@param options PhysicsBodyOptions # Body configuration.
function Physics.body(entity, options) end

---Creates or replaces an entity collider.
---@param entity integer # Entity identifier.
---@param options PhysicsColliderOptions # Shape, material, and filter configuration.
function Physics.collider(entity, options) end

---Removes physics components from an entity.
---@param entity integer # Entity identifier.
function Physics.remove(entity) end

---@nodiscard
---Returns the closest collider along a ray.
---@param origin Vec3 # World-space ray origin.
---@param direction Vec3 # Ray direction.
---@param options? PhysicsQueryOptions # Query filters.
---@return PhysicsRayHit|nil # Closest hit, or nil.
function Physics.raycast(origin, direction, options) end

---@nodiscard
---Returns entities overlapping a sphere.
---@param center Vec3 # World-space sphere center.
---@param radius number # Sphere radius.
---@param options? PhysicsQueryOptions # Query filters.
---@return integer[] # Unique overlapping entity identifiers.
function Physics.overlap_sphere(center, radius, options) end

---Sets a registered body linear velocity.
---@param entity integer # Entity identifier.
---@param velocity Vec3 # World-space velocity.
function Physics.set_velocity(entity, velocity) end

---Applies an instantaneous impulse to a body.
---@param entity integer # Entity identifier.
---@param impulse Vec3 # World-space impulse.
function Physics.apply_impulse(entity, impulse) end

