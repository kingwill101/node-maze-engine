import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/runtime.dart';
import 'package:node/game/components.dart';
import 'package:node/platformer/platformer_components.dart';
import 'package:node/platformer/platformer_system.dart';

void main() {
  test('platformer kernel lands, moves, and jumps deterministically', () {
    final context = EngineContext();
    final session = context.world.create([
      ScriptProperties({'scene_name': 'Test', 'move_axis': 1}),
    ]);
    final player = context.world.create([
      Transform3(2, .81, 2),
      PlatformerBody(checkpointX: 2, checkpointY: .8),
      ScriptComponents({'platformer_player': {}, 'character_animation': {}}),
    ]);
    context.world.create([
      Transform3(3, 0, 2),
      ScriptComponents({
        'platform': {'width': 6, 'height': .35},
      }),
    ]);
    const system = PlatformerPhysicsSystem(minimumX: 0, maximumX: 20);

    for (var frame = 0; frame < 8; frame++) {
      system.update(context, 1 / 60);
    }
    final transform = context.world.get<Transform3>(player);
    final body = context.world.get<PlatformerBody>(player);
    expect(body.grounded, isTrue);
    expect(transform.x, greaterThan(2));
    expect(
      context.world
          .get<ScriptComponents>(player)
          .values['character_animation']?['state'],
      'run',
    );

    context.world.get<ScriptProperties>(session).values['jump_requested'] =
        true;
    system.update(context, 1 / 60);
    expect(body.velocityY, greaterThan(0));
    expect(body.grounded, isFalse);
    expect(
      context.world
          .get<ScriptComponents>(player)
          .values['platformer_player']?['just_jumped'],
      isTrue,
    );
  });

  test('falling below the death plane restores the checkpoint', () {
    final context = EngineContext();
    context.world.create([
      ScriptProperties({'scene_name': 'Test'}),
    ]);
    final player = context.world.create([
      Transform3(8, -3.1, 2),
      PlatformerBody(checkpointX: 3, checkpointY: 1.2),
      ScriptComponents({'platformer_player': {}}),
    ]);

    const PlatformerPhysicsSystem(
      minimumX: 0,
      maximumX: 20,
    ).update(context, 1 / 60);

    final transform = context.world.get<Transform3>(player);
    final body = context.world.get<PlatformerBody>(player);
    expect(transform.x, 3);
    expect(transform.y, 1.2);
    expect(body.respawnCount, 1);
  });

  test('moving platforms carry grounded and scripted riders', () {
    final context = EngineContext();
    final platform = context.world.create([
      Transform3(4, 1, 2),
      ScriptComponents({
        'platform': {'width': 4, 'height': .4},
      }),
    ]);
    final body = PlatformerBody(checkpointX: 4, checkpointY: 2)
      ..grounded = true
      ..groundedPlatform = platform;
    final player = context.world.create([Transform3(4, 1.85, 2), body]);
    final enemy = context.world.create([
      Transform3(4.5, 1.5, 2),
      ScriptComponents({
        'platform_rider': {'platform': platform.id},
      }),
    ]);

    movePlatformAndRiders(context, platform, 4.5, 1.75, 2);

    expect(context.world.get<Transform3>(player).x, 4.5);
    expect(context.world.get<Transform3>(player).y, 2.6);
    expect(context.world.get<Transform3>(enemy).x, 5);
    expect(context.world.get<Transform3>(enemy).y, 2.25);
  });
}
