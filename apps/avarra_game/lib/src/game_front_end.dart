import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_experience_settings.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return Scaffold(
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }
}

final class _FrontDoorTitle extends StatelessWidget {
  const _FrontDoorTitle({
    required this.worldName,
    required this.sourceLabel,
    required this.onEnter,
    required this.onWorlds,
    required this.onSettings,
  });

  final String worldName;
  final String sourceLabel;
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
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _ControlHint(icon: Icons.mouse, text: 'CLICK · MOVE / TARGET'),
              _ControlHint(icon: Icons.keyboard, text: 'WASD · SPACE · E'),
              _ControlHint(icon: Icons.pause, text: 'ESC · PAUSE'),
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
    required this.missionTitle,
    required this.missionText,
    required this.objective,
    required this.onBegin,
    super.key,
  });

  final String worldName;
  final String missionTitle;
  final String missionText;
  final String objective;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
                label: 'Prologue. $missionTitle. $missionText',
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }
}

/// Blocking in-game menu with current authored story and progression context.
final class GameplayPauseOverlay extends StatelessWidget {
  const GameplayPauseOverlay({
    required this.worldName,
    required this.missionTitle,
    required this.missionText,
    required this.objective,
    required this.inventory,
    required this.connectedSession,
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
  final bool connectedSession;
  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onWorlds;
  final VoidCallback onReturnToTitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
                      );
                      final story = _PauseStory(
                        worldName: worldName,
                        missionTitle: missionTitle,
                        missionText: missionText,
                        objective: objective,
                        inventory: inventory,
                        connectedSession: connectedSession,
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
    );
  }
}

final class _PauseActions extends StatelessWidget {
  const _PauseActions({
    required this.onResume,
    required this.onSettings,
    required this.onWorlds,
    required this.onReturnToTitle,
  });

  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onWorlds;
  final VoidCallback onReturnToTitle;

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
      const Text(
        'ESC · RESUME',
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

final class _PauseStory extends StatelessWidget {
  const _PauseStory({
    required this.worldName,
    required this.missionTitle,
    required this.missionText,
    required this.objective,
    required this.inventory,
    required this.connectedSession,
  });

  final String worldName;
  final String missionTitle;
  final String missionText;
  final String objective;
  final String inventory;
  final bool connectedSession;

  @override
  Widget build(BuildContext context) => Column(
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
