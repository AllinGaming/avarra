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
    super.key,
  });

  final String label;
  final Vector3 direction;
  final Widget icon;
  final void Function(int pointer, Vector3 direction) onPointerDown;
  final ValueChanged<int> onPointerEnd;
  final ValueChanged<Vector3> onSemanticTap;
  final bool showTooltip;

  @override
  State<HoldDirectionButton> createState() => _HoldDirectionButtonState();
}

final class _HoldDirectionButtonState extends State<HoldDirectionButton> {
  final Set<int> _activePointers = {};

  void _handlePointerDown(PointerDownEvent event) {
    setState(() => _activePointers.add(event.pointer));
    widget.onPointerDown(event.pointer, widget.direction);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (!_activePointers.remove(event.pointer)) {
      return;
    }
    setState(() {});
    widget.onPointerEnd(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _activePointers.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final button = Semantics(
      button: true,
      label: widget.label,
      onTap: () => widget.onSemanticTap(widget.direction),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
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
    );
    if (!widget.showTooltip) {
      return button;
    }
    return Tooltip(message: widget.label, child: button);
  }
}
