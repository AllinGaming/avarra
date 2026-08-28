import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_controls.dart';
import 'game_experience_settings.dart';
import 'gameplay_character_progression.dart';
import 'gameplay_quest_chronicle.dart';
import 'gameplay_story_archive.dart';

@immutable
final class GameFrontDoorPreview {
  GameFrontDoorPreview({
    required String worldName,
    required String sourceLabel,
    required String missionTitle,
    required String missionText,
  }) : worldName = worldName.trim(),
       sourceLabel = sourceLabel.trim(),
       missionTitle = missionTitle.trim(),
       missionText = missionText.trim() {
    if (this.worldName.isEmpty ||
        this.sourceLabel.isEmpty ||
        this.missionTitle.isEmpty ||
        this.missionText.isEmpty) {
      throw ArgumentError('Front-door preview text must not be empty.');
    }
  }

  final String worldName;
  final String sourceLabel;
  final String missionTitle;
  final String missionText;
}

/// A cinematic, responsive product front door before runtime authority starts.
final class GameFrontDoor extends StatefulWidget {
  const GameFrontDoor({
    required this.preview,
    required this.settings,
    required this.onEnter,
    required this.onWorlds,
    required this.onSettings,
    super.key,
  });

  final GameFrontDoorPreview preview;
  final GameExperienceSettings settings;
  final VoidCallback? onEnter;
  final VoidCallback onWorlds;
  final VoidCallback onSettings;

  @override
  State<GameFrontDoor> createState() => _GameFrontDoorState();
}

final class _GameFrontDoorState extends State<GameFrontDoor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  GameInputPromptMode _inputPromptMode = GameInputPromptMode.keyboard;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(GameFrontDoor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    if (widget.settings.reducedMotion) {
      _controller
        ..stop()
        ..value = 0.18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  KeyEventResult _handlePromptKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final mode = gameInputPromptModeFor(event);
      if (_inputPromptMode != mode) {
        setState(() => _inputPromptMode = mode);
      }
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerInput(PointerDownEvent event) {
    if (_inputPromptMode == GameInputPromptMode.keyboard) return;
    setState(() => _inputPromptMode = GameInputPromptMode.keyboard);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return _GameMenuActivationScope(
      child: Focus(
        onKeyEvent: _handlePromptKeyEvent,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerInput,
          child: Scaffold(
            key: const Key('game_front_door'),
            backgroundColor: const Color(0xFF07080A),
            body: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.42, -0.55),
                      radius: 1.35,
                      colors: [
                        Color(0xFF4D2117),
                        Color(0xFF151013),
                        Color(0xFF06070A),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _AshfallFrontDoorPainter(animation: _controller),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Color(0x11000000),
                        Color(0xD9000000),
                      ],
                      stops: [0, 0.48, 1],
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final title = _FrontDoorTitle(
                        worldName: preview.worldName,
                        sourceLabel: preview.sourceLabel,
                        controlBindings: widget.settings.controlBindings,
                        inputPromptMode: _inputPromptMode,
                        onEnter: widget.onEnter,
                        onWorlds: widget.onWorlds,
                        onSettings: widget.onSettings,
                      );
                      final story = _FrontDoorStory(preview: preview);
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 64 : 22,
                          vertical: wide ? 52 : 28,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - (wide ? 104 : 56),
                            ),
                          ),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(flex: 6, child: title),
                                    const SizedBox(width: 54),
                                    Expanded(flex: 4, child: story),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    title,
                                    const SizedBox(height: 26),
                                    story,
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _FrontDoorTitle extends StatelessWidget {
  const _FrontDoorTitle({
    required this.worldName,
    required this.sourceLabel,
    required this.controlBindings,
    required this.inputPromptMode,
    required this.onEnter,
    required this.onWorlds,
    required this.onSettings,
  });

  final String worldName;
  final String sourceLabel;
  final GameControlBindings controlBindings;
  final GameInputPromptMode inputPromptMode;
  final VoidCallback? onEnter;
  final VoidCallback onWorlds;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'AVARRA Game. $worldName.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A WORLD FORGED IN ASH',
            style: TextStyle(
              color: Color(0xFFE59D51),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.4,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'AVARRA',
              key: const Key('front_door_title'),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: const Color(0xFFFFE4B2),
                fontWeight: FontWeight.w900,
                fontSize: 82,
                letterSpacing: 8,
                height: 0.95,
                shadows: const [
                  Shadow(color: Color(0xFFFF6A2A), blurRadius: 30),
                  Shadow(
                    color: Colors.black,
                    blurRadius: 8,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            worldName.toUpperCase(),
            key: const Key('front_door_world_name'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFD6C5AF),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sourceLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF93877D), fontSize: 12),
          ),
          const SizedBox(height: 30),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const Key('enter_world'),
                  autofocus: onEnter != null,
                  onPressed: onEnter,
                  icon: const Icon(Icons.local_fire_department_rounded),
                  label: Text(
                    onEnter == null ? 'READING THE ASH…' : 'ENTER THE WORLD',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB84B26),
                    foregroundColor: const Color(0xFFFFF0D7),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('front_door_worlds'),
                  onPressed: onWorlds,
                  icon: const Icon(Icons.public),
                  label: const Text('WORLDS & MULTIPLAYER'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('front_door_settings'),
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune),
                  label: const Text('SETTINGS'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            key: const Key('front_door_control_hints'),
            spacing: 16,
            runSpacing: 8,
            children: inputPromptMode == GameInputPromptMode.controller
                ? const [
                    _ControlHint(
                      icon: Icons.gamepad_outlined,
                      text: 'D-PAD · MOVE / TARGET',
                    ),
                    _ControlHint(
                      icon: Icons.sports_esports,
                      text: 'X STRIKE · B DODGE · Y MEND · A USE',
                    ),
                    _ControlHint(icon: Icons.pause, text: 'START · PAUSE'),
                  ]
                : [
                    const _ControlHint(
                      icon: Icons.mouse,
                      text: 'CLICK · MOVE / TARGET',
                    ),
                    _ControlHint(
                      icon: Icons.keyboard,
                      text:
                          '${controlBindings.promptLabelFor(GameControl.moveUp, inputPromptMode)}'
                          '/${controlBindings.promptLabelFor(GameControl.moveLeft, inputPromptMode)}'
                          '/${controlBindings.promptLabelFor(GameControl.moveDown, inputPromptMode)}'
                          '/${controlBindings.promptLabelFor(GameControl.moveRight, inputPromptMode)} MOVE'
                          ' · ${controlBindings.promptLabelFor(GameControl.primarySkill, inputPromptMode)} STRIKE'
                          ' · ${controlBindings.promptLabelFor(GameControl.dodge, inputPromptMode)} DODGE'
                          ' · ${controlBindings.promptLabelFor(GameControl.recovery, inputPromptMode)} MEND'
                          ' · ${controlBindings.promptLabelFor(GameControl.interact, inputPromptMode)} USE',
                    ),
                    const _ControlHint(icon: Icons.pause, text: 'ESC · PAUSE'),
                  ],
          ),
        ],
      ),
    );
  }
}

