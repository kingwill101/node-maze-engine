local M = {}

function M.register()
  Prefab.define('wisp', function(entity)
    draw_sphere(entity, 'core', 0, 0.28, 0, 0.16, '#31e7ff')
    drawing_set_animation(entity, 'core', 'float', 2.4, 0.18)
    Node.add_component(entity, 'guide', { role = 'pathfinder' })
  end)

  Prefab.define('rune', function(entity)
    draw_box(entity, 'glyph', 0, 0.32, 0, 0.08, 0.32, 0.08, '#b35cff')
    drawing_set_animation(entity, 'glyph', 'spin', 1.8, 0)
  end)

  Prefab.define('orb', function(entity)
    draw_sphere(entity, 'orb', 0, 0.3, 0, 0.24, '#ffd45c')
    drawing_set_animation(entity, 'orb', 'pulse', 3, 0.22)
  end)

  Prefab.define('bolt', function(entity)
    Node.add_component(entity, 'projectile', {
      damage = 1,
      hurts_player = true,
    })
    particle_emitter(entity, 'trail', 10, 0.65, 3.5, 0.045, '#ff3970', 'trail')
    draw_sphere(entity, 'bolt', 0, 0.25, 0, 0.13, '#ff3970')
    drawing_set_animation(entity, 'bolt', 'pulse', 10, 0.3)
  end)

  Prefab.define('boss', function(entity)
    Node.add_component(entity, 'boss', {
      health = 12,
      phase = 'awakening',
    })
    particle_emitter(entity, 'void_crown', 24, 1.1, 1.4, 0.055, '#b35cff', 'orbit')
    draw_sphere(entity, 'body', 0, 0.55, 0, 0.72, '#b35cff')
    drawing_set_animation(entity, 'body', 'float', 1.6, 0.16)
    draw_box(entity, 'crown', 0, 1.35, 0, 0.48, 0.08, 0.48, '#ffd45c')
    drawing_set_animation(entity, 'crown', 'spin', 1.2, 0)
  end)

  Prefab.define('empty', function(entity) end)
end

return M
