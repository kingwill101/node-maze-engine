import 'dart:async';

import 'package:scene/physics.dart' as physics;
import 'package:vector_math/vector_math.dart';

import '../engine/app.dart';
import '../engine/core_plugins.dart';
import '../engine/entity.dart';
import '../engine/plugin.dart';
import '../engine/resources.dart';
import '../engine/runtime.dart';
import '../engine/schedule.dart';

/// Backend-neutral body configuration. Dynamic bodies require a solver backend.
class PhysicsBody3d {
  PhysicsBody3d({
    this.kind = physics.BodyType.fixed,
    this.mass,
    Vector3? linearVelocity,
    Vector3? angularVelocity,
    this.linearDamping = 0,
    this.angularDamping = 0,
    this.gravityScale = 1,
    this.continuousCollisionDetection = false,
    Vector3? linearAxisFactor,
    Vector3? angularAxisFactor,
  }) : linearVelocity = linearVelocity ?? Vector3.zero(),
       angularVelocity = angularVelocity ?? Vector3.zero(),
       linearAxisFactor = linearAxisFactor ?? Vector3.all(1),
       angularAxisFactor = angularAxisFactor ?? Vector3.all(1);

  final physics.BodyType kind;
  final double? mass;
  final Vector3 linearVelocity;
  final Vector3 angularVelocity;
  final double linearDamping;
  final double angularDamping;
  final double gravityScale;
  final bool continuousCollisionDetection;
  final Vector3 linearAxisFactor;
  final Vector3 angularAxisFactor;
}

/// Collision geometry attached to an entity body.
class PhysicsCollider3d {
  PhysicsCollider3d({
    required this.shape,
    this.material = physics.PhysicsMaterial.defaultMaterial,
    this.isTrigger = false,
    Matrix4? localPose,
    this.layer = 0xFFFFFFFF,
    this.mask = 0xFFFFFFFF,
  }) : localPose = localPose ?? Matrix4.identity();

  PhysicsCollider3d.box(
    Vector3 halfExtents, {
    physics.PhysicsMaterial material = physics.PhysicsMaterial.defaultMaterial,
    bool isTrigger = false,
    Matrix4? localPose,
    int layer = 0xFFFFFFFF,
    int mask = 0xFFFFFFFF,
  }) : this(
         shape: physics.BoxShape(halfExtents: halfExtents),
         material: material,
         isTrigger: isTrigger,
         localPose: localPose,
         layer: layer,
         mask: mask,
       );

  PhysicsCollider3d.sphere(
    double radius, {
    physics.PhysicsMaterial material = physics.PhysicsMaterial.defaultMaterial,
    bool isTrigger = false,
    Matrix4? localPose,
    int layer = 0xFFFFFFFF,
    int mask = 0xFFFFFFFF,
  }) : this(
         shape: physics.SphereShape(radius: radius),
         material: material,
         isTrigger: isTrigger,
         localPose: localPose,
         layer: layer,
         mask: mask,
       );

  final physics.Shape shape;
  final physics.PhysicsMaterial material;
  final bool isTrigger;
  final Matrix4 localPose;
  final int layer;
  final int mask;
}

enum PhysicsContactPhase { began, ended, triggerEntered, triggerExited }

class PhysicsContactEvent {
  const PhysicsContactEvent({
    required this.phase,
    required this.entityA,
    required this.entityB,
    this.contacts = const [],
  });

  final PhysicsContactPhase phase;
  final Entity entityA;
  final Entity entityB;
  final List<physics.ContactPoint> contacts;
}

class PhysicsRayHit {
  const PhysicsRayHit({
    required this.entity,
    required this.point,
    required this.normal,
    required this.distance,
  });

  final Entity entity;
  final Vector3 point;
  final Vector3 normal;
  final double distance;
}

/// ECS-facing owner and query interface for a Flutter Scene physics backend.
class PhysicsRuntime implements DisposableResource {
  PhysicsRuntime(this.simulation, this.context) {
    _collisionSubscription = simulation.collisions.listen(_onCollision);
  }

