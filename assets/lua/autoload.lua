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
local platformer_crystals = 0
local platformer_total_crystals = 0
local platformer_respawns = 0
local platformer_damage_cooldown = 0
local platformer_checkpoint_x = 2
local platformer_checkpoint_y = 0.9

local platformer_levels = {
  ['Moonfall Causeway'] = {
    route = { count = 14, spacing = 5, heights = {0,1.2,2.4,1.2,0.2,1.4,2.6,1.3} },
    title = 'MOONFALL CAUSEWAY RESTORED',
  },
  ['The Bellwood Canopy'] = {
    route = { count = 20, spacing = 5, heights = {0,1.1,2.3,3.5,2.2,1,2.2,3.4,2.1,0.8} },
    title = 'THE BELLWOOD SINGS AGAIN',
  },
  ['Citadel of Inverted Rain'] = {
    route = { count = 26, spacing = 5, boss = true, heights = {0,1.25,2.5,3.7,2.45,1.2,0,1.2,2.4,3.6,2.3,1.1} },
    title = 'THE STAR EATER IS BANISHED',
  },
}

-- Builds long, always-reachable routes from a compact Lua description. The
-- height patterns never rise more than 1.25 units between adjacent platforms,
-- keeping every generated jump inside the native platformer kernel's envelope.
local function generate_platformer_route(config)
  local route = config.route
  config.platforms = {}
  config.crystals = {}
  config.hazards = {}
  config.checkpoints = {}
  config.enemies = {}
  for index = 1, route.count do
    local x = 4 + (index - 1) * route.spacing
    local y = route.heights[((index - 1) % #route.heights) + 1]
    config.platforms[#config.platforms + 1] = { x, y, index == 1 and 6.5 or 3.4 }
    if index == 1 then
      config.crystals[#config.crystals + 1] = { x + 1.5, y + 1 }
    elseif index >= 4 and index % 2 == 0 then
      config.crystals[#config.crystals + 1] = { x, y + 1 }
    end
    if index > 2 and index % 5 == 0 then
      config.hazards[#config.hazards + 1] = { x + 0.75, y + 0.38 }
    end
    if index > 1 and index % 7 == 0 then
      config.checkpoints[#config.checkpoints + 1] = { x, y + 0.8 }
    elseif index > 2 and index % 3 == 0 and index < route.count then
      config.enemies[#config.enemies + 1] = { x, y + 0.83, 1.15 }
    end
  end
  local final_x = 4 + (route.count - 1) * route.spacing
  local final_y = route.heights[((route.count - 1) % #route.heights) + 1]
  config.exit = { final_x + 1, final_y + 0.65 }
  if route.boss then
    local boss_index = route.count - 1
    local boss_y = route.heights[((boss_index - 1) % #route.heights) + 1]
    config.boss = { final_x - route.spacing, boss_y + 0.83, 1.8 }
  end
end

local function spawn_platform(path, x, y, width)
  local platform = Prefab.instantiate('platform', path, x, y, 2)
  Node.set_value(platform, 'platform', 'width', width)
  draw_box(platform, 'stone', 0, 0, 0, width * 0.675, 0.35, 1.1, '#23315f')
  draw_box(platform, 'rune_rail', 0, 0.32, 0, width * 0.675, 0.06, 1.14, '#31e7ff')
  drawing_set_animation(platform, 'rune_rail', 'pulse', 2.4, 0.08)
  return platform
end

local function setup_platformer(root, config)
  platformer_active = true
  generate_platformer_route(config)
  hud_remove(root, 'status')
  entity_set_position(player, 2, 0.9, 2)
  Node.add_component(player, 'platformer_player', { grounded = false })
  Node.add_component(player, 'character_animation', { state = 'idle', facing = 1 })
  for _, enemy in ipairs(SceneTree.get_nodes_in_group('enemies')) do
    Node.queue_free(enemy)
  end

  for index, platform in ipairs(config.platforms) do
    spawn_platform('/root/platforms/' .. index, platform[1], platform[2], platform[3])
  end
  for index, position in ipairs(config.crystals) do
    Prefab.instantiate('crystal', '/root/crystals/' .. index, position[1], position[2], 2)
  end
  for index, position in ipairs(config.hazards) do
    Prefab.instantiate('moon_spike', '/root/hazards/' .. index, position[1], position[2], 2)
  end
  for index, position in ipairs(config.checkpoints) do
    Prefab.instantiate('moon_checkpoint', '/root/checkpoints/' .. index, position[1], position[2], 2)
  end
  for index, position in ipairs(config.enemies) do
    local enemy = Prefab.instantiate('thorn_runner', '/root/platform_enemies/' .. index, position[1], position[2], 2)
    Node.set_value(enemy, 'platform_enemy', 'origin', position[1])
    Node.set_value(enemy, 'platform_enemy', 'range', position[3])
  end
  if config.boss ~= nil then
    local moon_boss = Prefab.instantiate('star_eater', '/root/platform_boss', config.boss[1], config.boss[2], 2)
    Node.set_value(moon_boss, 'platform_enemy', 'origin', config.boss[1])
    Node.set_value(moon_boss, 'platform_enemy', 'range', config.boss[3])
    hud_label(root, 'platform_boss', 'STAR EATER 6/6', 'top_left', 20, 58, '#ff3970', 14)
  end
  entity_set_property(root, 'platformer_boss_required', config.boss ~= nil)
  platformer_crystals = #config.crystals
  platformer_total_crystals = platformer_crystals
  Prefab.instantiate('exit_gate', '/root/platformer_exit', config.exit[1], config.exit[2], 2)

  entity_set_property(root, 'move_axis', 0)
  entity_set_property(root, 'jump_requested', false)
  entity_set_property(root, 'platformer_finish_title', config.title)
  hud_label(root, 'platform_goal', 'STAR CRYSTALS 0/' .. platformer_total_crystals, 'top_right', 20, 20, '#ffd45c', 14)
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
  local platformer_config = platformer_levels[entity_get_property(root, 'scene_name')]
  if platformer_config ~= nil then
    setup_platformer(root, platformer_config)
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
    platformer_damage_cooldown = math.max(0, platformer_damage_cooldown - delta)
    if Node.get_value(player, 'platformer_player', 'just_jumped') then
      Node.set_value(player, 'platformer_player', 'just_jumped', false)
      particle_emitter(player, 'jump_burst', 14, 0.45, 3.2, 0.04, '#31e7ff', 'burst')
    end
    local respawns = Node.get_value(player, 'platformer_player', 'respawn_count') or 0
    if respawns > platformer_respawns then
      platformer_respawns = respawns
      hud_label(root, 'platform_message', 'THE VOID RETURNS YOU', 'top_left', 20, 92, '#ff3970', 13)
    end

    for _, checkpoint in ipairs(SceneTree.get_nodes_with_component('checkpoint')) do
      if not Node.get_value(checkpoint, 'checkpoint', 'active') and math.abs(x - entity_get_x(checkpoint)) < 0.55 and math.abs(y - entity_get_y(checkpoint)) < 1.25 then
        Node.set_value(checkpoint, 'checkpoint', 'active', true)
        platformer_checkpoint_x = entity_get_x(checkpoint)
        platformer_checkpoint_y = entity_get_y(checkpoint) + 1
        platformer_set_checkpoint(player, platformer_checkpoint_x, platformer_checkpoint_y)
        particle_emitter(checkpoint, 'saved', 28, 0.8, 2.8, 0.045, '#ffd45c', 'burst')
        hud_label(root, 'platform_message', 'MOON LANTERN LIT — JOURNEY SAVED', 'top_left', 20, 92, '#ffd45c', 13)
      end
    end

    for _, hazard in ipairs(SceneTree.get_nodes_with_component('hazard')) do
      if platformer_damage_cooldown <= 0 and math.abs(x - entity_get_x(hazard)) < 0.48 and math.abs(y - entity_get_y(hazard)) < 0.75 then
        game_damage_player(Node.get_value(hazard, 'hazard', 'damage') or 1, 'MOON THORNS — ONE HEART LOST')
        entity_set_position(player, platformer_checkpoint_x, platformer_checkpoint_y, 2)
        platformer_damage_cooldown = 1.2
      end
    end

    for _, enemy in ipairs(SceneTree.get_nodes_with_component('platform_enemy')) do
      local ex = entity_get_x(enemy)
      local origin = Node.get_value(enemy, 'platform_enemy', 'origin') or ex
      local range = Node.get_value(enemy, 'platform_enemy', 'range') or 1.5
      local speed = Node.get_value(enemy, 'platform_enemy', 'speed') or 1.4
      local direction = Node.get_value(enemy, 'platform_enemy', 'direction') or 1
      ex = ex + direction * speed * delta
      if ex > origin + range then
        ex = origin + range
        direction = -1
      end
      if ex < origin - range then
        ex = origin - range
        direction = 1
      end
      entity_set_position(enemy, ex, entity_get_y(enemy), 2)
      Node.set_value(enemy, 'platform_enemy', 'direction', direction)
      if platformer_damage_cooldown <= 0 and math.abs(x - ex) < 0.58 and math.abs(y - entity_get_y(enemy)) < 0.8 then
        game_damage_player(1, 'A THORN RUNNER STEALS A HEART')
        entity_set_position(player, platformer_checkpoint_x, platformer_checkpoint_y, 2)
        platformer_damage_cooldown = 1.2
      end
      for _, bolt in ipairs(SceneTree.get_nodes_in_group('player_projectiles')) do
        if math.abs(entity_get_x(bolt) - ex) < 0.6 and math.abs(entity_get_y(bolt) - entity_get_y(enemy)) < 0.9 then
          Node.queue_free(bolt)
          local health = (Node.get_value(enemy, 'platform_enemy', 'health') or 1) - 1
          Node.set_value(enemy, 'platform_enemy', 'health', health)
          if Node.get_value(enemy, 'platform_enemy', 'boss') then
            hud_label(root, 'platform_boss', 'STAR EATER ' .. math.max(health, 0) .. '/6', 'top_left', 20, 58, '#ff3970', 14)
          end
          if health <= 0 then
            Node.queue_free(enemy)
            game_add_score(Node.get_value(enemy, 'platform_enemy', 'boss') and 3000 or 300)
            if Node.get_value(enemy, 'platform_enemy', 'boss') then
              hud_label(root, 'platform_message', 'THE STAR EATER BREAKS INTO CONSTELLATIONS', 'top_left', 20, 92, '#ffd45c', 13)
              hud_remove(root, 'platform_boss')
            end
          end
          particle_emitter(player, 'enemy_burst', 20, 0.7, 3.2, 0.04, '#b35cff', 'burst')
        end
      end
    end

    for _, crystal in ipairs(SceneTree.get_nodes_with_component('crystal')) do
      if math.abs(x - entity_get_x(crystal)) < 0.55 and math.abs(y - entity_get_y(crystal)) < 0.8 then
        Node.remove_component(crystal, 'crystal')
        Node.queue_free(crystal)
        platformer_crystals = platformer_crystals - 1
        game_add_score(Node.get_value(crystal, 'crystal', 'points') or 250)
        particle_emitter(player, 'star_burst', 24, 0.8, 4.5, 0.055, '#ffd45c', 'burst')
        hud_label(root, 'platform_goal', 'STAR CRYSTALS ' .. (platformer_total_crystals - platformer_crystals) .. '/' .. platformer_total_crystals, 'top_right', 20, 20, '#ffd45c', 14)
      end
    end

    local exit = Node.get('/root/platformer_exit')
    local boss_defeated = not entity_get_property(root, 'platformer_boss_required') or Node.get('/root/platform_boss') == 0
    if platformer_crystals == 0 and boss_defeated and exit ~= 0 and math.abs(x - entity_get_x(exit)) < 0.8 and math.abs(y - entity_get_y(exit)) < 1.4 then
      game_complete_level(entity_get_property(root, 'platformer_finish_title'))
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
