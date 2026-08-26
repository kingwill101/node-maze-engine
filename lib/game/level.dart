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

class LevelCampaign {
  const LevelCampaign({required this.name, required this.levels});

  final String name;
  final List<LevelDefinition> levels;
}
