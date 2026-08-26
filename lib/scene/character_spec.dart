enum CharacterPrimitive { sphere, box, torus }

class CharacterMaterialSpec {
  const CharacterMaterialSpec({required this.name, required this.color});

  final String name;
  final String color;
}

class CharacterPartSpec {
  const CharacterPartSpec({
    required this.name,
    required this.parent,
    required this.primitive,
    required this.material,
    required this.position,
    required this.scale,
    this.rotation = const [0, 0, 0],
  });

  final String name;
  final String? parent;
  final CharacterPrimitive primitive;
  final String material;
  final List<double> position;
  final List<double> scale;
  final List<double> rotation;
}

class CharacterSpec {
  const CharacterSpec({
    required this.name,
    required this.materials,
    required this.parts,
  });

  final String name;
  final List<CharacterMaterialSpec> materials;
  final List<CharacterPartSpec> parts;

  List<String> validate() {
    final errors = <String>[];
    final materialNames = <String>{};
    for (final material in materials) {
      if (!materialNames.add(material.name)) {
        errors.add('Duplicate material: ${material.name}');
      }
      if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(material.color)) {
        errors.add('Invalid color for ${material.name}: ${material.color}');
      }
    }
    final partNames = <String>{};
    for (final part in parts) {
      if (!partNames.add(part.name)) {
        errors.add('Duplicate part: ${part.name}');
      }
      if (!materialNames.contains(part.material)) {
        errors.add('Unknown material ${part.material} on ${part.name}');
      }
      if (part.position.length != 3 ||
          part.scale.length != 3 ||
          part.rotation.length != 3) {
        errors.add('Part ${part.name} transforms must contain three values');
      }
    }
    for (final part in parts) {
      if (part.parent != null && !partNames.contains(part.parent)) {
        errors.add('Unknown parent ${part.parent} on ${part.name}');
      }
      final ancestors = <String>{part.name};
      var parent = part.parent;
      while (parent != null) {
        if (!ancestors.add(parent)) {
          errors.add('Cyclic hierarchy at ${part.name}');
          break;
        }
        parent = parts
            .where((candidate) => candidate.name == parent)
            .firstOrNull
            ?.parent;
      }
    }
    return errors;
  }
}
