import 'dart:io';

import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || arguments.single.trim().isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/export_tiny_world.dart <output.avarra>',
    );
    exitCode = 64;
    return;
  }
  final session = CreatorWorldSession(initialWorld: createForgeSampleWorld());
  final source = session.exportCanonical();
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsString(source, flush: true);
  stdout.writeln('Exported ${source.length} bytes to ${output.path}');
}
