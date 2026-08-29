local player = 0
local gears_left = 0
local gears_total = 0
local checkpoint_x = 3
local checkpoint_y = 0.9
local respawns = 0
local damage_cooldown = 0
local animation_time = 0
-- Scripted platformer rigs use the entity origin at the collider centre.
-- Tavi's original art was authored from the soles upward, so translate the
-- whole rig to put the lowest boot point at PlatformerBody.halfHeight (-0.45).
-- A boot is centred at 0.20 and draw_box's 0.16 height is a full extent, so
-- its unshifted sole is 0.12; 0.12 - 0.57 = -0.45.
local rig_y = -0.57

local chapters = {
  ['Clover Gearway'] = { count = 16, heights = {0,0.8,1.7,0.7,0,1.1,2.0,1.0}, moving = false },
  ['Treetop Foundry'] = { count = 22, heights = {0,1.0,2.1,3.0,2.0,0.9,1.8,2.8,1.6}, moving = true },
  ['Sunbell Keep'] = { count = 28, heights = {0,1.1,2.2,3.2,2.1,1.0,0,1.2,2.4,3.3}, moving = true },
}

local function platform(path, x, y, width, moving)
  local entity = Prefab.instantiate('grass_platform', path, x, y, 2)
  Node.set_value(entity, 'platform', 'width', width)
  drawing_remove(entity, 'brick')
  drawing_remove(entity, 'grass')
  drawing_remove(entity, 'soil')
  draw_box(entity, 'brick', 0, 0, 0, width * 0.5, 0.34, 0.9, '#c96b32')
  draw_box(entity, 'grass', 0, 0.34, 0, width * 0.5, 0.09, 0.94, '#55c95d')
  draw_box(entity, 'soil', 0, -0.25, 0, width * 0.46, 0.08, 0.88, '#7b3f2b')
  if moving then Node.add_component(entity, 'moving_platform', { origin = y, phase = x * 0.17 }) end
  return entity
end

local function dress_player()
  Node.add_component(player, 'platformer_player', { grounded = false })
  Node.add_component(player, 'character_animation', { state = 'idle', facing = 1 })
  draw_sphere(player, 'body', 0, rig_y + 0.66, 0, 0.34, '#2676d8')
  draw_sphere(player, 'head', 0, rig_y + 1.2, 0, 0.4, '#f7c873')
  draw_box(player, 'cap', -0.05, rig_y + 1.58, 0, 0.42, 0.12, 0.36, '#16a085')
  draw_box(player, 'cap_bill', 0.34, rig_y + 1.5, 0, 0.24, 0.06, 0.32, '#0f766e')
  draw_sphere(player, 'eye', 0.27, rig_y + 1.27, 0.3, 0.055, '#172554')
  draw_box(player, 'boot_left', -0.2, rig_y + 0.2, 0, 0.18, 0.16, 0.28, '#c2413b')
  draw_box(player, 'boot_right', 0.2, rig_y + 0.2, 0, 0.18, 0.16, 0.28, '#c2413b')
  draw_sphere(player, 'glove_left', -0.38, rig_y + 0.72, 0, 0.13, '#f5f1d8')
  draw_sphere(player, 'glove_right', 0.38, rig_y + 0.72, 0, 0.13, '#f5f1d8')
  draw_box(player, 'scarf', -0.28, rig_y + 1.0, -0.05, 0.34, 0.08, 0.12, '#ff8a3d')
end

