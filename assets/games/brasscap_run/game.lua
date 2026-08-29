local function stage(width)
  local border, empty, actors = {}, {}, {}
  for x = 1, width do border[x], empty[x], actors[x] = '#', ' ', ' ' end
  empty[1], empty[width] = '#', '#'
  actors[1], actors[width], actors[3], actors[width - 2] = '#', '#', 'P', 'A'
  return {
    table.concat(border), table.concat(empty), table.concat(actors),
    table.concat(empty), table.concat(border),
  }
end

return {
  games = {{
    id = 'brasscap_run',
    name = 'Brasscap Run',
    tagline = 'A bright clockwork 2.5D platform adventure',
    campaign = 'The Great Gearway',
    autoload = 'assets/games/brasscap_run/autoload.lua',
    behavior = false,
    prefabs = 'assets/games/brasscap_run/prefabs.lua',
    player_renderer = 'script',
    platform_environment = 'bright',
    controls = 'A / D MOVE   •   SPACE JUMP   •   STOMP BEETLES   •   P PAUSE',
    icon = 'sun', accent_color = '#ffd23f', background_color = '#237a58',
  }},
  levels = {
    { game = 'brasscap_run', name = 'Clover Gearway', camera = 'platformer', render_distance = 26,
      story = 'Tavi races through the clover works after the royal sunrise gear rolls away.',
      objective = 'Collect the brass gears and ring the finish bell', maze = stage(86),
      tuning = { player_speed = 4.8, ghost_speed = 0.1, bonus_seconds = 999 } },
    { game = 'brasscap_run', name = 'Treetop Foundry', camera = 'platformer', render_distance = 30,
      story = 'The road climbs into a canopy of windmills, springs, and walking beetle engines.',
      objective = 'Ride the moving lifts through the foundry canopy', maze = stage(116),
      tuning = { player_speed = 5.0, ghost_speed = 0.1, bonus_seconds = 999 } },
    { game = 'brasscap_run', name = 'Sunbell Keep', camera = 'platformer', render_distance = 34,
      story = 'Above the clouds, Baron Boiler has chained the morning bell to his tallest keep.',
      objective = 'Cross the sky keep and ring the Sunbell', maze = stage(146),
      tuning = { player_speed = 5.2, ghost_speed = 0.1, bonus_seconds = 999 } },
  },
}
