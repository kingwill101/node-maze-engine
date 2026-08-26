import '../engine/runtime.dart';
import '../game/components.dart';
import 'platformer_components.dart';

class PlatformerPhysicsSystem implements EngineSystem {
  const PlatformerPhysicsSystem({
    required this.minimumX,
    required this.maximumX,
  });

  final double minimumX;
  final double maximumX;

  @override
  void update(EngineContext context, double deltaSeconds) {
    final sessions = context.world.query<ScriptProperties>().where(
      (entry) => entry.$2.values.containsKey('scene_name'),
    );
    final players = context.world.query2<Transform3, PlatformerBody>().toList();
    if (sessions.isEmpty || players.isEmpty) return;
    final session = sessions.first.$2.values;
    final playerEntity = players.first.$1;
    final transform = players.first.$2;
    final body = players.first.$3;
    final axis = ((session['move_axis'] as num?)?.toDouble() ?? 0).clamp(-1, 1);
    final nextX = (transform.x + axis * body.moveSpeed * deltaSeconds).clamp(
      minimumX,
      maximumX,
    );

    final jumpRequested = session.remove('jump_requested') == true;
    var justJumped = false;
    if (jumpRequested && body.grounded) {
      body
        ..velocityY = body.jumpSpeed
        ..grounded = false;
      justJumped = true;
    }

    body.velocityY -= body.gravity * deltaSeconds;
    var nextY = transform.y + body.velocityY * deltaSeconds;
    body.grounded = false;
    if (body.velocityY <= 0) {
      for (final (_, platformTransform, components)
          in context.world.query2<Transform3, ScriptComponents>()) {
        final platform = components.values['platform'];
        if (platform == null) continue;
        final width = (platform['width'] as num?)?.toDouble() ?? 4;
        final halfHeight = (platform['height'] as num?)?.toDouble() ?? .35;
        final top = platformTransform.y + halfHeight;
        final previousFeet = transform.y - body.halfHeight;
        final nextFeet = nextY - body.halfHeight;
        if ((nextX - platformTransform.x).abs() <= width / 2 + body.halfWidth &&
            previousFeet >= top - .18 &&
            nextFeet <= top) {
          nextY = top + body.halfHeight;
          body
            ..velocityY = 0
            ..grounded = true;
          break;
        }
      }
    }

    var respawned = false;
    if (nextY < -3) {
      transform
        ..x = body.checkpointX
        ..y = body.checkpointY;
      body
        ..velocityY = 0
        ..grounded = false;
      body.respawnCount++;
      respawned = true;
    } else {
      transform
        ..x = nextX
        ..y = nextY;
    }

    final script = context.world.maybeGet<ScriptComponents>(playerEntity);
    final movement = script?.values['platformer_player'];
    if (movement != null) {
      movement
        ..['grounded'] = body.grounded
        ..['velocity_y'] = body.velocityY
        ..['just_jumped'] = justJumped
        ..['respawned'] = respawned
        ..['respawn_count'] = body.respawnCount;
    }
    final animation = script?.values['character_animation'];
    if (animation != null) {
      if (axis != 0) animation['facing'] = axis;
      animation['state'] = !body.grounded
          ? (body.velocityY >= 0 ? 'jump' : 'fall')
          : axis != 0
          ? 'run'
          : 'idle';
    }
  }
}
