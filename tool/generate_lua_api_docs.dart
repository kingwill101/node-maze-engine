import 'dart:io';

import 'package:node/engine/runtime.dart';
import 'package:node/scripting/lua_behavior_runtime.dart';

void main() {
  final runtime = LuaBehaviorRuntime(EngineContext());
  final output = Directory('docs/lua')..createSync(recursive: true);
  File('${output.path}/node_engine.lua')
      .writeAsStringSync(runtime.renderLuaLanguageServerAnnotations());
  File('${output.path}/node_engine.json')
      .writeAsStringSync(runtime.renderLuaApiJson());
  stdout.writeln('Generated Lua API metadata in ${output.path}.');
}
