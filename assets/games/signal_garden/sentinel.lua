local personality = 'custodian'

function ready(entity)
  personality = entity_get_property(entity, 'personality') or 'custodian'
  entity_add_to_group(entity, 'signal_custodians')
  entity_set_property(entity, 'state', 'listening')
  draw_sphere(entity, 'antenna', 0, 0.62, 0, 0.09, '#8dffef')
  drawing_set_animation(entity, 'antenna', 'pulse', 4, 0.14)
  set_timer('ping', 2.5 + (entity % 3) * 0.35, true)
end

function timeout(entity, timer_name)
  if timer_name == 'ping' then emit_signal(entity, 'custodian_ping', personality) end
end

function fixed_update(entity, delta)
  local x = entity_get_x(entity)
  local z = entity_get_z(entity)
  local dx = player_get_x() - x
  local dz = player_get_z() - z
  local direction = 'none'
  if math.abs(dx) > math.abs(dz) then
    direction = dx > 0 and 'right' or 'left'
  else
    direction = dz > 0 and 'down' or 'up'
  end
  entity_request_move(entity, direction)
end
