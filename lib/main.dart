import 'dart:math' as math;

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:flutter_lualike/flutter_lualike.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'engine/entity.dart';
import 'engine/world.dart';
import 'game/components.dart';
import 'game/game_audio.dart';
import 'game/game_save.dart';
import 'game/level.dart';
import 'game/maze_game.dart';
import 'generated/nix_character.g.dart';
import 'scene/moonfall_environment.dart';
import 'scene/procedural_character.dart';
import 'scripting/lua_level_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await useAssetBundle(rootBundle, assetRoot: 'assets/lua');
  final levelSource = await rootBundle.loadString('assets/lua/level.lua');
  final catalog = await LuaLevelLoader().loadCatalog(
    levelSource,
    scriptPath: 'assets/lua/level.lua',
  );
  final saveStore = SharedPreferencesGameSaveStore();
  final saveData = await saveStore.load();
  runApp(
    MazeEngineApp(catalog: catalog, saveStore: saveStore, saveData: saveData),
  );
}

class MazeEngineApp extends StatefulWidget {
  const MazeEngineApp({
    super.key,
    this.catalog,
    this.campaign,
    this.saveStore,
    this.saveData,
  }) : assert(catalog != null || campaign != null);

  final GameCatalog? catalog;
  final LevelCampaign? campaign;
  final GameSaveStore? saveStore;
  final GameSaveData? saveData;

  @override
  State<MazeEngineApp> createState() => _MazeEngineAppState();
}

class _MazeEngineAppState extends State<MazeEngineApp> {
  int? selectedGame;
  int? selectedLevel;
  late final GameSaveData saveData = widget.saveData ?? GameSaveData();

  Future<void> _completeChapter(String gameId, int chapter) async {
    final game = catalog.games.firstWhere((game) => game.id == gameId);
    setState(() {
      saveData.completeChapter(gameId, chapter, game.campaign.levels.length);
    });
    await widget.saveStore?.save(saveData);
  }

  Future<void> _updateSettings({
    required bool reducedMotion,
    required bool highContrast,
    required bool audioEnabled,
  }) async {
    setState(() {
      saveData
        ..reducedMotion = reducedMotion
        ..highContrast = highContrast
        ..audioEnabled = audioEnabled;
    });
    await widget.saveStore?.save(saveData);
  }

  GameCatalog get catalog =>
      widget.catalog ??
      GameCatalog(
        name: 'Node Game Center',
        games: [
          GameDefinition(
            id: 'legacy',
            name: widget.campaign!.name,
            tagline: '',
            campaign: widget.campaign!,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final activeGame = selectedGame == null
        ? null
        : catalog.games[selectedGame!];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Node Game Center',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: saveData.highContrast
            ? Colors.black
            : const Color(0xff050510),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff31e7ff),
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: saveData.reducedMotion),
        child: child!,
      ),
      home: activeGame == null
          ? GameCenterScene(
              catalog: catalog,
              settings: saveData,
              onSettingsChanged: _updateSettings,
              onSelect: (index) => setState(() => selectedGame = index),
            )
          : selectedLevel == null
          ? StartScene(
              campaign: activeGame.campaign,
              unlockedLevelIndex: saveData.unlockedChapter(activeGame.id),
              completedLevels: {
                for (
                  var index = 0;
                  index < activeGame.campaign.levels.length;
                  index++
                )
                  if (saveData.isCompleted(activeGame.id, index)) index,
              },
              onStart: (index) => setState(() => selectedLevel = index),
              onBack: () => setState(() => selectedGame = null),
            )
          : MazeGameView(
              campaign: activeGame.campaign,
              gameId: activeGame.id,
              audioEnabled: saveData.audioEnabled,
              initialLevelIndex: selectedLevel!,
              onLevelCompleted: _completeChapter,
              onExitToMenu: () => setState(() => selectedLevel = null),
            ),
    );
  }
}

class GameCenterScene extends StatefulWidget {
  const GameCenterScene({
    super.key,
    required this.catalog,
    required this.onSelect,
    this.settings,
    this.onSettingsChanged,
  });

  final GameCatalog catalog;
  final ValueChanged<int> onSelect;
  final GameSaveData? settings;
  final Future<void> Function({
    required bool reducedMotion,
    required bool highContrast,
    required bool audioEnabled,
  })?
  onSettingsChanged;

  @override
  State<GameCenterScene> createState() => _GameCenterSceneState();
}

class _GameCenterSceneState extends State<GameCenterScene> {
  int selected = 0;
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      setState(() => selected = (selected + 1) % widget.catalog.games.length);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(
        () => selected =
            (selected - 1 + widget.catalog.games.length) %
            widget.catalog.games.length,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelect(selected);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: _handleKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _TitleBackdrop(),
          if (widget.settings != null && widget.onSettingsChanged != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: IconButton.filledTonal(
                    tooltip: 'Accessibility settings',
                    icon: const Icon(Icons.accessibility_new),
                    onPressed: _showSettings,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NODE GAME CENTER',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 7,
                      color: Color(0xff31e7ff),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.catalog.games.length} WORLDS · ONE LUA/ECS ENGINE',
                    style: const TextStyle(
                      letterSpacing: 3,
                      color: Color(0xffb35cff),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (
                        var index = 0;
                        index < widget.catalog.games.length;
                        index++
                      )
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == 0 ? 18 : 0,
                            ),
                            child: _GameCard(
                              game: widget.catalog.games[index],
                              selected: selected == index,
                              onTap: () => setState(() => selected = index),
                              onStart: () => widget.onSelect(index),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => widget.onSelect(selected),
                    icon: const Icon(Icons.sports_esports),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('OPEN GAME'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _showSettings() async {
    var reducedMotion = widget.settings!.reducedMotion;
    var highContrast = widget.settings!.highContrast;
    var audioEnabled = widget.settings!.audioEnabled;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ACCESSIBILITY'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Audio'),
                  subtitle: const Text('Music and gameplay sound effects'),
                  value: audioEnabled,
                  onChanged: (value) =>
                      setDialogState(() => audioEnabled = value),
                ),
                SwitchListTile(
                  title: const Text('Reduced motion'),
                  subtitle: const Text('Disables interface transitions'),
                  value: reducedMotion,
                  onChanged: (value) =>
                      setDialogState(() => reducedMotion = value),
                ),
                SwitchListTile(
                  title: const Text('High contrast'),
                  subtitle: const Text('Uses a pure-black game center'),
                  value: highContrast,
                  onChanged: (value) =>
                      setDialogState(() => highContrast = value),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                widget.onSettingsChanged!(
                  reducedMotion: reducedMotion,
                  highContrast: highContrast,
                  audioEnabled: audioEnabled,
                );
                Navigator.pop(context);
              },
              child: const Text('SAVE SETTINGS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.selected,
    required this.onTap,
    required this.onStart,
  });

  final GameDefinition game;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onDoubleTap: onStart,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 250,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: game.id == 'moonfall_courier'
              ? const [Color(0xff321957), Color(0xff102f52)]
              : const [Color(0xff10224a), Color(0xff071227)],
        ),
        border: Border.all(
          color: selected ? const Color(0xff31e7ff) : Colors.white24,
          width: selected ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            game.id == 'moonfall_courier'
                ? Icons.nightlight_round
                : Icons.blur_circular,
            size: 48,
            color: game.id == 'moonfall_courier'
                ? const Color(0xffb35cff)
                : const Color(0xff31e7ff),
          ),
          const Spacer(),
          Text(
            game.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(game.tagline, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Text(
            '${game.campaign.levels.length} CHAPTER${game.campaign.levels.length == 1 ? '' : 'S'}',
            style: const TextStyle(color: Color(0xffffd45c), letterSpacing: 2),
          ),
        ],
      ),
    ),
  );
}

class StartScene extends StatefulWidget {
  const StartScene({
    super.key,
    required this.campaign,
    required this.onStart,
    this.onBack,
    this.unlockedLevelIndex,
    this.completedLevels = const {},
  });

  final LevelCampaign campaign;
  final ValueChanged<int> onStart;
  final VoidCallback? onBack;
  final int? unlockedLevelIndex;
  final Set<int> completedLevels;

  int get maximumUnlocked => unlockedLevelIndex ?? campaign.levels.length - 1;

  @override
  State<StartScene> createState() => _StartSceneState();
}

