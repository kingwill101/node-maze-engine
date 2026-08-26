import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GameSaveData {
  GameSaveData({
    Map<String, int>? unlockedChapters,
    Set<String>? completedChapters,
    this.reducedMotion = false,
    this.highContrast = false,
  }) : unlockedChapters = Map.of(unlockedChapters ?? const {}),
       completedChapters = Set.of(completedChapters ?? const {});

  final Map<String, int> unlockedChapters;
  final Set<String> completedChapters;
  bool reducedMotion;
  bool highContrast;

  int unlockedChapter(String gameId) => unlockedChapters[gameId] ?? 0;

  bool isCompleted(String gameId, int chapter) =>
      completedChapters.contains('$gameId:$chapter');

  void completeChapter(String gameId, int chapter, int chapterCount) {
    completedChapters.add('$gameId:$chapter');
    final next = (chapter + 1).clamp(0, chapterCount - 1);
    final current = unlockedChapters[gameId] ?? 0;
    unlockedChapters[gameId] = next > current ? next : current;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'unlocked_chapters': unlockedChapters,
    'completed_chapters': completedChapters.toList()..sort(),
    'reduced_motion': reducedMotion,
    'high_contrast': highContrast,
  };

  factory GameSaveData.fromJson(Map<String, Object?> json) => GameSaveData(
    unlockedChapters: {
      for (final entry
          in (json['unlocked_chapters'] as Map<Object?, Object?>? ?? {})
              .entries)
        entry.key.toString(): (entry.value as num).toInt(),
    },
    completedChapters: {
      for (final value in (json['completed_chapters'] as List<Object?>? ?? []))
        value.toString(),
    },
    reducedMotion: json['reduced_motion'] == true,
    highContrast: json['high_contrast'] == true,
  );
}

abstract interface class GameSaveStore {
  Future<GameSaveData> load();
  Future<void> save(GameSaveData data);
}

class SharedPreferencesGameSaveStore implements GameSaveStore {
  SharedPreferencesGameSaveStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const saveKey = 'node_game_center.save.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<GameSaveData> load() async {
    final source = await _preferences.getString(saveKey);
    if (source == null) return GameSaveData();
    try {
      return GameSaveData.fromJson(jsonDecode(source) as Map<String, Object?>);
    } on Object {
      return GameSaveData();
    }
  }

  @override
  Future<void> save(GameSaveData data) =>
      _preferences.setString(saveKey, jsonEncode(data.toJson()));
}
