import 'dart:io';

import 'package:avarra_game/src/runtime_world_library.dart';
import 'package:avarra_world/avarra_world.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run bin/runtime_import_proof.dart '
      '<input.avarra|--load-selected> <catalog-directory> '
      '<game-asset-directory>',
    );
    exitCode = 64;
    return;
  }
  final input = arguments[0];
  final catalogDirectory = Directory(arguments[1]);
  final assetDirectory = Directory(arguments[2]);
  final library = RuntimeWorldLibrary(
    directory: catalogDirectory,
    assetAvailability: (path) => File(
      '${assetDirectory.path}${Platform.pathSeparator}'
      '${path.replaceAll('/', Platform.pathSeparator)}',
    ).exists(),
  );
  final entry = input == '--load-selected'
      ? await library.loadSelected()
      : await library.importFile(input);
  if (entry == null) {
    stderr.writeln('No imported runtime world is selected.');
    exitCode = 2;
    return;
  }
  final runtime = const RuntimeWorldLoader().load(
    WorldPackageCodec().decode(entry.source),
  );
  stdout.writeln('${runtime.definition.id.value}|${runtime.definition.name}');
}