class _StartSceneState extends State<StartScene> {
  int selected = 0;
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final count = widget.campaign.levels.length;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      setState(() => selected = (selected + 1) % count);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() => selected = (selected - 1 + count) % count);
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (selected <= widget.maximumUnlocked) widget.onStart(selected);
    } else if (event.logicalKey == LogicalKeyboardKey.escape &&
        widget.onBack != null) {
      widget.onBack!();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.campaign.levels[selected];
    return Scaffold(
      body: Focus(
        autofocus: true,
        focusNode: focusNode,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _TitleBackdrop(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 30, 36, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.campaign.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 9,
                        color: Color(0xff31e7ff),
                        shadows: [
                          Shadow(color: Color(0xff31e7ff), blurRadius: 24),
                        ],
                      ),
                    ),
                    Text(
                      level.gameId == 'moonfall_courier'
                          ? 'MOONFALL COURIER'
                          : 'NODE MAZE',
                      style: const TextStyle(
                        letterSpacing: 5,
                        color: Color(0xffb35cff),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      level.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        level.story,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Badge(
                          label: '${level.maze.width} × ${level.maze.height}',
                        ),
                        _Badge(
                          label: switch (level.cameraMode) {
                            CameraMode.firstPerson => 'CORRIDOR START',
                            CameraMode.platformer => 'PLATFORMER START',
                            CameraMode.follow => 'TACTICAL START',
                          },
                        ),
                        _Badge(label: '${level.events.length} STORY EVENTS'),
                        if (level.autoRun) const _Badge(label: 'AUTO-RUN'),
                        if (level.name == 'Dreamseed 7331')
                          const _Badge(label: 'LUA GENERATED'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 126,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.campaign.levels.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => _MapCard(
                          index: index,
                          level: widget.campaign.levels[index],
                          selected: selected == index,
                          locked: index > widget.maximumUnlocked,
                          completed: widget.completedLevels.contains(index),
                          onSelect: () => setState(() => selected = index),
                          onStart: () {
                            if (index <= widget.maximumUnlocked) {
                              widget.onStart(index);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: selected <= widget.maximumUnlocked
                              ? () => widget.onStart(selected)
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('START CHAPTER'),
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Text(
                          'A / D OR ← / → SELECT   •   ENTER STARTS',
                          style: TextStyle(
                            letterSpacing: 2,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.index,
    required this.level,
    required this.selected,
    required this.locked,
    required this.completed,
    required this.onSelect,
    required this.onStart,
  });

  final int index;
  final LevelDefinition level;
  final bool selected;
  final bool locked;
  final bool completed;
  final VoidCallback onSelect;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: InkWell(
      key: ValueKey('map-card-$index'),
      onTap: onSelect,
      onDoubleTap: onStart,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xee10224a) : const Color(0xbb08081c),
          border: Border.all(
            color: selected ? const Color(0xff31e7ff) : Colors.white24,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x6631e7ff), blurRadius: 22)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locked
                  ? 'LOCKED'
                  : completed
                  ? 'COMPLETE'
                  : '0${index + 1}',
              style: const TextStyle(color: Color(0xffb35cff)),
            ),
            const Spacer(),
            Text(
              level.name.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              level.objective.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TitleBackdrop extends StatelessWidget {
  const _TitleBackdrop();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TitleBackdropPainter(),
    child: const SizedBox.expand(),
  );
}

class _TitleBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.55, -.35),
          radius: 1.2,
          colors: [Color(0xff172c63), Color(0xff08081c), Color(0xff020208)],
        ).createShader(Offset.zero & size),
    );
    final grid = Paint()
      ..color = const Color(0x2231e7ff)
      ..strokeWidth = 1;
    const spacing = 44.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MazeGameView extends StatefulWidget {
  const MazeGameView({
    super.key,
    required this.campaign,
    required this.gameId,
    required this.audioEnabled,
    this.initialLevelIndex = 0,
    required this.onExitToMenu,
    required this.onLevelCompleted,
  });
  final LevelCampaign campaign;
  final String gameId;
  final bool audioEnabled;
  final int initialLevelIndex;
  final VoidCallback onExitToMenu;
  final void Function(String gameId, int chapter) onLevelCompleted;

  @override
  State<MazeGameView> createState() => _MazeGameViewState();
}

class _MazeGameViewState extends State<MazeGameView> {
  late MazeGame game;
  late int levelIndex;
  double animationSeconds = 0;
  double cameraYaw = math.pi;
  double targetCameraYaw = math.pi;
  late CameraMode activeCameraMode;
  bool paused = false;
  bool inspectorVisible = false;
  bool completionRecorded = false;
  late final GameAudio audio = GameAudio(enabled: widget.audioEnabled);
  int observedScore = 0;
  int observedLives = 3;
  int observedCheckpoints = 0;
  double get sceneTileScale =>
      activeCameraMode == CameraMode.firstPerson ? 2.35 : 1;
  final FocusNode focusNode = FocusNode();
  final CuboidGeometry wallGeometry = CuboidGeometry(vm.Vector3(1, .9, .88));
  final CuboidGeometry wallRailGeometry = CuboidGeometry(
    vm.Vector3(1, .12, .96),
  );
  final SphereGeometry pelletGeometry = SphereGeometry(radius: .1);
  final SphereGeometry powerPelletGeometry = SphereGeometry(radius: .2);
  final SphereGeometry playerGeometry = SphereGeometry(radius: .38);
  final SphereGeometry ghostGeometry = SphereGeometry(radius: .38);
  final SphereGeometry detailGeometry = SphereGeometry(radius: .12);
  final SphereGeometry scriptSphereGeometry = SphereGeometry(radius: 1);
  final CuboidGeometry scriptBoxGeometry = CuboidGeometry(vm.Vector3.all(1));
  final CuboidGeometry floorGeometry = CuboidGeometry(vm.Vector3(1, .08, 1));
  final CuboidGeometry runeGeometry = CuboidGeometry(vm.Vector3(.12, .3, .12));
  final TorusGeometry portalGeometry = TorusGeometry(
    radius: .38,
    tubeRadius: .07,
  );
  late final UnlitMaterial wallMaterial = _material(.015, .04, .18);
  late final UnlitMaterial wallRailMaterial = _material(.02, .65, 1);
  late final UnlitMaterial pelletMaterial = _material(1, .72, .15);
  late final UnlitMaterial powerPelletMaterial = _material(.1, 1, .9);
  late final UnlitMaterial floorMaterial = _material(.012, .018, .07);
  late final UnlitMaterial playerMaterial = _material(1, .84, .05);
  late final UnlitMaterial rubyMaterial = _material(1, .08, .2);
  late final UnlitMaterial saffronMaterial = _material(1, .42, .05);
  late final UnlitMaterial irisMaterial = _material(.68, .18, 1);
  late final UnlitMaterial mintMaterial = _material(.05, .88, .55);
  late final UnlitMaterial frightenedMaterial = _material(.08, .18, 1);
  late final UnlitMaterial frightenedBlinkMaterial = _material(1, 1, 1);
  late final UnlitMaterial burgundyMaterial = _material(.38, .035, .08);
  late final UnlitMaterial tealMaterial = _material(.05, .72, .62);
  late final UnlitMaterial eyeMaterial = _material(1, .93, .75);
  late final UnlitMaterial pupilMaterial = _material(.08, .025, .02);
  late final UnlitMaterial fruitMaterial = _material(1, .05, .34);
  PreprocessedMaterial? neonWallMaterial;
  PreprocessedMaterial? riftFloorMaterial;
  PreprocessedMaterial? arcaneEnergyMaterial;
  final Map<String, UnlitMaterial> scriptMaterials = {};
  late final ProceduralCharacterResources nixResources =
      ProceduralCharacterResources(nixCharacterSpec);
  final MoonfallEnvironmentResources moonfallEnvironmentResources =
      MoonfallEnvironmentResources();

  @override
  void initState() {
    super.initState();
    levelIndex = widget.initialLevelIndex;
    game = MazeGame(level: widget.campaign.levels[levelIndex]);
    activeCameraMode = game.level.cameraMode;
    _snapCameraYaw();
    _loadGhostBehavior();
    _loadSceneMaterials();
    if (widget.gameId == 'moonfall_courier') audio.startMoonfallAmbience();
  }

  Future<void> _loadGhostBehavior() async {
    final target = game;
    final sources = await Future.wait([
      rootBundle.loadString('assets/lua/autoload.lua'),
      rootBundle.loadString('assets/lua/ghost.lua'),
      rootBundle.loadString('assets/lua/prefabs.lua'),
    ]);
    await target.loadGameScripts(
      autoloadSource: sources[0],
      ghostSource: sources[1],
      prefabSource: sources[2],
    );
  }

  void _startLevel(int index) {
    setState(() {
      levelIndex = index;
      game = MazeGame(level: widget.campaign.levels[levelIndex]);
      activeCameraMode = game.level.cameraMode;
      paused = false;
      completionRecorded = false;
      observedScore = 0;
      observedLives = 3;
      observedCheckpoints = 0;
      _snapCameraYaw();
    });
    _loadGhostBehavior();
  }

  Future<void> _loadSceneMaterials() async {
    final materials = await Future.wait([
      loadFmatMaterial('assets/materials/neon_wall.fmat'),
      loadFmatMaterial('assets/materials/rift_floor.fmat'),
      loadFmatMaterial('assets/materials/arcane_energy.fmat'),
    ]);
    if (!mounted) return;
    setState(() {
      neonWallMaterial = materials[0];
      riftFloorMaterial = materials[1];
      arcaneEnergyMaterial = materials[2];
    });
  }

  UnlitMaterial _material(double r, double g, double b) => UnlitMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..vertexColorWeight = 0;

  @override
  void dispose() {
    audio.dispose();
    focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (activeCameraMode == CameraMode.platformer && event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        game.setPlatformerAxis(0);
        return KeyEventResult.handled;
      }
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyP ||
            event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.pause)) {
      setState(() => paused = !paused);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyM) {
      widget.onExitToMenu();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyI) {
      setState(() => inspectorVisible = !inspectorVisible);
      return KeyEventResult.handled;
    }
    if (paused) return KeyEventResult.handled;
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyQ) {
      game.castPulseSpell();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyF) {
      game.firePlayerBolt(
        useFirstPersonFacing: activeCameraMode == CameraMode.firstPerson,
      );
      if (activeCameraMode == CameraMode.platformer) {
        audio.play(GameAudioCue.bolt);
      }
      return KeyEventResult.handled;
    }
    if (game.phase != GamePhase.playing &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      if (game.phase == GamePhase.won &&
          levelIndex + 1 >= widget.campaign.levels.length) {
        widget.onExitToMenu();
      } else {
        final next = game.phase == GamePhase.won ? levelIndex + 1 : levelIndex;
        _startLevel(next);
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyV ||
            event.logicalKey == LogicalKeyboardKey.tab)) {
      _toggleCameraMode();
      return KeyEventResult.handled;
    }
    if (activeCameraMode == CameraMode.firstPerson) {
      return _handleFirstPersonKey(event);
    }
    if (activeCameraMode == CameraMode.platformer) {
      return _handlePlatformerKey(event);
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => MoveDirection.right,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => MoveDirection.left,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => MoveDirection.up,
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => MoveDirection.down,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    game.requestMove(direction);
    return KeyEventResult.handled;
  }

  KeyEventResult _handlePlatformerKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      game.setPlatformerAxis(-1);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      game.setPlatformerAxis(1);
    } else if ((key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.keyW) &&
        event is KeyDownEvent) {
      game.requestPlatformerJump();
      audio.play(GameAudioCue.jump);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _toggleCameraMode() {
    setState(() {
      activeCameraMode = activeCameraMode == CameraMode.follow
          ? CameraMode.firstPerson
          : CameraMode.follow;
      if (activeCameraMode == CameraMode.firstPerson) {
        game.enterFirstPerson();
        _snapCameraYaw();
      }
    });
  }

  KeyEventResult _handleFirstPersonKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      game.turnFirstPerson(1);
      _setTargetYaw();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      game.turnFirstPerson(-1);
      _setTargetYaw();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      game.moveFirstPerson();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      game.moveFirstPerson(backward: true);
    } else if (key == LogicalKeyboardKey.space) {
      game.stopPlayer();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _setTargetYaw() {
    targetCameraYaw = switch (game.firstPersonFacing) {
      MoveDirection.up => math.pi,
      MoveDirection.right => math.pi / 2,
      MoveDirection.down => 0,
      MoveDirection.left => -math.pi / 2,
      MoveDirection.none => cameraYaw,
    };
    var difference = targetCameraYaw - cameraYaw;
    while (difference > math.pi) {
      targetCameraYaw -= math.pi * 2;
      difference = targetCameraYaw - cameraYaw;
    }
    while (difference < -math.pi) {
      targetCameraYaw += math.pi * 2;
      difference = targetCameraYaw - cameraYaw;
    }
  }

  void _snapCameraYaw() {
    cameraYaw = targetCameraYaw = switch (game.firstPersonFacing) {
      MoveDirection.up => math.pi,
      MoveDirection.right => math.pi / 2,
      MoveDirection.down => 0,
      MoveDirection.left => -math.pi / 2,
      MoveDirection.none => math.pi,
    };
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera();
    return Scaffold(
      body: Focus(
        autofocus: true,
        focusNode: focusNode,
        onKeyEvent: _handleKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: SceneView.declarative(
                camera: PerspectiveCamera(
                  position: camera.$1,
                  target: camera.$2,
                  fovRadiansY: activeCameraMode == CameraMode.firstPerson
                      ? 76 * math.pi / 180
                      : 45 * math.pi / 180,
                  fovNear: .06,
                ),
                onTick: (elapsed, deltaSeconds) {
                  animationSeconds = elapsed.inMicroseconds / 1000000;
                  final yawBlend = (deltaSeconds * 10).clamp(0.0, 1.0);
                  cameraYaw += (targetCameraYaw - cameraYaw) * yawBlend;
                  neonWallMaterial?.parameters.setFloat(
                    'pulse',
                    .5 + math.sin(animationSeconds * 2.2) * .5,
                  );
                  neonWallMaterial?.parameters.setVec4(
                    'color',
                    game.state.powerSeconds > 0
                        ? vm.Vector4(
                            .75 + math.sin(animationSeconds * 8) * .2,
                            .04,
                            1,
                            1,
                          )
                        : vm.Vector4(.02, .65, 1, 1),
                  );
                  riftFloorMaterial?.parameters.setFloat(
                    'phase',
                    animationSeconds,
                  );
                  arcaneEnergyMaterial?.parameters.setFloat(
                    'phase',
                    animationSeconds,
                  );
                  arcaneEnergyMaterial?.parameters.setFloat(
                    'intensity',
                    game.state.powerSeconds > 0 ? 1.75 : 1.0,
                  );
                  if (!paused) game.advance(deltaSeconds);
                  _updateAudioFeedback();
                  if (game.phase == GamePhase.won && !completionRecorded) {
                    completionRecorded = true;
                    audio.play(GameAudioCue.victory);
                    widget.onLevelCompleted(widget.gameId, levelIndex);
                  }
                  if (mounted) setState(() {});
                },
                loadingBuilder: (_, progress) => Center(
                  child: CircularProgressIndicator(
                    value: progress == 0 ? null : progress,
                  ),
                ),
                children: _sceneEntities(),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _HeroinePortrait(),
                        const SizedBox(width: 12),
                        _Badge(
                          label:
                              '${levelIndex + 1}/${widget.campaign.levels.length}  ${game.level.name.toUpperCase()}',
                        ),
                        const SizedBox(width: 8),
                        _Badge(
                          label: switch (activeCameraMode) {
                            CameraMode.firstPerson => 'CORRIDOR VIEW',
                            CameraMode.platformer => 'PLATFORM VIEW',
                            CameraMode.follow => 'TACTICAL VIEW',
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ..._scriptHudWidgets(),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    game.phase == GamePhase.playing
                        ? activeCameraMode == CameraMode.platformer
                              ? 'A / D MOVE   •   SPACE JUMP   •   F STAR BOLT   •   P PAUSE'
                              : 'F FIRE   •   Q STAR PULSE   •   V / TAB SWITCH VIEW   •   ${game.level.objective.toUpperCase()}'
                        : 'ENTER / SPACE TO RESTART',
                    style: const TextStyle(
                      letterSpacing: 3,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
            if (game.state.announcementSeconds > 0)
              _StoryBanner(message: game.state.announcement),
            Positioned(
              right: 20,
              bottom: 52,
              child: _MapOverlay(game: game, cameraMode: activeCameraMode),
            ),
            if (activeCameraMode == CameraMode.firstPerson)
              const Center(child: _Crosshair()),
            if (inspectorVisible) _RuntimeInspector(game: game),
            if (paused)
              _PauseOverlay(
                onResume: () => setState(() => paused = false),
                onExitToMenu: widget.onExitToMenu,
              ),
            if (game.phase != GamePhase.playing)
              _GameStateOverlay(
                phase: game.phase,
                score: game.score,
                hasNextLevel: levelIndex + 1 < widget.campaign.levels.length,
                isPlatformer: widget.gameId == 'moonfall_courier',
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _scriptHudWidgets() {
    final widgets = <Widget>[];
    for (final (_, hud) in game.runtime.context.world.query<ScriptHud>()) {
      for (final element in hud.elements.values) {
        final color = _scriptColor(element.color);
        final child = element.type == ScriptHudElementType.label
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xcc08081c),
                  border: Border.all(color: color.withValues(alpha: .7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    element.text,
                    style: TextStyle(
                      color: color,
                      fontSize: element.fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              )
            : SizedBox(
                width: element.width,
                height: element.height,
                child: LinearProgressIndicator(
                  value: element.maximum <= 0
                      ? 0
                      : (element.value / element.maximum).clamp(0, 1),
                  color: color,
                  backgroundColor: const Color(0x6608081c),
                ),
              );
        widgets.add(
          Positioned(
            top: element.anchor.startsWith('top') ? element.y : null,
            bottom: element.anchor.startsWith('bottom') ? element.y : null,
            left: element.anchor.endsWith('left') ? element.x : null,
            right: element.anchor.endsWith('right') ? element.x : null,
            child: SafeArea(child: IgnorePointer(child: child)),
          ),
        );
      }
    }
    return widgets;
  }

  void _updateAudioFeedback() {
    if (widget.gameId != 'moonfall_courier') return;
    if (game.score > observedScore) audio.play(GameAudioCue.collect);
    if (game.lives < observedLives) audio.play(GameAudioCue.hurt);
    final checkpoints = game.runtime.context.world
        .query<ScriptComponents>()
        .where((entry) => entry.$2.values['checkpoint']?['active'] == true)
        .length;
    if (checkpoints > observedCheckpoints) {
      audio.play(GameAudioCue.checkpoint);
    }
    observedScore = game.score;
    observedLives = game.lives;
    observedCheckpoints = checkpoints;
  }

  (vm.Vector3, vm.Vector3) _camera() {
    final transform = game.runtime.context.world.get<Transform3>(game.player);
    final player = _scenePosition(transform);
    if (activeCameraMode == CameraMode.firstPerson) {
      final mover = game.runtime.context.world.get<GridMover>(game.player);
      final moving = mover.direction != MoveDirection.none;
      final bob = moving ? math.sin(animationSeconds * 11) * .035 : 0.0;
      final forward = vm.Vector3(math.sin(cameraYaw), 0, math.cos(cameraYaw));
      return (
        player + vm.Vector3(0, .68 + bob, 0),
        player + vm.Vector3(0, .62 + bob, 0) + forward * 12,
      );
    }
    if (activeCameraMode == CameraMode.platformer) {
      return (player + vm.Vector3(0, 3.2, 9.5), player + vm.Vector3(0, 1.4, 0));
    }
    return (player + vm.Vector3(0, 10.5, 6.5), player + vm.Vector3(0, 0, -1.2));
  }

  List<Widget> _sceneEntities() {
    final playerTransform = game.runtime.context.world.get<Transform3>(
      game.player,
    );
    final renderDistance = game.level.renderDistance;
    final widgets = <Widget>[
      if (activeCameraMode == CameraMode.platformer)
        MoonfallEnvironment(
          resources: moonfallEnvironmentResources,
          playerX: playerTransform.x * sceneTileScale,
          time: animationSeconds,
        )
      else
        SceneMesh(
          name: 'maze-floor',
          geometry: floorGeometry,
          material: riftFloorMaterial ?? floorMaterial,
          position: vm.Vector3(
            playerTransform.x * sceneTileScale,
            -.5,
            playerTransform.z * sceneTileScale,
          ),
          scale: vm.Vector3(
            renderDistance * 2.4 * sceneTileScale,
            1,
            renderDistance * 2.4 * sceneTileScale,
          ),
        ),
      if (game.state.spellPulseSeconds > 0) _spellPulse(playerTransform),
    ];
    for (final (entity, transform)
        in game.runtime.context.world.query<Transform3>()) {
      if (!_isVisible(transform, playerTransform, renderDistance)) continue;
      if (game.runtime.context.world.has<PlayerTag>(entity)) {
        if (activeCameraMode == CameraMode.firstPerson) continue;
        widgets.add(_heroine(entity, transform));
        _appendScriptDrawings(widgets, entity, transform);
        continue;
      }
      if (game.runtime.context.world.has<GhostTag>(entity)) {
        widgets.add(_ghostCharacter(entity, transform));
        _appendScriptDrawings(widgets, entity, transform);
        continue;
      }
      if (game.runtime.context.world.has<BonusFruitTag>(entity)) {
        widgets.add(_bonusFruit(entity, transform));
        _appendScriptDrawings(widgets, entity, transform);
        continue;
      }
      if (game.runtime.context.world.has<PortalTag>(entity)) {
        widgets.add(_portal(entity, transform));
        continue;
      }
      if (game.runtime.context.world.has<SpellPickupTag>(entity)) {
        widgets.add(_spellPickup(entity, transform));
        continue;
      }
      if (game.runtime.context.world.has<KeyPickupTag>(entity)) {
        widgets.add(_keyPickup(entity, transform));
        continue;
      }
      final door = game.runtime.context.world.maybeGet<DoorTag>(entity);
      if (door != null) {
        if (!door.open) widgets.add(_door(entity, transform));
        continue;
      }
      final trap = game.runtime.context.world.maybeGet<TrapTag>(entity);
      if (trap != null) {
        widgets.add(_trap(entity, transform, trap));
        continue;
      }
      final wallRun = game.runtime.context.world.maybeGet<WallRun>(entity);
      if (wallRun != null) {
        widgets.add(_wallRun(entity, transform, wallRun));
        continue;
      }
      final visual = _visualFor(entity);
      if (visual == null) {
        _appendScriptDrawings(widgets, entity, transform);
        continue;
      }
      widgets.add(
        SceneMesh(
          key: ValueKey<int>(entity),
          geometry: visual.$1,
          material: visual.$2,
          position: _scenePosition(transform),
        ),
      );
      _appendScriptDrawings(widgets, entity, transform);
    }
    return widgets;
  }

  Widget _portal(Entity entity, Transform3 transform) => SceneNode(
    key: ValueKey<String>('portal-${entity.id}'),
    name: 'portal-${entity.id}',
    position: _scenePosition(transform),
    rotation: vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      animationSeconds * 1.8 + entity.id,
    ),
    children: [
      SceneMesh(
        geometry: portalGeometry,
        material: arcaneEnergyMaterial ?? neonWallMaterial ?? wallRailMaterial,
        scale: vm.Vector3.all(1.15 + math.sin(animationSeconds * 4) * .08),
      ),
      SceneMesh(
        geometry: portalGeometry,
        material: irisMaterial,
        position: vm.Vector3(0, .16, 0),
        scale: vm.Vector3.all(.72),
      ),
    ],
  );

  Widget _spellPickup(Entity entity, Transform3 transform) => SceneNode(
    key: ValueKey<String>('spell-${entity.id}'),
    name: 'star-pulse-pickup',
    position: vm.Vector3(
      transform.x * sceneTileScale,
      transform.y + math.sin(animationSeconds * 4.5) * .12,
      transform.z * sceneTileScale,
    ),
    rotation: vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      animationSeconds * 2.5,
    ),
    children: [
      SceneMesh(
        geometry: portalGeometry,
        material: irisMaterial,
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
        scale: vm.Vector3.all(.55),
      ),
      SceneMesh(
        geometry: detailGeometry,
        material: arcaneEnergyMaterial ?? powerPelletMaterial,
        scale: vm.Vector3.all(1.35),
      ),
    ],
  );

  Widget _keyPickup(Entity entity, Transform3 transform) => SceneNode(
    key: ValueKey<String>('key-${entity.id}'),
    position: vm.Vector3(
      transform.x * sceneTileScale,
      transform.y + math.sin(animationSeconds * 4) * .1,
      transform.z * sceneTileScale,
    ),
    rotation: vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      animationSeconds * 2,
    ),
    children: [
      SceneMesh(
        geometry: portalGeometry,
        material: arcaneEnergyMaterial ?? pelletMaterial,
        scale: vm.Vector3.all(.48),
      ),
      SceneMesh(
        geometry: runeGeometry,
        material: pelletMaterial,
        position: vm.Vector3(.38, 0, 0),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
      ),
    ],
  );

  Widget _door(Entity entity, Transform3 transform) => SceneNode(
    key: ValueKey<String>('door-${entity.id}'),
    position: _scenePosition(transform),
    children: [
      SceneMesh(
        geometry: wallGeometry,
        material: neonWallMaterial ?? wallMaterial,
        position: vm.Vector3(0, .42, 0),
        scale: vm.Vector3(.88, 1.8, .28),
      ),
      SceneMesh(
        geometry: portalGeometry,
        material: pelletMaterial,
        position: vm.Vector3(0, .45, .18),
        scale: vm.Vector3.all(.35),
      ),
    ],
  );

  Widget _trap(Entity entity, Transform3 transform, TrapTag trap) => SceneNode(
    key: ValueKey<String>('trap-${entity.id}'),
    position: _scenePosition(transform),
    rotation: vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      animationSeconds * (trap.cooldown > 0 ? 8 : 1.2),
    ),
    children: [
      for (var index = 0; index < 4; index++)
        SceneMesh(
          geometry: runeGeometry,
          material: trap.cooldown > 0 ? rubyMaterial : irisMaterial,
          rotation: vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            index * math.pi / 2,
          ),
          position: vm.Vector3(
            math.cos(index * math.pi / 2) * .3,
            .05,
            math.sin(index * math.pi / 2) * .3,
          ),
        ),
    ],
  );

  Widget _spellPulse(Transform3 player) {
    final progress = 1 - game.state.spellPulseSeconds / .8;
    return SceneMesh(
      name: 'star-pulse-wave',
      geometry: portalGeometry,
      material: arcaneEnergyMaterial ?? neonWallMaterial ?? wallRailMaterial,
      position: vm.Vector3(
        player.x * sceneTileScale,
        .08,
        player.z * sceneTileScale,
      ),
      scale: vm.Vector3.all(1 + progress * 9),
    );
  }

  void _appendScriptDrawings(
    List<Widget> widgets,
    Entity entity,
    Transform3 transform,
  ) {
    final world = game.runtime.context.world;
    final drawings = world.maybeGet<ScriptDrawings>(entity);
    final emitters = world.maybeGet<ScriptParticleEmitters>(entity);
    if ((drawings == null || drawings.values.isEmpty) &&
        (emitters == null || emitters.values.isEmpty)) {
      return;
    }
    widgets.add(
      SceneNode(
        key: ValueKey<String>('script-drawings-${entity.id}'),
        name: 'script-drawings-${entity.id}',
        position: _scenePosition(transform),
        children: [
          if (drawings != null)
            for (final drawing in drawings.values.values)
              _scriptDrawing(entity, drawing),
          if (emitters != null)
            for (final emitter in emitters.values.values)
              ..._particleEmitter(entity, emitter),
        ],
      ),
    );
  }

  Widget _scriptDrawing(Entity entity, ScriptDrawing drawing) {
    final phase = animationSeconds * drawing.animationSpeed + entity.id * .71;
    var x = drawing.x;
    var y = drawing.y;
    var z = drawing.z;
    var scale = 1.0;
    var rotation = vm.Quaternion.identity();
    switch (drawing.animation) {
      case 'pulse':
        scale += math.sin(phase) * drawing.animationAmount;
        break;
      case 'orbit':
        x += math.cos(phase) * drawing.animationAmount;
        z += math.sin(phase) * drawing.animationAmount;
        break;
      case 'float':
        y += math.sin(phase) * drawing.animationAmount;
        break;
      case 'spin':
        rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), phase);
        break;
    }
    return SceneMesh(
      key: ValueKey<String>('${entity.id}-${drawing.name}'),
      name: drawing.name,
      geometry: drawing.shape == ScriptPrimitiveShape.sphere
          ? scriptSphereGeometry
          : scriptBoxGeometry,
      material: drawing.name == 'bolt' && arcaneEnergyMaterial != null
          ? arcaneEnergyMaterial!
          : _scriptMaterial(drawing.color),
      position: vm.Vector3(x, y, z),
      rotation: rotation,
      scale: vm.Vector3(
        drawing.scaleX * scale,
        drawing.scaleY * scale,
        drawing.scaleZ * scale,
      ),
    );
  }

  List<Widget> _particleEmitter(Entity entity, ScriptParticleEmitter emitter) =>
      [
        for (var index = 0; index < emitter.count; index++)
          _particle(entity, emitter, index),
      ];

  Widget _particle(Entity entity, ScriptParticleEmitter emitter, int index) {
    final seed = index * 2.399963229728653 + entity.id * .731;
    final cycle =
        (animationSeconds * emitter.speed + index / emitter.count) % 1.0;
    var x = 0.0;
    var y = .25;
    var z = 0.0;
    switch (emitter.pattern) {
      case 'fountain':
        final spread = emitter.radius * cycle;
        x = math.cos(seed) * spread;
        z = math.sin(seed) * spread;
        y = .1 + math.sin(cycle * math.pi) * emitter.radius * 1.8;
      case 'burst':
        final distance = emitter.radius * cycle;
        x = math.cos(seed) * distance;
        z = math.sin(seed) * distance;
        y = .35 + math.sin(seed * 1.7) * distance * .55;
      case 'trail':
        final distance = emitter.radius * cycle;
        final velocity = game.runtime.context.world.maybeGet<ScriptVelocity>(
          entity,
        );
        final length = velocity == null
            ? 1.0
            : math.max(
                .001,
                math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z),
              );
        final dx = velocity == null ? 0.0 : velocity.x / length;
        final dz = velocity == null ? 1.0 : velocity.z / length;
        final jitter = math.sin(seed * 3.1) * emitter.radius * .12;
        x = -dx * distance - dz * jitter;
        z = -dz * distance + dx * jitter;
        y = .2 + math.cos(seed * 2.3) * emitter.radius * .1;
      default:
        final angle = seed + animationSeconds * emitter.speed;
        x = math.cos(angle) * emitter.radius;
        z = math.sin(angle) * emitter.radius;
        y = .35 + math.sin(angle * 1.7 + seed) * emitter.radius * .35;
    }
    final fade = math.sin(cycle * math.pi).abs().clamp(.15, 1.0);
    return SceneMesh(
      key: ValueKey<String>('particle-${entity.id}-${emitter.name}-$index'),
      geometry: detailGeometry,
      material: _scriptMaterial(emitter.color),
      position: vm.Vector3(x, y, z),
      scale: vm.Vector3.all(emitter.size * fade / .12),
    );
  }

  UnlitMaterial _scriptMaterial(String source) =>
      scriptMaterials.putIfAbsent(source, () {
        final color = _scriptColor(source);
        return _material(color.r, color.g, color.b);
      });

  Color _scriptColor(String source) {
    final normalized = source.replaceFirst('#', '');
    final value = int.tryParse(
      normalized.length == 6 ? 'ff$normalized' : normalized,
      radix: 16,
    );
    return Color(value ?? 0xffffffff);
  }

  vm.Vector3 _scenePosition(Transform3 transform) => vm.Vector3(
    transform.x * sceneTileScale,
    transform.y,
    transform.z * sceneTileScale,
  );

  bool _isVisible(
    Transform3 transform,
    Transform3 player,
    double renderDistance,
  ) =>
      (transform.x - player.x).abs() <= renderDistance &&
      (transform.z - player.z).abs() <= renderDistance;

  Widget _heroine(Entity entity, Transform3 transform) {
    if (activeCameraMode == CameraMode.platformer) {
      return _nixCharacter(entity, transform);
    }
    final mover = game.runtime.context.world.get<GridMover>(entity);
    final moving = mover.direction != MoveDirection.none;
    final stride = moving ? math.sin(animationSeconds * 12) : 0.0;
    final mouthScale = .3 + (math.sin(animationSeconds * 14).abs() * .75);
    final blink = _blinkScale(animationSeconds, entity.id * .37);
    final eyeDart = math.sin(animationSeconds * .83) * .025;
    final browLift = math.sin(animationSeconds * 1.7) * .018;
    final cheekSquash = 1 + math.sin(animationSeconds * 14).abs() * .08;
    final facing = switch (mover.direction) {
      MoveDirection.right => math.pi / 2,
      MoveDirection.left => -math.pi / 2,
      MoveDirection.up => math.pi,
      _ => 0.0,
    };
    return SceneNode(
      key: ValueKey<int>(entity),
      name: 'heroine',
      position: vm.Vector3(
        transform.x * sceneTileScale,
        transform.y + stride.abs() * .035,
        transform.z * sceneTileScale,
      ),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), facing),
      children: [
        SceneMesh(geometry: playerGeometry, material: playerMaterial),
        SceneMesh(
          geometry: detailGeometry,
          material: pupilMaterial,
          position: vm.Vector3(0, -.09, .36),
          scale: vm.Vector3(1.05 - mouthScale * .12, mouthScale, .18),
        ),
        for (final x in const [-.28, .28])
          SceneMesh(
            geometry: detailGeometry,
            material: playerMaterial,
            position: vm.Vector3(x, -.055, .325),
            scale: vm.Vector3(.54 * cheekSquash, .45, .22),
          ),
        SceneMesh(
          geometry: detailGeometry,
          material: burgundyMaterial,
          position: vm.Vector3(-.36, -.08 + stride * .025, .02),
          scale: vm.Vector3(1.1, .9, .9),
        ),
        SceneMesh(
          geometry: detailGeometry,
          material: burgundyMaterial,
          position: vm.Vector3(.36, -.08 - stride * .025, .02),
          scale: vm.Vector3(1.1, .9, .9),
        ),
        SceneMesh(
          geometry: detailGeometry,
          material: burgundyMaterial,
          position: vm.Vector3(-.17, -.34, .02),
          scale: vm.Vector3(1.15, .7, 1.35),
        ),
        SceneMesh(
          geometry: detailGeometry,
          material: burgundyMaterial,
          position: vm.Vector3(.17, -.34, .02),
          scale: vm.Vector3(1.15, .7, 1.35),
        ),
        SceneMesh(
          geometry: detailGeometry,
          material: eyeMaterial,
          position: vm.Vector3(-.13, .1, .34),
          scale: vm.Vector3(.72, blink, .32),
          children: [
            SceneMesh(
              geometry: detailGeometry,
              material: pupilMaterial,
              position: vm.Vector3(eyeDart, 0, .11),
              scale: vm.Vector3(.35, .48, .18),
            ),
          ],
        ),
        SceneMesh(
          geometry: detailGeometry,
          material: eyeMaterial,
          position: vm.Vector3(.13, .1, .34),
          scale: vm.Vector3(.72, blink, .32),
          children: [
            SceneMesh(
              geometry: detailGeometry,
              material: pupilMaterial,
              position: vm.Vector3(eyeDart, 0, .11),
              scale: vm.Vector3(.35, .48, .18),
            ),
          ],
        ),
        for (final x in const [-.13, .13])
          SceneMesh(
            geometry: runeGeometry,
            material: burgundyMaterial,
            position: vm.Vector3(x, .245 + browLift, .35),
            rotation: vm.Quaternion.axisAngle(
              vm.Vector3(0, 0, 1),
              x < 0 ? -.18 : .18,
            ),
            scale: vm.Vector3(.95, .15, .25),
          ),
        SceneMesh(
          geometry: detailGeometry,
          material: tealMaterial,
          position: vm.Vector3(.17, .36, .02),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -.55),
          scale: vm.Vector3(1.7, .55, .7),
        ),
      ],
    );
  }

  Widget _nixCharacter(Entity entity, Transform3 transform) {
    final animation = game.runtime.context.world
        .maybeGet<ScriptComponents>(entity)
        ?.values['character_animation'];
    final state = animation?['state']?.toString() ?? 'idle';
    final facing = (animation?['facing'] as num?)?.toDouble() ?? 1;
    final cycle = math.sin(animationSeconds * 11);
    final running = state == 'run';
    final airborne = state == 'jump' || state == 'fall';
    final stride = running ? cycle * .58 : 0.0;
    final pose = CharacterPose({
      'hips': CharacterPartPose(
        y: running ? cycle.abs() * .035 : math.sin(animationSeconds * 2) * .018,
        rotationZ: running ? cycle * .045 : 0,
      ),
      'left_upper_arm': CharacterPartPose(rotationZ: airborne ? -.72 : stride),
      'right_upper_arm': CharacterPartPose(rotationZ: airborne ? .72 : -stride),
      'left_thigh': CharacterPartPose(rotationZ: airborne ? .3 : -stride),
      'right_thigh': CharacterPartPose(rotationZ: airborne ? -.3 : stride),
      'left_shin': CharacterPartPose(
        rotationZ: airborne ? -.42 : math.max(0, stride) * .55,
      ),
      'right_shin': CharacterPartPose(
        rotationZ: airborne ? .42 : math.max(0, -stride) * -.55,
      ),
      'cloak': CharacterPartPose(
        rotationX: running ? .1 + cycle.abs() * .08 : .04,
        z: running ? -.04 : 0,
      ),
      'moon_charm': CharacterPartPose(
        scale: 1 + math.sin(animationSeconds * 5) * .12,
      ),
    });
    return SceneNode(
      key: ValueKey<String>('nix-${entity.id}'),
      name: 'nix_actor',
      position: _scenePosition(transform),
      rotation: vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        facing >= 0 ? math.pi / 2 : -math.pi / 2,
      ),
      scale: vm.Vector3.all(.78),
      children: [
        ProceduralCharacter(
          spec: nixCharacterSpec,
          resources: nixResources,
          pose: pose,
        ),
      ],
    );
  }

  Widget _wallRun(Entity entity, Transform3 transform, WallRun run) {
    final wave = math.sin(
      animationSeconds * 2.6 + transform.x * .42 + transform.z * .31,
    );
    final energy = .88 + wave * .12;
    final firstPerson = activeCameraMode == CameraMode.firstPerson;
    final wallHeight = firstPerson ? 2.25 : 1.0;
    final wallCenterY = firstPerson ? .55 : transform.y;
    final topRailY = firstPerson ? 1.01 : .47;
    final sideRailY = firstPerson ? .38 : .08;
    final runWidth = run.length * sceneTileScale;
    return SceneNode(
      key: ValueKey<int>(entity),
      name: 'wall-run-${entity.id}',
      position: vm.Vector3(
        transform.x * sceneTileScale,
        wallCenterY,
        transform.z * sceneTileScale,
      ),
      children: [
        SceneMesh(
          geometry: wallGeometry,
          material: wallMaterial,
          scale: vm.Vector3(runWidth - .08, wallHeight, 1),
        ),
        for (final z in const [-.47, .47])
          SceneMesh(
            geometry: wallRailGeometry,
            material: neonWallMaterial ?? wallRailMaterial,
            position: vm.Vector3(0, sideRailY, z),
            scale: vm.Vector3(
              runWidth - .14,
              (firstPerson ? 1.4 : .42) * energy,
              .18,
            ),
          ),
        SceneMesh(
          geometry: wallRailGeometry,
          material: neonWallMaterial ?? wallRailMaterial,
          position: vm.Vector3(0, topRailY, 0),
          scale: vm.Vector3(runWidth - .03, energy, 1),
        ),
        for (final x in [-(runWidth - 1) / 2, (runWidth - 1) / 2])
          SceneNode(
            position: vm.Vector3(x, (firstPerson ? 1.32 : .18) + wave * .04, 0),
            rotation: vm.Quaternion.axisAngle(
              vm.Vector3(0, 1, 0),
              animationSeconds * 1.4 + x,
            ),
            children: [
              SceneMesh(
                geometry: runeGeometry,
                material: neonWallMaterial ?? wallRailMaterial,
                scale: vm.Vector3(energy, 1.8, energy),
              ),
              SceneMesh(
                geometry: detailGeometry,
                material: powerPelletMaterial,
                position: vm.Vector3(0, .38 + wave * .08, 0),
                scale: vm.Vector3.all(.45 + energy * .1),
              ),
            ],
          ),
      ],
    );
  }

  Widget _ghostCharacter(Entity entity, Transform3 transform) {
    final world = game.runtime.context.world;
    final profile = world.get<GhostProfile>(entity);
    final bodyMaterial = _ghostMaterial(profile.personality);
    final phase = animationSeconds * 7 + entity.id * .8;
    final bob = math.sin(phase) * .035;
    final wobble = math.sin(phase * .7) * .08;
    final blink = _blinkScale(animationSeconds, entity.id * 1.13);
    final player = world.get<Transform3>(game.player);
    final lookX = ((player.x - transform.x) * .035).clamp(-.045, .045);
    final lookY = ((player.z - transform.z) * .018).clamp(-.025, .025);
    final frightened = game.state.powerSeconds > 0;
    return SceneNode(
      key: ValueKey<int>(entity),
      name: 'ghost-${profile.name.toLowerCase()}',
      position: vm.Vector3(
        transform.x * sceneTileScale,
        transform.y + bob,
        transform.z * sceneTileScale,
      ),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), wobble),
      children: [
        SceneMesh(
          geometry: ghostGeometry,
          material: bodyMaterial,
          scale: vm.Vector3(1, .95, 1),
        ),
        for (final x in const [-.12, .12])
          SceneMesh(
            geometry: detailGeometry,
            material: eyeMaterial,
            position: vm.Vector3(x, .1, .34),
            scale: vm.Vector3(.65, blink * .9, .3),
            children: [
              SceneMesh(
                geometry: detailGeometry,
                material: pupilMaterial,
                position: vm.Vector3(lookX, -lookY, .11),
                scale: vm.Vector3(
                  frightened ? .22 : .32,
                  frightened ? .24 : .42,
                  .16,
                ),
              ),
            ],
          ),
        SceneMesh(
          geometry: detailGeometry,
          material: frightened ? eyeMaterial : pupilMaterial,
          position: vm.Vector3(0, -.105, .35),
          scale: frightened
              ? vm.Vector3(.72, .14, .14)
              : vm.Vector3(.42, .1 + math.sin(phase) * .035, .14),
        ),
        for (final x in const [-.24, 0.0, .24])
          SceneMesh(
            geometry: detailGeometry,
            material: bodyMaterial,
            position: vm.Vector3(x, -.31, 0),
            scale: vm.Vector3(1.1, .65, 1.15),
          ),
      ],
    );
  }

  double _blinkScale(double seconds, double phaseOffset) {
    final cycle = (seconds + phaseOffset) % 4.2;
    if (cycle < .08) return .12 + cycle / .08 * .88;
    if (cycle < .16) return .12 + (.16 - cycle) / .08 * .88;
    if (cycle > 2.3 && cycle < 2.38) {
      return .18 + (cycle - 2.3) / .08 * .82;
    }
    return 1;
  }

  Widget _bonusFruit(Entity entity, Transform3 transform) => SceneNode(
    key: ValueKey<int>(entity),
    name: 'bonus-fruit',
    position: vm.Vector3(
      transform.x * sceneTileScale,
      transform.y + math.sin(animationSeconds * 5) * .08,
      transform.z * sceneTileScale,
    ),
    rotation: vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      animationSeconds * 2.5,
    ),
    children: [
      SceneMesh(
        geometry: detailGeometry,
        material: fruitMaterial,
        position: vm.Vector3(-.1, 0, 0),
        scale: vm.Vector3(1.35, 1.35, 1.35),
      ),
      SceneMesh(
        geometry: detailGeometry,
        material: fruitMaterial,
        position: vm.Vector3(.1, 0, 0),
        scale: vm.Vector3(1.35, 1.35, 1.35),
      ),
      SceneMesh(
        geometry: detailGeometry,
        material: tealMaterial,
        position: vm.Vector3(0, .17, 0),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -.45),
        scale: vm.Vector3(.45, 1.1, .45),
      ),
    ],
  );

  Material _ghostMaterial(String personality) {
    if (game.state.powerSeconds > 0) {
      final blink =
          game.state.powerSeconds < 2 &&
          (game.state.powerSeconds * 8).floor().isEven;
      return blink ? frightenedBlinkMaterial : frightenedMaterial;
    }
    return switch (personality) {
      'chaser' => rubyMaterial,
      'ambusher' => saffronMaterial,
      'shy' => irisMaterial,
      _ => mintMaterial,
    };
  }

  (Geometry, Material)? _visualFor(Entity entity) {
    final world = game.runtime.context.world;
    final pellet = world.maybeGet<PelletTag>(entity);
    if (pellet != null) {
      return pellet.power
          ? (powerPelletGeometry, powerPelletMaterial)
          : (pelletGeometry, pelletMaterial);
    }
    return null;
  }
}

