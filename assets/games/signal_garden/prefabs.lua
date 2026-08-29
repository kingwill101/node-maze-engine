local M = {}

function M.register()
  Prefab.define('signal_flower', function(entity)
    draw_sphere(entity, 'heart', 0, 0.28, 0, 0.16, '#8dffef')
    draw_box(entity, 'stem', 0, 0.05, 0, 0.035, 0.22, 0.035, '#31e7ff')
    drawing_set_animation(entity, 'heart', 'pulse', 3.2, 0.16)
    particle_emitter(entity, 'pollen', 5, 0.24, 0.7, 0.025, '#ffd45c', 'orbit')
  end)
end

return M
