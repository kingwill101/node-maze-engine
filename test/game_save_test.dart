import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/game_save.dart';

void main() {
  test('campaign progress serializes and never relocks later chapters', () {
    final save = GameSaveData(reducedMotion: true);

    save.completeChapter('moonfall_courier', 0, 3);
    save.completeChapter('moonfall_courier', 1, 3);
    save.completeChapter('moonfall_courier', 0, 3);

    expect(save.unlockedChapter('moonfall_courier'), 2);
    expect(save.isCompleted('moonfall_courier', 0), isTrue);
    expect(save.isCompleted('moonfall_courier', 1), isTrue);

    final restored = GameSaveData.fromJson(save.toJson());
    expect(restored.unlockedChapter('moonfall_courier'), 2);
    expect(restored.completedChapters, save.completedChapters);
    expect(restored.reducedMotion, isTrue);
  });
}
