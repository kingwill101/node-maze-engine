class Maze {
  Maze(this.rows)
    : assert(rows.isNotEmpty),
      assert(rows.every((row) => row.length == rows.first.length));

  final List<String> rows;
  int get width => rows.first.length;
  int get height => rows.length;

  bool isWall(int x, int y) =>
      x < 0 || y < 0 || x >= width || y >= height || rows[y][x] == '#';

  static final demo = Maze(const [
    '#############',
    '#o.........o#',
    '#.###.#.###.#',
    '#ABCD.#.....#',
    '###.#...#.###',
    '#...#.P.#...#',
    '#.###.#.###.#',
    '#o.........o#',
    '#############',
  ]);
}
