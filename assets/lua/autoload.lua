-- Global scene bootstrap. This VM is attached to /root before entity scripts,
-- analogous to a Godot autoload coordinating one active scene.
local player = 0
local portal_a = 0
local portal_b = 0
local portal_cooldown = 0
local hud_refresh = 0
local boss = 0
local boss_phase = 'dormant'
local projectile_serial = 0
local platformer_active = false
local platformer_velocity_y = 0
local platformer_grounded = false
local platformer_crystals = 0

local function spawn_platform(path, x, y, width)
  local platform = Prefab.instantiate('platform', path, x, y, 2)
  Node.set_value(platform, 'platform', 'width', width)
  draw_box(platform, 'stone', 0, 0, 0, width * 0.675, 0.35, 1.1, '#23315f')
  draw_box(platform, 'rune_rail', 0, 0.32, 0, width * 0.675, 0.06, 1.14, '#31e7ff')
  drawing_set_animation(platform, 'rune_rail', 'pulse', 2.4, 0.08)
  return platform
end

local function setup_platformer(root)
  platformer_active = true
  entity_set_position(player, 2, 0.9, 2)
  Node.add_component(player, 'platformer_player', { grounded = false })
  for _, enemy in ipairs(SceneTree.get_nodes_in_group('enemies')) do
    Node.queue_free(enemy)
  end

  spawn_platform('/root/platforms/start', 4.5, 0, 6.5)
  spawn_platform('/root/platforms/step_one', 9.5, 1.65, 2.2)
  spawn_platform('/root/platforms/step_two', 13.2, 3.0, 2.0)
  spawn_platform('/root/platforms/final', 17.2, 1.5, 3.8)

  local crystal_positions = {
    { 5.5, 1.0 }, { 9.5, 2.65 }, { 13.2, 4.0 }, { 17.4, 2.5 },
  }
  for index, position in ipairs(crystal_positions) do
    Prefab.instantiate('crystal', '/root/crystals/' .. index, position[1], position[2], 2)
  end
  platformer_crystals = #crystal_positions
  Prefab.instantiate('exit_gate', '/root/platformer_exit', 19.1, 2.15, 2)

  entity_set_property(root, 'move_axis', 0)
  entity_set_property(root, 'jump_requested', false)
  hud_label(root, 'platform_help', 'A/D MOVE   SPACE JUMP', 'bottom_left', 20, 24, '#31e7ff', 13)
  hud_label(root, 'platform_goal', 'STAR CRYSTALS 0/4', 'top_right', 20, 20, '#ffd45c', 14)
  emit_signal(root, 'platformer_ready', player)
end

