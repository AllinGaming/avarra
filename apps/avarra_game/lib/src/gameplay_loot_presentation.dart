import 'dart:math' as math;

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Returns deterministic inventory additions for presentation-only feedback.
List<String> newlyAddedInventoryItemIds({
  required Iterable<String> previous,
  required Iterable<String> next,
}) {
  final previousIds = Set<String>.of(previous);
  final addedIds = Set<String>.of(next).difference(previousIds).toList()
    ..sort();
  return List.unmodifiable(addedIds);
}

/// A bounded, pointer-transparent beam over available authored collectibles.
final class GameplayLootBeamOverlay extends StatefulWidget {
  GameplayLootBeamOverlay({
    required this.snapshot,
    required this.cameraRig,
    Set<EntityId> lootEntityIds = const {},
    this.maximumBeams = 8,
    super.key,
  }) : lootEntityIds = Set.unmodifiable(lootEntityIds) {
    if (maximumBeams <= 0 || maximumBeams > 16) {
      throw ArgumentError.value(
        maximumBeams,
        'maximumBeams',
        'Must be from 1 to 16.',
      );
    }
  }

  final PresentationSnapshot snapshot;
  final IsometricCameraRig cameraRig;
  final Set<EntityId> lootEntityIds;
  final int maximumBeams;

  @override
  State<GameplayLootBeamOverlay> createState() =>
      _GameplayLootBeamOverlayState();
}

final class _GameplayLootBeamOverlayState extends State<GameplayLootBeamOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(GameplayLootBeamOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.lootEntityIds.isEmpty) {
      _controller.stop();
      _controller.value = 0;
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
      key: const Key('gameplay_loot_beams'),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (size.isEmpty || widget.lootEntityIds.isEmpty) {
              return const SizedBox.shrink();
            }
            final anchors = <Offset>[];
            for (final entity in widget.snapshot.entities) {
              if (!widget.lootEntityIds.contains(entity.entityId)) continue;
              final position = entity.transform.position;
              final point = widget.cameraRig.screenPointForWorld(
                worldPoint: Vector3(position.x, position.y + 0.2, position.z),
                viewportWidth: size.width,
                viewportHeight: size.height,
              );
              if (point.x >= -40 &&
                  point.x <= size.width + 40 &&
                  point.y >= -150 &&
                  point.y <= size.height + 40) {
                anchors.add(Offset(point.x, point.y));
              }
              if (anchors.length == widget.maximumBeams) break;
            }
            return CustomPaint(
              key: const Key('gameplay_loot_beam_paint'),
              painter: _GameplayLootBeamPainter(
                animation: _controller,
                anchors: anchors,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

final class _GameplayLootBeamPainter extends CustomPainter {
  _GameplayLootBeamPainter({
    required Animation<double> animation,
    required this.anchors,
  }) : _animation = animation,
       super(repaint: animation);

  final Animation<double> _animation;
  final List<Offset> anchors;

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint();
    for (var index = 0; index < anchors.length; index += 1) {
      final anchor = anchors[index];
      final phase = _fraction(_animation.value + index * 0.217);
      final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
      final height = 112 + pulse * 20;
      final beamRect = Rect.fromLTRB(
        anchor.dx - 8,
        anchor.dy - height,
        anchor.dx + 8,
        anchor.dy + 2,
      );
      final glow = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCCFFB64A), Color(0x66FFE39A), Color(0x00FFEBC1)],
        ).createShader(beamRect)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 11 + pulse * 3;
      canvas.drawLine(
        Offset(anchor.dx, anchor.dy),
        Offset(anchor.dx, anchor.dy - height),
        glow,
      );

      final core = Paint()
        ..color = const Color(0xFFFFE9B4).withValues(alpha: 0.7 + pulse * 0.25)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(anchor.dx, anchor.dy - 2),
        Offset(anchor.dx, anchor.dy - height * 0.78),
        core,
      );

      final ring = Paint()
        ..color = const Color(0xFFFFB449).withValues(alpha: 0.55 + pulse * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawOval(
        Rect.fromCenter(
          center: anchor,
          width: 30 + pulse * 10,
          height: 11 + pulse * 4,
        ),
        ring,
      );

      for (var particle = 0; particle < 4; particle += 1) {
        final travel = _fraction(phase + particle * 0.23);
        final side = math.sin((travel + particle) * math.pi * 2) * 9;
        final point = Offset(
          anchor.dx + side,
          anchor.dy - 8 - travel * height * 0.8,
        );
        canvas.drawCircle(
          point,
          1.2 + particle * 0.25,
          particlePaint
            ..color = const Color(
              0xFFFFD47D,
            ).withValues(alpha: (1 - travel) * 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GameplayLootBeamPainter oldDelegate) {
    return !listEquals(oldDelegate.anchors, anchors);
  }
}

/// One confirmed inventory addition presented to the local player.
final class PickupPresentationNotice {
  PickupPresentationNotice({required this.sequence, required String itemLabel})
    : itemLabel = itemLabel.trim() {
    if (sequence <= 0) {
      throw ArgumentError.value(sequence, 'sequence', 'Must be positive.');
    }
    if (this.itemLabel.isEmpty) {
      throw ArgumentError.value(itemLabel, 'itemLabel', 'Must not be empty.');
    }
  }

  final int sequence;
  final String itemLabel;
}

/// Animated, accessible confirmation for authoritative inventory pickup.
final class GameplayPickupToast extends StatefulWidget {
  const GameplayPickupToast({required this.notice, this.onFinished, super.key});

  final PickupPresentationNotice? notice;
  final ValueChanged<int>? onFinished;

  @override
  State<GameplayPickupToast> createState() => _GameplayPickupToastState();
}

final class _GameplayPickupToastState extends State<GameplayPickupToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addStatusListener(_handleStatus);
    if (widget.notice != null) _controller.forward();
  }

  @override
  void didUpdateWidget(GameplayPickupToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice?.sequence != widget.notice?.sequence) {
      if (widget.notice == null) {
        _controller.reset();
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  void _handleStatus(AnimationStatus status) {
    final notice = widget.notice;
    if (status == AnimationStatus.completed && notice != null) {
      widget.onFinished?.call(notice.sequence);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return IgnorePointer(
      key: const Key('gameplay_pickup_toast'),
      child: notice == null
          ? const SizedBox.shrink()
          : Semantics(
              key: const Key('pickup_toast_semantics'),
              liveRegion: true,
              label: 'Loot acquired: ${notice.itemLabel}',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = _controller.value;
                  final fadeIn = (progress / 0.12).clamp(0, 1).toDouble();
                  final fadeOut = ((1 - progress) / 0.22)
                      .clamp(0, 1)
                      .toDouble();
                  final opacity = math.min(fadeIn, fadeOut).toDouble();
                  final slide =
                      12 * (1 - Curves.easeOutCubic.transform(fadeIn));
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, slide),
                      child: child,
                    ),
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE619120D),
                    border: Border.all(color: const Color(0xFFFFB85C)),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Color(0xAAFF8A22), blurRadius: 18),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.diamond_outlined,
                          color: Color(0xFFFFC269),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOOT ACQUIRED',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFFFFC269),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                  ),
                            ),
                            Text(
                              notice.itemLabel,
                              key: const Key('pickup_toast_item_label'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

double _fraction(double value) => value - value.floorToDouble();