class _RuntimeInspector extends StatelessWidget {
  const _RuntimeInspector({required this.game});
  final MazeGame game;

  @override
  Widget build(BuildContext context) {
    final world = game.runtime.context.world;
    final paths = game.sceneTree.paths.toList()..sort();
    return Positioned(
      top: 96,
      right: 20,
      bottom: 210,
      width: 390,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xf208081c),
          border: Border.all(color: const Color(0xff31e7ff)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x7731e7ff), blurRadius: 24),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE SCENE TREE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xff31e7ff),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${world.entityCount} ECS',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'I CLOSES  •  LIVE LUA PROPERTIES',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: Colors.white38,
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: paths.length,
                  itemBuilder: (context, index) {
                    final path = paths[index];
                    final entity = game.sceneTree.getNode(path);
                    if (entity == null || !world.isAlive(entity)) {
                      return const SizedBox.shrink();
                    }
                    final groups = world.maybeGet<ScriptGroups>(entity);
                    final properties = world.maybeGet<ScriptProperties>(entity);
                    final scriptComponents = world.maybeGet<ScriptComponents>(
                      entity,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            path,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xffe9d8ff),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '#${entity.id}  ${_components(world, entity).join(' · ')}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xff31e7ff),
                            ),
                          ),
                          if (groups != null && groups.values.isNotEmpty)
                            Text(
                              'groups: ${groups.values.join(', ')}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          if (scriptComponents != null &&
                              scriptComponents.values.isNotEmpty)
                            Text(
                              'lua: ${scriptComponents.values.keys.join(', ')}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xffb35cff),
                              ),
                            ),
                          if (properties != null &&
                              properties.values.isNotEmpty)
                            Text(
                              properties.values.entries
                                  .take(6)
                                  .map((entry) => '${entry.key}=${entry.value}')
                                  .join('  '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white60,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _components(World world, Entity entity) => [
    if (world.has<Transform3>(entity)) 'Transform3',
    if (world.has<GridMover>(entity)) 'GridMover',
    if (world.has<PlayerTag>(entity)) 'Player',
    if (world.has<GhostTag>(entity)) 'Ghost',
    if (world.has<BossTag>(entity)) 'Boss',
    if (world.has<DoorTag>(entity)) 'Door',
    if (world.has<TrapTag>(entity)) 'Trap',
    if (world.has<ScriptProjectileTag>(entity)) 'Projectile',
    if (world.maybeGet<ScriptComponents>(entity) case final components?)
      ...components.values.keys.map((name) => 'Lua:$name'),
    if (world.has<ScriptDrawings>(entity)) 'Drawings',
    if (world.has<ScriptParticleEmitters>(entity)) 'Particles',
    if (world.has<ScriptHud>(entity)) 'Hud',
    if (world.has<ScriptProperties>(entity)) 'Properties',
  ];
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onExitToMenu});

  final VoidCallback onResume;
  final VoidCallback onExitToMenu;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0x9902020c),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xee08081c),
            border: Border.all(color: const Color(0xffb35cff), width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x8831e7ff), blurRadius: 32),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'WORLD SUSPENDED',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xff31e7ff),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'P / ESCAPE RESUME   •   M MAP SELECT',
                  style: TextStyle(letterSpacing: 2, color: Colors.white60),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: onResume,
                      child: const Text('RESUME'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: onExitToMenu,
                      child: const Text('MAP SELECT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xcc08081c),
      border: Border.all(color: const Color(0xff31e7ff).withValues(alpha: .6)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
      ),
    ),
  );
}