function ready(root)
  player = get_node('/root/player')
  portal_a = get_node('/root/portals/1')
  portal_b = get_node('/root/portals/2')
  entity_set_property(root, 'bootstrapped', true)
  entity_set_property(root, 'player_node', player)
  entity_set_property(root, 'enemy_count', group_count('enemies'))
  entity_set_property(player, 'scene_ready', true)
  entity_add_component(root, 'hud')
  hud_label(root, 'status', 'LUA HUD INITIALIZING', 'top_right', 20, 20, '#ffffff', 14)
  if entity_get_property(root, 'scene_name') == 'Moonfall Causeway' then
    setup_platformer(root)
    return
  end
  local px = entity_get_x(player)
  local pz = entity_get_z(player)
  local wisp_a = instantiate('wisp', '/root/effects/guide_wisp_a', px + 1, 0.2, pz)
  local wisp_b = instantiate('wisp', '/root/effects/guide_wisp_b', px - 1, 0.2, pz)
  entity_set_property(wisp_a, 'role', 'pathfinder')
  entity_set_property(wisp_b, 'role', 'pathfinder')
  local rune = instantiate('rune', '/root/effects/spawn_rune', px, 0, pz + 1)
  drawing_set_animation(rune, 'glyph', 'spin', 2.6, 0.1)
  particle_emitter(rune, 'spawn_sparks', 18, 0.75, 1.8, 0.04, '#b35cff', 'fountain')
  entity_set_property(root, 'script_spawn_count', #get_nodes_in_group('script_spawned'))
  if entity_get_property(root, 'scene_name') == 'Dreamseed 7331' then
    local boss_x = px
    local boss_z = pz
    if entity_can_move(player, 'up') then boss_z = pz - 1
    elseif entity_can_move(player, 'right') then boss_x = px + 1
    elseif entity_can_move(player, 'down') then boss_z = pz + 1
    else boss_x = px - 1 end
    boss = instantiate('boss', '/root/bosses/dream_warden', boss_x, 0, boss_z)
    entity_set_property(boss, 'state', 'awakening')
    boss_phase = 'awakening'
    set_timer('boss_attack', 2.4, true)
    hud_label(root, 'boss', 'DREAM WARDEN: AWAKENING', 'top_left', 20, 92, '#b35cff', 13)
  end
  set_timer('scene_heartbeat', 5, true)
  emit_signal(root, 'scene_ready', entity_get_property(root, 'scene_name'))
end

function fixed_update(root, delta)
  if platformer_active then
    local x = entity_get_x(player)
    local y = entity_get_y(player)
    local axis = entity_get_property(root, 'move_axis') or 0
    local next_x = math.max(1.2, math.min(20.2, x + axis * 5.2 * delta))

    if entity_get_property(root, 'jump_requested') then
      entity_set_property(root, 'jump_requested', false)
      if platformer_grounded then
        platformer_velocity_y = 6.8
        platformer_grounded = false
        particle_emitter(player, 'jump_burst', 14, 0.45, 3.2, 0.04, '#31e7ff', 'burst')
      end
    end

    platformer_velocity_y = platformer_velocity_y - 14.5 * delta
    local next_y = y + platformer_velocity_y * delta
    platformer_grounded = false
    if platformer_velocity_y <= 0 then
      for _, platform in ipairs(SceneTree.get_nodes_with_component('platform')) do
        local px = entity_get_x(platform)
        local py = entity_get_y(platform)
        local width = Node.get_value(platform, 'platform', 'width') or 4
        local top = py + 0.35
        if math.abs(next_x - px) <= width / 2 and y - 0.45 >= top - 0.18 and next_y - 0.45 <= top then
          next_y = top + 0.45
          platformer_velocity_y = 0
          platformer_grounded = true
        end
      end
    end

    if next_y < -3 then
      next_x = 2
      next_y = 0.9
      platformer_velocity_y = 0
      hud_label(root, 'platform_message', 'THE VOID RETURNS YOU', 'top_left', 20, 92, '#ff3970', 13)
    end
    entity_set_position(player, next_x, next_y, 2)
    Node.set_value(player, 'platformer_player', 'grounded', platformer_grounded)

    for _, crystal in ipairs(SceneTree.get_nodes_with_component('crystal')) do
      if math.abs(next_x - entity_get_x(crystal)) < 0.55 and math.abs(next_y - entity_get_y(crystal)) < 0.8 then
        Node.remove_component(crystal, 'crystal')
        Node.queue_free(crystal)
        platformer_crystals = platformer_crystals - 1
        game_add_score(Node.get_value(crystal, 'crystal', 'points') or 250)
        particle_emitter(player, 'star_burst', 24, 0.8, 4.5, 0.055, '#ffd45c', 'burst')
        hud_label(root, 'platform_goal', 'STAR CRYSTALS ' .. (4 - platformer_crystals) .. '/4', 'top_right', 20, 20, '#ffd45c', 14)
      end
    end

    local exit = Node.get('/root/platformer_exit')
    if platformer_crystals == 0 and exit ~= 0 and math.abs(next_x - entity_get_x(exit)) < 0.8 and math.abs(next_y - entity_get_y(exit)) < 1.4 then
      game_complete_level('MOONFALL CAUSEWAY RESTORED')
    end
    return
  end

  hud_refresh = hud_refresh - delta
  if hud_refresh <= 0 then
    hud_refresh = 0.1
    local lives = entity_get_property(root, 'lives') or 3
    local score = entity_get_property(root, 'score') or 0
    local spells = entity_get_property(root, 'spell_charges') or 0
    local keys = entity_get_property(root, 'keys') or 0
    local power = entity_get_property(root, 'power_seconds') or 0
    local power_max = entity_get_property(root, 'power_max') or 1
    local status = string.format('LIVES %d   SCORE %05d', lives, score)
    if spells > 0 then status = status .. string.format('   SPELL Qx%d', spells) end
    if keys > 0 then status = status .. string.format('   KEY x%d', keys) end
    hud_label(root, 'status', status, 'top_right', 20, 20, '#ffffff', 14)
    if power > 0 then
      hud_bar(root, 'power', power, power_max, 'top_right', 20, 62, '#b35cff', 220, 8)
    else
      hud_remove(root, 'power')
    end
    if boss ~= 0 then
      local pellets = entity_get_property(root, 'pellets_remaining') or 0
      local total = entity_get_property(root, 'pellets_total') or 1
      local ratio = pellets / math.max(total, 1)
      local next_phase = ratio < 0.3 and 'enraged' or (ratio < 0.7 and 'hunting' or 'awakening')
      if next_phase ~= boss_phase then
        boss_phase = next_phase
        entity_set_property(boss, 'state', boss_phase)
        emit_signal(boss, 'boss_phase_changed', boss_phase)
        if boss_phase == 'enraged' then
          particle_emitter(boss, 'rage_burst', 42, 1.5, 3.8, 0.065, '#ff3970', 'burst')
        end
      end
      hud_label(root, 'boss', 'DREAM WARDEN: ' .. string.upper(boss_phase), 'top_left', 20, 92, '#b35cff', 13)
    end
  end

  if portal_cooldown > 0 then
    portal_cooldown = math.max(0, portal_cooldown - delta)
  end
  if portal_cooldown > 0 or portal_a == 0 or portal_b == 0 then return end

  local px = entity_get_x(player)
  local pz = entity_get_z(player)
  local ax = entity_get_x(portal_a)
  local az = entity_get_z(portal_a)
  local bx = entity_get_x(portal_b)
  local bz = entity_get_z(portal_b)

  if math.abs(px - ax) < 0.25 and math.abs(pz - az) < 0.25 then
    entity_set_position(player, bx, 0.45, bz)
    portal_cooldown = 0.75
    emit_signal(player, 'portal_entered', 2)
  elseif math.abs(px - bx) < 0.25 and math.abs(pz - bz) < 0.25 then
    entity_set_position(player, ax, 0.45, az)
    portal_cooldown = 0.75
    emit_signal(player, 'portal_entered', 1)
  end
end

function timeout(root, timer_name)
  if timer_name == 'scene_heartbeat' then
    emit_signal(root, 'scene_heartbeat', group_count('actors'))
  elseif timer_name == 'boss_attack' and boss ~= 0 and entity_is_alive(boss) then
    projectile_serial = projectile_serial + 1
    local bx = entity_get_x(boss)
    local bz = entity_get_z(boss)
    local dx = entity_get_x(player) - bx
    local dz = entity_get_z(player) - bz
    local length = math.max(0.001, math.sqrt(dx * dx + dz * dz))
    local speed = boss_phase == 'enraged' and 5.2 or 3.5
    local bolt = instantiate('bolt', '/root/projectiles/warden_' .. projectile_serial, bx, 0.25, bz)
    entity_set_velocity(bolt, dx / length * speed, 0, dz / length * speed, 6)
    emit_signal(boss, 'boss_fired', projectile_serial)
  end
end

function signal_received(root, signal_name, source, payload)
  if signal_name == 'player_cast_spell' then
    entity_set_property(root, 'last_spell', payload)
    entity_set_property(root, 'last_spell_caster', source)
  elseif signal_name == 'portal_entered' then
    entity_set_property(root, 'last_portal_actor', source)
  elseif signal_name == 'key_collected' then
    local doors = get_nodes_in_group('doors')
    for _, door in ipairs(doors) do door_set_open(door, true) end
    entity_set_property(root, 'last_key', source)
    emit_signal(root, 'doors_opened', #doors)
  elseif signal_name == 'trap_triggered' then
    entity_set_property(root, 'last_trap', source)
  elseif signal_name == 'player_fired' then
    entity_set_property(root, 'last_player_projectile', payload)
  end
end
