import 'package:flutter_test/flutter_test.dart';
import 'package:node/scene/moonfall_environment.dart';

void main() {
  test('parallax layers move at distinct camera-relative rates', () {
    const playerX = 10.0;

    final sky = moonfallParallaxOffset(playerX, .02);
    final moon = moonfallParallaxOffset(playerX, .06);
    final islands = moonfallParallaxOffset(playerX, .14);
    final ruins = moonfallParallaxOffset(playerX, .34);
    final atmosphere = moonfallParallaxOffset(playerX, .58);
    final foreground = moonfallParallaxOffset(playerX, 1.08);

    expect(sky, greaterThan(moon));
    expect(moon, greaterThan(islands));
    expect(islands, greaterThan(ruins));
    expect(ruins, greaterThan(atmosphere));
    expect(foreground, lessThan(0));
  });
}
