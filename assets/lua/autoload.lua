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
