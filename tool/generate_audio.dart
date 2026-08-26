import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

typedef Sample = double Function(double time);

void main() {
  final output = Directory('assets/audio')..createSync(recursive: true);
  _write(
    output,
    'jump.wav',
    .34,
    (t) => _tone(t, 260 + t * 620) * _fade(t, .34),
  );
  _write(
    output,
    'bolt.wav',
    .24,
    (t) =>
        (_tone(t, 740 - t * 900) + _tone(t, 1480 - t * 1200) * .3) *
        _fade(t, .24),
  );
  _write(
    output,
    'collect.wav',
    .5,
    (t) =>
        (_tone(
          t,
          t < .16
              ? 660
              : t < .32
              ? 880
              : 1320,
        ) *
        _fade(t, .5)),
  );
  _write(
    output,
    'hurt.wav',
    .42,
    (t) => (_tone(t, 150 - t * 110) + _noise(t) * .35) * _fade(t, .42),
  );
  _write(
    output,
    'checkpoint.wav',
    .9,
    (t) =>
        (_tone(t, 440) + _tone(t, 660) * .55 + _tone(t, 990) * .25) *
        _fade(t, .9),
  );
  _write(output, 'victory.wav', 2.2, (t) {
    const notes = [392.0, 523.25, 659.25, 783.99, 1046.5];
    final note = notes[(t / .4).floor().clamp(0, notes.length - 1)];
    return (_tone(t, note) + _tone(t, note / 2) * .35) * _fade(t % .4, .42);
  });
  _write(output, 'moonfall_ambience.wav', 8, (t) {
    final pad =
        _tone(t, 110) * .18 + _tone(t, 164.81) * .12 + _tone(t, 220) * .08;
    final shimmer =
        _tone(t, 880 + math.sin(t * .37) * 18) *
        (.025 + .02 * math.sin(t * .9));
    return (pad + shimmer) * math.min(1, math.min(t, 8 - t) / .7);
  });
}

double _tone(double time, double frequency) =>
    math.sin(time * frequency * math.pi * 2);

double _noise(double time) {
  final value = math.sin(time * 12345.678) * 43758.5453;
  return (value - value.floor()) * 2 - 1;
}

double _fade(double time, double duration) {
  final attack = (time / .025).clamp(0, 1);
  final release = ((duration - time) / (duration * .55)).clamp(0, 1);
  return (attack * release).toDouble();
}

void _write(Directory output, String name, double duration, Sample sample) {
  const sampleRate = 22050;
  final count = (sampleRate * duration).round();
  final dataSize = count * 2;
  final bytes = ByteData(44 + dataSize);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVEfmt ');
  bytes
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var index = 0; index < count; index++) {
    final value = (sample(index / sampleRate) * .42).clamp(-1, 1);
    bytes.setInt16(44 + index * 2, (value * 32767).round(), Endian.little);
  }
  File('${output.path}/$name').writeAsBytesSync(bytes.buffer.asUint8List());
}