  final physics.PhysicsSimulation simulation;
  final EngineContext context;
  final Map<Entity, _PhysicsRegistration> _registrations = {};
  final Map<int, Entity> _colliderEntities = {};
  late final StreamSubscription<physics.SimCollisionEvent>
  _collisionSubscription;

  String get backendName => simulation.backendName;

  PhysicsRayHit? raycast(
    Vector3 origin,
    Vector3 direction, {
    double maxDistance = double.infinity,
    int layerMask = 0xFFFFFFFF,
    bool includeTriggers = false,
  }) {
    final hit = simulation.raycast(
      Ray.originDirection(origin, direction.normalized()),
      maxDistance: maxDistance,
      layerMask: layerMask,
      includeTriggers: includeTriggers,
    );
    return hit == null ? null : _rayHit(hit);
  }

  List<PhysicsRayHit> raycastAll(
    Vector3 origin,
    Vector3 direction, {
    double maxDistance = double.infinity,
    int layerMask = 0xFFFFFFFF,
    bool includeTriggers = false,
  }) => simulation
      .raycastAll(
        Ray.originDirection(origin, direction.normalized()),
        maxDistance: maxDistance,
        layerMask: layerMask,
        includeTriggers: includeTriggers,
      )
      .map(_rayHit)
      .toList(growable: false);

  List<Entity> overlapSphere(
    Vector3 center,
    double radius, {
    int layerMask = 0xFFFFFFFF,
    bool includeTriggers = false,
  }) => simulation
      .overlapSphere(
        center,
        radius,
        layerMask: layerMask,
        includeTriggers: includeTriggers,
      )
      .map((hit) => _colliderEntities[hit.colliderHandle])
      .whereType<Entity>()
      .toSet()
      .toList(growable: false);

  List<Entity> overlapBox(
    Vector3 center,
    Vector3 halfExtents, {
    Quaternion? rotation,
    int layerMask = 0xFFFFFFFF,
    bool includeTriggers = false,
  }) => simulation
      .overlapBox(
        center,
        halfExtents,
        rotation ?? Quaternion.identity(),
        layerMask: layerMask,
        includeTriggers: includeTriggers,
      )
      .map((hit) => _colliderEntities[hit.colliderHandle])
      .whereType<Entity>()
      .toSet()
      .toList(growable: false);

  PhysicsRayHit? shapeCast(
    physics.Shape shape,
    Matrix4 from,
    Vector3 direction,
    double distance, {
    int layerMask = 0xFFFFFFFF,
    bool includeTriggers = false,
  }) {
    final hit = simulation.shapeCast(
      shape,
      from,
      direction.normalized(),
      distance,
      layerMask: layerMask,
      includeTriggers: includeTriggers,
    );
    return hit == null ? null : _rayHit(hit);
  }

  void setLinearVelocity(Entity entity, Vector3 velocity) {
    final registration = _requireRegistration(entity);
    registration.body?.linearVelocity.setFrom(velocity);
    simulation.setBodyLinearVelocity(registration.bodyHandle, velocity);
  }

  Vector3 linearVelocity(Entity entity) => simulation.readBodyLinearVelocity(
    _requireRegistration(entity).bodyHandle,
  );

  void applyImpulse(Entity entity, Vector3 impulse, {Vector3? atWorldPoint}) {
    simulation.applyImpulse(
      _requireRegistration(entity).bodyHandle,
      impulse,
      atWorldPoint: atWorldPoint,
    );
  }

  void applyForce(Entity entity, Vector3 force, {Vector3? atWorldPoint}) =>
      simulation.applyForce(
        _requireRegistration(entity).bodyHandle,
        force,
        atWorldPoint: atWorldPoint,
      );

  _PhysicsRegistration _requireRegistration(Entity entity) =>
      _registrations[entity] ??
      (throw StateError('$entity has no registered physics body'));

