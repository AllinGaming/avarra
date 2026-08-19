import 'dart:io';

import 'package:avarra_core/avarra_core.dart';

final class GameLaunchConfiguration {
  const GameLaunchConfiguration({this.forgeTestPlayWorldPath});

  factory GameLaunchConfiguration.parse(Iterable<String> arguments) {
    String? forgeTestPlayWorldPath;
    for (final argument in arguments) {
      if (!argument.startsWith(avarraForgeTestPlayArgumentPrefix)) continue;
      if (forgeTestPlayWorldPath != null) {
        throw const FormatException(
          'Only one Forge test-play world may be supplied.',
        );
      }
      final path = argument.substring(avarraForgeTestPlayArgumentPrefix.length);
      if (path.trim().isEmpty) {
        throw const FormatException(
          'The Forge test-play world path must not be empty.',
        );
      }
      if (!path.toLowerCase().endsWith('.avarra')) {
        throw const FormatException(
          'The Forge test-play world must use the .avarra extension.',
        );
      }
      forgeTestPlayWorldPath = path;
    }
    return GameLaunchConfiguration(
      forgeTestPlayWorldPath: forgeTestPlayWorldPath,
    );
  }

  final String? forgeTestPlayWorldPath;

  bool get isForgeTestPlay => forgeTestPlayWorldPath != null;

  Future<String> readForgeTestPlayWorldSource() {
    final path = forgeTestPlayWorldPath;
    if (path == null) {
      throw StateError('No Forge test-play world was configured.');
    }
    return File(path).readAsString();
  }
}
