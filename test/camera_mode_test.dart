import 'package:flutter_test/flutter_test.dart';
import 'package:node/game/level.dart';
import 'package:node/main.dart';

void main() {
  test('platformer view toggle never enters maze control cameras', () {
    final tactical = nextCameraMode(
      CameraMode.platformer,
      CameraMode.platformer,
    );
    final restored = nextCameraMode(tactical, CameraMode.platformer);

    expect(tactical, CameraMode.follow);
    expect(restored, CameraMode.platformer);
  });

  test('maze view toggle still alternates follow and first person', () {
    expect(
      nextCameraMode(CameraMode.follow, CameraMode.follow),
      CameraMode.firstPerson,
    );
    expect(
      nextCameraMode(CameraMode.firstPerson, CameraMode.follow),
      CameraMode.follow,
    );
  });
}
