import 'package:flutter/services.dart';

import '../game/level.dart';
import 'lua_level_loader.dart';

class LuaGamePackageLoader {
  const LuaGamePackageLoader({this.levelLoader = const LuaLevelLoader()});

  final LuaLevelLoader levelLoader;

  Future<GameCatalog> load(
    AssetBundle assets, {
    String indexPath = 'assets/games/catalog.lua',
  }) async {
    final index = await levelLoader.loadPackageIndex(
      await assets.loadString(indexPath),
      scriptPath: indexPath,
    );
    final games = <GameDefinition>[];
    for (final manifestPath in index.manifests) {
      final catalog = await levelLoader.loadCatalog(
        await assets.loadString(manifestPath),
        scriptPath: manifestPath,
      );
      games.addAll(catalog.games);
    }
    if (games.isEmpty) {
      throw const FormatException('No playable game packages were loaded');
    }
    return GameCatalog(name: index.name, games: games);
  }
}
