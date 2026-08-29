import 'package:lualike/lualike.dart';

import '../game/level.dart';
import '../game/maze.dart';

class LuaLevelLoader {
  const LuaLevelLoader();

  Future<LevelDefinition> load(String source, {String? scriptPath}) async {
    final campaign = await loadCampaign(source, scriptPath: scriptPath);
    return campaign.levels.first;
  }

  Future<LevelCampaign> loadCampaign(
    String source, {
    String? scriptPath,
  }) async {
    final result = await LuaLike().execute(source, scriptPath: scriptPath);
    final root = _unwrap(result);
    if (root is! Map) {
      throw const FormatException('Level script must return a table');
    }
    final map = _stringMap(root);
    final rawLevels = map['levels'];
    final levelMaps = rawLevels == null
        ? [map]
        : _tableList(rawLevels).map(_stringMap).toList();
    if (levelMaps.isEmpty) {
      throw const FormatException('Campaign must contain at least one level');
    }
    return LevelCampaign(
      name: _string(map['name'], fallback: 'Neon campaign'),
      levels: [for (final levelMap in levelMaps) _parseLevel(levelMap)],
    );
  }

  Future<GameCatalog> loadCatalog(String source, {String? scriptPath}) async {
    final result = await LuaLike().execute(source, scriptPath: scriptPath);
    final root = _unwrap(result);
    if (root is! Map) {
      throw const FormatException('Game catalog script must return a table');
    }
    final map = _stringMap(root);
    final levelMaps = _tableList(map['levels']).map(_stringMap).toList();
    final levels = [for (final levelMap in levelMaps) _parseLevel(levelMap)];
    final definitions = _optionalTableList(map['games']).map(_stringMap);
    final games = <GameDefinition>[];
    for (final definition in definitions) {
      final id = _string(definition['id'], fallback: 'unknown_game');
      final gameLevels = levels.where((level) => level.gameId == id).toList();
      if (gameLevels.isEmpty) continue;
      games.add(
        GameDefinition(
          id: id,
          name: _string(definition['name'], fallback: id),
          tagline: _string(definition['tagline'], fallback: ''),
          campaign: LevelCampaign(
            name: _string(definition['campaign'], fallback: id),
            levels: gameLevels,
          ),
          autoloadPath: _string(
            definition['autoload'],
            fallback: 'assets/lua/autoload.lua',
          ),
          behaviorPath: definition['behavior'] == false
              ? null
              : _string(
                  definition['behavior'],
                  fallback: 'assets/lua/ghost.lua',
                ),
          prefabPath: _string(
            definition['prefabs'],
            fallback: 'assets/lua/prefabs.lua',
          ),
        ),
      );
    }
    if (games.isEmpty) {
      throw const FormatException('Game catalog must contain playable games');
    }
    return GameCatalog(
      name: _string(map['catalog_name'], fallback: 'Node Game Center'),
      games: games,
    );
  }

  Future<GamePackageIndex> loadPackageIndex(
    String source, {
    String? scriptPath,
  }) async {
    final result = await LuaLike().execute(source, scriptPath: scriptPath);
    final root = _unwrap(result);
    if (root is! Map) {
      throw const FormatException('Game package index must return a table');
    }
    final map = _stringMap(root);
    final manifests = _stringList(map['manifests']);
    if (manifests.isEmpty) {
      throw const FormatException('Game package index must list manifests');
    }
    return GamePackageIndex(
      name: _string(map['name'], fallback: 'Node Game Center'),
      manifests: manifests,
    );
  }

  LevelDefinition _parseLevel(Map<String, Object?> map) {
    final rows = _stringList(map['maze']);
    _validateRows(rows);
    final tuning = _stringMap(map['tuning'] ?? const {});
    return LevelDefinition(
      gameId: _string(map['game'], fallback: 'node_maze'),
      name: _string(map['name'], fallback: 'Untitled maze'),
      maze: Maze(rows),
      story: _string(map['story'], fallback: ''),
      objective: _string(map['objective'], fallback: 'Clear every soul spark'),
      cameraMode: _cameraMode(map['camera']),
      renderDistance: _double(map['render_distance'], fallback: 12),
      autoRun: map['auto_run'] == true,
      events: [
        for (final event in _optionalTableList(map['events']))
          _parseEvent(_stringMap(event)),
      ],
      tuning: LevelTuning(
        playerSpeed: _double(tuning['player_speed'], fallback: 4),
        ghostSpeed: _double(tuning['ghost_speed'], fallback: 2.5),
        powerSeconds: _double(tuning['power_seconds'], fallback: 7),
        bonusSeconds: _double(tuning['bonus_seconds'], fallback: 10),
        bonusPoints: _int(tuning['bonus_points'], fallback: 1000),
      ),
    );
  }

