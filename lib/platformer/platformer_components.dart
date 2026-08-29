import '../engine/entity.dart';

class PlatformerBody {
  PlatformerBody({
    this.moveSpeed = 5.2,
    this.jumpSpeed = 6.8,
    this.gravity = 14.5,
    this.halfWidth = .28,
    this.halfHeight = .45,
    required this.checkpointX,
    required this.checkpointY,
  });

  final double moveSpeed;
  final double jumpSpeed;
  final double gravity;
  final double halfWidth;
  final double halfHeight;
  double checkpointX;
  double checkpointY;
  double velocityY = 0;
  bool grounded = false;
  Entity? groundedPlatform;
  int respawnCount = 0;
}
