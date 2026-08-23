import 'dart:math' as math;

import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// One projected presentation marker for derived authoritative quest guidance.
final class GameplayQuestMarker {
  GameplayQuestMarker({
    required this.kind,
    required this.label,
    required Vector3 worldPosition,
    required this.distanceMeters,
  }) : worldPosition = Vector3.copy(worldPosition) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'Must not be empty.');
    }
    if (!this.worldPosition.storage.every((value) => value.isFinite)) {
      throw ArgumentError.value(
        worldPosition,
        'worldPosition',
        'Must be finite.',
      );
    }
    if (!distanceMeters.isFinite || distanceMeters < 0) {
      throw ArgumentError.value(
        distanceMeters,
        'distanceMeters',
        'Must be finite and non-negative.',
      );
    }
  }

  final AuthoredQuestGuidanceKind kind;
  final String label;
  final Vector3 worldPosition;
  final double distanceMeters;
}

/// Keeps the current authored quest target readable on-screen or at the edge.
final class GameplayQuestMarkerOverlay extends StatefulWidget {
  const GameplayQuestMarkerOverlay({
    required this.marker,
    required this.cameraRig,
    super.key,
  });

  final GameplayQuestMarker? marker;
  final IsometricCameraRig cameraRig;

  @override
  State<GameplayQuestMarkerOverlay> createState() =>
      _GameplayQuestMarkerOverlayState();
}

final class _GameplayQuestMarkerOverlayState
    extends State<GameplayQuestMarkerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(GameplayQuestMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.marker == null) {
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
      key: const Key('gameplay_quest_marker'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final marker = widget.marker;
            final size = constraints.biggest;
            if (marker == null ||
                size.isEmpty ||
                size.width < 220 ||
                size.height < 140) {
              return const SizedBox.shrink();
            }
            final projected = widget.cameraRig.screenPointForWorld(
              worldPoint: marker.worldPosition + Vector3(0, 1.15, 0),
              viewportWidth: size.width,
              viewportHeight: size.height,
            );
            final center = Offset(size.width / 2, size.height / 2);
            final target = Offset(projected.x, projected.y);
            final clamped = Offset(
              target.dx.clamp(104, size.width - 104).toDouble(),
              target.dy.clamp(56, size.height - 74).toDouble(),
            );
            final offscreen = (target - clamped).distance > 0.5;
            final direction = target - center;
            final rotation =
                math.atan2(direction.dy, direction.dx) + math.pi / 2;
            final color = _guidanceColor(marker.kind);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: clamped.dx - 100,
                  top: clamped.dy - 48,
                  width: 200,
                  height: 96,
                  child: Semantics(
                    key: const Key('quest_marker_semantics'),
                    label:
                        'Quest target: ${marker.label}, '
                        '${_formatDistance(marker.distanceMeters)}',
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final pulse =
                            0.5 +
                            0.5 * math.sin(_controller.value * math.pi * 2);
                        return Transform.scale(
                          scale: 0.96 + pulse * 0.08,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            key: Key(
                              offscreen
                                  ? 'quest_marker_offscreen'
                                  : 'quest_marker_onscreen',
                            ),
                            angle: offscreen ? rotation : 0,
                            child: Icon(
                              offscreen
                                  ? Icons.navigation
                                  : Icons.keyboard_arrow_down,
                              color: color,
                              size: 30,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xE61A120C),
                              border: Border.all(color: color),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x99000000),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    marker.label,
                                    key: const Key('quest_marker_label'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: const Color(0xFFFFF0D1),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  Text(
                                    _formatDistance(marker.distanceMeters),
                                    key: const Key('quest_marker_distance'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: color),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

String gameplayQuestDistanceLabel(double distanceMeters) =>
    _formatDistance(distanceMeters);

String _formatDistance(double distanceMeters) {
  if (distanceMeters >= 1000) {
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
  return '${distanceMeters.round()} m';
}

Color _guidanceColor(AuthoredQuestGuidanceKind kind) => switch (kind) {
  AuthoredQuestGuidanceKind.objective => const Color(0xFF76D7FF),
  AuthoredQuestGuidanceKind.guardian => const Color(0xFFFF6558),
  AuthoredQuestGuidanceKind.collectible => const Color(0xFFFFC45C),
  AuthoredQuestGuidanceKind.turnIn => const Color(0xFF8ED489),
};
