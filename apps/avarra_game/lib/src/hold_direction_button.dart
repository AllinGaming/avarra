import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Directional control that remains active for the complete pointer hold.
final class HoldDirectionButton extends StatefulWidget {
  const HoldDirectionButton({
    required this.label,
    required this.direction,
    required this.icon,
    required this.onPointerDown,
    required this.onPointerEnd,
    required this.onSemanticTap,
    this.showTooltip = true,
    this.enabled = true,
    super.key,
  });

  final String label;
  final Vector3 direction;
  final Widget icon;
  final void Function(int pointer, Vector3 direction) onPointerDown;
  final ValueChanged<int> onPointerEnd;
  final ValueChanged<Vector3> onSemanticTap;
  final bool showTooltip;
  final bool enabled;

  @override
  State<HoldDirectionButton> createState() => _HoldDirectionButtonState();
}

final class _HoldDirectionButtonState extends State<HoldDirectionButton> {
  static const _tapThreshold = Duration(milliseconds: 180);

  final Set<int> _activePointers = {};
  final Set<int> _tapEligiblePointers = {};
  final Map<int, Timer> _tapTimers = {};

  void _handlePointerDown(PointerDownEvent event) {
    setState(() => _activePointers.add(event.pointer));
    _tapEligiblePointers.add(event.pointer);
    _tapTimers[event.pointer] = Timer(_tapThreshold, () {
      _tapTimers.remove(event.pointer);
      _tapEligiblePointers.remove(event.pointer);
    });
    widget.onPointerDown(event.pointer, widget.direction);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (!_activePointers.remove(event.pointer)) {
      return;
    }
    _tapTimers.remove(event.pointer)?.cancel();
    final shouldPulse = _tapEligiblePointers.remove(event.pointer);
    setState(() {});
    widget.onPointerEnd(event.pointer);
    if (event is PointerUpEvent && shouldPulse) {
      widget.onSemanticTap(widget.direction);
    }
  }

  @override
  void didUpdateWidget(HoldDirectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      final pointers = _activePointers.toList(growable: false);
      _activePointers.clear();
      for (final timer in _tapTimers.values) {
        timer.cancel();
      }
      _tapTimers.clear();
      _tapEligiblePointers.clear();
      for (final pointer in pointers) {
        widget.onPointerEnd(pointer);
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _tapTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _activePointers.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final button = Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled
          ? () => widget.onSemanticTap(widget.direction)
          : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.enabled ? _handlePointerDown : null,
        onPointerUp: widget.enabled ? _handlePointerEnd : null,
        onPointerCancel: widget.enabled ? _handlePointerEnd : null,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.35,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: pressed
                  ? colorScheme.primary.withValues(alpha: 0.24)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            width: 48,
            height: 48,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 24,
                  color: pressed ? colorScheme.primary : null,
                ),
                child: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.showTooltip) {
      return button;
    }
    return Tooltip(message: widget.label, child: button);
  }
}
