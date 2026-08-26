import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_character.dart <input.json> <output.dart>',
    );
    exitCode = 64;
    return;
  }
  final input = File(arguments[0]);
  final output = File(arguments[1]);
  final root = jsonDecode(input.readAsStringSync()) as Map<String, Object?>;
  final name = _string(root, 'name');
  final identifier = _identifier(name);
  final materials = _list(root, 'materials');
  final parts = _list(root, 'parts');
  _validate(materials, parts);

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: ${input.path}')
    ..writeln()
    ..writeln("import '../scene/character_spec.dart';")
    ..writeln()
    ..writeln('const ${identifier}CharacterSpec = CharacterSpec(')
    ..writeln("  name: ${_literal(name)},")
    ..writeln('  materials: [');
  for (final material in materials) {
    buffer
      ..writeln('    CharacterMaterialSpec(')
      ..writeln("      name: ${_literal(_string(material, 'name'))},")
      ..writeln("      color: ${_literal(_string(material, 'color'))},")
      ..writeln('    ),');
  }
  buffer
    ..writeln('  ],')
    ..writeln('  parts: [');
  for (final part in parts) {
    final parent = part['parent'];
    buffer
      ..writeln('    CharacterPartSpec(')
      ..writeln("      name: ${_literal(_string(part, 'name'))},")
      ..writeln(
        '      parent: ${parent == null ? 'null' : _literal(parent.toString())},',
      )
      ..writeln(
        '      primitive: CharacterPrimitive.${_string(part, 'primitive')},',
      )
      ..writeln("      material: ${_literal(_string(part, 'material'))},")
      ..writeln('      position: ${_numbers(part, 'position')},')
      ..writeln('      scale: ${_numbers(part, 'scale')},')
      ..writeln(
        '      rotation: ${_numbers(part, 'rotation', fallback: [0, 0, 0])},',
      )
      ..writeln('    ),');
  }
  buffer
    ..writeln('  ],')
    ..writeln(');');
  output
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());
}

List<Map<String, Object?>> _list(Map<String, Object?> root, String key) =>
    (root[key] as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .map(
          (value) => {
            for (final entry in value.entries)
              entry.key.toString(): entry.value,
          },
        )
        .toList();

String _string(Map<String, Object?> root, String key) {
  final value = root[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String _numbers(Map<String, Object?> root, String key, {List<num>? fallback}) {
  final values = (root[key] as List<Object?>?) ?? fallback;
  if (values == null ||
      values.length != 3 ||
      values.any((value) => value is! num)) {
    throw FormatException('$key must contain three numbers');
  }
  return '[${values.map((value) => (value as num).toDouble()).join(', ')}]';
}

void _validate(
  List<Map<String, Object?>> materials,
  List<Map<String, Object?>> parts,
) {
  final materialNames = materials.map((item) => _string(item, 'name')).toSet();
  final partNames = parts.map((item) => _string(item, 'name')).toSet();
  if (materialNames.length != materials.length) {
    throw const FormatException('Material names must be unique');
  }
  if (partNames.length != parts.length) {
    throw const FormatException('Part names must be unique');
  }
  for (final material in materials) {
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(_string(material, 'color'))) {
      throw FormatException('Invalid material color: ${material['color']}');
    }
  }
  for (final part in parts) {
    final primitive = _string(part, 'primitive');
    if (!const {'sphere', 'box', 'torus'}.contains(primitive)) {
      throw FormatException('Unsupported primitive: $primitive');
    }
    if (!materialNames.contains(_string(part, 'material'))) {
      throw FormatException('Unknown material on ${part['name']}');
    }
    final parent = part['parent'];
    if (parent != null && !partNames.contains(parent)) {
      throw FormatException('Unknown parent $parent');
    }
    _numbers(part, 'position');
    _numbers(part, 'scale');
    _numbers(part, 'rotation', fallback: const [0, 0, 0]);
  }
}

String _identifier(String source) {
  final words = source
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((word) => word.isNotEmpty);
  final pascal = words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join();
  return '${pascal[0].toLowerCase()}${pascal.substring(1)}';
}

String _literal(String source) => jsonEncode(source);
