import 'dart:math' as math;

import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

enum GameplayDestinationKind { move, attack, interact }

/// Immutable presentation target for one active movement/action approach.
final class GameplayDestinationIndicator {
  GameplayDestinationIndicator({
    required this.kind,
    required Vector3 worldPosition,
  }) : _worldPosition = Vector3.copy(worldPosition) {
    if (!_worldPosition.storage.every((value) => value.isFinite)) {
      throw ArgumentError.value(
        worldPosition,
        'worldPosition',
        'Must be finite.',
      );
    }
  }

  final GameplayDestinationKind kind;
  final Vector3 _worldPosition;

  Vector3 get worldPosition => Vector3.copy(_worldPosition);
}

/// Pointer-transparent, projected feedback for the current action destination.
final class GameplayDestinationOverlay extends StatefulWidget {
  const GameplayDestinationOverlay({
    required this.indicator,
    required this.cameraRig,
    super.key,
  });

  final GameplayDestinationIndicator? indicator;
  final IsometricCameraRig cameraRig;

  @override
  State<GameplayDestinationOverlay> createState() =>
      _GameplayDestinationOverlayState();
}

final class _GameplayDestinationOverlayState
    extends State<GameplayDestinationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(GameplayDestinationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.indicator == null) {
      _controller
        ..stop()
        ..value = 0;
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
    return IgnorePointer(
      key: const Key('gameplay_destination_indicator'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final indicator = widget.indicator;
            final size = constraints.biggest;
            if (indicator == null || size.isEmpty) {
              return const SizedBox.shrink();
            }
            final point = widget.cameraRig.screenPointForWorld(
              worldPoint: indicator.worldPosition + Vector3(0, 0.04, 0),
              viewportWidth: size.width,
              viewportHeight: size.height,
            );
            if (point.x < -50 ||
                point.x > size.width + 50 ||
                point.y < -30 ||
                point.y > size.height + 30) {
              return const SizedBox.shrink();
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: point.x - 44,
                  top: point.y - 24,
                  width: 88,
                  height: 48,
                  child: CustomPaint(
                    key: const Key('gameplay_destination_paint'),
                    painter: _GameplayDestinationPainter(
                      animation: _controller,
                      kind: indicator.kind,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _GameplayDestinationPainter extends CustomPainter {
  _GameplayDestinationPainter({
    required Animation<double> animation,
    required this.kind,
  }) : _animation = animation,
       super(repaint: animation);

  final Animation<double> _animation;
  final GameplayDestinationKind kind;

  Color get _color => switch (kind) {
    GameplayDestinationKind.move => const Color(0xFF7EDBFF),
    GameplayDestinationKind.attack => const Color(0xFFFF624F),
    GameplayDestinationKind.interact => const Color(0xFFFFBE58),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final phase = _animation.value;
    final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
    final center = size.center(Offset.zero);
    final outerOpacity = (1 - phase) * 0.62;
    final outer = Paint()
      ..color = _color.withValues(alpha: outerOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 44 + phase * 30,
        height: 18 + phase * 12,
      ),
      outer,
    );

    final ring = Paint()
      ..color = _color.withValues(alpha: 0.72 + pulse * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 45 + pulse * 5,
        height: 18 + pulse * 2,
      ),
      ring,
    );

    final mark = Paint()
      ..color = const Color(0xFFFFF0CC).withValues(alpha: 0.8 + pulse * 0.2)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    switch (kind) {
      case GameplayDestinationKind.move:
        for (var index = 0; index < 4; index += 1) {
          final angle = index * math.pi / 2;
          final direction = Offset(math.cos(angle), math.sin(angle));
          canvas.drawCircle(center + direction * (9 + pulse * 2), 2, mark);
        }
      case GameplayDestinationKind.attack:
        canvas.drawLine(
          center + const Offset(-6, -5),
          center + const Offset(6, 5),
          mark,
        );
        canvas.drawLine(
          center + const Offset(6, -5),
          center + const Offset(-6, 5),
          mark,
        );
      case GameplayDestinationKind.interact:
        final path = Path()
          ..moveTo(center.dx, center.dy - 7)
          ..lineTo(center.dx + 8, center.dy)
          ..lineTo(center.dx, center.dy + 7)
          ..lineTo(center.dx - 8, center.dy)
          ..close();
        canvas.drawPath(path, mark..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_GameplayDestinationPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}
