import 'package:audioplayers/audioplayers.dart';

enum GameAudioCue { jump, bolt, collect, hurt, checkpoint, victory }

class GameAudio {
  GameAudio({required this.enabled})
    : _effects = List.generate(4, (_) => AudioPlayer());

  bool enabled;
  final AudioPlayer _ambience = AudioPlayer();
  final List<AudioPlayer> _effects;
  int _nextEffect = 0;

  Future<void> startMoonfallAmbience() async {
    if (!enabled) return;
    try {
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.setVolume(.2);
      await _ambience.play(AssetSource('audio/moonfall_ambience.wav'));
    } on Object {
      // Browsers may defer audio until their first accepted user gesture.
    }
  }

  Future<void> play(GameAudioCue cue) async {
    if (!enabled) return;
    final player = _effects[_nextEffect++ % _effects.length];
    try {
      await player.stop();
      await player.setVolume(cue == GameAudioCue.hurt ? .65 : .5);
      await player.play(AssetSource('audio/${cue.name}.wav'));
    } on Object {
      // Audio is enhancement-only; gameplay must continue if a backend rejects it.
    }
  }

  Future<void> dispose() async {
    await _ambience.dispose();
    for (final player in _effects) {
      await player.dispose();
    }
  }
}
