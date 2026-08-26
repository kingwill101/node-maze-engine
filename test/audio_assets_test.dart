import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('procedural Moonfall audio assets are valid PCM wave files', () {
    for (final name in [
      'jump',
      'bolt',
      'collect',
      'hurt',
      'checkpoint',
      'victory',
      'moonfall_ambience',
    ]) {
      final bytes = File('assets/audio/$name.wav').readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF', reason: name);
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE', reason: name);
      expect(bytes.length, greaterThan(1000), reason: name);
    }
  });
}
