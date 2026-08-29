import '../engine/entity.dart';
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
    var nextX = (transform.x + axis * body.moveSpeed * deltaSeconds).clamp(
      minimumX,
      maximumX,
    );

    // Resolve solid platform sides before vertical movement. Standing exactly
    // on a platform is not vertical overlap, so actors can still walk across
    // its top and leave an edge naturally.
    for (final (_, platformTransform, components)
        in context.world.query2<Transform3, ScriptComponents>()) {
      final platform = components.values['platform'];
      if (platform == null || platform['one_way'] == true) continue;
      final width = (platform['width'] as num?)?.toDouble() ?? 4;
      final halfHeight = (platform['height'] as num?)?.toDouble() ?? .35;
      final left = platformTransform.x - width / 2;
      final right = platformTransform.x + width / 2;
      final bottom = platformTransform.y - halfHeight;
      final top = platformTransform.y + halfHeight;
      final actorBottom = transform.y - body.halfHeight;
      final actorTop = transform.y + body.halfHeight;
      final overlapsVertically =
          actorBottom < top - .0001 && actorTop > bottom + .0001;
      if (!overlapsVertically) continue;
      final currentLeft = transform.x - body.halfWidth;
      final currentRight = transform.x + body.halfWidth;
      final nextLeft = nextX - body.halfWidth;
      final nextRight = nextX + body.halfWidth;
      if (axis > 0 && currentRight <= left + .0001 && nextRight >= left) {
        nextX = left - body.halfWidth;
      } else if (axis < 0 &&
          currentLeft >= right - .0001 &&
          nextLeft <= right) {
        nextX = right + body.halfWidth;
      }
    }

    final jumpRequested = session.remove('jump_requested') == true;
    var justJumped = false;
    if (jumpRequested && body.grounded) {
      body
        ..velocityY = body.jumpSpeed
        ..grounded = false
        ..groundedPlatform = null;
      justJumped = true;
    }

    body.velocityY -= body.gravity * deltaSeconds;
    var nextY = transform.y + body.velocityY * deltaSeconds;
    body.grounded = false;
    body.groundedPlatform = null;
    if (body.velocityY <= 0) {
      for (final (platformEntity, platformTransform, components)
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
            ..grounded = true
            ..groundedPlatform = platformEntity;
          break;
        }
      }
    } else {
      // Solid platforms also stop upward motion at their underside. Lua can
      // set platform.one_way=true to retain jump-through behavior.
      for (final (_, platformTransform, components)
          in context.world.query2<Transform3, ScriptComponents>()) {
        final platform = components.values['platform'];
        if (platform == null || platform['one_way'] == true) continue;
        final width = (platform['width'] as num?)?.toDouble() ?? 4;
        final halfHeight = (platform['height'] as num?)?.toDouble() ?? .35;
        final bottom = platformTransform.y - halfHeight;
        final previousHead = transform.y + body.halfHeight;
        final nextHead = nextY + body.halfHeight;
        if ((nextX - platformTransform.x).abs() <= width / 2 + body.halfWidth &&
            previousHead <= bottom + .0001 &&
            nextHead >= bottom) {
          nextY = bottom - body.halfHeight;
          body.velocityY = 0;
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
        ..grounded = false
        ..groundedPlatform = null;
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

/// Moves a platform and every entity currently riding it by the same delta.
///
/// Physics-controlled actors are attached automatically when they land. Other
/// scripted actors opt in with `platform_rider.platform = platformEntity`.
void movePlatformAndRiders(
  EngineContext context,
  Entity platformEntity,
  double x,
  double y,
  double z,
) {
  final platform = context.world.get<Transform3>(platformEntity);
  final dx = x - platform.x;
  final dy = y - platform.y;
  final dz = z - platform.z;
  if (dx == 0 && dy == 0 && dz == 0) return;

  platform
    ..x = x
    ..y = y
    ..z = z;

  for (final (entity, transform) in context.world.query<Transform3>()) {
    if (entity == platformEntity) continue;
    final body = context.world.maybeGet<PlatformerBody>(entity);
    final scripts = context.world.maybeGet<ScriptComponents>(entity);
    final riderPlatform = scripts?.values['platform_rider']?['platform'];
    final attached =
        body?.groundedPlatform == platformEntity ||
        (riderPlatform is num && riderPlatform.toInt() == platformEntity.id);
    if (!attached) continue;
    transform
      ..x += dx
      ..y += dy
      ..z += dz;
    final walker = scripts?.values['walker'];
    final origin = walker?['origin'];
    if (origin is num && dx != 0) walker!['origin'] = origin.toDouble() + dx;
  }
}
