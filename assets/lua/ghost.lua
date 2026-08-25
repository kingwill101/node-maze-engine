-- Each ghost owns an isolated Lua VM. The ECS profile selects a personality,
-- while Dart exposes sensing and safe maze-navigation primitives.
local personality = 'chaser'
local patrol_corner = 1
local current_state = 'spawning'

function ready(entity)
  personality = entity_get_property(entity, 'personality')
  entity_add_to_group(entity, 'scripted_actors')
  entity_set_property(entity, 'state', 'hunting')
  current_state = 'hunting'
  entity_add_component(entity, 'drawings')
  draw_sphere(entity, 'familiar_a', 0.42, 0.25, 0, 0.07, '#31e7ff')
  drawing_set_animation(entity, 'familiar_a', 'orbit', 2.2, 0.24)
  draw_sphere(entity, 'familiar_b', -0.42, 0.12, 0, 0.05, '#b35cff')
  drawing_set_animation(entity, 'familiar_b', 'orbit', -1.7, 0.18)
  particle_emitter(entity, 'ectoplasm', 8, 0.42, 1.1, 0.035, '#31e7ff', 'orbit')
  set_timer('presence_pulse', 3 + (entity % 4) * 0.4, true)
  print('ghost ready', entity, personality)
end

function timeout(entity, timer_name)
  if timer_name == 'presence_pulse' then
    emit_signal(entity, 'enemy_presence', personality)
  elseif timer_name == 'spell_recover' then
    drawing_remove(entity, 'spell_shock')
    particle_remove(entity, 'spell_shards')
  end
end

function signal_received(entity, signal_name, source, payload)
  if signal_name == 'enemy_presence' and source ~= entity then
    entity_set_property(entity, 'last_ally_signal', source)
  elseif signal_name == 'player_cast_spell' then
    entity_set_property(entity, 'last_spell', payload)
    draw_box(entity, 'spell_shock', 0, 0.55, 0, 0.08, 0.3, 0.08, '#ffffff')
    drawing_set_animation(entity, 'spell_shock', 'spin', 12, 0)
    set_timer('spell_recover', 1.2, false)
    particle_emitter(entity, 'spell_shards', 16, 0.8, 4.5, 0.04, '#ffffff', 'burst')
  end
end

function fixed_update(entity, delta)
  local x = entity_get_x(entity)
  local z = entity_get_z(entity)
  local player_x = player_get_x()
  local player_z = player_get_z()
  local target_x = player_x
  local target_z = player_z
  local mode = 'chase'
  local aggression = entity_get_property(entity, 'aggression')

  if personality == 'ambusher' then
    local lead = 2 + aggression * 2
    target_x = player_x + player_get_dx() * lead
    target_z = player_z + player_get_dz() * lead
  elseif personality == 'shy' then
    local distance = math.abs(x - player_x) + math.abs(z - player_z)
    if distance < 5 then
      mode = 'flee'
    end
  elseif personality == 'patrol' then
    if patrol_corner == 1 then
      target_x = 1
      target_z = 1
    else
      target_x = 11
      target_z = 7
    end
    if math.abs(x - target_x) + math.abs(z - target_z) < 1.2 then
      patrol_corner = 3 - patrol_corner
    end
  end

  if power_active() then
    target_x = player_x
    target_z = player_z
    mode = 'flee'
    if current_state ~= 'frightened' then
      current_state = 'frightened'
      entity_set_property(entity, 'state', current_state)
      draw_sphere(entity, 'fear_flare', 0.5, 0.1, 0, 0.11, '#5522ff')
      drawing_set_animation(entity, 'fear_flare', 'orbit', 9, 0.32)
      emit_signal(entity, 'ghost_frightened', personality)
    end
  elseif current_state ~= 'hunting' then
    current_state = 'hunting'
    entity_set_property(entity, 'state', current_state)
    drawing_remove(entity, 'fear_flare')
  end

  entity_request_target(entity, target_x, target_z, mode)
end
