local player = 0

function ready(root)
  player = Node.get('/root/player')
  entity_set_property(root, 'package_id', 'signal_garden')
  hud_label(root, 'package', 'SIGNAL GARDEN · LUA PACKAGE', 'top_left', 20, 58, '#8dffef', 14)
  local flower = Prefab.instantiate('signal_flower', '/root/signal_flower', player_get_x() + 2, 0, player_get_z())
  Node.add_to_group(flower, 'garden_fx')
  set_timer('garden_pulse', 4, true)
end

function timeout(root, timer_name)
  if timer_name == 'garden_pulse' then
    emit_signal(root, 'garden_pulse', entity_get_property(root, 'score') or 0)
  end
end

function signal_received(root, signal_name, source, payload)
  if signal_name == 'custodian_ping' then
    entity_set_property(root, 'last_custodian', source)
  end
end

function fixed_update(root, delta)
  hud_label(root, 'score', 'HARMONY ' .. (entity_get_property(root, 'score') or 0), 'top_right', 20, 58, '#ffd45c', 14)
end
