import 'app.dart';

abstract interface class GamePlugin {
  String get name;

  void build(GameApp app);
}

class PluginGroup implements GamePlugin {
  const PluginGroup(this.name, this.plugins);

  @override
  final String name;
  final List<GamePlugin> plugins;

  @override
  void build(GameApp app) {
    for (final plugin in plugins) {
      app.addPlugin(plugin);
    }
  }
}
