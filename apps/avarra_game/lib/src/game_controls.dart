import 'dart:ui' show KeyEventDeviceType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which prompt family should represent the player's latest input.
enum GameInputPromptMode { keyboard, controller }

/// Game-owned controls. They map to existing input intents and never become
/// world, save, simulation, or network authority.
enum GameControl {
  moveUp,
  moveLeft,
  moveDown,
  moveRight,
  primarySkill,
  dodge,
  interact,
}

extension GameControlLabel on GameControl {
  String get label => switch (this) {
    GameControl.moveUp => 'Move up',
    GameControl.moveLeft => 'Move left',
    GameControl.moveDown => 'Move down',
    GameControl.moveRight => 'Move right',
    GameControl.primarySkill => 'Basic strike',
    GameControl.dodge => 'Dodge',
    GameControl.interact => 'Interact',
  };

  bool get isMovement => switch (this) {
    GameControl.moveUp ||
    GameControl.moveLeft ||
    GameControl.moveDown ||
    GameControl.moveRight => true,
    GameControl.primarySkill ||
    GameControl.dodge ||
    GameControl.interact => false,
  };
}

/// Deliberately bounded keyboard choices for AVARRA's first remapping surface.
///
/// Escape and arrow keys remain reserved fallbacks so menus and movement
/// cannot be made unreachable.
enum GameInputKey {
  keyW,
  keyA,
  keyS,
  keyD,
  keyQ,
  keyE,
  keyR,
  keyF,
  keyI,
  keyJ,
  keyK,
  keyL,
  keyZ,
  keyX,
  keyC,
  keyV,
  space,
  shiftLeft,
  controlLeft,
  altLeft,
}

const gameBindableInputKeys = GameInputKey.values;

extension GameInputKeyDefinition on GameInputKey {
  LogicalKeyboardKey get logicalKey => switch (this) {
    GameInputKey.keyW => LogicalKeyboardKey.keyW,
    GameInputKey.keyA => LogicalKeyboardKey.keyA,
    GameInputKey.keyS => LogicalKeyboardKey.keyS,
    GameInputKey.keyD => LogicalKeyboardKey.keyD,
    GameInputKey.keyQ => LogicalKeyboardKey.keyQ,
    GameInputKey.keyE => LogicalKeyboardKey.keyE,
    GameInputKey.keyR => LogicalKeyboardKey.keyR,
    GameInputKey.keyF => LogicalKeyboardKey.keyF,
    GameInputKey.keyI => LogicalKeyboardKey.keyI,
    GameInputKey.keyJ => LogicalKeyboardKey.keyJ,
    GameInputKey.keyK => LogicalKeyboardKey.keyK,
    GameInputKey.keyL => LogicalKeyboardKey.keyL,
    GameInputKey.keyZ => LogicalKeyboardKey.keyZ,
    GameInputKey.keyX => LogicalKeyboardKey.keyX,
    GameInputKey.keyC => LogicalKeyboardKey.keyC,
    GameInputKey.keyV => LogicalKeyboardKey.keyV,
    GameInputKey.space => LogicalKeyboardKey.space,
    GameInputKey.shiftLeft => LogicalKeyboardKey.shiftLeft,
    GameInputKey.controlLeft => LogicalKeyboardKey.controlLeft,
    GameInputKey.altLeft => LogicalKeyboardKey.altLeft,
  };

  String get label => switch (this) {
    GameInputKey.keyW => 'W',
    GameInputKey.keyA => 'A',
    GameInputKey.keyS => 'S',
    GameInputKey.keyD => 'D',
    GameInputKey.keyQ => 'Q',
    GameInputKey.keyE => 'E',
    GameInputKey.keyR => 'R',
    GameInputKey.keyF => 'F',
    GameInputKey.keyI => 'I',
    GameInputKey.keyJ => 'J',
    GameInputKey.keyK => 'K',
    GameInputKey.keyL => 'L',
    GameInputKey.keyZ => 'Z',
    GameInputKey.keyX => 'X',
    GameInputKey.keyC => 'C',
    GameInputKey.keyV => 'V',
    GameInputKey.space => 'SPACE',
    GameInputKey.shiftLeft => 'SHIFT',
    GameInputKey.controlLeft => 'CTRL',
    GameInputKey.altLeft => 'ALT',
  };
}