class _HeroinePortrait extends StatelessWidget {
  const _HeroinePortrait();

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xff08081c),
      border: Border.all(color: const Color(0xff31e7ff), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x6631e7ff), blurRadius: 16)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      'assets/images/heroine-portrait-v2.png',
      fit: BoxFit.cover,
    ),
  );
}

class _GameStateOverlay extends StatelessWidget {
  const _GameStateOverlay({
    required this.phase,
    required this.score,
    required this.hasNextLevel,
    required this.isPlatformer,
  });
  final GamePhase phase;
  final int score;
  final bool hasNextLevel;
  final bool isPlatformer;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xaa02020c),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xee08081c),
            border: Border.all(color: const Color(0xff31e7ff), width: 2),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x8831e7ff), blurRadius: 32),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  phase == GamePhase.won
                      ? isPlatformer
                            ? hasNextLevel
                                  ? 'CHAPTER COMPLETE'
                                  : 'THE MOON RESTORED'
                            : 'MAZE CLEARED'
                      : 'GAME OVER',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xff31e7ff),
                  ),
                ),
                const SizedBox(height: 12),
                if (phase == GamePhase.won && isPlatformer && !hasNextLevel)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      width: 480,
                      child: Text(
                        'Nix delivers the final moon-note. The inverted rain turns to starlight, and every lost road home appears again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.5, color: Colors.white70),
                      ),
                    ),
                  ),
                Text(
                  'SCORE ${score.toString().padLeft(5, '0')}',
                  style: const TextStyle(fontSize: 18, letterSpacing: 3),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ENTER / SPACE',
                  style: TextStyle(letterSpacing: 2, color: Colors.white60),
                ),
                if (phase == GamePhase.won && hasNextLevel)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'ENTER THE NEXT REALM',
                      style: TextStyle(
                        letterSpacing: 2,
                        color: Color(0xff31e7ff),
                      ),
                    ),
                  ),
                if (phase == GamePhase.won && !hasNextLevel)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'ENTER TO RETURN TO THE CHAPTER MAP',
                      style: TextStyle(
                        letterSpacing: 2,
                        color: Color(0xffffd45c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StoryBanner extends StatelessWidget {
  const _StoryBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 32,
    right: 32,
    top: 112,
    child: IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xdd08081c),
            border: Border.all(color: const Color(0xffb35cff)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x7731e7ff), blurRadius: 24),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Color(0xffe9d8ff),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _CrosshairPainter()),
    ),
  );
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xaa31e7ff)
      ..strokeWidth = 1.5;
    final center = size.center(Offset.zero);
    canvas.drawLine(
      center - const Offset(8, 0),
      center - const Offset(3, 0),
      paint,
    );
    canvas.drawLine(
      center + const Offset(3, 0),
      center + const Offset(8, 0),
      paint,
    );
    canvas.drawLine(
      center - const Offset(0, 8),
      center - const Offset(0, 3),
      paint,
    );
    canvas.drawLine(
      center + const Offset(0, 3),
      center + const Offset(0, 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapOverlay extends StatelessWidget {
  const _MapOverlay({required this.game, required this.cameraMode});
  final MazeGame game;
  final CameraMode cameraMode;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xdd03030d),
        border: Border.all(color: const Color(0xaa31e7ff)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x5531e7ff), blurRadius: 18)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 220,
          height: 140,
          child: CustomPaint(painter: _MazeMapPainter(game, cameraMode)),
        ),
      ),
    ),
  );
}

