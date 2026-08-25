import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/runtime.dart';
import 'package:node/game/components.dart';
import 'package:node/scripting/lua_behavior_runtime.dart';
import 'package:node/scripting/lua_behavior_scheduler.dart';

void main() {
  test('signals cross isolated entity Lua VMs on the next safe tick', () async {
    final engine = EngineContext();
    final scheduler = LuaBehaviorScheduler();
    final sender = engine.world.create([ScriptProperties()]);
    final receiver = engine.world.create([ScriptProperties()]);

    await scheduler.attach(
      entity: sender,
      runtime: LuaBehaviorRuntime(engine, emitSignal: scheduler.emitSignal),
      source: '''
        function ready(entity)
          emit_signal(entity, 'alarm', 'moon_gate')
        end
      ''',
    );
    await scheduler.attach(
      entity: receiver,
      runtime: LuaBehaviorRuntime(engine, emitSignal: scheduler.emitSignal),
      source: '''
        function signal_received(entity, name, source, payload)
          entity_set_property(entity, 'signal_name', name)
          entity_set_property(entity, 'signal_source', source)
          entity_set_property(entity, 'signal_payload', payload)
        end
      ''',
    );

    scheduler.fixedUpdate(1 / 60);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final values = engine.world.get<ScriptProperties>(receiver).values;
    expect(values['signal_name'], 'alarm');
    expect(values['signal_source'], sender.id);
    expect(values['signal_payload'], 'moon_gate');
  });
}
