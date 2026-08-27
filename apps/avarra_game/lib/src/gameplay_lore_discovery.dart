import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gameplay_story_archive.dart';

/// A persistent, reactive entry point from live gameplay to earned story.
final class GameplayLoreShortcut extends StatefulWidget {
  const GameplayLoreShortcut({
    required this.progress,
    this.pendingDiscoveryCount = 0,
    required this.reducedMotion,
    required this.onPressed,
    super.key,
  }) : assert(pendingDiscoveryCount >= 0);

  final GameStoryArchiveProgress progress;
  final int pendingDiscoveryCount;
  final bool reducedMotion;
  final VoidCallback onPressed;

  @override
  State<GameplayLoreShortcut> createState() => _GameplayLoreShortcutState();
}

final class _GameplayLoreShortcutState extends State<GameplayLoreShortcut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _newMemoryCount = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      value: 1,
    )..addStatusListener(_handlePulseStatus);
  }

  @override
  void didUpdateWidget(GameplayLoreShortcut oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added =
        widget.progress.revealedCount - oldWidget.progress.revealedCount;
    if (added > 0) {
      _newMemoryCount = added;
      if (widget.reducedMotion) {
        _pulse.value = 1;
      } else {
        _pulse.forward(from: 0);
      }
    } else if (widget.reducedMotion && !oldWidget.reducedMotion) {
      _pulse.value = 1;
    }
  }

  void _handlePulseStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _newMemoryCount = 0);
    }
  }

  @override
  void dispose() {
    _pulse
      ..removeStatusListener(_handlePulseStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulsing = _pulse.isAnimating && !widget.reducedMotion;
        final intensity = pulsing ? math.sin(_pulse.value * math.pi) : 0.0;
        final color = Color.lerp(
          const Color(0xFFD4A76A),
          const Color(0xFFFFE1A3),
          intensity,
        )!;
        final discoveryVisualLabel = _newMemoryCount == 1
            ? 'NEW MEMORY'
            : '$_newMemoryCount NEW MEMORIES';
        final discoverySemanticLabel = _newMemoryCount == 1
            ? 'New story memory'
            : '$_newMemoryCount new story memories';
        final pendingVisualLabel = widget.pendingDiscoveryCount == 1
            ? '1 NEW'
            : '${widget.pendingDiscoveryCount} NEW';
        final pendingSemanticLabel = widget.pendingDiscoveryCount == 1
            ? '1 new memory awaiting review.'
            : '${widget.pendingDiscoveryCount} new memories awaiting review.';
        final visualLabel = pulsing
            ? '$discoveryVisualLabel · ${widget.progress.countLabel}'
            : widget.pendingDiscoveryCount > 0
            ? 'LORE · ${widget.progress.countLabel} · $pendingVisualLabel'
            : 'LORE · ${widget.progress.countLabel}';
        final semanticsLabel = pulsing
            ? '$discoverySemanticLabel discovered. '
                  '${widget.progress.revealedCount} of '
                  '${widget.progress.totalCount} memories revealed. Open lore.'
            : 'Story archive. ${widget.progress.revealedCount} of '
                  '${widget.progress.totalCount} memories revealed. '
                  '${widget.pendingDiscoveryCount > 0 ? '$pendingSemanticLabel ' : ''}'
                  'Open lore.';
        return Semantics(
          key: const Key('gameplay_lore_shortcut_semantics'),
          button: true,
          liveRegion: pulsing,
          label: semanticsLabel,
          child: ExcludeSemantics(
            child: Transform.scale(
              scale: 1 + (0.035 * intensity),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    if (intensity > 0)
                      BoxShadow(
                        color: color.withValues(alpha: 0.38 * intensity),
                        blurRadius: 15 * intensity,
                        spreadRadius: 1.5 * intensity,
                      ),
                  ],
                ),
                child: OutlinedButton.icon(
                  key: const Key('open_lore_archive'),
                  onPressed: widget.onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.8)),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.auto_stories_outlined, size: 17),
                  label: Text(
                    visualLabel,
                    key: const Key('gameplay_lore_shortcut_label'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
