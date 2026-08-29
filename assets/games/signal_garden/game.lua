return {
  games = {
    {
      id = 'signal_garden',
      name = 'Signal Garden',
      tagline = 'A Lua-authored constellation chase',
      campaign = 'The Singing Circuit',
      autoload = 'assets/games/signal_garden/autoload.lua',
      behavior = 'assets/games/signal_garden/sentinel.lua',
      prefabs = 'assets/games/signal_garden/prefabs.lua',
    },
  },
  levels = {
    {
      game = 'signal_garden',
      name = 'First Transmission',
      story = 'A silent garden broadcasts a melody through abandoned machines. Gather its notes before the custodians erase the signal.',
      objective = 'Collect every signal note and survive the custodians',
      camera = 'follow',
      render_distance = 14,
      events = {
        { after_seconds = 3, message = 'THE GARDEN IS AN INDEPENDENT LUA GAME PACKAGE.' },
        { pellets_ratio = 0.5, message = 'THE SIGNAL FINDS A HARMONY.', score_bonus = 400 },
      },
      maze = {
        '#################',
        '#o....#...#....o#',
        '#.##..#...#..##.#',
        '#...A...P...B...#',
        '#.##..#...#..##.#',
        '#.....#...#.....#',
        '#.###...s...###.#',
        '#.....#...#.....#',
        '#...C...K...D...#',
        '#o....#...#....o#',
        '#################',
      },
      tuning = { player_speed = 4.6, ghost_speed = 2.2, power_seconds = 8.0,
                 bonus_seconds = 11.0, bonus_points = 1800 },
    },
  },
}