  LevelEventDefinition _parseEvent(Map<String, Object?> map) =>
      LevelEventDefinition(
        message: _string(map['message'], fallback: 'The world shifts...'),
        afterSeconds: _nullableDouble(map['after_seconds']),
        pelletsRemainingRatio: _nullableDouble(map['pellets_ratio']),
        scoreBonus: _int(map['score_bonus'], fallback: 0),
      );

  CameraMode _cameraMode(Object? value) => switch (value) {
    'first_person' => CameraMode.firstPerson,
    'platformer' => CameraMode.platformer,
    _ => CameraMode.follow,
  };

  List<Object?> _optionalTableList(Object? value) =>
      value == null ? const [] : _tableList(value);

  List<Object?> _tableList(Object? value) {
    final raw = _unwrap(value);
    if (raw is List) return raw;
    if (raw is Map) {
      final entries = raw.entries.toList()
        ..sort((a, b) => (a.key as num).compareTo(b.key as num));
      return entries.map((entry) => entry.value).toList();
    }
    throw const FormatException('Campaign levels must be an array');
  }

  Object? _unwrap(Object? value) {
    final raw = value is Value ? value.unwrap() : value;
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          _unwrap(entry.key): _unwrap(entry.value),
      };
    }
    if (raw is List) return raw.map(_unwrap).toList();
    return raw;
  }

  Map<String, Object?> _stringMap(Object? value) {
    final raw = _unwrap(value);
    if (raw is! Map) return {};
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }

  List<String> _stringList(Object? value) {
    final raw = _unwrap(value);
    if (raw is List) return raw.map((item) => item.toString()).toList();
    if (raw is Map) {
      final entries = raw.entries.toList()
        ..sort((a, b) => (a.key as num).compareTo(b.key as num));
      return entries.map((entry) => entry.value.toString()).toList();
    }
    throw const FormatException('Level maze must be an array of row strings');
  }

  void _validateRows(List<String> rows) {
    if (rows.isEmpty || rows.any((row) => row.length != rows.first.length)) {
      throw const FormatException(
        'Maze rows must be non-empty and equally wide',
      );
    }
    final source = rows.join();
    if ('P'.allMatches(source).length != 1) {
      throw const FormatException(
        'Maze must contain exactly one P player spawn',
      );
    }
    if (!RegExp('[A-D]').hasMatch(source)) {
      throw const FormatException(
        'Maze must contain at least one A-D ghost spawn',
      );
    }
    if (source.replaceAll(RegExp(r'[#.oPsTK|^ A-D]'), '').isNotEmpty) {
      throw const FormatException('Maze contains unsupported tile characters');
    }
    final portals = 'T'.allMatches(source).length;
    if (portals != 0 && portals != 2) {
      throw const FormatException('Maze must contain zero or two T portals');
    }
    _validateConnectivity(rows);
  }

  void _validateConnectivity(List<String> rows) {
    final width = rows.first.length;
    final height = rows.length;
    late (int, int) spawn;
    var traversable = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (rows[y][x] != '#') traversable++;
        if (rows[y][x] == 'P') spawn = (x, y);
      }
    }
    const directions = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    bool isOpen((int, int) cell) =>
        cell.$1 >= 0 &&
        cell.$2 >= 0 &&
        cell.$1 < width &&
        cell.$2 < height &&
        rows[cell.$2][cell.$1] != '#';
    final exits = directions
        .map((delta) => (spawn.$1 + delta.$1, spawn.$2 + delta.$2))
        .where(isOpen)
        .toList();
    if (exits.isEmpty) {
      throw const FormatException('Player spawn must have an open exit');
    }
    final visited = <(int, int)>{spawn};
    final pending = <(int, int)>[spawn];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final delta in directions) {
        final next = (current.$1 + delta.$1, current.$2 + delta.$2);
        if (isOpen(next) && visited.add(next)) pending.add(next);
      }
    }
    if (visited.length != traversable) {
      throw const FormatException(
        'Every spawn and collectible must be reachable from P',
      );
    }
  }

  String _string(Object? value, {required String fallback}) =>
      value?.toString() ?? fallback;
  double _double(Object? value, {required double fallback}) =>
      value is num ? value.toDouble() : fallback;
  double? _nullableDouble(Object? value) =>
      value is num ? value.toDouble() : null;
  int _int(Object? value, {required int fallback}) =>
      value is num ? value.toInt() : fallback;
}
