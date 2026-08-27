class Transform3 {
  Transform3(this.x, this.y, this.z);
  double x;
  double y;
  double z;
}

class SpawnPoint {
  const SpawnPoint(this.x, this.z);
  final double x;
  final double z;
}

enum MoveDirection {
  none(0, 0),
  left(-1, 0),
  right(1, 0),
  up(0, -1),
  down(0, 1);

  const MoveDirection(this.dx, this.dy);
  final int dx;
  final int dy;
}

class GridMover {
  GridMover({this.speed = 4});
  final double speed;
  MoveDirection direction = MoveDirection.none;
  MoveDirection requested = MoveDirection.none;
}

class WallTag {
  const WallTag();
}

class WallRun {
  const WallRun(this.length);
  final int length;
}

class PelletTag {
  const PelletTag({this.power = false});
  final bool power;
}

class BonusFruitTag {
  const BonusFruitTag({this.points = 1000});
  final int points;
}

class PortalTag {
  const PortalTag(this.destinationX, this.destinationZ);
  final double destinationX;
  final double destinationZ;
}

class SpellPickupTag {
  const SpellPickupTag();
}

class KeyPickupTag {
  const KeyPickupTag();
}

class DoorTag {
  DoorTag({this.open = false});
  bool open;
}

class TrapTag {
  TrapTag({this.active = true});
  bool active;
  double cooldown = 0;
}

class ScriptVelocity {
  ScriptVelocity(this.x, this.y, this.z, {this.remainingSeconds = 5});
  double x;
  double y;
  double z;
  double remainingSeconds;
}

class ScriptProjectileTag {
  const ScriptProjectileTag({this.damage = 1, this.hurtsPlayer = true});
  final int damage;
  final bool hurtsPlayer;
}

class BossTag {
  const BossTag();
}

class PlayerTag {
  const PlayerTag();
}

class GhostTag {
  const GhostTag();
}

class GhostProfile {
  const GhostProfile({required this.name, required this.personality});
  final String name;
  final String personality;
}

class ScriptProperties {
  ScriptProperties([Map<String, Object?> values = const {}])
    : values = Map.of(values);

  final Map<String, Object?> values;
}

/// Game-defined components authored entirely by Lua.
///
/// Native Dart components remain available for engine-level hot paths, while
/// arbitrary gameplay concepts live here without requiring a Dart type.
class ScriptComponents {
  ScriptComponents([Map<String, Map<String, Object?>> values = const {}])
    : values = {
        for (final entry in values.entries) entry.key: Map.of(entry.value),
      };

  final Map<String, Map<String, Object?>> values;
}

class ScriptGroups {
  ScriptGroups([Iterable<String> values = const []]) : values = Set.of(values);

  final Set<String> values;
}

enum ScriptPrimitiveShape { sphere, box }

class ScriptDrawing {
  ScriptDrawing({
    required this.name,
    required this.shape,
    required this.x,
    required this.y,
    required this.z,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.color,
  });

  final String name;
  final ScriptPrimitiveShape shape;
  double x;
  double y;
  double z;
  double scaleX;
  double scaleY;
  double scaleZ;
  String color;
  String animation = 'none';
  double animationSpeed = 1;
  double animationAmount = .15;
}

class ScriptDrawings {
  final Map<String, ScriptDrawing> values = {};
}

class ScriptParticleEmitter {
  ScriptParticleEmitter({
    required this.name,
    required this.count,
    required this.radius,
    required this.speed,
    required this.size,
    required this.color,
    required this.pattern,
    this.remainingSeconds,
  });

  final String name;
  int count;
  double radius;
  double speed;
  double size;
  String color;
  String pattern;
  double? remainingSeconds;
}

class ScriptParticleEmitters {
  final Map<String, ScriptParticleEmitter> values = {};
}

enum ScriptHudElementType { label, bar }

class ScriptHudElement {
  ScriptHudElement({
    required this.name,
    required this.type,
    required this.anchor,
    required this.x,
    required this.y,
    required this.color,
    this.text = '',
    this.fontSize = 14,
    this.value = 0,
    this.maximum = 1,
    this.width = 180,
    this.height = 10,
  });

  final String name;
  final ScriptHudElementType type;
  String anchor;
  double x;
  double y;
  String color;
  String text;
  double fontSize;
  double value;
  double maximum;
  double width;
  double height;
}

class ScriptHud {
  final Map<String, ScriptHudElement> elements = {};
}

class LuaSignal {
  const LuaSignal({required this.name, required this.source, this.payload});

  final String name;
  final int source;
  final Object? payload;
}

class ScoreChanged {
  const ScoreChanged(this.score);
  final int score;
}

class LivesChanged {
  const LivesChanged(this.lives);
  final int lives;
}

enum GamePhase { playing, won, gameOver }

class GameState {
  int score = 0;
  int lives = 3;
  int pelletsRemaining = 0;
  int pelletsTotal = 0;
  double powerSeconds = 0;
  int ghostCombo = 0;
  bool bonusSpawned = false;
  double bonusSeconds = 0;
  GamePhase phase = GamePhase.playing;
  double elapsedSeconds = 0;
  String announcement = '';
  double announcementSeconds = 0;
  final Set<int> firedLevelEvents = {};
  int spellCharges = 0;
  double spellPulseSeconds = 0;
  int keys = 0;
}

class SpellCast {
  const SpellCast();
}

class PowerModeChanged {
  const PowerModeChanged(this.seconds);
  final double seconds;
}

class LevelCompleted {
  const LevelCompleted();
}

class BonusSpawned {
  const BonusSpawned();
}

class BonusCollected {
  const BonusCollected(this.points);
  final int points;
}