@immutable
final class GameControlBindings {
  const GameControlBindings({
    this.moveUp = GameInputKey.keyW,
    this.moveLeft = GameInputKey.keyA,
    this.moveDown = GameInputKey.keyS,
    this.moveRight = GameInputKey.keyD,
    this.primarySkill = GameInputKey.space,
    this.dodge = GameInputKey.shiftLeft,
    this.interact = GameInputKey.keyE,
  });

  static const defaults = GameControlBindings();

  final GameInputKey moveUp;
  final GameInputKey moveLeft;
  final GameInputKey moveDown;
  final GameInputKey moveRight;
  final GameInputKey primarySkill;
  final GameInputKey dodge;
  final GameInputKey interact;

  GameInputKey keyFor(GameControl control) => switch (control) {
    GameControl.moveUp => moveUp,
    GameControl.moveLeft => moveLeft,
    GameControl.moveDown => moveDown,
    GameControl.moveRight => moveRight,
    GameControl.primarySkill => primarySkill,
    GameControl.dodge => dodge,
    GameControl.interact => interact,
  };

  String labelFor(GameControl control) => keyFor(control).label;

  String promptLabelFor(GameControl control, GameInputPromptMode mode) =>
      switch (mode) {
        GameInputPromptMode.keyboard => labelFor(control),
        GameInputPromptMode.controller => switch (control) {
          GameControl.moveUp => 'D-PAD UP',
          GameControl.moveLeft => 'D-PAD LEFT',
          GameControl.moveDown => 'D-PAD DOWN',
          GameControl.moveRight => 'D-PAD RIGHT',
          GameControl.primarySkill => 'X',
          GameControl.dodge => 'B',
          GameControl.interact => 'A',
        },
      };

  /// Rebinding to an occupied key swaps both controls, so every action remains
  /// reachable and the settings dialog never creates an ambiguous binding.
  GameControlBindings rebind(GameControl control, GameInputKey key) {
    final previous = keyFor(control);
    if (previous == key) return this;
    GameControl? conflict;
    for (final candidate in GameControl.values) {
      if (candidate != control && keyFor(candidate) == key) {
        conflict = candidate;
        break;
      }
    }
    var next = _replace(control, key);
    if (conflict != null) next = next._replace(conflict, previous);
    return next;
  }

  GameControl? movementControlFor(LogicalKeyboardKey key) {
    for (final control in GameControl.values.where(
      (candidate) => candidate.isMovement,
    )) {
      if (matches(control, key)) return control;
    }
    return null;
  }

  GameControl? actionControlFor(LogicalKeyboardKey key) {
    for (final control in const [
      GameControl.primarySkill,
      GameControl.dodge,
      GameControl.interact,
    ]) {
      if (matches(control, key)) return control;
    }
    return null;
  }

  bool matches(GameControl control, LogicalKeyboardKey key) {
    final selected = keyFor(control);
    if (selected.logicalKey == key) return true;
    if (selected == GameInputKey.shiftLeft &&
        key == LogicalKeyboardKey.shiftRight) {
      return true;
    }
    if (selected == GameInputKey.controlLeft &&
        key == LogicalKeyboardKey.controlRight) {
      return true;
    }
    if (selected == GameInputKey.altLeft &&
        key == LogicalKeyboardKey.altRight) {
      return true;
    }
    return switch (control) {
      GameControl.moveUp => key == LogicalKeyboardKey.arrowUp,
      GameControl.moveLeft => key == LogicalKeyboardKey.arrowLeft,
      GameControl.moveDown => key == LogicalKeyboardKey.arrowDown,
      GameControl.moveRight => key == LogicalKeyboardKey.arrowRight,
      GameControl.primarySkill =>
        key == LogicalKeyboardKey.gameButtonX ||
            key == LogicalKeyboardKey.gameButton3,
      GameControl.dodge =>
        key == LogicalKeyboardKey.gameButtonB ||
            key == LogicalKeyboardKey.gameButton2,
      GameControl.interact =>
        key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.gameButton1,
    };
  }

