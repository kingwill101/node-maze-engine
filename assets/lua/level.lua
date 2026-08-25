-- Deterministic recursive-backtracker maze generator. Odd dimensions produce
-- a solid outer boundary and one connected network of corridors.
function generate_maze(width, height, seed)
  math.randomseed(seed)
  local grid = {}
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do grid[y][x] = '#' end
  end

  local carved = { { 2, 2 } }
  local stack = { { 2, 2 } }
  grid[2][2] = '.'
  local directions = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }

  while #stack > 0 do
    local current = stack[#stack]
    local choices = {}
    for _, direction in ipairs(directions) do
      local nx = current[1] + direction[1]
      local ny = current[2] + direction[2]
      if nx > 1 and nx < width and ny > 1 and ny < height and grid[ny][nx] == '#' then
        choices[#choices + 1] = { nx, ny, direction[1], direction[2] }
      end
    end
    if #choices == 0 then
      table.remove(stack)
    else
      local chosen = choices[math.random(#choices)]
      grid[current[2] + chosen[4] / 2][current[1] + chosen[3] / 2] = '.'
      grid[chosen[2]][chosen[1]] = '.'
      stack[#stack + 1] = { chosen[1], chosen[2] }
      carved[#carved + 1] = { chosen[1], chosen[2] }
    end
  end

  grid[2][2] = 'P'
  local marks = { 'A', 'B', 'C', 'D' }
  for i = 1, 4 do
    local cell = carved[#carved - i * 3]
    grid[cell[2]][cell[1]] = marks[i]
  end
  grid[height - 1][width - 1] = 'o'
  grid[2][width - 1] = 'o'

  local rows = {}
  for y = 1, height do rows[y] = table.concat(grid[y]) end
  return rows
end

return {
  name = 'Neon Rift Tour',
  levels = {
    {
      name = 'Neon Junction',
      story = 'The Lantern Guild sends Pip into a machine-temple where stolen stars have been caged.',
      objective = 'Free every soul spark and awaken the north gate',
      camera = 'follow',
      render_distance = 11,
      events = {
        { after_seconds = 4, message = 'A whisper travels through the neon stone: FIND THE STAR KEY.' },
        { pellets_ratio = 0.5, message = 'The temple wakes. Its walls begin to sing.', score_bonus = 250 },
      },
      maze = {
        '#############',
        '#o...s.....o#',
        '#.###T#T###.#',
        '#ABCD.#.....#',
        '###.#...#.###',
        '#...#.P^#...#',
        '#.###.#.###.#',
        '#o..K..|...o#',
        '#############',
      },
      tuning = { player_speed = 4.0, ghost_speed = 2.5, power_seconds = 7.0,
                 bonus_seconds = 10.0, bonus_points = 1000 },
    },
    {
      name = 'Circuit Gardens',
      story = 'Beyond the gate grows a forest of copper vines, patrolled by four hungry wardens.',
      objective = 'Cross the gardens and restore the moonwell',
      camera = 'follow',
      render_distance = 13,
      events = {
        { after_seconds = 5, message = 'MOONWELL: Wanderer, bring me the light they scattered.' },
        { pellets_ratio = 0.35, message = 'A silver path opens somewhere ahead.', score_bonus = 500 },
      },
      maze = {
        '#########################',
        '#o.......#.......#.....o#',
        '#.#####..#.#####.#.###..#',
        '#.....#..#...#...#...#..#',
        '###.#.#.#####.#.###.#.###',
        '#...#.#.......#.....#...#',
        '#.###.###.###.#####.###.#',
        '#A.B.C.D#...#.....#.....#',
        '#.#######.#.#####.#####.#',
        '#.........#...P.........#',
        '#.#######.#######.#####.#',
        '#o.....................o#',
        '#########################',
      },
      tuning = { player_speed = 4.25, ghost_speed = 2.75, power_seconds = 6.5,
                 bonus_seconds = 9.0, bonus_points = 1500 },
    },
    {
      name = 'The Long Grid',
      story = 'Reality folds into a luminous causeway. Run—the Star Eater is directly behind you.',
      objective = 'Survive the rift road and reach the final beacon',
      camera = 'first_person',
      auto_run = true,
      render_distance = 16,
      events = {
        { after_seconds = 3, message = 'RIFT RUN: Do not look behind you.' },
        { after_seconds = 18, message = 'The road is collapsing. Follow the cyan fire!' },
        { pellets_ratio = 0.25, message = 'The final beacon answers your call.', score_bonus = 1000 },
      },
      maze = {
        '###################################',
        '#o.......#.......#.......#.....o..#',
        '#.#####..#.#####.#.#####.#.###....#',
        '#.....#..#.....#.#.....#.#...#....#',
        '###.#.########.#.#####.#.###.#.####',
        '#...#..........#.......#.....#....#',
        '#.#####.######.###.#########.##...#',
        '#A.B.C.D#....#.....#..............#',
        '#.#######.##.#######.###########..#',
        '#...........#....P................#',
        '#.#########.#######.#########.###.#',
        '#...........#.......#.........#...#',
        '###.#######.#.#####.#.#######.#.###',
        '#o..........#.......#..........o..#',
        '###################################',
      },
      tuning = { player_speed = 4.5, ghost_speed = 3.0, power_seconds = 6.0,
                 bonus_seconds = 8.0, bonus_points = 2500 },
    },
    {
      name = 'Dreamseed 7331',
      story = 'The maze dreams a new body from a number whispered by the Moonwell.',
      objective = 'Map the algorithmic dream and recover its two star hearts',
      camera = 'first_person',
      render_distance = 14,
      events = {
        { after_seconds = 4, message = 'SEED 7331: Every corridor is connected. None are familiar.' },
        { pellets_ratio = 0.5, message = 'The dream notices that you are inside it.', score_bonus = 733 },
      },
      maze = generate_maze(31, 21, 7331),
      tuning = { player_speed = 4.3, ghost_speed = 2.9, power_seconds = 8.0,
                 bonus_seconds = 12.0, bonus_points = 3333 },
    },
  },
}
