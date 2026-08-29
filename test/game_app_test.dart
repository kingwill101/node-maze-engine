import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/app.dart';
import 'package:node/engine/plugin.dart';
import 'package:node/engine/runtime.dart';
import 'package:node/engine/schedule.dart';
import 'package:node/engine/state.dart';

class _Log {
  final List<String> values = <String>[];
}

class _LogSystem implements EngineSystem {
  const _LogSystem(this.value);

  final String value;

  @override
  void update(EngineContext context, double deltaSeconds) {
    context.resources.get<_Log>().values.add(value);
  }
}

class _TestPlugin implements GamePlugin {
  const _TestPlugin();

  @override
  String get name => 'test';

  @override
  void build(GameApp app) {
    app
      ..insertResource(_Log())
      ..addSystem(
        ScheduleLabel.update,
        const _LogSystem('plugin'),
        label: 'plugin',
      );
  }
}

enum _Mode { menu, playing }

void main() {
  test('plugins are idempotent and install systems and resources', () {
    final app = GameApp()..addPlugin(const _TestPlugin());
    app.addPlugin(const _TestPlugin()).update(.01);

    expect(app.plugins, {'test'});
    expect(app.context.resources.get<_Log>().values, ['plugin']);
  });

  test('schedules respect lifecycle and explicit ordering', () {
    final log = _Log();
    final app = GameApp(fixedDelta: .1)
      ..insertResource(log)
      ..addSystem(ScheduleLabel.startup, const _LogSystem('startup'))
      ..addSystem(
        ScheduleLabel.fixedUpdate,
        const _LogSystem('physics'),
        label: 'physics',
        after: {'input'},
      )
      ..addSystem(
        ScheduleLabel.fixedUpdate,
        const _LogSystem('input'),
        label: 'input',
      )
      ..addSystem(ScheduleLabel.update, const _LogSystem('update'));

    app.update(.25);
    app.update(.01);

    expect(log.values, [
      'startup',
      'input',
      'physics',
      'input',
      'physics',
      'update',
      'update',
    ]);
  });

  test('commands defer structural mutations until schedule boundaries', () {
    final app = GameApp();
    late final int reserved;
    app.addSystem(
      ScheduleLabel.update,
      _ClosureSystem((context) {
        final entity = context.commands.spawn([_Log()]);
        reserved = entity.id;
        expect(context.world.isAlive(entity), isFalse);
      }),
    );

    app.update(.01);

    expect(app.context.world.entityCount, 1);
    expect(app.context.world.entities.single.id, reserved);
  });

  test('typed state transitions are deferred and emitted as events', () {
    final app = GameApp()..initState(_Mode.menu);
    StateTransition<_Mode>? observed;
    app.context.events.on<StateTransition<_Mode>>((event) => observed = event);
    app.context.resources.get<StateMachine<_Mode>>().setNext(_Mode.playing);

    app.applyState<_Mode>();

    expect(observed?.from, _Mode.menu);
    expect(observed?.to, _Mode.playing);
  });

  test('dependency cycles and missing labels fail loudly', () {
    final missing = GameApp()
      ..addSystem(
        ScheduleLabel.update,
        const _LogSystem('a'),
        label: 'a',
        after: {'missing'},
      );
    expect(() => missing.update(.01), throwsStateError);

    final cycle = GameApp()
      ..addSystem(
        ScheduleLabel.update,
        const _LogSystem('a'),
        label: 'a',
        after: {'b'},
      )
      ..addSystem(
        ScheduleLabel.update,
        const _LogSystem('b'),
        label: 'b',
        after: {'a'},
      );
    expect(() => cycle.update(.01), throwsStateError);
  });
}

class _ClosureSystem implements EngineSystem {
  const _ClosureSystem(this.callback);

  final void Function(EngineContext context) callback;

  @override
  void update(EngineContext context, double deltaSeconds) => callback(context);
}