  bool isPressed(Set<LogicalKeyboardKey> keys, GameControl control) =>
      keys.any((key) => matches(control, key));

  Map<String, Object?> toJson() => {
    for (final control in GameControl.values)
      control.name: keyFor(control).name,
  };

  factory GameControlBindings.decode(Object? source) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Invalid AVARRA control bindings.');
    }
    final parsed = <GameControl, GameInputKey>{};
    for (final control in GameControl.values) {
      final value = source[control.name];
      if (value is! String) {
        throw const FormatException('Invalid AVARRA control bindings.');
      }
      final GameInputKey key;
      try {
        key = GameInputKey.values.byName(value);
      } on ArgumentError {
        throw const FormatException('Unsupported AVARRA control key.');
      }
      parsed[control] = key;
    }
    if (parsed.values.toSet().length != GameControl.values.length) {
      throw const FormatException('AVARRA control keys must be unique.');
    }
    return GameControlBindings(
      moveUp: parsed[GameControl.moveUp]!,
      moveLeft: parsed[GameControl.moveLeft]!,
      moveDown: parsed[GameControl.moveDown]!,
      moveRight: parsed[GameControl.moveRight]!,
      primarySkill: parsed[GameControl.primarySkill]!,
      dodge: parsed[GameControl.dodge]!,
      interact: parsed[GameControl.interact]!,
    );
  }

  GameControlBindings _replace(GameControl control, GameInputKey key) =>
      GameControlBindings(
        moveUp: control == GameControl.moveUp ? key : moveUp,
        moveLeft: control == GameControl.moveLeft ? key : moveLeft,
        moveDown: control == GameControl.moveDown ? key : moveDown,
        moveRight: control == GameControl.moveRight ? key : moveRight,
        primarySkill: control == GameControl.primarySkill ? key : primarySkill,
        dodge: control == GameControl.dodge ? key : dodge,
        interact: control == GameControl.interact ? key : interact,
      );

  @override
  bool operator ==(Object other) =>
      other is GameControlBindings &&
      moveUp == other.moveUp &&
      moveLeft == other.moveLeft &&
      moveDown == other.moveDown &&
      moveRight == other.moveRight &&
      primarySkill == other.primarySkill &&
      dodge == other.dodge &&
      interact == other.interact;

  @override
  int get hashCode => Object.hash(
    moveUp,
    moveLeft,
    moveDown,
    moveRight,
    primarySkill,
    dodge,
    interact,
  );
}

bool isGamePauseKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.escape ||
    key == LogicalKeyboardKey.gameButtonStart;

GameInputPromptMode gameInputPromptModeFor(KeyEvent event) {
  if (_controllerLogicalKeys.contains(event.logicalKey) ||
      event.deviceType == KeyEventDeviceType.gamepad ||
      event.deviceType == KeyEventDeviceType.directionalPad ||
      event.deviceType == KeyEventDeviceType.joystick) {
    return GameInputPromptMode.controller;
  }
  return GameInputPromptMode.keyboard;
}

String gamePausePrompt(GameInputPromptMode mode) => switch (mode) {
  GameInputPromptMode.keyboard => 'ESC',
  GameInputPromptMode.controller => 'START',
};

final _controllerLogicalKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.gameButtonA,
  LogicalKeyboardKey.gameButtonB,
  LogicalKeyboardKey.gameButtonX,
  LogicalKeyboardKey.gameButton1,
  LogicalKeyboardKey.gameButton2,
  LogicalKeyboardKey.gameButton3,
  LogicalKeyboardKey.gameButtonStart,
};