class _MazeMapPainter extends CustomPainter {
  _MazeMapPainter(this.game, this.cameraMode);
  final MazeGame game;
  final CameraMode cameraMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (cameraMode == CameraMode.platformer) {
      _paintPlatformer(canvas, size);
      return;
    }
    final maze = game.maze;
    final scale = math.min(size.width / maze.width, size.height / maze.height);
    final origin = Offset(
      (size.width - maze.width * scale) / 2,
      (size.height - maze.height * scale) / 2,
    );
    final wallPaint = Paint()..color = const Color(0xff12377a);
    final edgePaint = Paint()
      ..color = const Color(0xff31e7ff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.5, scale * .08);
    for (var y = 0; y < maze.height; y++) {
      for (var x = 0; x < maze.width; x++) {
        if (!maze.isWall(x, y)) continue;
        final cell = Rect.fromLTWH(
          origin.dx + x * scale,
          origin.dy + y * scale,
          scale,
          scale,
        );
        canvas.drawRect(cell, wallPaint);
        canvas.drawRect(cell, edgePaint);
      }
    }

    final world = game.runtime.context.world;
    final sparkPaint = Paint()..color = const Color(0xffffd45c);
    for (final (_, transform, pellet)
        in world.query2<Transform3, PelletTag>()) {
      canvas.drawCircle(
        _point(origin, scale, transform),
        pellet.power ? scale * .19 : math.max(1, scale * .08),
        sparkPaint,
      );
    }
    final ghostPaint = Paint()..color = const Color(0xffff3970);
    for (final (_, transform, _) in world.query2<Transform3, GhostTag>()) {
      canvas.drawCircle(
        _point(origin, scale, transform),
        math.max(2, scale * .23),
        ghostPaint,
      );
    }
    final keyPaint = Paint()..color = const Color(0xffffd45c);
    for (final (_, transform, _) in world.query2<Transform3, KeyPickupTag>()) {
      canvas.drawCircle(
        _point(origin, scale, transform),
        math.max(2, scale * .2),
        keyPaint,
      );
    }
    final doorPaint = Paint()..color = const Color(0xffb35cff);
    for (final (_, transform, door) in world.query2<Transform3, DoorTag>()) {
      if (door.open) continue;
      final point = _point(origin, scale, transform);
      canvas.drawRect(
        Rect.fromCenter(
          center: point,
          width: math.max(2, scale * .65),
          height: math.max(2, scale * .65),
        ),
        doorPaint,
      );
    }
    final trapPaint = Paint()..color = const Color(0xffff6d3a);
    for (final (_, transform, trap) in world.query2<Transform3, TrapTag>()) {
      if (!trap.active) continue;
      final point = _point(origin, scale, transform);
      canvas.drawLine(
        point - Offset(scale * .2, scale * .2),
        point + Offset(scale * .2, scale * .2),
        trapPaint,
      );
      canvas.drawLine(
        point + Offset(scale * .2, -scale * .2),
        point + Offset(-scale * .2, scale * .2),
        trapPaint,
      );
    }

