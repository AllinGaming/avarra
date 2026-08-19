import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/game_launch_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads one exact Forge test-play package from process arguments',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'avarra-game-launch-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final world = File(
        '${directory.path}${Platform.pathSeparator}forge-preview.avarra',
      );
      await world.writeAsString('canonical world source');

      final configuration = GameLaunchConfiguration.parse([
        '--ignored-runtime-option',
        '$avarraForgeTestPlayArgumentPrefix${world.path}',
      ]);

      expect(configuration.isForgeTestPlay, isTrue);
      expect(configuration.forgeTestPlayWorldPath, world.path);
      expect(
        await configuration.readForgeTestPlayWorldSource(),
        'canonical world source',
      );
    },
  );

  test('rejects malformed or duplicate Forge test-play arguments', () {
    expect(
      () => GameLaunchConfiguration.parse([avarraForgeTestPlayArgumentPrefix]),
      throwsFormatException,
    );
    expect(
      () => GameLaunchConfiguration.parse([
        '${avarraForgeTestPlayArgumentPrefix}world.json',
      ]),
      throwsFormatException,
    );
    expect(
      () => GameLaunchConfiguration.parse([
        '${avarraForgeTestPlayArgumentPrefix}one.avarra',
        '${avarraForgeTestPlayArgumentPrefix}two.avarra',
      ]),
      throwsFormatException,
    );

    const configuration = GameLaunchConfiguration();
    expect(configuration.isForgeTestPlay, isFalse);
    expect(configuration.readForgeTestPlayWorldSource, throwsStateError);
  });
}
