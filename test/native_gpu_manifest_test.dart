import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native manifests opt into Flutter GPU', () {
    expect(
      File('macos/Runner/Info.plist').readAsStringSync(),
      contains('<key>FLTEnableFlutterGPU</key>\n\t<true/>'),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('<key>FLTEnableFlutterGPU</key>\n\t<true/>'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('io.flutter.embedding.android.EnableFlutterGPU'),
    );
  });
}
