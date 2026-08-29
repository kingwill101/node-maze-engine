/// Serializable gameplay-side descriptions realized by a scene backend.
/// These contain no Flutter, GPU, geometry, or material instances.
enum ScenePrimitive {
  box,
  sphere,
  icosphere,
  plane,
  cylinder,
  capsule,
  torus,
  disc,
  ring,
  wedge,
}

enum SceneMaterialKind { unlit, physicallyBased, sprite, shader, fmat }

class SceneMesh3d {
  SceneMesh3d({
    required this.primitive,
    this.material = 'default',
    this.width = 1,
    this.height = 1,
    this.depth = 1,
    this.visible = true,
    this.replacesDefault = true,
    this.castShadows = true,
    this.receiveShadows = true,
    this.renderLayer = 1,
  });

  ScenePrimitive primitive;
  String material;
  double width;
  double height;
  double depth;
  bool visible;
  bool replacesDefault;
  bool castShadows;
  bool receiveShadows;
  int renderLayer;
}

class SceneMaterial3d {
  SceneMaterial3d({
    this.kind = SceneMaterialKind.unlit,
    this.color = '#ffffff',
    this.asset,
    this.metallic = 0,
    this.roughness = 1,
    this.emissive = 0,
    this.opacity = 1,
    Map<String, Object?>? parameters,
  }) : parameters = parameters ?? <String, Object?>{};

  SceneMaterialKind kind;
  String color;
  String? asset;
  double metallic;
  double roughness;
  double emissive;
  double opacity;
  final Map<String, Object?> parameters;
}

enum SceneLightKind { directional, point, spot, area }

class SceneLight3d {
  SceneLight3d({
    required this.kind,
    this.color = '#ffffff',
    this.intensity = 1,
    this.range = 10,
    this.innerAngle = .35,
    this.outerAngle = .65,
    this.castShadows = false,
    this.width = 1,
    this.height = 1,
  });

  SceneLightKind kind;
  String color;
  double intensity;
  double range;
  double innerAngle;
  double outerAngle;
  bool castShadows;
  double width;
  double height;
}

class SceneCamera3d {
  SceneCamera3d({
    this.active = false,
    this.fovRadians = 1,
    this.near = .05,
    this.far = 500,
  });

  bool active;
  double fovRadians;
  double near;
  double far;
}

class SceneAsset3d {
  SceneAsset3d(this.path, {this.subtree, this.animation, this.autoPlay = true});

  String path;
  String? subtree;
  String? animation;
  bool autoPlay;
}

class SceneParticle3d {
  SceneParticle3d({
    this.maxParticles = 128,
    this.rate = 10,
    this.lifetime = 1,
    this.shape = 'point',
    this.color = '#ffffff',
    this.size = .1,
    this.modules = const <String>[],
  });

  int maxParticles;
  double rate;
  double lifetime;
  String shape;
  String color;
  double size;
  List<String> modules;
}

class SceneEnvironment3d {
  SceneEnvironment3d({
    this.environmentAsset,
    this.skyAsset,
    this.fog = false,
    this.ambientOcclusion = false,
    this.globalIllumination = false,
    this.screenSpaceReflections = false,
    this.godRays = false,
    this.depthOfField = false,
    this.autoExposure = false,
    this.temporalAntiAliasing = false,
  });

  String? environmentAsset;
  String? skyAsset;
  bool fog;
  bool ambientOcclusion;
  bool globalIllumination;
  bool screenSpaceReflections;
  bool godRays;
  bool depthOfField;
  bool autoExposure;
  bool temporalAntiAliasing;
}