  PhysicsRayHit _rayHit(physics.SimRaycastHit hit) => PhysicsRayHit(
    entity: _colliderEntities[hit.colliderHandle]!,
    point: hit.worldPoint,
    normal: hit.worldNormal,
    distance: hit.distance,
  );

  void _onCollision(physics.SimCollisionEvent event) {
    final a = _colliderEntities[event.colliderHandleA];
    final b = _colliderEntities[event.colliderHandleB];
    if (a == null || b == null) return;
    final phase = switch (event) {
      physics.SimCollisionBegan() => PhysicsContactPhase.began,
      physics.SimCollisionEnded() => PhysicsContactPhase.ended,
      physics.SimTriggerEntered() => PhysicsContactPhase.triggerEntered,
      physics.SimTriggerExited() => PhysicsContactPhase.triggerExited,
    };
    context.events.emit(
      PhysicsContactEvent(
        phase: phase,
        entityA: a,
        entityB: b,
        contacts: event is physics.SimCollisionBegan
            ? event.contacts
            : const [],
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _collisionSubscription.cancel();
    simulation.dispose();
    _registrations.clear();
    _colliderEntities.clear();
  }
}

class PhysicsPlugin implements GamePlugin {
  PhysicsPlugin({physics.PhysicsSimulation? simulation})
    : simulation = simulation ?? physics.BasicSimulation();

  final physics.PhysicsSimulation simulation;

  @override
  String get name => 'node.physics';

  @override
  void build(GameApp app) {
    simulation.fixedTimestep = app.fixedDelta;
    final runtime = PhysicsRuntime(simulation, app.context);
    app
      ..addPlugin(const TransformPlugin())
      ..insertResource(runtime)
      ..addSystem(
        ScheduleLabel.fixedPreUpdate,
        const _PhysicsSyncSystem(),
        label: 'physics.sync',
      )
      ..addSystem(
        ScheduleLabel.fixedUpdate,
        const _PhysicsStepSystem(),
        label: 'physics.step',
      )
      ..addSystem(
        ScheduleLabel.postUpdate,
        const _PhysicsInterpolationSystem(),
        label: 'physics.interpolate',
        before: const {'transform.propagate'},
      );
  }
}

class _PhysicsSyncSystem implements EngineSystem {
  const _PhysicsSyncSystem();

  @override
  void update(EngineContext context, double deltaSeconds) {
    final runtime = context.resources.get<PhysicsRuntime>();
    final desired = <Entity>{
      for (final (entity, _) in context.world.query<PhysicsCollider3d>())
        entity,
    };
    for (final entity in runtime._registrations.keys.toList()) {
      if (!desired.contains(entity) || !context.world.isAlive(entity)) {
        _unregister(runtime, entity);
      }
    }
    for (final entity in desired) {
      final collider = context.world.get<PhysicsCollider3d>(entity);
      final body = context.world.maybeGet<PhysicsBody3d>(entity);
      final existing = runtime._registrations[entity];
      if (existing == null ||
          !identical(existing.collider, collider) ||
          !identical(existing.body, body)) {
        if (existing != null) _unregister(runtime, entity);
        _register(runtime, entity, body, collider);
      } else if (body?.kind == physics.BodyType.kinematic) {
        final pose = existing.target;
        runtime.simulation.setBodyKinematicTargetPose(
          existing.bodyHandle,
          pose.worldTranslation,
          pose.worldRotation,
        );
      }
    }
  }

  void _register(
    PhysicsRuntime runtime,
    Entity entity,
    PhysicsBody3d? body,
    PhysicsCollider3d collider,
  ) {
    final target = _EcsPoseTarget(runtime.context, entity);
    final bodyHandle = runtime.simulation.createBody(
      target: target,
      type: body?.kind ?? physics.BodyType.fixed,
      additionalMass: body?.mass,
    );
    if (body != null) {
      runtime.simulation
        ..setBodyLinearVelocity(bodyHandle, body.linearVelocity)
        ..setBodyAngularVelocity(bodyHandle, body.angularVelocity)
        ..setBodyLinearDamping(bodyHandle, body.linearDamping)
        ..setBodyAngularDamping(bodyHandle, body.angularDamping)
        ..setBodyGravityScale(bodyHandle, body.gravityScale)
        ..setBodyCcdEnabled(bodyHandle, body.continuousCollisionDetection)
        ..setBodyAxisLocks(
          bodyHandle,
          body.linearAxisFactor,
          body.angularAxisFactor,
        );
    }
    final colliderHandles = runtime.simulation.createColliders(
      bodyHandle,
      collider.shape,
      material: collider.material,
      isTrigger: collider.isTrigger,
      localPose: collider.localPose,
      collisionLayer: collider.layer,
      collisionMask: collider.mask,
    );
    if (colliderHandles.isEmpty) {
      runtime.simulation.destroyBody(bodyHandle);
      throw UnsupportedError(
        '${runtime.backendName} does not support ${collider.shape.runtimeType}',
      );
    }
    runtime._registrations[entity] = _PhysicsRegistration(
      bodyHandle,
      colliderHandles,
      target,
      body,
      collider,
    );
    for (final handle in colliderHandles) {
      runtime._colliderEntities[handle] = entity;
    }
  }

  void _unregister(PhysicsRuntime runtime, Entity entity) {
    final registration = runtime._registrations.remove(entity);
    if (registration == null) return;
    for (final handle in registration.colliderHandles) {
      runtime._colliderEntities.remove(handle);
      runtime.simulation.destroyCollider(handle);
    }
    runtime.simulation.destroyBody(registration.bodyHandle);
  }
}

class _PhysicsStepSystem implements EngineSystem {
  const _PhysicsStepSystem();

  @override
  void update(EngineContext context, double deltaSeconds) =>
      context.resources.get<PhysicsRuntime>().simulation.step(deltaSeconds);
}

class _PhysicsInterpolationSystem implements EngineSystem {
  const _PhysicsInterpolationSystem();

  @override
  void update(EngineContext context, double deltaSeconds) => context.resources
      .get<PhysicsRuntime>()
      .simulation
      .interpolatePoses(context.resources.get<FixedInterpolation>().alpha);
}

class _PhysicsRegistration {
  const _PhysicsRegistration(
    this.bodyHandle,
    this.colliderHandles,
    this.target,
    this.body,
    this.collider,
  );

  final int bodyHandle;
  final List<int> colliderHandles;
  final _EcsPoseTarget target;
  final PhysicsBody3d? body;
  final PhysicsCollider3d collider;
}

class _EcsPoseTarget implements physics.PoseTarget {
  const _EcsPoseTarget(this.context, this.entity);

  final EngineContext context;
  final Entity entity;

  Matrix4 get _worldMatrix {
    Matrix4 resolve(Entity current, Set<Entity> visiting) {
      if (!visiting.add(current)) {
        throw StateError('Transform hierarchy contains a cycle at $current');
      }
      final result = context.world.get<LocalTransform>(current).matrix();
      final parent = context.world.maybeGet<Parent>(current)?.entity;
      if (parent != null) return resolve(parent, visiting) * result;
      return result;
    }

    return resolve(entity, <Entity>{});
  }

  @override
  Vector3 get worldTranslation => _worldMatrix.getTranslation();

  @override
  Quaternion get worldRotation {
    final translation = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.zero();
    _worldMatrix.decompose(translation, rotation, scale);
    return rotation;
  }

  @override
  void setWorldPose(Vector3 translation, Quaternion rotation) {
    final local = context.world.get<LocalTransform>(entity);
    var world = Matrix4.compose(translation, rotation, local.scale);
    final parent = context.world.maybeGet<Parent>(entity)?.entity;
    if (parent != null) {
      final parentWorld = _EcsPoseTarget(context, parent)._worldMatrix;
      world = Matrix4.copy(parentWorld)..invert();
      world.multiply(Matrix4.compose(translation, rotation, local.scale));
    }
    world.decompose(local.translation, local.rotation, local.scale);
  }
}
