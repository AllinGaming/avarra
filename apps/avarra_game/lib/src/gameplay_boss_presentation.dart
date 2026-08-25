import 'dart:math' as math;

import 'package:avarra_core/avarra_core.dart';
import 'package:flutter/material.dart';

enum GameplayBossNoticeKind { engaged, phaseTwo, phaseThree, defeated }

final class GameplayBossNotice {
  const GameplayBossNotice({
    required this.sequence,
    required this.bossEntityId,
    required this.bossName,
    required this.kind,
    required this.text,
  }) : assert(sequence > 0),
       assert(bossName.length > 0),
       assert(text.length > 0);

  final int sequence;
  final EntityId bossEntityId;
  final String bossName;
  final GameplayBossNoticeKind kind;
  final String text;

  String get heading => switch (kind) {
    GameplayBossNoticeKind.engaged => 'BOSS AWAKENED',
    GameplayBossNoticeKind.phaseTwo => 'PHASE II',
    GameplayBossNoticeKind.phaseThree => 'FINAL PHASE',
    GameplayBossNoticeKind.defeated => 'BOSS DEFEATED',
  };
}

/// Timed, pointer-transparent presentation of an authoritative boss beat.
final class GameplayBossToast extends StatefulWidget {
  const GameplayBossToast({
    required this.notice,
    this.compact = false,
    this.onFinished,
    super.key,
  });

  final GameplayBossNotice? notice;
  final bool compact;
  final ValueChanged<int>? onFinished;

  @override
  State<GameplayBossToast> createState() => _GameplayBossToastState();
}

final class _GameplayBossToastState extends State<GameplayBossToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..addStatusListener(_handleStatus);
    if (widget.notice != null) _controller.forward();
  }

  @override
  void didUpdateWidget(GameplayBossToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice?.sequence == widget.notice?.sequence) return;
    if (widget.notice == null) {
      _controller.reset();
    } else {
      _controller.forward(from: 0);
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
      key: const Key('gameplay_boss_notice'),
      child: notice == null
          ? const SizedBox.shrink()
          : Semantics(
              key: const Key('boss_notice_semantics'),
              liveRegion: true,
              label: '${notice.heading}. ${notice.bossName}. ${notice.text}',
              child: AnimatedBuilder(
                animation: _controller,
                child: _BossNoticeCard(notice: notice, compact: widget.compact),
                builder: (context, child) {
                  final progress = _controller.value;
                  final fadeIn = (progress / 0.1).clamp(0, 1).toDouble();
                  final fadeOut = ((1 - progress) / 0.16)
                      .clamp(0, 1)
                      .toDouble();
                  return Opacity(
                    opacity: math.min(fadeIn, fadeOut),
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * Curves.easeOut.transform(fadeIn),
                      child: child,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

final class _BossNoticeCard extends StatelessWidget {
  const _BossNoticeCard({required this.notice, required this.compact});

  final GameplayBossNotice notice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final defeated = notice.kind == GameplayBossNoticeKind.defeated;
    final accent = defeated ? const Color(0xFFFFD36B) : const Color(0xFFFF5A3D);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 330 : 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF21A0907),
          border: Border.symmetric(
            horizontal: BorderSide(color: accent, width: 2),
          ),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 28),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 22,
            compact ? 10 : 14,
            compact ? 14 : 22,
            compact ? 11 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notice.heading,
                key: const Key('boss_notice_heading'),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notice.bossName.toUpperCase(),
                key: const Key('boss_notice_name'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                notice.text,
                key: const Key('boss_notice_text'),
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE9D4C7),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