local function build_level(root, config)
  for _, enemy in ipairs(SceneTree.get_nodes_in_group('enemies')) do Node.queue_free(enemy) end
  entity_set_position(player, 3, 0.9, 2)
  platformer_set_checkpoint(player, 3, 0.9)
  checkpoint_x, checkpoint_y = 3, 0.9
  dress_player()
  gears_left, gears_total = 0, 0
  local spacing = 4.8
  for index = 1, config.count do
    local x = 3 + (index - 1) * spacing
    local y = config.heights[((index - 1) % #config.heights) + 1]
    local width = index == 1 and 6.5 or 3.6
    local landing = platform('/root/platforms/' .. index, x, y, width, config.moving and index % 6 == 0)
    if index > 1 and index < config.count then
      Prefab.instantiate('gear_coin', '/root/gears/' .. index, x, y + 1.0, 2)
      gears_left, gears_total = gears_left + 1, gears_total + 1
    end
    if index > 2 and index % 4 == 0 then
      -- Feet end at local -0.06; +0.445 puts them on grass at +0.385.
      local bug = Prefab.instantiate('beetle', '/root/beetles/' .. index, x + 0.45, y + 0.445, 2)
      Node.set_value(bug, 'walker', 'origin', x + 0.45)
      Node.add_component(bug, 'platform_rider', { platform = landing })
    end
    if index > 2 and index % 7 == 0 then
      Prefab.instantiate('spring', '/root/springs/' .. index, x - 0.7, y + 0.4, 2)
    end
    if index > 2 and index % 9 == 0 then
      Prefab.instantiate('checkpoint', '/root/checkpoints/' .. index, x, y + 0.35, 2)
    end
  end
  local final_x = 3 + (config.count - 1) * spacing
  local final_y = config.heights[((config.count - 1) % #config.heights) + 1]
  Prefab.instantiate('finish_bell', '/root/finish', final_x + 0.8, final_y + 0.35, 2)
  entity_set_property(root, 'move_axis', 0)
  entity_set_property(root, 'jump_requested', false)
  hud_label(root, 'gears', 'BRASS GEARS 0/' .. gears_total, 'top_right', 20, 20, '#ffd23f', 14)
  hud_label(root, 'world', 'BRASSCAP RUN', 'top_left', 20, 58, '#8dffef', 14)
end

local function animate_player(root, delta)
  animation_time = animation_time + delta
  local axis = entity_get_property(root, 'move_axis') or 0
  local facing = axis < 0 and -1 or 1
  local stride = math.abs(axis) > 0.01 and math.sin(animation_time * 13) or 0
  local bob = math.abs(stride) * 0.035
  draw_sphere(player, 'body', 0, rig_y + 0.66 + bob, 0, 0.34, '#2676d8')
  draw_sphere(player, 'head', 0, rig_y + 1.2 + bob, 0, 0.4, '#f7c873')
  draw_box(player, 'cap', -0.05, rig_y + 1.58 + bob, 0, 0.42, 0.12, 0.36, '#16a085')
  draw_box(player, 'cap_bill', facing * 0.34, rig_y + 1.5 + bob, 0, 0.24, 0.06, 0.32, '#0f766e')
  draw_sphere(player, 'eye', facing * 0.27, rig_y + 1.27 + bob, 0.3, 0.055, '#172554')
  draw_box(player, 'boot_left', -0.2, rig_y + 0.2 + stride * 0.07, 0, 0.18, 0.16, 0.28, '#c2413b')
  draw_box(player, 'boot_right', 0.2, rig_y + 0.2 - stride * 0.07, 0, 0.18, 0.16, 0.28, '#c2413b')
  draw_sphere(player, 'glove_left', -0.38, rig_y + 0.72 - stride * 0.08, 0, 0.13, '#f5f1d8')
  draw_sphere(player, 'glove_right', 0.38, rig_y + 0.72 + stride * 0.08, 0, 0.13, '#f5f1d8')
  draw_box(player, 'scarf', -facing * 0.28, rig_y + 1.0 + bob, -0.05, 0.34, 0.08, 0.12, '#ff8a3d')
  Node.set_value(player, 'character_animation', 'state', math.abs(axis) > 0.01 and 'run' or 'idle')
  Node.set_value(player, 'character_animation', 'facing', facing)
end

function ready(root)
  player = Node.get('/root/player')
  local config = chapters[entity_get_property(root, 'scene_name')]
  if config ~= nil then build_level(root, config) end
end

function fixed_update(root, delta)
  local x, y = entity_get_x(player), entity_get_y(player)
  damage_cooldown = math.max(0, damage_cooldown - delta)
  animate_player(root, delta)

  local new_respawns = Node.get_value(player, 'platformer_player', 'respawn_count') or 0
  if new_respawns > respawns then
    respawns = new_respawns
    game_damage_player(1, 'TAVI TUMBLED — TRY THE GEARWAY AGAIN')
  end

  for _, gear in ipairs(SceneTree.get_nodes_with_component('gear_coin')) do
    if math.abs(x - entity_get_x(gear)) < 0.55 and math.abs(y - entity_get_y(gear)) < 0.8 then
      Node.queue_free(gear)
      gears_left = gears_left - 1
      game_add_score(100)
      particle_emitter(player, 'gear_flash', 10, 0.4, 4, 0.04, '#ffd23f', 'burst', 0.4)
      hud_label(root, 'gears', 'BRASS GEARS ' .. (gears_total - gears_left) .. '/' .. gears_total, 'top_right', 20, 20, '#ffd23f', 14)
    end
  end

  for _, spring in ipairs(SceneTree.get_nodes_with_component('spring')) do
    if math.abs(x - entity_get_x(spring)) < 0.5 and math.abs(y - entity_get_y(spring)) < 0.8 then
      platformer_launch(player, Node.get_value(spring, 'spring', 'power') or 10.5)
      particle_emitter(spring, 'boing', 8, 0.35, 5, 0.035, '#f5f1d8', 'fountain', 0.35)
    end
  end

  for _, checkpoint in ipairs(SceneTree.get_nodes_with_component('checkpoint')) do
    if not Node.get_value(checkpoint, 'checkpoint', 'active') and math.abs(x - entity_get_x(checkpoint)) < 0.6 then
      Node.set_value(checkpoint, 'checkpoint', 'active', true)
      checkpoint_x, checkpoint_y = entity_get_x(checkpoint), entity_get_y(checkpoint) + 0.8
      platformer_set_checkpoint(player, checkpoint_x, checkpoint_y)
      hud_label(root, 'message', 'WIND PENNANT SAVED!', 'top_left', 20, 92, '#8dffef', 13)
    end
  end

  for _, walker in ipairs(SceneTree.get_nodes_with_component('walker')) do
    local ex = entity_get_x(walker)
    local origin = Node.get_value(walker, 'walker', 'origin') or ex
    local range = Node.get_value(walker, 'walker', 'range') or 1.4
    local direction = Node.get_value(walker, 'walker', 'direction') or 1
    ex = ex + direction * (Node.get_value(walker, 'walker', 'speed') or 1.25) * delta
    if ex > origin + range or ex < origin - range then direction = -direction end
    entity_set_position(walker, ex, entity_get_y(walker), 2)
    Node.set_value(walker, 'walker', 'direction', direction)
    if damage_cooldown <= 0 and math.abs(x - ex) < 0.58 and math.abs(y - entity_get_y(walker)) < 0.78 then
      local velocity = Node.get_value(player, 'platformer_player', 'velocity_y') or 0
      if velocity < 0 and y > entity_get_y(walker) + 0.35 then
        Node.queue_free(walker)
        platformer_launch(player, 5.4)
        game_add_score(250)
      else
        game_damage_player(1, 'A TICK-BEETLE BONKED TAVI')
        entity_set_position(player, checkpoint_x, checkpoint_y, 2)
        damage_cooldown = 1.0
      end
    end
  end

  for _, moving in ipairs(SceneTree.get_nodes_with_component('moving_platform')) do
    local origin = Node.get_value(moving, 'moving_platform', 'origin') or entity_get_y(moving)
    local phase = Node.get_value(moving, 'moving_platform', 'phase') or 0
    platformer_move_platform(moving, entity_get_x(moving), origin + math.sin(phase + x * 0.02) * 0.65, 2)
    Node.set_value(moving, 'moving_platform', 'phase', phase + delta * 1.4)
  end

  local finish = Node.get('/root/finish')
  if finish ~= 0 and gears_left == 0 and math.abs(x - entity_get_x(finish)) < 0.8 then
    hud_label(root, 'message', 'THE SUNBELL RINGS!', 'top_left', 20, 92, '#ffd23f', 14)
    game_complete_level('THE SUNBELL RINGS — GEARWAY CLEAR!')
  end
end
