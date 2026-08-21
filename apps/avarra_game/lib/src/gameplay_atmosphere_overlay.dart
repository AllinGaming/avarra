import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A bounded, visual-only ash/ember layer that keeps idle scenes moving.
final class GameplayAtmosphereOverlay extends StatefulWidget {
  const GameplayAtmosphereOverlay({this.compact = false, super.key});

  final bool compact;

  @override
  State<GameplayAtmosphereOverlay> createState() =>
      _GameplayAtmosphereOverlayState();
}

final class _GameplayAtmosphereOverlayState
    extends State<GameplayAtmosphereOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const Key('gameplay_atmosphere'),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GameplayAtmospherePainter(
            animation: _controller,
            particleCount: widget.compact ? 12 : 20,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

final class _GameplayAtmospherePainter extends CustomPainter {
  _GameplayAtmospherePainter({
    required Animation<double> animation,
    required this.particleCount,
  }) : _animation = animation,
       super(repaint: animation);

  final Animation<double> _animation;
  final int particleCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final progress = _animation.value;
    final paint = Paint()..blendMode = BlendMode.screen;
    for (var index = 0; index < particleCount; index += 1) {
      final seed = _fraction(index * 0.61803398875 + 0.13);
      final speed = 0.18 + (index % 5) * 0.025;
      final travel = _fraction(seed + progress * speed);
      final x = _fraction(seed * 7.31 + progress * 0.045) * size.width;
      final y = (1 - travel) * size.height;
      final shimmer =
          0.45 + 0.55 * math.sin((progress * 2 + seed) * math.pi * 2).abs();
      final alpha = (28 + shimmer * 72).round();
      final radius = 0.8 + (index % 4) * 0.45;
      paint.color = Color.fromARGB(alpha, 255, 153 + index % 3 * 22, 78);
      canvas.drawCircle(Offset(x, y), radius, paint);

      if (index.isEven) {
        paint
          ..color = Color.fromARGB((alpha * 0.25).round(), 255, 105, 52)
          ..strokeWidth = radius * 0.7;
        canvas.drawLine(
          Offset(x, y + radius * 5),
          Offset(x, y + radius * 1.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GameplayAtmospherePainter oldDelegate) {
    return oldDelegate.particleCount != particleCount;
  }
}

double _fraction(double value) => value - value.floorToDouble();