final class _FrontDoorStory extends StatelessWidget {
  const _FrontDoorStory({required this.preview});

  final GameFrontDoorPreview preview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9110D0C),
        border: const Border(
          left: BorderSide(color: Color(0xFFFFA34F), width: 3),
          top: BorderSide(color: Color(0x557C5A3D)),
          right: BorderSide(color: Color(0x557C5A3D)),
          bottom: BorderSide(color: Color(0x557C5A3D)),
        ),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 28)],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'THE CALL',
              style: TextStyle(
                color: Color(0xFFFFA34F),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preview.missionTitle,
              key: const Key('front_door_mission_title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFFFE2B6),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              preview.missionText,
              key: const Key('front_door_mission_text'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFD7C9B8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0x557C5A3D)),
            const SizedBox(height: 8),
            const Text(
              'Every world carries its own danger, history, and last hope.',
              style: TextStyle(
                color: Color(0xFFA99A89),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ControlHint extends StatelessWidget {
  const _ControlHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFFAA7950), size: 16),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9B8D80),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    ],
  );
}

/// Full-screen authored prologue shown before first simulation movement.
final class GameMissionBriefingOverlay extends StatelessWidget {
  const GameMissionBriefingOverlay({
    required this.worldName,
    required this.chapterLabel,
    required this.missionTitle,
    required this.missionText,
    required this.objective,
    required this.onBegin,
    super.key,
  });