    final player = world.get<Transform3>(game.player);
    final center = _point(origin, scale, player);
    final facing = cameraMode == CameraMode.firstPerson
        ? game.firstPersonFacing
        : world.get<GridMover>(game.player).direction;
    final direction = Offset(facing.dx.toDouble(), facing.dy.toDouble());
    final normalized = direction.distance == 0
        ? const Offset(0, -1)
        : direction / direction.distance;
    final side = Offset(-normalized.dy, normalized.dx);
    final radius = math.max(3.5, scale * .38);
    final marker = Path()
      ..moveTo(
        center.dx + normalized.dx * radius,
        center.dy + normalized.dy * radius,
      )
      ..lineTo(
        center.dx - normalized.dx * radius * .65 + side.dx * radius * .65,
        center.dy - normalized.dy * radius * .65 + side.dy * radius * .65,
      )
      ..lineTo(
        center.dx - normalized.dx * radius * .65 - side.dx * radius * .65,
        center.dy - normalized.dy * radius * .65 - side.dy * radius * .65,
      )
      ..close();
    canvas.drawPath(marker, Paint()..color = const Color(0xffffffff));
  }

  void _paintPlatformer(Canvas canvas, Size size) {
    final world = game.runtime.context.world;
    const padding = 9.0;
    final width = math.max(1, game.maze.width - 1);
    Offset point(Transform3 transform) => Offset(
      padding + transform.x / width * (size.width - padding * 2),
      size.height -
          padding -
          ((transform.y + 3) / 11).clamp(0, 1) * (size.height - padding * 2),
    );

    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      Paint()
        ..color = const Color(0x8831e7ff)
        ..strokeWidth = 2,
    );
    for (final (_, transform, components)
        in world.query2<Transform3, ScriptComponents>()) {
      final center = point(transform);
      if (components.values.containsKey('platform')) {
        final platform = components.values['platform']!;
        final platformWidth =
            ((platform['width'] as num?)?.toDouble() ?? 2) /
            width *
            (size.width - padding * 2);
        canvas.drawLine(
          center - Offset(platformWidth / 2, 0),
          center + Offset(platformWidth / 2, 0),
          Paint()
            ..color = const Color(0xff31e7ff)
            ..strokeWidth = 3,
        );
      } else if (components.values.containsKey('crystal')) {
        canvas.drawCircle(center, 3, Paint()..color = const Color(0xffffd45c));
      } else if (components.values.containsKey('hazard')) {
        canvas.drawCircle(center, 3, Paint()..color = const Color(0xffff3970));
      } else if (components.values.containsKey('checkpoint')) {
        canvas.drawCircle(center, 4, Paint()..color = const Color(0xffb35cff));
      } else if (components.values.containsKey('platform_enemy')) {
        canvas.drawCircle(center, 4, Paint()..color = const Color(0xffff6d3a));
      } else if (components.values.containsKey('exit_gate')) {
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 5, height: 10),
          Paint()..color = const Color(0xff8dffef),
        );
      }
    }
    final player = point(world.get<Transform3>(game.player));
    canvas.drawCircle(player, 5, Paint()..color = const Color(0xffffffff));
    canvas.drawCircle(
      player,
      7,
      Paint()
        ..color = const Color(0xff31e7ff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  Offset _point(Offset origin, double scale, Transform3 transform) => Offset(
    origin.dx + (transform.x + .5) * scale,
    origin.dy + (transform.z + .5) * scale,
  );

  @override
  bool shouldRepaint(covariant _MazeMapPainter oldDelegate) => true;
}
