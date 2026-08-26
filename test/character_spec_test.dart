import 'package:flutter_test/flutter_test.dart';
import 'package:node/generated/nix_character.g.dart';

void main() {
  test('generated Nix character spec is structurally valid', () {
    expect(nixCharacterSpec.validate(), isEmpty);
    expect(nixCharacterSpec.parts, hasLength(32));
    expect(
      nixCharacterSpec.parts.map((part) => part.name),
      containsAll([
        'hips',
        'head',
        'left_upper_arm',
        'right_upper_arm',
        'left_boot',
        'right_boot',
        'moon_charm',
      ]),
    );
  });

  test('generated hierarchy exposes animation-ready named joints', () {
    final parts = {for (final part in nixCharacterSpec.parts) part.name: part};

    expect(parts['left_forearm']!.parent, 'left_upper_arm');
    expect(parts['left_hand']!.parent, 'left_forearm');
    expect(parts['right_shin']!.parent, 'right_thigh');
    expect(parts['right_boot']!.parent, 'right_shin');
    expect(parts['left_pupil']!.parent, 'left_iris');
  });
}