  final String worldName;
  final String chapterLabel;
  final String missionTitle;
  final String missionText;
  final String objective;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    return _GameMenuActivationScope(
      child: ColoredBox(
        key: const Key('mission_briefing_overlay'),
        color: const Color(0xF20A0808),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 660),
                child: Semantics(
                  liveRegion: true,
                  label: '$chapterLabel. Prologue. $missionTitle. $missionText',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        worldName.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFB58C63),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFFF9A48),
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        chapterLabel,
                        key: const Key('mission_briefing_chapter'),
                        style: const TextStyle(
                          color: Color(0xFFB58C63),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'PROLOGUE',
                        style: TextStyle(
                          color: Color(0xFFFFA34F),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        missionTitle,
                        key: const Key('mission_briefing_title'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: const Color(0xFFFFE0B0),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        missionText,
                        key: const Key('mission_briefing_text'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFD6C9B9),
                              height: 1.55,
                            ),
                      ),
                      const SizedBox(height: 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF17110E),
                          border: Border.all(color: const Color(0xFF6D4C32)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.outlined_flag,
                                color: Color(0xFFFFB55D),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  objective,
                                  key: const Key('mission_briefing_objective'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('begin_mission'),
                        autofocus: true,
                        onPressed: onBegin,
                        icon: const Icon(Icons.local_fire_department),
                        label: const Text('BEGIN THE JOURNEY'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB84B26),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking victory recap shown only when the local player newly completes an
/// authored mission.
final class GameMissionCompleteOverlay extends StatelessWidget {
  const GameMissionCompleteOverlay({
    required this.worldName,
    required this.chapterLabel,
    required this.missionTitle,
    required this.missionText,
    required this.completionLabel,
    required this.inventory,
    required this.playerStatus,
    required this.connectedSession,
    required this.reducedMotion,
    this.inputPromptMode = GameInputPromptMode.keyboard,
    required this.onContinue,
    required this.onReturnToTitle,
    super.key,
  });

  final String worldName;
  final String chapterLabel;
  final String missionTitle;
  final String missionText;
  final String completionLabel;
  final String inventory;
  final String playerStatus;
  final bool connectedSession;
  final bool reducedMotion;
  final GameInputPromptMode inputPromptMode;
  final VoidCallback onContinue;
  final VoidCallback onReturnToTitle;

  @override
  Widget build(BuildContext context) {
    return _GameMenuActivationScope(
      child: ColoredBox(
        key: const Key('mission_complete_overlay'),
        color: const Color(0xF5070808),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 1.15,
              colors: [Color(0xFF3E2A13), Color(0xFF17110C), Color(0xFF070808)],
              stops: [0, 0.48, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: TweenAnimationBuilder<double>(
                  key: const Key('mission_complete_reveal'),
                  tween: Tween(begin: 0, end: 1),
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 680),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Semantics(
                      key: const Key('mission_complete_semantics'),
                      container: true,
                      liveRegion: true,
                      label:
                          '$chapterLabel. Mission complete. '
                          '$missionTitle. $missionText. '
                          '$completionLabel.',
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xF21A130D),
                          border: Border.all(
                            color: const Color(0xFFC99045),
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xAA000000),
                              blurRadius: 42,
                              spreadRadius: 4,
                            ),
                            BoxShadow(color: Color(0x447F4A17), blurRadius: 28),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                worldName.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFBDA27C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFFFC768),
                                size: 44,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                chapterLabel,
                                key: const Key('mission_complete_chapter'),
                                style: const TextStyle(
                                  color: Color(0xFFBDA27C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'MISSION COMPLETE',
                                style: TextStyle(
                                  color: Color(0xFFFFD992),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.4,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                missionTitle,
                                key: const Key('mission_complete_title'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      color: const Color(0xFFFFE6B6),
                                      fontWeight: FontWeight.w900,
                                      height: 1.08,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                missionText,
                                key: const Key('mission_complete_text'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: const Color(0xFFE0D3C1),
                                      height: 1.5,
                                    ),
                              ),
                              const SizedBox(height: 22),
                              const Divider(color: Color(0xFF745632)),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _MissionCompleteResult(
                                    icon: Icons.outlined_flag,
                                    label: 'OATH FULFILLED',
                                    value: completionLabel,
                                  ),
                                  _MissionCompleteResult(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'CARRIED FORWARD',
                                    value: inventory,
                                  ),
                                  _MissionCompleteResult(
                                    icon: Icons.favorite_outline,
                                    label: 'CHAMPION',
                                    value: playerStatus,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                connectedSession
                                    ? 'ONLINE SESSION CONTINUES WHILE YOU REVIEW'
                                    : 'THE ASH SETTLES AROUND THE RELAY',
                                key: const Key('mission_complete_session_note'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFAA9273),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    key: const Key(
                                      'continue_after_mission_complete',
                                    ),
                                    autofocus: true,
                                    onPressed: onContinue,
                                    icon: const Icon(Icons.explore_outlined),
                                    label: const Text('CONTINUE EXPLORING'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFB85C27),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 15,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    key: const Key(
                                      'mission_complete_return_to_title',
                                    ),
                                    onPressed: onReturnToTitle,
                                    icon: const Icon(Icons.home_outlined),
                                    label: const Text('RETURN TO TITLE'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${gamePausePrompt(inputPromptMode)} · CONTINUE',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF8D8074),
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _MissionCompleteResult extends StatelessWidget {
  const _MissionCompleteResult({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 218,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA100D0A),
        border: Border.all(color: const Color(0xFF60492F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFD0A35B), size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC2A77E),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF0E3D0),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum GameplayPauseStorySection { journey, lore }

/// Blocking in-game menu with current authored story and progression context.
final class GameplayPauseOverlay extends StatelessWidget {
  const GameplayPauseOverlay({
    required this.worldName,
    required this.missionTitle,
    required this.missionText,
    required this.objective,
    required this.inventory,
    this.characterProgression,
    required this.connectedSession,
    this.questChapters = const [],
    this.storyArchiveChapters = const [],
    this.initialStorySection = GameplayPauseStorySection.journey,
    this.highlightedStoryEntryKeys = const [],
    this.onStoryDiscoveriesReviewed,
    this.reducedMotion = false,
    this.inputPromptMode = GameInputPromptMode.keyboard,
    required this.onResume,
    required this.onSettings,
    required this.onWorlds,
    required this.onReturnToTitle,
    super.key,
  });

  final String worldName;
  final String missionTitle;
  final String missionText;
  final String objective;
  final String inventory;
  final GameCharacterProgression? characterProgression;
  final bool connectedSession;
  final List<GameQuestChronicleChapter> questChapters;
  final List<GameStoryArchiveChapter> storyArchiveChapters;
  final GameplayPauseStorySection initialStorySection;
  final List<String> highlightedStoryEntryKeys;
  final VoidCallback? onStoryDiscoveriesReviewed;
  final bool reducedMotion;
  final GameInputPromptMode inputPromptMode;
  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onWorlds;
  final VoidCallback onReturnToTitle;

  @override
  Widget build(BuildContext context) {
    return _GameMenuActivationScope(
      child: ColoredBox(
        key: const Key('gameplay_pause_overlay'),
        color: const Color(0xE8100C0D),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFA171210),
                    border: Border.all(color: const Color(0xFF765235)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, blurRadius: 36),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 620;
                        final actions = _PauseActions(
                          onResume: onResume,
                          onSettings: onSettings,
                          onWorlds: onWorlds,
                          onReturnToTitle: onReturnToTitle,
                          inputPromptMode: inputPromptMode,
                        );
                        final story = _PauseStory(
                          worldName: worldName,
                          missionTitle: missionTitle,
                          missionText: missionText,
                          objective: objective,
                          inventory: inventory,
                          characterProgression: characterProgression,
                          connectedSession: connectedSession,
                          questChapters: questChapters,
                          storyArchiveChapters: storyArchiveChapters,
                          initialStorySection: initialStorySection,
                          highlightedStoryEntryKeys: highlightedStoryEntryKeys,
                          onStoryDiscoveriesReviewed:
                              onStoryDiscoveriesReviewed,
                          reducedMotion: reducedMotion,
                        );
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 230, child: actions),
                                  const SizedBox(width: 28),
                                  Expanded(child: story),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  story,
                                  const SizedBox(height: 22),
                                  actions,
                                ],
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PauseActions extends StatelessWidget {
  const _PauseActions({
    required this.onResume,
    required this.onSettings,
    required this.onWorlds,
    required this.onReturnToTitle,
    required this.inputPromptMode,
  });

  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onWorlds;
  final VoidCallback onReturnToTitle;
  final GameInputPromptMode inputPromptMode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'PAUSED',
        style: TextStyle(
          color: Color(0xFFFFD89B),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        key: const Key('resume_game'),
        autofocus: true,
        onPressed: onResume,
        icon: const Icon(Icons.play_arrow),
        label: const Text('RESUME'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('pause_settings'),
        onPressed: onSettings,
        icon: const Icon(Icons.tune),
        label: const Text('SETTINGS'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('pause_worlds'),
        onPressed: onWorlds,
        icon: const Icon(Icons.public),
        label: const Text('WORLDS'),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        key: const Key('return_to_title'),
        onPressed: onReturnToTitle,
        icon: const Icon(Icons.home_outlined),
        label: const Text('RETURN TO TITLE'),
      ),
      const SizedBox(height: 12),
      Text(
        '${gamePausePrompt(inputPromptMode)} · RESUME',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF8D8074),
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

final class _GameMenuActivationScope extends StatelessWidget {
  const _GameMenuActivationScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.gameButton1): ActivateIntent(),
    },
    child: FocusTraversalGroup(child: child),
  );
}

final class _PauseStory extends StatelessWidget {
  const _PauseStory({
    required this.worldName,
    required this.missionTitle,
    required this.missionText,
    required this.objective,
    required this.inventory,
    required this.characterProgression,
    required this.connectedSession,
    required this.questChapters,
    required this.storyArchiveChapters,
    required this.initialStorySection,
    required this.highlightedStoryEntryKeys,
    required this.onStoryDiscoveriesReviewed,
    required this.reducedMotion,
  });

  final String worldName;
  final String missionTitle;
  final String missionText;
  final String objective;
  final String inventory;
  final GameCharacterProgression? characterProgression;
  final bool connectedSession;
  final List<GameQuestChronicleChapter> questChapters;
  final List<GameStoryArchiveChapter> storyArchiveChapters;
  final GameplayPauseStorySection initialStorySection;
  final List<String> highlightedStoryEntryKeys;
  final VoidCallback? onStoryDiscoveriesReviewed;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          worldName.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFAE8260),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          missionTitle,
          key: const Key('pause_mission_title'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFFFFDDA8),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          missionText,
          key: const Key('pause_mission_text'),
          style: const TextStyle(color: Color(0xFFCABDAC), height: 1.4),
        ),
        if (characterProgression case final progression?) ...[
          const SizedBox(height: 16),
          GameplayCharacterProgressionPanel(progression: progression),
        ],
        if (questChapters.isNotEmpty || storyArchiveChapters.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PauseStoryPanels(
            questChapters: questChapters,
            archiveChapters: storyArchiveChapters,
            initialSection: initialStorySection,
            highlightedEntryKeys: highlightedStoryEntryKeys,
            onDiscoveriesReviewed: onStoryDiscoveriesReviewed,
            reducedMotion: reducedMotion,
          ),
        ],
        const SizedBox(height: 16),
        _PauseFact(icon: Icons.outlined_flag, label: objective),
        const SizedBox(height: 8),
        _PauseFact(icon: Icons.inventory_2_outlined, label: inventory),
        if (connectedSession) ...[
          const SizedBox(height: 14),
          const Text(
            'ONLINE SESSION CONTINUES WHILE THIS MENU IS OPEN',
            style: TextStyle(
              color: Color(0xFFFF9368),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }
}

final class _PauseStoryPanels extends StatefulWidget {
  const _PauseStoryPanels({
    required this.questChapters,
    required this.archiveChapters,
    required this.initialSection,
    required this.highlightedEntryKeys,
    required this.onDiscoveriesReviewed,
    required this.reducedMotion,
  });

  final List<GameQuestChronicleChapter> questChapters;
  final List<GameStoryArchiveChapter> archiveChapters;
  final GameplayPauseStorySection initialSection;
  final List<String> highlightedEntryKeys;
  final VoidCallback? onDiscoveriesReviewed;
  final bool reducedMotion;

  @override
  State<_PauseStoryPanels> createState() => _PauseStoryPanelsState();
}

final class _PauseStoryPanelsState extends State<_PauseStoryPanels> {
  late GameplayPauseStorySection _section;

  @override
  void initState() {
    super.initState();
    _section = _availableSection(widget.initialSection);
  }

  @override
  void didUpdateWidget(_PauseStoryPanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _section = _availableSection(widget.initialSection);
    } else if (_section == GameplayPauseStorySection.lore &&
        widget.archiveChapters.isEmpty &&
        widget.questChapters.isNotEmpty) {
      _section = GameplayPauseStorySection.journey;
    } else if (_section == GameplayPauseStorySection.journey &&
        widget.questChapters.isEmpty &&
        widget.archiveChapters.isNotEmpty) {
      _section = GameplayPauseStorySection.lore;
    }
  }

  GameplayPauseStorySection _availableSection(
    GameplayPauseStorySection requested,
  ) {
    if (requested == GameplayPauseStorySection.lore &&
        widget.archiveChapters.isNotEmpty) {
      return GameplayPauseStorySection.lore;
    }
    if (requested == GameplayPauseStorySection.journey &&
        widget.questChapters.isNotEmpty) {
      return GameplayPauseStorySection.journey;
    }
    return widget.archiveChapters.isNotEmpty
        ? GameplayPauseStorySection.lore
        : GameplayPauseStorySection.journey;
  }

  void _show(GameplayPauseStorySection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final discoveryEntryKeys = _validStoryDiscoveryEntryKeys(
      chapters: widget.archiveChapters,
      highlightedEntryKeys: widget.highlightedEntryKeys,
    );
    final duration = widget.reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PauseStoryTabs(
          section: _section,
          journeyEnabled: widget.questChapters.isNotEmpty,
          loreEnabled: widget.archiveChapters.isNotEmpty,
          pendingLoreCount: discoveryEntryKeys.length,
          onSelected: _show,
        ),
        const SizedBox(height: 9),
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _section == GameplayPauseStorySection.journey
              ? _PauseJourneyPanel(
                  key: const ValueKey('pause_journey_panel'),
                  chapters: widget.questChapters,
                )
              : _PauseLorePanel(
                  key: const ValueKey('pause_lore_panel'),
                  chapters: widget.archiveChapters,
                  highlightedEntryKeys: discoveryEntryKeys,
                  onDiscoveriesReviewed: widget.onDiscoveriesReviewed,
                  reducedMotion: widget.reducedMotion,
                ),
        ),
      ],
    );
  }
}

final class _PauseStoryTabs extends StatelessWidget {
  const _PauseStoryTabs({
    required this.section,
    required this.journeyEnabled,
    required this.loreEnabled,
    required this.pendingLoreCount,
    required this.onSelected,
  });

  final GameplayPauseStorySection section;
  final bool journeyEnabled;
  final bool loreEnabled;
  final int pendingLoreCount;
  final ValueChanged<GameplayPauseStorySection> onSelected;

  String? get _pendingLoreLabel =>
      pendingLoreCount > 0 ? '$pendingLoreCount NEW' : null;

  String get _loreSemanticsLabel => switch (pendingLoreCount) {
    0 => 'Lore tab',
    1 => 'Lore tab. 1 new memory awaiting review.',
    _ => 'Lore tab. $pendingLoreCount new memories awaiting review.',
  };

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _PauseStoryTab(
          key: const Key('pause_journey_tab'),
          icon: Icons.route_outlined,
          label: 'JOURNEY',
          selected: section == GameplayPauseStorySection.journey,
          onPressed: journeyEnabled
              ? () => onSelected(GameplayPauseStorySection.journey)
              : null,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _PauseStoryTab(
          key: const Key('pause_lore_tab'),
          icon: Icons.menu_book_outlined,
          label: 'LORE',
          badgeLabel: _pendingLoreLabel,
          semanticsLabel: _loreSemanticsLabel,
          selected: section == GameplayPauseStorySection.lore,
          onPressed: loreEnabled
              ? () => onSelected(GameplayPauseStorySection.lore)
              : null,
        ),
      ),
    ],
  );
}

final class _PauseStoryTab extends StatelessWidget {
  const _PauseStoryTab({
    required this.icon,
    required this.label,
    this.badgeLabel,
    this.semanticsLabel,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? badgeLabel;
  final String? semanticsLabel;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFB55D) : const Color(0xFF9F8D78);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? '$label tab',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: selected
              ? const Color(0x332F1D0E)
              : const Color(0x44100C0A),
          side: BorderSide(
            color: selected ? const Color(0xFF9B6332) : const Color(0x5576573D),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
        icon: Icon(icon, size: 16),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              if (badgeLabel case final badge?) ...[
                const SizedBox(width: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x332F1D0E),
                    border: Border.all(color: const Color(0xAAAE6F32)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      badge,
                      key: const Key('pause_lore_pending_badge'),
                      style: const TextStyle(
                        color: Color(0xFFFFC46B),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _validStoryDiscoveryEntryKeys({
  required List<GameStoryArchiveChapter> chapters,
  required List<String> highlightedEntryKeys,
}) {
  final revealedEntryKeys = {
    for (final chapter in chapters)
      for (final entry in chapter.entries)
        if (entry.isRevealed) entry.stableKey,
  };
  final addedEntryKeys = <String>{};
  return [
    for (final entryKey in highlightedEntryKeys)
      if (revealedEntryKeys.contains(entryKey) && addedEntryKeys.add(entryKey))
        entryKey,
  ];
}

final class _PauseJourneyPanel extends StatelessWidget {
  const _PauseJourneyPanel({required this.chapters, super.key});

  final List<GameQuestChronicleChapter> chapters;

  @override
  Widget build(BuildContext context) {
    final entries = [for (final chapter in chapters) ...chapter.entries];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'REQUIRED PATH',
              style: TextStyle(
                color: Color(0xFFFFB55D),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const Spacer(),
            Text(
              '${entries.where((entry) => entry.state == GameQuestChronicleEntryState.completed).length}'
              '/${entries.length}',
              key: const Key('quest_chronicle_progress'),
              style: const TextStyle(
                color: Color(0xFF9F8D78),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x99100C0A),
            border: Border.all(color: const Color(0x5576573D)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                for (
                  var chapterIndex = 0;
                  chapterIndex < chapters.length;
                  chapterIndex++
                ) ...[
                  if (chapterIndex > 0)
                    const Divider(height: 16, color: Color(0x4476573D)),
                  _QuestChronicleChapterHeader(chapter: chapters[chapterIndex]),
                  for (
                    var entryIndex = 0;
                    entryIndex < chapters[chapterIndex].entries.length;
                    entryIndex++
                  )
                    _QuestChronicleRow(
                      chapterNumber: chapters[chapterIndex].chapterNumber,
                      index: entryIndex,
                      entry: chapters[chapterIndex].entries[entryIndex],
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _PauseLorePanel extends StatefulWidget {
  const _PauseLorePanel({
    required this.chapters,
    required this.highlightedEntryKeys,
    required this.onDiscoveriesReviewed,
    required this.reducedMotion,
    super.key,
  });

  final List<GameStoryArchiveChapter> chapters;
  final List<String> highlightedEntryKeys;
  final VoidCallback? onDiscoveriesReviewed;
  final bool reducedMotion;

  @override
  State<_PauseLorePanel> createState() => _PauseLorePanelState();
}

final class _PauseLorePanelState extends State<_PauseLorePanel> {
  final GlobalKey _highlightedRowKey = GlobalKey(
    debugLabel: 'latest_story_archive_entry',
  );
  int? _selectedDiscoveryIndex;
  String? _scheduledEntryKey;

  @override
  void didUpdateWidget(_PauseLorePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameEntryKeys(
      oldWidget.highlightedEntryKeys,
      widget.highlightedEntryKeys,
    )) {
      _selectedDiscoveryIndex = null;
      _scheduledEntryKey = null;
    }
  }

  bool _sameEntryKeys(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _showDiscovery(int index) {
    if (_selectedDiscoveryIndex == index) return;
    setState(() {
      _selectedDiscoveryIndex = index;
      _scheduledEntryKey = null;
    });
  }

  void _scheduleHighlightedEntryScroll(String entryKey) {
    if (_scheduledEntryKey == entryKey) return;
    _scheduledEntryKey = entryKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduledEntryKey != entryKey) return;
      final targetContext = _highlightedRowKey.currentContext;
      if (targetContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.2,
          duration: widget.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = [for (final chapter in widget.chapters) ...chapter.entries];
    final revealedCount = entries.where((entry) => entry.isRevealed).length;
    final discoveryEntryKeys = _validStoryDiscoveryEntryKeys(
      chapters: widget.chapters,
      highlightedEntryKeys: widget.highlightedEntryKeys,
    );
    final selectedDiscoveryIndex = discoveryEntryKeys.isEmpty
        ? null
        : switch (_selectedDiscoveryIndex) {
            final index
                when index != null && index < discoveryEntryKeys.length =>
              index,
            _ => discoveryEntryKeys.length - 1,
          };
    final highlightedEntryKey = selectedDiscoveryIndex == null
        ? null
        : discoveryEntryKeys[selectedDiscoveryIndex];
    if (highlightedEntryKey != null) {
      _scheduleHighlightedEntryScroll(highlightedEntryKey);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'STORY ARCHIVE',
              style: TextStyle(
                color: Color(0xFFD7A76C),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const Spacer(),
            Text(
              '$revealedCount/${entries.length} MEMORIES',
              key: const Key('story_archive_progress'),
              style: const TextStyle(
                color: Color(0xFF9F8D78),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xCC160F0B), Color(0xCC0D0A09)],
            ),
            border: Border.all(color: const Color(0x6676573D)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                for (
                  var chapterIndex = 0;
                  chapterIndex < widget.chapters.length;
                  chapterIndex++
                ) ...[
                  if (chapterIndex > 0)
                    const Divider(height: 18, color: Color(0x5576573D)),
                  _StoryArchiveChapterHeader(
                    chapter: widget.chapters[chapterIndex],
                  ),
                  for (final entry
                      in widget.chapters[chapterIndex].entries) ...[
                    if (entry.stableKey == highlightedEntryKey &&
                        selectedDiscoveryIndex != null &&
                        discoveryEntryKeys.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 3, 10, 5),
                        child: _StoryDiscoveryNavigator(
                          selectedIndex: selectedDiscoveryIndex,
                          count: discoveryEntryKeys.length,
                          onPrevious: selectedDiscoveryIndex > 0
                              ? () => _showDiscovery(selectedDiscoveryIndex - 1)
                              : null,
                          onNext:
                              selectedDiscoveryIndex <
                                  discoveryEntryKeys.length - 1
                              ? () => _showDiscovery(selectedDiscoveryIndex + 1)
                              : null,
                          onReviewed: widget.onDiscoveriesReviewed,
                        ),
                      ),
                    _StoryArchiveEntryRow(
                      key: entry.stableKey == highlightedEntryKey
                          ? _highlightedRowKey
                          : null,
                      entry: entry,
                      discoveryIndex: entry.stableKey == highlightedEntryKey
                          ? selectedDiscoveryIndex
                          : null,
                      discoveryCount: discoveryEntryKeys.length,
                      onReviewed: discoveryEntryKeys.length == 1
                          ? widget.onDiscoveriesReviewed
                          : null,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _StoryDiscoveryNavigator extends StatelessWidget {
  const _StoryDiscoveryNavigator({
    required this.selectedIndex,
    required this.count,
    required this.onPrevious,
    required this.onNext,
    required this.onReviewed,
  }) : assert(selectedIndex >= 0),
       assert(selectedIndex < count);

  final int selectedIndex;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReviewed;

  @override
  Widget build(BuildContext context) {
    final position = selectedIndex + 1;
    return Semantics(
      key: const Key('story_archive_discovery_navigator'),
      container: true,
      label: 'New story discoveries. Showing $position of $count.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xAA2A190C),
          border: Border.all(color: const Color(0x99D7A76C)),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('previous_story_discovery'),
              tooltip: 'Previous new memory',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              color: const Color(0xFFFFD68F),
              disabledColor: const Color(0xFF625A54),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEW DISCOVERIES',
                    style: TextStyle(
                      color: Color(0xFFD7A76C),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$position OF $count',
                    key: const Key('story_archive_discovery_position'),
                    style: const TextStyle(
                      color: Color(0xFFFFE8C6),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('next_story_discovery'),
              tooltip: 'Next new memory',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              color: const Color(0xFFFFD68F),
              disabledColor: const Color(0xFF625A54),
              visualDensity: VisualDensity.compact,
            ),
            if (onReviewed != null)
              IconButton(
                key: const Key('mark_story_discoveries_reviewed'),
                tooltip: 'Mark new memories reviewed',
                onPressed: onReviewed,
                icon: const Icon(Icons.done_all),
                color: const Color(0xFF80BF7D),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

final class _StoryArchiveChapterHeader extends StatelessWidget {
  const _StoryArchiveChapterHeader({required this.chapter});

  final GameStoryArchiveChapter chapter;

  @override
  Widget build(BuildContext context) {
    final (stateLabel, color, icon) = switch (chapter.state) {
      GameStoryArchiveChapterState.completed => (
        'COMPLETE',
        const Color(0xFF80BF7D),
        Icons.auto_stories,
      ),
      GameStoryArchiveChapterState.active => (
        'OPEN',
        const Color(0xFFFFB55D),
        Icons.book_outlined,
      ),
      GameStoryArchiveChapterState.locked => (
        'SEALED',
        const Color(0xFF756A61),
        Icons.lock_outline,
      ),
    };
    return Semantics(
      key: ValueKey('story_archive_chapter_${chapter.chapterNumber}'),
      header: true,
      label:
          '${chapter.chapterLabel}. ${chapter.title}. $stateLabel. '
          '${chapter.revealedCount} of ${chapter.entries.length} memories discovered.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.chapterLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFDDA8),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stateLabel,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _StoryArchiveEntryRow extends StatelessWidget {
  const _StoryArchiveEntryRow({
    required this.entry,
    required this.discoveryIndex,
    required this.discoveryCount,
    required this.onReviewed,
    super.key,
  });

  final GameStoryArchiveEntry entry;
  final int? discoveryIndex;
  final int discoveryCount;
  final VoidCallback? onReviewed;

  @override
  Widget build(BuildContext context) {
    final revealed = entry.isRevealed;
    final highlighted = discoveryIndex != null;
    final discoveryPosition = highlighted ? discoveryIndex! + 1 : null;
    final discoverySemantic = !highlighted
        ? ''
        : discoveryCount > 1
        ? 'Newly discovered memory $discoveryPosition of $discoveryCount. '
        : 'Latest discovered memory. ';
    final discoveryLabel = discoveryCount > 1
        ? 'NEW MEMORY $discoveryPosition OF $discoveryCount'
        : 'LATEST MEMORY';
    final color = highlighted
        ? const Color(0xFFFFD68F)
        : revealed
        ? const Color(0xFFD7A76C)
        : const Color(0xFF625A54);
    final text = entry.text;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 3, 10, 5),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xAA33200F)
            : revealed
            ? const Color(0x661B130E)
            : const Color(0x44100D0B),
        border: highlighted
            ? Border.all(color: color, width: 1.5)
            : Border(
                left: BorderSide(color: color, width: revealed ? 2 : 1),
              ),
        boxShadow: highlighted
            ? const [
                BoxShadow(
                  color: Color(0x44FFB957),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            highlighted
                ? Icons.auto_awesome
                : revealed
                ? Icons.menu_book
                : Icons.lock_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              key: ValueKey('story_archive_entry_${entry.stableKey}'),
              container: true,
              excludeSemantics: true,
              label: revealed
                  ? '$discoverySemantic'
                        '${entry.kindLabel}. ${entry.label}. $text'
                  : '${entry.kindLabel}. ${entry.label}. Undiscovered.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlighted) ...[
                    Text(
                      discoveryLabel,
                      key: ValueKey('story_archive_latest_${entry.stableKey}'),
                      style: const TextStyle(
                        color: Color(0xFFFFD68F),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    entry.kindLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.label,
                    style: TextStyle(
                      color: revealed
                          ? highlighted
                                ? const Color(0xFFFFE8C6)
                                : const Color(0xFFE8D8C3)
                          : const Color(0xFF82766C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (text != null)
                    Text(
                      text,
                      style: const TextStyle(
                        color: Color(0xFFCDBFAE),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    )
                  else
                    const Text(
                      'UNDISCOVERED MEMORY',
                      style: TextStyle(
                        color: Color(0xFF625A54),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (highlighted && onReviewed != null) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const Key('mark_story_discoveries_reviewed'),
              tooltip: 'Mark new memory reviewed',
              onPressed: onReviewed,
              icon: const Icon(Icons.done),
              color: const Color(0xFF80BF7D),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

final class _QuestChronicleChapterHeader extends StatelessWidget {
  const _QuestChronicleChapterHeader({required this.chapter});

  final GameQuestChronicleChapter chapter;

  @override
  Widget build(BuildContext context) {
    final (stateLabel, color) = switch (chapter.state) {
      GameQuestChronicleChapterState.completed => (
        'COMPLETE',
        const Color(0xFF80BF7D),
      ),
      GameQuestChronicleChapterState.current => (
        'ACTIVE',
        const Color(0xFFFFB55D),
      ),
      GameQuestChronicleChapterState.pending => (
        'UP NEXT',
        const Color(0xFF8A7E72),
      ),
    };
    return Semantics(
      key: ValueKey('quest_chronicle_chapter_${chapter.chapterNumber}'),
      header: true,
      label: '${chapter.chapterLabel}. ${chapter.title}. $stateLabel',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.chapterLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFDDA8),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color.withValues(alpha: 0.55)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _QuestChronicleRow extends StatelessWidget {
  const _QuestChronicleRow({
    required this.chapterNumber,
    required this.index,
    required this.entry,
  });

  final int chapterNumber;
  final int index;
  final GameQuestChronicleEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, stateLabel) = switch (entry.state) {
      GameQuestChronicleEntryState.completed => (
        Icons.check_circle,
        const Color(0xFF80BF7D),
        'Completed',
      ),
      GameQuestChronicleEntryState.current => (
        Icons.adjust,
        const Color(0xFFFFB55D),
        'Current',
      ),
      GameQuestChronicleEntryState.pending => (
        Icons.circle_outlined,
        const Color(0xFF6E6258),
        'Pending',
      ),
    };
    return Semantics(
      label: '$stateLabel: ${entry.label}',
      child: Padding(
        key: ValueKey('quest_chronicle_entry_${chapterNumber}_$index'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  color: entry.state == GameQuestChronicleEntryState.pending
                      ? const Color(0xFF8A7E72)
                      : const Color(0xFFE7D8C5),
                  fontSize: 12,
                  fontWeight:
                      entry.state == GameQuestChronicleEntryState.current
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PauseFact extends StatelessWidget {
  const _PauseFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFFFFA34F), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
    ],
  );
}

final class _AshfallFrontDoorPainter extends CustomPainter {
  _AshfallFrontDoorPainter({required Animation<double> animation})
    : _animation = animation,
      super(repaint: animation);

  final Animation<double> _animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final progress = _animation.value;
    final horizon = size.height * 0.7;
    final silhouette = Path()
      ..moveTo(0, horizon)
      ..lineTo(size.width * 0.1, horizon * 0.92)
      ..lineTo(size.width * 0.16, horizon)
      ..lineTo(size.width * 0.22, horizon * 0.78)
      ..lineTo(size.width * 0.26, horizon)
      ..lineTo(size.width * 0.34, horizon * 0.88)
      ..lineTo(size.width * 0.42, horizon)
      ..lineTo(size.width * 0.5, horizon * 0.73)
      ..lineTo(size.width * 0.54, horizon)
      ..lineTo(size.width * 0.7, horizon * 0.9)
      ..lineTo(size.width * 0.79, horizon)
      ..lineTo(size.width * 0.88, horizon * 0.8)
      ..lineTo(size.width * 0.92, horizon)
      ..lineTo(size.width, horizon * 0.9)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(silhouette, Paint()..color = const Color(0xE6060709));

    final ember = Paint()..blendMode = BlendMode.screen;
    for (var index = 0; index < 34; index++) {
      final seed = _fraction(index * 0.6180339 + 0.17);
      final travel = _fraction(seed + progress * (0.11 + index % 5 * 0.012));
      final x =
          _fraction(seed * 8.7 + progress * (0.018 + index % 3 * 0.009)) *
          size.width;
      final y = size.height * (0.96 - travel * 0.88);
      final glow = 0.35 + 0.65 * math.sin((travel + seed) * math.pi).abs();
      ember.color = const Color(
        0xFFFF8A3D,
      ).withValues(alpha: 0.16 + glow * 0.42);
      canvas.drawCircle(Offset(x, y), 0.7 + (index % 4) * 0.45, ember);
    }
  }

  @override
  bool shouldRepaint(_AshfallFrontDoorPainter oldDelegate) => false;
}

double _fraction(double value) => value - value.floorToDouble();
