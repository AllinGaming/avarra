import 'dart:ui' show KeyEventDeviceType;

import 'package:avarra_game/src/game_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults retain keyboard, arrow, controller, and pause fallbacks', () {
    const bindings = GameControlBindings.defaults;

    expect(bindings.matches(GameControl.moveUp, LogicalKeyboardKey.keyW), true);
    expect(
      bindings.matches(GameControl.moveUp, LogicalKeyboardKey.arrowUp),
      true,
    );
    expect(
      bindings.actionControlFor(LogicalKeyboardKey.gameButtonX),
      GameControl.primarySkill,
    );
    expect(
      bindings.actionControlFor(LogicalKeyboardKey.gameButtonB),
      GameControl.dodge,
    );
    expect(
      bindings.actionControlFor(LogicalKeyboardKey.gameButtonY),
      GameControl.recovery,
    );
    expect(
      bindings.actionControlFor(LogicalKeyboardKey.gameButtonA),
      GameControl.interact,
    );
    expect(isGamePauseKey(LogicalKeyboardKey.gameButtonStart), true);
    expect(isGamePauseKey(LogicalKeyboardKey.escape), true);
  });

  test('rebind swaps conflicts and keeps every control reachable', () {
    final bindings = GameControlBindings.defaults.rebind(
      GameControl.primarySkill,
      GameInputKey.keyE,
    );

    expect(bindings.primarySkill, GameInputKey.keyE);
    expect(bindings.interact, GameInputKey.space);
    expect(
      bindings.actionControlFor(LogicalKeyboardKey.keyE),
      GameControl.primarySkill,
    );
    expect(
      bindings.actionControlFor(LogicalKeyboardKey.space),
      GameControl.interact,
    );
    expect(
      bindings.toJson().values.toSet(),
      hasLength(GameControl.values.length),
    );
  });

  test('codec round-trips bindings and rejects ambiguous input', () {
    final bindings = GameControlBindings.defaults
        .rebind(GameControl.moveUp, GameInputKey.keyI)
        .rebind(GameControl.dodge, GameInputKey.keyR);

    expect(GameControlBindings.decode(bindings.toJson()), bindings);
    expect(
      () => GameControlBindings.decode({
        ...bindings.toJson(),
        GameControl.interact.name: GameInputKey.keyR.name,
      }),
      throwsFormatException,
    );
    expect(
      () => GameControlBindings.decode({
        ...bindings.toJson(),
        GameControl.interact.name: 'unsupported',
      }),
      throwsFormatException,
    );
  });

  test('right-side modifier keys follow their selected left-side binding', () {
    const bindings = GameControlBindings.defaults;

    expect(
      bindings.matches(GameControl.dodge, LogicalKeyboardKey.shiftRight),
      true,
    );
  });

  test('remapped movement replaces its old key but keeps arrow fallback', () {
    final bindings = GameControlBindings.defaults.rebind(
      GameControl.moveUp,
      GameInputKey.keyI,
    );

    expect(
      bindings.movementControlFor(LogicalKeyboardKey.keyI),
      GameControl.moveUp,
    );
    expect(bindings.movementControlFor(LogicalKeyboardKey.keyW), isNull);
    expect(
      bindings.isPressed({LogicalKeyboardKey.arrowUp}, GameControl.moveUp),
      isTrue,
    );
  });

  test('prompt labels follow remaps and the active input family', () {
    final bindings = GameControlBindings.defaults
        .rebind(GameControl.moveUp, GameInputKey.keyI)
        .rebind(GameControl.primarySkill, GameInputKey.keyQ)
        .rebind(GameControl.interact, GameInputKey.keyF);

    expect(
      bindings.promptLabelFor(GameControl.moveUp, GameInputPromptMode.keyboard),
      'I',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.primarySkill,
        GameInputPromptMode.keyboard,
      ),
      'Q',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.interact,
        GameInputPromptMode.keyboard,
      ),
      'F',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.moveUp,
        GameInputPromptMode.controller,
      ),
      'D-PAD UP',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.primarySkill,
        GameInputPromptMode.controller,
      ),
      'X',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.dodge,
        GameInputPromptMode.controller,
      ),
      'B',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.recovery,
        GameInputPromptMode.controller,
      ),
      'Y',
    );
    expect(
      bindings.promptLabelFor(
        GameControl.interact,
        GameInputPromptMode.controller,
      ),
      'A',
    );
    expect(gamePausePrompt(GameInputPromptMode.keyboard), 'ESC');
    expect(gamePausePrompt(GameInputPromptMode.controller), 'START');
  });

  test('input prompt mode follows both controller keys and device types', () {
    const keyboardEvent = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyW,
      logicalKey: LogicalKeyboardKey.keyW,
      timeStamp: Duration.zero,
    );
    const controllerKeyEvent = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.gameButtonA,
      logicalKey: LogicalKeyboardKey.gameButtonA,
      timeStamp: Duration.zero,
    );
    const directionalPadEvent = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowUp,
      logicalKey: LogicalKeyboardKey.arrowUp,
      timeStamp: Duration.zero,
      deviceType: KeyEventDeviceType.directionalPad,
    );

    expect(gameInputPromptModeFor(keyboardEvent), GameInputPromptMode.keyboard);
    expect(
      gameInputPromptModeFor(controllerKeyEvent),
      GameInputPromptMode.controller,
    );
    expect(
      gameInputPromptModeFor(directionalPadEvent),
      GameInputPromptMode.controller,
    );
  });
}
