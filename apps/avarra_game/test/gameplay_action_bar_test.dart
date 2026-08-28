import 'package:avarra_game/src/game_controls.dart';
import 'package:avarra_game/src/gameplay_action_bar.dart';
import 'package:avarra_gameplay/avarra_gameplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives bounded cooldown progress from simulation time', () {
    final cooldown = GameplaySkillCooldown.at(
      total: const Duration(milliseconds: 800),
      now: const Duration(milliseconds: 1250),
      nextReadyAt: const Duration(milliseconds: 1650),
    );

    expect(cooldown.remaining, const Duration(milliseconds: 400));
    expect(cooldown.remainingFraction, 0.5);
    expect(cooldown.remainingLabel, '0.4s');
    expect(cooldown.isReady, isFalse);

    final overdue = GameplaySkillCooldown.at(
      total: const Duration(milliseconds: 800),
      now: const Duration(seconds: 2),
      nextReadyAt: const Duration(milliseconds: 1800),
    );
    expect(overdue.isReady, isTrue);
    expect(overdue.remainingFraction, 0);
    expect(overdue.remainingLabel, 'READY');
  });

  test('maps only the documented combat hotkeys', () {
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.space),
      GameplayHotkeyAction.primarySkill,
    );
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.keyE),
      GameplayHotkeyAction.interact,
    );
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.shiftLeft),
      GameplayHotkeyAction.dodge,
    );
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.keyR),
      GameplayHotkeyAction.recovery,
    );
    expect(gameplayHotkeyActionFor(LogicalKeyboardKey.keyQ), isNull);
  });

  test('maps remapped actions while retaining controller aliases', () {
    final bindings = GameControlBindings.defaults
        .rebind(GameControl.primarySkill, GameInputKey.keyQ)
        .rebind(GameControl.dodge, GameInputKey.keyR)
        .rebind(GameControl.recovery, GameInputKey.keyC)
        .rebind(GameControl.interact, GameInputKey.keyF);

    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.keyQ, bindings: bindings),
      GameplayHotkeyAction.primarySkill,
    );
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.keyR, bindings: bindings),
      GameplayHotkeyAction.dodge,
    );
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.keyC, bindings: bindings),
      GameplayHotkeyAction.recovery,
    );
    expect(
      gameplayHotkeyActionFor(LogicalKeyboardKey.keyF, bindings: bindings),
      GameplayHotkeyAction.interact,
    );
    expect(
      gameplayHotkeyActionFor(
        LogicalKeyboardKey.gameButtonX,
        bindings: bindings,
      ),
      GameplayHotkeyAction.primarySkill,
    );
  });

  testWidgets('shows health and dispatches ready action slots', (tester) async {
    var primaryActivations = 0;
    var dodgeActivations = 0;
    var recoveryActivations = 0;
    var interactionActivations = 0;
    final bindings = GameControlBindings.defaults
        .rebind(GameControl.primarySkill, GameInputKey.keyQ)
        .rebind(GameControl.dodge, GameInputKey.keyR)
        .rebind(GameControl.recovery, GameInputKey.keyC)
        .rebind(GameControl.interact, GameInputKey.keyF);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GameplayActionBar(
              currentHealth: 75,
              maximumHealth: 100,
              primaryCooldown: GameplaySkillCooldown(
                total: const Duration(milliseconds: 800),
                remaining: Duration.zero,
              ),
              primaryEngaged: false,
              dodgeCooldown: GameplaySkillCooldown(
                total: playerDodgeCooldown,
                remaining: Duration.zero,
              ),
              recoveryCooldown: GameplaySkillCooldown(
                total: playerRecoveryCooldown,
                remaining: Duration.zero,
              ),
              onPrimary: () => primaryActivations++,
              onDodge: () => dodgeActivations++,
              onRecovery: () => recoveryActivations++,
              onInteract: () => interactionActivations++,
              controlBindings: bindings,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('gameplay_action_bar')), findsOneWidget);
    expect(find.text('75/100'), findsOneWidget);
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('BASIC STRIKE · READY'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byKey(const Key('action_bar_health_progress')),
          )
          .value,
      0.75,
    );

    await tester.tap(find.byKey(const Key('basic_attack')));
    await tester.tap(find.byKey(const Key('dodge')));
    await tester.tap(find.byKey(const Key('relic_mend')));
    await tester.tap(find.byKey(const Key('interact')));
    expect(primaryActivations, 1);
    expect(dodgeActivations, 1);
    expect(recoveryActivations, 1);
    expect(interactionActivations, 1);
  });

  testWidgets('shows radial recovery and disables unavailable interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GameplayActionBar(
              currentHealth: 40,
              maximumHealth: 100,
              primaryCooldown: GameplaySkillCooldown(
                total: const Duration(milliseconds: 800),
                remaining: const Duration(milliseconds: 360),
              ),
              primaryEngaged: true,
              dodgeCooldown: GameplaySkillCooldown(
                total: playerDodgeCooldown,
                remaining: const Duration(milliseconds: 600),
              ),
              recoveryCooldown: GameplaySkillCooldown(
                total: playerRecoveryCooldown,
                remaining: const Duration(seconds: 6),
              ),
              onPrimary: () {},
              onDodge: () {},
              onRecovery: () {},
              onInteract: null,
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('BASIC STRIKE · 0.4s'), findsOneWidget);
    expect(find.byKey(const Key('primary_skill_cooldown')), findsOneWidget);
    expect(find.byKey(const Key('dodge_skill_cooldown')), findsOneWidget);
    expect(find.byKey(const Key('recovery_skill_cooldown')), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const Key('dodge'))).onTap,
      isNull,
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('interact'))).onTap,
      isNull,
    );
  });

  testWidgets('switches action keycaps to controller prompts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GameplayActionBar(
              currentHealth: 100,
              maximumHealth: 100,
              primaryCooldown: GameplaySkillCooldown(
                total: const Duration(milliseconds: 800),
                remaining: Duration.zero,
              ),
              primaryEngaged: false,
              dodgeCooldown: GameplaySkillCooldown(
                total: playerDodgeCooldown,
                remaining: Duration.zero,
              ),
              recoveryCooldown: GameplaySkillCooldown(
                total: playerRecoveryCooldown,
                remaining: Duration.zero,
              ),
              onPrimary: () {},
              onDodge: () {},
              onRecovery: () {},
              onInteract: () {},
              inputPromptMode: GameInputPromptMode.controller,
            ),
          ),
        ),
      ),
    );

    expect(find.text('X'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Y'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('SPACE'), findsNothing);
    expect(find.text('SHIFT'), findsNothing);
    expect(find.text('E'), findsNothing);
  });
}
