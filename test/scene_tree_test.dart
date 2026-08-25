import 'package:flutter_test/flutter_test.dart';
import 'package:node/engine/scene_tree.dart';
import 'package:node/engine/world.dart';

void main() {
  test('scene tree resolves normalized Godot-style node paths', () {
    final world = World();
    final player = world.create();
    final tree = SceneTree()..register('/root/player/', player);

    expect(tree.getNode('player'), player);
    expect(tree.getNode('//root//player'), player);
    expect(tree.pathOf(player), '/root/player');
    expect(tree.hasNode('/root/missing'), isFalse);
  });
}
