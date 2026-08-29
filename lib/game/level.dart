import 'maze.dart';

class LevelTuning {
  const LevelTuning({
    this.playerSpeed = 4,
    this.ghostSpeed = 2.5,
    this.powerSeconds = 7,
    this.bonusSeconds = 10,
    this.bonusPoints = 1000,
  });

  final double playerSpeed;
  final double ghostSpeed;
  final double powerSeconds;
  final double bonusSeconds;
  final int bonusPoints;
}

enum CameraMode { follow, firstPerson, platformer }

class LevelEventDefinition {
  const LevelEventDefinition({
    required this.message,
    this.afterSeconds,
    this.pelletsRemainingRatio,
    this.scoreBonus = 0,
  });

  final String message;
  final double? afterSeconds;
  final double? pelletsRemainingRatio;
  final int scoreBonus;
}

class LevelDefinition {
  const LevelDefinition({
    this.gameId = 'node_maze',
    required this.name,
    required this.maze,
    this.tuning = const LevelTuning(),
    this.story = '',
    this.objective = 'Clear every soul spark',
    this.cameraMode = CameraMode.follow,
    this.renderDistance = 12,
    this.autoRun = false,
    this.events = const [],
  });

  final String gameId;
  final String name;
  final Maze maze;
  final LevelTuning tuning;
  final String story;
  final String objective;
  final CameraMode cameraMode;
  final double renderDistance;
  final bool autoRun;
  final List<LevelEventDefinition> events;

  factory LevelDefinition.defaultFor(Maze maze) =>
      LevelDefinition(name: 'Neon Junction', maze: maze);
}

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    required this.campaign,
    this.autoloadPath = 'assets/lua/autoload.lua',
    this.behaviorPath = 'assets/lua/ghost.lua',
    this.prefabPath = 'assets/lua/prefabs.lua',
    this.playerRenderer = 'native',
    this.platformEnvironment = 'moonfall',
    this.controls = '',
    this.icon = 'orb',
    this.accentColor = '#31e7ff',
    this.backgroundColor = '#10224a',
  });

  final String id;
  final String name;
  final String tagline;
  final LevelCampaign campaign;
  final String autoloadPath;
  final String? behaviorPath;
  final String prefabPath;
  final String playerRenderer;
  final String platformEnvironment;
  final String controls;
  final String icon;
  final String accentColor;
  final String backgroundColor;
}

class GamePackageIndex {
  const GamePackageIndex({required this.name, required this.manifests});

  final String name;
  final List<String> manifests;
}

class GameCatalog {
  const GameCatalog({required this.name, required this.games});

  final String name;
  final List<GameDefinition> games;
}

class LevelCampaign {
  const LevelCampaign({required this.name, required this.levels});

  final String name;
  final List<LevelDefinition> levels;
}
